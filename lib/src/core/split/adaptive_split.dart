import 'package:flutter/material.dart';

import 'package:adaptive_layouts/src/core/shared/adaptive_layout_config.dart';
import 'package:adaptive_layouts/src/core/shared/divider_builder.dart';
import 'package:adaptive_layouts/src/core/shared/pane_config.dart';
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
    );
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void didUpdateWidget(AdaptiveSplit oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _settleController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // DIVIDER DRAG
  // ===========================================================================

  void _handleDividerDragStart() {
    _settleController.stop();
    setState(() => _isDividerDragging = true);
  }

  void _handleDividerDragEnd() {
    setState(() => _isDividerDragging = false);
    _settleToNearestAnchor();
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

        return isExpanded
            ? _buildExpandedLayout(constraints)
            : _buildCompactLayout();
      },
    );
  }

  /// Expanded: side-by-side panes with draggable divider.
  Widget _buildExpandedLayout(BoxConstraints constraints) {
    final availableWidth = constraints.maxWidth;
    _lastExpandedWidth = availableWidth;
    final primaryWidth = _paneWidth.width(availableWidth);

    final primaryPane = SizedBox(
      width: primaryWidth,
      child: KeyedSubtree(
        key: _primaryKey,
        child: widget.primaryBuilder(context, true),
      ),
    );

    final secondaryPane = Expanded(
      child: KeyedSubtree(
        key: _secondaryKey,
        child: widget.secondaryBuilder(context, true),
      ),
    );

    final isStart = widget.primaryPosition == SplitPrimaryPosition.start;
    final first = isStart ? primaryPane : secondaryPane;
    final second = isStart ? secondaryPane : primaryPane;
    final dividerBuilder = widget.dividerBuilder;

    return Stack(
      children: [
        Row(children: [first, second]),
        // Divider — visual (if builder provided) or invisible drag zone.
        PositionedDirectional(
          start: isStart
              ? primaryWidth -
                    12 // 24px hit area centered on the border
              : availableWidth - primaryWidth - 12,
          top: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _handleDividerDragStart(),
            onHorizontalDragUpdate: (d) =>
                _handleDividerDragUpdate(d.primaryDelta ?? 0),
            onHorizontalDragEnd: (_) => _handleDividerDragEnd(),
            child: SizedBox(
              width: 24,
              child: dividerBuilder != null
                  ? dividerBuilder(
                      context,
                      _isDividerDragging,
                      _isDividerSettling,
                    )
                  : null,
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
