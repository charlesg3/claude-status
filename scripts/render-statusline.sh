#!/usr/bin/env bash
# scripts/render-statusline.sh — terminal status line renderer
#
# Reads STATE_FILE and prints a single formatted, ANSI-coloured status line
# to stdout. Intended for tmux status-right or any terminal status bar.
#
# Environment:
#   STATE_FILE  — path to the session state JSON (required; must exist)
#   COLUMNS     — terminal width; falls back to stty or 80

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_ROOT/scripts/lib/config.sh"

# ---------------------------------------------------------------------------
# Terminal width
# ---------------------------------------------------------------------------
TERM_WIDTH="${COLUMNS:-$(stty size </dev/tty 2>/dev/null | awk '{print $2}')}"
TERM_WIDTH="${TERM_WIDTH:-120}"

# ---------------------------------------------------------------------------
# ANSI color helpers
# ---------------------------------------------------------------------------
_fg() {
  # _fg HEX — print truecolor ANSI escape for foreground color
  local hex="${1#\#}"
  printf '\033[38;2;%d;%d;%dm' \
    "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
}
RESET='\033[0m'
DIM='\033[2m'

# Load colors from config (fall back to sensible defaults)
C_WORKING="$(_fg "$(get_config 'statusline.colors.working'   '6FC1FF')")"
C_READY="$(_fg   "$(get_config 'statusline.colors.ready'     '55B96D')")"
C_ERROR="$(_fg   "$(get_config 'statusline.colors.error'     'FF2C6D')")"
C_WARNING="$(_fg "$(get_config 'statusline.colors.warning'   'FFB86C')")"
C_BRANCH="$(_fg  "$(get_config 'statusline.colors.branch'    'B1B9F5')")"
C_DIM="$(_fg     "$(get_config 'statusline.colors.dim'       '676B79')")"

# Load icons from config
I_WORKING="$(get_config   'statusline.icons.working'    '↻')"
I_READY="$(get_config     'statusline.icons.ready'      '●')"
I_DIRECTORY="$(get_config 'statusline.icons.directory'  '📁')"
I_BRANCH="$(get_config    'statusline.icons.branch'     '🌿')"
I_STAGED="$(get_config    'statusline.icons.staged'     '+')"
I_MODIFIED="$(get_config  'statusline.icons.modified'   '*')"
I_COST="$(get_config      'statusline.icons.cost'       '💰')"
I_DURATION="$(get_config  'statusline.icons.duration'   '⏱')"

# ---------------------------------------------------------------------------
# Read state fields
# ---------------------------------------------------------------------------
_field() { jq -r ".${1} // empty" "$STATE_FILE" 2>/dev/null; }

STATE="$(        _field state)"
DIRECTORY="$(    _field directory)"
BRANCH="$(       _field branch)"
GIT_STAGED="$(   _field git_staged)"
GIT_MOD="$(      _field git_modified)"
CONTEXT_PCT="$(  _field context_pct)"
COST_USD="$(     _field cost_usd)"
SESSION_ID="$(   _field session_id)"
SESSION_START="$(_field session_start_epoch)"
DURATION=""
[[ -n "$SESSION_START" ]] && DURATION=$(( ${MOCK_NOW:-$(date +%s)} - SESSION_START ))

# In statusLine mode, fresh stdin values passed from statusline.sh are
# authoritative (STATE_FILE may not have been patched yet between patch and read)
[[ -n "${STDIN_CONTEXT_PCT:-}" ]] && CONTEXT_PCT="$STDIN_CONTEXT_PCT"
[[ -n "${STDIN_COST_USD:-}"    ]] && COST_USD="$STDIN_COST_USD"

# ---------------------------------------------------------------------------
# Component renderers
# Each prints a styled string (with ANSI) to stdout; empty = disabled/empty.
# ---------------------------------------------------------------------------

comp_state() {
  case "$STATE" in
    working) printf '%b%s %s%b' "$C_WORKING" "$I_WORKING" "working" "$RESET" ;;
    ready)   printf '%b%s %s%b' "$C_READY"   "$I_READY"   "ready"   "$RESET" ;;
    *)       printf '%b%s%b'    "$C_DIM"     "${STATE:-?}" "$RESET" ;;
  esac
}

comp_directory() {
  [[ -n "$DIRECTORY" ]] || return 0
  local name
  name="$(basename "$DIRECTORY")"
  printf '%b%s %s%b' "$C_DIM" "$I_DIRECTORY" "$name" "$RESET"
}

comp_branch() {
  [[ -n "$BRANCH" ]] || return 0
  printf '%b%s %s%b' "$C_BRANCH" "$I_BRANCH" "$BRANCH" "$RESET"
}

comp_git_status() {
  local out=""
  [[ "${GIT_STAGED:-0}" -gt 0 ]] && out+="${I_STAGED}${GIT_STAGED}"
  [[ "${GIT_MOD:-0}"    -gt 0 ]] && out+="${out:+ }${I_MODIFIED}${GIT_MOD}"
  [[ -n "$out" ]] && printf '%b%s%b' "$C_WARNING" "$out" "$RESET"
}

comp_context() {
  [[ -n "$CONTEXT_PCT" ]] || return 0
  # Color transitions: green (< 50%) → orange (50–79%) → red (≥ 80%)
  local color="$C_READY"
  [[ "$CONTEXT_PCT" -ge 50 ]] && color="$C_WARNING"
  [[ "$CONTEXT_PCT" -ge 80 ]] && color="$C_ERROR"
  # Fill bar: 10 chars of █ (filled) and ░ (empty)
  local filled=$(( CONTEXT_PCT / 10 )) empty i bar="" void=""
  empty=$(( 10 - filled ))
  for (( i=0; i<filled; i++ )); do bar+='█'; done
  for (( i=0; i<empty;  i++ )); do void+='░'; done
  printf '%b%s%b%b%s%b %s%%%b' \
    "$color" "$bar" "$RESET" \
    "$DIM"   "$void" "$RESET" \
    "$CONTEXT_PCT" "$RESET"
}

comp_cost() {
  [[ -n "$COST_USD" ]] || return 0
  printf '%b%s$%.2f%b' "$C_WARNING" "$I_COST" "$COST_USD" "$RESET"
}

comp_duration() {
  [[ -n "$DURATION" ]] || return 0
  local d="$DURATION" formatted
  if (( d < 60 )); then
    formatted="${d}s"
  elif (( d < 3600 )); then
    formatted="$(printf '%dm %ds' $(( d / 60 )) $(( d % 60 )))"
  else
    formatted="$(printf '%dh %dm' $(( d / 3600 )) $(( (d % 3600) / 60 )))"
  fi
  printf '%b%s %s%b' "$C_DIM" "$I_DURATION" "$formatted" "$RESET"
}

comp_session_id() {
  [[ -n "$SESSION_ID" ]] || return 0
  printf '%b[%s]%b' "$C_DIM" "${SESSION_ID:0:8}" "$RESET"
}

# ---------------------------------------------------------------------------
# _visible_len STRING — length of string after stripping ANSI escape codes
# ---------------------------------------------------------------------------
_visible_len() {
  local plain
  plain="$(printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g')"
  local chars wide
  chars=$(printf '%s' "$plain" | wc -m | tr -d ' ')
  # Supplementary-plane emoji (📁 🌿 💰 etc.) have a 4-byte UTF-8 leading
  # byte in range F0–F4 and occupy 2 terminal columns, not 1 code point.
  wide=$(printf '%s' "$plain" | LC_ALL=C awk '{
    for (i = 1; i <= length($0); i++) {
      b = substr($0, i, 1)
      if (b >= "\360" && b <= "\364") w++
    }
  } END { print w+0 }')
  echo $(( chars + wide ))
}

# ---------------------------------------------------------------------------
# Assemble layout
# ---------------------------------------------------------------------------

# Build left and right segment arrays from layout, split on "spacer"
LEFT_PARTS=()
RIGHT_PARTS=()
IN_RIGHT=false

mapfile -t LAYOUT < <(get_config 'statusline.layout' '' \
  | jq -r '.[]' 2>/dev/null \
  || printf '%s\n' state directory branch git_status spacer context cost duration)

for item in "${LAYOUT[@]}"; do
  if [[ "$item" == "spacer" ]]; then
    IN_RIGHT=true
    continue
  fi
  if $IN_RIGHT; then
    RIGHT_PARTS+=("$item")
  else
    LEFT_PARTS+=("$item")
  fi
done

# Render each section
_render_section() {
  local parts=("$@")
  local out=""
  for name in "${parts[@]}"; do
    local seg
    seg=$(comp_"${name//-/_}" 2>/dev/null || true)
    [[ -n "$seg" ]] && out+="${out:+  }${seg}"
  done
  printf '%s' "$out"
}

LEFT="$(_render_section  "${LEFT_PARTS[@]+"${LEFT_PARTS[@]}"}")"
RIGHT="$(_render_section "${RIGHT_PARTS[@]+"${RIGHT_PARTS[@]}"}")"

# ---------------------------------------------------------------------------
# Print with spacer padding
# ---------------------------------------------------------------------------
if [[ -z "$RIGHT" ]]; then
  printf '%b%s%b\n' "" "$LEFT" ""
else
  LEFT_LEN="$(_visible_len "$LEFT")"
  RIGHT_LEN="$(_visible_len "$RIGHT")"
  # 2 spaces gap + 3 char right margin (Claude clips the last few chars)
  SPACER_LEN=$(( TERM_WIDTH - LEFT_LEN - RIGHT_LEN - 5 ))
  [[ $SPACER_LEN -lt 1 ]] && SPACER_LEN=1
  PADDING="$(printf '%*s' "$SPACER_LEN" '')"
  printf '%s%s%s\n' "$LEFT" "$PADDING" "$RIGHT"
fi
