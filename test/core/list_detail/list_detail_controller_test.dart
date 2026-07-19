import 'package:morph_kit/morph_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ListDetailController', () {
    test('starts empty by default', () {
      final controller = ListDetailController<String>();
      expect(controller.selectedId, isNull);
      expect(controller.hasSelection, isFalse);
      expect(controller.isDetailVisible, isFalse);
    });

    test('starts with the initial selection when provided', () {
      final controller = ListDetailController<String>(initialSelection: 'a');
      expect(controller.selectedId, 'a');
      expect(controller.hasSelection, isTrue);
      expect(controller.isDetailVisible, isTrue);
    });

    test('select updates state and notifies', () {
      final controller = ListDetailController<String>();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.select('a');

      expect(controller.selectedId, 'a');
      expect(controller.hasSelection, isTrue);
      expect(notifications, 1);
    });

    test('selecting the already-selected id is a no-op', () {
      final controller = ListDetailController<String>(initialSelection: 'a');
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.select('a');

      expect(notifications, 0);
    });

    test('dismiss clears selection and notifies once', () {
      final controller = ListDetailController<String>(initialSelection: 'a');
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.dismiss();
      expect(controller.selectedId, isNull);
      expect(notifications, 1);

      // Dismissing again is a no-op.
      controller.dismiss();
      expect(notifications, 1);
    });

    test('isDetailVisible stays true while animating out', () {
      final controller = ListDetailController<String>(initialSelection: 'a');

      // The widget marks the exit animation as running, then dismisses.
      controller.dismiss();
      controller.setAnimatingOut(true);
      expect(controller.hasSelection, isFalse);
      expect(controller.isDetailVisible, isTrue);

      controller.setAnimatingOut(false);
      expect(controller.isDetailVisible, isFalse);
    });

    test('select cancels a pending animating-out state', () {
      final controller = ListDetailController<String>(initialSelection: 'a');
      controller.dismiss();
      controller.setAnimatingOut(true);

      controller.select('b');

      expect(controller.selectedId, 'b');
      expect(controller.isDetailVisible, isTrue);
      controller.setAnimatingOut(false);
      // Still visible — there IS a selection now.
      expect(controller.isDetailVisible, isTrue);
    });
  });
}
