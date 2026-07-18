import 'package:adaptive_layouts/src/core/shared/pane_anchor.dart';
import 'package:adaptive_layouts/src/core/shared/pane_resize_mode.dart';

/// Expanded-layout pane configuration for `ListDetailLayout`.
///
/// Pure data — no builders, no UI. Reusable across future pane-based widgets.
///
/// ```dart
/// ListDetailLayout(
///   paneConfig: PaneConfig(
///     defaultListWidth: 400,
///     anchors: PaneAnchor.listDetail,
///   ),
///   ...
/// )
/// ```
class PaneConfig {
  /// Creates an expanded-layout pane configuration.
  const PaneConfig({
    this.defaultListWidth = 360,
    this.minListWidth = 200,
    this.maxListRatio = 0.5,
    this.anchors = const [],
    this.initialAnchorIndex = 1,
    this.resizeMode = PaneResizeMode.ratio,
  });

  /// Default width of the list pane in logical pixels.
  final double defaultListWidth;

  /// Minimum width the list pane can be resized to.
  final double minListWidth;

  /// Maximum proportion (0.0–1.0) the list pane can occupy.
  final double maxListRatio;

  /// Anchor points for divider snapping. Empty = free dragging.
  ///
  /// On drag end the divider animates to the nearest anchor. Anchor positions
  /// are still clamped by [minListWidth] and [maxListRatio] — an anchor
  /// outside that range settles at the clamp boundary.
  final List<PaneAnchor> anchors;

  /// Index into [anchors] for the width on first render.
  /// Ignored when [anchors] is empty.
  final int initialAnchorIndex;

  /// How pane width is stored after dragging.
  final PaneResizeMode resizeMode;

  /// Sensible defaults for a standard list-detail layout.
  static const standard = PaneConfig();

  /// Standard defaults with list-detail anchor points.
  static const withAnchors = PaneConfig(anchors: PaneAnchor.listDetail);
}
