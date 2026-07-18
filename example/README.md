# adaptive_layouts example

A full app in one file (`lib/main.dart`) — not a toy. It is a small
project-tracker app that runs the package inside the hardest topology it has
to survive in production: an auto_route app with a persistent status strip
above the router, domain tabs (bottom nav ↔ rail), nested secondary tab
routers, URL-synced list-detail panes in overlay mode inside every tab, and
adaptive modals.

## Run

```sh
flutter run -d chrome    # URL bar shows the deep-link sync live
flutter run -d macos
```

If `main.gr.dart` is stale after editing routes:

```sh
dart run build_runner build --delete-conflicting-outputs
```

## Test

```sh
flutter test             # end-to-end journeys through the whole topology
```

## Things to try

- **Resize across 720px** with a ticket open and a comment draft typed — the
  shell morphs (bottom nav ↔ rail, slide-over ↔ side-by-side) and the draft
  survives, because the detail subtree is reparented, not rebuilt.
- **Phone width:** open a ticket — the detail covers the tab bar and bottom
  nav. Swipe right to dismiss, or use back.
- **Deep links (web):** paste `/work/tickets/ticket-hooks/options`,
  `/work/tickets/new`, `/admin/integrations/token/token-ci`,
  `/ops/setup/runner/concurrency` into the URL bar.
- **Modals:** open "New ticket" and resize while it's open — dialog ↔ bottom
  sheet, state preserved.
- **Delete the open entity** (detail pane's delete button, or delete a ticket
  from its options modal) — the pane auto-dismisses via `selectedIdExists`.
- **Overlay suppression:** on phone width, open a ticket, then navigate by
  URL to `/ops/monitor` — the work domain stays mounted but its overlay must
  disappear.
- **Status strip:** deploy a build (Ops → Monitor, or a build's rocket
  button) — the strip at the top stays put across every route swap and
  overlay.
