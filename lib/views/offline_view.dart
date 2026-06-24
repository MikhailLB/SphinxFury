import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── OfflineView ────────────────────────────────────────────
// Shown whenever connectivity drops (first launch or mid-WebView).
// Uses the project-specific gray background art with a single
// "Retry" call-to-action overlaid at the bottom.
//
// The caller supplies [rebuild], a builder for the screen we
// should pushReplacement to when the user taps Retry — usually
// either the splash (IntroView) or the WebView (ShellView).
// ────────────────────────────────────────────────────────────

class OfflineView extends StatefulWidget {
  final WidgetBuilder rebuild;

  const OfflineView({super.key, required this.rebuild});

  @override
  State<OfflineView> createState() => _OfflineViewState();
}

class _OfflineViewState extends State<OfflineView>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  late final AnimationController _press;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pressAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );

    // Edge-to-edge — artwork extends under the status bar and the
    // navigation pill so no dead bands remain at the top or bottom.
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
    _press.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_busy) return;
    await _press.forward();
    await _press.reverse();
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.rebuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final landscape = size.width > size.height;
    final bg = landscape
        ? 'assets/Nowifi/Horizontal_Nowifi.webp'
        : 'assets/Nowifi/Vertical_Nowifi.png';

    // Portrait → fit width so the banner with "NO INTERNET CONNECTION"
    //            stays visible without horizontal cropping.
    //            Top alignment keeps the headline anchored to the top.
    // Landscape → fit height (cover-like) since the artwork already
    //             has horizontal proportions.
    final fit = landscape ? BoxFit.cover : BoxFit.fitWidth;
    final alignment = landscape ? Alignment.center : Alignment.topCenter;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0703),
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              bg,
              fit: fit,
              alignment: alignment,
            ),

            // Subtle dim so the button keeps contrast.
            Container(color: Colors.black.withValues(alpha: 0.10)),

            Positioned(
              left: landscape ? size.width * 0.30 : size.width * 0.10,
              right: landscape ? size.width * 0.30 : size.width * 0.10,
              bottom: size.height * (landscape ? 0.08 : 0.06),
              child: ScaleTransition(
                scale: _pressAnim,
                child: _RetryCta(busy: _busy, onTap: _retry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetryCta extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;

  const _RetryCta({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: busy
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFE6B547), Color(0xFFB07A1A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: busy ? const Color(0xFF50330C) : null,
          border: Border.all(
            color: const Color(0xFFFFE3A1).withValues(alpha: 0.55),
            width: 1.4,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: busy
              ? const []
              : [
                  BoxShadow(
                    color: const Color(0xFFE6B547).withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: busy
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFE3A1),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Reconnecting…',
                    style: TextStyle(
                      color: Color(0xFFFFE3A1),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              )
            : const Text(
                'Retry',
                style: TextStyle(
                  color: Color(0xFF1A0A00),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
      ),
    );
  }
}
