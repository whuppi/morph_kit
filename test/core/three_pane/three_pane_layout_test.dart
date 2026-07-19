import 'package:adaptive_layouts/adaptive_layouts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Role-priority partitioning, order decoupling, per-divider resizing,
/// and offstage state retention for ThreePaneLayout.
void main() {
  Widget buildLayout({double largeBreakpoint = 1200}) {
    return ThreePaneLayout(
      largeBreakpoint: largeBreakpoint,
      panes: [
        PaneSpec(
          role: PaneRole.secondary,
          preferredWidth: 300,
          builder: (context) =>
              const ColoredBox(key: Key('list'), color: Color(0xFF111111)),
        ),
        PaneSpec(
          role: PaneRole.primary,
          builder: (context) => const ColoredBox(
            key: Key('editor'),
            color: Color(0xFF222222),
            child: CounterPane(),
          ),
        ),
        PaneSpec(
          role: PaneRole.tertiary,
          preferredWidth: 260,
          builder: (context) =>
              const ColoredBox(key: Key('inspector'), color: Color(0xFF333333)),
        ),
      ],
    );
  }

  const compact = Size(500, 800);
  const medium = Size(1000, 800);
  const large = Size(1400, 800);

  bool onstage(WidgetTester tester, Key key) {
    final finder = find.byKey(key, skipOffstage: true);
    return tester.any(finder);
  }

  group('partitions', () {
    testWidgets('compact shows only the primary pane', (tester) async {
      await pumpApp(tester, buildLayout(), size: compact);
      expect(onstage(tester, const Key('editor')), isTrue);
      expect(onstage(tester, const Key('list')), isFalse);
      expect(onstage(tester, const Key('inspector')), isFalse);
      expect(tester.getSize(find.byKey(const Key('editor'))).width, 500);
    });

    testWidgets('medium shows primary + secondary; tertiary yields', (
      tester,
    ) async {
      await pumpApp(tester, buildLayout(), size: medium);
      expect(onstage(tester, const Key('editor')), isTrue);
      expect(onstage(tester, const Key('list')), isTrue);
      expect(onstage(tester, const Key('inspector')), isFalse);
      // Visual order preserved: list (secondary) sits at the start even
      // though the primary outranks it.
      expect(tester.getTopLeft(find.byKey(const Key('list'))).dx, 0);
      expect(tester.getSize(find.byKey(const Key('list'))).width, 300);
      expect(tester.getSize(find.byKey(const Key('editor'))).width, 700);
    });

    testWidgets('large shows all three at their preferred widths', (
      tester,
    ) async {
      await pumpApp(tester, buildLayout(), size: large);
      expect(onstage(tester, const Key('inspector')), isTrue);
      expect(tester.getSize(find.byKey(const Key('list'))).width, 300);
      expect(tester.getSize(find.byKey(const Key('inspector'))).width, 260);
      expect(
        tester.getSize(find.byKey(const Key('editor'))).width,
        1400 - 300 - 260,
      );
    });
  });

  group('dividers', () {
    testWidgets('start divider resizes the secondary pane', (tester) async {
      await pumpApp(tester, buildLayout(), size: large);

      await tester.dragFrom(const Offset(300, 400), const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('list'))).width,
        closeTo(360, 30),
      );
    });

    testWidgets('end divider resizes the tertiary pane (inverted)', (
      tester,
    ) async {
      await pumpApp(tester, buildLayout(), size: large);

      // The tertiary boundary sits at 1400 - 260. Dragging toward the
      // start GROWS the tertiary.
      await tester.dragFrom(const Offset(1140, 400), const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('inspector'))).width,
        closeTo(320, 30),
      );
    });

    testWidgets('dragged width survives a partition round trip', (
      tester,
    ) async {
      await pumpApp(tester, buildLayout(), size: large);
      await tester.dragFrom(const Offset(300, 400), const Offset(80, 0));
      await tester.pumpAndSettle();
      final dragged = tester.getSize(find.byKey(const Key('list'))).width;

      await pumpApp(tester, buildLayout(), size: compact);
      await tester.pumpAndSettle();
      await pumpApp(tester, buildLayout(), size: large);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('list'))).width, dragged);
    });
  });

  group('state retention', () {
    testWidgets('hidden panes keep their live state offstage', (tester) async {
      await pumpApp(tester, buildLayout(), size: large);

      // Mutate state inside the primary pane, then hide the others and
      // bring them back — and shrink so even the primary's neighbors
      // cycle through offstage.
      await tester.tap(find.text('count: 0'));
      await tester.pump();
      expect(find.text('count: 1'), findsOneWidget);

      await pumpApp(tester, buildLayout(), size: compact);
      await tester.pumpAndSettle();
      expect(find.text('count: 1'), findsOneWidget);

      await pumpApp(tester, buildLayout(), size: large);
      await tester.pumpAndSettle();
      expect(find.text('count: 1'), findsOneWidget);
    });
  });

  group('two panes', () {
    testWidgets('a two-pane list works and caps at two partitions', (
      tester,
    ) async {
      final layout = ThreePaneLayout(
        panes: [
          PaneSpec(
            role: PaneRole.secondary,
            preferredWidth: 300,
            builder: (context) =>
                const ColoredBox(key: Key('side'), color: Color(0xFF111111)),
          ),
          PaneSpec(
            role: PaneRole.primary,
            builder: (context) =>
                const ColoredBox(key: Key('main'), color: Color(0xFF222222)),
          ),
        ],
      );
      await pumpApp(tester, layout, size: large);
      expect(tester.getSize(find.byKey(const Key('side'))).width, 300);
      expect(tester.getSize(find.byKey(const Key('main'))).width, 1100);

      await pumpApp(tester, layout, size: compact);
      await tester.pumpAndSettle();
      expect(onstage(tester, const Key('main')), isTrue);
      expect(onstage(tester, const Key('side')), isFalse);
    });
  });
}
