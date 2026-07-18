import 'package:adaptive_layouts/adaptive_layouts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

Widget _layout({ListDetailController<String>? controller}) {
  return Material(
    child: ListDetailLayout<String>(
      controller: controller,
      compactDetailMode: CompactDetailMode.route,
      listBuilder: (context, selectedId, onSelect) => Column(
        children: [
          for (final id in const ['a', 'b'])
            TextButton(onPressed: () => onSelect(id), child: Text('item-$id')),
        ],
      ),
      detailBuilder: (context, id, mode, onDismiss) => Material(
        child: Column(
          children: [
            Text('detail-$id (${mode.name})'),
            TextButton(onPressed: onDismiss, child: const Text('close')),
            const Expanded(child: CounterPane()),
          ],
        ),
      ),
      emptyStateBuilder: (context) => const Text('empty'),
    ),
  );
}

NavigatorState _navigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator));

void main() {
  testWidgets('selecting pushes a REAL route with its entrance animation', (
    tester,
  ) async {
    await pumpApp(tester, _layout(), size: const Size(500, 800));
    expect(_navigator(tester).canPop(), isFalse);

    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();

    expect(find.text('detail-a (stacked)'), findsOneWidget);
    expect(_navigator(tester).canPop(), isTrue);
  });

  testWidgets('system back pops the route and clears the selection', (
    tester,
  ) async {
    final controller = ListDetailController<String>();
    await pumpApp(
      tester,
      _layout(controller: controller),
      size: const Size(500, 800),
    );
    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(controller.hasSelection, isFalse);
    expect(find.text('detail-a (stacked)'), findsNothing);
    expect(find.text('item-a'), findsOneWidget);
    expect(_navigator(tester).canPop(), isFalse);
  });

  testWidgets('controller.dismiss pops with a real exit animation', (
    tester,
  ) async {
    final controller = ListDetailController<String>();
    await pumpApp(
      tester,
      _layout(controller: controller),
      size: const Size(500, 800),
    );
    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();

    controller.dismiss();
    await tester.pump();
    await tester.pump(); // sync fires post-frame, pop starts
    await tester.pump(const Duration(milliseconds: 50));

    // Mid-exit: the detail rides the route out; isDetailVisible holds.
    expect(find.text('detail-a (stacked)'), findsOneWidget);
    expect(controller.isDetailVisible, isTrue);

    await tester.pumpAndSettle();
    expect(find.text('detail-a (stacked)'), findsNothing);
    expect(controller.isDetailVisible, isFalse);
  });

  testWidgets('the close button inside the detail dismisses', (tester) async {
    final controller = ListDetailController<String>();
    await pumpApp(
      tester,
      _layout(controller: controller),
      size: const Size(500, 800),
    );
    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(controller.hasSelection, isFalse);
    expect(_navigator(tester).canPop(), isFalse);
  });

  testWidgets('detail state survives compact ↔ expanded resizes', (
    tester,
  ) async {
    await pumpApp(tester, _layout(), size: const Size(500, 800));
    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CounterPane));
    await tester.tap(find.byType(CounterPane));
    await tester.pump();
    expect(find.text('count: 2'), findsOneWidget);

    await resizeWindow(tester, const Size(1000, 800));
    expect(find.text('detail-a (sideBySide)'), findsOneWidget);
    expect(find.text('count: 2'), findsOneWidget);
    expect(_navigator(tester).canPop(), isFalse); // pane, not a route

    await resizeWindow(tester, const Size(500, 800));
    expect(find.text('detail-a (stacked)'), findsOneWidget);
    expect(find.text('count: 2'), findsOneWidget);
    expect(_navigator(tester).canPop(), isTrue); // routed again
  });

  testWidgets('expanded layout never pushes a route', (tester) async {
    await pumpApp(tester, _layout(), size: const Size(1000, 800));
    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();

    expect(find.text('detail-a (sideBySide)'), findsOneWidget);
    expect(_navigator(tester).canPop(), isFalse);
  });

  testWidgets('deep-link mount shows the detail from the first frame', (
    tester,
  ) async {
    final controller = ListDetailController<String>(initialSelection: 'b');
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: _layout(controller: controller)));
    // First frame — before any post-frame push: the bridge shows it.
    expect(find.text('detail-b (stacked)'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('detail-b (stacked)'), findsOneWidget);
    expect(_navigator(tester).canPop(), isTrue);
  });

  testWidgets('re-selecting during the exit animation lands cleanly', (
    tester,
  ) async {
    await pumpApp(tester, _layout(), size: const Size(500, 800));
    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 40)); // exit under way
    await tester.tap(find.text('item-b'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('detail-b (stacked)'), findsOneWidget);
    expect(find.text('detail-a (stacked)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection change while open swaps content in the same route', (
    tester,
  ) async {
    final controller = ListDetailController<String>();
    await pumpApp(
      tester,
      _layout(controller: controller),
      size: const Size(500, 800),
    );
    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();

    controller.select('b');
    await tester.pumpAndSettle();

    expect(find.text('detail-b (stacked)'), findsOneWidget);
    _navigator(tester).pop();
    await tester.pumpAndSettle();
    expect(_navigator(tester).canPop(), isFalse); // it was a single route
  });

  testWidgets('live flip into route mode wires the re-show chain', (
    tester,
  ) async {
    final controller = ListDetailController<String>();
    final mode = ValueNotifier<CompactDetailMode>(CompactDetailMode.overlay);
    final tab = ValueNotifier<int>(0);
    addTearDown(mode.dispose);
    addTearDown(tab.dispose);

    // Children built ONCE and reused: a tab switch then only repaints the
    // re-shown child — like a kept-alive tab router — so the re-show must
    // be woken by PAINT, not by a rebuild that happens to come along.
    final tickets = ValueListenableBuilder<CompactDetailMode>(
      valueListenable: mode,
      builder: (context, m, _) => Material(
        child: ListDetailLayout<String>(
          controller: controller,
          compactDetailMode: m,
          listBuilder: (context, selectedId, onSelect) => Column(
            children: [
              for (final id in const ['a', 'b'])
                TextButton(
                  onPressed: () => onSelect(id),
                  child: Text('item-$id'),
                ),
            ],
          ),
          detailBuilder: (context, id, detailMode, onDismiss) => Material(
            child: Column(
              children: [
                Text('detail-$id (${detailMode.name})'),
                TextButton(onPressed: onDismiss, child: const Text('close')),
                const Expanded(child: CounterPane()),
              ],
            ),
          ),
          emptyStateBuilder: (context) => const Text('empty'),
        ),
      ),
    );
    const other = Material(child: Center(child: Text('other tab')));

    await pumpApp(
      tester,
      ValueListenableBuilder<int>(
        valueListenable: tab,
        builder: (context, index, _) =>
            IndexedStack(index: index, children: [tickets, other]),
      ),
      size: const Size(1000, 800),
    );

    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();
    expect(find.text('detail-a (sideBySide)'), findsOneWidget);

    // The user's step: flip the mode on the LIVE layout, at expanded.
    mode.value = CompactDetailMode.route;
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CounterPane));
    await tester.tap(find.byType(CounterPane));
    await tester.pump();

    tab.value = 1;
    await tester.pumpAndSettle();
    await resizeWindow(tester, const Size(500, 800));
    expect(_navigator(tester).canPop(), isFalse); // never over the other tab

    tab.value = 0;
    await tester.pumpAndSettle();

    expect(_navigator(tester).canPop(), isTrue); // routed, not inline
    expect(find.text('detail-a (stacked)'), findsOneWidget);
    expect(find.text('count: 2'), findsOneWidget); // state survived
  });

  testWidgets('resize to compact while hidden: return pushes the route', (
    tester,
  ) async {
    final controller = ListDetailController<String>();
    final tab = ValueNotifier<int>(0);
    addTearDown(tab.dispose);
    await pumpApp(
      tester,
      ValueListenableBuilder<int>(
        valueListenable: tab,
        builder: (context, index, _) => IndexedStack(
          index: index,
          children: [
            _layout(controller: controller),
            const Material(child: Center(child: Text('other tab'))),
          ],
        ),
      ),
      size: const Size(1000, 800),
    );
    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();
    expect(find.text('detail-a (sideBySide)'), findsOneWidget);
    await tester.tap(find.byType(CounterPane));
    await tester.tap(find.byType(CounterPane));
    await tester.pump();

    tab.value = 1;
    await tester.pumpAndSettle();

    // The breakpoint crossing happens while the tab is hidden.
    await resizeWindow(tester, const Size(500, 800));
    expect(_navigator(tester).canPop(), isFalse); // never over the other tab
    expect(find.text('other tab'), findsOneWidget);

    tab.value = 0;
    // ONE frame: the repaint's post-frame flush must push the route right
    // there (paintedThisFrame), not frames later via the deferred notifier
    // — on an idle device those later frames never come.
    await tester.pump();
    expect(_navigator(tester).canPop(), isTrue); // routed, not inline

    await tester.pump();
    expect(find.text('detail-a (stacked)'), findsOneWidget);
    expect(find.text('count: 2'), findsOneWidget); // state survived the trip
    await tester.pumpAndSettle();
  });

  testWidgets('hidden tab removes its route, keeps selection, re-shows', (
    tester,
  ) async {
    final controller = ListDetailController<String>();
    final tab = ValueNotifier<int>(0);
    addTearDown(tab.dispose);
    await pumpApp(
      tester,
      ValueListenableBuilder<int>(
        valueListenable: tab,
        builder: (context, index, _) => IndexedStack(
          index: index,
          children: [
            _layout(controller: controller),
            const Material(child: Center(child: Text('other tab'))),
          ],
        ),
      ),
      size: const Size(500, 800),
    );
    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();
    expect(find.text('detail-a (stacked)'), findsOneWidget);
    await tester.tap(find.byType(CounterPane));
    await tester.tap(find.byType(CounterPane));
    await tester.pump();

    tab.value = 1;
    await tester.pumpAndSettle();

    expect(find.text('detail-a (stacked)'), findsNothing);
    expect(_navigator(tester).canPop(), isFalse);
    expect(controller.hasSelection, isTrue); // selection survives the hide

    tab.value = 0;
    await tester.pumpAndSettle();

    expect(find.text('detail-a (stacked)'), findsOneWidget);
    expect(_navigator(tester).canPop(), isTrue);
    // The bridge re-homed the detail while its route was suppressed —
    // the element (and its state) never died.
    expect(find.text('count: 2'), findsOneWidget);
  });
}
