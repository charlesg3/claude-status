# Skill: test

Run the claude-watcher test suite and report results.

## Steps

1. Run the full suite via the unified runner:
   ```sh
   bash scripts/run-tests.sh
   ```
   This covers: bash/JSON syntax (all repo files), status bar unit tests, mock event
   smoke tests, and headless Neovim plugin tests.

2. To run everything except the slow headless Neovim test (mirrors the git hook):
   ```sh
   bash scripts/run-tests.sh --no-vim
   ```

3. To run a specific subset, pass a flag:
   ```sh
   bash scripts/run-tests.sh --syntax      # bash -n + jq syntax only
   bash scripts/run-tests.sh --statusline  # status bar unit tests only
   bash scripts/run-tests.sh --mock        # mock event smoke tests only
   bash scripts/run-tests.sh --vim         # headless nvim tests only
   ```

4. To inspect or fire individual mock events manually:
   ```sh
   bash tests/mock-event.sh --list         # list available events
   bash tests/mock-event.sh Stop           # fire a specific event
   bash tests/mock-event.sh PreToolUse
   bash tests/mock-event.sh PostToolUse
   bash tests/mock-event.sh Notification
   bash tests/mock-event.sh SubagentStop
   ```

5. For headless Neovim tests directly:
   ```sh
   nvim --headless -l tests/test-vim.lua
   ```

6. Report the results clearly:
   - State how many tests passed, failed, skipped.
   - For any failure, show the relevant error output.
   - If a test was skipped due to a missing dependency (e.g. nvim, jq), note that
     separately from actual failures.

## Notes

- The git pre-commit hook (installed by `install.sh`) runs `run-tests.sh --no-vim`
  automatically on every `git commit`. This covers syntax and unit tests without the
  latency of launching Neovim.
- CI (GitHub Actions) runs the full suite including Neovim on every push and PR.
- Before opening a PR, run the full suite locally at least once:
  `bash scripts/run-tests.sh`
