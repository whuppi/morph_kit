import 'dart:async';

import 'package:flutter/material.dart';

import 'package:adaptive_layouts/src/core/list_detail/compact_config.dart';
import 'package:adaptive_layouts/src/core/list_detail/compact_detail_overlay.dart';
import 'package:adaptive_layouts/src/core/list_detail/detail_layout_mode.dart';
import 'package:adaptive_layouts/src/core/list_detail/detail_page_route.dart';
import 'package:adaptive_layouts/src/core/list_detail/list_detail_controller.dart';
import 'package:adaptive_layouts/src/core/list_detail/paint_visibility_detector.dart';
import 'package:adaptive_layouts/src/core/shared/adaptive_layout_config.dart';
import 'package:adaptive_layouts/src/core/shared/divider_builder.dart';
import 'package:adaptive_layouts/src/core/shared/pane_config.dart';
import 'package:adaptive_layouts/src/core/shared/pane_width_model.dart';

part 'list_detail_layout_builders.dart';

// =============================================================================
// BUILDER TYPEDEFS
// =============================================================================

/// Builder for the list pane.
///
/// [selectedId] is the currently selected item (null if none).
/// [onSelect] selects an item — same as calling `controller.select(id)`.
typedef ListPaneBuilder<T> =
    Widget Function(
      BuildContext context,
      T? selectedId,
      ValueChanged<T> onSelect,
    );

/// Builder for the detail pane.
///
/// [id] is the selected item (never null — only called when selected).
/// [mode] indicates the layout: [DetailLayoutMode.stacked] (compact, full width)
/// or [DetailLayoutMode.sideBySide] (expanded, shared width).
/// [onDismiss] closes the detail — same as calling `controller.dismiss()`.
typedef DetailPaneBuilder<T> =
    Widget Function(
      BuildContext context,
      T id,
      DetailLayoutMode mode,
      VoidCallback onDismiss,
    );

// DividerBuilder is in shared/typedefs.dart — re-exported from barrel.

// =============================================================================
// WIDGET
// =============================================================================

/// Adaptive list-detail layout that morphs between compact and expanded modes.
///
/// - **Compact** (below [expandedBreakpoint]): list fills the screen, detail
///   slides over from the start edge with swipe-to-dismiss.
/// - **Expanded** (at or above [expandedBreakpoint]): side-by-side panes with
///   a draggable divider and anchor snapping.
///
/// ## Controller
///
/// Provide a [ListDetailController] for programmatic selection control and
/// router integration. If omitted, a default controller is created internally
/// (like [ScrollController]).
///
/// ## Builders
///
/// [dividerBuilder] and [emptyStateBuilder] are null by default.
/// Provide your own, or use a shipped component from the components layer.
///
/// ```dart
/// ListDetailLayout(
///   listBuilder: (context, selectedId, onSelect) => MyList(onTap: onSelect),
///   detailBuilder: (context, id, mode, onDismiss) => MyDetail(id: id),
/// )
/// ```
class ListDetailLayout<T> extends StatefulWidget {
  /// Creates an adaptive list-detail layout.
  const ListDetailLayout({
    super.key,
    this.controller,
    required this.listBuilder,
    required this.detailBuilder,
    this.emptyStateBuilder,
    this.dividerBuilder,
    this.expandedBreakpoint,
    this.paneConfig = const PaneConfig(),
    this.compactConfig = const CompactConfig(),
    this.compactDetailMode = CompactDetailMode.inline,
  });

  /// Controller for selection state. If null, creates one internally.
  final ListDetailController<T>? controller;

  /// Builder for the list pane.
  final ListPaneBuilder<T> listBuilder;

  /// Builder for the detail pane (only called when an item is selected).
  final DetailPaneBuilder<T> detailBuilder;

  /// Builder for the empty state shown in expanded layout when nothing is selected.
  /// Null by default (shows empty space). Use a shipped component or your own.
  final WidgetBuilder? emptyStateBuilder;

  /// Builder for the expanded-layout pane divider.
  /// Null by default (invisible drag zone). Use a shipped component or your own.
  final DividerBuilder? dividerBuilder;

  /// Width breakpoint for compact ↔ expanded switch.
  /// If null, reads from [AdaptiveLayoutConfig] ancestor, then falls back to 720.
  final double? expandedBreakpoint;

  /// Expanded-layout pane configuration (widths, anchors, resize behavior).
  final PaneConfig paneConfig;

  /// Compact-layout configuration (animation, gestures, back behavior, overlay).
  final CompactConfig compactConfig;

  /// How the detail pane is placed in compact layout.
  ///
  /// [CompactDetailMode.inline] (default): detail renders inline within the
  /// widget tree. Does NOT cover sibling widgets (bottom nav, tab bars).
  /// Recommended for most use cases.
  ///
  /// [CompactDetailMode.overlay]: detail renders in an ancestor [Overlay] via
  /// [OverlayPortal] — covers sibling widgets. Which overlay is controlled
  /// by [CompactConfig.useRootOverlay]. Widget state preserved via [GlobalKey].
  ///
  /// [CompactDetailMode.route]: detail is pushed as a REAL page route —
  /// the app's [PageTransitionsTheme] (platform transitions, predictive
  /// back, edge swipes) applies natively, and back is the route's own.
  /// The same [PaintVisibilityDetector] suppression applies: an unpainted
  /// instance (hidden tab) removes its route, keeping the selection, and
  /// re-pushes instantly when painted again.
  ///
  /// **Note on overlay mode with tabs:** When multiple overlay-mode instances
  /// are mounted simultaneously (e.g. tab navigation with state preservation),
  /// a [PaintVisibilityDetector] automatically suppresses inactive instances'
  /// overlays based on paint status. Hiding is zero-frame; re-showing has a
  /// one-frame delay when switching back. Works with any parent that stops
  /// painting inactive children (IndexedStack, Offstage, Visibility, etc.).
  ///
  /// Inline and overlay share the slide animation and swipe-to-dismiss
  /// gesture; route mode delegates both to the real route.
  final CompactDetailMode compactDetailMode;

  @override
  State<ListDetailLayout<T>> createState() => _ListDetailLayoutState<T>();
}

// =============================================================================
// STATE
// =============================================================================

class _ListDetailLayoutState<T> extends State<ListDetailLayout<T>>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // Controller — owned or external (same pattern as ScrollController)
  // ---------------------------------------------------------------------------

  ListDetailController<T>? _ownedController;
  ListDetailController<T> get _controller =>
      widget.controller ?? (_ownedController ??= ListDetailController<T>());

  /// Tracks whether this instance is the active painted child in an
  /// IndexedStack. Used to suppress overlay rendering for inactive tabs.
  final PaintVisibilityDetector _paintVisibility = PaintVisibilityDetector();

  // ---------------------------------------------------------------------------
  // Slide animation (compact layout — used by both inline and overlay modes)
  // ---------------------------------------------------------------------------

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // ---------------------------------------------------------------------------
  // Outgoing detail — keeps the detail widget alive during dismiss animation.
  //
  // Technique from Flutter's AnimatedSwitcher: when the current child changes,
  // the old child moves to _outgoingEntries and stays in the tree while its
  // exit animation plays. It's removed only on AnimationStatus.dismissed.
  // See: packages/flutter/lib/src/widgets/animated_switcher.dart
  //
  // _outgoingDetailId holds the ID of the detail that's animating out.
  // While non-null, the detail widget remains in the tree with this ID,
  // even though _controller.selectedId is already null.
  // ---------------------------------------------------------------------------

  /// ID of the detail animating out. Keeps the widget in the tree during
  /// the exit animation. Cleared on AnimationStatus.dismissed.
  /// (Same pattern as AnimatedSwitcher._outgoingEntries.)
  T? _outgoingDetailId;

  /// The last non-null selectedId seen from the controller. Used to seed
  /// [_outgoingDetailId] when the controller clears its selection externally
  /// (via controller.dismiss() without going through _handleDismiss).
  /// Without this, the outgoing ID would be lost before we can capture it.
  T? _lastSeenSelectedId;

  /// The ID to render in the detail pane: the current selection, or the
  /// outgoing ID during dismiss animation.
  T? get _visibleDetailId => _controller.selectedId ?? _outgoingDetailId;

  // ---------------------------------------------------------------------------
  // RTL support
  // ---------------------------------------------------------------------------

  TextDirection _textDirection = TextDirection.ltr;
  bool get _isRtl => _textDirection == TextDirection.rtl;

  // ---------------------------------------------------------------------------
  // Gesture tracking
  // ---------------------------------------------------------------------------

  // Compact layout swipe-to-dismiss
  double _dragExtent = 0;
  bool _isDragging = false;

  // Expanded layout divider drag — width/clamp/snap logic lives in the model;
  // this state owns only the gesture flags and the settle animation.
  late PaneWidthModel _paneWidth;
  bool _isDividerDragging = false;
  late AnimationController _settleController;
  bool get _isDividerSettling => _settleController.isAnimating;

  // ---------------------------------------------------------------------------
  // Detail widget state preservation across compact ↔ expanded transitions.
  // GlobalKey causes Flutter to reparent (move) the widget instead of
  // destroying and recreating it when the layout mode changes.
  // See: https://docs.flutter.dev/resources/inside-flutter
  // ---------------------------------------------------------------------------

  final GlobalKey _detailKey = GlobalKey();

  // ---------------------------------------------------------------------------
  // Overlay-based compact detail (CompactDetailMode.overlay)
  //
  // The overlay is shown ONCE in initState and never hidden. The overlay
  // child builder returns SizedBox.shrink() when in expanded mode or when
  // no detail is visible — zero cost, zero visual impact.
  //
  // This eliminates the need to call show()/hide() on layout transitions,
  // which avoids the OverlayPortalController assertion against toggling
  // during the layout phase. No addPostFrameCallback, no frame gap.
  // ---------------------------------------------------------------------------

  final CompactDetailOverlay _overlay = CompactDetailOverlay();

  /// Tracks whether we're currently in expanded layout.
  bool _isExpanded = false;

  bool get _useOverlay => widget.compactDetailMode == CompactDetailMode.overlay;

  // ---------------------------------------------------------------------------
  // Route-based compact detail (CompactDetailMode.route)
  //
  // The detail lives in a REAL page route. All navigation runs post-frame
  // through one reconciler (_syncDetailRoute). The detail key has exactly
  // one holder per frame: the route (via _detailRouted), the expanded pane,
  // or the one-frame bridge (buildCompactRouteList).
  // ---------------------------------------------------------------------------

  bool get _useRoute => widget.compactDetailMode == CompactDetailMode.route;

  /// The pushed detail route while active (not popping).
  DetailPageRoute? _detailRoute;

  /// A popped route still playing its real exit animation. Its subtree
  /// holds the detail key until the animation is dismissed — new pushes
  /// wait for it.
  DetailPageRoute? _exitingRoute;

  /// Captured at push time — the layout's context is unusable in dispose.
  NavigatorState? _routeNavigator;

  /// True while a route (active or exiting) owns the detail key; the
  /// expanded pane builds an empty slot meanwhile.
  final ValueNotifier<bool> _detailRouted = ValueNotifier<bool>(false);

  /// Render the detail inline (keyed) for the frame between a resize into
  /// compact (or a deep-link mount) and the instant route push — without
  /// it that frame flashes the bare list.
  bool _bridgeDetail = false;

  /// Next push skips the entrance animation (resize swap, deep link,
  /// paint re-show) — the detail was already visually present.
  bool _instantRoutePush = false;

  bool _routeSyncScheduled = false;
  bool _wasExpandedForBridge = false;
  bool _routePaintCheckArmed = false;

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: widget.compactConfig.duration,
    );
    _slideAnimation = _buildSlideAnimation();

    _paneWidth = PaneWidthModel(
      widget.paneConfig,
      referenceWidth: _referenceWidth,
    );
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _controller.addListener(_onControllerChanged);

    // If starting with a selection (e.g. deep link), show detail immediately
    // without animation — the user navigated directly to this state.
    if (_controller.hasSelection) {
      _slideController.value = 1.0;
      _lastSeenSelectedId = _controller.selectedId;
    }

    // In overlay mode, show the portal once and keep it showing forever.
    // The overlay child builder controls visibility via the slide animation
    // and _isExpanded flag — returning SizedBox.shrink() when invisible.
    if (_useOverlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _overlay.show();
      });
    }

    if (_useRoute) {
      // A mount with a selection (deep link) shows the detail from the
      // first frame via the bridge, then hands it to an instant push.
      _bridgeDetail = _controller.hasSelection;
      _instantRoutePush = _controller.hasSelection;
      _paintVisibility.notifier.addListener(_scheduleRouteSync);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newDirection = Directionality.of(context);
    if (newDirection != _textDirection) {
      _textDirection = newDirection;
      final currentValue = _slideController.value;
      _slideAnimation = _buildSlideAnimation();
      _slideController.value = currentValue;
    }
  }

  @override
  void didUpdateWidget(ListDetailLayout<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Controller changed — re-wire listener
    final oldController = oldWidget.controller ?? _ownedController;
    final newController = _controller;
    if (oldController != newController) {
      oldController?.removeListener(_onControllerChanged);
      newController.addListener(_onControllerChanged);
    }

    if (widget.compactConfig.duration != oldWidget.compactConfig.duration) {
      _slideController.duration = widget.compactConfig.duration;
    }
    if (widget.compactConfig.curve != oldWidget.compactConfig.curve) {
      _slideAnimation = _buildSlideAnimation();
    }
    if (!identical(widget.paneConfig, oldWidget.paneConfig)) {
      _settleController.stop();
      _paneWidth = PaneWidthModel(
        widget.paneConfig,
        referenceWidth: _referenceWidth,
      );
    }

    if (widget.compactDetailMode != oldWidget.compactDetailMode &&
        oldWidget.compactDetailMode == CompactDetailMode.route) {
      _teardownDetailRoute();
    }
  }

  /// Reference width for ratio conversion — the expanded breakpoint, since
  /// that is the minimum width the expanded layout can have.
  double get _referenceWidth =>
      widget.expandedBreakpoint ??
      AdaptiveLayoutConfig.defaultExpandedBreakpoint;

  @override
  void dispose() {
    if (_useRoute) _paintVisibility.notifier.removeListener(_scheduleRouteSync);
    _teardownDetailRoute();
    _controller.removeListener(_onControllerChanged);
    _ownedController?.dispose();
    _slideController.dispose();
    _settleController.dispose();
    _paintVisibility.dispose();
    super.dispose();
  }

  /// Removes any live route without animation. Used on dispose and on a
  /// compactDetailMode change away from route mode. Navigation is illegal
  /// while the tree is locked, so the removal is deferred a frame.
  void _teardownDetailRoute() {
    final orphan = _detailRoute ?? _exitingRoute;
    _detailRoute = null;
    _exitingRoute = null;
    _detailRouted.value = false;
    if (orphan == null) return;
    final navigator = _routeNavigator;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator != null && navigator.mounted && orphan.isActive) {
        navigator.removeRoute(orphan);
      }
    });
  }

  // ===========================================================================
  // SLIDE ANIMATION
  // ===========================================================================

  /// Builds the slide Tween with correct direction for RTL/LTR.
  /// In LTR, detail slides from the right. In RTL, from the left.
  Animation<Offset> _buildSlideAnimation() {
    return Tween<Offset>(
      begin: Offset(_isRtl ? -1 : 1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: widget.compactConfig.curve,
      ),
    );
  }

  // ===========================================================================
  // CONTROLLER → ANIMATION SYNC
  //
  // Maps data state changes from the controller to visual transitions.
  // The outgoing detail pattern ensures the detail widget stays in the tree
  // during the dismiss animation, matching AnimatedSwitcher's approach.
  //
  // Both inline and overlay modes use the same animation logic. The only
  // difference is WHERE the detail renders (inline Stack vs OverlayPortal).
  // ===========================================================================

  void _onControllerChanged() {
    if (_controller.selectedId != null) {
      _lastSeenSelectedId = _controller.selectedId;
    }

    // Route mode (compact): selection changes translate to route pushes and
    // pops in the reconciler — none of the slide machinery below applies.
    if (_useRoute && !_isExpanded) {
      _scheduleRouteSync();
      if (mounted) setState(() {});
      return;
    }

    final shouldBeOpen = _controller.hasSelection;
    final isCurrentlyOpen =
        _slideController.value > 0 || _slideController.isAnimating;

    if (shouldBeOpen && !isCurrentlyOpen) {
      // === ENTERING: detail was closed, now something is selected ===
      _outgoingDetailId = null;
      unawaited(_slideController.forward());
    } else if (!shouldBeOpen && isCurrentlyOpen) {
      // === EXITING: detail was open, selection cleared ===
      //
      // _outgoingDetailId may already be set by _handleDismiss (internal path:
      // back button, swipe). For external path (controller.dismiss() called
      // directly), _outgoingDetailId is null — fall back to _lastSeenSelectedId
      // which captured the ID before the controller cleared it.
      _outgoingDetailId ??= _lastSeenSelectedId;
      _controller.setAnimatingOut(true);
      unawaited(
        _slideController.reverse().then((_) {
          if (mounted) {
            setState(() => _outgoingDetailId = null);
            _controller.setAnimatingOut(false);
          }
        }),
      );
    }
    // SWITCHING (shouldBeOpen && isCurrentlyOpen with different ID):
    // No animation needed — just rebuild with the new ID.
    // (_lastSeenSelectedId tracking happens at the top of this method.)

    if (mounted) setState(() {});
  }

  // ===========================================================================
  // ROUTE MODE — the reconciler and its verbs
  // ===========================================================================

  void _armRoutePaintCheck() {
    if (_routePaintCheckArmed) return;
    _routePaintCheckArmed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routePaintCheckArmed = false;
      if (!mounted || _detailRoute == null) return;
      if (!_paintVisibility.paintedThisFrame &&
          _paintVisibility.notifier.value) {
        _paintVisibility.notifier.value = false;
        _scheduleRouteSync();
      }
    });
  }

  void _scheduleRouteSync() {
    if (!_useRoute || _routeSyncScheduled) return;
    _routeSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeSyncScheduled = false;
      if (mounted) _syncDetailRoute();
    });
    // The paint-probe listener fires inside another frame's post-frame
    // flush; post-frame callbacks don't schedule frames, so without this
    // the sync waits for a frame that may never come on an idle device.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Reconciles the pushed route with the desired state — the ONLY place
  /// route-mode navigation happens, always post-frame, never during build.
  void _syncDetailRoute() {
    // paintedThisFrame covers the frame where paint just resumed: the
    // notifier only flips true a deferred callback later, and waiting for
    // it costs extra frames of the inline bridge on screen.
    final painted =
        _paintVisibility.notifier.value || _paintVisibility.paintedThisFrame;
    final wantRoute = !_isExpanded && _controller.hasSelection && painted;
    final route = _detailRoute;

    if (wantRoute && route == null) {
      if (_exitingRoute != null) {
        // The previous detail still holds the key through its exit
        // animation — try again next frame.
        _scheduleRouteSync();
        return;
      }
      _pushDetailRoute();
    } else if (!wantRoute && route != null) {
      if (!_isExpanded && !painted && _controller.hasSelection) {
        // Tab hidden under the route (URL navigation): remove instantly,
        // KEEP the selection, re-push instantly when painted again.
        _instantRoutePush = true;
        _removeDetailRoute(route);
      } else if (_isExpanded) {
        // Resize into expanded: the pane claims the key in the same
        // synchronous block the route releases it.
        _removeDetailRoute(route);
      } else {
        // Programmatic dismissal — real exit animation.
        _popDetailRoute(route);
      }
    }
  }

  void _pushDetailRoute() {
    final navigator = Navigator.of(
      context,
      rootNavigator: widget.compactConfig.useRootNavigator,
    );
    final route = DetailPageRoute(
      instantEntrance: _instantRoutePush,
      builder: _buildRoutedDetail,
    );
    _detailRoute = route;
    _routeNavigator = navigator;
    _detailRouted.value = true;
    _bridgeDetail = false;
    _instantRoutePush = false;
    unawaited(
      route.popped.then((_) {
        if (mounted) _onDetailRoutePopped(route);
      }),
    );
    unawaited(navigator.push(route));
    // The route animation exists only after install.
    route.animation?.addStatusListener((status) {
      if (status != AnimationStatus.dismissed || !mounted) return;
      if (!identical(_exitingRoute, route)) return;
      _exitingRoute = null;
      if (_detailRoute == null) _detailRouted.value = false;
      _controller.setAnimatingOut(false);
      _scheduleRouteSync();
    });
    if (mounted) setState(() {});
  }

  /// Handles the route being popped — by the system back gesture,
  /// predictive back, or our own [_popDetailRoute]. Fires at pop START;
  /// the route keeps the detail key through its exit animation.
  void _onDetailRoutePopped(DetailPageRoute route) {
    // Identity guard: a removed route also completes `popped` — only the
    // still-active route's completion is a real dismissal.
    if (!identical(route, _detailRoute)) return;
    _detailRoute = null;
    _exitingRoute = route;
    _controller.setAnimatingOut(true);
    if (_controller.hasSelection) {
      // Externally popped — sync the data state. The route-mode branch of
      // _onControllerChanged schedules a sync, which finds nothing to do.
      _controller.dismiss();
    }
    if (mounted) setState(() {});
  }

  /// Animated dismissal of the active route.
  void _popDetailRoute(DetailPageRoute route) {
    final navigator = _routeNavigator;
    if (navigator == null || !navigator.mounted) return;
    if (route.isCurrent) {
      navigator.pop();
    } else if (route.isActive) {
      // Something sits above the detail (a dialog) — remove silently.
      _detailRoute = null;
      _detailRouted.value = false;
      navigator.removeRoute(route);
    }
  }

  /// Instant removal — resize swaps, paint suppression. Releases the key
  /// in the same synchronous block so the next holder can claim it.
  void _removeDetailRoute(DetailPageRoute route) {
    _detailRoute = null;
    _detailRouted.value = false;
    final navigator = _routeNavigator;
    if (navigator != null && navigator.mounted && route.isActive) {
      navigator.removeRoute(route);
    }
    if (mounted) setState(() {});
  }

  /// The route's content: the keyed detail, live against the controller.
  /// During the exit animation the selection is already cleared —
  /// [_lastSeenSelectedId] keeps the content on screen for the ride out.
  Widget _buildRoutedDetail(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final id = _controller.selectedId ?? _lastSeenSelectedId;
        if (id == null) return const SizedBox.shrink();
        return KeyedSubtree(
          key: _detailKey,
          child: widget.detailBuilder(
            context,
            id,
            DetailLayoutMode.stacked,
            _handleDismiss,
          ),
        );
      },
    );
  }

  // ===========================================================================
  // CALLBACKS
  // ===========================================================================

  void _handleSelect(T id) => _controller.select(id);

  /// Dismisses the detail pane with exit animation.
  ///
  /// Captures [_visibleDetailId] into [_outgoingDetailId] BEFORE the controller
  /// clears its selection. This ensures the detail widget stays in the tree
  /// during the exit animation (AnimatedSwitcher outgoing pattern).
  ///
  /// This method is used for ALL dismiss paths — back button, swipe gesture,
  /// and programmatic controller.dismiss(). The controller's dismiss() is
  /// routed through here to guarantee the outgoing ID is always captured.
  void _handleDismiss() {
    if (!_controller.hasSelection && _outgoingDetailId == null) return;
    _outgoingDetailId = _visibleDetailId;
    _controller.dismiss();
  }

  // ===========================================================================
  // COMPACT LAYOUT — SWIPE-TO-DISMISS GESTURE
  // ===========================================================================

  void _handleCompactDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragExtent = 0;
  }

  void _handleCompactDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final delta = details.primaryDelta ?? 0;
    // In LTR, swipe right (positive delta) dismisses.
    // In RTL, swipe left (negative delta) dismisses.
    _dragExtent += _isRtl ? -delta : delta;
    _dragExtent = _dragExtent.clamp(0, double.infinity);

    final screenWidth = MediaQuery.sizeOf(context).width;
    _slideController.value = 1.0 - (_dragExtent / screenWidth).clamp(0.0, 1.0);
  }

  void _handleCompactDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final velocity = details.primaryVelocity ?? 0;
    final dismissVelocity = _isRtl ? -velocity : velocity;
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (_dragExtent > screenWidth * widget.compactConfig.dismissThreshold ||
        dismissVelocity > widget.compactConfig.dismissVelocity) {
      _handleDismiss();
    } else {
      unawaited(_slideController.forward());
    }
    _dragExtent = 0;
  }

  // ===========================================================================
  // EXPANDED LAYOUT — DIVIDER DRAG GESTURE
  // ===========================================================================

  /// Width of the expanded layout, captured by [buildExpandedLayout] every
  /// build — divider gestures can only fire after it has been set.
  double _lastExpandedWidth = 0;

  void _handleDividerDragStart() {
    _settleController.stop();
    setState(() => _isDividerDragging = true);
  }

  void _handleDividerDragEnd() {
    setState(() => _isDividerDragging = false);
    _settleToNearestAnchor();
  }

  void _handleDividerDragUpdate(double delta) {
    // In RTL, Row reverses children — dragging right should shrink the list.
    final effectiveDelta = _isRtl ? -delta : delta;
    setState(() => _paneWidth.drag(effectiveDelta, _lastExpandedWidth));
  }

  /// Animates the divider to the nearest anchor. No-op without anchors.
  void _settleToNearestAnchor() {
    final availableWidth = _lastExpandedWidth;
    final target = _paneWidth.snapTarget(availableWidth);
    if (target == null) return;

    final begin = _paneWidth.width(availableWidth);
    final curve = CurvedAnimation(
      parent: _settleController,
      curve: Curves.easeOutCubic,
    );
    void tick() {
      _paneWidth.setWidth(
        begin + (target - begin) * curve.value,
        availableWidth,
      );
      if (mounted) setState(() {});
    }

    _settleController
      ..reset()
      ..addListener(tick);
    _settleController.forward().whenCompleteOrCancel(() {
      _settleController.removeListener(tick);
      if (mounted) setState(() {});
    });
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint = AdaptiveLayoutConfig.resolveBreakpoint(
          context,
          widget.expandedBreakpoint,
        );
        final isExpanded = constraints.maxWidth >= breakpoint;
        _isExpanded = isExpanded;

        // Evaluate overlay visibility (immediate hide for inactive tabs).
        if (_useOverlay) _paintVisibility.evaluate();

        // When transitioning expanded→compact with overlay and active
        // selection, jump the slide animation to fully open so the detail
        // appears instantly (it was already visible in expanded mode).
        // No need to toggle the overlay — it's always showing.
        if (_useOverlay && !isExpanded && _controller.hasSelection) {
          if (_slideController.value == 0 && !_slideController.isAnimating) {
            _slideController.value = 1.0;
          }
        }

        if (_useOverlay) {
          // Overlay mode: OverlayPortal wraps BOTH layout modes so it's
          // always in the tree. The overlay child returns the sliding detail
          // when compact, or SizedBox.shrink() when expanded.
          final innerLayout = isExpanded
              ? buildExpandedLayout(constraints)
              : buildCompactOverlayList();
          return buildOverlayPortalWrapper(
            child: PaintVisibilityObserver(
              detector: _paintVisibility,
              child: innerLayout,
            ),
          );
        }

        if (_useRoute) {
          _paintVisibility.evaluate();
          // One-shot: after THIS frame's paint, verify the layout actually
          // painted. A build pass that ends unpainted means the tab was
          // hidden under the route (URL navigation) — suppress it. Armed
          // only by build passes, so clean idle frames never false-trigger.
          if (_detailRoute != null) _armRoutePaintCheck();
          if (isExpanded) {
            _bridgeDetail = false;
          } else if (_wasExpandedForBridge && _controller.hasSelection) {
            // Resize into compact with an open detail: bridge the frame
            // until the instant push lands, so the list never flashes.
            _bridgeDetail = true;
            _instantRoutePush = true;
          }
          _wasExpandedForBridge = isExpanded;
          _scheduleRouteSync();
          final innerLayout = isExpanded
              ? buildExpandedLayout(constraints)
              : buildCompactRouteList();
          return PaintVisibilityObserver(
            detector: _paintVisibility,
            child: innerLayout,
          );
        }

        return isExpanded
            ? buildExpandedLayout(constraints)
            : buildCompactLayout();
      },
    );
  }
}
