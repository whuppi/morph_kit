import 'package:adaptive_layouts/adaptive_layouts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

Widget _layout(CompactDetailMode mode) {
  return Material(
    child: ListDetailLayout<String>(
      compactDetailMode: mode,
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
            const Expanded(child: CounterPane()),
          ],
        ),
      ),
      emptyStateBuilder: (context) => const Text('empty'),
    ),
  );
}

final _stacked = find.text('detail-a (stacked)');
final _sideBySide = find.text('detail-a (sideBySide)');

/// A crossing delivered as many small per-frame deltas — a window drag.
/// The panes must animate their re-arrangement at the threshold exactly
/// like they do for a one-frame jump; only the tracking of pane geometry
/// within an arrangement follows the hand without motion.
Future<void> _draggedResize(WidgetTester tester, double from, double to) async {
  var width = from;
  while (width != to) {
    width = from > to
        ? (width - 30).clamp(to, from)
        : (width + 30).clamp(from, to);
    tester.view.physicalSize = Size(width, 800);
    await tester.pump();
  }
}

void main() {
  for (final mode in [CompactDetailMode.inline, CompactDetailMode.overlay]) {
    for (final (label, cross) in [
      (
        'one-frame jump',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(500, 800);
          await tester.pump();
        },
      ),
      (
        'window drag',
        (WidgetTester tester) => _draggedResize(tester, 1000, 700),
      ),
    ]) {
      testWidgets('${mode.name}: $label grows the detail out of its pane', (
        tester,
      ) async {
        await pumpApp(tester, _layout(mode), size: const Size(1000, 800));
        await tester.tap(find.text('item-a'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CounterPane));
        await tester.tap(find.byType(CounterPane));
        await tester.pump();

        await cross(tester);
        await tester.pump(const Duration(milliseconds: 40));

        final midMorph = tester.getTopLeft(_stacked).dx;
        await tester.pumpAndSettle();
        final settled = tester.getTopLeft(_stacked).dx;

        expect(midMorph, greaterThan(settled)); // slid in from the pane edge
        expect(find.text('count: 2'), findsOneWidget); // state rode the morph
      });
    }

    testWidgets('${mode.name}: crossing into expanded slides the list in', (
      tester,
    ) async {
      await pumpApp(tester, _layout(mode), size: const Size(500, 800));
      await tester.tap(find.text('item-a'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CounterPane));
      await tester.tap(find.byType(CounterPane));
      await tester.pump();

      tester.view.physicalSize = const Size(1000, 800);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      // Mid-entry the detail is wider than its final pane: its leading
      // edge sits closer to the window edge than the settled divider.
      final midEntry = tester.getTopLeft(_sideBySide).dx;
      await tester.pumpAndSettle();
      final settled = tester.getTopLeft(_sideBySide).dx;

      expect(midEntry, lessThan(settled));
      expect(find.text('count: 2'), findsOneWidget);
    });
  }

  for (final (label, cross) in [
    (
      'one-frame jump',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(500, 800);
        await tester.pump();
      },
    ),
    ('window drag', (WidgetTester tester) => _draggedResize(tester, 1000, 700)),
  ]) {
    testWidgets('route: $label plays the real route entrance', (tester) async {
      await pumpApp(
        tester,
        _layout(CompactDetailMode.route),
        size: const Size(1000, 800),
      );
      await tester.tap(find.text('item-a'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CounterPane));
      await tester.tap(find.byType(CounterPane));
      await tester.pump();

      await cross(tester); // crossing frame: list + offstage bridge
      await tester.pump(const Duration(milliseconds: 16)); // overlay inserts
      await tester.pump(const Duration(milliseconds: 16)); // route content live

      // Entrance under way — and the LIST sits beneath it, not the bridge.
      expect(find.text('item-a'), findsOneWidget);
      final route = ModalRoute.of(tester.element(_stacked))!;
      expect(route.animation!.status, AnimationStatus.forward);

      await tester.pumpAndSettle();
      expect(route.animation!.status, AnimationStatus.completed);
      expect(find.text('count: 2'), findsOneWidget);
    });
  }

  for (final (style, expectation) in [
    (ExpandedEntryStyle.reveal, 'final width throughout — no reflow'),
    (ExpandedEntryStyle.resize, 'growing widths — reflows as it arrives'),
  ]) {
    testWidgets('${style.name} entry gives the list $expectation', (
      tester,
    ) async {
      final widths = <double>[];
      await pumpApp(
        tester,
        Material(
          child: ListDetailLayout<String>(
            paneConfig: PaneConfig(entryStyle: style),
            listBuilder: (context, selectedId, onSelect) => LayoutBuilder(
              builder: (context, constraints) {
                widths.add(constraints.maxWidth);
                return TextButton(
                  onPressed: () => onSelect('a'),
                  child: const Text('item-a'),
                );
              },
            ),
            detailBuilder: (context, id, mode, onDismiss) =>
                Text('detail-$id (${mode.name})'),
            emptyStateBuilder: (context) => const Text('empty'),
          ),
        ),
        size: const Size(500, 800),
      );
      await tester.tap(find.text('item-a'));
      await tester.pumpAndSettle();

      widths.clear();
      tester.view.physicalSize = const Size(1000, 800);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();

      final finalWidth = widths.last;
      final reflowed = widths.any((w) => w < finalWidth - 0.01);
      expect(reflowed, style == ExpandedEntryStyle.resize);
    });
  }

  testWidgets('route: crossing into expanded slides the list in seamlessly', (
    tester,
  ) async {
    await pumpApp(
      tester,
      _layout(CompactDetailMode.route),
      size: const Size(500, 800),
    );
    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CounterPane));
    await tester.tap(find.byType(CounterPane));
    await tester.pump();

    tester.view.physicalSize = const Size(1000, 800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    final midEntry = tester.getTopLeft(_sideBySide).dx;
    await tester.pumpAndSettle();
    final settled = tester.getTopLeft(_sideBySide).dx;

    expect(midEntry, lessThan(settled));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse); // the route is gone
    expect(find.text('count: 2'), findsOneWidget);
  });
}
