import 'package:flutter/animation.dart';

/// Compact-layout configuration for `ListDetailLayout`.
///
/// Controls animation, gestures, back behavior, and overlay strategy
/// when the layout is in compact (mobile) mode. Pure data — no animation
/// objects, no UI.
///
/// ```dart
/// ListDetailLayout(
///   compactConfig: CompactConfig(
///     duration: Duration(milliseconds: 200),
///     curve: Curves.easeOut,
///   ),
///   ...
/// )
/// ```
class CompactConfig {
  /// Creates a compact-layout configuration.
  const CompactConfig({
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
    this.dismissThreshold = 0.3,
    this.dismissVelocity = 500,
    this.detailBackground,
    this.handleBackGesture = true,
    this.useRootOverlay = false,
  });

  /// Duration of the slide open/close animation.
  final Duration duration;

  /// Curve for the slide animation.
  final Curve curve;

  /// Fraction of screen width (0.0–1.0) that must be dragged to dismiss.
  final double dismissThreshold;

  /// Minimum velocity (px/s) for a fling gesture to dismiss.
  final double dismissVelocity;

  /// Background color for the detail pane in compact layout.
  ///
  /// When the detail slides over the list, it needs an opaque background
  /// so the list behind isn't visible through the content.
  ///
  /// - `null` (default): uses `Theme.of(context).colorScheme.surface` at render time
  /// - Explicit color: uses that color (e.g. `Colors.transparent` for peek-through)
  ///
  /// This only affects compact layout. In expanded (side-by-side) layout,
  /// each pane fills its own bounded area — no overlap, no background needed.
  final Color? detailBackground;

  /// Whether to intercept the back gesture in compact layout to dismiss detail.
  /// When true, wraps the compact layout in `PopScope`.
  /// Applies to both `CompactDetailMode.inline` and `CompactDetailMode.overlay`.
  final bool handleBackGesture;

  /// Which `Overlay` to render in when using `CompactDetailMode.overlay`.
  ///
  /// When false (default), renders in the nearest `Overlay` — typically the
  /// Navigator's overlay. Covers siblings (bottom nav, tab bars) but not
  /// ancestors above the Navigator (app bars, persistent banners).
  ///
  /// When true, renders in the root `Overlay` — covers the entire screen.
  ///
  /// Same convention as [Overlay.of(context, rootOverlay:)] and
  /// [Navigator.of(context, rootNavigator:)].
  ///
  /// Ignored when `CompactDetailMode.inline` is used.
  final bool useRootOverlay;
}
