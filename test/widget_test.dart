import 'package:flutter_test/flutter_test.dart';
import 'package:sphinx_fury/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const SphinxFuryApp());
    expect(find.byType(SphinxFuryApp), findsOneWidget);
  });
}
