# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `scripts/statusline.sh` — `statusLine` stdin mode: detects when Claude calls the script as `statusLine.command` (no `STATE_FILE` env var, stdin is a pipe), reads live session JSON, computes `context_pct = floor(100 - remaining_percentage)` and extracts `cost_usd`, patches STATE_FILE atomically so other renderers stay current, then renders as normal (#35)
- `tests/data/stdin-mode/` — test scenario exercising the `statusLine` stdin code path with `stdin.json` alongside `state.json` (#35)

### Changed
- `tests/test-statusline.sh` — `run_scenario` now handles stdin-mode scenarios (presence of `stdin.json` in the scenario dir); COLUMNS is passed explicitly in env args for both code paths (#35)
- `dotfiles/install.sh` — claude-status hook wiring updated to register `SessionStart`, `UserPromptSubmit`, `Notification`, `Stop`, `SessionEnd` (replaces `PreToolUse`/`PostToolUse`/`SubagentStop`); sets `statusLine.command` to our `scripts/statusline.sh` when claude-status is present

### Changed
- `hooks/claude-hook.sh` — `SessionStart` now records `session_start_epoch`; `UserPromptSubmit` no longer deletes `duration_seconds` (#35)
- `scripts/statusline.sh` — duration component now shows total session time (`now - session_start_epoch`), computed live on each render so it never disappears mid-session; supports `MOCK_NOW` env var for deterministic tests (#35)
- `tests/test-statusline.sh` — exports `MOCK_NOW=1772340000` so duration is stable across runs (#35)
- `tests/data/*/state.json` — replaced `duration_seconds` with `session_start_epoch` derived from `MOCK_NOW - duration` (#35)

### Fixed
- `hooks/claude-hook.sh` — Stop hook exiting non-zero (silent crash) when no long-running notification fired: `$fired && log_info` expanded `false` as a command (exit 1), triggering `set -e`; replaced with `[[ "$fired" == "true" ]] && ... || true`
- `scripts/statusline.sh` — terminal width now read via `stty size </dev/tty` (TIOCGWINSZ) instead of `tput cols` which always returned 80 when stdin was a pipe; falls back to 120 (#35)
- `scripts/statusline.sh` — `_visible_len` now counts supplementary-plane emoji (UTF-8 leading byte F0–F4) as 2 terminal columns; fixes right-side padding for 📁 🌿 💰 icons (#35)
- `scripts/statusline.sh` — spacer subtracts 3-char right margin to avoid content being clipped by Claude's statusline renderer (#35)
- `scripts/statusline.sh` — added debug log at `/tmp/claude-statusline.log` to aid diagnosis of rendering issues (#35)

## [0.1.0] - 2026-02-28

### Added
- `scripts/lib/config.sh` — `get_config` and `get_threshold` helpers; merges repo defaults with `~/.config/claude-status/config.json`; handles JSON `false` correctly via `if .key == null` instead of `// empty` (#17)
- `scripts/lib/state.sh` — atomic state file read/write helpers (`write_state`, `patch_state`, `read_state_field`) (#18)
- `scripts/lib/notify.sh` — OS desktop notification helper for macOS (`osascript`) and Linux (`notify-send`) (#19)
- `scripts/lib/sound.sh` — sound notification helper; resolves per-event path overrides, falls back to random file from a directory; uses `afplay` on macOS, `mpg123` on Linux (#20)
- `hooks/claude-hook.sh` — single-entry-point dispatcher for `SessionStart`, `UserPromptSubmit`, `Notification`, `Stop`, `SessionEnd`; writes session state, fires long-running and permission-prompt notifications (#6)
- `scripts/statusline.sh` — component-based status line formatter; left/right layout split on `spacer`; components: `state`, `directory`, `branch`, `git_status`, `context`, `cost`, `duration` (#12)
- `tests/data/long-running/` — test scenario for long-running sessions (1h+ duration, high cost)

### Changed
- `config.json` — removed per-component `enabled` flags (layout array controls rendering); removed `last_status` from default layout; updated error color to `#C91614` (Panda theme pure red, replacing hot-pink)
- `README.md` — restructured installation as Step 1 (always required) + Step 2 (optional status bar or Neovim plugin); updated hook config to correct five events; updated notification events table
- `CLAUDE.md` — updated architecture section with correct hook events; added null-punning convention documenting the `false`/`null` distinction in `get_config`

### Fixed
- `tests/test-statusline.sh` — `((counter++))` with `set -e` exits when counter is 0; replaced with `counter=$(( counter + 1 ))` throughout (#12)

### Removed
- `tests/data/tool-failure/` and `tests/data/tool-success/` — removed scenarios that relied on the dropped `last_status` component

[0.1.0]: https://github.com/charlesg3/claude-status/compare/91897a4...v0.1.0
[Unreleased]: https://github.com/charlesg3/claude-status/compare/v0.1.0...HEAD
