import 'package:morph_kit/morph_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Pumps an app with a button that opens an adaptive modal hosting a
/// [CounterPane]. Returns a record with the collected modes and results.
class _ModalHarness {
  final List<ModalLayoutMode> modes = [];
  T? result<T>() => _result as T?;
  Object? _result;
  bool completed = false;

  Widget build({
    ModalConfig config = const ModalConfig(),
    double? expandedBreakpoint,
  }) {
    return Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          onPressed: () async {
            final value = await showAdaptiveModal<Object>(
              context: context,
              config: config,
              expandedBreakpoint: expandedBreakpoint,
              builder: (context, mode) {
                modes.add(mode);
                return const SizedBox(
                  width: 300,
                  height: 200,
                  child: CounterPane(),
                );
              },
            );
            _result = value;
            completed = true;
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('form selection', () {
    testWidgets('wide window presents a real Dialog', (tester) async {
      final harness = _ModalHarness();
      await pumpApp(tester, harness.build(), size: const Size(1000, 800));
      await _open(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(harness.modes.last, ModalLayoutMode.dialog);
    });

    testWidgets('narrow window presents a real BottomSheet', (tester) async {
      final harness = _ModalHarness();
      await pumpApp(tester, harness.build(), size: const Size(500, 800));
      await _open(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(harness.modes.last, ModalLayoutMode.sheet);
    });

    testWidgets('explicit breakpoint param wins', (tester) async {
      final harness = _ModalHarness();
      await pumpApp(
        tester,
        harness.build(expandedBreakpoint: 1200),
        size: const Size(1000, 800),
      );
      await _open(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('inherited AdaptiveLayoutConfig breakpoint applies', (
      tester,
    ) async {
      final harness = _ModalHarness();
      await pumpApp(
        tester,
        AdaptiveLayoutConfig(expandedBreakpoint: 1200, child: harness.build()),
        size: const Size(1000, 800),
      );
      await _open(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });

  group('live swap', () {
    testWidgets('dialog → sheet on shrink, state preserved', (tester) async {
      final harness = _ModalHarness();
      await pumpApp(tester, harness.build(), size: const Size(1000, 800));
      await _open(tester);
      expect(find.byType(Dialog), findsOneWidget);

      await tester.tap(find.byType(CounterPane));
      await tester.tap(find.byType(CounterPane));
      await tester.pump();
      expect(find.text('count: 2'), findsOneWidget);

      await resizeWindow(tester, const Size(500, 800));

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('count: 2'), findsOneWidget);
      expect(harness.modes.last, ModalLayoutMode.sheet);
    });

    testWidgets('sheet → dialog on grow, state preserved', (tester) async {
      final harness = _ModalHarness();
      await pumpApp(tester, harness.build(), size: const Size(500, 800));
      await _open(tester);
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.tap(find.byType(CounterPane));
      await tester.pump();

      await resizeWindow(tester, const Size(1000, 800));

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('count: 1'), findsOneWidget);
    });

    testWidgets('round trip keeps state', (tester) async {
      final harness = _ModalHarness();
      await pumpApp(tester, harness.build(), size: const Size(1000, 800));
      await _open(tester);

      await tester.tap(find.byType(CounterPane));
      await tester.pump();
      await resizeWindow(tester, const Size(500, 800));
      await tester.tap(find.byType(CounterPane));
      await tester.pump();
      await resizeWindow(tester, const Size(1000, 800));

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('count: 2'), findsOneWidget);
    });

    testWidgets('swap does not complete the caller future', (tester) async {
      final harness = _ModalHarness();
      await pumpApp(tester, harness.build(), size: const Size(1000, 800));
      await _open(tester);

      await resizeWindow(tester, const Size(500, 800));

      expect(harness.completed, isFalse);
    });
  });

  group('dismissal and results', () {
    testWidgets('pop returns the value to the original caller', (tester) async {
      final harness = _ModalHarness();
      await pumpApp(tester, harness.build(), size: const Size(1000, 800));
      await _open(tester);

      Navigator.of(tester.element(find.byType(CounterPane))).pop('picked');
      await tester.pumpAndSettle();

      expect(harness.completed, isTrue);
      expect(harness.result<String>(), 'picked');
    });

    testWidgets('pop after a swap still returns the value', (tester) async {
      final harness = _ModalHarness();
      await pumpApp(tester, harness.build(), size: const Size(1000, 800));
      await _open(tester);
      await resizeWindow(tester, const Size(500, 800));

      Navigator.of(tester.element(find.byType(CounterPane))).pop('after-swap');
      await tester.pumpAndSettle();

      expect(harness.result<String>(), 'after-swap');
    });

    testWidgets('barrier tap dismisses with null', (tester) async {
      final harness = _ModalHarness();
      await pumpApp(tester, harness.build(), size: const Size(1000, 800));
      await _open(tester);

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(harness.completed, isTrue);
      expect(harness.result<Object>(), isNull);
    });

    testWidgets('barrierDismissible: false blocks barrier tap', (tester) async {
      final harness = _ModalHarness();
      await pumpApp(
        tester,
        harness.build(config: const ModalConfig(barrierDismissible: false)),
        size: const Size(1000, 800),
      );
      await _open(tester);

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(harness.completed, isFalse);
    });

    testWidgets('sheet drags down to dismiss (Material physics)', (
      tester,
    ) async {
      final harness = _ModalHarness();
      await pumpApp(tester, harness.build(), size: const Size(500, 800));
      await _open(tester);

      await tester.fling(find.byType(CounterPane), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(harness.completed, isTrue);
    });

    testWidgets('enableDrag: false keeps the sheet up', (tester) async {
      final harness = _ModalHarness();
      await pumpApp(
        tester,
        harness.build(config: const ModalConfig(enableDrag: false)),
        size: const Size(500, 800),
      );
      await _open(tester);

      await tester.fling(find.byType(CounterPane), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });

  group('chrome forwarding', () {
    testWidgets('showDragHandle: true shows Material drag handle', (
      tester,
    ) async {
      final harness = _ModalHarness();
      await pumpApp(
        tester,
        harness.build(config: const ModalConfig(showDragHandle: true)),
        size: const Size(500, 800),
      );
      await _open(tester);

      // Material's drag handle is a Semantics-labeled grab area inside
      // the BottomSheet.
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Semantics),
        ),
        findsWidgets,
      );
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.showDragHandle, isTrue);
    });

    testWidgets('builder mode reflects the presented form', (tester) async {
      final harness = _ModalHarness();
      await pumpApp(tester, harness.build(), size: const Size(1000, 800));
      await _open(tester);
      expect(harness.modes.last, ModalLayoutMode.dialog);

      await resizeWindow(tester, const Size(500, 800));
      expect(harness.modes.last, ModalLayoutMode.sheet);

      await resizeWindow(tester, const Size(1000, 800));
      expect(harness.modes.last, ModalLayoutMode.dialog);
    });
  });
}
