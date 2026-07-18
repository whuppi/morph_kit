import 'package:adaptive_layouts/src/core/list_detail/paint_visibility_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Mirrors the real wiring: [PaintVisibilityDetector.evaluate] runs during
  /// layout (LayoutBuilder), [PaintVisibilityObserver] reports paints.
  Widget harness(PaintVisibilityDetector detector, {required bool offstage}) {
    return Offstage(
      offstage: offstage,
      child: LayoutBuilder(
        builder: (context, constraints) {
          detector.evaluate();
          return PaintVisibilityObserver(
            detector: detector,
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }

  testWidgets('stays visible while painting', (tester) async {
    final detector = PaintVisibilityDetector();
    addTearDown(detector.dispose);

    await tester.pumpWidget(harness(detector, offstage: false));
    await tester.pumpWidget(harness(detector, offstage: false));

    expect(detector.notifier.value, isTrue);
  });

  testWidgets('flips to hidden when paint stops', (tester) async {
    final detector = PaintVisibilityDetector();
    addTearDown(detector.dispose);

    await tester.pumpWidget(harness(detector, offstage: false));

    // Frame 1 offstage: evaluate still sees last frame's paint.
    await tester.pumpWidget(harness(detector, offstage: true));
    // Frame 2 offstage: no paint happened last frame → hidden.
    await tester.pumpWidget(harness(detector, offstage: true));

    expect(detector.notifier.value, isFalse);
  });

  testWidgets('flips back to visible when paint resumes', (tester) async {
    final detector = PaintVisibilityDetector();
    addTearDown(detector.dispose);

    await tester.pumpWidget(harness(detector, offstage: false));
    await tester.pumpWidget(harness(detector, offstage: true));
    await tester.pumpWidget(harness(detector, offstage: true));
    expect(detector.notifier.value, isFalse);

    // Paint resumes; the notifier update is deferred to a post-frame
    // callback (one-frame re-show lag by design).
    await tester.pumpWidget(harness(detector, offstage: false));
    await tester.pump();

    expect(detector.notifier.value, isTrue);
  });
}
