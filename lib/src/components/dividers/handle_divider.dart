import 'package:flutter/material.dart';

/// Pane divider with hover feedback, drag handle dots, and settle indicator.
///
/// Inspired by macOS split view and Material 3 drag affordances.
///
/// Visual states:
/// - **Idle**: thin 1px line in [ColorScheme.outlineVariant]
/// - **Hover/Drag**: thickens to 4px in [ColorScheme.primary], shows
///   three-dot drag handle in [ColorScheme.onPrimary]
/// - **Settling**: 4px in [ColorScheme.primary] at 70% opacity (anchor snap)
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
  /// Creates a divider with the given interaction state.
  const HandleDivider({
    super.key,
    required this.isDragging,
    required this.isSettling,
  });

  /// Whether the user is actively dragging this divider.
  final bool isDragging;

  /// Whether the divider is animating to an anchor snap point.
  final bool isSettling;

  /// Builder that matches the `DividerBuilder` typedef.
  ///
  /// This is a [StatefulWidget] that manages its own hover state,
  /// so it returns a new instance each call. The widget framework
  /// handles diffing and state preservation via the element tree.
  static Widget builder(
    BuildContext context,
    bool isDragging,
    bool isSettling,
  ) {
    return HandleDivider(isDragging: isDragging, isSettling: isSettling);
  }

  @override
  State<HandleDivider> createState() => _HandleDividerState();
}

class _HandleDividerState extends State<HandleDivider> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = _isHovering || widget.isDragging;

    // Resolve the line color based on state priority:
    // settling > active (hover/drag) > idle
    final Color lineColor;
    if (widget.isSettling) {
      lineColor = colorScheme.primary.withValues(alpha: 0.7);
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
