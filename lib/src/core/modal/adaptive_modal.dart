import 'dart:async';

import 'package:flutter/material.dart';

import 'package:adaptive_layouts/src/core/modal/modal_config.dart';
import 'package:adaptive_layouts/src/core/modal/modal_layout_mode.dart';
import 'package:adaptive_layouts/src/core/modal/modal_morph.dart';
import 'package:adaptive_layouts/src/core/shared/adaptive_layout_config.dart';

/// Signature for building the modal's content.
///
/// [mode] is the current presentation form. To keep state across a live
/// form change, return the same root widget type for both modes — the
/// content is moved between the two routes under a stable key, and a
/// different root type would defeat the move.
typedef AdaptiveModalBuilder =
    Widget Function(BuildContext context, ModalLayoutMode mode);

/// Shows a modal that presents as a real Material dialog on expanded
/// widths and a real Material bottom sheet on compact widths — and
/// live-swaps between the two when the window is resized across the
/// breakpoint, preserving the content widget's state.
///
/// The two forms are Flutter's own [DialogRoute] and
/// [ModalBottomSheetRoute], so barrier semantics, theming
/// ([DialogThemeData], [BottomSheetThemeData]), drag-to-dismiss physics,
/// back handling, and accessibility labels are all Material's — not
/// re-implementations. On a resize across the breakpoint the active route
/// is atomically replaced (no exit/entrance animation) and the content
/// element is reparented into the new route in the same frame.
///
/// The returned future completes with the pop result when the modal is
/// dismissed, no matter how many form swaps happened in between.
///
/// ```dart
/// final choice = await showAdaptiveModal<String>(
///   context: context,
///   builder: (context, mode) => SettingsSheet(
///     showCloseButton: mode == ModalLayoutMode.dialog,
///   ),
/// );
/// ```
///
/// The dialog form wraps the content in a [Dialog]; the sheet form lets
/// [ModalBottomSheetRoute] provide its [BottomSheet]. The breakpoint
/// resolves at call time: [expandedBreakpoint] param > inherited
/// [AdaptiveLayoutConfig] > 720.
Future<T?> showAdaptiveModal<T>({
  required BuildContext context,
  required AdaptiveModalBuilder builder,
  ModalConfig config = const ModalConfig(),
  double? expandedBreakpoint,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final session = _ModalSession<T>(
    navigator: navigator,
    builder: builder,
    config: config,
    breakpoint: AdaptiveLayoutConfig.resolveBreakpoint(
      context,
      expandedBreakpoint,
    ),
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    settings: routeSettings,
  );
  return session.open(MediaQuery.sizeOf(context).width);
}

/// One open modal: owns the content key, the active route, and the
/// result future across route swaps.
class _ModalSession<T> {
  _ModalSession({
    required this.navigator,
    required this.builder,
    required this.config,
    required this.breakpoint,
    required this.themes,
    required this.settings,
  });

  final NavigatorState navigator;
  final AdaptiveModalBuilder builder;
  final ModalConfig config;
  final double breakpoint;
  final CapturedThemes themes;
  final RouteSettings? settings;

  /// Anchors the content element so it reparents between routes on swap.
  final GlobalKey _contentKey = GlobalKey();

  /// Proxies the pop result: the caller awaits this single future while
  /// the underlying route may be replaced any number of times.
  final Completer<T?> _result = Completer<T?>();

  Route<T?>? _active;
  ModalLayoutMode? _activeMode;

  /// True while the active sheet route is the chrome-less ghost a flight
  /// lands on; the landing replaces it with a normally-chromed route.
  bool _activeIsGhost = false;
  bool _swapScheduled = false;

  /// The in-flight container transform, when a swap is morphing.
  ModalMorphFlight? _flight;

  /// Drives the routes' content slot: placeholder while a flight holds
  /// the content, the keyed content otherwise.
  final ValueNotifier<bool> _morphing = ValueNotifier<bool>(false);

  Future<T?> open(double width) {
    _push(_modeFor(width), animate: true);
    return _result.future;
  }

  ModalLayoutMode _modeFor(double width) =>
      width >= breakpoint ? ModalLayoutMode.dialog : ModalLayoutMode.sheet;

  /// Pushes the route for [mode]. On swap, [removeFirst] is the outgoing
  /// route — removed AFTER `_active` points at the new route, so the old
  /// route's completion is recognized as stale by the identity guard, and
  /// BEFORE the push, so both changes land in one frame (the content's
  /// reparent window).
  void _push(
    ModalLayoutMode mode, {
    required bool animate,
    Route<T?>? removeFirst,
    bool ghost = false,
  }) {
    final route = _buildRoute(mode, animate: animate, ghost: ghost);
    _active = route;
    _activeMode = mode;
    _activeIsGhost = ghost && mode == ModalLayoutMode.sheet;
    unawaited(
      route.popped.then((value) {
        // Identity guard: a swapped-out route also completes (with null)
        // when removed — only the currently-active route's completion is
        // the user dismissing the modal.
        if (identical(route, _active) && !_result.isCompleted) {
          // A dismissal mid-flight lands the content into the exiting
          // route immediately, so the exit animation shows it.
          _endFlight();
          _result.complete(value);
        }
      }),
    );
    if (removeFirst != null) navigator.removeRoute(removeFirst);
    unawaited(navigator.push(route));
  }

  /// Called from the content's build when the window width no longer
  /// matches the presented form. Navigation can't run during build, so
  /// the swap is deferred to after the frame.
  void _requestSwap() {
    if (_swapScheduled) return;
    _swapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _swapScheduled = false;
      if (_result.isCompleted || !navigator.mounted) return;
      final active = _active;
      if (active == null) return;
      // Re-derive from the live width — it may have crossed back during
      // the frame the swap waited on.
      final target = _modeFor(MediaQuery.sizeOf(navigator.context).width);
      if (target == _activeMode) return;
      final morphing = config.morph && _beginOrRetargetFlight(target);
      _push(target, animate: false, removeFirst: active, ghost: morphing);
    });
  }

  /// The drag-handle decision for the REAL sheet route, mirroring
  /// `BottomSheet`'s own resolution so ghost spacing and flight replica
  /// match what lands.
  bool _effectiveShowDragHandle(ThemeData theme) =>
      config.showDragHandle ??
      (config.enableDrag && (theme.bottomSheetTheme.showDragHandle ?? false));

  /// The vertical offset between a form's surface and its content: the
  /// drag-handle band for a handle-showing sheet, 0 otherwise.
  double _contentInsetFor(ModalLayoutMode mode, ThemeData theme) =>
      mode == ModalLayoutMode.sheet && _effectiveShowDragHandle(theme)
      ? kMinInteractiveDimension
      : 0;

  /// Launches the container transform for a swap toward [target] — or, if
  /// a flight is already in the air (the window crossed back mid-morph),
  /// redirects it from its current visual state. Runs BEFORE the route
  /// swap while `_activeMode` is still the outgoing form and the content
  /// (in the outgoing route or the existing flight) is still measurable.
  /// Returns whether a flight is airborne; false bails to the instant cut.
  bool _beginOrRetargetFlight(ModalLayoutMode target) {
    final overlay = navigator.overlay;
    if (overlay == null) return false;
    final theme = Theme.of(navigator.context);
    final end = ModalFormVisuals.of(theme, target);

    final flight = _flight;
    if (flight != null) {
      flight.retarget(
        end: end,
        mode: target,
        contentInsetEnd: _contentInsetFor(target, theme),
      );
      return true;
    }

    final outgoingMode = _activeMode;
    final box = _contentKey.currentContext?.findRenderObject();
    final overlayBox = overlay.context.findRenderObject();
    if (outgoingMode == null) return false;
    if (box is! RenderBox || overlayBox is! RenderBox) return false;
    if (!box.attached || !box.hasSize) return false;
    final startRect =
        box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;

    _flight = ModalMorphFlight(
      overlay: overlay,
      startRect: startRect,
      start: ModalFormVisuals.of(theme, outgoingMode),
      end: end,
      duration: config.morphDuration,
      curve: config.morphCurve,
      targetMode: target,
      contentInsetStart: _contentInsetFor(outgoingMode, theme),
      contentInsetEnd: _contentInsetFor(target, theme),
      handleColor:
          theme.bottomSheetTheme.dragHandleColor ??
          theme.colorScheme.onSurfaceVariant,
      handleSize: theme.bottomSheetTheme.dragHandleSize ?? const Size(32, 4),
      // The Builder sits ABOVE the key: the subtree from the keyed node
      // down must be identical in every host (routes and flight), or the
      // reparent degrades into a rebuild and state dies.
      contentBuilder: (context) => themes.wrap(
        Builder(
          builder: (context) {
            final flight = _flight;
            return KeyedSubtree(
              key: _contentKey,
              child: builder(
                context,
                flight == null ? target : flight.targetMode,
              ),
            );
          },
        ),
      ),
      // Land one frame after arrival so the placeholder has adopted the
      // content's final reported size — the handoff is then pixel-clean.
      onCompleted: () {
        final flight = _flight;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (identical(flight, _flight)) _endFlight(landed: true);
        });
      },
    );
    _morphing.value = true;
    _flight!.insert();
    return true;
  }

  /// Hands the content from the flight into the active route's slot and
  /// tears the flight down — all in one synchronous block, so the element
  /// moves in a single frame. A [landed] flight over a ghost sheet also
  /// replaces the ghost with the normally-chromed route in that same
  /// block, so the real chrome appears exactly under the flight's final,
  /// identical-looking frame.
  void _endFlight({bool landed = false}) {
    final flight = _flight;
    if (flight == null) return;
    if (landed && _activeIsGhost) {
      final ghost = _active;
      _push(ModalLayoutMode.sheet, animate: false, removeFirst: ghost);
    }
    _morphing.value = false;
    _flight = null;
    flight.dispose();
  }

  Route<T?> _buildRoute(
    ModalLayoutMode mode, {
    required bool animate,
    bool ghost = false,
  }) {
    // Swap pushes skip the entrance animation (the modal is already
    // visually present); exits keep Material's timing either way.
    final style = animate ? null : AnimationStyle(duration: Duration.zero);
    switch (mode) {
      case ModalLayoutMode.dialog:
        return DialogRoute<T>(
          context: navigator.context,
          builder: (context) => _ModalScope<T>(session: this, mode: mode),
          themes: themes,
          barrierColor: config.barrierColor ?? Colors.black54,
          barrierDismissible: config.barrierDismissible,
          useSafeArea: config.useSafeArea,
          settings: settings,
          animationStyle: style,
        );
      case ModalLayoutMode.sheet:
        // The ghost variant a flight lands on: chrome-less (transparent
        // surface, no handle, no drag) but with the REAL barrier and the
        // real layout machinery, so scrim continuity and target tracking
        // hold while nothing of the destination is visible before the
        // flight becomes it.
        return ModalBottomSheetRoute<T>(
          builder: (context) => _ModalScope<T>(session: this, mode: mode),
          capturedThemes: themes,
          isScrollControlled: config.isScrollControlled,
          modalBarrierColor: config.barrierColor,
          isDismissible: config.barrierDismissible,
          enableDrag: ghost ? false : config.enableDrag,
          showDragHandle: ghost ? false : config.showDragHandle,
          backgroundColor: ghost ? Colors.transparent : null,
          elevation: ghost ? 0 : null,
          clipBehavior: Clip.antiAlias,
          settings: settings,
          sheetAnimationStyle: style,
        );
    }
  }
}

/// Per-route content: watches the window width, requests a swap on a
/// breakpoint crossing, and mounts the user's content under the session's
/// stable key.
class _ModalScope<T> extends StatelessWidget {
  const _ModalScope({required this.session, required this.mode});

  final _ModalSession<T> session;
  final ModalLayoutMode mode;

  @override
  Widget build(BuildContext context) {
    if (session._modeFor(MediaQuery.sizeOf(context).width) != mode) {
      session._requestSwap();
    }
    // While a flight holds the content, the route lays out a same-size
    // placeholder instead — its live rect is the flight's landing target,
    // and only one holder of the content key exists per frame.
    return ValueListenableBuilder<bool>(
      valueListenable: session._morphing,
      builder: (context, morphing, _) {
        final flight = session._flight;
        final ghosting = morphing && flight != null;
        final Widget content;
        if (ghosting) {
          // The LayoutBuilder reports the width this slot OFFERS, so the
          // flight can lay the content out at its true final width — the
          // placeholder then mirrors the resulting size back. The spacer
          // stands in for the drag-handle band the ghost route omits, so
          // the placeholder sits exactly where the content will land.
          final inset = session._contentInsetFor(mode, Theme.of(context));
          content = LayoutBuilder(
            builder: (context, constraints) {
              flight.reportDestinationMaxWidth(constraints.maxWidth);
              final placeholder = ValueListenableBuilder<Size>(
                valueListenable: flight.contentSize,
                builder: (context, size, _) =>
                    SizedBox.fromSize(key: flight.placeholderKey, size: size),
              );
              if (inset == 0) return placeholder;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: inset),
                  placeholder,
                ],
              );
            },
          );
        } else {
          content = KeyedSubtree(
            key: session._contentKey,
            child: session.builder(context, mode),
          );
        }
        if (mode != ModalLayoutMode.dialog) return content;
        // antiAlias (not Material's default Clip.none) so corner rendering
        // at rest matches the flight's clipped surface — content painting
        // near the corners would otherwise pop square at the handoff. The
        // ghost variant is fully invisible: the flight IS the dialog until
        // landing, when this same widget rebuilds with real chrome.
        return ghosting
            ? Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                shadowColor: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                child: content,
              )
            : Dialog(clipBehavior: Clip.antiAlias, child: content);
      },
    );
  }
}
