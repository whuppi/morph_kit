.PHONY: check hooks lint-shell analyze analyze-floor platforms format test test-example clean

# ═══════════════════════════════════════════════════════════════════
# SDK resolution
#
# Uses fvm by default. Contributors without fvm can override:
# make check DART=dart FLUTTER=flutter
# morph_kit is a Flutter package — the suite runs on flutter_test
# (host VM, no device, no browser). example/ is its own Flutter app
# package, resolved / analyzed from its OWN root (analyze_core gives it
# a `flutter analyze` pass; the journeys drive its real UI).
# ═══════════════════════════════════════════════════════════════════

DART    ?= fvm dart
FLUTTER ?= fvm flutter
TEST_RESULTS_DIR ?= test-results
TIMEOUT := $(if $(CI),--timeout=30x,)
VERBOSE := $(if $(CI),--verbose,)

# ═══════════════════════════════════════════════════════════════════
# § 1 — Gate
# ═══════════════════════════════════════════════════════════════════
#
# make check    Full local gate before handing work over.

check: lint-shell analyze analyze-floor platforms test test-example

# make hooks    Activate the repo's git hooks (commit-msg, pre-commit).
#               Run once after cloning — they stay dormant otherwise.
#               Idempotent. The hooks live at the repo root
#               (.githooks/), stamped from the shared whuppi set.
hooks:
	@git config core.hooksPath .githooks
	@echo "✓ git hooks active (core.hooksPath → .githooks)"

# make lint-shell  Shell portability gate: shellcheck + a bash-version scan
#                  over the repo's shell scripts. Shared gate
#                  tool/lint_shell.sh (canonical in whuppi/ci, stamped).
lint-shell:
	@bash tool/lint_shell.sh


# make platforms  Gate pub.dev platform support: pana (the exact analyzer
#                 pub.dev runs, pinned via tool/versions.env) must report all
#                 6 platforms, else a regression like an unconditional dart:io
#                 import silently drops a platform. Shared gate
#                 tool/platforms_gate.sh (canonical in whuppi/ci, stamped).
platforms:
	@DART="$(DART)" EXPECTED_PLATFORMS="android ios linux macos windows web" bash tool/platforms_gate.sh

# ═══════════════════════════════════════════════════════════════════
# § 2 — Analyze
# ═══════════════════════════════════════════════════════════════════
#
# make analyze  Resolve, format, analyze at --fatal-infos. Resolve runs
#               FIRST because `dart format` reads the resolved language
#               version — an unresolved tree formats differently.
#               Locally format fixes in place; under CI a diff fails.
#               analyze_core gives example/ its own `flutter analyze`
#               pass from its own root.

analyze:
	@echo "=== Flutter: pub get ==="
	@$(FLUTTER) pub get
	@echo "=== Dart: format ==="
	@if [ -n "$$CI" ]; then \
	  $(DART) format --set-exit-if-changed lib test; \
	else \
	  $(DART) format lib test; \
	fi
	@echo "=== analyze (shared core) ==="
	@DART="$(DART)" FLUTTER="$(FLUTTER)" ANALYZE_DIRS="lib test" bash tool/analyze_core.sh

# make analyze-floor  Resolve to the OLDEST in-range dependencies and
#                     analyze the shipped code (lib). The wide lower
#                     bounds are only honest if the code analyzes against
#                     them, not just the newest a fresh resolve picks.
#                     Tests are excluded on purpose — a consumer sees
#                     lib, never your tests. Snapshots and restores the
#                     lock so a local run leaves the tree clean.
analyze-floor:
	@$(FLUTTER) pub get >/dev/null
	@cp pubspec.lock pubspec.lock.floorbak; \
	$(FLUTTER) pub downgrade >/dev/null && $(DART) analyze --fatal-infos lib; rc=$$?; \
	mv pubspec.lock.floorbak pubspec.lock; \
	$(FLUTTER) pub get >/dev/null 2>&1 || true; \
	exit $$rc

# make format   Format in place (analyze also formats; this is the
#               standalone entry).
format:
	@$(DART) format lib test

# ═══════════════════════════════════════════════════════════════════
# § 3 — Test
# ═══════════════════════════════════════════════════════════════════
#
# make test     The full flutter_test suite (host VM) — controller, width
#               model, layouts (inline + overlay), paint probe, split,
#               components.

test:
	@echo "=== Flutter test suite (host VM) ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	@$(FLUTTER) test $(VERBOSE) $(TIMEOUT) --file-reporter json:$(TEST_RESULTS_DIR)/vm.json

# make test-example  The example app's journeys — the full dummy topology
#                    (nested tab routers, URL sync, overlay details,
#                    adaptive modals) driven end to end.
test-example:
	@echo "=== Example: journeys (host VM, the demo UI end to end) ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	cd example && $(FLUTTER) test $(VERBOSE) $(TIMEOUT) test/journeys --file-reporter json:../$(TEST_RESULTS_DIR)/example.json

# ═══════════════════════════════════════════════════════════════════
# § 4 — Clean
# ═══════════════════════════════════════════════════════════════════

clean:
	@$(FLUTTER) clean >/dev/null 2>&1 || true
	@rm -rf $(TEST_RESULTS_DIR)
	@echo "✓ clean"
