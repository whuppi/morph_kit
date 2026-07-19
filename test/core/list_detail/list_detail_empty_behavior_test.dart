import 'package:adaptive_layouts/adaptive_layouts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

Widget _layout({
  ListDetailController<String>? controller,
  ExpandedEmptyBehavior behavior = ExpandedEmptyBehavior.listOnly,
}) {
  return Material(
    child: ListDetailLayout<String>(
      controller: controller,
      expandedEmptyBehavior: behavior,
      listBuilder: (context, selectedId, onSelect) => ColoredBox(
        key: const Key('list'),
        color: const Color(0xFF111111),
        child: Center(
          child: TextButton(
            onPressed: () => onSelect('a'),
            child: const Text('item-a'),
          ),
        ),
      ),
      detailBuilder: (context, id, mode, onDismiss) => ColoredBox(
        key: const Key('detail'),
        color: const Color(0xFF333333),
        child: Column(
          children: [
            Text('detail-$id'),
            TextButton(onPressed: onDismiss, child: const Text('close')),
            const Expanded(child: CounterPane()),
          ],
        ),
      ),
      emptyStateBuilder: (context) => const Text('empty state'),
    ),
  );
}

void main() {
  const expanded = Size(1000, 800);

  testWidgets('listOnly: the list owns the full width until a selection', (
    tester,
  ) async {
    await pumpApp(tester, _layout(), size: expanded);

    expect(tester.getSize(find.byKey(const Key('list'))).width, 1000);
    expect(find.text('empty state'), findsNothing);
    expect(find.byKey(const Key('detail')), findsNothing);
  });

  testWidgets('listOnly: selecting reveals the pane; dismissing returns it', (
    tester,
  ) async {
    await pumpApp(tester, _layout(), size: expanded);

    await tester.tap(find.text('item-a'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    // Mid-reveal: the pane is arriving, list yielding.
    final midList = tester.getSize(find.byKey(const Key('list'))).width;
    expect(midList, lessThan(1000));
    // Reveal discipline: the arriving detail is laid at its FINAL width.
    expect(tester.getSize(find.byKey(const Key('detail'))).width, 500);

    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('list'))).width, 500);
    expect(find.text('detail-a'), findsOneWidget);

    await tester.tap(find.text('close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    // Mid-exit the outgoing detail still rides the retreating pane.
    expect(find.text('detail-a'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('list'))).width, 1000);
    expect(find.byKey(const Key('detail')), findsNothing);
  });

  testWidgets('listOnly: crossings without a selection are a non-event', (
    tester,
  ) async {
    await pumpApp(tester, _layout(), size: const Size(500, 800));
    expect(tester.getSize(find.byKey(const Key('list'))).width, 500);

    await resizeWindow(tester, expanded);
    // Full-width list on both sides of the breakpoint — no pane flash,
    // no empty state, nothing animating.
    expect(tester.getSize(find.byKey(const Key('list'))).width, 1000);
    expect(find.text('empty state'), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('listOnly: crossing with a selection lands both panes', (
    tester,
  ) async {
    await pumpApp(tester, _layout(), size: const Size(500, 800));
    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CounterPane));
    await tester.tap(find.byType(CounterPane));
    await tester.pump();

    await resizeWindow(tester, expanded);
    expect(tester.getSize(find.byKey(const Key('list'))).width, 500);
    expect(find.text('detail-a'), findsOneWidget);
    expect(find.text('count: 2'), findsOneWidget); // state survived

    await resizeWindow(tester, const Size(500, 800));
    expect(find.text('count: 2'), findsOneWidget);
  });

  for (final mode in CompactDetailMode.values) {
    testWidgets(
      'placeholder (${mode.name}): empty-pane crossings animate both ways',
      (tester) async {
        await pumpApp(
          tester,
          Material(
            child: ListDetailLayout<String>(
              compactDetailMode: mode,
              listBuilder: (context, selectedId, onSelect) =>
                  const ColoredBox(key: Key('list'), color: Color(0xFF111111)),
              detailBuilder: (context, id, mode, onDismiss) => Text('d-$id'),
              emptyStateBuilder: (context) => const Text('empty state'),
            ),
          ),
          size: const Size(500, 800),
        );

        // Into expanded: the empty pane REVEALS — mid-flight the list has
        // yielded partially and the placeholder is already on screen.
        tester.view.physicalSize = const Size(1000, 800);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final midList = tester.getSize(find.byKey(const Key('list'))).width;
        expect(midList, lessThan(1000));
        expect(midList, greaterThan(500));
        expect(find.text('empty state'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byKey(const Key('list'))).width, 500);

        // Into compact: the empty pane RETREATS — the expanded geometry
        // stays alive at the compact width until the retreat lands.
        tester.view.physicalSize = const Size(500, 800);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(find.text('empty state'), findsOneWidget); // still riding out
        expect(
          tester.getSize(find.byKey(const Key('list'))).width,
          lessThan(500),
        );
        await tester.pumpAndSettle();
        expect(find.text('empty state'), findsNothing);
        expect(tester.getSize(find.byKey(const Key('list'))).width, 500);
      },
    );
  }

  testWidgets('live flip between behaviors lands the settled layout', (
    tester,
  ) async {
    final behavior = ValueNotifier<ExpandedEmptyBehavior>(
      ExpandedEmptyBehavior.placeholder,
    );
    addTearDown(behavior.dispose);
    await pumpApp(
      tester,
      ValueListenableBuilder<ExpandedEmptyBehavior>(
        valueListenable: behavior,
        builder: (context, b, _) => _layout(behavior: b),
      ),
      size: expanded,
    );
    expect(find.text('empty state'), findsOneWidget);

    behavior.value = ExpandedEmptyBehavior.listOnly;
    await tester.pumpAndSettle();
    expect(find.text('empty state'), findsNothing);
    expect(tester.getSize(find.byKey(const Key('list'))).width, 1000);

    behavior.value = ExpandedEmptyBehavior.placeholder;
    await tester.pumpAndSettle();
    expect(find.text('empty state'), findsOneWidget);
  });
}
