# Skill: commit

Stage and commit changes with a well-formed commit message.

## Pre-flight: changelog

Before staging anything, check whether CHANGELOG.md has content under
`## [Unreleased]` that reflects the current changes.

- If [Unreleased] is empty or only contains the bare section header, **stop and
  run `/changelog` first**, then return here.
- The changelog entry must be committed in the same commit as the feature work —
  not as a separate "update changelog" commit.

## Commit message format

```
`[{feat|bug|chore}/KEBAB-DESCRIPTION]` short description in imperative mood

Overview paragraph: what is being changed and why, with enough context
for someone reading the log to understand the change without diffing.

Changes:
- specific thing changed in file or module
- another specific change, referencing the relevant code/concept
- ...

Caveats (omit section if none):
- known dependency on issue #N before this is fully usable
- outstanding edge case or known limitation
- anything that will need follow-up

refs #N      (work in progress — more commits coming for this issue)
closes #N    (this commit finishes the issue)
```

**Rules for the subject line:**
- Format must be `[type/kebab-description] imperative summary`
- `type` is one of: `feat`, `bug`, `chore`
- `KEBAB-DESCRIPTION` matches the branch name suffix (e.g. branch `feat/3-hook-dispatcher` → `` `[feat/hook-dispatcher]` ``)
- Total first line ≤ 72 characters
- No period at the end

## Steps

1. Run `git status` and `git diff` (staged + unstaged) to understand what changed.

2. Verify CHANGELOG.md [Unreleased] has content (see above).

3. Check whether `README.md` needs updating. Update it in the same commit if the
   changes affect any of the following:
   - User-visible behaviour or workflow
   - Config keys (added, removed, renamed, or changed defaults)
   - OS-level dependencies (add a row to the Requirements table and update `install.sh`)

4. Draft the commit message following the format above.

5. Warn if there is no `refs #N` or `closes #N` — every commit should correspond
   to a GitHub issue. If no issue exists, prompt the user to create one first
   with `/add-issue`.

6. Show the staged file list and draft message to the user for confirmation.

7. Stage specific files by name — never `git add -A` or `git add .` without review.
   Always include CHANGELOG.md if it has been updated.

8. Commit using a HEREDOC to preserve formatting:
   ```
   git commit -m "$(cat <<'EOF'
   `[feat/hook-dispatcher]` add single entry-point hook dispatcher

   Overview here.

   Changes:
   - hooks/claude-hook.sh: new dispatcher reads hook_event_name from stdin
   - scripts/common.sh: source shared helpers

   closes #1
   EOF
   )"
   ```

9. Run `git status` after to confirm the working tree is clean.

## Rules

- Never add `Co-Authored-By: Claude` or any AI attribution lines.
- Never use `--no-verify` to skip the pre-commit hook.
- Never amend a previously pushed commit.
- One logical change per commit — if the diff spans multiple concerns, split it.
