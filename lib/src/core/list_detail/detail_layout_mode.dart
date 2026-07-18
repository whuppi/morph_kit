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

  /// Detail is pushed as a REAL page route on the Navigator.
  ///
  /// Covers everything below the route (bottom nav, tab bars) and inherits
  /// the app's `PageTransitionsTheme` — platform transitions, predictive
  /// back, Cupertino edge swipes. Back is handled by the route itself
  /// (`CompactConfig.handleBackGesture` and the slide/swipe machinery are
  /// not used in this mode). Which navigator receives the route is
  /// controlled by `CompactConfig.useRootNavigator`. State is preserved
  /// across compact ↔ expanded resizes by reparenting the detail element
  /// between the route and the expanded pane.
  route,
}
