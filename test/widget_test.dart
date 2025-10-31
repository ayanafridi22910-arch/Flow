import 'package:flow/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FirstPage UI test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Allow the app to settle
    await tester.pumpAndSettle();

    // Verify that the app bar title is correct.
    expect(find.text('Flow Dashboard'), findsOneWidget);

    // Verify that the "Start Blocking Session" button is present.
    expect(find.text('Start Blocking Session'), findsOneWidget);

    // Verify that the "Your Total Screen Time" text is present.
    expect(find.text('Your Total Screen Time'), findsOneWidget);
  });
}