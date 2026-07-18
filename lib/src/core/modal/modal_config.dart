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
    this.useSafeArea = true,
    this.isScrollControlled = true,
    this.enableDrag = true,
    this.showDragHandle,
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

  /// Whether a form swap plays a container transform — the surface glides
  /// and reshapes from one form's geometry to the other's, with the live
  /// content inside. When false, the swap is an instant cut.
  final bool morph;

  /// Duration of the container transform.
  final Duration morphDuration;

  /// Curve of the container transform.
  final Curve morphCurve;
}
