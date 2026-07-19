import 'package:flutter/widgets.dart';

/// Shared configuration for all morph_kit widgets in the subtree.
///
/// Place this high in the widget tree (e.g., above `MaterialApp`) to set
/// defaults that all `ListDetailLayout` and future widgets inherit.
///
/// Same pattern as `Theme`, [MediaQuery], [Directionality].
///
/// ```dart
/// AdaptiveLayoutConfig(
///   expandedBreakpoint: 720,
///   child: MaterialApp(...),
/// )
/// ```
///
/// Per-widget overrides still work — a widget's explicit `expandedBreakpoint`
/// param takes precedence over the inherited value.
class AdaptiveLayoutConfig extends InheritedWidget {
  /// Creates the inherited layout configuration.
  const AdaptiveLayoutConfig({
    super.key,
    this.expandedBreakpoint = defaultExpandedBreakpoint,
    required super.child,
  });

  /// Width breakpoint (logical pixels) for switching from compact (single-pane)
  /// to expanded (multi-pane) layout.
  final double expandedBreakpoint;

  /// Default breakpoint when no [AdaptiveLayoutConfig] is in the tree.
  static const double defaultExpandedBreakpoint = 720;

  /// Reads the nearest [AdaptiveLayoutConfig] from the widget tree.
  /// Returns null if none is found.
  static AdaptiveLayoutConfig? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdaptiveLayoutConfig>();
  }

  /// Resolves the expanded breakpoint: widget param > inherited > default.
  static double resolveBreakpoint(BuildContext context, double? widgetParam) {
    if (widgetParam != null) return widgetParam;
    return maybeOf(context)?.expandedBreakpoint ?? defaultExpandedBreakpoint;
  }

  @override
  bool updateShouldNotify(AdaptiveLayoutConfig oldWidget) {
    return expandedBreakpoint != oldWidget.expandedBreakpoint;
  }
}
