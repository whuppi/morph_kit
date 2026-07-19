import 'package:adaptive_layouts/adaptive_layouts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness({required bool isDragging, required bool isSettling}) {
    return MaterialApp(
      home: Center(
        child: SizedBox(
          width: 24,
          height: 400,
          child: Builder(
            builder: (context) => MaterialDivider.builder(
              context,
              DividerState(isDragging: isDragging, isSettling: isSettling),
            ),
          ),
        ),
      ),
    );
  }

  Finder line() => find.byType(AnimatedContainer);

  testWidgets('idle renders the thin line', (tester) async {
    await tester.pumpWidget(harness(isDragging: false, isSettling: false));
    await tester.pumpAndSettle();
    expect(tester.getSize(line()).width, MaterialDivider.lineWidth);
  });

  testWidgets('dragging thickens the line', (tester) async {
    await tester.pumpWidget(harness(isDragging: true, isSettling: false));
    await tester.pumpAndSettle();
    expect(tester.getSize(line()).width, 4);
  });

  testWidgets('settling also shows the active state', (tester) async {
    await tester.pumpWidget(harness(isDragging: false, isSettling: true));
    await tester.pumpAndSettle();
    expect(tester.getSize(line()).width, 4);
  });
}
