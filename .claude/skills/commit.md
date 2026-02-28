# Skill: commit

Stage and commit changes with a well-formed commit message.

## Pre-flight: changelog

Before staging anything, check whether CHANGELOG.md has content under
`## [Unreleased]` that reflects the current changes.

- If [Unreleased] is empty or only contains the bare section header, **stop and
  run `/changelog` first**, then return here.
- The changelog entry must be committed in the same commit as the feature work —
  not as a separate "update changelog" commit.

## Steps

1. Run `git status` and `git diff` (staged + unstaged) to understand what has changed.

2. Verify CHANGELOG.md [Unreleased] has content (see above).

3. Draft a commit message:
   - Imperative mood, present tense: "add watcher health check", not "added"
   - First line ≤ 72 characters
   - Reference the issue: `refs #N` (work in progress) or `closes #N` (last commit
     for this issue)
   - Body optional but useful for non-obvious changes

4. Show the staged file list and draft message to the user for confirmation.

5. Stage specific files by name — never `git add -A` or `git add .` without review.
   Always include CHANGELOG.md if it has been updated.

6. Commit using a HEREDOC to preserve formatting:
   ```
   git commit -m "$(cat <<'EOF'
   your message here

   refs #N
   EOF
   )"
   ```

7. Run `git status` after to confirm the working tree is clean.

## Rules

- Never add `Co-Authored-By: Claude` or any AI attribution lines.
- Never use `--no-verify` to skip the pre-commit hook.
- Never amend a previously pushed commit.
- One logical change per commit — if the diff spans multiple concerns, split it.
