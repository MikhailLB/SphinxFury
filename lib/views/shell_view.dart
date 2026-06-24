import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/link_monitor.dart';
import '../core/net_client.dart';
import '../core/signal_dispatcher.dart';
import '../core/vault_store.dart';
import 'offline_view.dart';

// ─── ShellView ──────────────────────────────────────────────
// Full-screen WebView host for the resolved partner URL.
//
// Notable engineering points:
//   • Both orientations enabled, immersive system UI.
//   • PopScope blocks app exit and instead drives the WebView's
//     back history.
//   • Live connectivity stream pushes user to OfflineView when
//     the link drops mid-session.
//   • Two JS injections at every onPageFinished:
//       - kill safe-area insets so we never see white bars on
//         notched panels;
//       - scroll focused inputs above the soft keyboard.
//   • Too-many-redirects detection with bounded retry from the
//     last good main-frame URL.
//   • External schemes (intent:, tel:, market:, etc.) route to
//     url_launcher instead of failing inside the WebView.
// ────────────────────────────────────────────────────────────

Future<void> primeShell() async {
  // Reserved for any future platform pre-warm.
}

class ShellView extends StatefulWidget {
  final String url;
  final VaultStore vault;
  final SignalDispatcher signal;
  final LinkMonitor link;

  const ShellView({
    super.key,
    required this.url,
    required this.vault,
    required this.signal,
    required this.link,
  });

  @override
  State<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<ShellView> with WidgetsBindingObserver {
  late final WebViewController _wv;
  bool _spinner = true;
  bool _navigatedOff = false;
  StreamSubscription<List<ConnectivityResult>>? _pulseSub;

  String? _lastMain;
  int _redirectRetries = 0;

  // ── Lifecycle ──────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _applyImmersive();

    _wv = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(netClient.ua)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _spinner = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _spinner = false);
            _redirectRetries = 0;
            _injectSafeAreaPurge();
            _injectKeyboardLift();
          },
          onWebResourceError: _onWebError,
          onHttpError: (_) {},
          onNavigationRequest: _onNavigation,
        ),
      );

    _configureAndroid();
    _wv.loadRequest(Uri.parse(widget.url));

    widget.signal.onWarmUrl = (u) {
      if (mounted) _wv.loadRequest(Uri.parse(u));
    };

    _pulseSub = widget.link.pulse.listen((hops) {
      if (hops.every((r) => r == ConnectivityResult.none)) {
        _detectAndRedirectOffline();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _applyImmersive();
  }

  void _applyImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseSub?.cancel();
    widget.signal.onWarmUrl = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  // ── Navigation handlers ────────────────────────────────

  NavigationDecision _onNavigation(NavigationRequest req) {
    final uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;

    const allowed = {'http', 'https', 'about', 'data', 'blob'};
    if (allowed.contains(uri.scheme)) {
      if (req.isMainFrame) _lastMain = req.url;
      return NavigationDecision.navigate;
    }

    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((_) => false));
    return NavigationDecision.prevent;
  }

  void _onWebError(WebResourceError err) {
    if (err.isForMainFrame != true) return;

    final txt = err.description.toLowerCase();
    final tooMany = txt.contains('too_many_redirects') ||
        txt.contains('too many redirects') ||
        err.errorCode == -1007 ||
        err.errorCode == -9;

    if (tooMany && _lastMain != null && _redirectRetries < 3) {
      _redirectRetries++;
      _wv.loadRequest(Uri.parse(_lastMain!));
      return;
    }
    _detectAndRedirectOffline();
  }

  Future<void> _detectAndRedirectOffline() async {
    if (_navigatedOff) return;
    final online = await widget.link.isOnline();
    if (online || !mounted) return;
    _navigatedOff = true;

    final current = await _wv.currentUrl() ?? widget.url;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OfflineView(
          rebuild: (_) => ShellView(
            url: current,
            vault: widget.vault,
            signal: widget.signal,
            link: widget.link,
          ),
        ),
      ),
    );
  }

  // ── Android-specific tuning ────────────────────────────

  void _configureAndroid() {
    if (!Platform.isAndroid) return;
    if (_wv.platform is! AndroidWebViewController) return;

    final ac = _wv.platform as AndroidWebViewController;
    ac.setMediaPlaybackRequiresUserGesture(false);
    ac.setOnShowFileSelector(_handleFileSelect);

    final cookieMgr = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookieMgr.setAcceptThirdPartyCookies(ac, true);
  }

  Future<List<String>> _handleFileSelect(FileSelectorParams p) async {
    try {
      final picked = await FilePicker.pickFiles(
        allowMultiple: p.mode == FileSelectorMode.openMultiple,
        type: FileType.any,
      );
      if (picked == null) return const [];
      return picked.files
          .where((f) => f.path != null)
          .map((f) => Uri.file(f.path!).toString())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ── JS shims ───────────────────────────────────────────

  void _injectKeyboardLift() {
    _wv.runJavaScript(r'''
(function(){
  if (window.__sphxKbLift) return;
  window.__sphxKbLift = true;

  function focusable(el){
    return el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);
  }
  function lift(){
    var el = document.activeElement;
    if (!focusable(el)) return;
    var vp = window.visualViewport;
    if (vp){
      var r = el.getBoundingClientRect();
      var floor = vp.offsetTop + vp.height;
      if (r.bottom > floor - 20 || r.top < vp.offsetTop){
        el.scrollIntoView({behavior:'auto', block:'nearest'});
      }
    } else {
      el.scrollIntoView({behavior:'auto', block:'nearest'});
    }
  }

  document.addEventListener('focusin', function(e){
    if (focusable(e.target)) setTimeout(lift, 350);
  });

  if (window.visualViewport){
    var prev = window.visualViewport.height;
    window.visualViewport.addEventListener('resize', function(){
      var h = window.visualViewport.height;
      if (h < prev) setTimeout(lift, 120);
      prev = h;
    });
  }
})();
''');
  }

  void _injectSafeAreaPurge() {
    _wv.runJavaScript(r'''
(function(){
  if (window.__sphxSAFE) return;
  window.__sphxSAFE = true;

  var SID = '__sphx_safearea';
  var CSS =
    ':root{' +
      '--safe-area-inset-top:0px!important;' +
      '--safe-area-inset-right:0px!important;' +
      '--safe-area-inset-bottom:0px!important;' +
      '--safe-area-inset-left:0px!important;' +
      '--sat:0px!important;--sar:0px!important;' +
      '--sab:0px!important;--sal:0px!important;' +
      '--safe-top:0px!important;--safe-right:0px!important;' +
      '--safe-bottom:0px!important;--safe-left:0px!important;' +
    '}' +
    'html,body,#__nuxt,#__layout,#app,#root,.gameview-mobile-header{' +
      'padding-top:0!important;padding-left:0!important;' +
      'padding-right:0!important;margin-top:0!important;' +
    '}';

  function kbOpen(){
    if (!window.visualViewport) return false;
    return window.visualViewport.height < window.innerHeight * 0.75;
  }

  function paint(){
    if (kbOpen()) return;
    var head = document.head || document.documentElement;
    if (!head) return;
    var meta = document.querySelector('meta[name="viewport"]');
    if (meta && !/viewport-fit\s*=\s*contain/i.test(meta.getAttribute('content') || '')){
      var c = (meta.getAttribute('content') || '')
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
      meta.setAttribute('content', c + (c ? ', ' : '') + 'viewport-fit=contain');
    }
    var node = document.getElementById(SID);
    if (!node){
      node = document.createElement('style');
      node.id = SID;
      head.appendChild(node);
    }
    if (node.textContent !== CSS) node.textContent = CSS;
    if (head.lastElementChild !== node) head.appendChild(node);
  }

  paint();
  ['pushState','replaceState'].forEach(function(fn){
    var orig = history[fn];
    history[fn] = function(){
      var r = orig.apply(this, arguments);
      setTimeout(paint, 80);
      setTimeout(paint, 400);
      return r;
    };
  });
  window.addEventListener('popstate', function(){ setTimeout(paint, 80); });
  setInterval(paint, 2500);
})();
''');
  }

  // ── UI ─────────────────────────────────────────────────

  Future<bool> _swallowPop() async {
    if (await _wv.canGoBack()) {
      await _wv.goBack();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final landscape = mq.orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (popped, _) async {
        if (!popped) await _swallowPop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: landscape
                  ? EdgeInsets.only(
                      left: mq.viewPadding.left,
                      right: mq.viewPadding.right,
                    )
                  : EdgeInsets.only(top: mq.viewPadding.top),
              child: WebViewWidget(controller: _wv),
            ),
            if (_spinner)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB347)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
