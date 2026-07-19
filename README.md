<h1 align="center">adaptive_layouts</h1>

<p align="center">
  <a href="https://pub.dev/packages/adaptive_layouts"><img src="https://img.shields.io/pub/v/adaptive_layouts.svg" alt="pub package"></a>
  <a href="https://pub.dev/packages/adaptive_layouts/score"><img src="https://img.shields.io/pub/likes/adaptive_layouts" alt="likes"></a>
  <a href="https://pub.dev/packages/adaptive_layouts/score"><img src="https://img.shields.io/pub/points/adaptive_layouts" alt="pub points"></a>
  <a href="https://github.com/whuppi/adaptive_layouts"><img src="https://img.shields.io/github/stars/whuppi/adaptive_layouts?style=flat&logo=github" alt="GitHub stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license: MIT"></a>
</p>

Layout widgets that morph between phone and tablet / desktop forms. On a phone, the detail pane slides over the list and covers the bottom nav; on a wide window, the two panes sit side by side with a draggable divider. When the user resizes a desktop window across the breakpoint, the panes rearrange — and the widgets inside them keep their state. A half-typed message survives the resize, because the detail is moved in the tree, not rebuilt.

Three layouts carry the package today: `ListDetailLayout` (list + selected detail, the messaging-app shape), `AdaptiveSplit` (two always-present panes, the player shape), and `showAdaptiveModal` (a real Material dialog on wide windows that is a real Material bottom sheet on narrow ones). Every layout that joins them follows the same rules: router-agnostic, state-management-agnostic, and the smallest possible integration surface — a plain `ChangeNotifier` controller, or just an awaited future.

> **The guarantee that makes this package exist:** pane and modal content *instances* survive the compact ↔ expanded morph. The standard adaptive components (Compose's `ListDetailPaneScaffold`, route-based detail pages) rebuild the detail from saved state instead — cursor position, scroll offset, and in-flight animations reset. Here they don't.

> **Status:** 0.x. The API can change between minor versions until `1.0.0` — pre-1.0, the minor is the breaking axis, so pin `^0.N.0` and read the changelog on minor bumps.

> like it? a [⭐ star](https://github.com/whuppi/adaptive_layouts) or [👍 like](https://pub.dev/packages/adaptive_layouts) is the entire marketing budget. [Bugs & features →](https://github.com/whuppi/adaptive_layouts/issues)

---

<details>
<summary><b>👀 Peek inside</b></summary>

- [Install](#install)
- [Quick start](#quick-start)
- [Usage](#usage)
  - [The controller](#the-controller)
  - [Covering the bottom nav (overlay mode)](#covering-the-bottom-nav-overlay-mode)
  - [Sizing the panes](#sizing-the-panes)
  - [Two panes without a selection](#two-panes-without-a-selection)
  - [A modal that swaps between dialog and bottom sheet](#a-modal-that-swaps-between-dialog-and-bottom-sheet)
  - [One breakpoint for the whole app](#one-breakpoint-for-the-whole-app)
- [Why widget-level morphing](#why-widget-level-morphing)
- [The example app](#the-example-app)
- [Platform support](#platform-support)
- [Not in the box](#not-in-the-box)
- [Docs](#docs)
- [License](#license)

</details>

---

## Install

```yaml
dependencies:
  adaptive_layouts:
```

Pure Flutter — no native code, no assets, no setup, any platform.

---

## Quick start

Two builders, and the layout handles the rest — breakpoint switching, slide animation, swipe-to-dismiss, back-gesture handling, state preservation:

```dart
import 'package:adaptive_layouts/adaptive_layouts.dart';

ListDetailLayout<String>(
  listBuilder: (context, selectedId, onSelect) => ChatList(
    selectedId: selectedId,   // highlight the open row on wide layouts
    onTap: onSelect,          // tapping a row opens its detail
  ),
  detailBuilder: (context, id, mode, onDismiss) => ChatScreen(
    id: id,
    showBackButton: mode == DetailLayoutMode.stacked,     // phone: back arrow
    showCloseButton: mode == DetailLayoutMode.sideBySide, // wide: close X
    onBack: onDismiss,
  ),
)
```

Below 720px the detail slides over the list (`DetailLayoutMode.stacked`); at 720px and above the panes share the width (`DetailLayoutMode.sideBySide`). The `mode` argument tells your detail which affordance to show — everything else is the same widget.

---

## Usage

### The controller

`ListDetailController` works like `ScrollController`: skip it and the widget creates one internally; provide one to drive selection from outside.

```dart
final controller = ListDetailController<String>();

ListDetailLayout<String>(
  controller: controller,
  listBuilder: ...,
  detailBuilder: ...,
)

controller.select('chat-42');   // open programmatically (deep link, router)
controller.dismiss();           // close with the exit animation
```

Two reads with different jobs:

```dart
controller.hasSelection;    // data state — flips the instant dismiss() runs
controller.isDetailVisible; // visual state — stays true until the exit
                            // animation finishes
```

`isDetailVisible` is what an app shell wants for timing UI around the detail — it answers "is the pane still on screen", not "is something selected". URL sync sits on top of these three members; the [example app](example/) ships a complete `ListDetailRouter` for auto_route as reference wiring.

### Covering the bottom nav (overlay mode)

By default the compact detail renders inline, inside the layout's own bounds — it cannot cover a bottom nav or tab bar that sits outside it. Overlay mode can:

```dart
ListDetailLayout<String>(
  compactDetailMode: CompactDetailMode.overlay,
  ...
)
```

The detail now renders in the Navigator's overlay, sliding over everything the Navigator covers — bottom nav, tab bars — while staying in the widget tree with its state intact. `CompactConfig(useRootOverlay: true)` targets the root overlay instead, covering ancestors above the Navigator too.

Overlay mode is built for kept-alive tab navigation: when several overlay-mode layouts are mounted at once (one per tab) and only one tab is painted, the inactive tabs' overlays suppress themselves automatically — hiding is immediate, reappearing takes one frame. Works with `IndexedStack`, `Offstage`, tab routers, or any parent that stops painting inactive children.

And when the compact detail should be a real page — real platform transitions, **predictive back**, Cupertino edge swipes, all from your app's `PageTransitionsTheme`:

```dart
ListDetailLayout<String>(
  compactDetailMode: CompactDetailMode.route,
  ...
)
```

Selecting pushes a genuine page route holding the detail; back is the route's own (no interception). Resize across the breakpoint and the same detail element reparents between the route and the side-by-side pane — the state guarantee holds through real navigation. Hidden kept-alive tabs remove their route (keeping the selection and the detail's state) and restore it instantly when shown again — including when the breakpoint crossing itself happens while the tab is hidden.

One app-side note: every route push makes Flutter scan the shell for `Hero` tags, kept-alive tabs included. If several `FloatingActionButton`s coexist under one page (one per tab), give them explicit `heroTag`s — the shared default tag asserts on the first push.

### The empty detail pane — three schools

When nothing is selected at expanded width, list-detail apps follow one of three established patterns; the package supports all three:

1. **Placeholder** (default) — the pane stays reserved and shows `emptyStateBuilder` (`IconMessageEmpty` ships as a convenience). The Apple Mail / Outlook reading-pane shape.
2. **Auto-select** — never show emptiness: when the list loads and nothing is selected, select the first (or last-used) item from your controller: `controller.select(items.first.id)`. The Notes / Slack shape. This is a data decision, so it stays app-side — the layout doesn't know your data, and auto-selecting can be wrong (empty lists, destructive contexts, deep links). The example app ships the recipe behind a ⚙ toggle.
3. **On-demand pane** — the list owns the full width until a selection summons the pane, which reveals from the end edge; dismissing hands the width back. Material's "supporting pane" shape (Gmail without a reading pane):

```dart
ListDetailLayout<String>(
  expandedEmptyBehavior: ExpandedEmptyBehavior.listOnly,
  ...
)
```

A side effect worth knowing: with `listOnly`, compact and expanded look identical when nothing is selected (a full-width list), so breakpoint crossings without a selection stop being a visible event entirely.

### Picking a compact detail mode

All three modes keep the state guarantee across resizes. They differ in what the open detail covers and who owns the back gesture:

| | `inline` | `overlay` | `route` |
|---|---|---|---|
| Covers bottom nav / tab bars | no | yes | yes — it's a page |
| Dismiss gesture | swipe anywhere on the detail | swipe anywhere on the detail | the platform's own (predictive back on Android, edge swipe on iOS/macOS) |
| Back animation | package slide | package slide | your `PageTransitionsTheme` |
| Android predictive-back preview | lost (back is intercepted) | lost | full |
| Page's snackbars / FABs while open | visible | hidden behind the detail | re-home into the detail's `Scaffold`, like normal navigation |
| Screen readers see covered content | no — excluded while open | no — blocked while open | no — it's a page |
| Escape dismisses (desktop) | yes, when focus is in the detail | yes, when focus is in the detail | yes — the route's own `DismissIntent` |
| Crossing into compact, detail open | detail grows out of its pane | detail grows out of its pane | the route's real entrance plays |
| Crossing into expanded, detail open | list slides in beside the detail | list slides in beside the detail | list slides in beside the detail |
| Hero discipline (`heroTag`s) | not needed | not needed | needed |

Rule of thumb: `inline` when the surrounding chrome should stay present, `overlay` for a full-screen feel without real navigation, `route` when the detail should behave like a native page and inherit every platform back-gesture convention as it evolves. The per-value doc comments on `CompactDetailMode` carry the full contracts.

Breakpoint crossings animate the pane re-arrangement in every mode — fold/unfold, rotation, split-screen snap, or dragging the window edge across the threshold. Only the pane geometry itself tracks the drag without motion (a lagging pane would fight your hand); the arrangement flip is always animated, the way Compose's canonical scaffolds and desktop sidebars behave. That includes the EMPTY placeholder pane: with nothing selected it reveals from the end edge on expand and retreats into it on shrink.

Entering expanded, the arriving list is laid out at its final width and slides in clipped — content never reflows mid-entry, the way a desktop sidebar arrives. Prefer the list to lay out live and grow into its pane instead? `PaneConfig(entryStyle: ExpandedEntryStyle.resize)`.

The divider remembers. A dragged divider position survives compact spells, window resizes, and rebuilds — `PaneConfig` compares by value, so constructing it inline in `build` never resets the width model. Prefer a fresh divider on every return to the wide layout instead? `PaneConfig(widthMemory: PaneWidthMemory.resetOnReentry)`.

### Sizing the panes

`PaneConfig` is pure data; the divider visual is a builder you pick or write:

```dart
ListDetailLayout<String>(
  paneConfig: const PaneConfig(
    defaultListWidth: 300,  // starting width, scaled from the breakpoint
    minListWidth: 240,      // drag floor
    maxListRatio: 0.4,      // drag ceiling, as a share of the window
  ),
  dividerBuilder: HandleDivider.builder,  // macOS-style hover + drag handle
  ...
)
```

Ships with two dividers — `HandleDivider` (resize cursor, three-dot handle, settle tint) and `MaterialDivider` (thin line) — or pass your own `DividerBuilder`. Null means an invisible drag zone: resizing still works, nothing is drawn.

Two extras for desktop-grade feel:

```dart
// Snap points: on release, the divider animates to the nearest anchor.
PaneConfig(
  anchors: [PaneAnchor.fromStart(240), PaneAnchor.proportion(0.5)],
  initialAnchorIndex: 0,
)

// Fixed width: the pane keeps its pixel width when the window resizes
// (default is ratio — the pane scales with the window).
PaneConfig(resizeMode: PaneResizeMode.pixels)
```

### Snap-collapse and the divider's keyboard

Panes can collapse — force the divider past a pane's minimum and it snaps
shut, VS Code style. Opt in per side:

```dart
PaneConfig(
  collapsible: PaneCollapsible.start,  // none / start / end / both
  collapsedSize: 56,                   // 0 hides fully; 56 keeps an icon rail
)
```

The mechanics follow desktop split views: dragging past the limit by half
the pane's minimum snaps it to `collapsedSize` with the pre-collapse width
remembered; releasing short of that springs back. The parked divider stays
grabbable (the shipped `HandleDivider` turns into a pull tab), and the
surviving pane can offer its own affordance by reading `PaneScope`:

```dart
// Inside a detail pane — the hamburger recipe:
final scope = PaneScope.maybeOf(context);
if (scope?.collapsed == PaneSide.start)
  IconButton(icon: const Icon(Icons.menu), onPressed: scope!.restore)
```

`PaneScope` also exposes `collapse(PaneSide)` for app-driven collapse
buttons. Programmatic collapse/restore snap instantly; the drag path is
the animated one.

The divider itself follows the WAI-ARIA window-splitter pattern — it's
focusable and screen-reader adjustable out of the box:

| Input | Effect |
|---|---|
| Arrow left / right | Resize by 24px |
| Enter | Collapse the allowed side / restore |
| Home / End | Animate to the minimum / maximum |
| Double click | Reset to the default width (restore first if collapsed) |
| Screen reader | Adjustable element announcing the pane's share ("36%") |

Localize the announcement via `PaneConfig(dividerSemanticsLabel: ...)`.

For the wide layout's "nothing selected" area, pass any builder — or the shipped one:

```dart
emptyStateBuilder: IconMessageEmpty.of(
  icon: Icons.chat_bubble_outline,
  message: 'Select a conversation',
)
```

### Two panes without a selection

`AdaptiveSplit` is the sibling for screens where both panes always exist — a player with its queue, an editor with its preview:

```dart
AdaptiveSplit(
  primaryBuilder: (context, isExpanded) => PlayerHero(),
  secondaryBuilder: (context, isExpanded) => QueueList(),
  dividerBuilder: HandleDivider.builder,
  compactBehavior: SplitCompactBehavior.stack,  // or .hidden
)
```

Wide: side by side with the same draggable divider (primary at the start or end via `primaryPosition`). Narrow: a vertical stack, or primary only. Both panes keep their state across the morph, same as the detail pane does.

### Three panes by role priority

`ThreePaneLayout` is the pane-scaffold shape from Material's adaptive
layouts: up to three panes that appear and yield as the window grows.
Two thresholds carve the width into partitions (one pane below the
expanded breakpoint, two below `largeBreakpoint`, three above). Roles
decide WHO wins a slot — `primary` survives to the narrowest window —
and the pane list's order decides WHERE, decoupled from priority:

```dart
ThreePaneLayout(
  panes: [
    PaneSpec(role: PaneRole.secondary, preferredWidth: 300,
        builder: (_) => Outline()),
    PaneSpec(role: PaneRole.primary, builder: (_) => Editor()),
    PaneSpec(role: PaneRole.tertiary, preferredWidth: 280,
        builder: (_) => Inspector()),
  ],
)
```

The highest-priority visible pane flexes; the others hold draggable
widths (full divider contract — drag, keyboard, double-click reset,
screen readers). Hidden panes stay alive offstage with tickers paused,
so an inspector's scroll position survives the window shrinking and
growing back (`retainHiddenPanes: false` opts out).

Use `ListDetailLayout` when compact needs list/detail *navigation*;
use `ThreePaneLayout` when panes are supporting surfaces that simply
yield to width.

### A modal that swaps between dialog and bottom sheet

`showAdaptiveModal` presents a real Material dialog on wide windows and a real Material bottom sheet on narrow ones — `DialogRoute` and `ModalBottomSheetRoute` underneath, so your `DialogTheme` / `BottomSheetTheme`, Material's drag physics, and back handling all apply. Resize across the breakpoint while it is open and the modal plays a container transform: the surface glides and reshapes from one form to the other with the live content inside, and a half-typed form field survives the trip. `ModalConfig(morph: false)` swaps instantly instead.

```dart
final choice = await showAdaptiveModal<String>(
  context: context,
  config: const ModalConfig(showDragHandle: true),
  builder: (context, mode) => SizedBox(
    width: mode == ModalLayoutMode.dialog ? 420 : double.infinity,
    child: NewTicketForm(),
  ),
);
```

`ModalConfig` forwards Flutter's own route parameters under Flutter's own names — barrier label and dismissibility, safe area, sheet constraints and drag, anchor points, focus and traversal behavior, entrance `AnimationStyle`s — with null always meaning "Flutter's default", so new platform behavior reaches you without package releases. Visual styling (shape, elevation, drag-handle look) is deliberately NOT duplicated here: it flows through `DialogThemeData` / `BottomSheetThemeData` as usual. Two params are withheld on purpose: the sheet's `clipBehavior` (the container transform's landing is pixel-matched against `Clip.antiAlias`) and `transitionAnimationController` (the swap machinery owns the routes' lifecycles).

The returned future completes with the pop result no matter how many form swaps happened while the modal was open. Each form keeps its own Material surface tone (`surfaceContainerHigh` for dialogs, `surfaceContainerLow` for sheets, themable as usual); `ModalConfig(backgroundColor: ...)` pins one color across both forms when the crossfade is unwanted. One contract: return the same root widget type for both modes (like the `SizedBox` above) — the content moves between the two routes under a stable key, and a changed root type would defeat the move.

### One breakpoint for the whole app

Set it once above `MaterialApp`; every layout in the subtree inherits it. A widget's own `expandedBreakpoint` parameter still wins when you need a local exception; with neither, the default is 720.

```dart
AdaptiveLayoutConfig(
  expandedBreakpoint: 800,
  child: MaterialApp(...),
)
```

---

## Why widget-level morphing

<details>
<summary><b>🧩 Why not push the detail as a route on phones?</b></summary>

A route-based compact detail gets platform behaviors free (predictive back, edge swipe), but the detail then lives inside a page — and pages rebuild their content from state. Carrying one widget instance between "pane 2 of a wide layout" and "a pushed route" means either lifting every piece of ephemeral state out of the widgets, or a fragile zero-transition page dance around duplicate `GlobalKey`s mid-animation.

This package keeps both layouts inside one widget instead. The detail mounts under a stable `GlobalKey`, so the morph reparents the same element — Flutter's documented mechanism for moving a widget without losing its state. The cost is owned in exchange: the slide animation, swipe-to-dismiss, and back handling are implemented here rather than inherited from the Navigator. That trade — a stronger state guarantee for a self-implemented navigation feel — is the package's identity.

</details>

<details>
<summary><b>🧩 How overlay mode survives tab navigation</b></summary>

An `OverlayPortal` paints in the Overlay, outside its parent — so a parent that stops painting (an inactive `IndexedStack` child) cannot take its overlay down with it. The layout closes that hole by probing paint itself: a render object reports "I was painted this frame", and the layout checks the flag during the next layout pass. Not painted last frame means the tab is inactive, and the overlay child collapses to nothing. The portal itself is shown once and never toggled, which sidesteps `OverlayPortalController`'s restriction against show/hide during layout. The full contract, including the invariants to keep when editing this machinery, is in [`docs/UPDATING.md`](docs/UPDATING.md).

</details>

<details>
<summary><b>🧩 Why the modal uses real Material routes</b></summary>

The pane layouts own their navigation feel in exchange for the state guarantee. The modal gets both: each form is Flutter's own route (`DialogRoute`, `ModalBottomSheetRoute`), so theming, drag-to-dismiss physics, and back handling are Material's — and framework improvements arrive with Flutter upgrades. On a breakpoint crossing the active route is atomically replaced in a single frame, and since every route of a Navigator lives in one Overlay — one element tree — the keyed content reparents into the new route instead of rebuilding. A session object proxies the pop result across swaps, so the caller's awaited future never notices.

The swap animation is Material's container-transform pattern with one upgrade Material itself doesn't have: `Hero` and `OpenContainer` both rebuild the content they animate, while this flight carries the *live element* — the surface lerps rect, shape, color, and elevation between the two forms with your widget's state intact inside it. The destination route lays out a same-size placeholder whose live rect steers the landing each frame, so keyboard insets and content reflow are tracked automatically.

</details>

---

## The example app

[`example/`](example/) is a full app in one file, not a snippet gallery: three domains behind an adaptive shell (bottom nav ↔ rail), nested tab routers, URL-synced list-details in overlay mode inside every tab, adaptive modals, and a persistent strip above the router. It exists so package changes are tested against the hardest real topology — its `flutter test` journeys cover resize state preservation, overlay suppression across tabs, deep links, and auto-dismiss on deletion.

```sh
cd example
flutter run -d chrome   # the URL bar shows the deep-link sync live
flutter test            # the journey suite
```

---

## Platform support

Pure Flutter, no conditional imports, no platform code:

| Android | iOS | macOS | Windows | Linux | Web |
|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## Not in the box

- **Router / URL integration** — deliberately. The controller is the seam; wire it to any router. The example ships complete auto_route reference wiring (`ListDetailRouter`, `MultiTypeListDetailRouter`) to copy from.
- **Selection validation** — the layout does not know whether `chat-42` still exists. When an entity is deleted, the app clears the selection (the example's `selectedIdExists` pattern shows how, including why the dismissal must be deferred out of the build phase).
- **Navigation bars, rails, tab bars** — this package lays out panes; the shell around them is your app's.

---

## Docs

The README covers the everyday stuff. wanna go deeper?

| Doc | What's inside |
|---|---|
| [Architecture](docs/ARCHITECTURE.md) | How it's built: the two-layer split, the overlay machinery, the width model, design decisions |
| [Capabilities](docs/CAPABILITY_ROADMAP.md) | Every capability with status, plus the explicit non-goals |
| [Updating](docs/UPDATING.md) | Maintenance recipes and the invariants that must not break |
| [Example](example/) | The full-app integration reference, journeys checked by test |

---

## License

MIT. See [LICENSE](LICENSE).
