import 'package:adaptive_layouts/adaptive_layouts.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptiveLayoutConfig', () {
    testWidgets('resolveBreakpoint prefers the widget param', (tester) async {
      double? resolved;
      await tester.pumpWidget(
        AdaptiveLayoutConfig(
          expandedBreakpoint: 900,
          child: Builder(
            builder: (context) {
              resolved = AdaptiveLayoutConfig.resolveBreakpoint(context, 600);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, 600);
    });

    testWidgets('resolveBreakpoint falls back to the inherited value', (
      tester,
    ) async {
      double? resolved;
      await tester.pumpWidget(
        AdaptiveLayoutConfig(
          expandedBreakpoint: 900,
          child: Builder(
            builder: (context) {
              resolved = AdaptiveLayoutConfig.resolveBreakpoint(context, null);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, 900);
    });

    testWidgets('resolveBreakpoint defaults to 720 with nothing in the tree', (
      tester,
    ) async {
      double? resolved;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolved = AdaptiveLayoutConfig.resolveBreakpoint(context, null);
            return const SizedBox();
          },
        ),
      );
      expect(resolved, AdaptiveLayoutConfig.defaultExpandedBreakpoint);
      expect(resolved, 720);
    });

    test('updateShouldNotify fires only when the breakpoint changes', () {
      const a = AdaptiveLayoutConfig(child: SizedBox());
      const b = AdaptiveLayoutConfig(
        expandedBreakpoint: 900,
        child: SizedBox(),
      );
      expect(b.updateShouldNotify(a), isTrue);
      expect(
        const AdaptiveLayoutConfig(child: SizedBox()).updateShouldNotify(a),
        isFalse,
      );
    });
  });
}
