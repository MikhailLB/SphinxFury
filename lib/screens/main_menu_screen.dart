import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import 'level_select_screen.dart';
import 'webview_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _sphinxController;
  late Animation<double> _sphinxFloat;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _sphinxController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _sphinxFloat = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _sphinxController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _sphinxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/Vertical_LoadingScreen.webp', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.45)),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 240),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _sphinxFloat,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, _sphinxFloat.value),
                      child: child,
                    ),
                    child: Image.asset(
                      'assets/sphx.webp',
                      fit: BoxFit.contain,
                      width: size.width * 0.72,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildButtons(context),
                const SizedBox(height: 20),
                _buildFooterLinks(context),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        _EgyptButton(
          label: 'PLAY',
          icon: Icons.play_arrow_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const LevelSelectScreen()),
          ),
        ),
        const SizedBox(height: 14),
        _EgyptButton(
          label: 'PRIVACY POLICY',
          icon: Icons.shield_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WebViewScreen(
                url: 'https://sphinxfury.com/privacy-policy.html',
                title: 'Privacy Policy',
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _EgyptButton(
          label: 'SUPPORT',
          icon: Icons.help_outline_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WebViewScreen(
                url: 'https://sphinxfury.com/support.html',
                title: 'Support',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLinks(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WebViewScreen(
                url: 'https://sphinxfury.com/privacy-policy.html',
                title: 'Privacy Policy',
              ),
            ),
          ),
          child: Text(
            'Privacy Policy',
            style: TextStyle(
              color: AppColors.sandstone.withValues(alpha: 0.7),
              fontSize: 12,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.sandstone.withValues(alpha: 0.5),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '•',
            style: TextStyle(
              color: AppColors.gold.withValues(alpha: 0.5),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WebViewScreen(
                url: 'https://sphinxfury.com/support.html',
                title: 'Support',
              ),
            ),
          ),
          child: Text(
            'Support',
            style: TextStyle(
              color: AppColors.sandstone.withValues(alpha: 0.7),
              fontSize: 12,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.sandstone.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _EgyptButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _EgyptButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B2314), Color(0xFF6B3D1E)],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.gold, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.25),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
