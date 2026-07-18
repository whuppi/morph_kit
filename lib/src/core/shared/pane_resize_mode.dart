/// How pane width is stored after the user drags the divider.
enum PaneResizeMode {
  /// Fixed pixel width — stays the same size when window resizes.
  pixels,

  /// Proportional ratio — scales when window resizes.
  ratio,
}
