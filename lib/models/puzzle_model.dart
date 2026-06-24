import 'dart:math';

class PuzzleModel {
  final int gridSize;
  late List<int> tiles;
  late List<int> solution;

  PuzzleModel({required this.gridSize}) {
    final total = gridSize * gridSize;
    solution = List.generate(total, (i) => i);
    tiles = List.from(solution);
    _shuffle();
  }

  void _shuffle() {
    final rng = Random();
    do {
      tiles.shuffle(rng);
    } while (!_isSolvable() || isSolved());
  }

  bool _isSolvable() {
    int inversions = 0;
    final flat = tiles.where((t) => t != 0).toList();
    for (int i = 0; i < flat.length; i++) {
      for (int j = i + 1; j < flat.length; j++) {
        if (flat[i] > flat[j]) inversions++;
      }
    }
    if (gridSize % 2 == 1) {
      return inversions % 2 == 0;
    } else {
      final blankRow = tiles.indexOf(0) ~/ gridSize;
      final rowFromBottom = gridSize - blankRow;
      return (rowFromBottom % 2 == 0) ? (inversions % 2 == 1) : (inversions % 2 == 0);
    }
  }

  bool isSolved() {
    for (int i = 0; i < tiles.length; i++) {
      if (tiles[i] != solution[i]) return false;
    }
    return true;
  }

  bool canMove(int index) {
    final blankIndex = tiles.indexOf(0);
    final row = index ~/ gridSize;
    final col = index % gridSize;
    final blankRow = blankIndex ~/ gridSize;
    final blankCol = blankIndex % gridSize;

    return (row == blankRow && (col - blankCol).abs() == 1) ||
        (col == blankCol && (row - blankRow).abs() == 1);
  }

  void move(int index) {
    if (!canMove(index)) return;
    final blankIndex = tiles.indexOf(0);
    tiles[blankIndex] = tiles[index];
    tiles[index] = 0;
  }

  int get blankIndex => tiles.indexOf(0);
}
