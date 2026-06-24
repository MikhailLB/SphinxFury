import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main_menu_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  int _dotCount = 0;
  Timer? _progressTimer;
  Timer? _dotTimer;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount + 1) % 4);
    });

    _startProgress();
  }

  void _startProgress() {
    const totalDuration = Duration(milliseconds: 3200);
    const interval = Duration(milliseconds: 50);
    final steps = totalDuration.inMilliseconds ~/ interval.inMilliseconds;
    int currentStep = 0;

    _progressTimer = Timer.periodic(interval, (timer) {
      currentStep++;
      final ratio = currentStep / steps;

      double newProgress;
      if (ratio < 0.85) {
        newProgress = ratio / 0.85 * 0.92;
      } else {
        newProgress = 0.92 + (ratio - 0.85) / 0.15 * 0.08;
      }

      if (mounted) {
        setState(() => _progress = newProgress.clamp(0.0, 1.0));
      }

      if (currentStep >= steps && !_navigating) {
        timer.cancel();
        _navigating = true;
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const MainMenuScreen(),
                transitionsBuilder:
                    (context, anim, secondaryAnimation, child) =>
                        FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 600),
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          final bgAsset = isLandscape
              ? 'assets/Horizontal_LoadingScreen.webp'
              : 'assets/Vertical_LoadingScreen.webp';

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                bgAsset,
                fit: BoxFit.cover,
              ),
              Container(
                color: Colors.black.withValues(alpha: 0.3),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: isLandscape ? 32 : 60,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Loading$dots',
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
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
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 10,
                          backgroundColor: Colors.black45,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFD4AF37),
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
