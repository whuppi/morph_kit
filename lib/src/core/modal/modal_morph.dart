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
    required this.shadowColor,
  });

  /// Resolves the visuals for [mode] from [theme], mirroring the Material
  /// defaults `Dialog` and `BottomSheet` use when the theme sets nothing.
  factory ModalFormVisuals.of(
    ThemeData theme,
    ModalLayoutMode mode, {
    Color? backgroundColor,
  }) {
    switch (mode) {
      case ModalLayoutMode.dialog:
        return ModalFormVisuals(
          shape:
              theme.dialogTheme.shape ??
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          color:
              backgroundColor ??
              theme.dialogTheme.backgroundColor ??
              theme.colorScheme.surfaceContainerHigh,
          elevation: theme.dialogTheme.elevation ?? 6,
          shadowColor: theme.dialogTheme.shadowColor ?? Colors.transparent,
        );
      case ModalLayoutMode.sheet:
        return ModalFormVisuals(
          shape:
              theme.bottomSheetTheme.shape ??
              const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
          color:
              backgroundColor ??
              theme.bottomSheetTheme.modalBackgroundColor ??
              theme.bottomSheetTheme.backgroundColor ??
              theme.colorScheme.surfaceContainerLow,
          elevation:
              theme.bottomSheetTheme.modalElevation ??
              theme.bottomSheetTheme.elevation ??
              1,
          shadowColor: theme.bottomSheetTheme.shadowColor ?? Colors.transparent,
        );
    }
  }

  /// Surface shape (all-corner radius for dialogs, top radius for sheets).
  final ShapeBorder shape;

  /// Surface color.
  final Color color;

  /// Surface elevation.
  final double elevation;

  /// Shadow color — transparent by Material 3 default for both forms, so
  /// the flight casts exactly the shadow the real chrome does (none,
  /// unless the theme opts in).
  final Color shadowColor;

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
      shadowColor: Color.lerp(a.shadowColor, b.shadowColor, t) ?? b.shadowColor,
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
/// The sizing contract that makes the landing seamless without a
/// feedback loop: the content is laid out at the CONTAINER's lerped width
/// (so it reflows with the morph instead of being cropped by it), while
/// the placeholder's width follows each form's convention — the slot
/// decides for full-bleed sheets, the content decides for dialogs — and
/// only the HEIGHT flows from the flight's measurement ([contentSize]).
/// The placeholder's global rect — the true final geometry — is the
/// flight target throughout.
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
    required double contentInsetStart,
    required double contentInsetEnd,
    required this.handleColor,
    required this.handleSize,
  }) : _startRect = startRect,
       _start = start,
       _end = end,
       _insetStart = contentInsetStart,
       _insetEnd = contentInsetEnd,
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

  /// Drag-handle replica visuals, resolved from the theme the way
  /// `BottomSheet` resolves them.
  final Color handleColor;

  /// See [handleColor].
  final Size handleSize;

  /// Marks the destination route's placeholder so its live rect can be
  /// tracked as the flight target.
  final GlobalKey placeholderKey = GlobalKey(
    debugLabel: 'modal morph placeholder',
  );

  /// The content's laid-out size, reported from the flight one frame
  /// behind layout. The destination placeholder mirrors it.
  final ValueNotifier<Size> contentSize;

  /// The content's natural width, sampled ONCE from the first flight
  /// layout (laid loose): a content narrower than its container decides
  /// its own width; one that fills the container is full-bleed. After the
  /// sample the content is laid TIGHT at the container's lerped width so
  /// it reflows with the morph — the frozen sample (not the live, now
  /// container-driven measure) feeds the placeholder's width, which is
  /// what breaks the width feedback circle.
  double? get naturalWidth => _naturalWidth;
  double? _naturalWidth;

  /// Whether the sampled content fills whatever width it is given.
  bool get isFullBleed => _isFullBleed;
  bool _isFullBleed = false;
  bool _widthSampled = false;

  void _recordSample(Size size, double containerWidth) {
    if (_widthSampled) return;
    _widthSampled = true;
    _isFullBleed = size.width >= containerWidth - 0.5;
    _naturalWidth = size.width;
  }

  late final AnimationController _controller;
  Rect _startRect;
  ModalFormVisuals _start;
  ModalFormVisuals _end;

  /// Vertical space between the surface's top edge and the content — the
  /// drag-handle band (`kMinInteractiveDimension`) when that endpoint is a
  /// handle-showing sheet, 0 otherwise. The tracked rects are CONTENT
  /// rects; the painted surface extends above them by the lerped inset.
  double _insetStart;
  double _insetEnd;
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
    required double contentInsetEnd,
  }) {
    _startRect = currentRect();
    _start = ModalFormVisuals.lerp(_start, _end, _t);
    _insetStart = lerpDouble(_insetStart, _insetEnd, _t) ?? _insetEnd;
    _insetEnd = contentInsetEnd;
    _end = end;
    targetMode = mode;
    _lastTargetRect = null;
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
        final t = _t;
        final visuals = ModalFormVisuals.lerp(_start, _end, t);
        final inset = lerpDouble(_insetStart, _insetEnd, t) ?? _insetEnd;
        // The tracked rect is the CONTENT rect; the surface extends above
        // it by the handle band of whichever endpoint(s) have one.
        final surfaceRect = Rect.fromLTRB(
          rect.left,
          rect.top - inset,
          rect.right,
          rect.bottom,
        );
        final handleOpacity = switch ((_insetStart > 0, _insetEnd > 0)) {
          (true, true) => 1.0,
          (false, true) => t,
          (true, false) => 1.0 - t,
          (false, false) => 0.0,
        };
        return Stack(
          children: [
            Positioned.fromRect(
              rect: surfaceRect,
              child: IgnorePointer(
                child: Material(
                  // Material implicitly animates shape/elevation changes
                  // over ~200ms. The flight IS the animation — without
                  // zero here Material's internal tween lags the lerp and
                  // the corners pop at landing.
                  animationDuration: Duration.zero,
                  clipBehavior: Clip.antiAlias,
                  shape: visuals.shape,
                  color: visuals.color,
                  elevation: visuals.elevation,
                  shadowColor: visuals.shadowColor,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: inset),
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          // First layout is loose to sample the content's
                          // natural width; then tight so the content
                          // shrinks/grows WITH the container instead of
                          // jumping to its destination width at takeoff.
                          minWidth: _widthSampled ? rect.width : 0,
                          maxWidth: rect.width,
                          minHeight: 0,
                          maxHeight: maxHeight,
                          child: _MeasureSize(
                            onSize: (size) {
                              _recordSample(size, rect.width);
                              if (contentSize.value != size) {
                                contentSize.value = size;
                              }
                            },
                            child: contentBuilder(context),
                          ),
                        ),
                      ),
                      if (handleOpacity > 0)
                        Opacity(
                          opacity: handleOpacity,
                          child: SizedBox(
                            height: kMinInteractiveDimension,
                            child: Center(
                              child: Container(
                                width: handleSize.width,
                                height: handleSize.height,
                                decoration: BoxDecoration(
                                  color: handleColor,
                                  borderRadius: BorderRadius.circular(
                                    handleSize.height / 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
