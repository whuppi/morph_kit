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

  /// Expanded: side-by-side panes with draggable divider.
  Widget buildExpandedLayout(BoxConstraints constraints) {
    final availableWidth = constraints.maxWidth;
    _lastExpandedWidth = availableWidth;
    final listWidth = _paneWidth.width(availableWidth);

    final selectedId = _controller.selectedId;
    final dividerBuilder = widget.dividerBuilder;

    return Stack(
      children: [
        Row(
          children: [
            SizedBox(
              width: listWidth,
              child: widget.listBuilder(context, selectedId, _handleSelect),
            ),
            Expanded(
              // While a route (active or exiting) holds the detail key, the
              // pane leaves its slot empty — exactly one key holder per
              // frame. The route still covers the screen for that frame,
              // so the empty slot is never visible.
              child: selectedId != null
                  ? ValueListenableBuilder<bool>(
                      valueListenable: _detailRouted,
                      builder: (context, routed, _) => routed
                          ? const SizedBox.shrink()
                          : KeyedSubtree(
                              key: _detailKey,
                              child: widget.detailBuilder(
                                context,
                                selectedId,
                                DetailLayoutMode.sideBySide,
                                _handleDismiss,
                              ),
                            ),
                    )
                  : widget.emptyStateBuilder?.call(context) ??
                        const SizedBox.shrink(),
            ),
          ],
        ),
        // Divider — visual (if builder provided) or invisible drag zone
        PositionedDirectional(
          start: listWidth - 12, // 24px hit area centered on the border
          top: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _handleDividerDragStart(),
            onHorizontalDragUpdate: (d) =>
                _handleDividerDragUpdate(d.primaryDelta ?? 0),
            onHorizontalDragEnd: (_) => _handleDividerDragEnd(),
            child: SizedBox(
              width: 24,
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
