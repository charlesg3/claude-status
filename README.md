# claude-watcher

claude-watcher is a Claude Code hook dispatcher, background session watcher, status bar
formatter, and Neovim plugin — all in one cohesive system. It connects Claude's hook
events to your editor, terminal, and OS so you always know exactly what Claude is doing,
even when you've switched away from its window.

When Claude finishes a long task, claude-watcher sends an OS notification, plays a
configurable sound, and optionally posts a message directly to the Neovim buffer that
owns the session. A background watcher process polls Claude's session state file at
200 ms intervals for event responsiveness and 1 s intervals for status bar updates,
writing formatted state that your shell prompt or tmux status line can read at any time.

The system is designed to be fully standalone — it works without Neovim and without
the status bar. Notifications (OS, sound, Neovim, terminal bell) work independently.
The optional Neovim plugin adds session-aware buffer tracking, `WinEnter`/`WinLeave`-based
"claude mode" detection, and in-editor notifications via the Neovim RPC server.
The status bar is disabled via `statusline.enabled: false` in your config.

## Features

- **Single hook dispatcher** — one script handles every Claude hook event; easy to chain
  with your own scripts
- **Background watcher** — monitors session liveness at 200 ms; self-terminates when
  Claude exits; writes structured state to `/tmp`
- **Status bar formatter** — reads state file and outputs a formatted, component-togglable
  status string for shell prompts or tmux
- **OS notifications** — `osascript` on macOS, `notify-send` on Linux; configurable per
  event type (complete, error, long-running)
- **Sound notifications** — `afplay` on macOS, `paplay` on Linux; per-event and
  per-volume control
- **Vim notifications** — posts messages to the owning Neovim instance via `--server` /
  `remote-expr`; no extra daemon required
- **Long-running detection** — notifies when a prompt exceeds a configurable threshold
  (default 60 s)
- **Idempotent watcher startup** — every hook run calls the watcher start routine; if
  already running it exits silently; if a stale PID is found (crash detected) it logs,
  optionally notifies, and restarts
- **Config merging** — `config.json` in the repo holds defaults; user overrides live in
  `~/.config/claude-watcher/config.json`
- **Neovim plugin** — session-to-buffer mapping via PPID ancestry walk, claude mode
  detection, standard `g:` config vars
- **Continuous versioning** — PRs labelled `minor` bump the minor version and reset
  patch; unlabelled PRs bump the patch

## Requirements

| Dependency | Purpose | macOS | Linux |
|---|---|---|---|
| `bash` 4+ | All scripts | pre-installed | pre-installed |
| `jq` | JSON config parsing | `brew install jq` | `apt install jq` |
| `afplay` | Sound notifications | pre-installed | — |
| `paplay` | Sound notifications | — | `apt install pulseaudio-utils` |
| `libnotify` (`notify-send`) | OS notifications | — | `apt install libnotify-bin` |
| `nvim` | Vim notifications + plugin | optional | optional |

Run `install.sh` to check and install OS dependencies automatically.

## Installation

### Without Neovim (standalone)

```sh
git clone https://github.com/charlesg3/claude-watcher ~/.config/claude-watcher
cd ~/.config/claude-watcher
bash install.sh
```

Add the hooks to `~/.claude/settings.json` (see [Configuring Claude Hooks](#configuring-claude-hooks) below).

Optionally edit `~/.config/claude-watcher/config.json` to override defaults.

### With Neovim — vim-plug

```vim
Plug 'charlesg3/claude-watcher', {'rtp': '.'}
```

### With Neovim — lazy.nvim

```lua
{
  'charlesg3/claude-watcher',
  config = function()
    -- optional: override defaults before setup
    vim.g.claude_watcher_notify_vim = true
    require('claude-watcher').setup()
  end,
}
```

### With Neovim — packer.nvim

```lua
use {
  'charlesg3/claude-watcher',
  config = function() require('claude-watcher').setup() end,
}
```

### With Neovim — pathogen (submodule style)

```sh
cd ~/.config/nvim  # or your nvim config root
git submodule add https://github.com/charlesg3/claude-watcher bundle/claude-watcher
```

Then in your `init.vim`:

```vim
execute pathogen#infect()
```

The `plugin/claude-watcher.vim` file loads automatically via pathogen.

## Configuration

Configuration is loaded by merging two JSON files:

1. `config.json` in the repo — global defaults, version-controlled
2. `~/.config/claude-watcher/config.json` — user overrides, never overwritten by updates

Keys present in the user file take precedence. Nested objects are merged one level deep;
arrays and scalars are replaced wholesale.

### Top-level keys

| Key | Default | Description |
|---|---|---|
| `project_name` | `"claude-watcher"` | Internal identifier |
| `config_dir` | `"~/.config/claude-watcher"` | Where user config and assets live |
| `state_dir` | `"/tmp"` | Where session state files are written |
| `log.file` | `"~/.local/share/claude-watcher/watcher.log"` | Watcher log path |
| `log.max_lines` | `500` | Log is trimmed to this many lines on rotation |
| `watcher.event_interval_ms` | `200` | Poll interval for hook events |
| `watcher.display_interval_ms` | `1000` | Poll interval for status bar refresh |
| `notifications.sound.enabled` | `true` | Master switch for sound |
| `notifications.sound.volume` | `0.7` | Volume (0.0–1.0) |
| `notifications.sound.on_complete` | `true` | Sound on task complete |
| `notifications.sound.on_error` | `true` | Sound on error |
| `notifications.sound.on_long_running` | `true` | Sound when threshold exceeded |
| `notifications.os.enabled` | `true` | Master switch for OS notifications |
| `notifications.os.on_complete` | `true` | OS notify on complete |
| `notifications.os.on_error` | `true` | OS notify on error |
| `notifications.os.on_long_running` | `true` | OS notify when threshold exceeded |
| `notifications.vim.enabled` | `true` | Master switch for Vim notifications |
| `notifications.vim.on_complete` | `true` | Vim notify on complete |
| `notifications.vim.on_error` | `true` | Vim notify on error |
| `notifications.vim.on_long_running` | `true` | Vim notify when threshold exceeded |
| `long_running.enabled` | `true` | Enable long-running detection |
| `long_running.threshold_seconds` | `60` | Seconds before a prompt is "long-running" |
| `statusline.enabled` | `true` | Master switch for the status bar; disable to use notifications only |
| `statusline.components.*` | (all enabled) | Toggle individual status bar components |
| `statusline.icons.*` | (see config.json) | Unicode icons used in the status bar |
| `statusline.colors.*` | (see config.json) | Hex colors for status bar segments |

### Example user override

```json
{
  "long_running": { "threshold_seconds": 30 },
  "notifications": {
    "sound": { "enabled": false },
    "os":    { "on_complete": false }
  }
}
```

## Configuring Claude Hooks

Add the following to `~/.claude/settings.json`. Every hook event points to the same
dispatcher script, which inspects `hook_event_name` and dispatches accordingly.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "~/.config/claude-watcher/hooks/claude-hook.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "~/.config/claude-watcher/hooks/claude-hook.sh" }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "~/.config/claude-watcher/hooks/claude-hook.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "~/.config/claude-watcher/hooks/claude-hook.sh" }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "~/.config/claude-watcher/hooks/claude-hook.sh" }
        ]
      }
    ]
  }
}
```

### Hook chaining

The dispatcher accepts extra positional arguments — each one is an additional script to
run after the built-in handling. The same hook input JSON is forwarded to each script via
stdin.

```json
{ "type": "command", "command": "~/.config/claude-watcher/hooks/claude-hook.sh /path/to/my-script.sh" }
```

Your script receives the raw Claude hook JSON on stdin and can do anything with it.
Exit codes from chained scripts are logged but do not affect Claude's hook processing.

## Status Bar Setup

`scripts/statusline.sh` reads the session state file and prints a one-line formatted
string. Integrate it into your shell prompt or tmux status:

**tmux** (`~/.tmux.conf`):

```
set -g status-right '#(~/.config/claude-watcher/scripts/statusline.sh)'
set -g status-interval 1
```

**zsh prompt** (`~/.zshrc`):

```sh
_claude_status() { ~/.config/claude-watcher/scripts/statusline.sh 2>/dev/null; }
RPROMPT='$(_claude_status)'
```

Toggle components in `config.json` under `statusline.components` — set `"enabled": false`
for any segment you don't want.

## Neovim Plugin Configuration

Set any of these before `require('claude-watcher').setup()` (or before the plugin loads
via pathogen/vim-plug):

| Variable | Default | Description |
|---|---|---|
| `g:claude_watcher_enabled` | `1` | Master enable/disable |
| `g:claude_watcher_notify_vim` | `1` | Show in-editor notifications |
| `g:claude_watcher_notify_level` | `'info'` | Minimum level: `'info'`, `'warn'`, `'error'` |
| `g:claude_watcher_claude_mode_hl` | `'StatusLine'` | Highlight group for claude mode indicator |
| `g:claude_watcher_server_socket` | `''` | Override nvim server socket path |
| `g:claude_watcher_state_dir` | `'/tmp'` | Must match `state_dir` in config.json |

## Troubleshooting

**Watcher is not starting**
Check the log at `~/.local/share/claude-watcher/watcher.log`. Ensure `jq` is installed
and that the hooks script is executable (`chmod +x hooks/claude-hook.sh`).

**No OS notifications on Linux**
Install `libnotify-bin` (`apt install libnotify-bin`) and ensure a notification daemon
(e.g. `dunst`, `mako`) is running.

**No sound on Linux**
Install `pulseaudio-utils` (`apt install pulseaudio-utils`) and verify PulseAudio or
PipeWire is running (`pactl info`).

**Neovim notifications not appearing**
The plugin requires Neovim to be started with `--listen` or for `$NVIM` to be set.
Check that `g:claude_watcher_notify_vim` is `1` and that the server socket path is
discoverable. Run `:echo serverlist()` in Neovim to verify.

**Hook not firing**
Confirm the path in `~/.claude/settings.json` is correct and the script is executable.
Test manually: `echo '{"hook_event_name":"Stop","session_id":"test"}' | bash hooks/claude-hook.sh`.

**Status bar shows nothing**
Ensure a watcher process is running for your session. The hook dispatcher starts it
automatically on the first hook event. Check `/tmp/claude-watcher-*.json` for state files.

## License

MIT — see [LICENSE](LICENSE) for details.
