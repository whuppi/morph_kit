import 'dart:async';

import 'package:flutter/material.dart';

import 'package:adaptive_layouts/src/core/list_detail/compact_config.dart';
import 'package:adaptive_layouts/src/core/list_detail/compact_detail_overlay.dart';
import 'package:adaptive_layouts/src/core/list_detail/detail_layout_mode.dart';
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
  /// **Note on overlay mode with tabs:** When multiple overlay-mode instances
  /// are mounted simultaneously (e.g. tab navigation with state preservation),
  /// a [PaintVisibilityDetector] automatically suppresses inactive instances'
  /// overlays based on paint status. Hiding is zero-frame; re-showing has a
  /// one-frame delay when switching back. Works with any parent that stops
  /// painting inactive children (IndexedStack, Offstage, Visibility, etc.).
  ///
  /// Both modes use the same slide animation and swipe-to-dismiss gesture.
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
  }

  /// Reference width for ratio conversion — the expanded breakpoint, since
  /// that is the minimum width the expanded layout can have.
  double get _referenceWidth =>
      widget.expandedBreakpoint ??
      AdaptiveLayoutConfig.defaultExpandedBreakpoint;

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _ownedController?.dispose();
    _slideController.dispose();
    _settleController.dispose();
    _paintVisibility.dispose();
    super.dispose();
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

    // Track the last non-null selection for external dismiss fallback.
    if (_controller.selectedId != null) {
      _lastSeenSelectedId = _controller.selectedId;
    }

    if (mounted) setState(() {});
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

        return isExpanded
            ? buildExpandedLayout(constraints)
            : buildCompactLayout();
      },
    );
  }
}
