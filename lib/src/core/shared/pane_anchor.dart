import 'package:flutter/foundation.dart';

/// Snap point for tablet pane divider positioning.
///
/// Defines where the divider can snap to when the user finishes dragging.
/// Supports proportional (% of width) and fixed offset (dp from edge) anchors.
///
/// ```dart
/// // 50% split
/// PaneAnchor.proportion(0.5)
///
/// // 240dp from the start edge
/// PaneAnchor.fromStart(240)
///
/// // 240dp from the end edge
/// PaneAnchor.fromEnd(240)
/// ```
@immutable
class PaneAnchor {
  const PaneAnchor._({required this.proportion, required this.startOffset});

  /// Anchor at a proportion of available width.
  ///
  /// [value] must be between 0.0 and 1.0.
  const PaneAnchor.proportion(double value)
    : this._(proportion: value, startOffset: double.nan);

  /// Anchor at a fixed offset from the start edge.
  const PaneAnchor.fromStart(double offset)
    : this._(proportion: double.nan, startOffset: offset);

  /// Anchor at a fixed offset from the end edge.
  const PaneAnchor.fromEnd(double offset)
    : this._(proportion: double.nan, startOffset: -offset);

  /// Proportion of available width (0.0–1.0).
  /// [double.nan] when using offset instead.
  final double proportion;

  /// Fixed offset in logical pixels from the start edge.
  /// Negative values indicate offset from the end edge.
  /// [double.nan] when using proportion instead.
  final double startOffset;

  /// Whether this anchor uses a proportion (vs fixed offset).
  bool get isProportion => !proportion.isNaN;

  /// Resolves this anchor to a pixel position for the given [availableWidth].
  double resolve(double availableWidth) {
    if (isProportion) {
      return availableWidth * proportion;
    }
    if (startOffset >= 0) {
      return startOffset;
    }
    // Negative = from end
    return availableWidth + startOffset;
  }

  /// Standard list-detail anchors:
  /// collapsed, 240dp from start, 50% split, 240dp from end, fully expanded.
  static const listDetail = [
    PaneAnchor.proportion(0.0),
    PaneAnchor.fromStart(240),
    PaneAnchor.proportion(0.5),
    PaneAnchor.fromEnd(240),
    PaneAnchor.proportion(1.0),
  ];

  // NaN is the "unused" sentinel and NaN == NaN is false — plain field
  // comparison would make every offset anchor unequal to itself.
  static bool _sameField(double a, double b) => (a.isNaN && b.isNaN) || a == b;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaneAnchor &&
          runtimeType == other.runtimeType &&
          _sameField(proportion, other.proportion) &&
          _sameField(startOffset, other.startOffset);

  @override
  int get hashCode => Object.hash(proportion, startOffset);
}
