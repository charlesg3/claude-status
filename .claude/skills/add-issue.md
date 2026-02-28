# Skill: add-issue

Create a new GitHub issue with the correct labels and remind about branch naming.

## Steps

1. Ask the user for:
   - **Title**: short, imperative description (the bare title, without prefix)
   - **Type**: `feat`, `bug`, or `chore`
   - **Component(s)**: one or more of: vim-plugin, status-bar, hooks, config,
     notifications, install, tests, docs
   - **Description**: what the issue is and why it matters

2. Format the issue title as **`[type/component]` bare title** — matching commit and
   branch convention:
   - `` `[feat/hooks]` `` add hook dispatcher
   - `` `[bug/hooks]` `` fix concurrent hook state write race
   - `` `[chore/tests]` `` add headless Neovim test suite

   Use the primary component as the label after the slash. If multiple components apply,
   pick the most specific one for the title prefix; add all as labels.

3. Map type to primary label:
   - `feat` → `feature`
   - `bug` → `bug`
   - `chore` → `chore`

4. Map each selected component to its label (same names as the component list above).

5. Build the issue body from the appropriate template:

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

6. Create the issue with the formatted title:
   ```sh
   gh issue create \
     --title "\`[feat/hooks]\` add hook dispatcher" \
     --label "feature,hooks" \
     --body "..."
   ```

7. Show the issue URL and number.

8. Remind the user:
   - Feature/chore branch: `git checkout -b feat/N-short-desc`
   - Bug branch: `git checkout -b bug/N-short-desc`
   - Replace N with the issue number just created.
