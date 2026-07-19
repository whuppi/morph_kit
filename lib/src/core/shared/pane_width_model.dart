import 'package:adaptive_layouts/src/core/shared/pane_collapse.dart';
import 'package:adaptive_layouts/src/core/shared/pane_config.dart';
import 'package:adaptive_layouts/src/core/shared/pane_resize_mode.dart';

/// Pure width/drag/snap logic for a draggable pane divider.
///
/// Shared by `ListDetailLayout` and `SplitLayout` so both widgets resize,
/// clamp, and anchor-snap identically. Owns no animation — the widget drives
/// the settle animation and feeds interpolated widths back via [setWidth].
///
/// Width is stored per [PaneConfig.resizeMode]:
/// - [PaneResizeMode.ratio] — a proportion; the pane scales with the window.
/// - [PaneResizeMode.pixels] — a pixel width; the pane stays fixed when the
///   window resizes.
///
/// All reads go through [width], which applies the [PaneConfig.minListWidth]
/// and [PaneConfig.maxListRatio] clamps — including for anchor positions, so
/// an anchor outside the clamp range settles at the clamp boundary.
class PaneWidthModel {
  /// Creates a width model for [config].
  PaneWidthModel(
    this.config, {
    required this.referenceWidth,
    PaneCollapsible? collapsible,
  }) : collapsible = collapsible ?? config.collapsible;

  /// The pane configuration this model applies.
  final PaneConfig config;

  /// Which sides may collapse, in MODEL space (start = the pane this
  /// model's width measures). Layouts whose measured pane isn't on the
  /// directional start (`SplitLayout` with an end-positioned primary)
  /// pass a flipped value so [PaneConfig.collapsible] stays directional.
  final PaneCollapsible collapsible;

  /// The width [PaneConfig.defaultListWidth] is converted against in ratio
  /// mode — the layout's expanded breakpoint (the minimum expanded width).
  /// On wider windows the pane scales up proportionally from there.
  final double referenceWidth;

  /// Stored proportion (ratio mode) — null until initialized.
  double? _ratio;

  /// Stored pixel width (pixels mode) — null until initialized.
  double? _pixels;

  bool get _isRatioMode => config.resizeMode == PaneResizeMode.ratio;

  /// Lazily initializes the stored width on first use.
  ///
  /// With anchors configured, the initial width comes from
  /// [PaneConfig.initialAnchorIndex] resolved against the actual
  /// [availableWidth]. Without anchors, it comes from
  /// [PaneConfig.defaultListWidth] — converted to a proportion of
  /// [referenceWidth] in ratio mode, so the pane scales with the window.
  void _ensureInitialized(double availableWidth) {
    if (_ratio != null || _pixels != null) return;

    if (config.anchors.isNotEmpty) {
      final index = config.initialAnchorIndex.clamp(
        0,
        config.anchors.length - 1,
      );
      final initialWidth = config.anchors[index].resolve(availableWidth);
      if (_isRatioMode) {
        _ratio = initialWidth / availableWidth;
      } else {
        _pixels = initialWidth;
      }
      return;
    }

    if (_isRatioMode) {
      _ratio = config.defaultListWidth / referenceWidth;
    } else {
      _pixels = config.defaultListWidth;
    }
  }

  double _clamp(double widthPx, double availableWidth) {
    final max = availableWidth * config.maxListRatio;
    // A narrow window can push the max below the min; min wins so the pane
    // never collapses under minListWidth.
    if (max <= config.minListWidth) return config.minListWidth;
    return widthPx.clamp(config.minListWidth, max);
  }

  // ---------------------------------------------------------------------------
  // Collapse (desktop split-view semantics)
  //
  // A collapsible pane snaps to `config.collapsedSize` when the divider is
  // forced past its limit by half the pane's minimum size, live during the
  // drag and reversible mid-drag. The pre-collapse width is cached so a
  // restore returns exactly where the user was. The parked divider stays
  // draggable.
  // ---------------------------------------------------------------------------

  /// The collapsed pane, or null when both panes are visible.
  PaneSide? get collapsed => _collapsed;
  PaneSide? _collapsed;

  /// Pixel width to restore to when un-collapsing.
  double? _cachedWidth;

  /// The un-clamped drag position of the current gesture, in start-pane
  /// pixels. Null when no drag is active.
  double? _rawDragWidth;

  /// The maximum start-pane width for [availableWidth].
  double _maxWidth(double availableWidth) {
    final max = availableWidth * config.maxListRatio;
    return max <= config.minListWidth ? config.minListWidth : max;
  }

  /// Overshoot needed past a limit before the pane snaps collapsed —
  /// half the pane's minimum size (the desktop split-view threshold).
  double _collapseThreshold(PaneSide side, double availableWidth) {
    final paneMin = side == PaneSide.start
        ? config.minListWidth
        : availableWidth - _maxWidth(availableWidth);
    return paneMin / 2;
  }

  /// The pane's current width in pixels, clamped for [availableWidth].
  ///
  /// When a pane is collapsed the width is parked: `collapsedSize` for a
  /// collapsed start pane, `availableWidth - collapsedSize` for a
  /// collapsed end pane. The clamps do not apply to parked widths.
  double width(double availableWidth) {
    switch (_collapsed) {
      case PaneSide.start:
        return config.collapsedSize;
      case PaneSide.end:
        return availableWidth - config.collapsedSize;
      case null:
        _ensureInitialized(availableWidth);
        final raw = _isRatioMode ? availableWidth * _ratio! : _pixels!;
        return _clamp(raw, availableWidth);
    }
  }

  /// Starts a drag gesture: caches the width a restore should return to
  /// and seeds the un-clamped drag position.
  void dragStart(double availableWidth) {
    _rawDragWidth = width(availableWidth);
    if (_collapsed == null) _cachedWidth = _rawDragWidth;
  }

  /// Applies a horizontal drag delta (already direction-corrected for RTL).
  ///
  /// Tracks the un-clamped position so a collapsible pane can snap
  /// collapsed when forced past its limit — and snap back when the drag
  /// returns, exactly like desktop split views.
  void drag(double delta, double availableWidth) {
    _ensureInitialized(availableWidth);
    // Overshoot accumulates only within a started gesture ([dragStart]).
    // A bare drag() call is its own micro-gesture measured from the
    // current width — repeated calls never carry clamp overshoot over.
    final gestureActive = _rawDragWidth != null;
    final raw = (_rawDragWidth ?? width(availableWidth)) + delta;
    if (gestureActive) _rawDragWidth = raw;
    final min = config.minListWidth;
    final max = _maxWidth(availableWidth);

    if (collapsible.allows(PaneSide.start) &&
        raw < min - _collapseThreshold(PaneSide.start, availableWidth)) {
      _collapsed = PaneSide.start;
      return;
    }
    if (collapsible.allows(PaneSide.end) &&
        raw > max + _collapseThreshold(PaneSide.end, availableWidth)) {
      _collapsed = PaneSide.end;
      return;
    }
    _collapsed = null;

    if (_isRatioMode) {
      _ratio = (raw / availableWidth).clamp(
        min / availableWidth,
        config.maxListRatio,
      );
    } else {
      _pixels = _clamp(raw, availableWidth);
    }
  }

  /// Ends a drag gesture.
  void dragEnd() {
    _rawDragWidth = null;
  }

  /// Collapses [side] programmatically, caching the current width for
  /// [restoreTarget]. No-op when [collapsible] disallows it.
  void collapse(PaneSide side, double availableWidth) {
    if (!collapsible.allows(side) || _collapsed == side) return;
    _cachedWidth = width(availableWidth);
    _collapsed = side;
  }

  /// Un-collapses without animating. The widget usually animates to
  /// [restoreTarget] instead and calls this when the settle lands.
  void restore(double availableWidth) {
    if (_collapsed == null) return;
    _collapsed = null;
    setWidth(
      _clamp(_cachedWidth ?? config.defaultListWidth, availableWidth),
      availableWidth,
    );
  }

  /// The width a restore animation should settle to.
  double restoreTarget(double availableWidth) =>
      _clamp(_cachedWidth ?? config.defaultListWidth, availableWidth);

  /// The configured default width (the divider's double-click reset
  /// target): the initial anchor when anchors are configured, else
  /// [PaneConfig.defaultListWidth] under the resize-mode conversion.
  double defaultWidth(double availableWidth) {
    if (config.anchors.isNotEmpty) {
      final index = config.initialAnchorIndex.clamp(
        0,
        config.anchors.length - 1,
      );
      return _clamp(
        config.anchors[index].resolve(availableWidth),
        availableWidth,
      );
    }
    final raw = _isRatioMode
        ? availableWidth * (config.defaultListWidth / referenceWidth)
        : config.defaultListWidth;
    return _clamp(raw, availableWidth);
  }

  /// Sets the width to an exact pixel value (used by the settle animation).
  void setWidth(double widthPx, double availableWidth) {
    if (_isRatioMode) {
      _ratio = widthPx / availableWidth;
    } else {
      _pixels = widthPx;
    }
  }

  /// The width the divider should settle to after a drag, or null when no
  /// snapping applies (no anchors configured, or already at the target).
  ///
  /// Picks the anchor whose clamped position is nearest to the current width.
  double? snapTarget(double availableWidth) {
    if (config.anchors.isEmpty) return null;

    final current = width(availableWidth);
    double? nearest;
    var nearestDistance = double.infinity;
    for (final anchor in config.anchors) {
      final position = _clamp(anchor.resolve(availableWidth), availableWidth);
      final distance = (position - current).abs();
      if (distance < nearestDistance) {
        nearest = position;
        nearestDistance = distance;
      }
    }

    if (nearest == null || nearestDistance < 0.5) return null;
    return nearest;
  }
}
