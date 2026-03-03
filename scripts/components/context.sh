#!/usr/bin/env bash
# scripts/components/context.sh — context window usage bar
#
# Shows a 10-char fill bar and percentage.
# Color transitions driven by statusline.context.warning_threshold and
# statusline.context.error_threshold in config.json.

comp_context() {
  local pct
  pct="$(read_state_field context_pct)"
  [[ -n "$pct" ]] || return 0

  local warn_threshold error_threshold
  warn_threshold="$(get_config 'statusline.context.warning_threshold' '65')"
  error_threshold="$(get_config 'statusline.context.error_threshold' '75')"

  local color="ready"
  [[ "$pct" -ge "$warn_threshold"  ]] && color="warning"
  [[ "$pct" -ge "$error_threshold" ]] && color="error"

  local filled=$(( pct / 10 )) empty i bar="" void=""
  empty=$(( 10 - filled ))
  for (( i=0; i<filled; i++ )); do bar+='█'; done
  for (( i=0; i<empty;  i++ )); do void+='░'; done

  printf '[[%s]]%s[[/]][[dim]]%s[[/]] %s%%' "$color" "$bar" "$void" "$pct"
}

source "$(dirname "${BASH_SOURCE[0]}")/../lib/component-standalone.sh"
