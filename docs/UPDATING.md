# adaptive_layouts — Updating

> **Type:** maintenance · **Scope:** adaptive_layouts · **Last verified:** 2026-07-19
> **Companion docs:** [`ARCHITECTURE.md`](ARCHITECTURE.md) · [`CAPABILITY_ROADMAP.md`](CAPABILITY_ROADMAP.md)

Maintenance recipes and the invariants that must not break. When code and
docs disagree, code wins — then fix the doc in the same commit.

---

## The check sequence

```sh
make check          # analyze + package tests + example journeys
# or piecewise:
fvm flutter analyze
fvm flutter test                       # package suite (unit + widget)
cd example && fvm flutter test         # full-app journeys
```

Green on all three before claiming any change done. The example app is the
integration harness — it reproduces the hardest consumer topology (nested
kept-alive tab routers + overlay mode + URL sync) so package changes are
validated against real conditions without touching a real app.

---

## §1 — The overlay invariants (DO NOT BREAK)

The overlay compact mode rests on three invariants. Every one was earned by
a real failure; tests pin them (`test/core/list_detail/
list_detail_overlay_test.dart`, `paint_visibility_detector_test.dart`, and
the example's overlay journeys).

1. **The `OverlayPortal` is shown once and never hidden.** The overlay child
   collapses to `SizedBox.shrink()` instead. Toggling show/hide on layout
   transitions trips `OverlayPortalController`'s assertion during the layout
   phase and reintroduces a one-frame gap.
2. **`PaintVisibilityDetector.evaluate()` runs during layout;
   `PaintVisibilityObserver` reports during paint; the re-show notifier
   update is deferred to a post-frame callback.** Layout-after-paint ordering
   is what makes the was-painted flag trustworthy; mutating a notifier during
   paint is illegal. Hide is zero-frame, re-show has a one-frame lag —
   that asymmetry is by design.
3. **Suppression needs a subsequent build pass of the inactive child.** Real
   tab switches produce one. Don't "fix" this by polling or timers; if a
   consumer hits a case with no rebuild, the answer is an explicit rebuild
   at the shell, not package-side scheduling.

Related: on expanded → compact with an open selection, the slide controller
JUMPS to 1.0 (no re-animation) — the detail was already visible.

## §2 — The morph invariants

- **The list, the detail, and both split panes mount under stable
  `GlobalKey`s.** Anything that
  changes a pane's position in the tree between compact and expanded must
  keep the same key wrapping the same builder output, or state preservation
  (the package's core guarantee) silently dies. The resize tests fail loudly
  if it does.
- **Dismiss keeps the outgoing detail in the tree** until the exit animation
  reaches `dismissed` (`_outgoingDetailId`, plus `_lastSeenSelectedId` for
  external `controller.dismiss()` calls). Removing either breaks one of the
  two dismiss paths.

---

## §3 — The modal swap invariants (DO NOT BREAK)

`showAdaptiveModal` presents real Material routes (`DialogRoute`,
`ModalBottomSheetRoute`) and replaces one with the other when the window
crosses the breakpoint. The swap machinery in
`src/core/modal/adaptive_modal.dart` holds three invariants:

1. **The swap is one synchronous block: point `_active` at the new route →
   `removeRoute(old)` → `push(new)`.** All three land in one frame — that is
   what lets the `GlobalKey`'d content reparent instead of unmount, and what
   keeps old and new content from coexisting (duplicate-key crash).
2. **The identity guard decides what a route completion means.** A removed
   route also completes its `popped` future (with null); only the completion
   of the route that is still `_active` is the user dismissing the modal.
   Reorder the swap so `_active` still points at the old route during
   `removeRoute` and the caller's future completes with null mid-swap.
3. **Swaps navigate post-frame, from live width.** The crossing is detected
   during build (navigation is illegal there); by the time the callback runs
   the width may have crossed back, so the target mode is re-derived — never
   captured at schedule time.

With the container transform (`ModalConfig.morph`, default on), three more:

4. **Exactly one holder of the content key per frame.** While a flight is
   in the air the routes build a placeholder instead of the keyed content
   (`_morphing` drives the branch). Flight start and flight end each move
   the key in one synchronous block. Two holders in one frame is a
   duplicate-key crash; zero is a silent state reset.
5. **The subtree from the keyed node down is identical in every host.**
   The flight's `Builder` (for the captured-themes context) sits ABOVE the
   `KeyedSubtree` — insert anything between the key and the user's content
   in one host but not the others and the reparent degrades into a rebuild.
6. **A dismissal mid-flight lands the content before the result completes.**
   The `popped` handler calls `_endFlight()` first, so the exiting route
   shows the content during its exit animation and the flight's ticker is
   disposed. Completing the result while a flight is airborne leaks the
   ticker and pops an empty route.
7. **Content lays TIGHT at the container's lerped width; the placeholder's
   width comes from the one-time natural-width sample.** Tight layout is
   what makes the content shrink and grow WITH the morph — loose layout
   lets self-sized content jump to its destination width at takeoff, and
   destination-width layout makes the narrower container visibly crop it.
   The width circularity that tight-following would otherwise cause
   (placeholder width from content width from container width) is broken
   by sampling: the measurer lays the child LOOSE as a pre-pass inside
   the same layout (never painted — a painted loose frame is a visible
   narrow-flash at takeoff), records the natural width and whether the
   content is full-bleed, then lays tight for real. The placeholder's
   width is that frozen sample (full-bleed → the slot decides via
   `double.infinity`; self-sized → the sampled width), delivered through
   `sampleRevision` — the size channel alone can't carry it, since the
   tight-laid size often doesn't change when the sample does. A retarget
   switches the target form, so it marks the sample stale and the next
   layout resamples — a stale sample is the sheet landing at the
   dialog's width and snapping wide. Only the HEIGHT flows from the live
   measurement. Related: both
   resting forms pass `Clip.antiAlias` so corner rendering matches the
   flight's clipped surface; reverting to Material's default `Clip.none`
   makes content near the corners pop square at handoff.
8. **The destination stays a ghost until the flight becomes it.** During a
   morph the sheet is pushed chrome-less (transparent surface, no handle,
   no drag — but the REAL barrier, for scrim continuity) and the dialog
   form zeroes its chrome reactively. Landing on a ghost sheet does a
   same-frame swap to the normally-chromed route; the reveal is invisible
   because the flight's final frame is pixel-identical to the real chrome.
   Pushing a visible destination brings back the "fully-formed empty sheet
   waiting for its content" artifact.
9. **The handle band is `kMinInteractiveDimension`, imported — plus one
   structural replica.** The ghost's placeholder inset and the flight's
   surface inset both use the SAME constant `BottomSheet` uses for its
   content padding, so the metric cannot drift — and both apply it as
   `Padding` INSIDE the bounded slot, never a spacer stacked above:
   constraint-filling content must get height − band, or the slot
   overflows by exactly the band (found live with a scrollable panel;
   the flight mirrors the math via `maxHeight − inset`). The handle's look
   (`dragHandleSize ?? theme ?? Size(32, 4)`, radius h/2, color
   `dragHandleColor ?? theme ?? onSurfaceVariant`) is replicated from the
   SDK source and pinned by the landing-parity test — if a Flutter upgrade
   moves it, that test fails loudly.
10. **The flight's Material must not out-paint the flight.** Three paint
    parities, each found as a real landing pop: the flight's `Material`
    sets `animationDuration: Duration.zero` (Material implicitly tweens
    shape/elevation over ~200ms, lagging the lerp — the widget tree
    claims the lerped shape while the pixels stay behind); its
    `shadowColor` resolves from the theme with the M3 default of
    transparent (both real forms cast no shadow — a default black shadow
    on the flight vanishes at handoff); and the ghost → real `Dialog`
    flips a `ValueKey` so its Material mounts fresh instead of implicitly
    tweening elevation after landing.

## §4 — The route-mode invariants (DO NOT BREAK)

`CompactDetailMode.route` hosts the compact detail in a real page route.
The machinery in `list_detail_layout.dart` holds:

1. **All navigation flows through `_syncDetailRoute`, post-frame.** Build
   detects, the reconciler acts. Navigating during build asserts.
2. **Exactly one holder of the detail key per frame** — the route (while
   `_detailRouted`), the expanded pane, or the one-frame bridge. The pane
   leaves its slot empty while a route holds the key; the route still
   covers the screen that frame, so the gap is invisible.
3. **Dismissal is deselection — there is NO pop handoff.** The content
   rides the popped route's real exit animation and dies with it, exactly
   like the inline outgoing pattern. This is why predictive back (and its
   cancel) needs no special handling. An exiting route keeps the key until
   its animation is dismissed; new pushes wait for it.
4. **The identity guard on `popped`.** A removed route also completes;
   only the still-active route's completion is a user dismissal.
5. **The route stays non-opaque.** The paint probe below detects "tab
   hidden under the route"; an opaque route blinds the probe AND
   un-paints the very layout that owns the route — a suppression loop.
6. **Suppression is a build-armed one-shot, and it corrects the stale
   probe.** `evaluate()` (layout) resets the paint flag; the post-frame
   check PEEKS `paintedThisFrame` only after a frame whose build armed
   it — clean idle frames (where paint legitimately skips undirtied
   layers) can never false-trigger. The check never resets the flag;
   `evaluate` owns the reset. It runs on EVERY route-mode build (not
   only routed ones): paint can stop without any build running
   `evaluate()` (keep-alive tab buckets — TabBarView), leaving the
   notifier stale-TRUE. A built-but-unpainted frame flips it false —
   which is also what re-arms `_onPaint`'s deferred "paint resumed"
   signal; a stuck-true notifier never fires it and the re-show would
   never wake.
7. **A push needs same-frame paint evidence; a suppressed detail is
   re-homed in the bridge.** The sync reads `paintedThisFrame` when the
   frame's build ran `evaluate()` (fresh both ways: pushes in the very
   flush where paint resumed, AND vetoes the stale-true notifier that
   once pushed a hidden tab's route over the visible screen), falling
   back to the notifier only for listener-woken syncs in buildless
   frames. `_scheduleRouteSync` calls `ensureVisualUpdate()` — the
   listener fires inside another frame's post-frame flush, where a
   queued callback otherwise waits for a frame an idle device never
   schedules. And whenever the route is removed while the selection is
   kept, `_bridgeDetail` is set in the same block: the bridge claims
   the detail key the frame the route dies — a keyless frame unmounts
   the element and destroys its state. (Repro for all three: open the
   detail expanded, hide the tab, resize to compact, return.)
8. **Route pushes run Hero scans over the whole shell.** Flutter scans
   the from-route subtree — including kept-alive tab children — for
   `Hero` tags on every push. Two `FloatingActionButton`s with default
   hero tags anywhere under the shell assert and wreck the transition.
   App-side rule (documented in the README): give FABs explicit
   `heroTag`s (or `null`) when several coexist under one page.
9. **Crossings animate the ARRANGEMENT, never the tracking — and the
   offstage bridge is the route's handoff.** Pane geometry follows a
   window drag with zero motion (a lagging pane fights the hand); the
   arrangement flip at the breakpoint animates on EVERY crossing, drag
   or jump alike — the Compose-canonical pane motion. Into compact:
   inline/overlay reuse the slide controller (start at the old divider
   fraction, settle to full); route mode drops `instantEntrance` and
   lets the REAL entrance play over the LIST — the bridge goes
   `Offstage` for the handoff frame: still the detail key's holder (a
   keyless frame unmounts the element) but invisible, so the entrance
   never slides over a copy of itself. Into expanded (every mode): the
   detail starts full width — for route mode this makes the instant
   route removal seamless, the pane's first frame matches the route's
   last — and `_expandEntryController` slides the list in, scaling only
   the RENDERED list width (the width model keeps real geometry; the
   rebuild rides an AnimatedBuilder, never a setState listener, which
   would fire during build when a crossing frame seeds the value).
   Hidden layouts (paint-probe false) always take the instant path — an
   entrance nobody watches is wasted, and the re-show contract expects
   instant. A first build is never a crossing (`_hasBuiltOnce`) — deep
   links render settled. The EMPTY placeholder pane crosses too: it
   reveals via `_detailPaneController` on expand, and on shrink build()
   keeps the expanded geometry alive at the compact width
   (`_emptyPaneRetreating`) until the retreat lands — the steady visuals
   on both ends are a full-width list, so the tree swap is invisible.
   During those builds `_lastExpandedWidth` must NOT update (it would
   record the compact width and corrupt the crossing math).
10. **`didUpdateWidget` mirrors initState's per-mode wiring.** Mode flips
   happen on LIVE layouts (settings screens exist). Entering route mode
   must attach the paint-probe listener — it IS the re-show chain; a
   layout flipped into route mode without it looks fine until a tab
   hide + return leaves the detail resting inline forever. Anything a
   mode's initState wires, the flip must wire; anything it wires, the
   flip away must unwind. The regression test pins this with a
   paint-only re-show (children reused across the tab switch), because
   a harness that rebuilds on tab switch masks a dead listener.

## §4b — The divider interaction invariants (DO NOT BREAK)

1. **All divider interactivity lives in `PaneDividerRegion`** — drag,
   double-click reset, keyboard shortcuts, semantics. The layouts supply
   callbacks; neither layout builds its own `GestureDetector` for the
   divider. A new interaction goes into the region once and both widgets
   get it.
2. **Collapse mechanics are model state** (`PaneWidthModel.collapsed`,
   VS Code spec: half-minimum threshold on the raw drag position,
   `_cachedWidth` restore, spring-back short of the threshold). Widgets
   never track their own collapsed flag.
3. **`PaneSide` / `PaneCollapsible` are DIRECTIONAL in every public
   surface** (config, `DividerState.collapsed`, `PaneScope`). The width
   model works in model space (start = the measured pane).
   `SplitLayout` with an end-positioned primary translates at its
   boundary: flipped `collapsible` into the model, flipped `collapsed` /
   at-limit flags / Home-End targets out of it. `ListDetailLayout`'s
   model space IS directional, no translation. Breaking this makes the
   pull tab point the wrong way and `PaneScope` lie.
4. **Collapsed pane content reflows down to its floor width, never
   below it.** The clip slot (`heldAtFloor`) lays content at
   `max(floor, slot width)` — live reflow while the slot is above the
   floor, rigid-and-clipped below it (start pane's floor is
   `minListWidth`, end pane's is `available * (1 - maxListRatio)`).
   No jump at an animation's first frame, no squish below the floor
   the app designed for.
5. **Programmatic collapse/restore snap instantly**; only the drag path
   animates. `_settleToWidth` is the single settle primitive — anchors,
   Home/End, and double-click reset all route through it.
6. **Keyboard steps are micro-drags** through `_handleDividerDragUpdate`,
   so RTL (and split's primary-position inversion) apply identically to
   pointer and keyboard. Never add a parallel resize path.
7. **Semantics carry `value` + `increasedValue` + `decreasedValue`
   together** — Flutter asserts if increase/decrease actions exist with a
   `value` but no stepped values. The share strings come from the
   layout's `_paneSharePercent`.
8. **Parked panes don't dance.** A collapsed pane's crossing arrives at
   the final arrangement directly: the rail docks at its parked width
   from frame one (fixed end slot + background spacer while the list's
   slide-in plays; divider anchored to the DOCKED boundary), and both
   the parked-list entry slide and the empty-pane reveal/retreat are
   skipped when parked. The collapse animation belongs to the moment
   the user collapsed — a window resize isn't that moment. A rail
   entrance flourish is the app's own business inside its rail builder;
   never stretch a fixed-width rail across an animating slot.
8b. **Rail slots replace the clip only when the app opts in.** A
   `collapsed*Builder` lays its content at the REAL slot width
   (`StackFit.expand` — the offstage child is zero-size and must not
   set the stack's size) while the pane parks in `Offstage` +
   `TickerMode(false)`, state alive. Both panes carry reparenting
   GlobalKeys, so the wrap/unwrap reparents instead of remounting.
9. **Never `clamp` pane bounds without the min-wins guard.** Expanded
   geometry renders at COMPACT widths during the empty-pane retreat, so
   `availableWidth * maxListRatio` can drop below `minListWidth` —
   `double.clamp` THROWS on inverted bounds. `PaneWidthModel._clamp`
   and every `_paneSharePercent` guard with "ceiling <= floor → floor";
   any new bound computation must too.
10. **The divider stays grabbable when parked.** The region's position is
   clamped fully on-screen at `collapsedSize`; a collapsed pane must
   always be recoverable by drag alone.

## §5 — Adding a component (divider / empty state)

1. Create the file under `src/components/{dividers|empty_states}/`.
2. Match the shared contract: dividers implement the `DividerBuilder`
   typedef via a static `builder`; empty states expose a
   `WidgetBuilder`-returning static (`IconMessageEmpty.of` shape).
3. Components may import Material and core typedefs — never core widgets'
   internals. Core must not gain an import of the new component.
4. Export from the barrel's components section.
5. Mirror a test under `test/components/...` asserting the visual states
   (idle / dragging / settling / focused / collapsed pull-tab for
   dividers).
6. Row in `CAPABILITY_ROADMAP.md`.

## §6 — Adding a config field

1. Add the field to the right pure-data class (`PaneConfig`,
   `CompactConfig`) with a default that preserves current behavior.
2. **Add the field to `==` and `hashCode` when the class has them**
   (`PaneConfig` does). A field missing from equality makes two different
   configs compare equal — the layout then ignores the change at runtime.
   Never compare configs by `identical`: apps construct them inline in
   `build`, and identity comparison resets user state (the dragged
   divider) on every rebuild. Watch `double.nan` sentinel fields —
   NaN == NaN is false (`PaneAnchor` carries the fix).
3. Wire it where it acts. If it affects pane width, it goes through
   `PaneWidthModel` — never inline width math in a widget (the two widgets
   must stay identical in resize behavior).
4. If a widget must react to the field changing at runtime, handle it in
   `didUpdateWidget` (see the `paneConfig` reset there).
5. Unit-test the model change; widget-test the visible effect.
6. **No decorative fields.** A config field with no behavior behind it is a
   lie — this package once shipped `anchors` / `resizeMode` / `isSettling`
   unimplemented; they're real now. Don't regress the standard.

## §7 — Adding a layout widget

1. New folder under `src/core/<name>/` (peer of `list_detail/`, `split/`).
2. Reuse the shared vocabulary: `AdaptiveLayoutConfig.resolveBreakpoint`,
   `PaneConfig` + `PaneWidthModel` for any draggable pane, the
   `DividerBuilder` typedef, GlobalKey reparenting for anything that
   morphs.
3. Nullable builder params for anything a component could fill.
4. Barrel export, mirrored test folder, roadmap rows, architecture tree
   update.

## §8 — Changing the API surface

Pre-1.0, the minor version is the breaking axis — bump it for any breaking
change and say so in the changelog. Workspace consumers use `path:`
dependencies, so breaks surface at their next analyze. After any signature
change: run the check sequence here, then
`fvm flutter analyze` in each consuming app (the workspace grep for
`adaptive_layouts` finds them). Update the example's usage in the same
session — it is the reference consumers copy from.

---

## Reading the failure modes

| Failure | First check |
|---|---|
| Overlay detail lingers over another tab | Did a rebuild pass reach the inactive child? (§1.3) Then: `evaluate()` still called from the layout builder? |
| Assertion: OverlayPortalController show/hide during layout | Someone reintroduced portal toggling — restore the always-showing shape (§1.1) |
| Duplicate GlobalKey crash on resize | A pane is built in both layouts within one frame — check the mode branches only ever mount one copy |
| Detail state resets on window resize | GlobalKey chain broken (§2) |
| Divider ignores drags | The hit zone (`dividerHitWidth`, default 24) is centered on the pane border; check the width actually read from `PaneWidthModel`, and whether a collapsed pane parked it at the window edge |
| Snap lands at the wrong place | Anchor positions clamp by min/max — verify against `pane_width_model_test.dart` expectations |
