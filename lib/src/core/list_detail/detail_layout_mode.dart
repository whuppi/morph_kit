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
/// All three modes keep the same guarantee — the detail's widget
/// *instance* survives compact ↔ expanded resizes — and differ in where
/// the detail is mounted, which decides what it covers, who owns the
/// back gesture, and how the page's own chrome (snackbars, FABs)
/// stacks against it.
enum CompactDetailMode {
  /// Detail renders inline, within the layout's own bounds.
  ///
  /// - Does NOT cover siblings: bottom nav and tab bars stay visible
  ///   and tappable next to the open detail.
  /// - Slide-over entrance, swipe anywhere on the detail to dismiss,
  ///   system back intercepted via `PopScope`
  ///   (`CompactConfig.handleBackGesture`). The interception costs
  ///   Android's predictive-back preview — the system cannot peek a
  ///   route that isn't one.
  /// - The page's snackbars, FABs, and bottom sheets render above the
  ///   layout as usual — nothing is hidden.
  /// - Assistive tech gets route parity: the open detail scopes as a
  ///   route, the covered list leaves the semantics tree, and
  ///   `DismissIntent` (Escape on desktop) dismisses when the focus is
  ///   inside the detail.
  /// - Breakpoint crossings with an open detail: a discrete jump (fold,
  ///   rotation, split-screen snap) grows the detail out of its pane to
  ///   full width; a continuous window drag tracks the hand — no motion.
  ///
  /// Pick when the detail is part of the screen and the surrounding
  /// chrome should stay present.
  inline,

  /// Detail renders in an ancestor `Overlay` via `OverlayPortal`.
  ///
  /// - Covers sibling widgets (bottom nav, tab bars) for a full-screen
  ///   feel WITHOUT real navigation — no route churn, no Hero scans.
  ///   Which overlay via `CompactConfig.useRootOverlay`.
  /// - Same gestures as [inline]: slide-over, swipe anywhere to
  ///   dismiss, `PopScope` back interception (predictive-back preview
  ///   lost). Later-pushed routes (dialogs, sheets) still appear above.
  /// - The page's snackbars, FABs, and bottom sheets render INSIDE the
  ///   page — structurally BELOW the overlay entry — so an open detail
  ///   hides them. Inherent to overlay stacking, not configurable.
  /// - Kept-alive multi-tab shells are handled: inactive tabs' overlays
  ///   suppress themselves (paint-probe) and reappear on return.
  /// - Assistive tech gets route parity: the open detail scopes as a
  ///   route, everything it covers leaves the semantics tree
  ///   (`BlockSemantics` — the Drawer/ModalBarrier primitive), and
  ///   `DismissIntent` (Escape on desktop) dismisses when the focus is
  ///   inside the detail.
  /// - Breakpoint crossings with an open detail: a discrete jump (fold,
  ///   rotation, split-screen snap) grows the detail out of its pane to
  ///   full width; a continuous window drag tracks the hand — no motion.
  ///
  /// Pick for full-screen details with instant resize morphs, when the
  /// page's own snackbars/FABs are not needed while a detail is open.
  overlay,

  /// Detail is pushed as a REAL page route on the Navigator.
  ///
  /// - Covers everything — it is a page. Which navigator via
  ///   `CompactConfig.useRootNavigator`.
  /// - Back belongs to the route: Android predictive back, iOS/macOS
  ///   edge swipe, and the transition animation all come from the
  ///   app's `PageTransitionsTheme` — platform behavior updates arrive
  ///   with Flutter upgrades. The package's slide/swipe machinery and
  ///   `CompactConfig.handleBackGesture` are not used. There is no
  ///   swipe-anywhere dismissal; the platform decides the gesture.
  /// - Snackbars behave like normal page navigation: an in-progress
  ///   snackbar re-homes into the detail's `Scaffold` (give the detail
  ///   one to receive them), per `ScaffoldMessenger`'s standard rules.
  /// - Every push runs Flutter's Hero scan over the shell — multiple
  ///   `FloatingActionButton`s under one page need explicit `heroTag`s.
  /// - State is still preserved across resizes: the detail element
  ///   reparents between the route and the expanded pane. Hidden
  ///   kept-alive tabs remove their route (selection and state kept)
  ///   and restore it instantly when shown again.
  /// - Breakpoint crossings with an open detail: a discrete jump (fold,
  ///   rotation, split-screen snap) plays the route's REAL entrance over
  ///   the list; a continuous window drag pushes with zero entrance —
  ///   tracking the hand, not animating against it.
  ///
  /// Pick when the detail should feel like native navigation and evolve
  /// with the platform's back-gesture conventions.
  route,
}
