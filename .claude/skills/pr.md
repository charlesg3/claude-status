# Skill: pr

Create a GitHub pull request with correct naming, version label, and issue reference.

## Steps

1. Check the current branch name.
   - Must follow `feat/N-short-kebab-desc` or `bug/N-short-kebab-desc`.
   - If it does not match, warn the user and ask them to rename it before continuing.

2. Extract the issue number N from the branch name.

3. Run `git log --oneline main..HEAD` to see all commits on this branch.

4. Check whether all commits include the CHANGELOG.md update. If not, remind the
   user to run `/changelog` before opening the PR.

5. Determine the version bump type:
   - Ask the user: "Is this a minor bump or a patch bump?"
   - Minor = new feature that changes the public interface or adds a major capability.
   - Patch = bug fix, small addition, docs, internal refactor.

6. Draft the PR title (≤ 70 characters, imperative mood).

7. Draft the PR body:
   ```
   ## Summary
   - <bullet 1>
   - <bullet 2>

   ## Changes
   - <change> (#N)

   ## Test plan
   - [ ] bash scripts/run-tests.sh passes
   - [ ] manually tested: <describe>

   ## Checklist
   - [ ] CHANGELOG.md updated
   - [ ] Branch follows naming convention

   Closes #N
   ```
   The "Closes #N" line is **required** — the PR will not be valid without it.

8. Determine the label to apply:
   - Minor bump → add label `minor`
   - Patch bump → no version label needed

9. Push the branch if it has no upstream:
   ```
   git push -u origin HEAD
   ```

10. Create the PR:
    ```
    gh pr create \
      --title "..." \
      --label "minor"         # only if minor bump \
      --body "$(cat <<'EOF'
    ...body...
    EOF
    )"
    ```

11. Print the PR URL.

12. Remind the user: once merged, the version in CHANGELOG.md's most recent
    `## [x.y.z]` entry becomes the new release tag.

## Rules

- Never open a PR from `main` to `main`.
- "Closes #N" in the body is mandatory.
- Branch name must follow the `feat/` or `bug/` convention — warn loudly if not.
- Do not add `Co-Authored-By` lines.
