import 'package:flutter/material.dart';

import 'package:morph_kit/src/core/shared/divider_builder.dart';
import 'package:morph_kit/src/core/shared/pane_collapse.dart';

/// Pane divider with hover feedback, drag handle dots, settle indicator,
/// at-limit tinting, and a pull-tab restore affordance when a pane is
/// collapsed.
///
/// Inspired by macOS split views and Material 3 drag affordances.
///
/// Visual states:
/// - **Idle**: thin 1px line in [ColorScheme.outlineVariant]
/// - **Hover/Drag/Focus**: thickens to 4px in [ColorScheme.primary], shows
///   three-dot drag handle in [ColorScheme.onPrimary]
/// - **Settling**: 4px in [ColorScheme.primary] at 70% opacity (anchor snap)
/// - **At a limit**: [ColorScheme.tertiary] tint — the pane is pinned; a
///   further forced drag collapses it (when the config allows)
/// - **Collapsed**: a pull tab with a chevron pointing where the pane
///   went — drag it back out (or the app calls restore) to bring the
///   pane back
///
/// Shows [SystemMouseCursors.resizeColumn] on hover.
///
/// ```dart
/// ListDetailLayout(
///   dividerBuilder: HandleDivider.builder,
///   ...
/// )
/// ```
class HandleDivider extends StatefulWidget {
  /// Creates a divider for the given interaction state.
  const HandleDivider({super.key, required this.state});

  /// The divider's interaction state.
  final DividerState state;

  /// Builder that matches the `DividerBuilder` typedef.
  ///
  /// This is a [StatefulWidget] that manages its own hover state,
  /// so it returns a new instance each call. The widget framework
  /// handles diffing and state preservation via the element tree.
  static Widget builder(BuildContext context, DividerState state) {
    return HandleDivider(state: state);
  }

  @override
  State<HandleDivider> createState() => _HandleDividerState();
}

class _HandleDividerState extends State<HandleDivider> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = widget.state;

    if (state.collapsed != null) {
      return _PullTab(
        collapsed: state.collapsed!,
        hovering: _isHovering,
        onHover: (v) => setState(() => _isHovering = v),
      );
    }

    final isActive = _isHovering || state.isDragging || state.isFocused;
    final atLimit = state.atMinimum || state.atMaximum;

    // Resolve the line color based on state priority:
    // settling > at-limit > active (hover/drag/focus) > idle
    final Color lineColor;
    if (state.isSettling) {
      lineColor = colorScheme.primary.withValues(alpha: 0.7);
    } else if (atLimit && isActive) {
      lineColor = colorScheme.tertiary;
    } else if (isActive) {
      lineColor = colorScheme.primary;
    } else {
      lineColor = colorScheme.outlineVariant;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isActive ? 4 : 1,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(2),
          ),
          child: isActive
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HandleDot(color: colorScheme.onPrimary),
                    const SizedBox(height: 4),
                    _HandleDot(color: colorScheme.onPrimary),
                    const SizedBox(height: 4),
                    _HandleDot(color: colorScheme.onPrimary),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}

/// Restore affordance shown while a pane is collapsed: a rounded tab with
/// a chevron pointing towards the hidden pane. Dragging the divider (this
/// whole hit zone) restores it.
class _PullTab extends StatelessWidget {
  const _PullTab({
    required this.collapsed,
    required this.hovering,
    required this.onHover,
  });

  final PaneSide collapsed;
  final bool hovering;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ltr = Directionality.of(context) == TextDirection.ltr;
    // Chevron points AWAY from the collapsed pane — the direction a drag
    // restores it.
    final towardsEnd = (collapsed == PaneSide.start) == ltr;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 16,
          height: 56,
          decoration: BoxDecoration(
            color: hovering
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Icon(
            towardsEnd ? Icons.chevron_right : Icons.chevron_left,
            size: 14,
            color: hovering
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Small circular dot used in the three-dot drag handle indicator.
class _HandleDot extends StatelessWidget {
  const _HandleDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
