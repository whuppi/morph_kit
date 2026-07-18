/// How the detail pane is displayed relative to the list.
enum DetailLayoutMode {
  /// Detail is stacked on top of the list — full width.
  /// Used in compact layout. The detail slides over the list.
  stacked,

  /// Detail is displayed side-by-side with the list — shared width.
  /// Used in expanded layout. Both panes are visible simultaneously.
  sideBySide,
}

/// How the detail pane is placed in compact (mobile) layout.
///
/// Both modes use the same slide animation and swipe-to-dismiss gesture.
/// The difference is WHERE the detail widget tree is mounted.
enum CompactDetailMode {
  /// Detail renders inline within the layout's widget tree.
  /// Does NOT cover sibling widgets (bottom nav, tab bars).
  inline,

  /// Detail renders in an ancestor `Overlay` via `OverlayPortal`.
  /// Covers sibling widgets (bottom nav, tab bars) while keeping the
  /// detail in the widget tree (state preserved via GlobalKey).
  /// Which overlay is controlled by `CompactConfig.useRootOverlay`.
  overlay,
}
