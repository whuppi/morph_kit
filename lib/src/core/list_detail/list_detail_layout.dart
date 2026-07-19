import 'dart:async';

import 'package:flutter/material.dart';

import 'package:adaptive_layouts/src/core/list_detail/compact_config.dart';
import 'package:adaptive_layouts/src/core/list_detail/compact_detail_overlay.dart';
import 'package:adaptive_layouts/src/core/list_detail/detail_layout_mode.dart';
import 'package:adaptive_layouts/src/core/list_detail/detail_page_route.dart';
import 'package:adaptive_layouts/src/core/list_detail/expanded_empty_behavior.dart';
import 'package:adaptive_layouts/src/core/list_detail/list_detail_controller.dart';
import 'package:adaptive_layouts/src/core/list_detail/paint_visibility_detector.dart';
import 'package:adaptive_layouts/src/core/shared/adaptive_layout_config.dart';
import 'package:adaptive_layouts/src/core/shared/divider_builder.dart';
import 'package:adaptive_layouts/src/core/shared/expanded_entry_style.dart';
import 'package:adaptive_layouts/src/core/shared/pane_collapse.dart';
import 'package:adaptive_layouts/src/core/shared/pane_config.dart';
import 'package:adaptive_layouts/src/core/shared/pane_divider_region.dart';
import 'package:adaptive_layouts/src/core/shared/pane_scope.dart';
import 'package:adaptive_layouts/src/core/shared/pane_width_memory.dart';
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
    this.collapsedListBuilder,
    this.collapsedDetailBuilder,
    this.dividerBuilder,
    this.expandedBreakpoint,
    this.paneConfig = const PaneConfig(),
    this.compactConfig = const CompactConfig(),
    this.compactDetailMode = CompactDetailMode.inline,
    this.expandedEmptyBehavior = ExpandedEmptyBehavior.placeholder,
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

  /// What a collapsed list pane shows, laid out at the REAL slot width
  /// (`PaneConfig.collapsedSize`) — the icon-rail slot. While it shows,
  /// the list pane parks offstage with its state alive; restoring brings
  /// the same instance back. Null keeps the default: the list clipped at
  /// its minimum width. The builder's context sits under [PaneScope],
  /// so `PaneScope.of(context).restore` is the expand affordance.
  final WidgetBuilder? collapsedListBuilder;

  /// Same slot for a collapsed detail pane ([PaneCollapsible.end]).
  final WidgetBuilder? collapsedDetailBuilder;

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

  /// What the expanded layout does with the detail slot when nothing is
  /// selected: a persistent pane showing [emptyStateBuilder] (default),
  /// or a full-width list that yields only when a selection opens.
  final ExpandedEmptyBehavior expandedEmptyBehavior;

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

  /// Same guarantee for the list pane: wraps every list slot so mode
  /// switches, collapse clipping, and rail parking reparent the live
  /// element instead of remounting it.
  final GlobalKey _listPaneKey = GlobalKey();

  /// The list pane under its reparenting key. Every build site uses
  /// this — exactly one renders per frame.
  Widget _keyedList(T? selectedId) => KeyedSubtree(
    key: _listPaneKey,
    child: widget.listBuilder(context, selectedId, _handleSelect),
  );

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
  bool _routePaintCheckArmed = false;

  /// Render the bridge invisibly: the element stays alive for the key
  /// handoff while the LIST shows beneath an animated route entrance.
  bool _bridgeOffstage = false;

  /// Expanded/compact state of the previous build — a flip marks the
  /// breakpoint-crossing frame (all modes). Meaningless until the first
  /// build has happened: a deep-link mount is not a crossing.
  bool _wasExpandedLastBuild = false;
  bool _hasBuiltOnce = false;

  /// Drives the crossing INTO expanded with an open detail: the detail
  /// starts full width (matching what compact just showed — one frame of
  /// perfect continuity) and the list slides in, pushing it into its
  /// pane. 0 = no list; 1 = settled expanded layout.
  late final AnimationController _expandEntryController;

  /// Detail-pane presence at expanded for
  /// [ExpandedEmptyBehavior.listOnly]: 0 = the list owns the full width,
  /// 1 = both panes settled. Tracks the selection in every mode (cheap,
  /// tickless when idle) so a crossing into expanded finds it correct.
  late final AnimationController _detailPaneController;

  /// True between a route-mode build (which ran `evaluate()`) and the
  /// sync that consumes it. In such a frame `paintedThisFrame` is the
  /// authoritative visibility signal; the notifier can be a stale TRUE
  /// when the widget sat in a keep-alive bucket where paint stopped but
  /// no build ever ran `evaluate()` to correct it (TabBarView tabs).
  bool _routeFrameEvaluated = false;

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
    // No listeners on either: buildExpandedLayout wraps itself in an
    // AnimatedBuilder on both — a setState listener would fire during
    // build when a crossing frame seeds a value.
    _expandEntryController = AnimationController(
      vsync: this,
      duration: widget.compactConfig.duration,
      value: 1.0,
    );
    _detailPaneController = AnimationController(
      vsync: this,
      duration: widget.compactConfig.duration,
      value: _controller.hasSelection ? 1.0 : 0.0,
    );

    _paneWidth = PaneWidthModel(
      widget.paneConfig,
      referenceWidth: _referenceWidth,
    );
    _settleController = AnimationController(
      vsync: this,
      duration: widget.paneConfig.settleDuration,
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
      _expandEntryController.duration = widget.compactConfig.duration;
      _detailPaneController.duration = widget.compactConfig.duration;
    }
    if (widget.expandedEmptyBehavior != oldWidget.expandedEmptyBehavior) {
      // A live flip mid-animation would strand the pane half-open.
      _detailPaneController.value = _controller.hasSelection ? 1.0 : 0.0;
    }
    if (widget.compactConfig.curve != oldWidget.compactConfig.curve) {
      _slideAnimation = _buildSlideAnimation();
    }
    // Value comparison, not identity: apps construct configs inline in
    // build, and resetting the model on every rebuild would erase the
    // user's dragged divider position.
    if (widget.paneConfig != oldWidget.paneConfig) {
      _settleController.stop();
      _settleController.duration = widget.paneConfig.settleDuration;
      _paneWidth = PaneWidthModel(
        widget.paneConfig,
        referenceWidth: _referenceWidth,
      );
    }

    if (widget.compactDetailMode != oldWidget.compactDetailMode) {
      // Mode flips happen on LIVE layouts (a settings screen, a debug
      // toggle). Every per-mode wiring initState does must be mirrored
      // here or the new mode runs with dead machinery.
      if (oldWidget.compactDetailMode == CompactDetailMode.route) {
        _paintVisibility.notifier.removeListener(_scheduleRouteSync);
        _teardownDetailRoute();
        _bridgeDetail = false;
        _instantRoutePush = false;
      }
      // Leaving overlay mode needs no teardown: the OverlayPortal only
      // exists inside the overlay build branch, so it leaves the tree
      // with the mode.
      if (widget.compactDetailMode == CompactDetailMode.route) {
        // Same wiring as a route-mode initState: the paint-probe listener
        // IS the re-show chain — without it a repaint never wakes the
        // reconciler and an open detail rests inline forever. An open
        // selection starts bridged until the instant push claims it.
        _bridgeDetail = _controller.hasSelection;
        _instantRoutePush = _controller.hasSelection;
        _paintVisibility.notifier.addListener(_scheduleRouteSync);
      }
      if (widget.compactDetailMode == CompactDetailMode.overlay) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _useOverlay) _overlay.show();
        });
      }
      // Entering the slide-driven modes (inline / overlay) with a
      // selection already open: the detail is a settled fact, not an
      // entrance — snap the slide to match.
      if (widget.compactDetailMode != CompactDetailMode.route) {
        _slideController.value = _controller.hasSelection ? 1.0 : 0.0;
      }
    }
  }

  /// Reference width for ratio conversion — the expanded breakpoint, since
  /// that is the minimum width the expanded layout can have.
  double get _referenceWidth =>
      widget.expandedBreakpoint ??
      AdaptiveLayoutConfig.defaultExpandedBreakpoint;

  @override
  void dispose() {
    // Unconditional: the listener may have been wired by a live mode flip
    // rather than initState; removing an unattached listener is a no-op.
    _paintVisibility.notifier.removeListener(_scheduleRouteSync);
    _teardownDetailRoute();
    _controller.removeListener(_onControllerChanged);
    _ownedController?.dispose();
    _slideController.dispose();
    _expandEntryController.dispose();
    _detailPaneController.dispose();
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

    // The pane controller means "selection presence" only in listOnly;
    // in placeholder behavior it is a crossing transient for the empty
    // pane, and selection changes must not drag it around.
    final selectionDrivesPane =
        widget.expandedEmptyBehavior == ExpandedEmptyBehavior.listOnly;

    if (shouldBeOpen && !isCurrentlyOpen) {
      // === ENTERING: detail was closed, now something is selected ===
      _outgoingDetailId = null;
      unawaited(_slideController.forward());
      if (selectionDrivesPane) unawaited(_detailPaneController.forward());
    } else if (!shouldBeOpen && isCurrentlyOpen) {
      // === EXITING: detail was open, selection cleared ===
      //
      // _outgoingDetailId may already be set by _handleDismiss (internal path:
      // back button, swipe). For external path (controller.dismiss() called
      // directly), _outgoingDetailId is null — fall back to _lastSeenSelectedId
      // which captured the ID before the controller cleared it.
      _outgoingDetailId ??= _lastSeenSelectedId;
      _controller.setAnimatingOut(true);
      // Both exits ride together (compact slide-out / expanded pane
      // retreat); the outgoing detail is released only when the slower
      // one lands, so neither surface loses its content mid-exit.
      unawaited(
        Future.wait([
          _slideController.reverse(),
          if (selectionDrivesPane) _detailPaneController.reverse(),
        ]).then((_) {
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
      if (!mounted) return;
      if (!_paintVisibility.paintedThisFrame &&
          _paintVisibility.notifier.value) {
        // Built but not painted: the notifier is stale-true (paint can
        // stop without a build running evaluate() — keep-alive buckets).
        // Correcting it here is what re-arms the paint probe's deferred
        // "paint resumed" signal; a stuck-true notifier never fires it
        // and the re-show sync would never be woken.
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
    // When this frame's build ran evaluate(), paintedThisFrame is ground
    // truth — fresh in both directions: it covers the frame where paint
    // just resumed (the notifier flips true a deferred callback later)
    // AND it vetoes a stale-true notifier for a layout whose paint
    // stopped without any build noticing (keep-alive tab buckets). Only
    // syncs woken by the notifier itself, in a frame with no build, fall
    // back to the notifier.
    final painted = _routeFrameEvaluated
        ? _paintVisibility.paintedThisFrame
        : _paintVisibility.notifier.value;
    _routeFrameEvaluated = false;
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
        // KEEP the selection, re-push instantly when painted again. The
        // bridge takes the detail key in the same frame the route dies —
        // without a holder the element unmounts and the state is gone.
        _instantRoutePush = true;
        _bridgeDetail = true;
        _bridgeOffstage = false;
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
    _bridgeOffstage = false;
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
    _paneWidth.dragStart(_lastExpandedWidth);
    setState(() => _isDividerDragging = true);
  }

  void _handleDividerDragEnd() {
    _paneWidth.dragEnd();
    setState(() => _isDividerDragging = false);
    // A collapsed pane parks — anchor snapping applies only to visible
    // panes.
    if (_paneWidth.collapsed == null) _settleToNearestAnchor();
  }

  void _handleDividerDragUpdate(double delta) {
    // In RTL, Row reverses children — dragging right should shrink the list.
    final effectiveDelta = _isRtl ? -delta : delta;
    setState(() => _paneWidth.drag(effectiveDelta, _lastExpandedWidth));
  }

  /// Animates the divider to the nearest anchor. No-op without anchors.
  void _settleToNearestAnchor() {
    final target = _paneWidth.snapTarget(_lastExpandedWidth);
    if (target != null) _settleToWidth(target);
  }

  /// Animates the divider to [target] using the settle knobs.
  void _settleToWidth(double target) {
    final availableWidth = _lastExpandedWidth;
    final begin = _paneWidth.width(availableWidth);
    if ((target - begin).abs() < 0.5) return;
    final curve = CurvedAnimation(
      parent: _settleController,
      curve: widget.paneConfig.settleCurve,
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
  // EXPANDED LAYOUT — DIVIDER KEYBOARD / COLLAPSE ACTIONS
  // ===========================================================================

  /// Keyboard step: one micro-drag through the normal resize path, so RTL
  /// correction and clamping apply identically to pointer drags.
  void _handleDividerStep(double delta) {
    if (_paneWidth.collapsed != null) return;
    _settleController.stop();
    _handleDividerDragUpdate(delta);
  }

  /// Collapses [side] instantly. Programmatic collapse (keyboard, app
  /// buttons) snaps — the drag path is the only animated route in 1b.
  void _collapsePane(PaneSide side) {
    if (!_isExpanded || _paneWidth.collapsed != null) return;
    if (!widget.paneConfig.collapsible.allows(side)) return;
    _settleController.stop();
    setState(() => _paneWidth.collapse(side, _lastExpandedWidth));
  }

  /// Restores a collapsed pane to its remembered width instantly.
  void _restorePane() {
    if (_paneWidth.collapsed == null) return;
    setState(() => _paneWidth.restore(_lastExpandedWidth));
  }

  /// Enter on the focused divider: restore when collapsed, else collapse
  /// the first side the config allows.
  void _handleDividerToggleCollapse() {
    if (_paneWidth.collapsed != null) {
      _restorePane();
      return;
    }
    final collapsible = widget.paneConfig.collapsible;
    if (collapsible.allows(PaneSide.start)) {
      _collapsePane(PaneSide.start);
    } else if (collapsible.allows(PaneSide.end)) {
      _collapsePane(PaneSide.end);
    }
  }

  /// Double-click / double-tap: back to the configured default width
  /// (the VS Code sash-reset gesture). Restores first when collapsed.
  void _handleDividerReset() {
    if (_paneWidth.collapsed != null) {
      _restorePane();
      return;
    }
    _settleToWidth(_paneWidth.defaultWidth(_lastExpandedWidth));
  }

  void _handleDividerJumpToMinimum() {
    if (_paneWidth.collapsed != null) _restorePane();
    _settleToWidth(widget.paneConfig.minListWidth);
  }

  void _handleDividerJumpToMaximum() {
    if (_paneWidth.collapsed != null) _restorePane();
    _settleToWidth(_lastExpandedWidth * widget.paneConfig.maxListRatio);
  }

  /// The scope data descendants read via [PaneScope]. Collapse/restore
  /// route through the same actions the divider uses.
  PaneScopeData _paneScopeData() => PaneScopeData(
    collapsed: _isExpanded ? _paneWidth.collapsed : null,
    isExpanded: _isExpanded,
    collapsedSize: widget.paneConfig.collapsedSize,
    collapse: _collapsePane,
    restore: _restorePane,
  );

  // ===========================================================================
  // BREAKPOINT CROSSINGS
  // ===========================================================================

  /// Finds x with `curve.transform(x) == y` by bisection. Easing curves
  /// are monotonic; for a non-monotonic curve this still lands on ONE
  /// valid crossing, which is all a seed needs.
  static double _inverseCurve(Curve curve, double y) {
    var lo = 0.0;
    var hi = 1.0;
    for (var i = 0; i < 24; i++) {
      final mid = (lo + hi) / 2;
      if (curve.transform(mid) < y) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /// True while the empty placeholder pane is animating out after a
  /// crossing into compact: build() keeps the expanded geometry alive at
  /// the compact width until the retreat lands. The steady visuals on
  /// both ends are identical (a full-width list), so the swap to the
  /// real compact tree afterwards is invisible.
  bool get _emptyPaneRetreating =>
      widget.expandedEmptyBehavior == ExpandedEmptyBehavior.placeholder &&
      !_controller.hasSelection &&
      _detailPaneController.isAnimating;

  /// Detects a breakpoint-crossing frame against the previous build.
  /// A first build is never a crossing — deep links render settled.
  ({bool intoCompact, bool intoExpanded}) _detectCrossing(bool isExpanded) {
    final intoCompact = _hasBuiltOnce && _wasExpandedLastBuild && !isExpanded;
    final intoExpanded = _hasBuiltOnce && !_wasExpandedLastBuild && isExpanded;
    _wasExpandedLastBuild = isExpanded;
    _hasBuiltOnce = true;
    return (intoCompact: intoCompact, intoExpanded: intoExpanded);
  }

  /// Crossing-frame side effects: the arrangement-flip motion and the
  /// width-memory policy. Pane geometry tracks a window drag with no
  /// motion; the arrangement flip always animates — the Compose-canonical
  /// pane motion.
  void _handleCrossing(({bool intoCompact, bool intoExpanded}) crossing) {
    if (crossing.intoCompact && !_useRoute && _controller.hasSelection) {
      // The detail GROWS out of its pane: the slide starts with its
      // leading edge at the divider's FRACTIONAL position and settles to
      // full width. The fraction, not the old pixel position — when the
      // window itself jumped narrower, the old pixels can lie beyond the
      // new width entirely and the detail would vanish and slide in from
      // off-screen instead of growing from the divider. (Route mode's
      // equivalent is the real route entrance — see the route branch in
      // build.)
      final dividerFraction =
          (_paneWidth.width(_lastExpandedWidth) / _lastExpandedWidth).clamp(
            0.0,
            1.0,
          );
      // The controller value passes through the easing curve before it
      // becomes an offset — seed with the curve's inverse so the FIRST
      // painted frame puts the leading edge exactly on the divider.
      _slideController.value = _inverseCurve(
        widget.compactConfig.curve,
        1.0 - dividerFraction,
      );
      unawaited(_slideController.forward());
    }

    // Placeholder behavior, nothing selected: the EMPTY pane is still an
    // arrangement flip — it reveals from the end edge on expand and
    // retreats into it on shrink, like any pane. Seeds skip when already
    // animating so a rapid re-cross continues from the current position.
    final placeholderEmpty =
        widget.expandedEmptyBehavior == ExpandedEmptyBehavior.placeholder &&
        !_controller.hasSelection;
    if (crossing.intoExpanded && placeholderEmpty) {
      if (!_detailPaneController.isAnimating) {
        _detailPaneController.value = 0.0;
      }
      unawaited(_detailPaneController.forward());
    }
    if (crossing.intoCompact && placeholderEmpty) {
      if (!_detailPaneController.isAnimating) {
        _detailPaneController.value = 1.0;
      }
      // The compact tree has no pane to animate — build() keeps the
      // expanded GEOMETRY alive at the compact width until the retreat
      // lands, then the setState swaps in the real compact tree.
      unawaited(
        _detailPaneController.reverse().then((_) {
          if (mounted) setState(() {});
        }),
      );
    }

    if (crossing.intoExpanded) {
      if (widget.paneConfig.widthMemory == PaneWidthMemory.resetOnReentry) {
        // Fresh divider on every re-entry — the opt-out from the default
        // persistent memory. Reset BEFORE the entry animation reads the
        // model, so the list arrives at its default width.
        _settleController.stop();
        _paneWidth = PaneWidthModel(
          widget.paneConfig,
          referenceWidth: _referenceWidth,
        );
      }
      if (_controller.hasSelection) {
        // The detail starts full width — matching what compact just
        // showed, route or slide-over alike — and the list slides in,
        // pushing it into its pane.
        _expandEntryController.value = 0.0;
        unawaited(_expandEntryController.forward());
      }
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => PaneScope(
        data: _paneScopeData(),
        child: _buildForConstraints(context, constraints),
      ),
    );
  }

  Widget _buildForConstraints(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final breakpoint = AdaptiveLayoutConfig.resolveBreakpoint(
      context,
      widget.expandedBreakpoint,
    );
    final isExpanded = constraints.maxWidth >= breakpoint;
    _isExpanded = isExpanded;

    final crossing = _detectCrossing(isExpanded);

    // Evaluate overlay visibility (immediate hide for inactive tabs).
    if (_useOverlay) _paintVisibility.evaluate();

    _handleCrossing(crossing);

    // Overlay entering compact outside a crossing frame (deep link,
    // mode flip): the detail is a settled fact — show it fully open.
    if (_useOverlay && !isExpanded && _controller.hasSelection) {
      if (_slideController.value == 0 && !_slideController.isAnimating) {
        _slideController.value = 1.0;
      }
    }

    if (_useOverlay) {
      // Overlay mode: OverlayPortal wraps BOTH layout modes so it's
      // always in the tree. The overlay child returns the sliding detail
      // when compact, or SizedBox.shrink() when expanded.
      final innerLayout = isExpanded || _emptyPaneRetreating
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
      _routeFrameEvaluated = true;
      // One-shot: after THIS frame's paint, verify the layout actually
      // painted. A build pass that ends unpainted means the layout is
      // hidden (under the route, or in a keep-alive tab) — suppress
      // the route and correct the stale-true notifier. Armed only by
      // build passes, so clean idle frames never false-trigger.
      _armRoutePaintCheck();
      if (isExpanded) {
        _bridgeDetail = false;
        _bridgeOffstage = false;
      } else if (crossing.intoCompact && _controller.hasSelection) {
        // Resize into compact with an open detail: the bridge holds
        // the detail key until the push claims it. On a visible
        // layout the route plays its REAL entrance (the app's
        // PageTransitionsTheme) over the list, so the bridge goes
        // offstage — alive for the handoff, invisible. On a hidden
        // layout an entrance nobody watches is waste: visible bridge
        // + instant push, so the re-show contract stays instant.
        _bridgeDetail = true;
        if (_paintVisibility.notifier.value) {
          _bridgeOffstage = true;
          _instantRoutePush = false;
        } else {
          _bridgeOffstage = false;
          _instantRoutePush = true;
        }
      }
      _scheduleRouteSync();
      final innerLayout = isExpanded || _emptyPaneRetreating
          ? buildExpandedLayout(constraints)
          : buildCompactRouteList();
      return PaintVisibilityObserver(
        detector: _paintVisibility,
        child: innerLayout,
      );
    }

    return isExpanded || _emptyPaneRetreating
        ? buildExpandedLayout(constraints)
        : buildCompactLayout();
  }
}
