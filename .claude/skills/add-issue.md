# Skill: add-issue

Create a new GitHub issue with the correct labels and remind about branch naming.

## Steps

1. Ask the user for:
   - **Title**: short, imperative description
   - **Type**: feature or bug
   - **Component(s)**: one or more of: vim-plugin, watcher, status-bar, hooks, config,
     notifications, install, tests, docs
   - **Description**: what the issue is and why it matters

2. Map type to primary label:
   - feature → `feature`
   - bug → `bug`

3. Map each selected component to its label (same names as the component list above).

4. Build the issue body from the appropriate template:

   For **features**:
   ```
   ## Summary
   <description>

   ## Motivation
   <why this matters>

   ## Proposed Solution
   <how to implement it>

   ## Acceptance Criteria
   - [ ] <criterion 1>
   - [ ] <criterion 2>
   ```

   For **bugs**:
   ```
   ## Summary
   <description>

   ## Steps to Reproduce
   1. <step>

   ## Expected Behavior
   <what should happen>

   ## Actual Behavior
   <what happens instead>
   ```

5. Create the issue:
   ```sh
   gh issue create \
     --title "..." \
     --label "feature,watcher" \
     --body "..."
   ```

6. Show the issue URL and number.

7. Remind the user:
   - Feature branch: `git checkout -b feat/N-short-desc`
   - Bug branch: `git checkout -b bug/N-short-desc`
   - Replace N with the issue number just created.
