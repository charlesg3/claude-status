# claude-status

claude-status keeps you informed while Claude works — without requiring you to watch
the terminal. When a long task finishes or something goes wrong, it tells you through
whatever channel you prefer: a desktop notification, a sound, or an alert in your editor.

It works without Neovim and without a status bar. You can use as much or as little of
it as you want.

## Features

- **Desktop notifications** — native OS alerts when a task completes or errors; works on
  macOS and Linux; each channel gracefully skips if its tool is not installed
- **Sound alerts** — plays a sound file or picks a random sound from a folder; different
  sounds per event; adjustable volume
- **Neovim integration** — in-editor alerts posted to the Neovim instance that owns the
  Claude session; detects the right buffer automatically; "claude mode" API for statuslines
- **Optional status bar** — shows session state, git context, cost, and context usage;
  component-based so you enable only what you want; works with tmux or shell prompts
- **Highly configurable** — every channel can be tuned independently; per-channel
  thresholds let Neovim alert sooner than OS notifications; user config is never
  overwritten by updates

## Requirements

| Dependency | Purpose | macOS | Linux |
|---|---|---|---|
| `bash` 4+ | All scripts | pre-installed | pre-installed |
| `jq` | JSON config parsing | `brew install jq` | `apt install jq` |
| `afplay` | Sound notifications | pre-installed | — |
| `mpg123` | Sound notifications | — | `apt install mpg123` |
| `libnotify` (`notify-send`) | OS notifications | — | `apt install libnotify-bin` |
| `nvim` | Vim notifications + plugin | optional | optional |

Run `install.sh` to check and install OS dependencies automatically.

## Installation

### Step 1 — Base installation (always required)

```sh
git clone https://github.com/charlesg3/claude-status ~/src/claude-status
cd ~/src/claude-status
bash install.sh
```

Add the hooks to `~/.claude/settings.json` (see [Configuring Claude Hooks](#configuring-claude-hooks) below).

Optionally edit `~/.config/claude-status/config.json` to override defaults.

### Step 2 (optional) — Status bar or Neovim plugin

After the base installation you can add a status bar, the Neovim plugin, or both.
See [Status Bar Setup](#status-bar-setup) and [Neovim Plugin Configuration](#neovim-plugin-configuration).
The Neovim plugin can be used instead of the status bar.

**vim-plug**

```vim
Plug 'charlesg3/claude-status', {'rtp': '.'}
```

**lazy.nvim**

```lua
{
  'charlesg3/claude-status',
  config = function()
    -- optional: override defaults before setup
    vim.g.claude_status_notify_vim = true
    require('claude-status').setup()
  end,
}
```

**packer.nvim**

```lua
use {
  'charlesg3/claude-status',
  config = function() require('claude-status').setup() end,
}
```

**pathogen (submodule style)**

```sh
cd ~/.config/nvim  # or your nvim config root
git submodule add https://github.com/charlesg3/claude-status bundle/claude-status
```

Then in your `init.vim`:

```vim
execute pathogen#infect()
```

The `plugin/claude-status.vim` file loads automatically via pathogen.

## Configuration

Configuration is loaded by merging two JSON files:

1. `config.json` in the repo — global defaults, version-controlled
2. `~/.config/claude-status/config.json` — user overrides, never overwritten by updates

Keys present in the user file take precedence. Nested objects are merged one level deep;
arrays and scalars are replaced wholesale.

### Top-level keys

| Key | Default | Description |
|---|---|---|
| `project_name` | `"claude-status"` | Internal identifier |
| `config_dir` | `"~/.config/claude-status"` | Where user config and assets live |
| `state_dir` | `"/tmp"` | Where session state files are written |
| `log.file` | `"~/.local/share/claude-status/claude-status.log"` | Log path |
| `log.max_lines` | `500` | Log is trimmed to this many lines on rotation |
| `notifications.sound.enabled` | `true` | Master switch for sound |
| `notifications.sound.volume` | `0.7` | Volume (0.0–1.0) |
| `notifications.sound.on_long_running` | `true` | Sound when prompt finishes above threshold |
| `notifications.sound.on_error` | `true` | Sound on error |
| `notifications.sound.long_running_threshold` | `null` | Per-channel threshold override; `null` uses global |
| `notifications.os.enabled` | `true` | Master switch for OS notifications |
| `notifications.os.on_long_running` | `true` | OS notify when prompt finishes above threshold |
| `notifications.os.on_error` | `true` | OS notify on error |
| `notifications.os.long_running_threshold` | `null` | Per-channel threshold override; `null` uses global |
| `notifications.vim.enabled` | `true` | Master switch for Vim notifications |
| `notifications.vim.on_long_running` | `true` | Vim notify when prompt finishes above threshold |
| `notifications.vim.on_error` | `true` | Vim notify on error |
| `notifications.vim.long_running_threshold` | `null` | Per-channel threshold override; `null` uses global |
| `long_running.threshold_seconds` | `120` | Global default: seconds after which a completed prompt notifies; `0` = always |
| `statusline.enabled` | `true` | Master switch for the status bar; disable to use notifications only |
| `statusline.components.*` | (all enabled) | Toggle individual status bar components |
| `statusline.icons.*` | (see config.json) | Unicode icons used in the status bar |
| `statusline.colors.*` | (see config.json) | Hex colors for status bar segments |

### Example user override

```json
{
  "long_running": { "threshold_seconds": 120 },
  "notifications": {
    "sound": { "enabled": false },
    "os":    { "long_running_threshold": 120 },
    "vim":   { "long_running_threshold": 30 }
  }
}
```

This disables sound entirely, uses the global 120 s threshold for OS notifications, but
notifies Neovim after only 30 s — useful when you are in the editor and want earlier
feedback without being spammed by OS popups for quick tasks.

## Notification Events

claude-status fires notifications on these events:

| Event | When it fires |
|---|---|
| `long_running` | A prompt **completes** after running longer than the effective threshold. Set any channel's threshold to `0` to notify on every completion for that channel. Default threshold: 120 s. |
| `permission_prompt` | Claude needs your permission before it can continue. |

These events are intentionally minimal. The goal is to surface moments when Claude needs
your attention, not to narrate every action. See the Configuration section above for
per-channel threshold overrides.

## Configuring Claude Hooks

Add the following to `~/.claude/settings.json`. All hook events point to the same
dispatcher script, which inspects `hook_event_name` and dispatches accordingly.

Adjust the path to match wherever you cloned the repo (the example uses `~/src/claude-status`).

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "~/src/claude-status/hooks/claude-hook.sh" }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "~/src/claude-status/hooks/claude-hook.sh" }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          { "type": "command", "command": "~/src/claude-status/hooks/claude-hook.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "~/src/claude-status/hooks/claude-hook.sh" }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          { "type": "command", "command": "~/src/claude-status/hooks/claude-hook.sh" }
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
{ "type": "command", "command": "~/src/claude-status/hooks/claude-hook.sh /path/to/my-script.sh" }
```

Your script receives the raw Claude hook JSON on stdin and can do anything with it.
Exit codes from chained scripts are logged but do not affect Claude's hook processing.

## Status Bar Setup

`scripts/statusline.sh` reads the session state file and prints a one-line formatted
string suitable for tmux or a shell prompt right side.

The status bar reads from a per-session state file in `/tmp`. When running a single
Claude session, a global fallback file is supported so the status bar always shows the
most recent session. Multi-session support (showing the state for the session tied to the
current window) is a known open problem — see the tracking issues for current status.

Toggle components in `config.json` under `statusline.components` — set `"enabled": false`
for any segment you don't want.

## Neovim Plugin Configuration

Set any of these before `require('claude-status').setup()` (or before the plugin loads
via pathogen/vim-plug):

| Variable | Default | Description |
|---|---|---|
| `g:claude_status_enabled` | `1` | Master enable/disable |
| `g:claude_status_notify_vim` | `1` | Show in-editor notifications |
| `g:claude_status_notify_level` | `'info'` | Minimum level: `'info'`, `'warn'`, `'error'` |
| `g:claude_status_claude_mode_hl` | `'StatusLine'` | Highlight group for claude mode indicator |
| `g:claude_status_server_socket` | `''` | Override nvim server socket path |
| `g:claude_status_state_dir` | `'/tmp'` | Must match `state_dir` in config.json |

## Troubleshooting

**Hooks are not firing**
Check the log at `~/.local/share/claude-status/claude-status.log`. Ensure `jq` is installed
and that the hooks script is executable (`chmod +x hooks/claude-hook.sh`).

**No OS notifications on Linux**
Install `libnotify-bin` (`apt install libnotify-bin`) and ensure a notification daemon
(e.g. `dunst`, `mako`) is running.

**No sound on Linux**
Install `mpg123` (`apt install mpg123`) and verify it can play a file directly:
`mpg123 /path/to/sound.mp3`.

**Neovim notifications not appearing**
The plugin requires Neovim to be started with `--listen` or for `$NVIM` to be set.
Check that `g:claude_status_notify_vim` is `1` and that the server socket path is
discoverable. Run `:echo serverlist()` in Neovim to verify.

**Hook not firing**
Confirm the path in `~/.claude/settings.json` is correct and the script is executable.
Test manually: `echo '{"hook_event_name":"Stop","session_id":"test"}' | bash hooks/claude-hook.sh`.

**Status bar shows nothing**
Check `/tmp/claude-status-*.json` for state files. The hook dispatcher creates one on the
first hook event. Verify the hook is configured correctly in `~/.claude/settings.json`.

## License

MIT — see [LICENSE](LICENSE) for details.
