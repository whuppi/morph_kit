/// How the list pane arrives when a breakpoint crossing enters the
/// expanded layout with an open detail.
///
/// The yielding detail resizes live in both styles: its first frame is
/// exactly the full-width layout compact just showed, so there is no
/// jump — the styles differ only in how the ARRIVING list is laid out.
enum ExpandedEntryStyle {
  /// The list is laid out at its final width and slides in clipped —
  /// its content never reflows during the entry. The way desktop
  /// sidebars arrive (macOS Finder, Mail).
  reveal,

  /// The list is laid out at the animated width each frame and reflows
  /// as it grows into its pane.
  resize,
}
