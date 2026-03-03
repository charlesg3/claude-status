#!/usr/bin/env bash
# scripts/components/state.sh — Claude session state component

comp_state() {
  local state
  state="$(read_state_field state)"
  case "$state" in
    working) printf '[[working]]%s working[[/]]' "$(get_icon 'working')" ;;
    ready)
      local duration
      duration="$(read_state_field duration_seconds)"
      if [[ -n "$duration" && "$duration" -gt 0 ]]; then
        printf '[[ready]]%s ready[[/]] [[dim]](%ss)[[/]]' "$(get_icon 'ready')" "$duration"
      else
        printf '[[ready]]%s ready[[/]]' "$(get_icon 'ready')"
      fi
      ;;
    waiting) printf '[[ready]]%s waiting[[/]]'   "$(get_icon 'ready')"   ;;
    *)       printf '[[dim]]%s[[/]]' "${state:-?}" ;;
  esac
}

source "$(dirname "${BASH_SOURCE[0]}")/../lib/component-standalone.sh"
