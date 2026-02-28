# Skill: pr

Create a GitHub pull request with correct naming, version label, issue reference,
and a completed test plan.

## PR title format

```
`[{feat|bug|chore}/KEBAB-DESCRIPTION]` short description in imperative mood
```

Same format as the commit subject line. ≤ 70 characters total.

## Steps

1. Check the current branch name.
   - Must follow `feat/N-kebab`, `bug/N-kebab`, or `chore/N-kebab`.
   - If it does not match, warn the user and ask them to rename it before continuing.

2. Extract the issue number N from the branch name.
   - **Warn loudly if no issue number is present** — every PR must correspond to a
     GitHub issue. If none exists, run `/add-issue` first.

3. Run `git log --oneline main..HEAD` to see all commits on this branch.

4. Check whether CHANGELOG.md [Unreleased] has been updated. If not, run
   `/changelog` before opening the PR.

5. Determine the version bump type:
   - Ask the user: "Is this a minor bump or a patch bump?"
   - Minor = new capability or interface change.
   - Patch = bug fix, small addition, docs, refactor.

6. **Run the test suite** before drafting the PR body:
   ```
   bash scripts/run-tests.sh 2>&1
   ```
   Capture the full output — it goes into the PR body.

7. Draft the PR title following the format above.

8. Draft the PR body:
   ```markdown
   ## Summary

   Brief description of what this PR does and why.

   ## Changes
   - specific change in module/file
   - another change
   - ...

   ## Test plan
   - [x] bash scripts/run-tests.sh passes
   - [x] manually tested: <describe what you did>
   - [ ] unchecked item = not yet done (leave unchecked if not complete)

   ## Test output
   ```
   <paste full output of bash scripts/run-tests.sh here>
   ```

   Closes #N
   ```

   **Requirements:**
   - `Closes #N` is **mandatory**. The PR will not be valid without it.
   - Test plan checkboxes must be filled `[x]` only if actually completed.
   - If any test plan item is unchecked, note why in the PR body.
   - The test output code block must contain real output, not placeholder text.

9. **Pre-merge checklist** — before creating the PR, verify:
   - [ ] All test plan items are checked `[x]`
   - [ ] Test output is pasted in the body (not a placeholder)
   - [ ] `Closes #N` is present
   - [ ] Branch name follows the convention
   - [ ] CHANGELOG.md is updated

   If any item is unmet, warn the user and do not open the PR until resolved.

10. Determine the label:
    - Minor bump → `--label "minor"`
    - Patch / chore → no version label

11. Push the branch if it has no upstream:
    ```
    git push -u origin HEAD
    ```

12. Create the PR:
    ```
    gh pr create \
      --title "\`[feat/hook-dispatcher]\` add single entry-point hook dispatcher" \
      --label "minor" \
      --body "$(cat <<'EOF'
    ...body...
    EOF
    )"
    ```

13. Print the PR URL.

14. Remind the user: once merged, the version in CHANGELOG.md's most recent
    `## [x.y.z]` entry becomes the new release tag.

## Rules

- Never open a PR from `main` to `main`.
- `Closes #N` in the body is mandatory — warn if missing.
- Branch name must follow the `feat/`, `bug/`, or `chore/` convention.
- Test plan must be filled in with real results before merging.
- Do not add `Co-Authored-By` lines.
