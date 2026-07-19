import 'package:flutter/material.dart';

import 'package:morph_kit/src/core/shared/divider_builder.dart';

/// Material-style pane divider with drag and settle visual feedback.
///
/// Shows a thin vertical line that thickens and changes color when dragged.
/// Uses the ambient [ColorScheme] for theming.
///
/// A ready-made divider component for `ListDetailLayout`. Use it by
/// passing `MaterialDivider.builder` as the `dividerBuilder`, or
/// build your own.
class MaterialDivider {
  MaterialDivider._();

  /// Width of the visible divider line.
  static const double lineWidth = 1;

  /// Builder that matches the `DividerBuilder` typedef.
  static Widget builder(BuildContext context, DividerState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = state.isDragging || state.isSettling || state.isFocused;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: isActive ? 4 : lineWidth,
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primary.withValues(alpha: 0.6)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          borderRadius: isActive ? BorderRadius.circular(2) : null,
        ),
      ),
    );
  }
}
