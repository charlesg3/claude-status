# Skill: issues

List open GitHub issues grouped by component label.

## Steps

1. Fetch all open issues as JSON:
   ```sh
   gh issue list --state open --json number,title,labels,assignees
   ```

2. Group issues by their component label (vim-plugin, watcher, status-bar, hooks,
   config, notifications, install, tests, docs). An issue may appear in multiple
   groups if it has multiple component labels. Issues with no component label go
   under "uncategorised".

3. Format the output clearly, for example:
   ```
   watcher (3)
     #4  Add liveness check restart logic
     #7  State file race condition on fast events
     #11 Watcher PID persisted across reboots

   hooks (1)
     #2  Support chaining multiple scripts per event

   uncategorised (1)
     #1  Initial project setup
   ```

4. After the grouped list, show a count summary by label:
   ```
   Label counts:
     watcher        3
     hooks          1
     uncategorised  1
   ```

5. If there are no open issues, say so clearly.
