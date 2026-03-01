#!/usr/bin/env bash
# scripts/lib/notify.sh — OS desktop notification helpers
#
# SOURCE this file; do not execute it directly.
# Requires config.sh to be sourced first.
#
# Functions:
#   notify_os TITLE MESSAGE    — send a native desktop notification

# ---------------------------------------------------------------------------
# notify_os TITLE MESSAGE
# Sends a desktop notification using the best available tool.
# Silently skips if no notification tool is installed.
# ---------------------------------------------------------------------------
notify_os() {
  local title="$1"
  local message="$2"

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
