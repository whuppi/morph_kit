<h1 align="center">morph_kit</h1>

<p align="center">
  <a href="https://pub.dev/packages/morph_kit"><img src="https://img.shields.io/pub/v/morph_kit.svg" alt="pub package"></a>
  <a href="https://pub.dev/packages/morph_kit/score"><img src="https://img.shields.io/pub/likes/morph_kit" alt="likes"></a>
  <a href="https://pub.dev/packages/morph_kit/score"><img src="https://img.shields.io/pub/points/morph_kit" alt="pub points"></a>
  <a href="https://github.com/whuppi/morph_kit"><img src="https://img.shields.io/github/stars/whuppi/morph_kit?style=flat&logo=github" alt="GitHub stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license: MIT"></a>
</p>

Layout widgets that morph between phone and desktop forms. On a phone, the detail slides over the list; on a wide window, the panes sit side by side with a draggable divider. Resize across the breakpoint and the panes rearrange — while the widgets inside them **keep their state**: a half-typed message survives the resize, because the pane is moved in the tree, not rebuilt. Router-agnostic and state-management-agnostic; the integration surface is a plain `ChangeNotifier` controller, or just an awaited future.

> **Why a package? Isn't this just a `LayoutBuilder` with two branches?** A branch REBUILDS: the moment the window crosses the breakpoint, your detail widget is torn down and recreated — cursor position, scroll offset, and running animations reset. The standard adaptive components (Compose's `ListDetailPaneScaffold`, the typical push-a-detail-page flow) share the same weakness. This package moves the live widget *instances* between arrangements instead, in every mode — including a real-route mode where the detail reparents through genuine page navigation.

> **Status:** 0.x. Pre-1.0 the minor version is the breaking axis — pin `^0.N.0` and read the changelog on minor bumps.

> like it? a [⭐ star](https://github.com/whuppi/morph_kit) or [👍 like](https://pub.dev/packages/morph_kit) is the entire marketing budget. [Bugs & features →](https://github.com/whuppi/morph_kit/issues)

---

<details>
<summary><b>👀 Peek inside</b></summary>

- [Install](#install)
- [Quick start](#quick-start)
- [The morph](#the-morph)
- [Usage](#usage)
  - [The controller](#the-controller)
  - [Compact detail modes](#compact-detail-modes)
  - [The empty detail pane](#the-empty-detail-pane)
  - [Two peer panes — SplitLayout](#two-peer-panes--splitlayout)
  - [Sizing the panes](#sizing-the-panes)
  - [Snap-collapse and icon rails](#snap-collapse-and-icon-rails)
  - [The divider's keyboard and screen readers](#the-dividers-keyboard-and-screen-readers)
  - [A modal that swaps between dialog and sheet](#a-modal-that-swaps-between-dialog-and-sheet)
  - [One breakpoint for the whole app](#one-breakpoint-for-the-whole-app)
- [Platform support](#platform-support)
- [Not in the box](#not-in-the-box)
- [Docs](#docs)

</details>

---

## Install

```yaml
dependencies:
  morph_kit: ^0.1.1
```

Nothing else to do, on any platform. Pure Flutter: no native code, no assets, no setup.

---

## Quick start

Two builders, and the layout handles the rest — breakpoint switching, slide animation, swipe-to-dismiss, back gestures, state preservation:

```dart
import 'package:morph_kit/morph_kit.dart';

ListDetailLayout<String>(
  listBuilder: (context, selectedId, onSelect) => ChatList(
    selectedId: selectedId,   // highlight the open row on wide windows
    onTap: onSelect,          // tapping a row opens its detail
  ),
  detailBuilder: (context, id, mode, onDismiss) => ChatScreen(
    id: id,
    showBackButton: mode == DetailLayoutMode.stacked,     // narrow: back arrow
    showCloseButton: mode == DetailLayoutMode.sideBySide, // wide: close X
    onBack: onDismiss,
  ),
)
```

Below the breakpoint (default 720, [configurable app-wide](#one-breakpoint-for-the-whole-app)) the detail slides over the list; at or above it, the panes share the width. Narrow is called **compact** in this package; wide is **expanded**.

Three widgets, one per situation:

```dart
// 1. A list that DRIVES a detail: chats, tickets, inbox.
ListDetailLayout(listBuilder: ..., detailBuilder: ...)

// 2. Two panes that are PEERS — nobody selects anybody:
//    player + queue, editor + preview.
SplitLayout(primaryBuilder: ..., secondaryBuilder: ...)

// 3. A one-off surface the user summons: forms, pickers, confirmations.
//    Real dialog when expanded, real bottom sheet when compact.
await showAdaptiveModal(context: context, builder: ...)
```

---

## The morph

Every widget here makes the same promise when the window crosses the breakpoint: the panes rearrange, the *content* carries over. Four rules hold everywhere:

- **State survives.** Pane and modal content mounts under stable keys; a breakpoint crossing reparents the live element instead of rebuilding it. Text fields, scroll positions, and running animations carry across.
- **Crossings animate; drags track.** The arrangement flip (fold/unfold, rotation, window crossing the threshold) animates in both directions — including the empty placeholder pane — with one exception, two bullets down. Pane *geometry* tracks a window drag without added motion, because a lagging pane would fight your hand.
- **Arriving panes don't reflow.** Entering expanded, the list is laid out at its final width and slides in clipped — content never reflows mid-entry, the way a desktop sidebar arrives. Prefer live reflow? `PaneConfig(entryStyle: ExpandedEntryStyle.resize)`.
- **Parked panes don't dance.** A collapsed pane arrives already collapsed: its rail docks at the parked width from the first expanded frame. The collapse animation belongs to the moment the user collapsed — a window resize isn't that moment.

<details>
<summary><b>🧩 why the foundation is widget-level morphing, not routes</b></summary>

<br>

The obvious way to build an adaptive list-detail is route-based: on compact, push the detail as a page. It gets platform behaviors free — but a pushed page rebuilds its content from state, so the naive version loses cursor position, scroll offset, and running animations on every breakpoint crossing.

This package's foundation is one widget owning both arrangements instead. The detail mounts under a stable `GlobalKey`, and the morph reparents the same element — Flutter's documented mechanism for moving a widget without losing its state. In `inline` and `overlay` modes the cost of that choice is owned directly: the slide animation, swipe-to-dismiss, and back handling are implemented here rather than inherited from the Navigator.

`CompactDetailMode.route` then earns the platform behaviors back **on top of** that foundation: the pushed page hosts the same keyed element, and the layout choreographs the handoff so the key has exactly one owner per frame. A route-first design can't do this dance, because nobody outside the routes owns the element's lifecycle; a widget-first design can, because the layout always does. That layering — widget-level state engine underneath, real navigation opted in on top — is the package's identity.

</details>

---

## Usage

### The controller

`ListDetailController` works like `ScrollController`: skip it and the widget creates one internally; provide one to drive selection from outside.

```dart
final controller = ListDetailController<String>();

controller.select('chat-42');   // open programmatically (deep link, router)
controller.dismiss();           // close with the exit animation

controller.hasSelection;        // data state — flips the instant dismiss() runs
controller.isDetailVisible;     // visual state — stays true until the exit
                                // animation finishes (app-shell timing)
```

URL sync sits on top of these members; the [example app](example/) ships a complete `ListDetailRouter` for auto_route as reference wiring.

### Compact detail modes

`compactDetailMode` decides what the open detail is on compact widths:

```dart
ListDetailLayout<String>(
  compactDetailMode: CompactDetailMode.overlay,   // or .inline / .route
  ...
)
```

- **`inline`** (default) — the detail renders inside the layout's own bounds. Surrounding chrome (bottom nav, tab bar) stays visible.
- **`overlay`** — the detail renders in the Navigator's overlay and covers everything the Navigator covers: bottom nav, tab bars. Built for kept-alive tab navigation — inactive tabs suppress their overlays automatically. `CompactConfig(useRootOverlay: true)` covers ancestors above the Navigator too.
- **`route`** — selecting pushes a genuine page route holding the detail. Platform transitions, **predictive back**, Cupertino edge swipes — all from your app's `PageTransitionsTheme`, evolving with Flutter. Resize across the breakpoint and the same detail element reparents between the route and the side-by-side pane. Hidden kept-alive tabs remove their route (keeping the selection and the detail's state) and restore it instantly when shown again.

Rule of thumb: `inline` when the chrome should stay, `overlay` for a full-screen feel without real navigation, `route` when the detail should behave like a native page.

<details>
<summary><b>🧰 the full mode comparison table</b></summary>

<br>

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
| Hero discipline (`heroTag`s) | not needed | not needed | needed — explicit `heroTag` per FAB when several coexist under one page |

The per-value doc comments on `CompactDetailMode` carry the full contracts.

</details>

### The empty detail pane

When nothing is selected at expanded width, list-detail apps follow one of three established patterns; the package supports all three:

1. **Placeholder** (default) — the pane stays reserved and shows `emptyStateBuilder`. The Apple Mail reading-pane pattern.

   ```dart
   emptyStateBuilder: IconMessageEmpty.of(
     icon: Icons.chat_bubble_outline,
     message: 'Select a conversation',
   )
   ```

2. **Auto-select** — never show emptiness: when the list loads with no selection, call `controller.select(items.first.id)`. The Notes / Slack pattern. This is a data decision, so it stays app-side — the layout doesn't know your data, and auto-selecting can be wrong (empty lists, destructive contexts, deep links). The example ships the recipe behind a ⚙ toggle.

3. **On-demand pane** — the list owns the full width until a selection reveals the pane from the end edge; dismissing hands the width back. Material's "supporting pane" pattern:

   ```dart
   expandedEmptyBehavior: ExpandedEmptyBehavior.listOnly
   ```

   Side effect worth knowing: with `listOnly`, compact and expanded look identical when nothing is selected (a full-width list), so breakpoint crossings without a selection stop being a visible event.

### Two peer panes — SplitLayout

Both panes always exist, neither drives the other:

```dart
SplitLayout(
  primaryBuilder: (context, isExpanded) => PlayerHero(),
  secondaryBuilder: (context, isExpanded) => QueueList(),
  dividerBuilder: HandleDivider.builder,
  compactBehavior: SplitCompactBehavior.stack,  // or .hidden
)
```

Expanded: side by side with the same draggable divider (primary at the start or end via `primaryPosition`). Compact: a vertical stack, or the primary alone. Everything below about sizing, collapse, rails, and the divider's keyboard applies to `SplitLayout` identically (`collapsedPrimaryBuilder` / `collapsedSecondaryBuilder` are its rail slots).

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

Ships with two dividers — `HandleDivider` (resize cursor, three-dot handle, settle tint, pull tab when collapsed) and `MaterialDivider` (thin line) — or pass your own `DividerBuilder`. Null means an invisible drag zone: resizing still works, nothing is drawn.

<details>
<summary><b>🧰 anchors, resize modes, width memory</b></summary>

<br>

```dart
// Snap points: on release, the divider animates to the nearest anchor.
PaneConfig(
  anchors: [PaneAnchor.fromStart(240), PaneAnchor.proportion(0.5)],
  initialAnchorIndex: 0,
)

// Fixed width: the pane keeps its pixel width when the window resizes
// (default is ratio — the pane scales with the window).
PaneConfig(resizeMode: PaneResizeMode.pixels)

// Fresh divider on every return to expanded
// (default is persist — a dragged position survives compact spells).
PaneConfig(widthMemory: PaneWidthMemory.resetOnReentry)
```

The divider remembers by default: a dragged position survives compact spells, window resizes, and rebuilds. `PaneConfig` compares by value, so constructing it inline in `build` never resets the width model.

</details>

### Snap-collapse and icon rails

Expanded-only: force the divider past a pane's minimum and the pane snaps shut, the way desktop split views do. Opt in per side:

```dart
PaneConfig(
  collapsible: PaneCollapsible.start,  // none / start / end / both
  collapsedSize: 56,                   // 0 hides fully; 56 keeps an icon rail
)
```

Dragging past the limit by half the pane's minimum snaps it to `collapsedSize`, with the pre-collapse width remembered; releasing short of that springs back. The parked divider stays grabbable — pull it back out to restore.

**The rail.** With a non-zero `collapsedSize`, give the collapsed pane purpose-built content — it lays out at the actual collapsed width, and the real pane parks offstage with its state alive until restored:

```dart
ListDetailLayout(
  collapsedListBuilder: (context) => MyIconRail(
    onExpand: PaneScope.of(context).restore,
  ),
  ...
)
```

Without a rail builder, the collapsed pane shows its normal content clipped at its minimum width.

**The scope.** Any widget inside either pane can read the collapse state and act on it through `PaneScope` — the show-sidebar recipe:

```dart
// Inside a detail pane. Gate on collapsedSize == 0: a visible icon
// rail already carries the expand control, so only a FULLY hidden
// pane needs its own affordance.
final scope = PaneScope.maybeOf(context);
if (scope?.collapsed == PaneSide.start && scope!.collapsedSize == 0)
  IconButton(
    icon: const Icon(Icons.view_sidebar_outlined),
    onPressed: scope.restore,
  )
```

`PaneScope` also exposes `collapse(PaneSide)` for app-driven collapse buttons. Programmatic collapse and restore snap instantly; the drag path is the animated one.

### The divider's keyboard and screen readers

The divider follows the WAI-ARIA window-splitter pattern out of the box:

| Input | Effect |
|---|---|
| Tab | focuses the divider (`DividerState.isFocused` for your visual) |
| Arrow left / right | resize by 24px |
| Enter | collapse the allowed side / restore |
| Home / End | animate to the minimum / maximum |
| Double click | reset to the default width (restore first if collapsed) |
| Screen reader | adjustable element announcing the pane's share ("36%") |

Localize the announcement via `PaneConfig(dividerSemanticsLabel: ...)`.

### A modal that swaps between dialog and sheet

A real Material dialog on expanded, a real Material bottom sheet on compact — `DialogRoute` and `ModalBottomSheetRoute` underneath, so your `DialogTheme` / `BottomSheetTheme`, Material's drag physics, and back handling all apply:

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

Resize across the breakpoint while it is open and the modal plays a container transform: the surface glides and reshapes from one form to the other **with the live content inside** — a half-typed form field survives the trip. The returned future completes with the pop result no matter how many swaps happened. `ModalConfig(morph: false)` swaps instantly instead.

One contract: return the same root widget type for both modes (like the `SizedBox` above) — the content moves between the two routes under a stable key, and a changed root type would defeat the move.

<details>
<summary><b>🧰 what ModalConfig forwards, and what it deliberately doesn't</b></summary>

<br>

`ModalConfig` forwards Flutter's own route parameters under Flutter's own names — barrier label and dismissibility, safe area, sheet constraints and drag, anchor points, focus and traversal behavior, entrance `AnimationStyle`s — with null always meaning "Flutter's default", so new platform behavior reaches you without package releases.

Visual styling (shape, elevation, drag-handle look) is deliberately NOT duplicated here: it flows through `DialogThemeData` / `BottomSheetThemeData` as usual. Each form keeps its own Material surface tone (`surfaceContainerHigh` for dialogs, `surfaceContainerLow` for sheets); `ModalConfig(backgroundColor: ...)` pins one color across both forms.

Two params are withheld on purpose: the sheet's `clipBehavior` (the container transform's landing is pixel-matched against `Clip.antiAlias`) and `transitionAnimationController` (the swap machinery owns the routes' lifecycles).

</details>

### One breakpoint for the whole app

Set it once above `MaterialApp`; every layout and modal in the subtree inherits it. A widget's own `expandedBreakpoint` parameter still wins for a local exception; with neither, the default is 720.

```dart
AdaptiveLayoutConfig(
  expandedBreakpoint: 800,
  child: MaterialApp(...),
)
```

---

## Platform support

Pure Flutter, no conditional imports, no platform code:

| Android | iOS | macOS | Windows | Linux | Web |
|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

<details>
<summary><b>🧩 how overlay mode survives tab navigation</b></summary>

<br>

An `OverlayPortal` paints in the Overlay, outside its parent — so a parent that stops painting (an inactive `IndexedStack` child) cannot take its overlay down with it. The layout closes that hole by probing paint itself: a render object reports "I was painted this frame", and the layout checks the flag during the next layout pass. Not painted last frame means the tab is inactive, and the overlay child collapses to nothing. The portal itself is shown once and never toggled, which sidesteps `OverlayPortalController`'s restriction against show/hide during layout. The full contract is in [`docs/UPDATING.md`](docs/UPDATING.md).

</details>

<details>
<summary><b>🧩 why the modal uses real Material routes</b></summary>

<br>

The pane layouts own their navigation feel in exchange for the state guarantee. The modal gets both: each form is Flutter's own route, so theming, drag physics, and back handling are Material's — and framework improvements arrive with Flutter upgrades. On a breakpoint crossing the active route is atomically replaced in a single frame, and since every route of a Navigator lives in one Overlay — one element tree — the keyed content reparents into the new route instead of rebuilding. A session object proxies the pop result across swaps, so the caller's awaited future never notices. The swap's flight is Material's container-transform pattern carrying the *live element*, where `Hero` and `OpenContainer` would rebuild it; the full mechanics are in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

</details>

---

## Not in the box

What the shipped package doesn't do, and where that lives instead. Full per-capability status in the [capability roadmap](docs/CAPABILITY_ROADMAP.md).

- **Router / URL integration** — deliberately. The controller is the seam; wire it to any router. The example ships complete auto_route reference wiring (`ListDetailRouter`, `MultiTypeListDetailRouter`) to copy from.
- **Selection validation** — the layout does not know whether `chat-42` still exists. When an entity is deleted, the app clears the selection (the example's `selectedIdExists` pattern shows how).
- **Navigation bars, rails, tab bars** — this package lays out panes; the shell around them is your app's.
- **Three-pane scaffolds** — compose the shipped widgets, or build the shape app-side; a dedicated widget joins only when real consumers prove the generic design.

---

## Docs

The README covers the everyday stuff. wanna go deeper?

| Doc | What's inside |
|---|---|
| [Architecture](docs/ARCHITECTURE.md) | How it's built: the two-layer split, the overlay machinery, the width model, design decisions |
| [Capabilities](docs/CAPABILITY_ROADMAP.md) | What's shipped, what's planned, what won't happen |
| [Updating](docs/UPDATING.md) | Maintenance recipes and the invariants that must not break |
| [Example app](example/) | A full app, not a snippet gallery: three domains behind an adaptive shell, nested tab routers, URL sync, every compact mode, collapsible panes with rails, adaptive modals — with `flutter test` journeys covering resize state, overlay suppression, and deep links |

---

## License

MIT. See [LICENSE](LICENSE).
