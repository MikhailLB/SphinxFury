import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import 'main_menu_screen.dart';
import 'level_select_screen.dart';

class WinScreen extends StatefulWidget {
  final int moves;
  final int seconds;
  final String puzzleAsset;
  final String puzzleName;
  final int gridSize;

  const WinScreen({
    super.key,
    required this.moves,
    required this.seconds,
    required this.puzzleAsset,
    required this.puzzleName,
    required this.gridSize,
  });

  @override
  State<WinScreen> createState() => _WinScreenState();
}

class _WinScreenState extends State<WinScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _timeString {
    final m = widget.seconds ~/ 60;
    final s = widget.seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/bggame.webp', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.6)),
          FadeTransition(
            opacity: _fadeAnim,
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGlowText('PUZZLE', 40),
                  _buildGlowText('SOLVED!', 52),
                  const SizedBox(height: 32),
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: _buildCompletedImage(),
                  ),
                  const SizedBox(height: 32),
                  _buildStats(),
                  const SizedBox(height: 40),
                  _buildButtons(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowText(String text, double size) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.gold,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 6,
        shadows: [
          Shadow(
            color: AppColors.amber.withValues(alpha: 0.8),
            blurRadius: 24,
          ),
          Shadow(
            color: AppColors.gold.withValues(alpha: 0.4),
            blurRadius: 48,
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedImage() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.gold, width: 3),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(widget.puzzleAsset, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _WinStat(label: 'MOVES', value: '${widget.moves}'),
        Container(
          width: 1,
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          color: AppColors.darkGold,
        ),
        _WinStat(label: 'TIME', value: _timeString),
        Container(
          width: 1,
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          color: AppColors.darkGold,
        ),
        _WinStat(
          label: 'GRID',
          value: '${widget.gridSize}×${widget.gridSize}',
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        _WinButton(
          label: 'PLAY AGAIN',
          icon: Icons.replay_rounded,
          primary: true,
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LevelSelectScreen(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _WinButton(
          label: 'MAIN MENU',
          icon: Icons.home_outlined,
          primary: false,
          onTap: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainMenuScreen()),
            (route) => false,
          ),
        ),
      ],
    );
  }
}

class _WinStat extends StatelessWidget {
  final String label;
  final String value;

  const _WinStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.sandstone,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _WinButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  const _WinButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        height: 52,
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  colors: [
                    Color(0xFF8B6914),
                    Color(0xFFD4AF37),
                    Color(0xFF8B6914)
                  ],
                )
              : const LinearGradient(
                  colors: [Color(0xFF3B2314), Color(0xFF6B3D1E)],
                ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: AppColors.gold,
            width: primary ? 0 : 1.5,
          ),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: primary ? AppColors.hieroglyphBrown : AppColors.gold,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: primary ? AppColors.hieroglyphBrown : AppColors.gold,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
