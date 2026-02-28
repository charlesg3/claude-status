#!/usr/bin/env bash
# Visual + functional tests for scripts/statusline.sh.
#
# For each subdirectory under tests/data/, runs the statusline script with
# the scenario's state.json (and optional config.json override) and prints
# the rendered output.  Used both for CI assertion and for pasting into PR
# descriptions when status bar changes are involved.
#
# Usage:
#   bash tests/test-statusline.sh            # run all scenarios
#   bash tests/test-statusline.sh working    # run one named scenario
#
# Environment overrides:
#   STATUSLINE_WIDTH  Terminal width for rendering (default: 120)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
STATUSLINE="$REPO_DIR/scripts/statusline.sh"

source "$REPO_DIR/scripts/common.sh"

# Override terminal width for reproducible output.
# The statusline script reads COLUMNS (falls back to tput cols).
export COLUMNS="${STATUSLINE_WIDTH:-120}"

# ── Guard ─────────────────────────────────────────────────────────────────────
if [[ ! -f "$STATUSLINE" ]]; then
    err "scripts/statusline.sh not yet implemented"
    exit 1
fi

pass=0; fail=0; skip=0

run_scenario() {
    local scenario_dir="$1"
    local scenario
    scenario="$(basename "$scenario_dir")"
    local state_file="$scenario_dir/state.json"
    local config_file="$scenario_dir/config.json"

    if [[ ! -f "$state_file" ]]; then
        skip "$scenario"
        ((skip++)); return
    fi

    header "$scenario"

    local env_args=("STATE_FILE=$state_file")
    [[ -f "$config_file" ]] && env_args+=("CONFIG_OVERRIDE=$config_file")

    local output exit_code=0
    output=$(env "${env_args[@]}" bash "$STATUSLINE" 2>&1) || exit_code=$?

    if [[ -n "$output" ]]; then
        printf "%s\n" "$output"
    else
        printf "  (no output)\n"
    fi

    if [[ $exit_code -eq 0 ]]; then
        ok "exit 0"
        ((pass++))
    else
        err "exit $exit_code"
        ((fail++))
    fi
}

# ── Run scenarios ─────────────────────────────────────────────────────────────
if [[ $# -gt 0 ]]; then
    for name in "$@"; do
        scenario_dir="$DATA_DIR/$name"
        if [[ ! -d "$scenario_dir" ]]; then
            err "no scenario named '$name' in tests/data/"
            exit 1
        fi
        run_scenario "$scenario_dir"
    done
else
    for scenario_dir in "$DATA_DIR"/*/; do
        [[ -d "$scenario_dir" ]] || continue
        run_scenario "$scenario_dir"
    done
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if [[ $fail -eq 0 ]]; then
    pass_banner "All tests passed  ($pass passed, $skip skipped)"
else
    fail_banner "$fail failed  ($pass passed, $skip skipped)"
fi

[[ $fail -eq 0 ]]
