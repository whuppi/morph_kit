import 'package:morph_kit/morph_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Stage 1b divider interactivity: keyboard resizing, Enter collapse,
/// Home/End jumps, double-click reset, PaneScope actions, and the
/// screen-reader value contract. The WAI-ARIA window-splitter pattern.
void main() {
  Widget buildLayout({
    PaneConfig paneConfig = const PaneConfig(),
    DividerBuilder? dividerBuilder,
    Widget Function(BuildContext context)? detailExtra,
  }) {
    return ListDetailLayout<String>(
      controller: ListDetailController<String>(initialSelection: 'a'),
      paneConfig: paneConfig,
      dividerBuilder: dividerBuilder,
      listBuilder: (context, selectedId, onSelect) =>
          const ColoredBox(key: Key('list'), color: Color(0xFF111111)),
      detailBuilder: (context, id, mode, onDismiss) => ColoredBox(
        key: const Key('detail'),
        color: const Color(0xFF333333),
        child: detailExtra?.call(context) ?? const SizedBox(),
      ),
    );
  }

  const expanded = Size(1000, 800);
  double listWidth(WidgetTester tester) =>
      tester.getSize(find.byKey(const Key('list'))).width;

  Future<void> focusDivider(WidgetTester tester) async {
    // Test content has no other focusables — one Tab lands on the divider.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }

  group('keyboard', () {
    testWidgets('Tab focuses the divider; DividerState reports it', (
      tester,
    ) async {
      final states = <DividerState>[];
      await pumpApp(
        tester,
        buildLayout(
          dividerBuilder: (context, state) {
            states.add(state);
            return const SizedBox.expand();
          },
        ),
        size: expanded,
      );
      expect(states.last.isFocused, isFalse);

      await focusDivider(tester);
      expect(states.last.isFocused, isTrue);
    });

    testWidgets('arrow keys resize by the keyboard step', (tester) async {
      // Pixel mode, mid-range start: the ratio default sits exactly at the
      // maxListRatio cap, where growing would clamp to a no-op.
      await pumpApp(
        tester,
        buildLayout(
          paneConfig: const PaneConfig(
            defaultListWidth: 300,
            resizeMode: PaneResizeMode.pixels,
          ),
        ),
        size: expanded,
      );
      final before = listWidth(tester);
      expect(before, 300);

      await focusDivider(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(listWidth(tester), before + PaneDividerRegion.keyboardStep);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(listWidth(tester), before - PaneDividerRegion.keyboardStep);
    });

    testWidgets('Enter collapses the allowed side and restores', (
      tester,
    ) async {
      await pumpApp(
        tester,
        buildLayout(
          paneConfig: const PaneConfig(collapsible: PaneCollapsible.start),
        ),
        size: expanded,
      );
      final before = listWidth(tester);

      await focusDivider(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      // Collapsed slot is zero-wide; content stays laid out at minimum
      // inside the clip.
      expect(listWidth(tester), const PaneConfig().minListWidth);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(listWidth(tester), before);
    });

    testWidgets('Enter is a no-op when collapse is disallowed', (tester) async {
      await pumpApp(tester, buildLayout(), size: expanded);
      final before = listWidth(tester);

      await focusDivider(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(listWidth(tester), before);
    });

    testWidgets('Home and End settle to the pane limits', (tester) async {
      await pumpApp(tester, buildLayout(), size: expanded);

      await focusDivider(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(listWidth(tester), const PaneConfig().minListWidth);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(listWidth(tester), 1000 * const PaneConfig().maxListRatio);
    });
  });

  group('double-click reset', () {
    testWidgets('returns a dragged divider to the default width', (
      tester,
    ) async {
      await pumpApp(tester, buildLayout(), size: expanded);
      final defaultWidth = listWidth(tester);

      await tester.dragFrom(Offset(defaultWidth, 400), const Offset(-150, 0));
      await tester.pumpAndSettle();
      final dragged = listWidth(tester);
      expect(dragged, lessThan(defaultWidth));

      final dividerCenter = Offset(dragged, 400);
      await tester.tapAt(dividerCenter);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(dividerCenter);
      await tester.pumpAndSettle();
      expect(listWidth(tester), defaultWidth);
    });

    testWidgets('restores a collapsed pane', (tester) async {
      await pumpApp(
        tester,
        buildLayout(
          paneConfig: const PaneConfig(collapsible: PaneCollapsible.start),
        ),
        size: expanded,
      );
      final before = listWidth(tester);

      // Force-drag past the collapse threshold.
      await tester.dragFrom(Offset(before, 400), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(listWidth(tester), const PaneConfig().minListWidth);

      // Double-click the parked divider (at the start edge).
      const parked = Offset(6, 400);
      await tester.tapAt(parked);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(parked);
      await tester.pumpAndSettle();
      expect(listWidth(tester), before);
    });
  });

  group('PaneScope', () {
    testWidgets('detail pane sees the collapse and restores via action', (
      tester,
    ) async {
      await pumpApp(
        tester,
        buildLayout(
          paneConfig: const PaneConfig(collapsible: PaneCollapsible.start),
          detailExtra: (context) {
            final scope = PaneScope.of(context);
            if (scope.collapsed != PaneSide.start) return const SizedBox();
            return IconButton(
              key: const Key('hamburger'),
              icon: const Icon(Icons.menu),
              onPressed: scope.restore,
            );
          },
        ),
        size: expanded,
      );
      final before = listWidth(tester);
      expect(find.byKey(const Key('hamburger')), findsNothing);

      await tester.dragFrom(Offset(before, 400), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hamburger')), findsOneWidget);

      await tester.tap(find.byKey(const Key('hamburger')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hamburger')), findsNothing);
      expect(listWidth(tester), before);
    });

    testWidgets('collapse action snaps a pane closed programmatically', (
      tester,
    ) async {
      await pumpApp(
        tester,
        buildLayout(
          paneConfig: const PaneConfig(collapsible: PaneCollapsible.start),
          detailExtra: (context) => IconButton(
            key: const Key('collapse-list'),
            icon: const Icon(Icons.chevron_left),
            onPressed: () => PaneScope.of(context).collapse(PaneSide.start),
          ),
        ),
        size: expanded,
      );

      await tester.tap(find.byKey(const Key('collapse-list')));
      await tester.pumpAndSettle();
      expect(listWidth(tester), const PaneConfig().minListWidth);
    });

    testWidgets('collapse action refuses a disallowed side', (tester) async {
      await pumpApp(
        tester,
        buildLayout(
          detailExtra: (context) => IconButton(
            key: const Key('collapse-list'),
            icon: const Icon(Icons.chevron_left),
            onPressed: () => PaneScope.of(context).collapse(PaneSide.start),
          ),
        ),
        size: expanded,
      );
      final before = listWidth(tester);

      await tester.tap(find.byKey(const Key('collapse-list')));
      await tester.pumpAndSettle();
      expect(listWidth(tester), before);
    });
  });

  group('collapsed icon rail', () {
    Widget buildRailLayout() {
      return ListDetailLayout<String>(
        controller: ListDetailController<String>(initialSelection: 'a'),
        paneConfig: const PaneConfig(
          collapsible: PaneCollapsible.start,
          collapsedSize: 56,
        ),
        listBuilder: (context, selectedId, onSelect) =>
            const CounterPane(label: 'list'),
        detailBuilder: (context, id, mode, onDismiss) =>
            const ColoredBox(key: Key('detail'), color: Color(0xFF333333)),
        collapsedListBuilder: (context) {
          // The scope tells rail/pane content how collapsed "collapsed"
          // is — non-zero means this rail is the expand affordance.
          expect(PaneScope.of(context).collapsedSize, 56);
          return ColoredBox(
            key: const Key('rail'),
            color: const Color(0xFF444444),
            child: IconButton(
              key: const Key('rail-expand'),
              icon: const Icon(Icons.menu),
              onPressed: PaneScope.of(context).restore,
            ),
          );
        },
      );
    }

    testWidgets('rail lays out at the real slot width; list parks alive', (
      tester,
    ) async {
      await pumpApp(tester, buildRailLayout(), size: expanded);

      // Mutate list state, then collapse.
      await tester.tap(find.text('list: 0'));
      await tester.pump();

      await tester.dragFrom(const Offset(500, 400), const Offset(-600, 0));
      await tester.pumpAndSettle();

      // The rail owns the 56px slot — laid at 56, not clipped-at-minimum.
      expect(tester.getSize(find.byKey(const Key('rail'))).width, 56);
      // The list is parked offstage, still mounted.
      expect(find.text('list: 1', skipOffstage: false), findsOneWidget);
      expect(find.text('list: 1'), findsNothing);
    });

    testWidgets('rail restore brings the same list instance back', (
      tester,
    ) async {
      await pumpApp(tester, buildRailLayout(), size: expanded);
      await tester.tap(find.text('list: 0'));
      await tester.pump();
      final before = tester.getSize(find.text('list: 1')).width;
      expect(before, greaterThan(0));

      await tester.dragFrom(const Offset(500, 400), const Offset(-600, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('rail-expand')));
      await tester.pumpAndSettle();
      // Same live instance — the count survived the round trip.
      expect(find.text('list: 1'), findsOneWidget);
      expect(find.byKey(const Key('rail')), findsNothing);
    });

    testWidgets('empty placeholder collapses into the rail slot too', (
      tester,
    ) async {
      await pumpApp(
        tester,
        ListDetailLayout<String>(
          paneConfig: const PaneConfig(
            collapsible: PaneCollapsible.end,
            collapsedSize: 56,
          ),
          listBuilder: (context, selectedId, onSelect) =>
              const ColoredBox(key: Key('list'), color: Color(0xFF111111)),
          detailBuilder: (context, id, mode, onDismiss) =>
              const ColoredBox(color: Color(0xFF333333)),
          emptyStateBuilder: (_) => const Center(child: Text('pick one')),
          collapsedDetailBuilder: (context) =>
              const ColoredBox(key: Key('rail'), color: Color(0xFF444444)),
        ),
        size: expanded,
      );

      // Force-collapse the (empty) detail pane.
      await tester.dragFrom(const Offset(500, 400), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byKey(const Key('rail'))).width, 56);
      // The placeholder is parked offstage, not squished on screen.
      expect(find.text('pick one'), findsNothing);
      expect(find.text('pick one', skipOffstage: false), findsOneWidget);
    });

    testWidgets('collapsed empty pane survives a resize into compact', (
      tester,
    ) async {
      // Repro: both + 56px rail, collapse the empty detail, shrink the
      // window. The retreat renders expanded geometry at COMPACT width,
      // where the ratio ceiling drops below the min floor — the share
      // strings must not throw on inverted clamp bounds.
      Widget layout() => ListDetailLayout<String>(
        paneConfig: const PaneConfig(
          collapsible: PaneCollapsible.both,
          collapsedSize: 56,
        ),
        listBuilder: (context, selectedId, onSelect) =>
            const ColoredBox(key: Key('list'), color: Color(0xFF111111)),
        detailBuilder: (context, id, mode, onDismiss) =>
            const ColoredBox(color: Color(0xFF333333)),
        emptyStateBuilder: (_) => const Center(child: Text('pick one')),
        collapsedDetailBuilder: (context) =>
            const ColoredBox(key: Key('rail'), color: Color(0xFF444444)),
      );
      await pumpApp(tester, layout(), size: expanded);

      await tester.dragFrom(const Offset(500, 400), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rail')), findsOneWidget);

      await pumpApp(tester, layout(), size: const Size(390, 800));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const Key('list'))).width, 390);

      await pumpApp(tester, layout(), size: expanded);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('parked detail arrives docked — no detail-side morph', (
      tester,
    ) async {
      // Collapsed detail + selection, resize compact -> expanded: the
      // rail docks at the end edge at its parked width from frame one;
      // only the list plays its slide-in. The parked pane doesn't
      // replay a collapse it already did.
      Widget layout() => ListDetailLayout<String>(
        controller: ListDetailController<String>(initialSelection: 'a'),
        paneConfig: const PaneConfig(
          collapsible: PaneCollapsible.end,
          collapsedSize: 56,
        ),
        listBuilder: (context, selectedId, onSelect) =>
            const ColoredBox(key: Key('list'), color: Color(0xFF111111)),
        detailBuilder: (context, id, mode, onDismiss) =>
            const ColoredBox(key: Key('detail'), color: Color(0xFF333333)),
        collapsedDetailBuilder: (context) =>
            const ColoredBox(key: Key('rail'), color: Color(0xFF444444)),
      );
      await pumpApp(tester, layout(), size: expanded);
      await tester.dragFrom(const Offset(500, 400), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rail')), findsOneWidget);

      await pumpApp(tester, layout(), size: const Size(390, 800));
      await tester.pumpAndSettle();

      // Back to expanded — sample the crossing mid-flight.
      await pumpApp(tester, layout(), size: expanded);
      await tester.pump(const Duration(milliseconds: 100));
      final rail = find.byKey(const Key('rail'));
      expect(rail, findsOneWidget);
      expect(tester.getSize(rail).width, 56);
      expect(tester.getTopRight(rail).dx, 1000);
      // Mid-slide the list is still arriving: the reveal discipline
      // lays it at FINAL width clipped, end-aligned — so its leading
      // edge sits off-screen to the start while the slot grows.
      expect(tester.getTopLeft(find.byKey(const Key('list'))).dx, lessThan(0));

      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('list'))).width, 1000 - 56);
      expect(tester.getSize(rail).width, 56);
    });
  });

  group('semantics', () {
    testWidgets('divider is an adjustable element with a share value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, buildLayout(), size: expanded);

      final semantics = tester.getSemantics(
        find.bySemanticsLabel('Pane divider'),
      );
      expect(semantics.value, '50%');
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.increase),
        isTrue,
      );
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.decrease),
        isTrue,
      );
      handle.dispose();
    });
  });
}
