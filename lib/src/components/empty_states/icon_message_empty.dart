import 'package:flutter/material.dart';

/// Centered icon + message empty state layout.
///
/// Provides the structure (centering, spacing, theme-aware colors).
/// The user provides the content (icon, message).
///
/// ```dart
/// ListDetailLayout(
///   emptyStateBuilder: IconMessageEmpty.of(
///     icon: Icons.inbox_outlined,
///     message: t.chat.selectConversation, // your i18n string
///   ),
///   ...
/// )
/// ```
class IconMessageEmpty {
  IconMessageEmpty._();

  /// Creates a [WidgetBuilder] with the given [icon] and [message].
  static WidgetBuilder of({required IconData icon, required String message}) {
    return (context) {
      final colorScheme = Theme.of(context).colorScheme;

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    };
  }
}
