#!/usr/bin/env bash
# scripts/lib/sound.sh — sound notification helpers
#
# SOURCE this file; do not execute it directly.
# Requires config.sh to be sourced first.
#
# Sound file resolution order for event EVENT:
#   1. notifications.sound.path_overrides.EVENT  (per-event override)
#   2. notifications.sound.path                  (global sound file/dir)
#   3. If path is a directory → pick a random file from it
#   4. No sound if path is unset or the file is missing
#
# Functions:
#   play_sound EVENT   — play the sound for the given event (long_running|error)

# ---------------------------------------------------------------------------
# _resolve_sound_path EVENT
# Prints the path to the sound file to play, or empty string if none.
# ---------------------------------------------------------------------------
_resolve_sound_path() {
  local event="$1"
  local path

  # Per-event override takes precedence
  path=$(get_config "notifications.sound.path_overrides.${event}")
  [[ -z "$path" ]] && path=$(get_config "notifications.sound.path")
  [[ -z "$path" ]] && return 0

  # Expand ~ manually (not expanded inside double-quoted variables)
  path="${path/#\~/$HOME}"

  if [[ -d "$path" ]]; then
    # Pick a random sound file from the directory
    local files=()
    while IFS= read -r -d '' f; do
      files+=("$f")
    done < <(find "$path" -maxdepth 1 -type f \
      \( -name '*.mp3' -o -name '*.wav' -o -name '*.aiff' -o -name '*.ogg' \) \
      -print0 2>/dev/null)

    [[ ${#files[@]} -gt 0 ]] && printf '%s' "${files[RANDOM % ${#files[@]}]}"
  elif [[ -f "$path" ]]; then
    printf '%s' "$path"
  fi
}

# ---------------------------------------------------------------------------
# play_sound EVENT
# Plays the sound for the given event. Silently skips if no tool is available
# or no sound file is configured.
# EVENT: long_running | error
# ---------------------------------------------------------------------------
play_sound() {
  local event="$1"

  [[ "$(get_config 'notifications.sound.enabled' 'true')" == "true" ]] || return 0

  local sound_file
  sound_file=$(_resolve_sound_path "$event")
  [[ -n "$sound_file" ]] || return 0

  local volume
  volume=$(get_config 'notifications.sound.volume' '0.7')

  if [[ "$(uname)" == "Darwin" ]]; then
    command -v afplay &>/dev/null \
      && afplay -v "$volume" "$sound_file" &>/dev/null &
  else
    if command -v mpg123 &>/dev/null; then
      # mpg123 -f is a scale factor: 32768 = 100%, scale linearly
      local vol_int
      vol_int=$(awk "BEGIN { printf \"%.0f\", $volume * 32768 }")
      mpg123 -q -f "$vol_int" "$sound_file" &>/dev/null &
    fi
  fi
}
