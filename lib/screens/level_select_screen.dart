import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import 'game_screen.dart';

class PuzzleOption {
  final String asset;
  final String name;
  PuzzleOption(this.asset, this.name);
}

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  int _selectedGrid = 3;
  int _selectedPuzzle = 0;

  final List<PuzzleOption> _puzzles = [
    PuzzleOption('assets/pharaoh.webp', 'Tutankhamun'),
    PuzzleOption('assets/anubis.webp', 'Anubis'),
    PuzzleOption('assets/ra.webp', 'Ra'),
  ];

  final List<int> _grids = [3, 4, 5];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/bggame.webp', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.55)),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildSectionLabel('SELECT PUZZLE'),
                const SizedBox(height: 16),
                _buildPuzzleSelector(),
                const SizedBox(height: 28),
                _buildSectionLabel('SELECT DIFFICULTY'),
                const SizedBox(height: 16),
                _buildGridSelector(),
                const Spacer(),
                _buildPlayButton(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Text(
          'SELECT LEVEL',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        Positioned(
          left: 16,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: AppColors.gold, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.sandstone,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 3,
      ),
    );
  }

  Widget _buildPuzzleSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_puzzles.length, (i) {
        final isSelected = i == _selectedPuzzle;
        return GestureDetector(
          onTap: () => setState(() => _selectedPuzzle = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: isSelected ? 100 : 84,
            height: isSelected ? 100 : 84,
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? AppColors.gold : AppColors.darkGold,
                width: isSelected ? 3 : 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(_puzzles[i].asset, fit: BoxFit.cover),
                  if (!isSelected)
                    Container(color: Colors.black.withValues(alpha: 0.35)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGridSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _grids.map((g) {
        final isSelected = g == _selectedGrid;
        return GestureDetector(
          onTap: () => setState(() => _selectedGrid = g),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF8B6914), Color(0xFFD4AF37)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF2C1810), Color(0xFF3B2314)],
                    ),
              border: Border.all(
                color: isSelected ? AppColors.gold : AppColors.darkGold,
                width: isSelected ? 2.5 : 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.4),
                        blurRadius: 12,
                      )
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$g×$g',
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.hieroglyphBrown
                        : AppColors.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  g == 3
                      ? 'Easy'
                      : g == 4
                          ? 'Medium'
                          : 'Hard',
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.hieroglyphBrown.withValues(alpha: 0.8)
                        : AppColors.sandstone.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlayButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            gridSize: _selectedGrid,
            puzzleAsset: _puzzles[_selectedPuzzle].asset,
            puzzleName: _puzzles[_selectedPuzzle].name,
          ),
        ),
      ),
      child: Container(
        width: 220,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B6914), Color(0xFFD4AF37), Color(0xFF8B6914)],
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded,
                color: AppColors.hieroglyphBrown, size: 28),
            SizedBox(width: 8),
            Text(
              'START',
              style: TextStyle(
                color: AppColors.hieroglyphBrown,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
