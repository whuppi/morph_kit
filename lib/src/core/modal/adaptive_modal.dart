import 'dart:async';

import 'package:flutter/material.dart';

import 'package:adaptive_layouts/src/core/modal/modal_config.dart';
import 'package:adaptive_layouts/src/core/modal/modal_layout_mode.dart';
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
  bool _swapScheduled = false;

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
  }) {
    final route = _buildRoute(mode, animate: animate);
    _active = route;
    _activeMode = mode;
    unawaited(
      route.popped.then((value) {
        // Identity guard: a swapped-out route also completes (with null)
        // when removed — only the currently-active route's completion is
        // the user dismissing the modal.
        if (identical(route, _active) && !_result.isCompleted) {
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
      _push(target, animate: false, removeFirst: active);
    });
  }

  Route<T?> _buildRoute(ModalLayoutMode mode, {required bool animate}) {
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
        return ModalBottomSheetRoute<T>(
          builder: (context) => _ModalScope<T>(session: this, mode: mode),
          capturedThemes: themes,
          isScrollControlled: config.isScrollControlled,
          modalBarrierColor: config.barrierColor,
          isDismissible: config.barrierDismissible,
          enableDrag: config.enableDrag,
          showDragHandle: config.showDragHandle,
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
    final content = KeyedSubtree(
      key: session._contentKey,
      child: session.builder(context, mode),
    );
    return mode == ModalLayoutMode.dialog ? Dialog(child: content) : content;
  }
}
