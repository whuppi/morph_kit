import 'package:morph_kit/morph_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

Widget _layout(CompactDetailMode mode, {Widget? detailExtra}) {
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
            Text('detail-$id'),
            TextButton(onPressed: onDismiss, child: const Text('close')),
            if (detailExtra != null) detailExtra,
          ],
        ),
      ),
      emptyStateBuilder: (context) => const Text('empty'),
    ),
  );
}

SemanticsNode _rootNode(WidgetTester tester) {
  // The view's pipeline owner holds semantics — reach it through any
  // attached render object.
  return tester
      .renderObject(find.byType(Material).first)
      .owner!
      .semanticsOwner!
      .rootSemanticsNode!;
}

/// Every label reachable in the semantics tree.
Set<String> _semanticLabels(WidgetTester tester) {
  final labels = <String>{};
  void walk(SemanticsNode node) {
    if (node.label.isNotEmpty) labels.add(node.label);
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(_rootNode(tester));
  return labels;
}

void main() {
  for (final mode in [CompactDetailMode.inline, CompactDetailMode.overlay]) {
    testWidgets('${mode.name}: covered content leaves the semantics tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, _layout(mode), size: const Size(500, 800));

      expect(_semanticLabels(tester), contains('item-a'));

      await tester.tap(find.text('item-a'));
      await tester.pumpAndSettle();

      // Route parity: a screen reader must not traverse the list under
      // the open detail.
      final open = _semanticLabels(tester);
      expect(open, contains('detail-a'));
      expect(open, isNot(contains('item-a')));

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();
      expect(_semanticLabels(tester), contains('item-a'));

      handle.dispose();
    });

    testWidgets('${mode.name}: the open detail scopes as a route', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, _layout(mode), size: const Size(500, 800));
      await tester.tap(find.text('item-a'));
      await tester.pumpAndSettle();

      bool scoped = false;
      void walk(SemanticsNode node) {
        if (node.flagsCollection.scopesRoute) scoped = true;
        node.visitChildren((child) {
          walk(child);
          return true;
        });
      }

      walk(_rootNode(tester));
      expect(scoped, isTrue);

      handle.dispose();
    });

    testWidgets('${mode.name}: Escape dismisses when focus is in the detail', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpApp(
        tester,
        _layout(
          mode,
          detailExtra: Focus(focusNode: focus, child: const Text('focusable')),
        ),
        size: const Size(500, 800),
      );
      await tester.tap(find.text('item-a'));
      await tester.pumpAndSettle();

      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('detail-a'), findsNothing);
      expect(find.text('item-a'), findsOneWidget);
    });
  }

  testWidgets('overlay: content OUTSIDE the layout is blocked while open', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    // A bottom-nav-like sibling below the layout — overlay mode covers it
    // visually, so it must leave the semantics tree too.
    await pumpApp(
      tester,
      Column(
        children: [
          Expanded(child: _layout(CompactDetailMode.overlay)),
          const Material(child: Text('bottom-nav')),
        ],
      ),
      size: const Size(500, 800),
    );
    expect(_semanticLabels(tester), contains('bottom-nav'));

    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();
    expect(_semanticLabels(tester), isNot(contains('bottom-nav')));

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();
    expect(_semanticLabels(tester), contains('bottom-nav'));

    handle.dispose();
  });
}
