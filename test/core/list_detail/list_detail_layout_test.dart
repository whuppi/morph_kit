import 'package:adaptive_layouts/adaptive_layouts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Inline-mode behavior: pane morphing, animations, gestures, divider.
/// Overlay-mode behavior lives in list_detail_overlay_test.dart.
void main() {
  Widget buildLayout({
    ListDetailController<String>? controller,
    PaneConfig paneConfig = const PaneConfig(),
    CompactConfig compactConfig = const CompactConfig(),
    DividerBuilder? dividerBuilder,
  }) {
    return ListDetailLayout<String>(
      controller: controller,
      paneConfig: paneConfig,
      compactConfig: compactConfig,
      dividerBuilder: dividerBuilder,
      listBuilder: (context, selectedId, onSelect) => ColoredBox(
        key: const Key('list'),
        color: const Color(0xFF111111),
        child: Center(
          child: GestureDetector(
            key: const Key('select-a'),
            onTap: () => onSelect('a'),
            child: const Text('select a'),
          ),
        ),
      ),
      detailBuilder: (context, id, mode, onDismiss) => ColoredBox(
        key: const Key('detail'),
        color: const Color(0xFF333333),
        child: Column(
          children: [
            Text('detail: $id'),
            Text('mode: ${mode.name}'),
            IconButton(
              key: const Key('dismiss'),
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
            ),
            const Expanded(child: CounterPane()),
          ],
        ),
      ),
      emptyStateBuilder: (_) => const Text('empty state'),
    );
  }

  const expanded = Size(1000, 800);
  const compact = Size(400, 800);

  group('expanded layout', () {
    testWidgets('shows list and empty state when nothing is selected', (
      tester,
    ) async {
      await pumpApp(tester, buildLayout(), size: expanded);

      expect(find.byKey(const Key('list')), findsOneWidget);
      expect(find.text('empty state'), findsOneWidget);
      expect(find.byKey(const Key('detail')), findsNothing);
    });

    testWidgets('select opens side-by-side detail; dismiss closes it', (
      tester,
    ) async {
      await pumpApp(tester, buildLayout(), size: expanded);

      await tester.tap(find.byKey(const Key('select-a')));
      await tester.pumpAndSettle();

      expect(find.text('detail: a'), findsOneWidget);
      expect(find.text('mode: sideBySide'), findsOneWidget);
      expect(find.text('empty state'), findsNothing);
      // Both panes visible at once.
      expect(find.byKey(const Key('list')), findsOneWidget);

      await tester.tap(find.byKey(const Key('dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail')), findsNothing);
      expect(find.text('empty state'), findsOneWidget);
    });

    testWidgets('list starts at defaultListWidth scaled from the breakpoint', (
      tester,
    ) async {
      await pumpApp(
        tester,
        buildLayout(paneConfig: const PaneConfig(defaultListWidth: 360)),
        size: expanded,
      );
      // ratio 360/720 = 0.5 → 500 at 1000px (maxListRatio caps at 0.5 too).
      expect(tester.getSize(find.byKey(const Key('list'))).width, 500);
    });

    testWidgets('divider drag resizes the list within clamps', (tester) async {
      await pumpApp(tester, buildLayout(), size: expanded);
      final before = tester.getSize(find.byKey(const Key('list'))).width;

      await tester.dragFrom(Offset(before, 400), const Offset(-100, 0));
      await tester.pumpAndSettle();
      // Tolerance covers gesture touch slop.
      expect(
        tester.getSize(find.byKey(const Key('list'))).width,
        closeTo(before - 100, 30),
      );

      // Dragging far past maxListRatio clamps.
      await tester.dragFrom(Offset(before - 100, 400), const Offset(900, 0));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('list'))).width,
        1000 * const PaneConfig().maxListRatio,
      );
    });

    testWidgets(
      'divider position survives compact spells and equal-value config '
      'rebuilds',
      (tester) async {
        // Non-const configs: the inline-construction shape every app has.
        await pumpApp(
          tester,
          buildLayout(paneConfig: PaneConfig()),
          size: expanded,
        );
        final before = tester.getSize(find.byKey(const Key('list'))).width;
        await tester.dragFrom(Offset(before, 400), const Offset(-100, 0));
        await tester.pumpAndSettle();
        final dragged = tester.getSize(find.byKey(const Key('list'))).width;
        expect(dragged, isNot(before));

        // Rebuild with a NEW but value-equal config instance — must NOT
        // reset the width model (identity comparison did).
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.ltr,
              child: buildLayout(paneConfig: PaneConfig()),
            ),
          ),
        );
        await resizeWindow(tester, compact);
        await resizeWindow(tester, expanded);

        expect(
          tester.getSize(find.byKey(const Key('list'))).width,
          closeTo(dragged, 1),
        );
      },
    );

    testWidgets('settle knobs: custom duration and curve are honored', (
      tester,
    ) async {
      await pumpApp(
        tester,
        buildLayout(
          paneConfig: const PaneConfig(
            minListWidth: 100,
            maxListRatio: 0.9,
            anchors: [PaneAnchor.fromStart(240), PaneAnchor.fromStart(500)],
            initialAnchorIndex: 0,
            settleDuration: Duration(seconds: 1),
          ),
        ),
        size: expanded,
      );

      await tester.dragFrom(const Offset(240, 400), const Offset(200, 0));
      await tester.pump(const Duration(milliseconds: 400));
      // Default 220ms settle would already be done — the 1s one is not.
      final mid = tester.getSize(find.byKey(const Key('list'))).width;
      expect(mid, isNot(500));

      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('list'))).width, 500);
    });

    testWidgets('dividerHitWidth: a wide zone accepts far-off drags', (
      tester,
    ) async {
      await pumpApp(
        tester,
        buildLayout(paneConfig: const PaneConfig(dividerHitWidth: 120)),
        size: expanded,
      );
      final before = tester.getSize(find.byKey(const Key('list'))).width;

      // 50px from the border — outside the default 24px zone.
      await tester.dragFrom(Offset(before - 50, 400), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('list'))).width,
        lessThan(before),
      );
    });

    testWidgets('widthMemory.resetOnReentry forgets the drag on re-entry', (
      tester,
    ) async {
      await pumpApp(
        tester,
        buildLayout(
          paneConfig: const PaneConfig(
            widthMemory: PaneWidthMemory.resetOnReentry,
          ),
        ),
        size: expanded,
      );
      final before = tester.getSize(find.byKey(const Key('list'))).width;
      await tester.dragFrom(Offset(before, 400), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('list'))).width,
        isNot(before),
      );

      await resizeWindow(tester, compact);
      await resizeWindow(tester, expanded);

      // Fresh divider: back to the default width, drag forgotten.
      expect(tester.getSize(find.byKey(const Key('list'))).width, before);
    });

    testWidgets('divider settles to the nearest anchor after a drag', (
      tester,
    ) async {
      final settleSeen = <bool>[];
      await pumpApp(
        tester,
        buildLayout(
          paneConfig: const PaneConfig(
            minListWidth: 100,
            maxListRatio: 0.9,
            anchors: [PaneAnchor.fromStart(240), PaneAnchor.fromStart(500)],
            initialAnchorIndex: 0,
          ),
          dividerBuilder: (context, isDragging, isSettling) {
            settleSeen.add(isSettling);
            return const SizedBox();
          },
        ),
        size: expanded,
      );
      expect(tester.getSize(find.byKey(const Key('list'))).width, 240);

      // Drag towards the second anchor and release just past the midpoint.
      await tester.dragFrom(const Offset(240, 400), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byKey(const Key('list'))).width, 500);
      expect(settleSeen, contains(true));
    });
  });

  group('compact layout', () {
    testWidgets('select slides the detail over the list (stacked mode)', (
      tester,
    ) async {
      await pumpApp(tester, buildLayout(), size: compact);
      expect(find.byKey(const Key('detail')), findsNothing);

      await tester.tap(find.byKey(const Key('select-a')));
      await tester.pumpAndSettle();

      expect(find.text('mode: stacked'), findsOneWidget);
      // Detail covers the full layout width.
      expect(tester.getSize(find.byKey(const Key('detail'))).width, 400);
    });

    testWidgets('dismiss keeps the detail in the tree while animating out', (
      tester,
    ) async {
      final controller = ListDetailController<String>();
      await pumpApp(tester, buildLayout(controller: controller), size: compact);
      await tester.tap(find.byKey(const Key('select-a')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dismiss')));
      await tester.pump(const Duration(milliseconds: 100));

      // Mid-exit-animation: selection cleared, widget still in the tree.
      expect(controller.hasSelection, isFalse);
      expect(controller.isDetailVisible, isTrue);
      expect(find.byKey(const Key('detail')), findsOneWidget);

      await tester.pumpAndSettle();
      expect(controller.isDetailVisible, isFalse);
      expect(find.byKey(const Key('detail')), findsNothing);
    });

    testWidgets('external controller.dismiss() also animates out cleanly', (
      tester,
    ) async {
      final controller = ListDetailController<String>();
      await pumpApp(tester, buildLayout(controller: controller), size: compact);
      controller.select('a');
      await tester.pumpAndSettle();
      expect(find.text('detail: a'), findsOneWidget);

      controller.dismiss();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('detail')), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail')), findsNothing);
    });

    testWidgets('initial selection shows the detail without animation', (
      tester,
    ) async {
      final controller = ListDetailController<String>(initialSelection: 'a');
      await pumpApp(tester, buildLayout(controller: controller), size: compact);
      // First frame, no settling needed.
      expect(find.text('detail: a'), findsOneWidget);
    });

    testWidgets('back gesture dismisses the detail', (tester) async {
      await pumpApp(tester, buildLayout(), size: compact);
      await tester.tap(find.byKey(const Key('select-a')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail')), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail')), findsNothing);
    });

    testWidgets(
      'swipe past the threshold dismisses; a short swipe snaps back',
      (tester) async {
        await pumpApp(tester, buildLayout(), size: compact);
        await tester.tap(find.byKey(const Key('select-a')));
        await tester.pumpAndSettle();

        // Short swipe (< 0.3 * 400 = 120) — snaps back.
        await tester.drag(find.byKey(const Key('detail')), const Offset(50, 0));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('detail')), findsOneWidget);

        // Long swipe — dismisses.
        await tester.drag(
          find.byKey(const Key('detail')),
          const Offset(300, 0),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('detail')), findsNothing);
      },
    );

    testWidgets('works under RTL', (tester) async {
      await pumpApp(
        tester,
        buildLayout(),
        size: compact,
        textDirection: TextDirection.rtl,
      );
      await tester.tap(find.byKey(const Key('select-a')));
      await tester.pumpAndSettle();
      expect(find.text('detail: a'), findsOneWidget);

      await tester.tap(find.byKey(const Key('dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail')), findsNothing);
    });
  });

  group('resize across the breakpoint', () {
    testWidgets('detail widget state survives compact ↔ expanded', (
      tester,
    ) async {
      await pumpApp(tester, buildLayout(), size: expanded);
      await tester.tap(find.byKey(const Key('select-a')));
      await tester.pumpAndSettle();

      // Mutate detail-local state.
      await tester.tap(find.text('count: 0'));
      await tester.pump();
      await tester.tap(find.text('count: 1'));
      await tester.pump();
      expect(find.text('count: 2'), findsOneWidget);

      await resizeWindow(tester, compact);
      expect(find.text('mode: stacked'), findsOneWidget);
      expect(find.text('count: 2'), findsOneWidget);

      await resizeWindow(tester, expanded);
      expect(find.text('mode: sideBySide'), findsOneWidget);
      expect(find.text('count: 2'), findsOneWidget);
    });
  });
}
