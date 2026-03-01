#!/usr/bin/env bash
# scripts/lib/state.sh — atomic state file helpers for claude-status
#
# SOURCE this file; do not execute it directly.
# Requires config.sh to be sourced first (for get_config).
#
# State files live at $state_dir/claude-status-$session_id.json
# Writes are atomic: JSON is written to a .tmp file, then mv'd in place.
#
# Functions:
#   state_file_path SESSION_ID      — print the state file path
#   read_state_field STATE_FILE KEY — print a single field value
#   write_state SESSION_ID JSON     — atomically write full state JSON
#   patch_state SESSION_ID KEY VAL  — atomic single-field update

# ---------------------------------------------------------------------------
# state_file_path SESSION_ID
# ---------------------------------------------------------------------------
state_file_path() {
  local session_id="$1"
  local state_dir
  state_dir="$(get_config 'state_dir' '/tmp')"
  printf '%s/claude-status-%s.json' "$state_dir" "$session_id"
}

# ---------------------------------------------------------------------------
# read_state_field STATE_FILE KEY
# Prints the value for KEY, or empty string if absent/null.
# ---------------------------------------------------------------------------
read_state_field() {
  local state_file="$1"
  local key="$2"
  [[ -f "$state_file" ]] || return 0
  jq -r ".${key} // empty" "$state_file" 2>/dev/null
}

# ---------------------------------------------------------------------------
# write_state SESSION_ID JSON
# Atomically write a full JSON object as the session state.
# ---------------------------------------------------------------------------
write_state() {
  local session_id="$1"
  local json="$2"
  local state_file
  state_file="$(state_file_path "$session_id")"
  local tmp="${state_file}.tmp"

  printf '%s\n' "$json" | jq '.' > "$tmp" 2>/dev/null \
    && mv "$tmp" "$state_file"
}

# ---------------------------------------------------------------------------
# patch_state SESSION_ID KEY VALUE_JSON
# Atomically merge a single key into the existing state.
# VALUE_JSON must be valid JSON (strings must be quoted).
# Creates the state file if it does not exist.
# ---------------------------------------------------------------------------
patch_state() {
  local session_id="$1"
  local key="$2"
  local value_json="$3"
  local state_file
  state_file="$(state_file_path "$session_id")"
  local tmp="${state_file}.tmp"

  local existing="{}"
  [[ -f "$state_file" ]] && existing="$(cat "$state_file")"

  printf '%s\n' "$existing" \
    | jq --argjson v "$value_json" ".\"${key}\" = \$v" \
    > "$tmp" 2>/dev/null \
    && mv "$tmp" "$state_file"
}
