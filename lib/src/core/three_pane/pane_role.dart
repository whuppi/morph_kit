/// A pane's role in a multi-pane layout, carrying its display priority.
///
/// When the window has fewer partitions than panes, the highest-priority
/// panes win the slots (the Material adaptive scaffold model: primary
/// content survives longest, tertiary/extra panes yield first). Roles
/// decide WHO shows; the pane list's order decides WHERE.
enum PaneRole {
  /// The main content. Last pane standing on the narrowest windows.
  primary(10),

  /// Supporting content (a list, an outline, a sidebar). Appears from
  /// two partitions up.
  secondary(5),

  /// Extra content (an inspector, metadata, a preview). Appears only
  /// when a third partition is available.
  tertiary(1);

  const PaneRole(this.priority);

  /// Higher wins a partition slot when slots are scarce.
  final int priority;
}
