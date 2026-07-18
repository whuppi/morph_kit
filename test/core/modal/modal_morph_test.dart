import 'package:adaptive_layouts/adaptive_layouts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

Widget _opener({ModalConfig config = const ModalConfig()}) {
  return Builder(
    builder: (context) => Center(
      child: ElevatedButton(
        onPressed: () => showAdaptiveModal<Object>(
          context: context,
          config: config,
          builder: (context, mode) => SizedBox(
            width: mode == ModalLayoutMode.dialog ? 300 : double.infinity,
            height: 200,
            child: const CounterPane(),
          ),
        ),
        child: const Text('open'),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Resizes and pumps just far enough for the swap to fire and the flight
/// to be mid-air — no settling.
Future<void> _resizeIntoFlight(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

bool _contentIsInsideSheet(WidgetTester tester) => find
    .descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(CounterPane),
    )
    .evaluate()
    .isNotEmpty;

void main() {
  testWidgets('the swap flies: content leaves the routes, then lands', (
    tester,
  ) async {
    await pumpApp(tester, _opener(), size: const Size(1000, 800));
    await _open(tester);

    await tester.tap(find.byType(CounterPane));
    await tester.pump();

    await _resizeIntoFlight(tester, const Size(500, 800));

    // Mid-air: the destination sheet is up (with its placeholder), the
    // live content is in the flight — visible, stateful, in neither route.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(CounterPane), findsOneWidget);
    expect(_contentIsInsideSheet(tester), isFalse);
    expect(find.text('count: 1'), findsOneWidget);

    // Landing: content hands off into the sheet, flight gone, state kept.
    await tester.pumpAndSettle();
    expect(_contentIsInsideSheet(tester), isTrue);
    expect(find.text('count: 1'), findsOneWidget);
  });

  testWidgets('dismissing mid-flight lands the content and completes', (
    tester,
  ) async {
    await pumpApp(tester, _opener(), size: const Size(1000, 800));
    await _open(tester);
    await _resizeIntoFlight(tester, const Size(500, 800));
    expect(_contentIsInsideSheet(tester), isFalse);

    Navigator.of(tester.element(find.byType(CounterPane))).pop('mid-flight');
    await tester.pumpAndSettle();

    expect(find.byType(CounterPane), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('crossing back mid-flight retargets and still keeps state', (
    tester,
  ) async {
    await pumpApp(tester, _opener(), size: const Size(1000, 800));
    await _open(tester);

    await tester.tap(find.byType(CounterPane));
    await tester.pump();

    await _resizeIntoFlight(tester, const Size(500, 800));
    await _resizeIntoFlight(tester, const Size(1000, 800));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('count: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('morph: false swaps as an instant cut', (tester) async {
    await pumpApp(
      tester,
      _opener(config: const ModalConfig(morph: false)),
      size: const Size(1000, 800),
    );
    await _open(tester);

    tester.view.physicalSize = const Size(500, 800);
    await tester.pump();
    await tester.pump();

    // No flight: the content is already inside the sheet.
    expect(_contentIsInsideSheet(tester), isTrue);
  });

  testWidgets('flight surface morphs geometry between the forms', (
    tester,
  ) async {
    await pumpApp(tester, _opener(), size: const Size(1000, 800));
    await _open(tester);

    final dialogRect = tester.getRect(find.byType(CounterPane));

    await _resizeIntoFlight(tester, const Size(500, 800));
    final midRect = tester.getRect(find.byType(CounterPane));

    await tester.pumpAndSettle();
    final sheetRect = tester.getRect(find.byType(CounterPane));

    // The sheet form is wider than the dialog form and sits lower; the
    // mid-flight rect is between the two on both axes.
    expect(sheetRect.width, greaterThan(dialogRect.width));
    expect(midRect.width, greaterThanOrEqualTo(dialogRect.width));
    expect(midRect.width, lessThanOrEqualTo(sheetRect.width));
    expect(midRect.top, greaterThanOrEqualTo(dialogRect.top));
    expect(midRect.top, lessThanOrEqualTo(sheetRect.top));
  });
}
