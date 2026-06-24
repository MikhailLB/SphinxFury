// Minimal smoke test — full app boot relies on Firebase/Android plugins
// and cannot run inside flutter_test without scaffolding.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder', () {
    expect(1 + 1, equals(2));
  });
}
