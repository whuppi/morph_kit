import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'package:adaptive_layouts/src/core/modal/modal_layout_mode.dart';

/// The surface visuals of one modal form, resolved from the app theme so
/// the flight starts and ends looking like the real route chrome.
class ModalFormVisuals {
  /// Creates a resolved set of surface visuals.
  const ModalFormVisuals({
    required this.shape,
    required this.color,
    required this.elevation,
  });

  /// Resolves the visuals for [mode] from [theme], mirroring the Material
  /// defaults `Dialog` and `BottomSheet` use when the theme sets nothing.
  factory ModalFormVisuals.of(ThemeData theme, ModalLayoutMode mode) {
    switch (mode) {
      case ModalLayoutMode.dialog:
        return ModalFormVisuals(
          shape:
              theme.dialogTheme.shape ??
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          color:
              theme.dialogTheme.backgroundColor ??
              theme.colorScheme.surfaceContainerHigh,
          elevation: theme.dialogTheme.elevation ?? 6,
        );
      case ModalLayoutMode.sheet:
        return ModalFormVisuals(
          shape:
              theme.bottomSheetTheme.shape ??
              const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
          color:
              theme.bottomSheetTheme.modalBackgroundColor ??
              theme.bottomSheetTheme.backgroundColor ??
              theme.colorScheme.surfaceContainerLow,
          elevation:
              theme.bottomSheetTheme.modalElevation ??
              theme.bottomSheetTheme.elevation ??
              1,
        );
    }
  }

  /// Surface shape (all-corner radius for dialogs, top radius for sheets).
  final ShapeBorder shape;

  /// Surface color.
  final Color color;

  /// Surface elevation.
  final double elevation;

  /// The visuals at fraction [t] between [a] and [b].
  static ModalFormVisuals lerp(
    ModalFormVisuals a,
    ModalFormVisuals b,
    double t,
  ) {
    return ModalFormVisuals(
      shape: ShapeBorder.lerp(a.shape, b.shape, t) ?? b.shape,
      color: Color.lerp(a.color, b.color, t) ?? b.color,
      elevation: lerpDouble(a.elevation, b.elevation, t) ?? b.elevation,
    );
  }
}

/// One in-flight container transform between the modal's two forms.
///
/// During a form swap the live content element mounts here — an overlay
/// entry above the routes — while the destination route lays out with a
/// same-size placeholder. The flight lerps a surface (rect, shape, color,
/// elevation) from the outgoing form's geometry to the placeholder's LIVE
/// geometry, tracked every frame so keyboard insets, route entrance
/// motion, and content reflow all steer the landing. On arrival the
/// content reparents into the route and the flight disposes.
///
/// The sizing handshake that makes the landing seamless — one quantity
/// flows each way, so there is no feedback loop: the destination reports
/// the width it OFFERS (the placeholder's incoming constraints, via
/// [reportDestinationMaxWidth]); the flight lays the content out at that
/// width from the first frame and reports the resulting size to
/// [contentSize]; the placeholder adopts that size, and its global rect —
/// the true final geometry — is the flight target throughout.
class ModalMorphFlight {
  /// Starts a flight. The controller runs immediately.
  ModalMorphFlight({
    required this.overlay,
    required Rect startRect,
    required ModalFormVisuals start,
    required ModalFormVisuals end,
    required Duration duration,
    required this.curve,
    required this.contentBuilder,
    required VoidCallback onCompleted,
    required this.targetMode,
  }) : _startRect = startRect,
       _start = start,
       _end = end,
       contentSize = ValueNotifier<Size>(startRect.size) {
    _controller =
        AnimationController(
            vsync: const _FlightTickerProvider(),
            duration: duration,
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) onCompleted();
          })
          ..forward().ignore();
  }

  /// The navigator's overlay — flight host and coordinate space.
  final OverlayState overlay;

  /// Builds the live content (the session's keyed subtree).
  final WidgetBuilder contentBuilder;

  /// Flight timing curve.
  final Curve curve;

  /// The form being flown toward. Updated on retarget.
  ModalLayoutMode targetMode;

  /// Marks the destination route's placeholder so its live rect can be
  /// tracked as the flight target.
  final GlobalKey placeholderKey = GlobalKey(
    debugLabel: 'modal morph placeholder',
  );

  /// The content's laid-out size, reported from the flight one frame
  /// behind layout. The destination placeholder mirrors it.
  final ValueNotifier<Size> contentSize;

  /// The width the destination offers its content slot, reported from the
  /// placeholder's incoming constraints. The flight lays the content out
  /// at this width so the reported [contentSize] is the true final size —
  /// laying it out at the lerped container width instead is circular, and
  /// the circle has a wrong fixed point (a sheet that wraps to the
  /// dialog's width, then snaps wide after landing).
  double? _destinationMaxWidth;

  /// Called from the placeholder's `LayoutBuilder` during layout — plain
  /// field write, read on the controller's next tick.
  void reportDestinationMaxWidth(double width) {
    if (width.isFinite && width > 0) _destinationMaxWidth = width;
  }

  late final AnimationController _controller;
  Rect _startRect;
  ModalFormVisuals _start;
  ModalFormVisuals _end;
  Rect? _lastTargetRect;
  OverlayEntry? _entry;

  double get _t => curve.transform(_controller.value);

  /// The surface rect at this moment of the flight.
  Rect currentRect() {
    final target = _placeholderRect() ?? _lastTargetRect ?? _startRect;
    _lastTargetRect = target;
    return Rect.lerp(_startRect, target, _t) ?? target;
  }

  /// Inserts the flight into the overlay, above the routes.
  void insert() {
    final entry = OverlayEntry(builder: _build);
    _entry = entry;
    overlay.insert(entry);
  }

  /// Redirects a flight already in the air: the current visual state
  /// becomes the new start, and the controller restarts toward [end].
  void retarget({
    required ModalFormVisuals end,
    required ModalLayoutMode mode,
  }) {
    _startRect = currentRect();
    _start = ModalFormVisuals.lerp(_start, _end, _t);
    _end = end;
    targetMode = mode;
    _lastTargetRect = null;
    _destinationMaxWidth = null;
    unawaited(_controller.forward(from: 0));
    _entry?.markNeedsBuild();
  }

  /// Stops the flight and removes it from the overlay. The caller flips
  /// the session's morphing flag in the same synchronous block so the
  /// content reparents into the destination route this frame.
  void dispose() {
    _controller
      ..stop()
      ..dispose();
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    // contentSize is deliberately not disposed: the destination's
    // placeholder may still be unsubscribing during the handoff frame.
  }

  Rect? _placeholderRect() {
    final box = placeholderKey.currentContext?.findRenderObject();
    final overlayBox = overlay.context.findRenderObject();
    if (box is! RenderBox || overlayBox is! RenderBox) return null;
    if (!box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
  }

  Widget _build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final rect = currentRect();
        final visuals = ModalFormVisuals.lerp(_start, _end, _t);
        return Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: IgnorePointer(
                child: Material(
                  clipBehavior: Clip.antiAlias,
                  shape: visuals.shape,
                  color: visuals.color,
                  elevation: visuals.elevation,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minWidth: 0,
                    maxWidth: _destinationMaxWidth ?? rect.width,
                    minHeight: 0,
                    maxHeight: maxHeight,
                    child: _MeasureSize(
                      onSize: (size) {
                        if (contentSize.value != size) contentSize.value = size;
                      },
                      child: contentBuilder(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Standalone ticker source: the flight outlives any single route's State,
/// and tying the controller to the navigator's ticker would assert on app
/// teardown if a flight were mid-air.
class _FlightTickerProvider implements TickerProvider {
  const _FlightTickerProvider();

  @override
  Ticker createTicker(TickerCallback onTick) =>
      Ticker(onTick, debugLabel: 'ModalMorphFlight');
}

/// Reports the child's laid-out size, deferred to post-frame (notifying
/// listeners during layout is illegal).
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onSize, super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onSize);

  ValueChanged<Size> onSize;
  Size? _lastReported;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _lastReported) return;
    _lastReported = size;
    final reported = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(reported);
    });
  }
}
