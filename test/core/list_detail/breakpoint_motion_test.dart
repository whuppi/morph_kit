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

final _detail = find.text('detail-a (stacked)');

/// A crossing delivered as many small per-frame deltas — a window drag.
Future<void> _continuousResize(
  WidgetTester tester,
  double from,
  double to,
) async {
  var width = from;
  while (width > to) {
    width = (width - 30).clamp(to, from);
    tester.view.physicalSize = Size(width, 800);
    await tester.pump();
  }
}

void main() {
  for (final mode in [CompactDetailMode.inline, CompactDetailMode.overlay]) {
    testWidgets(
      '${mode.name}: discrete jump grows the detail out of its pane',
      (tester) async {
        await pumpApp(tester, _layout(mode), size: const Size(1000, 800));
        await tester.tap(find.text('item-a'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CounterPane));
        await tester.tap(find.byType(CounterPane));
        await tester.pump();

        // One-frame jump across the breakpoint (fold / rotation shape).
        tester.view.physicalSize = const Size(500, 800);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));

        final midMorph = tester.getTopLeft(_detail).dx;
        await tester.pumpAndSettle();
        final settled = tester.getTopLeft(_detail).dx;

        expect(midMorph, greaterThan(settled)); // it slid in from the pane edge
        expect(find.text('count: 2'), findsOneWidget); // state rode the morph
      },
    );

    testWidgets('${mode.name}: continuous drag across the breakpoint cuts', (
      tester,
    ) async {
      await pumpApp(tester, _layout(mode), size: const Size(1000, 800));
      await tester.tap(find.text('item-a'));
      await tester.pumpAndSettle();

      await _continuousResize(tester, 1000, 700);

      // No entrance animation is running — the detail is simply there.
      expect(tester.hasRunningAnimations, isFalse);
      final immediate = tester.getTopLeft(_detail).dx;
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_detail).dx, immediate);
    });
  }

  testWidgets('route: discrete jump plays the real route entrance', (
    tester,
  ) async {
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

    tester.view.physicalSize = const Size(500, 800);
    await tester.pump(); // crossing frame: list + offstage bridge, push queued
    await tester.pump(const Duration(milliseconds: 16)); // overlay inserts
    await tester.pump(const Duration(milliseconds: 16)); // route content live

    // Entrance under way — and the LIST sits beneath it, not the bridge.
    expect(find.text('item-a'), findsOneWidget);
    final route = ModalRoute.of(tester.element(_detail))!;
    expect(route.animation!.status, AnimationStatus.forward);

    await tester.pumpAndSettle();
    expect(route.animation!.status, AnimationStatus.completed);
    expect(find.text('count: 2'), findsOneWidget);
  });

  testWidgets('route: continuous drag across the breakpoint pushes instantly', (
    tester,
  ) async {
    await pumpApp(
      tester,
      _layout(CompactDetailMode.route),
      size: const Size(1000, 800),
    );
    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();

    await _continuousResize(tester, 1000, 700);
    await tester.pump();

    final route = ModalRoute.of(tester.element(_detail))!;
    expect(route.animation!.status, AnimationStatus.completed);
  });
}
