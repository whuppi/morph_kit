import 'package:morph_kit/morph_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// The native-passthrough contract: every `ModalConfig` field that mirrors
/// a parameter on Flutter's own routes arrives there verbatim.
void main() {
  const config = ModalConfig(
    barrierLabel: 'close the thing',
    anchorPoint: Offset(7, 11),
    traversalEdgeBehavior: TraversalEdgeBehavior.leaveFlutterView,
    constraints: BoxConstraints(maxWidth: 333),
    scrollControlDisabledMaxHeightRatio: 0.4,
    isScrollControlled: false,
    sheetAnimationStyle: AnimationStyle(duration: Duration(milliseconds: 5)),
  );

  Widget host() {
    return Material(
      child: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showAdaptiveModal<void>(
              context: context,
              config: config,
              builder: (context, mode) => const SizedBox(
                width: 200,
                height: 100,
                child: Text('modal-content'),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  testWidgets('sheet form receives the native params verbatim', (tester) async {
    await pumpApp(tester, host(), size: const Size(500, 800));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final route =
        ModalRoute.of(tester.element(find.text('modal-content')))!
            as ModalBottomSheetRoute<void>;
    expect(route.barrierLabel, 'close the thing');
    expect(route.anchorPoint, const Offset(7, 11));
    expect(route.constraints, const BoxConstraints(maxWidth: 333));
    expect(route.scrollControlDisabledMaxHeightRatio, 0.4);
    expect(route.isScrollControlled, isFalse);
    expect(
      route.sheetAnimationStyle,
      const AnimationStyle(duration: Duration(milliseconds: 5)),
    );
  });

  testWidgets('dialog form receives the native params verbatim', (
    tester,
  ) async {
    await pumpApp(tester, host(), size: const Size(1000, 800));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final route =
        ModalRoute.of(tester.element(find.text('modal-content')))!
            as DialogRoute<void>;
    expect(route.barrierLabel, 'close the thing');
    expect(route.anchorPoint, const Offset(7, 11));
    expect(route.traversalEdgeBehavior, TraversalEdgeBehavior.leaveFlutterView);
  });

  testWidgets('swap pushes stay instant even with a slow consumer style', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Material(
        child: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showAdaptiveModal<void>(
                context: context,
                config: const ModalConfig(
                  morph: false,
                  animationStyle: AnimationStyle(
                    duration: Duration(seconds: 5),
                  ),
                  sheetAnimationStyle: AnimationStyle(
                    duration: Duration(seconds: 5),
                  ),
                ),
                builder: (context, mode) => const SizedBox(
                  width: 200,
                  height: 100,
                  child: Text('modal-content'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      size: const Size(1000, 800),
    );
    await tester.tap(find.text('open'));
    // First entrance honors the consumer's 5s style — far from settled.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final entrance = ModalRoute.of(tester.element(find.text('modal-content')))!;
    expect(entrance.animation!.status, AnimationStatus.forward);
    await tester.pump(const Duration(seconds: 5));

    // The breakpoint swap overrides it to zero — settled within frames,
    // not seconds.
    tester.view.physicalSize = const Size(500, 800);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    final swapped = ModalRoute.of(tester.element(find.text('modal-content')))!;
    expect(swapped, isA<ModalBottomSheetRoute<void>>());
    expect(swapped.animation!.status, AnimationStatus.completed);
    await tester.pumpAndSettle();
  });
}
