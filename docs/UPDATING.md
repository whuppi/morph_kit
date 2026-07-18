# adaptive_layouts — Updating

> **Type:** maintenance · **Scope:** adaptive_layouts · **Last verified:** 2026-07-18
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

- **Detail and split panes mount under stable `GlobalKey`s.** Anything that
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
7. **Content lays at the container's lerped width; placeholder width is
   per-form convention.** The content reflows WITH the morph — laying it
   at the destination width makes the narrower container visibly crop it
   mid-flight. The width circularity that reflow would otherwise cause
   (placeholder width from content width from container width) is broken
   by convention instead of measurement: the ghost sheet's placeholder is
   `width: double.infinity` (sheets are full-bleed; the slot decides),
   the dialog's placeholder takes the content's measured width (dialogs
   wrap their content). Only the HEIGHT flows from the flight's
   measurement. Content that defies its form's convention (fixed-width
   sheet content, full-bleed dialog content) lands with a width settle —
   accepted trade. Related: both resting forms pass `Clip.antiAlias` so
   corner rendering matches the flight's clipped surface; reverting to
   Material's default `Clip.none` makes content near the corners pop
   square at handoff.
8. **The destination stays a ghost until the flight becomes it.** During a
   morph the sheet is pushed chrome-less (transparent surface, no handle,
   no drag — but the REAL barrier, for scrim continuity) and the dialog
   form zeroes its chrome reactively. Landing on a ghost sheet does a
   same-frame swap to the normally-chromed route; the reveal is invisible
   because the flight's final frame is pixel-identical to the real chrome.
   Pushing a visible destination brings back the "fully-formed empty sheet
   waiting for its content" artifact.
9. **The handle band is `kMinInteractiveDimension`, imported — plus one
   structural replica.** The ghost's placeholder spacer and the flight's
   surface inset both use the SAME constant `BottomSheet` uses for its
   content padding, so the metric cannot drift; the handle's look
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

## §4 — Adding a component (divider / empty state)

1. Create the file under `src/components/{dividers|empty_states}/`.
2. Match the shared contract: dividers implement the `DividerBuilder`
   typedef via a static `builder`; empty states expose a
   `WidgetBuilder`-returning static (`IconMessageEmpty.of` shape).
3. Components may import Material and core typedefs — never core widgets'
   internals. Core must not gain an import of the new component.
4. Export from the barrel's components section.
5. Mirror a test under `test/components/...` asserting the visual states
   (idle / dragging / settling for dividers).
6. Row in `CAPABILITY_ROADMAP.md`.

## §5 — Adding a config field

1. Add the field to the right pure-data class (`PaneConfig`,
   `CompactConfig`) with a default that preserves current behavior.
2. Wire it where it acts. If it affects pane width, it goes through
   `PaneWidthModel` — never inline width math in a widget (the two widgets
   must stay identical in resize behavior).
3. If a widget must react to the field changing at runtime, handle it in
   `didUpdateWidget` (see the `paneConfig` reset there).
4. Unit-test the model change; widget-test the visible effect.
5. **No decorative fields.** A config field with no behavior behind it is a
   lie — this package once shipped `anchors` / `resizeMode` / `isSettling`
   unimplemented; they're real now. Don't regress the standard.

## §6 — Adding a layout widget

1. New folder under `src/core/<name>/` (peer of `list_detail/`, `split/`).
2. Reuse the shared vocabulary: `AdaptiveLayoutConfig.resolveBreakpoint`,
   `PaneConfig` + `PaneWidthModel` for any draggable pane, the
   `DividerBuilder` typedef, GlobalKey reparenting for anything that
   morphs.
3. Nullable builder params for anything a component could fill.
4. Barrel export, mirrored test folder, roadmap rows, architecture tree
   update.

## §7 — Changing the API surface

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
| Divider ignores drags | The 24px hit zone is positioned at `paneWidth - 12`; check the width actually read from `PaneWidthModel` |
| Snap lands at the wrong place | Anchor positions clamp by min/max — verify against `pane_width_model_test.dart` expectations |
