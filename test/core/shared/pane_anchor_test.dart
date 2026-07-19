import 'package:morph_kit/morph_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaneAnchor', () {
    test('proportion resolves against available width', () {
      expect(const PaneAnchor.proportion(0.5).resolve(1000), 500);
      expect(const PaneAnchor.proportion(0.0).resolve(1000), 0);
      expect(const PaneAnchor.proportion(1.0).resolve(1000), 1000);
    });

    test('fromStart resolves to a fixed offset', () {
      expect(const PaneAnchor.fromStart(240).resolve(1000), 240);
      expect(const PaneAnchor.fromStart(240).resolve(500), 240);
    });

    test('fromEnd resolves relative to the end edge', () {
      expect(const PaneAnchor.fromEnd(240).resolve(1000), 760);
      expect(const PaneAnchor.fromEnd(240).resolve(500), 260);
    });

    test('isProportion distinguishes the two forms', () {
      expect(const PaneAnchor.proportion(0.5).isProportion, isTrue);
      expect(const PaneAnchor.fromStart(240).isProportion, isFalse);
      expect(const PaneAnchor.fromEnd(240).isProportion, isFalse);
    });

    test('equality is by value', () {
      expect(
        const PaneAnchor.proportion(0.5),
        const PaneAnchor.proportion(0.5),
      );
      expect(const PaneAnchor.fromStart(240), const PaneAnchor.fromStart(240));
      expect(
        const PaneAnchor.fromStart(240),
        isNot(const PaneAnchor.fromEnd(240)),
      );
    });

    test('equality holds for runtime instances (NaN sentinel)', () {
      // Non-const: const canonicalization would short-circuit through
      // `identical` and mask a NaN != NaN field comparison.
      double n(double v) => v;
      expect(PaneAnchor.fromStart(n(240)), PaneAnchor.fromStart(n(240)));
      expect(PaneAnchor.fromEnd(n(240)), PaneAnchor.fromEnd(n(240)));
      expect(PaneAnchor.proportion(n(0.5)), PaneAnchor.proportion(n(0.5)));
      expect(PaneAnchor.fromStart(n(240)), isNot(PaneAnchor.fromStart(n(241))));
      expect(
        PaneConfig(anchors: [PaneAnchor.fromStart(n(240))]),
        PaneConfig(anchors: [PaneAnchor.fromStart(n(240))]),
      );
    });

    test('listDetail preset spans collapsed to fully expanded', () {
      expect(PaneAnchor.listDetail, hasLength(5));
      expect(PaneAnchor.listDetail.first.resolve(1000), 0);
      expect(PaneAnchor.listDetail.last.resolve(1000), 1000);
    });
  });
}
