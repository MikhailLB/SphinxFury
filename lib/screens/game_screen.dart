import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/puzzle_model.dart';
import '../utils/app_colors.dart';
import 'win_screen.dart';

class GameScreen extends StatefulWidget {
  final int gridSize;
  final String puzzleAsset;
  final String puzzleName;

  const GameScreen({
    super.key,
    required this.gridSize,
    required this.puzzleAsset,
    required this.puzzleName,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late PuzzleModel _puzzle;
  ui.Image? _image;
  int _moves = 0;
  int _seconds = 0;
  Timer? _timer;
  int? _tappedIndex;

  @override
  void initState() {
    super.initState();
    _puzzle = PuzzleModel(gridSize: widget.gridSize);
    _loadImage();
    _startTimer();
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load(widget.puzzleAsset);
    final bytes = data.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _image = frame.image);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _timeString {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onTileTap(int index) {
    if (_puzzle.tiles[index] == 0) return;
    if (!_puzzle.canMove(index)) return;

    setState(() {
      _tappedIndex = index;
      _puzzle.move(index);
      _moves++;
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _tappedIndex = null);
    });

    if (_puzzle.isSolved()) {
      _timer?.cancel();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => WinScreen(
                moves: _moves,
                seconds: _seconds,
                puzzleAsset: widget.puzzleAsset,
                puzzleName: widget.puzzleName,
                gridSize: widget.gridSize,
              ),
              transitionsBuilder: (context, anim, secondaryAnimation, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/bggame.webp', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.5)),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildHeader(context),
                const SizedBox(height: 12),
                _buildStats(),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(child: _buildPuzzleGrid()),
                ),
                const SizedBox(height: 16),
                _buildShuffleButton(),
                const SizedBox(height: 20),
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
        Column(
          children: [
            Text(
              widget.puzzleName.toUpperCase(),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            Text(
              '${widget.gridSize}×${widget.gridSize}',
              style: const TextStyle(
                color: AppColors.sandstone,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        Positioned(
          left: 8,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: AppColors.gold, size: 20),
            onPressed: () {
              _timer?.cancel();
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatBadge(icon: Icons.touch_app_outlined, value: '$_moves', label: 'MOVES'),
        const SizedBox(width: 24),
        _StatBadge(icon: Icons.timer_outlined, value: _timeString, label: 'TIME'),
      ],
    );
  }

  Widget _buildPuzzleGrid() {
    if (_image == null) {
      return const CircularProgressIndicator(color: AppColors.gold);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSize = (constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight) *
            0.92;
        final tileSize = maxSize / widget.gridSize;
        final gridPixelSize = tileSize * widget.gridSize;

        return Container(
          width: gridPixelSize,
          height: gridPixelSize,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: List.generate(
              widget.gridSize * widget.gridSize,
              (i) => _buildTile(i, tileSize),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTile(int index, double tileSize) {
    final tileValue = _puzzle.tiles[index];
    final row = index ~/ widget.gridSize;
    final col = index % widget.gridSize;

    if (tileValue == 0) {
      return Positioned(
        left: col * tileSize,
        top: row * tileSize,
        width: tileSize,
        height: tileSize,
        child: Container(color: Colors.black87),
      );
    }

    final srcRow = (tileValue - 1) ~/ widget.gridSize;
    final srcCol = (tileValue - 1) % widget.gridSize;

    final isMovable = _puzzle.canMove(index);
    final isTapped = _tappedIndex == index;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      left: col * tileSize,
      top: row * tileSize,
      width: tileSize,
      height: tileSize,
      child: GestureDetector(
        onTap: () => _onTileTap(index),
        child: AnimatedScale(
          scale: isTapped ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isMovable
                    ? AppColors.gold.withValues(alpha: 0.9)
                    : AppColors.darkGold.withValues(alpha: 0.4),
                width: isMovable ? 1.5 : 0.8,
              ),
              boxShadow: isMovable
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.3),
                        blurRadius: 4,
                      )
                    ]
                  : null,
            ),
            child: ClipRect(
              child: CustomPaint(
                painter: _TilePainter(
                  image: _image!,
                  srcRow: srcRow,
                  srcCol: srcCol,
                  gridSize: widget.gridSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShuffleButton() {
    return GestureDetector(
      onTap: () {
        _timer?.cancel();
        setState(() {
          _puzzle = PuzzleModel(gridSize: widget.gridSize);
          _moves = 0;
          _seconds = 0;
        });
        _startTimer();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B2314), Color(0xFF6B3D1E)],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.gold, width: 1.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shuffle_rounded, color: AppColors.gold, size: 18),
            SizedBox(width: 8),
            Text(
              'SHUFFLE',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 14,
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

class _TilePainter extends CustomPainter {
  final ui.Image image;
  final int srcRow;
  final int srcCol;
  final int gridSize;

  _TilePainter({
    required this.image,
    required this.srcRow,
    required this.srcCol,
    required this.gridSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final tileW = imgW / gridSize;
    final tileH = imgH / gridSize;

    final src = Rect.fromLTWH(
      srcCol * tileW,
      srcRow * tileH,
      tileW,
      tileH,
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(_TilePainter old) =>
      old.image != image ||
      old.srcRow != srcRow ||
      old.srcCol != srcCol ||
      old.gridSize != gridSize;
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatBadge({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        border: Border.all(color: AppColors.darkGold, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.gold, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.sandstone,
                  fontSize: 9,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
