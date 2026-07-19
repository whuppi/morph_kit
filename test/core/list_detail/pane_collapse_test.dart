import 'package:adaptive_layouts/adaptive_layouts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Pane collapsing — Material's edge pane-expansion anchors, macOS's
/// split-view collapse: drag (or double-tap) the divider and a pane
/// gives up all its width, then comes back.
void main() {
  const collapsible = PaneConfig(
    minListWidth: 0,
    maxListRatio: 1.0,
    anchors: [
      PaneAnchor.proportion(0.0),
      PaneAnchor.proportion(0.5),
      PaneAnchor.proportion(1.0),
    ],
    initialAnchorIndex: 1,
    collapseOnDoubleTap: true,
  );

  Widget layout() {
    return Material(
      child: ListDetailLayout<String>(
        controller: ListDetailController<String>(initialSelection: 'a'),
        paneConfig: collapsible,
        listBuilder: (context, selectedId, onSelect) =>
            const ColoredBox(key: Key('list'), color: Color(0xFF111111)),
        detailBuilder: (context, id, mode, onDismiss) =>
            const ColoredBox(key: Key('detail'), color: Color(0xFF333333)),
      ),
    );
  }

  double listWidth(WidgetTester tester) =>
      tester.getSize(find.byKey(const Key('list'))).width;

  Future<void> doubleTapDivider(WidgetTester tester, double x) async {
    await tester.tapAt(Offset(x, 400));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(Offset(x, 400));
    await tester.pumpAndSettle();
  }

  testWidgets('dragging to the edge collapses the pane; back restores', (
    tester,
  ) async {
    await pumpApp(tester, layout(), size: const Size(1000, 800));
    expect(listWidth(tester), 500);

    // Hard drag left: settles on the 0% anchor — the list is GONE.
    await tester.dragFrom(const Offset(500, 400), const Offset(-450, 0));
    await tester.pumpAndSettle();
    expect(listWidth(tester), 0);
    expect(tester.getSize(find.byKey(const Key('detail'))).width, 1000);

    // The divider survives at the edge — drag it back out.
    await tester.dragFrom(const Offset(5, 400), const Offset(480, 0));
    await tester.pumpAndSettle();
    expect(listWidth(tester), 500);

    // Hard drag right: the DETAIL collapses instead.
    await tester.dragFrom(const Offset(500, 400), const Offset(460, 0));
    await tester.pumpAndSettle();
    expect(listWidth(tester), 1000);
    expect(tester.getSize(find.byKey(const Key('detail'))).width, 0);
  });

  testWidgets('double-tap collapses; double-tap again restores', (
    tester,
  ) async {
    await pumpApp(tester, layout(), size: const Size(1000, 800));

    await doubleTapDivider(tester, 500);
    expect(listWidth(tester), 0);

    await doubleTapDivider(tester, 5);
    expect(listWidth(tester), 500); // back to the pre-collapse position
  });

  testWidgets('double-tap restore lands proportionally after a resize', (
    tester,
  ) async {
    await pumpApp(tester, layout(), size: const Size(1000, 800));
    await doubleTapDivider(tester, 500); // collapsed at 50%

    await resizeWindow(tester, const Size(800, 800));
    await doubleTapDivider(tester, 5);
    expect(listWidth(tester), closeTo(400, 1)); // 50% of the new width
  });
}
