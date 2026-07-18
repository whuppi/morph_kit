import 'package:adaptive_layouts/src/core/shared/pane_config.dart';
import 'package:adaptive_layouts/src/core/shared/pane_resize_mode.dart';

/// Pure width/drag/snap logic for a draggable pane divider.
///
/// Shared by `ListDetailLayout` and `AdaptiveSplit` so both widgets resize,
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
  PaneWidthModel(this.config, {required this.referenceWidth});

  /// The pane configuration this model applies.
  final PaneConfig config;

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

  /// The pane's current width in pixels, clamped for [availableWidth].
  double width(double availableWidth) {
    _ensureInitialized(availableWidth);
    final raw = _isRatioMode ? availableWidth * _ratio! : _pixels!;
    return _clamp(raw, availableWidth);
  }

  /// Applies a horizontal drag delta (already direction-corrected for RTL).
  void drag(double delta, double availableWidth) {
    _ensureInitialized(availableWidth);
    if (_isRatioMode) {
      _ratio = (_ratio! + delta / availableWidth).clamp(
        config.minListWidth / availableWidth,
        config.maxListRatio,
      );
    } else {
      _pixels = _clamp(_pixels! + delta, availableWidth);
    }
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
