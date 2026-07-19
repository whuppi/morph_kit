# Changelog

<!--
═══════════════════════════════════════════════════════════════════════
CHANGELOG STANDARD — read before editing. Applies to both changelogs.
═══════════════════════════════════════════════════════════════════════
Two INDEPENDENT lane changelogs — do NOT mirror one from the other:
  • CHANGELOG.pre.md — the prerelease lane (`## X.Y.Z-dev.N`). Add an
    entry per prerelease you cut on dev.
  • CHANGELOG.md — the stable lane (`## X.Y.Z`). Add an entry per stable
    release, CONSOLIDATING the prerelease entries that ship under it.
They share prose but track their OWN version sequences. There is no
`cp + sed` regen: that mirror falsely assumed every prerelease becomes a
same-numbered stable, so it manufactured stable headings for versions
that never shipped — which the release tooling's `--check-versions` flags.
Hand-edit each lane's file directly.

ADDING A VERSION
  Add a heading at the TOP (newest first) of the right lane's file and
  write the summary. Exactly ONE new (untagged) version may sit at the
  top of each file — every heading BELOW it must already have its git tag
  (or a verified `release: no-tag` HTML-comment directive). `--check-versions`
  enforces this at PR + release time: a second un-released version is
  rejected, since it would collapse into the one release the merge cuts.
  Versions, commit lists, tags, publishing — the release tooling owns all
  of it; you only write the human summary.

ENTRY SHAPE
  ## X.Y.Z-dev.0
  <one-line prose lead — only to frame a big release or signal "no
   behavior change"; omit when the bullets speak for themselves>
  - **Breaking:** <what changed> → <migration step, INLINE>   ← always first
  - <upgrade action>                                          ← any required action next
  - Added/Changed <capability or improvement>                ← then improvements
  - Fixed <bug> ([#N](issue-url) reported by [@user](abs-url), [PR #N](abs-url))  ← fixes last

  Order IS the grouping — Breaking → action → added/changed → fixed. No
  `###` subsections: bullet order carries the categories. Only Breaking
  is bold-tagged; everything else is verb-led. Fixes start with "Fixed".

  EXCEPTION — the genesis entry (a ground-up build, no prior published
  version) uses facet tags instead of deltas: **API:** / **Platforms:** /
  etc., describing the new package's dimensions. See the 1.0.0-dev.0 entry.

CONTENT RULES (never change)
  • Migrate from the entry ALONE — breaking changes inline, old → new.
    (pub.dev freezes each version's CHANGELOG as a snapshot, so an entry
    can't rely on anything that later moves.)
  • NEVER link a living doc (README, docs/*) from an entry — it rots when
    the doc moves on.
  • Links point only at IMMUTABLE targets — a PR, commit, or issue:
    ([#N](https://github.com/whuppi/morph_kit/issues/N) reported by
    [@user](https://github.com/user), [PR #N](https://github.com/whuppi/morph_kit/pull/N)).
    Credit the issue + reporter when a reported issue drove the fix; the PR
    (or commit) link alone otherwise.
  • No capability inventories — "what's shipped" lives in README +
    docs/CAPABILITY_ROADMAP.md; the changelog says only what CHANGED.
═══════════════════════════════════════════════════════════════════════
-->

<!-- Add new versions below, newest first. -->

## 0.1.1

- Shortened the pubspec description to pub.dev's 60-180 character guidance (the 0.1.0 description was flagged by package analysis and cost pub points).

## 0.1.0

First release — adaptive layout widgets that morph between phone and desktop forms.

- **Widgets:** `ListDetailLayout` (list + selected detail) and `SplitLayout` (two always-present panes) switch between slide-over (compact) and side-by-side (expanded) at a configurable breakpoint.
- **State preservation:** pane widget instances survive the compact ↔ expanded morph — drafts, scroll positions, and in-flight animations carry across a window resize.
- **Adaptive modal:** `showAdaptiveModal` presents a real Material dialog on expanded widths and a real Material bottom sheet on compact — and swaps between the two real routes on resize with a container transform that carries the live content, preserving state and the awaited result.
- **Overlay mode:** the compact detail can render in the Navigator's overlay, covering bottom navs and tab bars; inactive kept-alive tabs suppress their overlays automatically.
- **Route mode:** `CompactDetailMode.route` hosts the compact detail in a real page route — the app's `PageTransitionsTheme` (platform transitions, predictive back, edge swipes) applies natively, and the detail element still reparents into the side-by-side pane on resize.
- **Accessibility:** in inline and overlay modes the open detail scopes as a route for screen readers, covered content leaves the semantics tree, and `DismissIntent` (Escape) dismisses when focus is inside the detail — route parity without a route.
- **Crossing motion:** breakpoint crossings animate in both directions — including the empty placeholder pane, which reveals and retreats at the end edge. With an open detail — into compact the detail grows out of its pane (inline/overlay) or plays the route's real entrance (route mode); into expanded the list slides in beside the full-width detail, laid out at its final width so content never reflows (`ExpandedEntryStyle.resize` opts into live reflow). Pane geometry keeps tracking window drags without motion.
- **Empty-pane behaviors:** `ExpandedEmptyBehavior.listOnly` gives the list the full expanded width until a selection reveals the detail pane from the end edge (the Material "supporting pane" shape); the default keeps the persistent placeholder pane. The auto-select-first school is documented as an app-side controller recipe.
- **Divider memory:** a dragged divider position survives compact spells and rebuilds — `PaneConfig` and `PaneAnchor` compare by value, so configs constructed inline in `build` never reset the width model. `PaneWidthMemory.resetOnReentry` opts into a fresh divider on every return to expanded.
- **Native passthroughs:** `ModalConfig` forwards Flutter's route parameters under Flutter's own names (barrier label, sheet constraints, max-height ratio, anchor points, focus/traversal behavior, entrance `AnimationStyle`s); visual styling stays on `DialogThemeData`/`BottomSheetThemeData`. Pane snap-settle duration/curve and the divider hit-zone width are `PaneConfig` knobs.
- **Divider:** draggable with min/max clamps, optional anchor snap points with a settle animation, and ratio or fixed-pixel resize modes; `HandleDivider` and `MaterialDivider` ship as ready-made visuals. The full interaction contract rides on `DividerState` (dragging / settling / at-limit / collapsed / focused).
- **Snap-collapse:** force the divider past a pane's minimum and it snaps shut (VS Code mechanics: half-minimum threshold, remembered width, spring-back short of it). `PaneCollapsible` opts in per side; `collapsedSize` keeps an icon rail or hides fully; collapsed content stays laid out at its minimum inside a clip. `HandleDivider` parks as a pull tab. Directional API holds for `SplitLayout`'s end-positioned primary.
- **Divider keyboard + screen readers:** the WAI-ARIA window-splitter pattern — Tab focus, arrows resize, Enter collapses/restores, Home/End jump to the limits, double-click resets to the default width; screen readers see an adjustable element announcing the pane's share.
- **Icon-rail slots:** `collapsedListBuilder` / `collapsedDetailBuilder` (and `SplitLayout`'s primary/secondary equivalents) give a collapsed pane purpose-built content laid out at the real `collapsedSize` — the VS Code activity-bar shape — while the pane parks offstage with its state alive. Both panes reparent via GlobalKey, so collapse, restore, and mode switches move the live element instead of rebuilding it.
- **PaneScope:** descendants of either pane read the collapse state (including `collapsedSize`, so a pane can tell a fully-hidden neighbor from a visible rail) and call `collapse`/`restore` — the hamburger-in-the-surviving-pane recipe, without threading callbacks.
- **Controller:** `ListDetailController` with an animation-aware `isDetailVisible` for app-shell timing; router-agnostic — the example ships full URL-sync reference wiring.
- **Platforms:** pure Flutter, no platform code — every platform.
