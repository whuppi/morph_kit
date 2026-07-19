import 'package:flutter/material.dart';

import 'package:adaptive_layouts/src/core/shared/adaptive_layout_config.dart';
import 'package:adaptive_layouts/src/core/shared/divider_builder.dart';
import 'package:adaptive_layouts/src/core/shared/pane_config.dart';
import 'package:adaptive_layouts/src/core/shared/pane_divider_region.dart';
import 'package:adaptive_layouts/src/core/shared/pane_resize_mode.dart';
import 'package:adaptive_layouts/src/core/shared/pane_width_model.dart';
import 'package:adaptive_layouts/src/core/three_pane/pane_role.dart';
import 'package:adaptive_layouts/src/core/three_pane/pane_spec.dart';

/// Up to three panes that appear and yield by role priority as the
/// window grows and shrinks — the Material adaptive pane-scaffold model.
///
/// Two thresholds carve the width into partitions: below
/// [expandedBreakpoint] one pane shows, below [largeBreakpoint] two,
/// above it three. When partitions are scarce, the highest-priority
/// roles win the slots ([PaneRole.primary] survives to the narrowest
/// window); the [panes] list's order decides left-to-right placement,
/// decoupled from priority.
///
/// The highest-priority visible pane flexes to fill remaining space;
/// the others hold a draggable width starting at their
/// [PaneSpec.preferredWidth]. Every divider carries the full interaction
/// contract (drag, keyboard, double-click reset, screen-reader
/// adjustment). Home/End and double-click snap instantly here — this
/// layout has no anchor system to settle against.
///
/// Hidden panes stay alive offstage (tickers paused), so a pane's
/// scroll position, form drafts, and in-flight state survive partition
/// changes in both directions.
///
/// ```dart
/// ThreePaneLayout(
///   panes: [
///     PaneSpec(role: PaneRole.secondary, builder: (_) => Outline()),
///     PaneSpec(role: PaneRole.primary, builder: (_) => Editor()),
///     PaneSpec(role: PaneRole.tertiary, builder: (_) => Inspector()),
///   ],
/// )
/// ```
class ThreePaneLayout extends StatefulWidget {
  /// Creates the layout. [panes] holds 2 or 3 specs in visual order.
  const ThreePaneLayout({
    super.key,
    required this.panes,
    this.expandedBreakpoint,
    this.largeBreakpoint = 1200,
    this.dividerBuilder,
    this.dividerHitWidth = 24,
    this.dividerSemanticsLabel = 'Pane divider',
    this.retainHiddenPanes = true,
  }) : assert(
         panes.length == 2 || panes.length == 3,
         'ThreePaneLayout takes 2 or 3 panes',
       );

  /// The panes, in the left-to-right (directional) order they occupy.
  final List<PaneSpec> panes;

  /// Width from which two partitions are available. Null resolves the
  /// app-wide default via [AdaptiveLayoutConfig].
  final double? expandedBreakpoint;

  /// Width from which three partitions are available.
  final double largeBreakpoint;

  /// Visual for the dividers; null keeps invisible drag zones.
  final DividerBuilder? dividerBuilder;

  /// Width of each divider's hit zone.
  final double dividerHitWidth;

  /// Screen-reader label for the dividers. Localize by passing your own.
  final String dividerSemanticsLabel;

  /// Keeps hidden panes alive offstage so their state survives
  /// partition changes. Turn off to unmount them instead.
  final bool retainHiddenPanes;

  @override
  State<ThreePaneLayout> createState() => _ThreePaneLayoutState();
}

class _ThreePaneLayoutState extends State<ThreePaneLayout> {
  late List<GlobalKey> _paneKeys;

  /// Width model per pane index. Only consulted while that pane is
  /// visible and not the flexible one, but kept alive throughout so a
  /// dragged width survives visibility changes.
  late List<PaneWidthModel> _models;

  double _lastAvailableWidth = 0;

  @override
  void initState() {
    super.initState();
    _paneKeys = List.generate(widget.panes.length, (_) => GlobalKey());
    _models = List.generate(widget.panes.length, _buildModel);
  }

  @override
  void didUpdateWidget(ThreePaneLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.panes.length != oldWidget.panes.length) {
      _paneKeys = List.generate(widget.panes.length, (_) => GlobalKey());
      _models = List.generate(widget.panes.length, _buildModel);
      return;
    }
    for (var i = 0; i < widget.panes.length; i++) {
      // Sizing fields only — builders are closures that never compare
      // equal when constructed inline, and a builder change doesn't
      // invalidate a dragged width.
      final spec = widget.panes[i];
      final old = oldWidget.panes[i];
      if (spec.preferredWidth != old.preferredWidth ||
          spec.minWidth != old.minWidth) {
        _models[i] = _buildModel(i);
      }
    }
  }

  PaneWidthModel _buildModel(int index) {
    final spec = widget.panes[index];
    // Each side pane reuses the shared width model in pixel mode; the
    // reference width is unused outside ratio mode.
    return PaneWidthModel(
      PaneConfig(
        defaultListWidth: spec.preferredWidth,
        minListWidth: spec.minWidth,
        resizeMode: PaneResizeMode.pixels,
      ),
      referenceWidth: _referenceWidth,
    );
  }

  double get _referenceWidth =>
      widget.expandedBreakpoint ??
      AdaptiveLayoutConfig.defaultExpandedBreakpoint;

  // ===========================================================================
  // PARTITIONS AND VISIBILITY
  // ===========================================================================

  int _partitions(double width) {
    final expanded = AdaptiveLayoutConfig.resolveBreakpoint(
      context,
      widget.expandedBreakpoint,
    );
    if (width < expanded) return 1;
    if (width < widget.largeBreakpoint) return 2;
    return 3;
  }

  /// Pane indices that win a slot, in visual order. Priority decides
  /// who; position decides where. Ties keep list order.
  List<int> _visibleIndices(int partitions) {
    final byPriority = List.generate(widget.panes.length, (i) => i)
      ..sort((a, b) {
        final cmp = widget.panes[b].role.priority.compareTo(
          widget.panes[a].role.priority,
        );
        return cmp != 0 ? cmp : a.compareTo(b);
      });
    final winners = byPriority.take(partitions).toList()..sort();
    return winners;
  }

  /// The flexible pane: highest priority among the visible.
  int _flexIndex(List<int> visible) => visible.reduce(
    (a, b) =>
        widget.panes[b].role.priority > widget.panes[a].role.priority ? b : a,
  );

  // ===========================================================================
  // DIVIDER ACTIONS
  // ===========================================================================

  /// Applies a LOGICAL (start-to-end) delta to pane [index]'s model.
  /// [growsTowardEnd] is true when the pane sits before its divider.
  void _dragModel(int index, double logicalDelta, bool growsTowardEnd) {
    final directed = growsTowardEnd ? logicalDelta : -logicalDelta;
    setState(() => _models[index].drag(directed, _lastAvailableWidth));
  }

  void _snapModel(int index, double target) {
    setState(() => _models[index].setWidth(target, _lastAvailableWidth));
  }

  double _maxPaneWidth() =>
      _lastAvailableWidth * const PaneConfig().maxListRatio;

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final partitions = _partitions(width);
        final visible = _visibleIndices(partitions);
        final hidden = List.generate(
          widget.panes.length,
          (i) => i,
        ).where((i) => !visible.contains(i)).toList();

        final layout = visible.length == 1
            ? _pane(visible.single)
            : _buildMultiPane(context, width, visible);

        if (!widget.retainHiddenPanes || hidden.isEmpty) return layout;
        return Stack(
          children: [
            // Hidden panes stay alive offstage with tickers paused —
            // their state survives partition changes.
            for (final i in hidden)
              Offstage(
                child: TickerMode(
                  enabled: false,
                  child: SizedBox(
                    width: widget.panes[i].preferredWidth,
                    height: constraints.maxHeight,
                    child: _pane(i),
                  ),
                ),
              ),
            layout,
          ],
        );
      },
    );
  }

  Widget _pane(int index) => KeyedSubtree(
    key: _paneKeys[index],
    child: Builder(builder: widget.panes[index].builder),
  );

  Widget _buildMultiPane(
    BuildContext context,
    double availableWidth,
    List<int> visible,
  ) {
    _lastAvailableWidth = availableWidth;
    final flexIndex = _flexIndex(visible);

    // Side-pane widths from their models, scaled down together if they
    // would squeeze the flexible pane below its own minimum.
    final widths = <int, double>{
      for (final i in visible)
        if (i != flexIndex) i: _models[i].width(availableWidth),
    };
    final sideTotal = widths.values.fold(0.0, (a, b) => a + b);
    final flexMin = widget.panes[flexIndex].minWidth;
    if (sideTotal > availableWidth - flexMin && sideTotal > 0) {
      final scale = (availableWidth - flexMin) / sideTotal;
      widths.updateAll((_, w) => w * scale);
    }

    final children = <Widget>[
      for (final i in visible)
        if (i == flexIndex)
          Expanded(child: _pane(i))
        else
          SizedBox(width: widths[i], child: _pane(i)),
    ];

    // Divider hit zones straddle each adjacent pane boundary.
    final clampedSideTotal = widths.values.fold(0.0, (a, b) => a + b);
    final flexWidth = availableWidth - clampedSideTotal;
    final dividers = <Widget>[];
    var cursor = 0.0;
    for (var slot = 0; slot < visible.length - 1; slot++) {
      final index = visible[slot];
      cursor += index == flexIndex ? flexWidth : widths[index]!;
      dividers.add(
        _divider(context, availableWidth, visible, flexIndex, slot, cursor),
      );
    }

    return Stack(
      children: [
        Row(children: children),
        ...dividers,
      ],
    );
  }

  Widget _divider(
    BuildContext context,
    double availableWidth,
    List<int> visible,
    int flexIndex,
    int slot,
    double boundary,
  ) {
    // The divider resizes the non-flexible neighbor of this boundary.
    final before = visible[slot];
    final after = visible[slot + 1];
    final controlled = before == flexIndex ? after : before;
    final growsTowardEnd = controlled == before;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    double controlledWidth() => _models[controlled].width(availableWidth);
    String share(double delta) {
      // Min-wins guard against inverted bounds on narrow windows.
      final floor = widget.panes[controlled].minWidth;
      final ceiling = _maxPaneWidth();
      final clamped = ceiling <= floor
          ? floor
          : (controlledWidth() + delta).clamp(floor, ceiling);
      return '${(clamped / availableWidth * 100).round()}%';
    }

    void applyPhysical(double physicalDelta) {
      final logical = isRtl ? -physicalDelta : physicalDelta;
      _dragModel(controlled, logical, growsTowardEnd);
    }

    return PositionedDirectional(
      start: (boundary - widget.dividerHitWidth / 2).clamp(
        0.0,
        availableWidth - widget.dividerHitWidth,
      ),
      top: 0,
      bottom: 0,
      child: PaneDividerRegion(
        hitWidth: widget.dividerHitWidth,
        stateFor: (focused) => DividerState(
          isDragging: _draggingSlot == slot,
          atMinimum:
              controlledWidth() <= widget.panes[controlled].minWidth + 0.5,
          atMaximum: controlledWidth() >= _maxPaneWidth() - 0.5,
          isFocused: focused,
        ),
        dividerBuilder: widget.dividerBuilder,
        onDragStart: () {
          _models[controlled].dragStart(availableWidth);
          setState(() => _draggingSlot = slot);
        },
        onDragDelta: applyPhysical,
        onDragEnd: () {
          _models[controlled].dragEnd();
          setState(() => _draggingSlot = null);
        },
        onStep: applyPhysical,
        // No collapse system here — Enter is a no-op by contract.
        onToggleCollapse: () {},
        onJumpToMinimum: () =>
            _snapModel(controlled, widget.panes[controlled].minWidth),
        onJumpToMaximum: () => _snapModel(controlled, _maxPaneWidth()),
        onReset: () =>
            _snapModel(controlled, widget.panes[controlled].preferredWidth),
        semanticsLabel: widget.dividerSemanticsLabel,
        semanticsValue: share(0),
        semanticsIncreasedValue: share(PaneDividerRegion.keyboardStep),
        semanticsDecreasedValue: share(-PaneDividerRegion.keyboardStep),
      ),
    );
  }

  int? _draggingSlot;
}
