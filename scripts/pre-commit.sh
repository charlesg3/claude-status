#!/usr/bin/env bash
# pre-commit.sh — staged-file checks for claude-status commits
#
# CLAUDE_STATUS_COMPONENT="pre-commit"
#
# Functions (also sourced by run-tests.sh):
#   check_bash_syntax   bash -n on every staged .sh file
#   check_json_syntax   jq . on every staged .json file
#   check_changelog     warn if CHANGELOG.md [Unreleased] has no content
#
# Run standalone:  bash scripts/pre-commit.sh
# Sourced by:      scripts/run-tests.sh

CLAUDE_STATUS_COMPONENT="pre-commit"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/common.sh
source "$PROJECT_ROOT/scripts/common.sh"

# Returns staged files matching an extended-regex pattern
_staged() {
  git -C "$PROJECT_ROOT" diff --cached --name-only --diff-filter=ACMR \
    | grep -E "$1" || true
}

# ---------------------------------------------------------------------------
# check_bash_syntax
#   bash -n on every staged shell script. Exits non-zero on any syntax error.
# ---------------------------------------------------------------------------
check_bash_syntax() {
  header "Bash syntax (staged files)"
  local failed=0
  local files=()

  mapfile -t files < <(_staged '\.sh$')
  mapfile -t -O "${#files[@]}" files < <(_staged '^hooks/')
  mapfile -t files < <(printf '%s\n' "${files[@]}" | sort -u)

  if [[ ${#files[@]} -eq 0 ]]; then
    ok "no shell scripts staged"
    return 0
  fi

  for f in "${files[@]}"; do
    local path="$PROJECT_ROOT/$f"
    [[ -f "$path" ]] || continue
    if bash -n "$path" 2>/dev/null; then
      ok "bash -n $f"
    else
      err "bash -n $f"
      bash -n "$path" 2>&1 | sed 's/^/      /'
      failed=1
    fi
  done

  return $failed
}

# ---------------------------------------------------------------------------
# check_json_syntax
#   jq . on every staged .json file. Exits non-zero on invalid JSON.
# ---------------------------------------------------------------------------
check_json_syntax() {
  header "JSON syntax (staged files)"
  local failed=0
  local files=()
  mapfile -t files < <(_staged '\.json$')

  if [[ ${#files[@]} -eq 0 ]]; then
    ok "no JSON files staged"
    return 0
  fi

  if ! command -v jq &>/dev/null; then
    warn "jq not found — skipping JSON syntax check"
    return 0
  fi

  for f in "${files[@]}"; do
    local path="$PROJECT_ROOT/$f"
    [[ -f "$path" ]] || continue
    if jq . "$path" &>/dev/null; then
      ok "jq $f"
    else
      err "jq $f"
      jq . "$path" 2>&1 | sed 's/^/      /'
      failed=1
    fi
  done

  return $failed
}

# ---------------------------------------------------------------------------
# check_changelog
#   Non-blocking warning when CHANGELOG.md [Unreleased] appears empty.
# ---------------------------------------------------------------------------
check_changelog() {
  header "Changelog"
  local cl="$PROJECT_ROOT/CHANGELOG.md"

  if [[ ! -f "$cl" ]]; then
    warn "CHANGELOG.md not found"
    return 0
  fi

  local unreleased_body
  unreleased_body=$(awk \
    '/^## \[Unreleased\]/{found=1; next} found && /^## /{exit} found{print}' \
    "$cl" | grep -v '^\s*$' || true)

  if [[ -z "$unreleased_body" ]]; then
    warn "CHANGELOG.md [Unreleased] section is empty — run /changelog before committing"
    return 0
  fi

  ok "CHANGELOG.md [Unreleased] has content"
  return 0
}

# ---------------------------------------------------------------------------
# main — only runs when executed directly, not when sourced by run-tests.sh
# ---------------------------------------------------------------------------
_pre_commit_main() {
  local exit_code=0

  check_bash_syntax  || exit_code=1
  check_json_syntax  || exit_code=1
  check_changelog    # non-blocking

  if [[ $exit_code -ne 0 ]]; then
    fail_banner "Pre-commit checks failed — commit aborted."
  else
    pass_banner "All pre-commit checks passed."
  fi

  return $exit_code
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _pre_commit_main "$@"
fi
