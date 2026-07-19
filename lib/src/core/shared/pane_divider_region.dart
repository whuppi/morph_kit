import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:adaptive_layouts/src/core/shared/divider_builder.dart';

/// The divider's interactive hit region, shared by `ListDetailLayout` and
/// `AdaptiveSplit`: drag gestures, double-click reset, keyboard resizing,
/// and screen-reader semantics — the WAI-ARIA window-splitter pattern
/// mapped to Flutter.
///
/// - Arrow keys resize by 24 logical pixels per press.
/// - Enter toggles collapse/restore (when the config allows collapse).
/// - Home / End jump to the minimum / maximum.
/// - Double click resets: restore when collapsed, default width otherwise.
/// - Screen readers see an adjustable element (increase/decrease).
class PaneDividerRegion extends StatefulWidget {
  /// Creates the divider hit region.
  const PaneDividerRegion({
    super.key,
    required this.hitWidth,
    required this.stateFor,
    required this.dividerBuilder,
    required this.onDragStart,
    required this.onDragDelta,
    required this.onDragEnd,
    required this.onStep,
    required this.onToggleCollapse,
    required this.onJumpToMinimum,
    required this.onJumpToMaximum,
    required this.onReset,
    required this.semanticsLabel,
    required this.semanticsValue,
    required this.semanticsIncreasedValue,
    required this.semanticsDecreasedValue,
  });

  /// Physical pixels one keyboard arrow press (or screen-reader
  /// increase/decrease) resizes by.
  static const double keyboardStep = 24;

  /// Width of the hit zone.
  final double hitWidth;

  /// Builds the [DividerState] for the current frame, given keyboard
  /// focus (owned here).
  final DividerState Function(bool isFocused) stateFor;

  /// The consumer's divider visual; null renders an invisible zone.
  final DividerBuilder? dividerBuilder;

  /// Drag lifecycle, physical deltas (callee corrects for RTL).
  final VoidCallback onDragStart;

  /// Applies a physical horizontal drag delta.
  final ValueChanged<double> onDragDelta;

  /// Ends the drag gesture.
  final VoidCallback onDragEnd;

  /// Keyboard resize by a physical delta (arrow keys, screen readers).
  final ValueChanged<double> onStep;

  /// Enter: collapse the pane, or restore it when collapsed.
  final VoidCallback onToggleCollapse;

  /// Home: pane to its minimum.
  final VoidCallback onJumpToMinimum;

  /// End: pane to its maximum.
  final VoidCallback onJumpToMaximum;

  /// Double click: restore when collapsed, else reset to the default.
  final VoidCallback onReset;

  /// Screen-reader label for the divider.
  final String semanticsLabel;

  /// Screen-reader value (the pane's share, e.g. "36%").
  final String semanticsValue;

  /// The value after one increase step (required by the semantics
  /// contract whenever increase/decrease actions exist).
  final String semanticsIncreasedValue;

  /// The value after one decrease step.
  final String semanticsDecreasedValue;

  @override
  State<PaneDividerRegion> createState() => _PaneDividerRegionState();
}

class _PaneDividerRegionState extends State<PaneDividerRegion> {
  bool _focused = false;

  static const double _keyboardStep = PaneDividerRegion.keyboardStep;

  @override
  Widget build(BuildContext context) {
    final state = widget.stateFor(_focused);

    return FocusableActionDetector(
      onFocusChange: (focused) => setState(() => _focused = focused),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(
          -_keyboardStep,
        ),
        SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(
          _keyboardStep,
        ),
        SingleActivator(LogicalKeyboardKey.enter): _ToggleCollapseIntent(),
        SingleActivator(LogicalKeyboardKey.home): _JumpIntent(toMinimum: true),
        SingleActivator(LogicalKeyboardKey.end): _JumpIntent(toMinimum: false),
      },
      actions: {
        _StepIntent: CallbackAction<_StepIntent>(
          onInvoke: (intent) {
            widget.onStep(intent.delta);
            return null;
          },
        ),
        _ToggleCollapseIntent: CallbackAction<_ToggleCollapseIntent>(
          onInvoke: (_) {
            widget.onToggleCollapse();
            return null;
          },
        ),
        _JumpIntent: CallbackAction<_JumpIntent>(
          onInvoke: (intent) {
            intent.toMinimum
                ? widget.onJumpToMinimum()
                : widget.onJumpToMaximum();
            return null;
          },
        ),
      },
      child: Semantics(
        container: true,
        label: widget.semanticsLabel,
        value: widget.semanticsValue,
        increasedValue: widget.semanticsIncreasedValue,
        decreasedValue: widget.semanticsDecreasedValue,
        onIncrease: () => widget.onStep(_keyboardStep),
        onDecrease: () => widget.onStep(-_keyboardStep),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => widget.onDragStart(),
          onHorizontalDragUpdate: (d) =>
              widget.onDragDelta(d.primaryDelta ?? 0),
          onHorizontalDragEnd: (_) => widget.onDragEnd(),
          onDoubleTap: widget.onReset,
          child: SizedBox(
            width: widget.hitWidth,
            child: widget.dividerBuilder?.call(context, state),
          ),
        ),
      ),
    );
  }
}

class _StepIntent extends Intent {
  const _StepIntent(this.delta);
  final double delta;
}

class _ToggleCollapseIntent extends Intent {
  const _ToggleCollapseIntent();
}

class _JumpIntent extends Intent {
  const _JumpIntent({required this.toMinimum});
  final bool toMinimum;
}
