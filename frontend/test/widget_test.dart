// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:scientist_ai/app.dart';

void main() {
  testWidgets('Renders Marie Query home', (WidgetTester tester) async {
    await tester.pumpWidget(const ScientistApp());
    expect(find.text('Marie Query'), findsOneWidget);
    expect(find.text('What are we investigating today?'), findsOneWidget);
  });
}
