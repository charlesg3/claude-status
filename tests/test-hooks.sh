#!/usr/bin/env bash
# tests/test-hooks.sh — test hook dispatcher state transitions
#
# Fires JSON payloads into hooks/claude-hook.sh and asserts that the
# resulting state file contains the expected field values.
#
# Usage:
#   bash tests/test-hooks.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$REPO_DIR/hooks/claude-hook.sh"

source "$REPO_DIR/scripts/common.sh"

pass=0; fail=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# assert NAME EXPECTED ACTUAL
assert() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    ok "$name"
    pass=$(( pass + 1 ))
  else
    err "$name (expected '$expected', got '$actual')"
    fail=$(( fail + 1 ))
  fi
}

# assert_nonempty NAME ACTUAL
assert_nonempty() {
  local name="$1" actual="$2"
  if [[ -n "$actual" ]]; then
    ok "$name"
    pass=$(( pass + 1 ))
  else
    err "$name (expected non-empty, got '')"
    fail=$(( fail + 1 ))
  fi
}

# assert_file NAME PATH
assert_file() {
  local name="$1" path="$2"
  if [[ -f "$path" ]]; then
    ok "$name"
    pass=$(( pass + 1 ))
  else
    err "$name (file not found: $path)"
    fail=$(( fail + 1 ))
  fi
}

# fire JSON — pipe a hook payload into the dispatcher (NVIM unset so
# notify_vim is a no-op; MOCK_NOW fixes date +%s for determinism)
fire() {
  printf '%s' "$1" \
    | env NVIM="" MOCK_NOW=1772340000 bash "$HOOK" 2>/dev/null
}

# field STATE_FILE KEY — read a field from the state file
field() {
  jq -r ".${2} // empty" "$1" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Setup: unique session so parallel runs don't collide
# ---------------------------------------------------------------------------
SID="test-hooks-$$"
STATE_FILE="/tmp/claude-status-${SID}.json"

cleanup() { rm -f "$STATE_FILE"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# SessionStart
# ---------------------------------------------------------------------------
header "SessionStart"

fire "{
  \"hook_event_name\": \"SessionStart\",
  \"session_id\": \"$SID\",
  \"cwd\": \"/tmp\",
  \"source\": \"normal\",
  \"model\": \"claude-test\"
}"

assert_file "creates state file"       "$STATE_FILE"
assert     "state = ready"             "ready"  "$(field "$STATE_FILE" state)"
assert     "directory set"             "/tmp"   "$(field "$STATE_FILE" directory)"
assert     "model set"                 "claude-test" "$(field "$STATE_FILE" model)"
assert_nonempty "session_id present"   "$(field "$STATE_FILE" session_id)"

# ---------------------------------------------------------------------------
# UserPromptSubmit
# ---------------------------------------------------------------------------
header "UserPromptSubmit"

fire "{
  \"hook_event_name\": \"UserPromptSubmit\",
  \"session_id\": \"$SID\",
  \"cwd\": \"/tmp\"
}"

assert "state = working"                "working" "$(field "$STATE_FILE" state)"
assert_nonempty "prompt_start_epoch set"          "$(field "$STATE_FILE" prompt_start_epoch)"

# ---------------------------------------------------------------------------
# Notification — permission_prompt
# ---------------------------------------------------------------------------
header "Notification (permission_prompt)"

fire "{
  \"hook_event_name\": \"Notification\",
  \"session_id\": \"$SID\",
  \"notification_type\": \"permission_prompt\",
  \"title\": \"Claude\",
  \"message\": \"Allow file write?\"
}"

assert "state = waiting" "waiting" "$(field "$STATE_FILE" state)"

# ---------------------------------------------------------------------------
# PreToolUse — should flip back to working after permission approval
# ---------------------------------------------------------------------------
header "PreToolUse"

fire "{
  \"hook_event_name\": \"PreToolUse\",
  \"session_id\": \"$SID\",
  \"cwd\": \"/tmp\"
}"

assert "state = working" "working" "$(field "$STATE_FILE" state)"

# ---------------------------------------------------------------------------
# Stop
# ---------------------------------------------------------------------------
header "Stop"

fire "{
  \"hook_event_name\": \"Stop\",
  \"session_id\": \"$SID\",
  \"cwd\": \"/tmp\"
}"

assert "state = ready"         "ready" "$(field "$STATE_FILE" state)"
assert_nonempty "duration_seconds set"  "$(field "$STATE_FILE" duration_seconds)"

# ---------------------------------------------------------------------------
# SessionEnd
# ---------------------------------------------------------------------------
header "SessionEnd"

fire "{
  \"hook_event_name\": \"SessionEnd\",
  \"session_id\": \"$SID\",
  \"cwd\": \"/tmp\"
}"

assert_file "state file still present after SessionEnd" "$STATE_FILE"
assert "state = exited" "exited" "$(field "$STATE_FILE" state)"

# ---------------------------------------------------------------------------
# compact SessionStart preserves working state
# ---------------------------------------------------------------------------
header "SessionStart (compact)"

# Seed a working state
fire "{
  \"hook_event_name\": \"UserPromptSubmit\",
  \"session_id\": \"$SID\",
  \"cwd\": \"/tmp\"
}"

fire "{
  \"hook_event_name\": \"SessionStart\",
  \"session_id\": \"$SID\",
  \"cwd\": \"/tmp\",
  \"source\": \"compact\",
  \"model\": \"claude-test\"
}"

assert "compact SessionStart preserves state = working" \
  "working" "$(field "$STATE_FILE" state)"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [[ $fail -eq 0 ]]; then
  pass_banner "All tests passed  ($pass passed)"
else
  fail_banner "$fail failed  ($pass passed)"
fi

[[ $fail -eq 0 ]]
