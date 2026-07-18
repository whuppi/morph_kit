import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

// =============================================================================
// PAINT VISIBILITY DETECTOR
//
// Solves: OverlayPortal stacking when multiple ListDetailLayout instances
// are mounted simultaneously but only one is actively painted (e.g.
// tab-based navigation with state preservation).
//
// Problem: OverlayPortal renders outside the parent's paint boundary.
// When a parent (any kind — IndexedStack, Offstage, Visibility, custom)
// stops painting this widget, the overlay entry remains visible.
//
// Solution: Two-phase detection using paint() as the universal signal.
//
//   HIDE (zero frame lag):
//     LayoutBuilder calls [evaluate]. This checks [_wasPaintedLastFrame].
//     If false → the widget wasn't painted in the previous frame →
//     set [notifier] to false immediately. Works because layout runs
//     AFTER the previous frame's paint, so the flag is settled.
//
//   SHOW (one frame lag):
//     When paint resumes (tab became active), [PaintVisibilityObserver.paint]
//     fires → sets [_wasPaintedLastFrame] = true → defers notifier update
//     via postFrameCallback (can't set notifier during paint). Next frame's
//     layout sees the flag and the overlay rebuilds.
//
// This is fully generic — works with any parent that stops painting children
// (IndexedStack, Offstage, Visibility, custom RenderObjects). No dependency
// on specific widget types.
// =============================================================================

/// Tracks whether a widget is being actively painted by the framework.
///
/// Exposes a [notifier] consumed by [ValueListenableBuilder] in overlays.
///
/// See [PaintVisibilityObserver] for the paint-trigger widget.
class PaintVisibilityDetector {
  /// Whether this widget is currently being painted.
  final ValueNotifier<bool> notifier = ValueNotifier<bool>(true);

  /// Set by `PaintVisibilityObserver.paint`, read by [evaluate].
  /// Represents whether paint() fired in the most recent frame.
  bool _wasPaintedLastFrame = true;

  bool _postFrameScheduled = false;

  /// Called from LayoutBuilder (layout phase).
  ///
  /// Checks whether paint() fired in the previous frame. If not, the widget
  /// is not being painted → set [notifier] to false immediately (zero lag).
  /// If yes, ensure [notifier] is true.
  void evaluate() {
    if (notifier.value != _wasPaintedLastFrame) {
      notifier.value = _wasPaintedLastFrame;
    }
    // Reset for next frame — if paint doesn't fire, stays false.
    _wasPaintedLastFrame = false;
  }

  /// Whether paint fired since the last [evaluate] reset. Route mode's
  /// one-shot post-frame check peeks this AFTER a frame whose build ran
  /// [evaluate]: the reset-then-paint ordering makes the flag a true
  /// painted-this-frame signal for exactly that frame. Read-only —
  /// [evaluate] owns the reset.
  bool get paintedThisFrame => _wasPaintedLastFrame;

  /// Called by [PaintVisibilityObserver] during paint.
  ///
  /// Marks this detector as painted. If transitioning from not-painted to
  /// painted (re-activation), defers the notifier update to a post-frame
  /// callback to avoid "build scheduled during frame" assertion.
  void _onPaint() {
    _wasPaintedLastFrame = true;

    if (!notifier.value && !_postFrameScheduled) {
      _postFrameScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _postFrameScheduled = false;
        if (_wasPaintedLastFrame && !notifier.value) {
          notifier.value = true;
        }
      });
    }
  }

  /// Releases the notifier.
  void dispose() {
    notifier.dispose();
  }
}

// =============================================================================
// PAINT TRIGGER WIDGET
// =============================================================================

/// Wraps a child and notifies a [PaintVisibilityDetector] when painted.
///
/// Place this around the content whose paint status you want to track.
/// When a parent stops painting this widget (e.g. inactive IndexedStack
/// child, Offstage, Visibility), paint() stops firing and the detector
/// knows the widget is invisible.
class PaintVisibilityObserver extends SingleChildRenderObjectWidget {
  /// Creates an observer that reports paints to [detector].
  const PaintVisibilityObserver({
    super.key,
    required this.detector,
    required super.child,
  });

  /// The detector to notify on paint.
  final PaintVisibilityDetector detector;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderPaintVisibilityObserver(detector);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPaintVisibilityObserver renderObject,
  ) {
    renderObject.detector = detector;
  }
}

/// Render object that notifies [PaintVisibilityDetector] during paint.
class RenderPaintVisibilityObserver extends RenderProxyBox {
  /// Creates the render object reporting to [detector].
  RenderPaintVisibilityObserver(this.detector);

  /// The detector to notify on paint.
  PaintVisibilityDetector detector;

  @override
  void paint(PaintingContext context, Offset offset) {
    detector._onPaint();
    super.paint(context, offset);
  }
}
