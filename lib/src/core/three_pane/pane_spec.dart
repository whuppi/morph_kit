import 'package:flutter/widgets.dart';

import 'package:adaptive_layouts/src/core/three_pane/pane_role.dart';

/// One pane in a `ThreePaneLayout`: its role, content, and sizing.
///
/// Deliberately no `==` override: [builder] is a closure, and closures
/// constructed inline in `build` never compare equal — a value equality
/// that included them would be always-false, and one that skipped them
/// would call different panes "equal". The layout compares the sizing
/// fields directly instead, so inline-constructed specs never reset a
/// dragged divider.
@immutable
class PaneSpec {
  /// Creates a pane spec.
  const PaneSpec({
    required this.role,
    required this.builder,
    this.preferredWidth = 360,
    this.minWidth = 200,
  });

  /// Decides which panes survive when partitions are scarce.
  final PaneRole role;

  /// The pane's content. Built once; the live widget instance survives
  /// partition changes via key reparenting.
  final WidgetBuilder builder;

  /// Starting width when this pane is NOT the flexible one. The
  /// highest-priority visible pane flexes to fill remaining space;
  /// the others hold a draggable width starting here.
  final double preferredWidth;

  /// Drag floor for this pane's divider.
  final double minWidth;
}
