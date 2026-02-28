# Skill: changelog

Update CHANGELOG.md with entries for recent work, and bump the version heading
according to the project's continuous-release versioning rules.

## Versioning rules

- Every PR merge produces a new release.
- If the PR carries the **`minor`** label: bump minor, reset patch to zero
  (e.g. `0.1.3` → `0.2.0`).
- Otherwise: bump patch by one (e.g. `0.1.3` → `0.1.4`).
- Major bumps are manual only.
- Determine the current version from the most recent `## [x.y.z]` heading in
  CHANGELOG.md (ignoring `[Unreleased]`).

## Steps

1. Read CHANGELOG.md to find the most recent released version and the current
   [Unreleased] content.

2. Ask the user (or infer from context):
   - Is this a minor bump or a patch bump?
   - What issue / PR number does this correspond to? (for the `(#N)` suffix)

3. Compute the new version string from the rules above.

4. Look at recent commits (`git log --oneline main..HEAD` or since last tag) and
   any closed issues to gather what changed.

5. Draft new entries grouped by category:
   - **Added** — new features
   - **Changed** — changes to existing behaviour
   - **Fixed** — bug fixes
   - **Removed** — removals or deprecations

   Each entry must end with `(#N)` referencing the issue or PR.

6. In CHANGELOG.md:
   a. Replace the `## [Unreleased]` heading with `## [NEW_VERSION] - YYYY-MM-DD`
      (today's date).
   b. Insert a fresh empty `## [Unreleased]` section above it.
   c. Update the compare URL at the bottom of the file:
      `[NEW_VERSION]: https://github.com/charlesg3/claude-watcher/compare/vOLD...vNEW`
      `[Unreleased]: https://github.com/charlesg3/claude-watcher/compare/vNEW...HEAD`

7. Show the diff to the user for confirmation before writing.

## Notes

- Do not create a git tag — that happens at merge time.
- The changelog entry should be written **before** running `/commit`, so that
  CHANGELOG.md is included in the same commit as the feature work.
- If [Unreleased] is already empty, warn the user and ask them to describe the changes.
