import 'package:adaptive_layouts/adaptive_layouts.dart';
import 'package:flutter/gestures.dart';
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
            builder: (context) =>
                HandleDivider.builder(context, isDragging, isSettling),
          ),
        ),
      ),
    );
  }

  Finder line() => find.byType(AnimatedContainer);
  Finder dots() => find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).shape == BoxShape.circle,
  );

  testWidgets('idle renders a thin 1px line with no handle dots', (
    tester,
  ) async {
    await tester.pumpWidget(harness(isDragging: false, isSettling: false));
    await tester.pumpAndSettle();

    expect(tester.getSize(line()).width, 1);
    expect(dots(), findsNothing);
  });

  testWidgets('dragging thickens the line and shows the three-dot handle', (
    tester,
  ) async {
    await tester.pumpWidget(harness(isDragging: true, isSettling: false));
    await tester.pumpAndSettle();

    expect(tester.getSize(line()).width, 4);
    expect(dots(), findsNWidgets(3));
  });

  testWidgets('hover activates the handle without dragging', (tester) async {
    await tester.pumpWidget(harness(isDragging: false, isSettling: false));
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(HandleDivider)));
    await tester.pumpAndSettle();

    expect(tester.getSize(line()).width, 4);
    expect(dots(), findsNWidgets(3));
  });

  testWidgets('settling renders without interaction (snap feedback)', (
    tester,
  ) async {
    await tester.pumpWidget(harness(isDragging: false, isSettling: true));
    await tester.pumpAndSettle();

    expect(find.byType(HandleDivider), findsOneWidget);
    // Settling is feedback-only: thin line, primary tint, no dots.
    expect(dots(), findsNothing);
  });
}
