import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/link_monitor.dart';
import '../core/signal_dispatcher.dart';
import '../core/vault_store.dart';
import '../setup/app_spec.dart';
import 'shell_view.dart' deferred as shell;

// ─── SignalConsentView ──────────────────────────────────────
// Egyptian-themed promo asking the user to allow push.  Two
// buttons: Accept (triggers the OS permission dialog) and
// Skip (sets a 3-day cool-down before re-asking).
//
// Layout adapts to both orientations.  The background uses the
// gray loading asset re-purposed as a Notifications backdrop;
// a translucent gold panel houses the call-to-action.
// ────────────────────────────────────────────────────────────

class SignalConsentView extends StatefulWidget {
  final VaultStore vault;
  final SignalDispatcher signal;
  final LinkMonitor link;
  final String contentUrl;

  const SignalConsentView({
    super.key,
    required this.vault,
    required this.signal,
    required this.link,
    required this.contentUrl,
  });

  @override
  State<SignalConsentView> createState() => _SignalConsentViewState();
}

class _SignalConsentViewState extends State<SignalConsentView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    // Let the backdrop run under the status bar and gesture pill so the
    // artwork covers the entire physical screen without dead bands.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _onAccept() async {
    final granted = await widget.signal.requestConsent();
    if (!granted) {
      await _scheduleSkip();
    }
    await _routeForward();
  }

  Future<void> _onSkip() async {
    await _scheduleSkip();
    await _routeForward();
  }

  Future<void> _scheduleSkip() async {
    final wakeAt = DateTime.now()
            .add(AppSpec.consentColdDown)
            .millisecondsSinceEpoch ~/
        1000;
    await widget.vault.writeConsentSkipUntil(wakeAt);
  }

  Future<void> _routeForward() async {
    await shell.loadLibrary();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => shell.ShellView(
          url: widget.contentUrl,
          vault: widget.vault,
          signal: widget.signal,
          link: widget.link,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final landscape = size.width > size.height;
    final bg = landscape
        ? 'assets/Notifications/Horizontal_Notifications.webp'
        : 'assets/Notifications/Vertical_Notifications.webp';

    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0703),
      extendBody: true,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              bg,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),

            // Darkening gradient on the lower half.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),

            if (landscape)
              _landscapePanel(size, bottomInset)
            else
              _portraitPanel(size, bottomInset),
          ],
        ),
      ),
    );
  }

  Widget _portraitPanel(Size size, double bottomInset) {
    return Positioned(
      left: size.width * 0.08,
      right: size.width * 0.08,
      bottom: size.height * 0.07 + bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AcceptCta(glow: _glowAnim, onTap: _onAccept),
          const SizedBox(height: 16),
          SkipCta(onTap: _onSkip),
        ],
      ),
    );
  }

  Widget _landscapePanel(Size size, double bottomInset) {
    // Landscape variant: no heading / icon — only Accept + Skip.
    return Positioned(
      left: 0,
      right: 0,
      bottom: size.height * 0.10 + bottomInset,
      child: Center(
        child: SizedBox(
          width: size.width * 0.45,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AcceptCta(glow: _glowAnim, onTap: _onAccept, compact: true),
              const SizedBox(height: 8),
              SkipCta(onTap: _onSkip, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class AcceptCta extends StatefulWidget {
  final Animation<double> glow;
  final VoidCallback onTap;
  final bool compact;

  const AcceptCta({
    super.key,
    required this.glow,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<AcceptCta> createState() => _AcceptCtaState();
}

class _AcceptCtaState extends State<AcceptCta> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedBuilder(
        animation: widget.glow,
        builder: (_, child) => AnimatedScale(
          scale: _down ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: widget.compact ? 12 : 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _down
                    ? const [Color(0xFFB07A1A), Color(0xFF8A5B0E)]
                    : const [Color(0xFFE6B547), Color(0xFFB07A1A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: const Color(0xFFFFE3A1).withValues(alpha: 0.7),
                width: 1.4,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE6B547)
                      .withValues(alpha: _down ? 0.15 : widget.glow.value),
                  blurRadius: _down ? 8 : 14 + widget.glow.value * 18,
                  spreadRadius: _down ? 0 : widget.glow.value * 4,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Accept',
                style: TextStyle(
                  color: const Color(0xFF1A0A00),
                  fontSize: widget.compact ? 16 : 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SkipCta extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;

  const SkipCta({super.key, required this.onTap, this.compact = false});

  @override
  State<SkipCta> createState() => _SkipCtaState();
}

class _SkipCtaState extends State<SkipCta> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedOpacity(
        opacity: _down ? 0.5 : 0.85,
        duration: const Duration(milliseconds: 80),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: widget.compact ? 4 : 8),
          child: Text(
            'Skip',
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.compact ? 15 : 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
