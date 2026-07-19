# adaptive_layouts — Capability Roadmap

> **Type:** roadmap · **Scope:** adaptive_layouts · **Last verified:** 2026-07-19
> **Companion docs:** [`ARCHITECTURE.md`](ARCHITECTURE.md) · [`UPDATING.md`](UPDATING.md)

Every capability the package offers or plans, with status. Nothing ships
while an active row is not `DONE` or `WONT_DO`. Statuses: `DONE` ·
`BUILDING` · `PLANNED` · `WONT_DO` (with reason).

---

## ListDetailLayout

| Capability | Status | Notes |
|---|---|---|
| Compact ↔ expanded morph at breakpoint | DONE | `LayoutBuilder`-driven; per-widget / inherited / 720 resolution |
| Detail state preservation across the morph | DONE | GlobalKey reparenting; covered by resize tests + example journeys |
| Side-by-side panes with draggable divider | DONE | Configurable hit zone (`dividerHitWidth`, default 24); nullable visual builder |
| Compact slide-over with swipe-to-dismiss | DONE | Threshold + fling velocity, both configurable |
| Back-gesture interception on compact | DONE | `PopScope`; opt-out via `CompactConfig.handleBackGesture` |
| Exit animation with outgoing-detail retention | DONE | AnimatedSwitcher pattern; internal + external dismiss paths |
| Controller (auto-created or injected) | DONE | `select` / `dismiss` / `hasSelection` / animation-aware `isDetailVisible` |
| Inline compact mode | DONE | Default; detail stays inside the layout's bounds |
| Overlay compact mode (covers bottom nav / tabs) | DONE | Always-showing `OverlayPortal`; nearest or root overlay |
| Overlay suppression for inactive kept-alive tabs | DONE | Paint-visibility probe; zero-frame hide, one-frame re-show |
| True-route compact mode (`CompactDetailMode.route`) | DONE | Real `PageRoute` with the app's `PageTransitionsTheme` (predictive back, edge swipes); atomic resize swaps reparent the detail between route and pane; paint-probe suppression for hidden tabs; the feared pop-handoff never existed — dismissal kills the detail by design, so predictive back is free |
| Empty state builder (expanded, no selection) | DONE | Nullable; `IconMessageEmpty` shipped as a convenience |
| RTL support | DONE | Slide, swipe, and divider drag are direction-aware |
| A11y route parity for inline/overlay details | DONE | Open detail scopes as a route; covered content leaves the semantics tree (`ExcludeSemantics` / `BlockSemantics`); `DismissIntent` (Escape) dismisses with focus inside |
| Breakpoint-crossing motion (both directions) | DONE | Into compact: detail grows out of its pane (inline/overlay) or the route's real entrance plays. Into expanded: the list slides in beside the full-width detail. Pane geometry still tracks drags without motion. Exception: parked (collapsed) panes arrive docked — no collapse replay on crossings |
| Expand-entry list style (reveal / resize) | DONE | `PaneConfig.entryStyle`: reveal (default — final-width, clipped, no reflow) or resize (lays out live, grows into the pane) |
| Divider position memory | DONE | Survives compact spells + rebuilds; `PaneConfig`/`PaneAnchor` value equality (incl. NaN-sentinel anchors) — inline-constructed configs never reset the model. `PaneWidthMemory.resetOnReentry` opts into a fresh divider per expanded spell (ListDetailLayout + SplitLayout) |
| Deep-link-friendly controller semantics | DONE | Initial selection renders without animation; example ships URL sync |
| Empty detail slot behaviors | DONE | `ExpandedEmptyBehavior`: placeholder (default, `emptyStateBuilder`) or listOnly (full-width list; the pane reveals from the end edge on selection, retreats on dismiss). Auto-select-first stays an app-side recipe (documented; example ⚙ toggle) |

## SplitLayout

| Capability | Status | Notes |
|---|---|---|
| Two-pane side-by-side with draggable divider | DONE | Same divider contract + width model as ListDetailLayout |
| Primary at start or end | DONE | Drag direction inverts for end-positioned primary |
| Compact: vertical stack or hidden secondary | DONE | `SplitCompactBehavior` |
| Pane state preservation across the morph | DONE | GlobalKeys on both panes |

## Adaptive modal (`showAdaptiveModal`)

| Capability | Status | Notes |
|---|---|---|
| Real Material routes per form | DONE | `DialogRoute` on expanded, `ModalBottomSheetRoute` on compact — chrome, theming, a11y all Material's |
| Live dialog ↔ sheet swap on resize | DONE | Atomic `removeRoute` + zero-entrance `push`; one-frame handoff |
| Content state preserved across swaps | DONE | `GlobalKey` reparent through the shared Navigator overlay; unit tests + example journey |
| Result future survives swaps | DONE | Session completer with route-identity guard |
| Breakpoint resolution | DONE | param > inherited `AdaptiveLayoutConfig` > 720, resolved at call time |
| Config forwarding | DONE | Native passthroughs under Flutter's names: barrier (color/dismissible/label), safe area, scroll control + max-height ratio, drag + handle, sheet constraints, anchorPoint, traversalEdgeBehavior, requestFocus, entrance AnimationStyles, routeSettings, useRootNavigator. Withheld by design: sheet clipBehavior (morph landing parity), transitionAnimationController (swap machinery owns route lifecycles). Styling stays on Dialog/BottomSheet themes |
| Animated cross-form morph (container transform) | DONE | Flight overlay carries the LIVE content between the real routes; placeholder-tracked landing; retarget + mid-flight-dismiss handled; `morph: false` restores the cut |

## Pane system (shared)

| Capability | Status | Notes |
|---|---|---|
| Ratio resize mode (pane scales with window) | DONE | Default; `defaultListWidth` referenced to the breakpoint |
| Pixels resize mode (pane fixed across resizes) | DONE | `PaneResizeMode.pixels` |
| Min-width / max-ratio clamping | DONE | Min wins when the window is too narrow for the ratio cap |
| Snap-collapse panes (VS Code spec) | DONE | `PaneCollapsible` per side + `collapsedSize` icon-rail; half-minimum threshold, cached-width restore, pull-tab `HandleDivider`; directional API preserved for `SplitLayout` end-positioned primary |
| Collapsed icon-rail slots | DONE | `collapsedListBuilder`/`collapsedDetailBuilder` (+ split equivalents): rail lays out at the real `collapsedSize`; the pane parks offstage (tickers paused) with its state alive; list pane gained its own reparenting GlobalKey |
| Divider keyboard + screen-reader support | DONE | WAI-ARIA window splitter: Tab-focusable, arrows resize, Enter toggles collapse, Home/End jump, double-click resets; semantics increase/decrease with pane-share value |
| PaneScope (pane state for descendants) | DONE | `collapsed`/`collapsedSize`/`isExpanded` + `collapse`/`restore` actions; the show-sidebar recipe gated on fully-hidden |
| Anchor snap points with settle animation | DONE | Nearest anchor on drag end; `isSettling` fed to divider builders; duration/curve via `PaneConfig.settleDuration`/`settleCurve` |
| Initial width from anchor index | DONE | `PaneConfig.initialAnchorIndex`, anchors non-empty |

## Components

| Capability | Status | Notes |
|---|---|---|
| `HandleDivider` (hover + drag handle + settle tint) | DONE | Desktop-grade: resize cursor, three-dot handle |
| `MaterialDivider` (thin line + active state) | DONE | |
| `IconMessageEmpty` empty state | DONE | `IconMessageEmpty.of(icon:, message:)` |

## Infrastructure

| Capability | Status | Notes |
|---|---|---|
| Package test suite mirroring `src/` | DONE | 174 tests: unit (controller, anchors, width model, collapse) + widget (layouts, modes, crossings, rails, divider keyboard/semantics, components) |
| Full-app example with journey tests | DONE | `example/` — nested tab routers, URL sync, modals, collapse rails; 12 journeys |
| Three canonical docs | DONE | This set |

## Explicit non-goals

| Capability | Status | Reason |
|---|---|---|
| Router integration in the package | WONT_DO | Router-agnostic by design; the example ships the auto_route reference wiring |
| Selection validation (entity existence) | WONT_DO | Layout must not know about data lifecycle; app clears selection |
| Navigator-page-based compact detail | WONT_DO | Would trade away instance preservation across resize (or force a no-transition page dance); the widget-level morph is the product |
| Three-pane (list + detail + extra) | PLANNED | Only when a real consumer needs it — compose two widgets until then |
