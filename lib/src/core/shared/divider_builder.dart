import 'package:flutter/widgets.dart';

import 'package:adaptive_layouts/src/core/shared/pane_collapse.dart';

/// The divider's full interaction state, handed to a [DividerBuilder]
/// every build.
///
/// A single state object instead of positional flags so the contract can
/// grow without breaking every builder — the same discipline as
/// `PaneConfig`.
@immutable
class DividerState {
  /// Creates a divider state snapshot.
  const DividerState({
    this.isDragging = false,
    this.isSettling = false,
    this.atMinimum = false,
    this.atMaximum = false,
    this.collapsed,
    this.isFocused = false,
  });

  /// True while the user is actively dragging.
  final bool isDragging;

  /// True while the divider animates to an anchor point or a restore.
  final bool isSettling;

  /// True when the start pane is pinned at its minimum width — the
  /// divider cannot move further without collapsing (if allowed).
  final bool atMinimum;

  /// True when the start pane is pinned at its maximum width.
  final bool atMaximum;

  /// The collapsed pane, or null when both panes are visible. When set,
  /// the divider is parked at that pane's edge — still draggable, and a
  /// builder should render a restore affordance (a pull tab).
  final PaneSide? collapsed;

  /// True when the divider has keyboard focus (arrow keys resize it).
  final bool isFocused;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DividerState &&
          other.isDragging == isDragging &&
          other.isSettling == isSettling &&
          other.atMinimum == atMinimum &&
          other.atMaximum == atMaximum &&
          other.collapsed == collapsed &&
          other.isFocused == isFocused;

  @override
  int get hashCode => Object.hash(
    isDragging,
    isSettling,
    atMinimum,
    atMaximum,
    collapsed,
    isFocused,
  );
}

/// Builder for a pane divider in expanded layout.
///
/// Shared across `ListDetailLayout`, `AdaptiveSplit`, and any future
/// multi-pane layout widget. Use a shipped component
/// (`MaterialDivider.builder`, `HandleDivider.builder`) or build your own.
typedef DividerBuilder =
    Widget Function(BuildContext context, DividerState state);
