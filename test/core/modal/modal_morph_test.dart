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

  testWidgets('the sheet lands at its final width — no post-landing resize', (
    tester,
  ) async {
    await pumpApp(tester, _opener(), size: const Size(1000, 800));
    await _open(tester);

    tester.view.physicalSize = const Size(500, 800);
    await tester.pump();
    await tester.pump();
    // Let the width handshake propagate (report → flight relayout → size
    // back), as continuous frames would on a device...
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // ...then jump near flight end: the destination sheet must already sit
    // at its true final geometry — the placeholder is laid out at the
    // width the sheet offers, not at the outgoing dialog's width.
    await tester.pump(const Duration(milliseconds: 250));
    final sheetSurface = find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Material),
        )
        .first;
    final flightEndRect = tester.getRect(sheetSurface);

    await tester.pumpAndSettle();
    expect(tester.getRect(sheetSurface), flightEndRect);
    expect(flightEndRect.width, 500);
  });

  testWidgets('both resting forms clip like the flight does', (tester) async {
    await pumpApp(tester, _opener(), size: const Size(1000, 800));
    await _open(tester);

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.clipBehavior, Clip.antiAlias);

    await resizeWindow(tester, const Size(500, 800));
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.clipBehavior, Clip.antiAlias);
  });

  testWidgets('the destination is a ghost until the flight becomes it', (
    tester,
  ) async {
    await pumpApp(
      tester,
      _opener(config: const ModalConfig(showDragHandle: true)),
      size: const Size(1000, 800),
    );
    await _open(tester);

    await _resizeIntoFlight(tester, const Size(500, 800));

    // Mid-flight the sheet route exists for layout and barrier, but shows
    // nothing: transparent surface, no elevation, no handle.
    final ghostSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(ghostSheet.backgroundColor, Colors.transparent);
    expect(ghostSheet.elevation, 0);
    expect(ghostSheet.showDragHandle, isFalse);

    // Landing replaces the ghost with the normally-chromed route.
    await tester.pumpAndSettle();
    final realSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(realSheet.backgroundColor, isNot(Colors.transparent));
    expect(realSheet.showDragHandle, isTrue);
    expect(_contentIsInsideSheet(tester), isTrue);
  });

  testWidgets('outbound dialog is a ghost too', (tester) async {
    await pumpApp(tester, _opener(), size: const Size(500, 800));
    await _open(tester);

    await _resizeIntoFlight(tester, const Size(1000, 800));
    final ghostDialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(ghostDialog.backgroundColor, Colors.transparent);
    expect(ghostDialog.elevation, 0);

    await tester.pumpAndSettle();
    final realDialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(realDialog.backgroundColor, isNull);
    expect(find.text('count: 0'), findsOneWidget);
  });

  testWidgets('landing under a drag handle does not jump', (tester) async {
    await pumpApp(
      tester,
      _opener(config: const ModalConfig(showDragHandle: true)),
      size: const Size(1000, 800),
    );
    await _open(tester);

    tester.view.physicalSize = const Size(500, 800);
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 250));
    final flightEnd = tester.getRect(find.byType(CounterPane));

    await tester.pumpAndSettle();
    final landed = tester.getRect(find.byType(CounterPane));

    // The ghost's placeholder spacer stands in for the handle band, so
    // the content lands exactly where the flight left it — a wrong spacer
    // metric shows up here as a ~48px vertical jump.
    expect(landed.top, closeTo(flightEnd.top, 2));
    expect(landed.left, closeTo(flightEnd.left, 2));
    expect(landed.width, closeTo(flightEnd.width, 2));
  });

  testWidgets('content reflows with the container — no destination-width '
      'chop', (tester) async {
    await pumpApp(tester, _opener(), size: const Size(1000, 800));
    await _open(tester);
    final dialogWidth = tester.getRect(find.byType(CounterPane)).width;

    await _resizeIntoFlight(tester, const Size(500, 800));

    // Mid-flight the content is laid at the container's lerped width —
    // strictly between the two forms. Jumping straight to the sheet's
    // width would mean the narrower container is cropping it.
    final midWidth = tester.getRect(find.byType(CounterPane)).width;
    expect(midWidth, greaterThan(dialogWidth));
    expect(midWidth, lessThan(500));

    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(CounterPane)).width, 500);
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
