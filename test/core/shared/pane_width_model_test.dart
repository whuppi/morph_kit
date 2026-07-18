import 'package:adaptive_layouts/adaptive_layouts.dart';
import 'package:adaptive_layouts/src/core/shared/pane_width_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ratio mode (default)', () {
    test('initial width comes from defaultListWidth scaled by window', () {
      final model = PaneWidthModel(
        const PaneConfig(defaultListWidth: 360),
        referenceWidth: 720,
      );
      // ratio = 360/720 = 0.5, but maxListRatio (0.5) also caps at 0.5.
      expect(model.width(1000), 500);
      // Scales with the window.
      expect(model.width(800), 400);
    });

    test('drag adjusts the ratio within min/max clamps', () {
      final model = PaneWidthModel(
        const PaneConfig(
          defaultListWidth: 300,
          minListWidth: 200,
          maxListRatio: 0.5,
        ),
        referenceWidth: 720,
      );
      final start = model.width(1000);

      model.drag(50, 1000);
      expect(model.width(1000), closeTo(start + 50, 0.001));

      // Dragging far right stops at maxListRatio.
      model.drag(5000, 1000);
      expect(model.width(1000), 500);

      // Dragging far left stops at minListWidth.
      model.drag(-5000, 1000);
      expect(model.width(1000), 200);
    });
  });

  group('pixels mode', () {
    test('width stays fixed when the window resizes', () {
      final model = PaneWidthModel(
        const PaneConfig(
          defaultListWidth: 360,
          resizeMode: PaneResizeMode.pixels,
          maxListRatio: 0.8,
        ),
        referenceWidth: 720,
      );
      expect(model.width(1000), 360);
      expect(model.width(2000), 360);
    });

    test('drag moves by pixels and clamps', () {
      final model = PaneWidthModel(
        const PaneConfig(
          defaultListWidth: 360,
          minListWidth: 200,
          maxListRatio: 0.5,
          resizeMode: PaneResizeMode.pixels,
        ),
        referenceWidth: 720,
      );
      model.drag(100, 1000);
      expect(model.width(1000), 460);

      model.drag(5000, 1000);
      expect(model.width(1000), 500);

      model.drag(-5000, 1000);
      expect(model.width(1000), 200);
    });
  });

  group('clamping', () {
    test(
      'minListWidth wins when the window is too narrow for maxListRatio',
      () {
        final model = PaneWidthModel(
          const PaneConfig(
            defaultListWidth: 300,
            minListWidth: 240,
            maxListRatio: 0.3,
          ),
          referenceWidth: 720,
        );
        // 0.3 * 700 = 210 < minListWidth 240 → min wins.
        expect(model.width(700), 240);
      },
    );
  });

  group('anchors', () {
    const config = PaneConfig(
      minListWidth: 100,
      maxListRatio: 0.9,
      anchors: [PaneAnchor.fromStart(240), PaneAnchor.proportion(0.5)],
      initialAnchorIndex: 0,
    );

    test('initial width comes from initialAnchorIndex', () {
      final model = PaneWidthModel(config, referenceWidth: 720);
      expect(model.width(1000), 240);
    });

    test('out-of-range initialAnchorIndex clamps to the anchor list', () {
      final model = PaneWidthModel(
        const PaneConfig(
          minListWidth: 100,
          maxListRatio: 0.9,
          anchors: [PaneAnchor.fromStart(240)],
          initialAnchorIndex: 7,
        ),
        referenceWidth: 720,
      );
      expect(model.width(1000), 240);
    });

    test('snapTarget picks the nearest anchor', () {
      final model = PaneWidthModel(config, referenceWidth: 720);
      model.width(1000); // initialize at 240

      model.setWidth(300, 1000);
      expect(model.snapTarget(1000), 240); // |300-240|=60 < |300-500|=200

      model.setWidth(420, 1000);
      expect(model.snapTarget(1000), 500);
    });

    test('snapTarget is null when already at an anchor', () {
      final model = PaneWidthModel(config, referenceWidth: 720);
      model.width(1000);
      expect(model.snapTarget(1000), isNull);
    });

    test('snapTarget is null without anchors', () {
      final model = PaneWidthModel(const PaneConfig(), referenceWidth: 720);
      model.width(1000);
      expect(model.snapTarget(1000), isNull);
    });

    test('anchor positions are clamped by minListWidth/maxListRatio', () {
      final model = PaneWidthModel(
        const PaneConfig(
          minListWidth: 200,
          maxListRatio: 0.5,
          anchors: [PaneAnchor.proportion(0.0), PaneAnchor.proportion(1.0)],
          initialAnchorIndex: 0,
        ),
        referenceWidth: 720,
      );
      // proportion(0.0) clamps up to minListWidth.
      expect(model.width(1000), 200);

      model.setWidth(400, 1000);
      // Nearest is proportion(1.0) → clamped to maxListRatio.
      expect(model.snapTarget(1000), 500);
    });

    test('setWidth feeds animation frames back into the model', () {
      final model = PaneWidthModel(config, referenceWidth: 720);
      model.width(1000);
      model.setWidth(371.5, 1000);
      expect(model.width(1000), closeTo(371.5, 0.001));
    });
  });
}
