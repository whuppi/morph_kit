import 'package:flutter/widgets.dart';

import 'package:adaptive_layouts/src/core/shared/pane_collapse.dart';

/// Pane-system state and actions, readable by any descendant of a pane —
/// list content, detail content, custom dividers.
///
/// The delivery mechanism for pane signals: instead of growing every
/// builder signature per signal, descendants read the scope. The
/// canonical use is a restore affordance inside the surviving pane:
///
/// ```dart
/// final scope = PaneScope.maybeOf(context);
/// if (scope?.collapsed == PaneSide.start)
///   IconButton(icon: const Icon(Icons.menu), onPressed: scope!.restore)
/// ```
@immutable
class PaneScopeData {
  /// Creates a scope snapshot with its actions.
  const PaneScopeData({
    required this.collapsed,
    required this.isExpanded,
    required this.collapse,
    required this.restore,
  });

  /// The collapsed pane, or null when both are visible. Always null in
  /// compact layout — collapse is expanded-only view state.
  final PaneSide? collapsed;

  /// Whether the layout is currently in its expanded (side-by-side) form.
  final bool isExpanded;

  /// Collapses [PaneSide] programmatically. No-op when the config
  /// disallows it or the layout is compact.
  final void Function(PaneSide side) collapse;

  /// Restores a collapsed pane to its remembered width. No-op when
  /// nothing is collapsed.
  final VoidCallback restore;
}

/// Hosts a [PaneScopeData] for a pane-based layout's subtree.
class PaneScope extends InheritedWidget {
  /// Creates the scope host.
  const PaneScope({super.key, required this.data, required super.child});

  /// The current pane state + actions.
  final PaneScopeData data;

  /// The nearest scope, or null outside a pane-based layout.
  static PaneScopeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaneScope>()?.data;

  /// The nearest scope. Throws outside a pane-based layout.
  static PaneScopeData of(BuildContext context) {
    final data = maybeOf(context);
    assert(data != null, 'PaneScope.of called outside a pane-based layout');
    return data!;
  }

  @override
  bool updateShouldNotify(PaneScope oldWidget) =>
      data.collapsed != oldWidget.data.collapsed ||
      data.isExpanded != oldWidget.data.isExpanded;
}
