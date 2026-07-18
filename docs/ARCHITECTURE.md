# adaptive_layouts — Architecture

> **Type:** architecture · **Scope:** adaptive_layouts · **Status:** SHIPPED · **Last verified:** 2026-07-18
> **Companion docs:** [`CAPABILITY_ROADMAP.md`](CAPABILITY_ROADMAP.md) · [`UPDATING.md`](UPDATING.md)

Adaptive layout widgets that morph between compact (mobile) and expanded
(tablet / desktop) form factors — preserving pane widget state across the
morph. Router-agnostic, state-management-agnostic. The package is a growing
family — each layout lives in its own `src/core/` subtree on shared
vocabulary (`src/core/shared/`). The runnable integration reference is
[`example/`](../example/) (a full multi-domain app with nested tab routers,
URL sync, and modals).

---

## 1. The two-layer split

```
lib/
├── adaptive_layouts.dart              # public barrel
└── src/
    ├── components/                    # GROWING LIBRARY — convenience widgets
    │   ├── dividers/
    │   │   ├── handle_divider.dart    # visible drag handle (macOS-style)
    │   │   └── material_divider.dart  # clean Material line
    │   └── empty_states/
    │       └── icon_message_empty.dart
    └── core/                          # PURE LAYOUT — no component imports
        ├── list_detail/
        │   ├── compact_config.dart            # compact-mode data (animation, gestures, overlay)
        │   ├── compact_detail_overlay.dart    # OverlayPortal wrapper (internal)
        │   ├── detail_layout_mode.dart        # stacked / sideBySide + inline / overlay
        │   ├── list_detail_controller.dart    # selection + visibility controller
        │   ├── list_detail_layout.dart        # widget + state (lifecycle, animation, gestures)
        │   ├── list_detail_layout_builders.dart  # part: build methods
        │   └── paint_visibility_detector.dart # overlay suppression for inactive tabs
        ├── modal/
        │   ├── adaptive_modal.dart            # showAdaptiveModal + route-swap session
        │   ├── modal_config.dart              # forwards to the Material routes
        │   └── modal_layout_mode.dart         # dialog / sheet
        ├── shared/
        │   ├── adaptive_layout_config.dart    # inherited breakpoint config
        │   ├── divider_builder.dart           # shared DividerBuilder typedef
        │   ├── pane_anchor.dart               # divider snap points
        │   ├── pane_config.dart               # expanded-pane data (widths, anchors, mode)
        │   ├── pane_resize_mode.dart          # ratio vs pixels
        │   └── pane_width_model.dart          # width/drag/clamp/snap logic (internal)
        └── split/
            └── adaptive_split.dart            # generic two-pane split widget
```

**Dependency rule (load-bearing): core never imports components.** Components
import core's typedefs only. A widget's divider / empty-state parameters are
nullable; the app passes a shipped component (`HandleDivider.builder`) or its
own. Swapping, extending, or deleting components never touches core.

`pane_width_model.dart` is internal (not exported): the shared math both
widgets use so they resize, clamp, and anchor-snap identically.

---

## 2. The widgets

### `ListDetailLayout<T>`

The main widget. One breakpoint decides the form:

- **Expanded** (width ≥ breakpoint): list and detail side-by-side with a
  draggable divider; `emptyStateBuilder` fills the detail area when nothing
  is selected.
- **Compact** (width < breakpoint): list fills the layout; the detail slides
  over from the end edge with swipe-to-dismiss and back-gesture interception
  (`PopScope`, per `CompactConfig.handleBackGesture`).

Builders receive everything they need — `listBuilder(context, selectedId,
onSelect)` and `detailBuilder(context, id, mode, onDismiss)` — so app code
never touches layout internals.

### `AdaptiveSplit`

The generic sibling: two panes (primary / secondary) with no selection
concept. Expanded = side-by-side with the same draggable divider; compact =
vertical stack or hidden secondary (`SplitCompactBehavior`). Used for
player-style screens where both panes always exist.

### `showAdaptiveModal`

The modal member of the family — a function, not a widget, because modals
are routes. Expanded widths get a real `DialogRoute`; compact widths a real
`ModalBottomSheetRoute` — Material's own chrome, theming, drag physics, and
accessibility. On a resize across the breakpoint the active route is
atomically replaced (`removeRoute` + zero-entrance `push` in one frame) and
the content element reparents into the new route under a stable `GlobalKey`.
A session object proxies the pop result across swaps, so the caller's
awaited future completes with the dismissal value no matter how many form
changes happened. `ModalConfig` only forwards parameters to the two routes.

### `ListDetailController<T>`

`ChangeNotifier`, `ScrollController`-style: omit it and the widget creates
one internally; provide it for programmatic control and router integration.

- `select(id)` / `dismiss()` — data mutations; the widget maps them to
  animations.
- `hasSelection` — data state, immediate.
- `isDetailVisible` — animation-aware: stays `true` during the slide-out so
  app shells can time nav-bar visibility. The widget syncs it via the
  `@internal setAnimatingOut`.

The controller owns data; the widget owns animation (`AnimationController`).
The controller needs no `TickerProvider`.

---

## 3. Compact detail placement — inline vs overlay

`CompactDetailMode` picks WHERE the sliding detail mounts. Both modes share
the same slide animation, swipe gesture, and back handling.

- **`inline`** (default): the detail renders inside the layout's own subtree.
  It cannot cover siblings (bottom nav, tab bars).
- **`overlay`**: the detail renders in an ancestor `Overlay` via
  `OverlayPortal`, so it covers everything the Navigator covers — bottom
  navs, tab bars — while the widget stays in the tree (state preserved).
  `CompactConfig.useRootOverlay` picks the nearest vs root overlay, same
  convention as `Overlay.of` / `Navigator.of`.

### The always-showing portal

The `OverlayPortal` wraps BOTH layout modes and is shown once after the first
frame, never hidden. The overlay child collapses to `SizedBox.shrink()` when
expanded or when no detail is visible. This avoids show/hide toggling on
layout transitions, which would trip `OverlayPortalController`'s assertion
against toggling during the layout phase — and removes the one-frame gap
that toggling would cause.

### Paint-visibility suppression

An `OverlayPortal` escapes its parent's paint. When several overlay-mode
layouts are mounted at once but only one is painted (tab navigation with
kept-alive tabs — `IndexedStack`, `Offstage`, auto-route tab routers), an
inactive tab's overlay would linger on screen. `PaintVisibilityDetector`
closes that hole with a two-phase paint probe:

- **Hide (zero-frame):** the layout's `LayoutBuilder` calls `evaluate()`
  during layout, which reads a was-painted-last-frame flag. Layout runs
  after the previous frame's paint, so the flag is settled: not painted →
  overlay child collapses immediately.
- **Show (one-frame lag):** when paint resumes, `PaintVisibilityObserver`
  (a `RenderProxyBox`) fires during paint and defers the notifier update to
  a post-frame callback (mutating during paint is illegal). The overlay
  reappears next frame.

Fully generic — works with any parent that stops painting inactive children.
Note the hide path needs a subsequent build pass of the inactive child;
real tab switches produce one. The three-invariant contract for editing this
machinery is in [`UPDATING.md`](UPDATING.md).

---

## 4. State preservation across the morph

Detail (and both `AdaptiveSplit` panes) are mounted under stable
`GlobalKey`s. When the layout morphs compact ↔ expanded, Flutter reparents
the same element instead of rebuilding it — text drafts, scroll positions,
and in-flight animations survive a window resize. This is the package's
strongest guarantee and the reason the morph is widget-level rather than
route-based.

The dismiss animation uses the `AnimatedSwitcher` outgoing pattern: when the
selection clears, the outgoing id keeps the detail in the tree until the
exit animation reaches `dismissed` (covering both internal dismissals and
external `controller.dismiss()` calls, via a last-seen-id fallback).

---

The modal extends the same mechanism across routes: all routes of a
Navigator share one Overlay — one element tree — so the keyed content
reparents between the outgoing and incoming route in the swap frame exactly
as pane content does between compact and expanded builds.

## 5. Pane width: config, model, anchors

`PaneConfig` is pure data: `defaultListWidth`, `minListWidth`,
`maxListRatio`, `anchors`, `initialAnchorIndex`, `resizeMode`.

`PaneWidthModel` (internal, shared by both widgets) owns the math:

- **Ratio mode** (default): `defaultListWidth` converts to a proportion of
  the expanded breakpoint (the minimum expanded width), so the pane scales
  with the window from there.
- **Pixels mode:** the pane keeps a fixed pixel width across window resizes.
- **Clamps:** every read clamps to `[minListWidth, maxListRatio × width]`;
  when a narrow window pushes the max below the min, min wins.
- **Anchors:** on drag end the divider animates (220ms, easeOutCubic) to the
  nearest anchor; the divider builder receives `isSettling: true` during the
  animation. Anchor positions are clamped like everything else. Empty
  `anchors` = free dragging, no snap.

The divider itself is a 24px invisible hit zone centered on the pane border;
`dividerBuilder` (nullable) draws the visual inside it. Divider drag is
RTL-aware, and inverted for an end-positioned `AdaptiveSplit` primary.

---

## 6. Configuration resolution

`AdaptiveLayoutConfig` (an `InheritedWidget`) sets the shared breakpoint for
a subtree. Resolution order, everywhere: widget's `expandedBreakpoint` param
→ inherited config → 720 default. RTL comes from ambient `Directionality`:
slide direction, swipe-dismiss direction, and divider drag all flip.

---

## 7. Design decisions

| Decision | Rationale |
|---|---|
| Two-layer core + components | Core is pure layout; components are replaceable defaults. Nullable builder params keep the dependency arrow one-way. |
| Controller pattern | One code path; simple users get an auto-controller, advanced users bring their own. Same as `ScrollController`. |
| `isDetailVisible` animation-aware | App shells need visual state (nav-bar timing), not data state. |
| Widget-level morph, not routes | Instance preservation across resize is the hard guarantee; a route-based compact detail would need a no-transition page dance to keep it. |
| Real Material routes for the modal | Dialogs and sheets should inherit app theme, drag physics, and future framework behavior; the atomic route swap + keyed reparent keeps the instance guarantee without re-implementing chrome. |
| Always-showing portal + paint probe | The only found shape that both dodges `OverlayPortalController`'s layout-phase assertion and suppresses inactive tabs' overlays. |
| `select()` no-op on same id | No guessed intent; toggle is the caller's logic. |
| Selection validation NOT in the package | Layout doesn't know about data existence; the app clears selection when an entity dies (see the example's `selectedIdExists` pattern). |

---

## 8. What's NOT in the package

| Concern | Where it lives |
|---|---|
| Router / URL sync | App code — the example ships a reference `ListDetailRouter` + `MultiTypeListDetailRouter` for auto_route |
| Selection validation (entity deleted?) | App code |
| Multi-type selection (settings-style mixed lists) | App code (example reference) |
| Breakpoint context extensions (`context.isCompact`) | App code |
