import 'package:adaptive_layouts/adaptive_layouts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the given icon and message, centered', (tester) async {
    final builder = IconMessageEmpty.of(
      icon: Icons.inbox_outlined,
      message: 'Select something',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Builder(builder: builder)),
      ),
    );

    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.text('Select something'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Select something'),
        matching: find.byType(Center),
      ),
      findsWidgets,
    );
  });
}
