/// What happens to a user-dragged divider position when the expanded
/// layout goes away and comes back (a compact spell, a tab trip).
enum PaneWidthMemory {
  /// The dragged position is remembered — proportionally in
  /// `PaneResizeMode.ratio`, absolutely in `PaneResizeMode.pixels`.
  persist,

  /// Every return to the expanded layout starts fresh from
  /// `PaneConfig.defaultListWidth` (or the initial anchor). Drags apply
  /// only within one expanded spell.
  resetOnReentry,
}
