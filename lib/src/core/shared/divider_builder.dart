import 'package:flutter/widgets.dart';

/// Builder for a pane divider in expanded layout.
///
/// Shared across `ListDetailLayout`, `AdaptiveSplit`, and any future
/// multi-pane layout widget. Use a shipped component
/// (`MaterialDivider.builder`, `HandleDivider.builder`) or build your own.
///
/// [isDragging] is true while the user is actively dragging.
/// [isSettling] is true while the divider animates to an anchor point.
typedef DividerBuilder =
    Widget Function(BuildContext context, bool isDragging, bool isSettling);
