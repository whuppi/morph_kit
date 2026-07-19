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

  testWidgets('content shrinks with the container on sheet → dialog', (
    tester,
  ) async {
    await pumpApp(tester, _opener(), size: const Size(500, 800));
    await _open(tester);
    expect(tester.getRect(find.byType(CounterPane)).width, 500);

    tester.view.physicalSize = const Size(1000, 800);
    await tester.pump();
    await tester.pump();
    // Let the natural-width sample + placeholder handshake propagate as
    // continuous frames would on a device...
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 90));

    // Mid-flight the content is laid tight at the container's lerped
    // width — narrowing gradually from the sheet's last width (640: the
    // M3 sheet max at the grown window) toward the dialog's 300. Jumping
    // straight to 300 at takeoff is the bug this pins.
    final midWidth = tester.getRect(find.byType(CounterPane)).width;
    expect(midWidth, lessThan(640));
    expect(midWidth, greaterThan(300));

    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(CounterPane)).width, 300);
  });

  testWidgets('backgroundColor knob colors both forms', (tester) async {
    const knob = Color(0xFF123456);
    await pumpApp(
      tester,
      _opener(config: const ModalConfig(backgroundColor: knob)),
      size: const Size(1000, 800),
    );
    await _open(tester);
    expect(tester.widget<Dialog>(find.byType(Dialog)).backgroundColor, knob);

    await resizeWindow(tester, const Size(500, 800));
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
      knob,
    );
  });

  testWidgets('fast back-and-forth still lands the sheet at full width', (
    tester,
  ) async {
    await pumpApp(tester, _opener(), size: const Size(1000, 800));
    await _open(tester);

    // Flip narrow → wide → narrow while flights are mid-air: each
    // retarget switches the target form, and the natural-width sample
    // must be retaken for the new form's content — a stale sample makes
    // the sheet land at the dialog's width, then snap wide.
    await _resizeIntoFlight(tester, const Size(500, 800));
    await _resizeIntoFlight(tester, const Size(1000, 800));
    await _resizeIntoFlight(tester, const Size(500, 800));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
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

  testWidgets('no narrow flash at takeoff — sampling never paints', (
    tester,
  ) async {
    await pumpApp(tester, _opener(), size: const Size(500, 800));
    await _open(tester);

    tester.view.physicalSize = const Size(1000, 800);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // Immediately after takeoff the content must still be near the
    // sheet's last width — a painted loose-sample frame shows up here as
    // the dialog-form content flashing to its own 300.
    expect(tester.getRect(find.byType(CounterPane)).width, greaterThan(500));

    await tester.pumpAndSettle(); // land the flight; free its ticker
  });

  testWidgets('constraint-filling content survives a handled-sheet morph', (
    tester,
  ) async {
    // Tall scrollable content (like a settings panel) fills whatever
    // height the slot offers. The ghost's handle band must reduce the
    // content's available height the way the real BottomSheet does —
    // stacking it on top instead overflows the slot by the band height.
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showAdaptiveModal<Object>(
              context: context,
              config: const ModalConfig(showDragHandle: true),
              builder: (context, mode) => SizedBox(
                width: mode == ModalLayoutMode.dialog ? 300 : double.infinity,
                child: SingleChildScrollView(
                  child: Column(
                    children: [for (var i = 0; i < 60; i++) Text('row $i')],
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
      size: const Size(1000, 800),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await resizeWindow(tester, const Size(500, 800));

    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('row 0'), findsOneWidget);

    await resizeWindow(tester, const Size(1000, 800));
    expect(tester.takeException(), isNull);
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('the flight paints exactly like the chrome it becomes', (
    tester,
  ) async {
    await pumpApp(tester, _opener(), size: const Size(1000, 800));
    await _open(tester);
    await _resizeIntoFlight(tester, const Size(500, 800));

    final flightMaterial = tester
        .widgetList<Material>(find.byType(Material))
        .singleWhere(
          (m) => m.clipBehavior == Clip.antiAlias && m.elevation > 0,
        );
    // Material implicitly animates shape/elevation over ~200ms — the
    // flight must opt out or its paint lags the lerp and pops at landing.
    expect(flightMaterial.animationDuration, Duration.zero);
    // M3 dialogs and sheets default to a transparent shadow; the flight
    // must match or its shadow vanishes at the handoff.
    expect(flightMaterial.shadowColor, Colors.transparent);

    await tester.pumpAndSettle(); // land the flight; free its ticker
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
