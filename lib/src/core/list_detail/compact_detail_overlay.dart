import 'package:flutter/material.dart';

/// Manages showing the detail pane as an overlay in compact (mobile) layout.
///
/// Uses [OverlayPortal] to render the detail in an ancestor [Overlay],
/// covering sibling widgets like bottom nav while keeping the widget
/// in the tree (state preserved).
///
/// Used internally by `ListDetailLayout` when
/// `CompactDetailMode.overlay` is set.
class CompactDetailOverlay {
  /// The portal controller — shown once, never hidden (see [show]).
  final OverlayPortalController controller = OverlayPortalController();

  /// Show the detail overlay.
  ///
  /// Called ONCE after the first frame and never hidden again — the overlay
  /// child collapses to nothing when there is no detail to show. Toggling
  /// the portal on layout transitions would trip
  /// [OverlayPortalController]'s assertion against show/hide during layout.
  void show() {
    if (!controller.isShowing) controller.show();
  }

  /// Build the [OverlayPortal] wrapper for the list pane.
  ///
  /// The list is the [child]. The detail is rendered in the overlay
  /// via [overlayChildBuilder] when `controller.show` is called.
  ///
  /// When [useRootOverlay] is false (default), renders in the nearest
  /// [Overlay] (typically the Navigator's). When true, renders in the
  /// root [Overlay] — covers the entire screen including app bars.
  /// Same convention as [Overlay.of] and [Navigator.of].
  Widget buildPortal({
    required Widget child,
    required Widget Function() overlayChildBuilder,
    bool useRootOverlay = false,
  }) {
    return OverlayPortal(
      controller: controller,
      overlayLocation: useRootOverlay
          ? OverlayChildLocation.rootOverlay
          : OverlayChildLocation.nearestOverlay,
      overlayChildBuilder: (_) => overlayChildBuilder(),
      child: child,
    );
  }
}
