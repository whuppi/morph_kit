part of 'list_detail_layout.dart';

/// Build methods for [_ListDetailLayoutState].
///
/// Extracted to a separate file for readability. These are pure widget
/// construction — they read state and return widget trees.
///
/// The main file retains lifecycle, animation, gestures, and the [build]
/// method that dispatches to these.
extension _LayoutBuilders<T> on _ListDetailLayoutState<T> {
  // ===========================================================================
  // EXPANDED LAYOUT
  // ===========================================================================

  /// Expanded: side-by-side panes with draggable divider, rebuilt per
  /// animation tick without setState listeners.
  Widget buildExpandedLayout(BoxConstraints constraints) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _expandEntryController,
        _detailPaneController,
      ]),
      builder: (context, _) => _buildExpandedLayoutInner(constraints),
    );
  }

  Widget _buildExpandedLayoutInner(BoxConstraints constraints) {
    final availableWidth = constraints.maxWidth;
    // Not during an empty-pane retreat: that build runs at the COMPACT
    // width and would corrupt the reference the crossing math uses.
    if (_isExpanded) _lastExpandedWidth = availableWidth;
    // Both animations scale SLOTS only — the width model is untouched,
    // so dividers and anchors keep their real geometry when they settle.
    final entry = _expandEntryController.isAnimating
        ? widget.compactConfig.curve.transform(_expandEntryController.value)
        : 1.0;
    final listOnly =
        widget.expandedEmptyBehavior == ExpandedEmptyBehavior.listOnly;
    // Detail-pane presence: 0 = list owns the full width. In listOnly it
    // tracks the selection; in placeholder behavior it is pinned at 1
    // except while an empty-pane crossing animation (reveal or retreat)
    // is in flight.
    final pane = listOnly || _detailPaneController.isAnimating
        ? widget.compactConfig.curve.transform(_detailPaneController.value)
        : 1.0;
    final finalListWidth = _paneWidth.width(availableWidth);
    // One formula, three motions: pane=1 → the entry scaling; entry=1 →
    // the pane reveal; both settled → the plain two-pane split.
    final listWidth =
        availableWidth - (availableWidth - finalListWidth * entry) * pane;

    final selectedId = _controller.selectedId;
    final detailId = listOnly ? _visibleDetailId : selectedId;
    final dividerBuilder = widget.dividerBuilder;

    Widget list = widget.listBuilder(context, selectedId, _handleSelect);
    if (entry < 1.0 &&
        widget.paneConfig.entryStyle == ExpandedEntryStyle.reveal) {
      // Reveal (default): the arriving list is laid out at its FINAL
      // width and slides in clipped — its content never reflows during
      // the entry. The yielding detail resizes live instead: its first
      // frame is exactly the full-width layout compact just showed, so
      // there is no jump, and native content panes reflow the same way
      // under a sliding sidebar. `ExpandedEntryStyle.resize` skips the
      // wrap: the list lays out at the animated slot width and reflows.
      list = ClipRect(
        child: OverflowBox(
          minWidth: finalListWidth,
          maxWidth: finalListWidth,
          alignment: AlignmentDirectional.centerEnd,
          child: list,
        ),
      );
    }

    Widget detailSlot;
    if (detailId != null) {
      // While a route (active or exiting) holds the detail key, the
      // pane leaves its slot empty — exactly one key holder per frame.
      // The route still covers the screen for that frame, so the empty
      // slot is never visible.
      detailSlot = ValueListenableBuilder<bool>(
        valueListenable: _detailRouted,
        builder: (context, routed, _) => routed
            ? const SizedBox.shrink()
            : KeyedSubtree(
                key: _detailKey,
                child: widget.detailBuilder(
                  context,
                  detailId,
                  DetailLayoutMode.sideBySide,
                  _handleDismiss,
                ),
              ),
      );
      if (listOnly && pane < 1.0) {
        // The arriving pane reveals from the end edge laid at its FINAL
        // width, clipped — same no-reflow discipline as the expand
        // entry. Start-aligned: a rigid sheet sliding in from the end
        // shows its leading portion first.
        detailSlot = ClipRect(
          child: OverflowBox(
            minWidth: availableWidth - finalListWidth,
            maxWidth: availableWidth - finalListWidth,
            alignment: AlignmentDirectional.centerStart,
            child: detailSlot,
          ),
        );
      }
    } else if (listOnly) {
      // Full-width list; the pane slot is zero-width and empty.
      detailSlot = const SizedBox.shrink();
    } else {
      detailSlot =
          widget.emptyStateBuilder?.call(context) ?? const SizedBox.shrink();
      if (pane < 1.0) {
        // The empty pane rides its crossing animation with the same
        // reveal discipline as content panes: laid at final width,
        // clipped — no re-centering wobble while the slot animates.
        detailSlot = ClipRect(
          child: OverflowBox(
            minWidth: availableWidth - finalListWidth,
            maxWidth: availableWidth - finalListWidth,
            alignment: AlignmentDirectional.centerStart,
            child: detailSlot,
          ),
        );
      }
    }

    return Stack(
      children: [
        Row(
          children: [
            SizedBox(width: listWidth, child: list),
            Expanded(child: detailSlot),
          ],
        ),
        // Divider — visual (if builder provided) or invisible drag zone.
        // In listOnly it exists whenever the pane does, riding the
        // animated seam — appearing only after settle reads as a pop-in.
        if (!listOnly || detailId != null)
          PositionedDirectional(
            // Hit area centered on the pane border.
            start: listWidth - widget.paneConfig.dividerHitWidth / 2,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) => _handleDividerDragStart(),
              onHorizontalDragUpdate: (d) =>
                  _handleDividerDragUpdate(d.primaryDelta ?? 0),
              onHorizontalDragEnd: (_) => _handleDividerDragEnd(),
              // Registered only when enabled: a double-tap recognizer
              // adds a disambiguation delay to other taps in the zone.
              onDoubleTap: widget.paneConfig.collapseOnDoubleTap
                  ? _handleDividerDoubleTap
                  : null,
              child: SizedBox(
                width: widget.paneConfig.dividerHitWidth,
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

  // ===========================================================================
  // COMPACT SLIDE LAYOUT (inline)
  // ===========================================================================

  /// Compact: list full-screen, detail slides over from start edge.
  ///
  /// The detail pane is kept in the tree during the dismiss animation via
  /// [_outgoingDetailId]. This matches Flutter's AnimatedSwitcher pattern
  /// where outgoing children stay in the tree until their exit animation
  /// reaches [AnimationStatus.dismissed].
  Widget buildCompactLayout() {
    final selectedId = _controller.selectedId;
    final detailId = _visibleDetailId;
    final showDetail = detailId != null;

    Widget body = Stack(
      children: [
        // List — always rendered behind detail (visible during swipe peek),
        // but hidden from assistive tech while covered: a screen reader
        // must not traverse content under the open detail, exactly as it
        // wouldn't under a pushed route.
        Positioned.fill(
          child: ExcludeSemantics(
            excluding: showDetail,
            child: widget.listBuilder(context, selectedId, _handleSelect),
          ),
        ),
        // Detail — slides over list, stays during dismiss animation
        if (showDetail) Positioned.fill(child: buildSlidingDetail()),
      ],
    );

    if (widget.compactConfig.handleBackGesture) {
      body = PopScope(
        canPop: selectedId == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && selectedId != null) _handleDismiss();
        },
        child: body,
      );
    }

    return body;
  }

  // ===========================================================================
  // OVERLAY PORTAL WRAPPER (always in tree when overlay mode is active)
  // ===========================================================================

  /// Wraps [child] in the [OverlayPortal]. The overlay child renders the
  /// sliding detail when compact, or nothing when expanded.
  ///
  /// By keeping the [OverlayPortal] always in the tree (wrapping both
  /// compact and expanded layouts), we avoid show/hide toggling on layout
  /// transitions — eliminating the one-frame gap caused by
  /// [OverlayPortalController] assertions during the layout phase.
  Widget buildOverlayPortalWrapper({required Widget child}) {
    return _overlay.buildPortal(
      child: child,
      overlayChildBuilder: () {
        // In expanded mode, detail is inline — overlay shows nothing.
        if (_isExpanded) return const SizedBox.shrink();
        // Suppress overlay for inactive IndexedStack children.
        return ValueListenableBuilder<bool>(
          valueListenable: _paintVisibility.notifier,
          builder: (_, visible, _) {
            if (!visible || _visibleDetailId == null) {
              return const SizedBox.shrink();
            }
            // The overlay covers the whole page — remove everything under
            // it from the semantics tree, same primitive Drawer and
            // ModalBarrier use. Guarded above: an ever-present blocker
            // would silence the page with no detail open.
            return BlockSemantics(child: buildSlidingDetail());
          },
        );
      },
      useRootOverlay: widget.compactConfig.useRootOverlay,
    );
  }

  // ===========================================================================
  // COMPACT OVERLAY LIST (list + back gesture, without the portal wrapper)
  // ===========================================================================

  /// The list pane for overlay mode. The [OverlayPortal] wrapper is handled
  /// separately by [buildOverlayPortalWrapper] so it stays in the tree
  /// across compact ↔ expanded transitions.
  Widget buildCompactOverlayList() {
    final selectedId = _controller.selectedId;

    Widget list = widget.listBuilder(context, selectedId, _handleSelect);
    if (widget.compactConfig.handleBackGesture) {
      list = PopScope(
        canPop: selectedId == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && selectedId != null) _handleDismiss();
        },
        child: list,
      );
    }

    return list;
  }

  // ===========================================================================
  // COMPACT ROUTE LIST (CompactDetailMode.route)
  // ===========================================================================

  /// Compact layout for route mode: the list alone — the detail lives in a
  /// real page route above. No [PopScope], no swipe machinery: the route
  /// owns back and transitions.
  Widget buildCompactRouteList() {
    final selectedId = _controller.selectedId;
    if (_bridgeDetail && !_detailRouted.value && selectedId != null) {
      // The frame between a resize into compact (or a deep-link mount) and
      // the push: render the detail inline under its key so the element
      // stays alive for the handoff. The push claims the key post-frame.
      final keyed = KeyedSubtree(
        key: _detailKey,
        child: widget.detailBuilder(
          context,
          selectedId,
          DetailLayoutMode.stacked,
          _handleDismiss,
        ),
      );
      if (_bridgeOffstage) {
        // Discrete crossing: the route's real entrance animates over the
        // LIST — the bridge only keeps the element alive, invisibly.
        return Stack(
          children: [
            Positioned.fill(
              child: widget.listBuilder(context, selectedId, _handleSelect),
            ),
            Offstage(child: keyed),
          ],
        );
      }
      return keyed;
    }
    return widget.listBuilder(context, selectedId, _handleSelect);
  }

  // ===========================================================================
  // SHARED SLIDING DETAIL (used by inline and overlay compact modes)
  // ===========================================================================

  /// The sliding detail pane with swipe-to-dismiss gesture.
  /// Used by both [buildCompactLayout] (inline) and
  /// `buildCompactOverlayLayout` (in the overlay).
  Widget buildSlidingDetail() {
    final detailId = _visibleDetailId;
    if (detailId == null) return const SizedBox.shrink();

    return GestureDetector(
      onHorizontalDragStart: _handleCompactDragStart,
      onHorizontalDragUpdate: _handleCompactDragUpdate,
      onHorizontalDragEnd: _handleCompactDragEnd,
      child: SlideTransition(
        position: _slideAnimation,
        // Route parity for assistive tech and keyboards: the open detail
        // reads as a route boundary to screen readers, and DismissIntent
        // (Escape, via WidgetsApp's default shortcuts) dismisses when the
        // focus sits inside the detail — the same courtesy ModalRoute
        // extends. Intents bubble from the focused node, so no focus is
        // stolen on open.
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          child: Actions(
            actions: {
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) {
                  _handleDismiss();
                  return null;
                },
              ),
            },
            child: ColoredBox(
              color:
                  widget.compactConfig.detailBackground ??
                  Theme.of(context).colorScheme.surface,
              child: KeyedSubtree(
                key: _detailKey,
                child: widget.detailBuilder(
                  context,
                  detailId,
                  DetailLayoutMode.stacked,
                  _handleDismiss,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
