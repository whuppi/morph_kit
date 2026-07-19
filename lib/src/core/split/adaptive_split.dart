import 'package:flutter/material.dart';

import 'package:adaptive_layouts/src/core/shared/adaptive_layout_config.dart';
import 'package:adaptive_layouts/src/core/shared/divider_builder.dart';
import 'package:adaptive_layouts/src/core/shared/pane_collapse.dart';
import 'package:adaptive_layouts/src/core/shared/pane_config.dart';
import 'package:adaptive_layouts/src/core/shared/pane_divider_region.dart';
import 'package:adaptive_layouts/src/core/shared/pane_scope.dart';
import 'package:adaptive_layouts/src/core/shared/pane_width_memory.dart';
import 'package:adaptive_layouts/src/core/shared/pane_width_model.dart';

// =============================================================================
// BUILDER TYPEDEFS
// =============================================================================

/// Builder for a pane in an [AdaptiveSplit].
///
/// [isExpanded] is true when in side-by-side expanded layout,
/// false when in compact (stacked) layout.
typedef SplitPaneBuilder =
    Widget Function(BuildContext context, bool isExpanded);

// =============================================================================
// ENUMS
// =============================================================================

/// Where the primary pane appears in expanded layout.
enum SplitPrimaryPosition {
  /// Primary on the start side (left in LTR, right in RTL).
  start,

  /// Primary on the end side (right in LTR, left in RTL).
  end,
}

/// How the secondary pane behaves in compact layout.
enum SplitCompactBehavior {
  /// Both panes stacked vertically (primary on top).
  stack,

  /// Secondary is hidden in compact layout.
  hidden,
}

// =============================================================================
// WIDGET
// =============================================================================

/// Adaptive two-pane split layout that morphs between compact and expanded.
///
/// - **Compact** (below [expandedBreakpoint]): vertical stack or hidden secondary
/// - **Expanded** (at or above [expandedBreakpoint]): side-by-side with
///   draggable divider
///
/// ## State Preservation
///
/// Both panes use internal [GlobalKey]s via [KeyedSubtree], so widget state
/// is automatically preserved across compact ↔ expanded transitions.
/// Same pattern as `ListDetailLayout`.
///
/// ## Usage
///
/// ```dart
/// AdaptiveSplit(
///   primaryBuilder: (context, isExpanded) => AlbumArt(),
///   secondaryBuilder: (context, isExpanded) => QueueOrVisualizer(),
///   dividerBuilder: HandleDivider.builder,
///   paneConfig: PaneConfig(
///     defaultListWidth: 400,
///     maxListRatio: 0.55,
///   ),
/// )
/// ```
class AdaptiveSplit extends StatefulWidget {
  /// Creates an adaptive two-pane split layout.
  const AdaptiveSplit({
    super.key,
    required this.primaryBuilder,
    required this.secondaryBuilder,
    this.primaryPosition = SplitPrimaryPosition.start,
    this.compactBehavior = SplitCompactBehavior.stack,
    this.expandedBreakpoint,
    this.paneConfig = const PaneConfig(),
    this.dividerBuilder,
    this.compactSpacing = 0,
    this.collapsedPrimaryBuilder,
    this.collapsedSecondaryBuilder,
  });

  /// Builder for the primary content pane.
  final SplitPaneBuilder primaryBuilder;

  /// Builder for the secondary content pane.
  final SplitPaneBuilder secondaryBuilder;

  /// Where the primary pane appears in expanded layout.
  /// In compact layout, primary is always on top.
  final SplitPrimaryPosition primaryPosition;

  /// How the secondary pane behaves in compact layout.
  final SplitCompactBehavior compactBehavior;

  /// Width breakpoint for compact ↔ expanded switch.
  /// If null, reads from [AdaptiveLayoutConfig] ancestor, then falls back to 720.
  final double? expandedBreakpoint;

  /// Expanded-layout pane configuration (widths, anchors, resize behavior).
  /// [PaneConfig.defaultListWidth] and friends size the PRIMARY pane here.
  final PaneConfig paneConfig;

  /// Builder for the expanded-layout pane divider.
  /// Null by default (invisible drag zone). Use a shipped component
  /// (`HandleDivider.builder`, `MaterialDivider.builder`) or your own —
  /// same [DividerBuilder] contract as `ListDetailLayout`.
  final DividerBuilder? dividerBuilder;

  /// Spacing between panes in compact (stacked) layout.
  final double compactSpacing;

  /// What a collapsed primary pane shows, laid out at the REAL slot
  /// width (`PaneConfig.collapsedSize`) — the icon-rail slot. While it
  /// shows, the primary parks offstage with its state alive. Null keeps
  /// the default: the pane clipped at its floor width. The builder's
  /// context sits under [PaneScope] for the restore affordance.
  final WidgetBuilder? collapsedPrimaryBuilder;

  /// Same slot for a collapsed secondary pane.
  final WidgetBuilder? collapsedSecondaryBuilder;

  @override
  State<AdaptiveSplit> createState() => _AdaptiveSplitState();
}

// =============================================================================
// STATE
// =============================================================================

class _AdaptiveSplitState extends State<AdaptiveSplit>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // Divider drag state — width/clamp/snap logic lives in the shared model;
  // this state owns only the gesture flags and the settle animation.
  // ---------------------------------------------------------------------------

  late PaneWidthModel _paneWidth;
  bool _isDividerDragging = false;
  late AnimationController _settleController;
  bool get _isDividerSettling => _settleController.isAnimating;

  /// Width of the expanded layout, captured every build — divider gestures
  /// can only fire after it has been set.
  double _lastExpandedWidth = 0;

  // ---------------------------------------------------------------------------
  // State preservation across compact ↔ expanded transitions.
  // GlobalKey causes Flutter to reparent (move) the widget instead of
  // destroying and recreating it when the layout mode changes.
  // Same technique as ListDetailLayout._detailKey.
  // ---------------------------------------------------------------------------

  final GlobalKey _primaryKey = GlobalKey();
  final GlobalKey _secondaryKey = GlobalKey();

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _paneWidth = PaneWidthModel(
      widget.paneConfig,
      referenceWidth: _referenceWidth,
      collapsible: _modelCollapsible,
    );
    _settleController = AnimationController(
      vsync: this,
      duration: widget.paneConfig.settleDuration,
    );
  }

  /// Crossing bookkeeping for [PaneWidthMemory.resetOnReentry]. A first
  /// build is never a crossing.
  bool _wasExpandedLastBuild = false;
  bool _hasBuiltOnce = false;

  /// Whether the last build laid out side-by-side. Gates collapse actions
  /// (collapse is expanded-only view state).
  bool _isExpanded = false;

  @override
  void didUpdateWidget(AdaptiveSplit oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Value comparison, not identity: apps construct configs inline in
    // build, and resetting the model on every rebuild would erase the
    // user's dragged divider position.
    if (widget.paneConfig != oldWidget.paneConfig) {
      _settleController.stop();
      _settleController.duration = widget.paneConfig.settleDuration;
      _paneWidth = PaneWidthModel(
        widget.paneConfig,
        referenceWidth: _referenceWidth,
        collapsible: _modelCollapsible,
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
    _settleController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // MODEL <-> DIRECTIONAL TRANSLATION
  // ===========================================================================

  // The width model measures the PRIMARY pane. When the primary sits at
  // the directional end, model-space sides are the mirror of the
  // directional sides the public API speaks. These helpers flip at the
  // boundary so `PaneSide` / `PaneCollapsible` stay directional
  // everywhere consumers see them.

  bool get _primaryAtStart =>
      widget.primaryPosition == SplitPrimaryPosition.start;

  PaneCollapsible get _modelCollapsible {
    final collapsible = widget.paneConfig.collapsible;
    if (_primaryAtStart) return collapsible;
    return switch (collapsible) {
      PaneCollapsible.start => PaneCollapsible.end,
      PaneCollapsible.end => PaneCollapsible.start,
      _ => collapsible,
    };
  }

  PaneSide _flipSide(PaneSide side) =>
      side == PaneSide.start ? PaneSide.end : PaneSide.start;

  PaneSide? get _visualCollapsed {
    final collapsed = _paneWidth.collapsed;
    if (collapsed == null || _primaryAtStart) return collapsed;
    return _flipSide(collapsed);
  }

  // ===========================================================================
  // DIVIDER DRAG
  // ===========================================================================

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
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final effectiveDelta = isRtl ? -delta : delta;
    // A start-positioned primary grows when dragging towards the end;
    // an end-positioned primary grows the other way.
    final directed = widget.primaryPosition == SplitPrimaryPosition.start
        ? effectiveDelta
        : -effectiveDelta;
    setState(() => _paneWidth.drag(directed, _lastExpandedWidth));
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
  // DIVIDER KEYBOARD / COLLAPSE ACTIONS
  // ===========================================================================

  /// Keyboard step: one micro-drag through the normal resize path, so RTL
  /// and primary-position correction apply identically to pointer drags.
  void _handleDividerStep(double delta) {
    if (_paneWidth.collapsed != null) return;
    _settleController.stop();
    _handleDividerDragUpdate(delta);
  }

  /// Collapses the directional [side] instantly. Programmatic collapse
  /// (keyboard, app buttons) snaps — the drag path is the only animated
  /// route in 1b.
  void _collapsePane(PaneSide side) {
    if (!_isExpanded || _paneWidth.collapsed != null) return;
    if (!widget.paneConfig.collapsible.allows(side)) return;
    _settleController.stop();
    final modelSide = _primaryAtStart ? side : _flipSide(side);
    setState(() => _paneWidth.collapse(modelSide, _lastExpandedWidth));
  }

  /// Restores a collapsed pane to its remembered width instantly.
  void _restorePane() {
    if (_paneWidth.collapsed == null) return;
    setState(() => _paneWidth.restore(_lastExpandedWidth));
  }

  /// Enter on the focused divider: restore when collapsed, else collapse
  /// the first directional side the config allows.
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

  /// Double-click / double-tap: back to the configured default width.
  /// Restores first when collapsed.
  void _handleDividerReset() {
    if (_paneWidth.collapsed != null) {
      _restorePane();
      return;
    }
    _settleToWidth(_paneWidth.defaultWidth(_lastExpandedWidth));
  }

  // Home/End move the DIVIDER to its directional start/end. In model
  // space that's the primary's minimum/maximum — mirrored when the
  // primary sits at the directional end.

  void _handleDividerJumpToMinimum() {
    if (_paneWidth.collapsed != null) _restorePane();
    _settleToWidth(
      _primaryAtStart
          ? widget.paneConfig.minListWidth
          : _lastExpandedWidth * widget.paneConfig.maxListRatio,
    );
  }

  void _handleDividerJumpToMaximum() {
    if (_paneWidth.collapsed != null) _restorePane();
    _settleToWidth(
      _primaryAtStart
          ? _lastExpandedWidth * widget.paneConfig.maxListRatio
          : widget.paneConfig.minListWidth,
    );
  }

  /// The scope data descendants read via [PaneScope].
  PaneScopeData _paneScopeData() => PaneScopeData(
    collapsed: _isExpanded ? _visualCollapsed : null,
    isExpanded: _isExpanded,
    collapsedSize: widget.paneConfig.collapsedSize,
    collapse: _collapsePane,
    restore: _restorePane,
  );

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
        if (_hasBuiltOnce &&
            !_wasExpandedLastBuild &&
            isExpanded &&
            widget.paneConfig.widthMemory == PaneWidthMemory.resetOnReentry) {
          // Fresh divider on every re-entry — the opt-out from the
          // default persistent memory.
          _settleController.stop();
          _paneWidth = PaneWidthModel(
            widget.paneConfig,
            referenceWidth: _referenceWidth,
            collapsible: _modelCollapsible,
          );
        }
        _wasExpandedLastBuild = isExpanded;
        _hasBuiltOnce = true;

        return PaneScope(
          data: _paneScopeData(),
          child: isExpanded
              ? _buildExpandedLayout(constraints)
              : _buildCompactLayout(),
        );
      },
    );
  }

  /// A collapsed pane's slot. With a rail builder the rail lays out at
  /// the REAL slot width while the pane parks offstage, state alive
  /// (tickers paused). Without one, the pane stays laid out at its
  /// floor width and clips as the slot shrinks.
  Widget _collapsedSlot({
    required Widget pane,
    required double paneLayoutWidth,
    required WidgetBuilder? railBuilder,
    required AlignmentDirectional alignment,
  }) {
    final held = OverflowBox(
      minWidth: paneLayoutWidth,
      maxWidth: paneLayoutWidth,
      alignment: alignment,
      child: pane,
    );
    if (railBuilder == null) return ClipRect(child: held);
    // StackFit.expand — the stack must take the slot's size, not the
    // offstage child's zero size.
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(child: TickerMode(enabled: false, child: held)),
        Builder(builder: railBuilder),
      ],
    );
  }

  /// Formats the directional-start pane's share after a model-space
  /// [delta], clamped to the pane limits, for the screen-reader value
  /// contract.
  String _paneSharePercent(double width, double delta, double availableWidth) {
    final clamped = (width + delta).clamp(
      widget.paneConfig.minListWidth,
      availableWidth * widget.paneConfig.maxListRatio,
    );
    final startShare = _primaryAtStart ? clamped : availableWidth - clamped;
    return '${(startShare / availableWidth * 100).round()}%';
  }

  /// The divider's interaction state for [DividerBuilder]s, in
  /// DIRECTIONAL terms: with an end-positioned primary the model's limits
  /// mirror, so at-minimum/at-maximum and the collapsed side all flip.
  DividerState _dividerState(double availableWidth, {bool isFocused = false}) {
    final collapsed = _paneWidth.collapsed;
    final width = _paneWidth.width(availableWidth);
    final max = availableWidth * widget.paneConfig.maxListRatio;
    final atModelMin =
        collapsed == null && width <= widget.paneConfig.minListWidth + 0.5;
    final atModelMax = collapsed == null && width >= max - 0.5;
    return DividerState(
      isDragging: _isDividerDragging,
      isSettling: _isDividerSettling,
      atMinimum: _primaryAtStart ? atModelMin : atModelMax,
      atMaximum: _primaryAtStart ? atModelMax : atModelMin,
      collapsed: _visualCollapsed,
      isFocused: isFocused,
    );
  }

  /// Expanded: side-by-side panes with draggable divider.
  Widget _buildExpandedLayout(BoxConstraints constraints) {
    final availableWidth = constraints.maxWidth;
    _lastExpandedWidth = availableWidth;
    final primaryWidth = _paneWidth.width(availableWidth);
    final collapsed = _paneWidth.collapsed;

    // A collapsed pane's content stays laid out at its minimum width —
    // its last legal layout — and clips as the slot shrinks below it.
    Widget primaryContent = KeyedSubtree(
      key: _primaryKey,
      child: widget.primaryBuilder(context, true),
    );
    if (collapsed == PaneSide.start) {
      primaryContent = _collapsedSlot(
        pane: primaryContent,
        paneLayoutWidth: widget.paneConfig.minListWidth,
        railBuilder: widget.collapsedPrimaryBuilder,
        alignment: AlignmentDirectional.centerStart,
      );
    }
    final primaryPane = SizedBox(width: primaryWidth, child: primaryContent);

    Widget secondaryContent = KeyedSubtree(
      key: _secondaryKey,
      child: widget.secondaryBuilder(context, true),
    );
    if (collapsed == PaneSide.end) {
      secondaryContent = _collapsedSlot(
        pane: secondaryContent,
        paneLayoutWidth: availableWidth * (1 - widget.paneConfig.maxListRatio),
        railBuilder: widget.collapsedSecondaryBuilder,
        alignment: AlignmentDirectional.centerEnd,
      );
    }
    final secondaryPane = Expanded(child: secondaryContent);

    final isStart = widget.primaryPosition == SplitPrimaryPosition.start;
    final first = isStart ? primaryPane : secondaryPane;
    final second = isStart ? secondaryPane : primaryPane;
    final dividerBuilder = widget.dividerBuilder;

    return Stack(
      children: [
        Row(children: [first, second]),
        // Divider — visual (if builder provided) or invisible drag zone.
        PositionedDirectional(
          // Hit area centered on the pane border.
          start:
              (isStart
                      ? primaryWidth - widget.paneConfig.dividerHitWidth / 2
                      : availableWidth -
                            primaryWidth -
                            widget.paneConfig.dividerHitWidth / 2)
                  .clamp(
                    0.0,
                    availableWidth - widget.paneConfig.dividerHitWidth,
                  ),
          top: 0,
          bottom: 0,
          child: PaneDividerRegion(
            hitWidth: widget.paneConfig.dividerHitWidth,
            stateFor: (focused) =>
                _dividerState(availableWidth, isFocused: focused),
            dividerBuilder: dividerBuilder,
            onDragStart: _handleDividerDragStart,
            onDragDelta: _handleDividerDragUpdate,
            onDragEnd: _handleDividerDragEnd,
            onStep: _handleDividerStep,
            onToggleCollapse: _handleDividerToggleCollapse,
            onJumpToMinimum: _handleDividerJumpToMinimum,
            onJumpToMaximum: _handleDividerJumpToMaximum,
            onReset: _handleDividerReset,
            semanticsLabel: widget.paneConfig.dividerSemanticsLabel,
            semanticsValue: _paneSharePercent(primaryWidth, 0, availableWidth),
            semanticsIncreasedValue: _paneSharePercent(
              primaryWidth,
              PaneDividerRegion.keyboardStep,
              availableWidth,
            ),
            semanticsDecreasedValue: _paneSharePercent(
              primaryWidth,
              -PaneDividerRegion.keyboardStep,
              availableWidth,
            ),
          ),
        ),
      ],
    );
  }

  /// Compact: vertical stack or hidden secondary.
  Widget _buildCompactLayout() {
    final primary = KeyedSubtree(
      key: _primaryKey,
      child: widget.primaryBuilder(context, false),
    );

    if (widget.compactBehavior == SplitCompactBehavior.hidden) {
      return primary;
    }

    return Column(
      children: [
        Expanded(child: primary),
        if (widget.compactSpacing > 0) SizedBox(height: widget.compactSpacing),
        Expanded(
          child: KeyedSubtree(
            key: _secondaryKey,
            child: widget.secondaryBuilder(context, false),
          ),
        ),
      ],
    );
  }
}
