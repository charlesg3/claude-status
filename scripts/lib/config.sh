#!/usr/bin/env bash
# scripts/lib/config.sh — config loading and merging for claude-status
#
# SOURCE this file; do not execute it directly.
#
# Merges two JSON files (highest precedence last):
#   1. <repo>/config.json           — shipped defaults
#   2. ~/.config/claude-status/config.json  — user overrides
#
# The merge uses jq's * operator (recursive object merge); user values win at
# every key. Arrays and scalars are replaced wholesale.
#
# Functions:
#   get_config KEY [DEFAULT]   — print value for a dotted jq path, or DEFAULT
#   get_threshold CHANNEL      — resolve effective long_running threshold for a
#                                channel (channel override or global default)
#
# Environment:
#   CONFIG_OVERRIDE   — path to an alternate user config (used by tests)

# ---------------------------------------------------------------------------
# Locate repo root from this file's own path
# ---------------------------------------------------------------------------
_CONFIG_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CONFIG_REPO_DIR="$(cd "$_CONFIG_LIB_DIR/../.." && pwd)"
_CONFIG_REPO_FILE="$_CONFIG_REPO_DIR/config.json"

# ---------------------------------------------------------------------------
# _build_config — merge repo + user config; print merged JSON to stdout.
# Called once and cached in _CLAUDE_MERGED_CONFIG.
# ---------------------------------------------------------------------------
_CLAUDE_MERGED_CONFIG=""

_build_config() {
  if [[ -n "$_CLAUDE_MERGED_CONFIG" ]]; then
    printf '%s' "$_CLAUDE_MERGED_CONFIG"
    return
  fi

  if [[ ! -f "$_CONFIG_REPO_FILE" ]]; then
    _CLAUDE_MERGED_CONFIG="{}"
    printf '{}'
    return
  fi

  local user_config="${CONFIG_OVERRIDE:-${HOME}/.config/claude-status/config.json}"
  local merged

  if [[ -f "$user_config" ]]; then
    merged=$(jq -s '.[0] * .[1]' "$_CONFIG_REPO_FILE" "$user_config" 2>/dev/null) \
      || merged="{}"
  else
    merged=$(jq '.' "$_CONFIG_REPO_FILE" 2>/dev/null) || merged="{}"
  fi

  _CLAUDE_MERGED_CONFIG="$merged"
  printf '%s' "$merged"
}

# ---------------------------------------------------------------------------
# get_config KEY [DEFAULT]
#
# Prints the value at the given jq key path.
# If the key is absent or null, prints DEFAULT (empty string if not given).
#
# Examples:
#   get_config 'log.file'
#   get_config 'long_running.threshold_seconds' '120'
# ---------------------------------------------------------------------------
get_config() {
  local key="$1"
  local default="${2:-}"
  local val
  # Use `if null then empty else tostring end` instead of `// empty` so that
  # JSON false is returned as the string "false" rather than being swallowed.
  # jq's // operator treats both null AND false as absent, which is wrong for
  # boolean config keys like statusline.enabled.
  val=$(_build_config \
    | jq -r "if .${key} == null then empty else (.${key} | tostring) end" \
    2>/dev/null)
  [[ "$val" == "null" ]] && val=""
  if [[ -z "$val" ]]; then
    printf '%s' "$default"
  else
    printf '%s' "$val"
  fi
}

# ---------------------------------------------------------------------------
# get_threshold CHANNEL
#
# Resolves the effective long_running threshold for the named channel.
# Returns the channel-specific override if set (non-null), otherwise the
# global long_running.threshold_seconds.
#
# CHANNEL: one of  sound  os  vim
# ---------------------------------------------------------------------------
get_threshold() {
  local channel="$1"
  local channel_threshold global_threshold

  channel_threshold=$(get_config "notifications.${channel}.long_running_threshold" "")
  global_threshold=$(get_config "long_running.threshold_seconds" "120")

  if [[ -n "$channel_threshold" && "$channel_threshold" != "null" ]]; then
    printf '%s' "$channel_threshold"
  else
    printf '%s' "$global_threshold"
  fi
}
