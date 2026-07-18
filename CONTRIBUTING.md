# Contributing

Contributions are welcome.

---

## Setup

```bash
git clone https://github.com/whuppi/adaptive_layouts.git
cd adaptive_layouts
make hooks               # activates commit-msg + pre-commit (run once)
fvm install              # downloads the SDK version pinned in .fvmrc
fvm flutter pub get
fvm flutter test
```

**Requires:** [FVM](https://fvm.app) (`.fvmrc` pins the exact SDK
version).

**Without FVM:** all Makefile commands accept `DART` and `FLUTTER`
overrides:

```bash
make check DART=dart FLUTTER=flutter
```

---

## Before submitting a PR

```bash
make check
```

Runs `lint-shell` + `analyze` (package + example app, each from its
own root) + `analyze-floor` + `platforms` (the same pana pub.dev runs) +
`test` (the widget suite, host VM) + `test-example` (the example app's
journeys through the full nav topology).
Must pass. Don't suppress with `// ignore:` — fix the underlying
issue.

---

## PR workflow

All PRs target `dev`. That's the only branch contributors touch.

```
your fork / feature branch ──PR──► dev
                                    ↓ CI: make targets via the make-target action
                                    ↓ PR title: Conventional Commits (feat: / fix: / etc.)
                                    ↓ squash-merge when green
                                    ↓ Full test suite via "ready-to-test" label
                                      (suites × OS matrix)
```

CI calls Makefile targets — same commands locally and in CI.

You don't write changelog entries, bump versions, or touch `prod`.
The maintainer handles releases.

---

## Code style

- Match existing code in the repo.
- The overlay invariants are sacred (`docs/UPDATING.md` §1): the
  OverlayPortal is shown once and never hidden; the paint probe
  evaluates during layout and reports during paint; suppression needs
  a rebuild pass. No timers, no polling.
- Panes mount under stable GlobalKeys — that reparenting IS the
  state-preservation guarantee across the compact ↔ expanded morph.
- Core never imports components; divider / empty-state params are
  nullable builders.
- Pane width math lives only in `PaneWidthModel` — never inline
  resize / clamp / snap logic in a widget.

---

## Maintenance recipes

Step-by-step recipes (and the invariants that must not break) live in
[`docs/UPDATING.md`](docs/UPDATING.md).

---

## Releases

Handled by the maintainer.
