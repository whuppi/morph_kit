import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:adaptive_layouts/src/core/shared/expanded_entry_style.dart';
import 'package:adaptive_layouts/src/core/shared/pane_anchor.dart';
import 'package:adaptive_layouts/src/core/shared/pane_resize_mode.dart';
import 'package:adaptive_layouts/src/core/shared/pane_width_memory.dart';

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
    this.entryStyle = ExpandedEntryStyle.reveal,
    this.widthMemory = PaneWidthMemory.persist,
    this.settleDuration = const Duration(milliseconds: 220),
    this.settleCurve = Curves.easeOutCubic,
    this.dividerHitWidth = 24,
    this.collapseOnDoubleTap = false,
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

  /// How the list pane arrives when a breakpoint crossing enters the
  /// expanded layout with an open detail.
  final ExpandedEntryStyle entryStyle;

  /// Whether a dragged divider position survives compact spells.
  final PaneWidthMemory widthMemory;

  /// Duration of the snap-to-anchor settle after a divider drag.
  final Duration settleDuration;

  /// Curve of the snap-to-anchor settle after a divider drag.
  final Curve settleCurve;

  /// Width of the divider's drag hit zone, centered on the pane border.
  final double dividerHitWidth;

  /// Double-tapping the divider toggles the pane collapsed and back —
  /// the macOS split-view gesture; Material's equivalent is pane
  /// expansion anchors at the edges. Collapse animates to
  /// [minListWidth], so a TRUE collapse needs `minListWidth: 0`
  /// (drag-to-collapse additionally needs `maxListRatio: 1.0` and edge
  /// anchors to reach the other side). Restoring returns to the
  /// pre-collapse position, or [defaultListWidth] when there is none.
  final bool collapseOnDoubleTap;

  /// Sensible defaults for a standard list-detail layout.
  static const standard = PaneConfig();

  /// Standard defaults with list-detail anchor points.
  static const withAnchors = PaneConfig(anchors: PaneAnchor.listDetail);

  // Value equality: layouts compare configs to decide whether to REBUILD
  // their width model. Identity comparison resets the user's dragged
  // divider on every rebuild for apps that construct the config inline.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaneConfig &&
          other.defaultListWidth == defaultListWidth &&
          other.minListWidth == minListWidth &&
          other.maxListRatio == maxListRatio &&
          listEquals(other.anchors, anchors) &&
          other.initialAnchorIndex == initialAnchorIndex &&
          other.resizeMode == resizeMode &&
          other.entryStyle == entryStyle &&
          other.widthMemory == widthMemory &&
          other.settleDuration == settleDuration &&
          other.settleCurve == settleCurve &&
          other.dividerHitWidth == dividerHitWidth &&
          other.collapseOnDoubleTap == collapseOnDoubleTap;

  @override
  int get hashCode => Object.hash(
    defaultListWidth,
    minListWidth,
    maxListRatio,
    Object.hashAll(anchors),
    initialAnchorIndex,
    resizeMode,
    entryStyle,
    widthMemory,
    settleDuration,
    settleCurve,
    dividerHitWidth,
    collapseOnDoubleTap,
  );
}
