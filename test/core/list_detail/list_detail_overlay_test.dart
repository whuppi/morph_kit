import 'package:adaptive_layouts/adaptive_layouts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Overlay-mode behavior: the detail renders in the ancestor Overlay so it
/// can cover siblings (bottom nav, tab bars), and paint-visibility
/// suppression hides it for inactive tab children.
void main() {
  Widget buildLayout({
    required ListDetailController<String> controller,
    String detailLabel = 'detail',
  }) {
    return ListDetailLayout<String>(
      controller: controller,
      compactDetailMode: CompactDetailMode.overlay,
      listBuilder: (context, selectedId, onSelect) => ColoredBox(
        key: Key('list-$detailLabel'),
        color: const Color(0xFF111111),
        child: Center(
          child: GestureDetector(
            key: Key('select-$detailLabel'),
            onTap: () => onSelect('a'),
            child: Text('select $detailLabel'),
          ),
        ),
      ),
      detailBuilder: (context, id, mode, onDismiss) => ColoredBox(
        key: Key('detail-$detailLabel'),
        color: const Color(0xFF333333),
        child: Center(child: Text('$detailLabel: $id (${mode.name})')),
      ),
      emptyStateBuilder: (_) => const Text('empty state'),
    );
  }

  const expanded = Size(1000, 800);
  const compact = Size(400, 800);

  testWidgets('compact detail covers siblings below the layout', (
    tester,
  ) async {
    final controller = ListDetailController<String>();
    await pumpApp(
      tester,
      Column(
        children: [
          Expanded(child: buildLayout(controller: controller)),
          const SizedBox(
            key: Key('bottom-bar'),
            height: 80,
            width: double.infinity,
          ),
        ],
      ),
      size: compact,
    );

    await tester.tap(find.byKey(const Key('select-detail')));
    await tester.pumpAndSettle();

    // The detail renders in the app-level Overlay — full window, on top of
    // the 80px bottom bar the layout does not own.
    final rect = tester.getRect(find.byKey(const Key('detail-detail')));
    expect(rect, const Rect.fromLTWH(0, 0, 400, 800));
  });

  testWidgets('expanded renders the detail inline exactly once', (
    tester,
  ) async {
    final controller = ListDetailController<String>();
    await pumpApp(tester, buildLayout(controller: controller), size: expanded);

    await tester.tap(find.byKey(const Key('select-detail')));
    await tester.pumpAndSettle();

    expect(find.text('detail: a (sideBySide)'), findsOneWidget);
    // Inline pane, not a full-window overlay.
    final rect = tester.getRect(find.byKey(const Key('detail-detail')));
    expect(rect.width, lessThan(1000));
  });

  testWidgets(
    'expanded → compact with an open selection shows the overlay instantly',
    (tester) async {
      final controller = ListDetailController<String>();
      await pumpApp(
        tester,
        buildLayout(controller: controller),
        size: expanded,
      );
      await tester.tap(find.byKey(const Key('select-detail')));
      await tester.pumpAndSettle();

      await resizeWindow(tester, compact);

      // No re-animation gap — the detail is already fully open.
      expect(find.text('detail: a (stacked)'), findsOneWidget);
      final rect = tester.getRect(find.byKey(const Key('detail-detail')));
      expect(rect.width, 400);
    },
  );

  testWidgets(
    'inactive tab children suppress their overlays (paint visibility)',
    (tester) async {
      final controllerA = ListDetailController<String>();
      final controllerB = ListDetailController<String>();
      late StateSetter setOuterState;
      var activeIndex = 0;

      await pumpApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            setOuterState = setState;
            return IndexedStack(
              index: activeIndex,
              children: [
                buildLayout(controller: controllerA, detailLabel: 'A'),
                buildLayout(controller: controllerB, detailLabel: 'B'),
              ],
            );
          },
        ),
        size: compact,
      );

      // Open a detail in tab A.
      await tester.tap(find.byKey(const Key('select-A')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-A')), findsOneWidget);

      // Switch to tab B. Tab A stays mounted, but its paint stops — the
      // overlay must not linger over tab B. (Suppression needs a build pass
      // of the inactive child, which real tab switches produce.)
      setOuterState(() => activeIndex = 1);
      await tester.pumpAndSettle();
      setOuterState(() {});
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('detail-A')), findsNothing);
      expect(find.text('select B'), findsOneWidget);

      // Switch back — the overlay reappears (one-frame re-show lag).
      setOuterState(() => activeIndex = 0);
      await tester.pumpAndSettle();
      setOuterState(() {});
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('detail-A')), findsOneWidget);
    },
  );
}
