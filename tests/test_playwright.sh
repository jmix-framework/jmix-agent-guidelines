#!/usr/bin/env bash
# Functional test for `install.sh playwright`.
#
# Runs the real Playwright step (npx @playwright/cli install --skills) into an
# isolated temp HOME, then asserts the skills store is populated and linked into
# the Claude CLI agent dir. Requires npx (Node.js) on PATH and network access to npm.
#
# Usage: tests/test_playwright.sh [SOURCE_DIR]
#   SOURCE_DIR defaults to the repository root (parent of this script's dir).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
SOURCE="${1:-$(cd "${SCRIPT_DIR}/.." && pwd -P)}"
INSTALL="${SOURCE}/install.sh"

[ -f "$INSTALL" ] || { echo "FAIL: install.sh not found at ${INSTALL}"; exit 1; }
command -v npx >/dev/null 2>&1 || { echo "FAIL: npx (Node.js) is required for this test"; exit 1; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t jmix-pwtest)"
trap 'rm -rf "$WORK"' EXIT
export HOME="${WORK}/home"
mkdir -p "$HOME"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "ok: $*"; }

bash "$INSTALL" playwright --agents claude,codex,opencode,junie >/dev/null

STORE="${HOME}/.agents/.playwright/skills"
[ -d "$STORE" ] || fail "playwright store missing at ${STORE}"
first="$(find "$STORE" -maxdepth 1 -mindepth 1 -type d | head -n1)"
[ -n "$first" ] || fail "playwright store is empty"
pass "playwright skills store populated"

# A produced skill folder must be linked into ~/.claude/skills and resolve.
name="$(basename "$first")"
[ -e "${HOME}/.claude/skills/${name}" ] || fail "claude symlink ${name} does not resolve"
pass "playwright skills linked into ~/.claude/skills"

echo ""
echo "PLAYWRIGHT INSTALLER TEST PASSED"
