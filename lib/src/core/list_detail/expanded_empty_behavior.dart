/// What the expanded layout does with the detail slot when nothing is
/// selected.
///
/// Two of the three established list-detail patterns are layout
/// decisions and live here. The third — auto-selecting the first item so
/// the pane is never empty (Notes, Slack, Settings apps) — is a data
/// decision the app makes with its controller: select an item when the
/// list loads and nothing is selected.
enum ExpandedEmptyBehavior {
  /// The detail pane is always present; without a selection it shows
  /// `emptyStateBuilder`. The Apple Mail / Outlook reading-pane shape.
  placeholder,

  /// The list owns the full width until a selection summons the detail
  /// pane, which reveals from the end edge; dismissing hands the width
  /// back. The Material "supporting pane" shape (Gmail without a
  /// reading pane). `emptyStateBuilder` is not used.
  listOnly,
}
