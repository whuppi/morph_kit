import 'package:flutter/widgets.dart';

/// Configuration for `showAdaptiveModal`.
///
/// Deliberately thin: the modal is presented by Flutter's own `DialogRoute`
/// and `ModalBottomSheetRoute`, so chrome, theming, drag physics, and
/// accessibility all come from Material. Most fields only forward to the
/// matching parameters on those routes; the `morph*` fields drive the
/// container transform played when a resize swaps the two forms.
///
/// ```dart
/// showAdaptiveModal(
///   context: context,
///   config: const ModalConfig(showDragHandle: true),
///   builder: (context, mode) => MyModalContent(),
/// )
/// ```
class ModalConfig {
  /// Creates a modal configuration.
  const ModalConfig({
    this.backgroundColor,
    this.barrierDismissible = true,
    this.barrierColor,
    this.barrierLabel,
    this.useSafeArea = true,
    this.isScrollControlled = true,
    this.enableDrag = true,
    this.showDragHandle,
    this.constraints,
    this.scrollControlDisabledMaxHeightRatio,
    this.anchorPoint,
    this.traversalEdgeBehavior,
    this.requestFocus,
    this.animationStyle,
    this.sheetAnimationStyle,
    this.morph = true,
    this.morphDuration = const Duration(milliseconds: 350),
    this.morphCurve = Curves.easeInOutCubicEmphasized,
  });

  /// Surface color for BOTH forms, overriding each form's theme
  /// resolution — Material's defaults give dialogs and sheets different
  /// surface tones (`surfaceContainerHigh` vs `surfaceContainerLow`);
  /// set this when the modal should keep one color across the morph.
  /// `null` keeps each form's own themed color (the flight crossfades
  /// between them).
  final Color? backgroundColor;

  /// Whether tapping the barrier dismisses the modal. Both forms.
  final bool barrierDismissible;

  /// Color of the barrier behind the modal. Both forms.
  /// `null` uses each route's Material default.
  final Color? barrierColor;

  /// Whether the dialog form avoids system intrusions (status bar, notches).
  /// Forwards to `DialogRoute.useSafeArea`.
  final bool useSafeArea;

  /// Whether the sheet form may grow to the full window height.
  /// Forwards to `ModalBottomSheetRoute.isScrollControlled`.
  ///
  /// Defaults to true (unlike `showModalBottomSheet`) so content gets the
  /// same height freedom in both forms.
  final bool isScrollControlled;

  /// Whether the sheet form can be dragged down to dismiss.
  /// Forwards to `ModalBottomSheetRoute.enableDrag`.
  final bool enableDrag;

  /// Whether the sheet form shows Material's drag handle.
  /// Forwards to `ModalBottomSheetRoute.showDragHandle`;
  /// `null` defers to `BottomSheetThemeData.showDragHandle`.
  final bool? showDragHandle;

  // The fields below are pure passthroughs to the matching parameter on
  // Flutter's own routes, under Flutter's own name — null always means
  // "Flutter's default". Visual styling (shape, elevation, drag-handle
  // look) is deliberately NOT here: it flows through DialogThemeData /
  // BottomSheetThemeData, the channel that evolves with the platform.
  // Also deliberately withheld: `clipBehavior` on the sheet (pinned to
  // Clip.antiAlias — the container transform's landing is pixel-matched
  // against it) and `transitionAnimationController` (the swap machinery
  // owns the routes' lifecycles).

  /// Semantic label for the barrier, read by screen readers.
  /// Forwards to both routes' `barrierLabel`.
  final String? barrierLabel;

  /// Size constraints for the sheet form.
  /// Forwards to `ModalBottomSheetRoute.constraints`.
  final BoxConstraints? constraints;

  /// Max height ratio for the sheet form when [isScrollControlled] is
  /// false. Forwards to
  /// `ModalBottomSheetRoute.scrollControlDisabledMaxHeightRatio`.
  final double? scrollControlDisabledMaxHeightRatio;

  /// Anchor for display-feature (fold / multi-screen) positioning.
  /// Forwards to both routes' `anchorPoint`.
  final Offset? anchorPoint;

  /// Focus-traversal behavior at the dialog's edges.
  /// Forwards to `DialogRoute.traversalEdgeBehavior`.
  final TraversalEdgeBehavior? traversalEdgeBehavior;

  /// Whether opening the modal moves focus into it.
  /// Forwards to both routes' `requestFocus`.
  final bool? requestFocus;

  /// Entrance/exit animation styling for the dialog form. Forwards to
  /// `DialogRoute.animationStyle`. Applies to the FIRST entrance and
  /// exits; breakpoint swaps keep their internal zero-duration override
  /// (the modal is already visually present).
  final AnimationStyle? animationStyle;

  /// Entrance/exit animation styling for the sheet form. Forwards to
  /// `ModalBottomSheetRoute.sheetAnimationStyle`. Same swap override as
  /// [animationStyle].
  final AnimationStyle? sheetAnimationStyle;

  /// Whether a form swap plays a container transform — the surface glides
  /// and reshapes from one form's geometry to the other's, with the live
  /// content inside. When false, the swap is an instant cut.
  final bool morph;

  /// Duration of the container transform.
  final Duration morphDuration;

  /// Curve of the container transform.
  final Curve morphCurve;
}
