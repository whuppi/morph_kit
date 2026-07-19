/// A side of a pane divider, in directional terms (start = left in LTR).
///
/// In `ListDetailLayout` the start pane is the list and the end pane is
/// the detail. In `AdaptiveSplit` the start pane is whichever pane sits
/// at the start per `SplitPrimaryPosition`.
enum PaneSide {
  /// The pane on the directional start side of the divider.
  start,

  /// The pane on the directional end side of the divider.
  end,
}

/// Which panes may snap-collapse when the divider is forced past their
/// size limit.
///
/// The mechanics follow desktop split views: dragging past a pane's
/// limit by half its minimum size snaps it to `PaneConfig.collapsedSize`
/// with the pre-collapse width remembered; releasing short of that
/// springs back to the limit. The parked divider stays draggable — pull
/// it back out to restore.
enum PaneCollapsible {
  /// Neither pane collapses; the limits are hard stops (default).
  none,

  /// Only the start pane (the list) collapses.
  start,

  /// Only the end pane (the detail) collapses.
  end,

  /// Both panes collapse.
  both,
}

/// Convenience checks for [PaneCollapsible].
extension PaneCollapsibleSides on PaneCollapsible {
  /// Whether [side] is allowed to collapse.
  bool allows(PaneSide side) => switch (this) {
    PaneCollapsible.none => false,
    PaneCollapsible.start => side == PaneSide.start,
    PaneCollapsible.end => side == PaneSide.end,
    PaneCollapsible.both => true,
  };
}
