import 'package:flutter/foundation.dart';

/// Controls selection state and detail visibility for `ListDetailLayout`.
///
/// Works like `ScrollController` — if you don't provide one, the widget
/// creates a default internally. Provide your own for programmatic control
/// or router integration.
///
/// ```dart
/// // Simple — widget manages everything:
/// ListDetailLayout(listBuilder: ..., detailBuilder: ...)
///
/// // Controlled — you drive selection:
/// final controller = ListDetailController<String>();
/// ListDetailLayout(controller: controller, ...)
///
/// controller.select('item-123');
/// controller.dismiss();
/// controller.addListener(() => print(controller.selectedId));
/// ```
class ListDetailController<T> extends ChangeNotifier {
  /// Create a controller with an optional initial selection.
  ListDetailController({T? initialSelection}) : _selectedId = initialSelection;

  T? _selectedId;
  bool _isAnimatingOut = false;

  /// Currently selected item ID. Null means nothing is selected.
  T? get selectedId => _selectedId;

  /// Whether an item is selected (data state — immediate, not animation-aware).
  bool get hasSelection => _selectedId != null;

  /// Whether the detail pane is visually on screen.
  ///
  /// Animation-aware: remains `true` during the slide-out animation even
  /// after [selectedId] becomes null. Use this for UI decisions like
  /// hiding the bottom navigation bar.
  ///
  /// Timeline when [dismiss] is called:
  /// 1. [selectedId] → null, [hasSelection] → false
  /// 2. [isDetailVisible] stays true (animation playing)
  /// 3. Animation completes → [isDetailVisible] → false
  bool get isDetailVisible => _selectedId != null || _isAnimatingOut;

  /// Select an item. Triggers the detail pane to open.
  ///
  /// No-op if [id] is already selected. If you want toggle behavior,
  /// check [selectedId] first and call [dismiss] explicitly.
  void select(T id) {
    if (_selectedId == id) return;
    _isAnimatingOut = false;
    _selectedId = id;
    notifyListeners();
  }

  /// Clear selection. Triggers the detail pane to close with animation.
  void dismiss() {
    if (_selectedId == null) return;
    _selectedId = null;
    // _isAnimatingOut is set by the widget via setAnimatingOut.
    notifyListeners();
  }

  /// Called by the widget to sync animation state.
  ///
  /// When the slide-out animation starts, the widget calls this with `true`.
  /// When the animation completes, it calls with `false`.
  /// This keeps [isDetailVisible] accurate during transitions.
  @internal
  void setAnimatingOut(bool value) {
    if (_isAnimatingOut == value) return;
    _isAnimatingOut = value;
    notifyListeners();
  }
}
