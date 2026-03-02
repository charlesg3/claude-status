#!/usr/bin/env bash
# scripts/lib/notify.sh — OS desktop notification helpers
#
# SOURCE this file; do not execute it directly.
# Requires config.sh to be sourced first.
#
# Functions:
#   kitty_tab_active           — returns 0 if running in Kitty with the active tab
#   notify_os TITLE MESSAGE    — send a native desktop notification

# ---------------------------------------------------------------------------
# kitty_tab_active
# Returns 0 (true) if the current process is running inside Kitty terminal
# and the tab containing this window is currently the active (visible) tab.
# Requires allow_remote_control yes in kitty.conf (sets $KITTY_LISTEN_ON).
# Returns 1 if not in Kitty, remote control is unavailable, or tab is inactive.
# ---------------------------------------------------------------------------
kitty_tab_active() {
  [[ -n "${KITTY_WINDOW_ID:-}" ]] || return 1
  [[ -n "${KITTY_LISTEN_ON:-}" ]] || return 1

  kitty @ --to "$KITTY_LISTEN_ON" ls 2>/dev/null \
    | jq --argjson id "$KITTY_WINDOW_ID" '
        [.[].tabs[] | select(any(.windows[]; .id == $id)) | .is_active] | any
      ' 2>/dev/null \
    | grep -q true
}

# ---------------------------------------------------------------------------
# notify_os TITLE MESSAGE
# Sends a desktop notification using the best available tool.
# Silently skips if no notification tool is installed, or if the current
# Kitty tab is active (user is already watching the terminal).
# ---------------------------------------------------------------------------
notify_os() {
  local title="$1"
  local message="$2"

  kitty_tab_active && return 0

  if [[ "$(uname)" == "Darwin" ]]; then
    if command -v osascript &>/dev/null; then
      osascript -e \
        "display notification \"${message//\"/\\\"}\" with title \"${title//\"/\\\"}\"" \
        &>/dev/null || true
    fi
  else
    if command -v notify-send &>/dev/null; then
      notify-send "$title" "$message" &>/dev/null || true
    fi
  fi
}
