import 'package:adaptive_layouts/adaptive_layouts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

void main() {
  Widget buildSplit({
    SplitPrimaryPosition primaryPosition = SplitPrimaryPosition.start,
    SplitCompactBehavior compactBehavior = SplitCompactBehavior.stack,
    PaneConfig paneConfig = const PaneConfig(),
    DividerBuilder? dividerBuilder,
  }) {
    return AdaptiveSplit(
      primaryPosition: primaryPosition,
      compactBehavior: compactBehavior,
      paneConfig: paneConfig,
      dividerBuilder: dividerBuilder,
      primaryBuilder: (context, isExpanded) => ColoredBox(
        key: const Key('primary'),
        color: const Color(0xFF111111),
        child: Center(child: Text('primary ${isExpanded ? 'exp' : 'cmp'}')),
      ),
      secondaryBuilder: (context, isExpanded) => const ColoredBox(
        key: Key('secondary'),
        color: Color(0xFF333333),
        child: CounterPane(),
      ),
    );
  }

  const expanded = Size(1000, 800);
  const compact = Size(400, 800);

  group('expanded layout', () {
    testWidgets('panes sit side-by-side; primary at defaultListWidth ratio', (
      tester,
    ) async {
      await pumpApp(tester, buildSplit(), size: expanded);

      // ratio 360/720 = 0.5 → 500 at 1000px.
      final primary = tester.getRect(find.byKey(const Key('primary')));
      final secondary = tester.getRect(find.byKey(const Key('secondary')));
      expect(primary.width, 500);
      expect(primary.left, 0);
      expect(secondary.left, 500);
      expect(find.text('primary exp'), findsOneWidget);
    });

    testWidgets('widthMemory.resetOnReentry forgets the drag on re-entry', (
      tester,
    ) async {
      await pumpApp(
        tester,
        buildSplit(
          paneConfig: const PaneConfig(
            widthMemory: PaneWidthMemory.resetOnReentry,
          ),
        ),
        size: expanded,
      );
      final before = tester.getRect(find.byKey(const Key('primary'))).width;
      await tester.dragFrom(Offset(before, 400), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const Key('primary'))).width,
        isNot(before),
      );

      await resizeWindow(tester, compact);
      await resizeWindow(tester, expanded);

      expect(tester.getRect(find.byKey(const Key('primary'))).width, before);
    });

    testWidgets('divider drag resizes the primary pane', (tester) async {
      await pumpApp(tester, buildSplit(), size: expanded);
      final before = tester.getRect(find.byKey(const Key('primary'))).width;

      await tester.dragFrom(Offset(before, 400), const Offset(-100, 0));
      await tester.pumpAndSettle();

      // Tolerance covers gesture touch slop.
      expect(
        tester.getRect(find.byKey(const Key('primary'))).width,
        closeTo(before - 100, 30),
      );
    });

    testWidgets('primaryPosition.end mirrors the panes and drag direction', (
      tester,
    ) async {
      await pumpApp(
        tester,
        buildSplit(primaryPosition: SplitPrimaryPosition.end),
        size: expanded,
      );

      final primary = tester.getRect(find.byKey(const Key('primary')));
      final secondary = tester.getRect(find.byKey(const Key('secondary')));
      expect(secondary.left, 0);
      expect(primary.left, 500);

      // Dragging RIGHT shrinks an end-positioned primary (inverted from a
      // start-positioned one, where dragging right grows it).
      await tester.dragFrom(const Offset(500, 400), const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const Key('primary'))).width,
        closeTo(400, 30),
      );
    });

    testWidgets('null dividerBuilder still leaves a working drag zone', (
      tester,
    ) async {
      await pumpApp(tester, buildSplit(dividerBuilder: null), size: expanded);
      final before = tester.getRect(find.byKey(const Key('primary'))).width;

      await tester.dragFrom(Offset(before, 400), const Offset(-80, 0));
      await tester.pumpAndSettle();

      // Tolerance covers gesture touch slop.
      expect(
        tester.getRect(find.byKey(const Key('primary'))).width,
        closeTo(before - 80, 30),
      );
    });

    testWidgets('divider settles to the nearest anchor after a drag', (
      tester,
    ) async {
      await pumpApp(
        tester,
        buildSplit(
          paneConfig: const PaneConfig(
            minListWidth: 100,
            maxListRatio: 0.9,
            anchors: [PaneAnchor.fromStart(240), PaneAnchor.fromStart(500)],
            initialAnchorIndex: 0,
          ),
        ),
        size: expanded,
      );
      expect(tester.getRect(find.byKey(const Key('primary'))).width, 240);

      await tester.dragFrom(const Offset(240, 400), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byKey(const Key('primary'))).width, 500);
    });
  });

  group('directional collapse (primary at end)', () {
    testWidgets('collapsing the directional end pane collapses the primary', (
      tester,
    ) async {
      await pumpApp(
        tester,
        buildSplit(
          primaryPosition: SplitPrimaryPosition.end,
          paneConfig: const PaneConfig(collapsible: PaneCollapsible.end),
        ),
        size: expanded,
      );
      // Primary sits at the directional end at the model width.
      final before = tester.getSize(find.byKey(const Key('primary'))).width;

      // Enter on the focused divider collapses the allowed (end) side —
      // which IS the primary here, despite being model-space start.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(
        tester.getSize(find.byKey(const Key('primary'))).width,
        const PaneConfig().minListWidth,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tester.getSize(find.byKey(const Key('primary'))).width, before);
    });

    testWidgets('DividerState reports the collapsed side directionally', (
      tester,
    ) async {
      final states = <DividerState>[];
      await pumpApp(
        tester,
        buildSplit(
          primaryPosition: SplitPrimaryPosition.end,
          paneConfig: const PaneConfig(collapsible: PaneCollapsible.end),
          dividerBuilder: (context, state) {
            states.add(state);
            return const SizedBox.expand();
          },
        ),
        size: expanded,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      // The model collapsed its start (the primary), but consumers see
      // the DIRECTIONAL side: end.
      expect(states.last.collapsed, PaneSide.end);
    });

    testWidgets('PaneScope actions speak directional sides', (tester) async {
      await pumpApp(
        tester,
        AdaptiveSplit(
          primaryPosition: SplitPrimaryPosition.end,
          paneConfig: const PaneConfig(collapsible: PaneCollapsible.end),
          primaryBuilder: (context, isExpanded) =>
              const ColoredBox(key: Key('primary'), color: Color(0xFF111111)),
          secondaryBuilder: (context, isExpanded) => Center(
            child: Builder(
              builder: (context) {
                final scope = PaneScope.of(context);
                return IconButton(
                  key: const Key('toggle'),
                  icon: const Icon(Icons.menu),
                  onPressed: scope.collapsed == null
                      ? () => scope.collapse(PaneSide.end)
                      : scope.restore,
                );
              },
            ),
          ),
        ),
        size: expanded,
      );
      final before = tester.getSize(find.byKey(const Key('primary'))).width;

      await tester.tap(find.byKey(const Key('toggle')));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('primary'))).width,
        const PaneConfig().minListWidth,
      );

      await tester.tap(find.byKey(const Key('toggle')));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('primary'))).width, before);
    });
  });

  group('compact layout', () {
    testWidgets('stack behavior shows both panes vertically', (tester) async {
      await pumpApp(tester, buildSplit(), size: compact);

      final primary = tester.getRect(find.byKey(const Key('primary')));
      final secondary = tester.getRect(find.byKey(const Key('secondary')));
      expect(find.text('primary cmp'), findsOneWidget);
      expect(primary.top, 0);
      expect(secondary.top, primary.bottom);
      expect(primary.width, 400);
    });

    testWidgets('hidden behavior drops the secondary pane', (tester) async {
      await pumpApp(
        tester,
        buildSplit(compactBehavior: SplitCompactBehavior.hidden),
        size: compact,
      );

      expect(find.byKey(const Key('primary')), findsOneWidget);
      expect(find.byKey(const Key('secondary')), findsNothing);
    });
  });

  group('resize across the breakpoint', () {
    testWidgets('pane widget state survives compact ↔ expanded', (
      tester,
    ) async {
      await pumpApp(tester, buildSplit(), size: expanded);

      await tester.tap(find.text('count: 0'));
      await tester.pump();
      expect(find.text('count: 1'), findsOneWidget);

      await resizeWindow(tester, compact);
      expect(find.text('count: 1'), findsOneWidget);

      await resizeWindow(tester, expanded);
      expect(find.text('count: 1'), findsOneWidget);
    });
  });
}
