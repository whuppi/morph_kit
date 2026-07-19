/// Adaptive layout widgets for Flutter.
///
/// Provides layout widgets that morph between compact (mobile) and expanded
/// (tablet / desktop) form factors with gesture support, animation, and a
/// controller pattern — preserving pane widget state across the morph.
///
/// ## Quick Start
///
/// ```dart
/// ListDetailLayout(
///   listBuilder: (context, selectedId, onSelect) => MyList(onTap: onSelect),
///   detailBuilder: (context, id, mode, onDismiss) => MyDetail(id: id),
/// )
/// ```
///
/// ## Architecture
///
/// - **Core** — pure layout engine. No UI opinions; never imports components.
/// - **Components** — convenience widgets (dividers, empty states). Replaceable.
library;

// Core — layout widgets
export 'src/core/list_detail/list_detail_layout.dart';
export 'src/core/list_detail/list_detail_controller.dart';
export 'src/core/list_detail/detail_layout_mode.dart';
export 'src/core/list_detail/expanded_empty_behavior.dart';
export 'src/core/list_detail/compact_config.dart';
export 'src/core/modal/adaptive_modal.dart';
export 'src/core/modal/modal_config.dart';
export 'src/core/modal/modal_layout_mode.dart';
export 'src/core/split/adaptive_split.dart';

// Core — shared configuration + vocabulary
export 'src/core/shared/adaptive_layout_config.dart';
export 'src/core/shared/divider_builder.dart';
export 'src/core/shared/expanded_entry_style.dart';
export 'src/core/shared/pane_anchor.dart';
export 'src/core/shared/pane_collapse.dart';
export 'src/core/shared/pane_config.dart';
export 'src/core/shared/pane_divider_region.dart';
export 'src/core/shared/pane_scope.dart';
export 'src/core/shared/pane_resize_mode.dart';
export 'src/core/shared/pane_width_memory.dart';
export 'src/core/three_pane/pane_role.dart';
export 'src/core/three_pane/pane_spec.dart';
export 'src/core/three_pane/three_pane_layout.dart';

// Components — convenience library (replaceable)
export 'src/components/dividers/handle_divider.dart';
export 'src/components/dividers/material_divider.dart';
export 'src/components/empty_states/icon_message_empty.dart';
