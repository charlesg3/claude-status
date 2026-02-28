#!/usr/bin/env bash
# run-tests.sh — run the full claude-watcher test suite
#
# Usage:
#   bash scripts/run-tests.sh              # run all tests
#   bash scripts/run-tests.sh --no-vim    # all tests except headless nvim (used by git hook)
#   bash scripts/run-tests.sh --statusline # status bar tests only
#   bash scripts/run-tests.sh --vim        # headless nvim tests only
#   bash scripts/run-tests.sh --mock       # mock event smoke tests only
#   bash scripts/run-tests.sh --syntax     # bash/json syntax check only
#
# The git pre-commit hook runs: bash scripts/run-tests.sh --no-vim
# CI runs the full suite without any flags.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_pass()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
_fail()   { printf '  \033[31m✗\033[0m %s\n' "$*"; }
_warn()   { printf '  \033[33m!\033[0m %s\n' "$*"; }
_header() { printf '\n\033[1m%s\033[0m\n' "$*"; }
_skip()   { printf '  \033[2m-\033[0m %s \033[2m(skipped)\033[0m\n' "$*"; }

PASS=0
FAIL=0
SKIP=0

_record_pass() { PASS=$(( PASS + 1 )); _pass "$*"; }
_record_fail() { FAIL=$(( FAIL + 1 )); _fail "$*"; }
_record_skip() { SKIP=$(( SKIP + 1 )); _skip "$*"; }

# ---------------------------------------------------------------------------
# syntax — bash -n and jq . on all scripts in repo
# ---------------------------------------------------------------------------
run_syntax() {
  _header "Syntax checks"

  local failed=0

  while IFS= read -r -d '' f; do
    if bash -n "$f" 2>/dev/null; then
      _record_pass "bash -n ${f#"$PROJECT_ROOT/"}"
    else
      _record_fail "bash -n ${f#"$PROJECT_ROOT/"}"
      bash -n "$f" 2>&1 | sed 's/^/      /'
      failed=1
    fi
  done < <(find "$PROJECT_ROOT" \
    -not -path '*/.git/*' \
    \( -name '*.sh' -o -path '*/hooks/*' \) \
    -type f -print0)

  if command -v jq &>/dev/null; then
    while IFS= read -r -d '' f; do
      if jq . "$f" &>/dev/null; then
        _record_pass "jq   ${f#"$PROJECT_ROOT/"}"
      else
        _record_fail "jq   ${f#"$PROJECT_ROOT/"}"
        jq . "$f" 2>&1 | sed 's/^/      /'
        failed=1
      fi
    done < <(find "$PROJECT_ROOT" \
      -not -path '*/.git/*' \
      -name '*.json' -type f -print0)
  else
    _record_skip "JSON syntax (jq not installed)"
  fi

  return $failed
}

# ---------------------------------------------------------------------------
# statusline — unit tests for scripts/statusline.sh
# ---------------------------------------------------------------------------
run_statusline() {
  _header "Status bar tests"
  local script="$PROJECT_ROOT/tests/test-statusline.sh"

  if [[ ! -f "$script" ]]; then
    _record_skip "tests/test-statusline.sh not found"
    return 0
  fi

  if bash "$script"; then
    _record_pass "test-statusline.sh"
  else
    _record_fail "test-statusline.sh"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# mock — smoke-test each known mock event through the hook dispatcher
# ---------------------------------------------------------------------------
run_mock() {
  _header "Mock event smoke tests"
  local mock_script="$PROJECT_ROOT/tests/mock-event.sh"
  local hook="$PROJECT_ROOT/hooks/claude-hook.sh"

  if [[ ! -f "$mock_script" ]]; then
    _record_skip "tests/mock-event.sh not found"
    return 0
  fi

  if [[ ! -f "$hook" ]]; then
    _record_skip "hooks/claude-hook.sh not found"
    return 0
  fi

  local events
  mapfile -t events < <(bash "$mock_script" --list 2>/dev/null || true)

  if [[ ${#events[@]} -eq 0 ]]; then
    _record_skip "no mock events defined"
    return 0
  fi

  local failed=0
  for event in "${events[@]}"; do
    if bash "$mock_script" "$event" 2>/dev/null; then
      _record_pass "mock: $event"
    else
      _record_fail "mock: $event"
      failed=1
    fi
  done

  return $failed
}

# ---------------------------------------------------------------------------
# vim — headless nvim plugin tests
# ---------------------------------------------------------------------------
run_vim() {
  _header "Neovim plugin tests"
  local script="$PROJECT_ROOT/tests/test-vim.lua"

  if [[ ! -f "$script" ]]; then
    _record_skip "tests/test-vim.lua not found"
    return 0
  fi

  if ! command -v nvim &>/dev/null; then
    _record_skip "nvim not installed"
    return 0
  fi

  if nvim --headless -l "$script" 2>/dev/null; then
    _record_pass "test-vim.lua"
  else
    _record_fail "test-vim.lua"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# summary
# ---------------------------------------------------------------------------
print_summary() {
  printf '\n'
  printf '─%.0s' {1..50}
  printf '\n'
  printf "  Passed: \033[32m%d\033[0m  Failed: \033[31m%d\033[0m  Skipped: \033[2m%d\033[0m\n" \
    "$PASS" "$FAIL" "$SKIP"
  printf '─%.0s' {1..50}
  printf '\n\n'
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  local run_all=true
  local do_syntax=false
  local do_statusline=false
  local do_vim=true      # included in "all" by default
  local do_mock=false
  local only_one=false   # set when user picks a specific suite

  for arg in "$@"; do
    case "$arg" in
      --syntax)     run_all=false; only_one=true; do_syntax=true ;;
      --statusline) run_all=false; only_one=true; do_statusline=true ;;
      --vim)        run_all=false; only_one=true; do_vim=true ;;
      --mock)       run_all=false; only_one=true; do_mock=true ;;
      --no-vim)     do_vim=false ;;   # run all suites except the slow nvim test
      -h|--help)
        printf 'Usage: %s [--syntax] [--statusline] [--vim] [--mock] [--no-vim]\n' \
          "$(basename "$0")"
        exit 0
        ;;
      *)
        printf 'Unknown option: %s\n' "$arg" >&2
        exit 1
        ;;
    esac
  done

  local exit_code=0

  if $run_all || $do_syntax;     then run_syntax     || exit_code=1; fi
  if $run_all || $do_statusline; then run_statusline  || exit_code=1; fi
  if $run_all || $do_mock;       then run_mock        || exit_code=1; fi
  if { $run_all || $do_vim; } && $do_vim; then run_vim || exit_code=1; fi

  print_summary

  if [[ $exit_code -ne 0 ]]; then
    printf '\033[31mTests failed.\033[0m\n\n'
  else
    printf '\033[32mAll tests passed.\033[0m\n\n'
  fi

  return $exit_code
}

main "$@"
