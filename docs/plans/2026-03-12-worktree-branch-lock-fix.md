# Fix Worktree Provisioning — Smarter Branch Lock + Git Show Replacements

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Stop the branch-lock lefthook from destroying provisioned files in parent agent directories when `just provision` runs `git checkout` for file operations.

**Architecture:** Two-pronged fix: (1) make the lefthook hook distinguish branch switches from file checkouts using git's post-checkout flag argument, and (2) replace all `git checkout <ref> -- <file>` calls in justfile templates with `git show <ref>:<file>` which doesn't trigger hooks at all.

**Tech Stack:** Lefthook (git hooks), Just (command runner), Ansible/Jinja2 (templates), Bash

---

### Task 1: Update the live lefthook.yml branch-lock hook

**Files:**
- Modify: `/Users/patrick/agents/orchestrator/workaxle-core/lefthook.yml:1-16`

**Step 1: Replace the current hook with a smarter version**

The current hook fires on all post-checkout events and runs `git reset --hard`, which destroys provisioned files. Replace it to:
- Check `{3}` (checkout type flag: `1` = branch switch, `0` = file checkout)
- Skip file-level checkouts entirely
- Remove `git reset --hard` — use `git checkout` to revert the branch without nuking untracked files

```yaml
## Lefthook configuration — branch lock
## Prevents branch switches; use worktrees instead.
## File-level checkouts (git checkout main -- file) are allowed.

post-checkout:
  commands:
    lock-branch:
      run: |
        # {3} = checkout type flag: 1=branch switch, 0=file checkout
        if [ "{3}" != "1" ]; then
          exit 0
        fi
        LOCKED_BRANCH="main"
        CURRENT=$(git symbolic-ref --short HEAD 2>/dev/null)
        if [ "$CURRENT" != "$LOCKED_BRANCH" ]; then
          echo "ERROR: Branch locked to '$LOCKED_BRANCH'. Use worktrees instead. Reverting."
          LEFTHOOK=0 git checkout "$LOCKED_BRANCH" --quiet
          exit 1
        fi
```

Note: `LEFTHOOK=0` on the revert checkout prevents the hook from firing recursively.

**Step 2: Verify lefthook picks up the change**

Run:
```bash
cd ~/agents/orchestrator/workaxle-core && lefthook install
```
Expected: lefthook installs successfully.

**Step 3: Test that file checkouts no longer trigger the lock**

Run:
```bash
cd ~/agents/orchestrator/workaxle-core && git checkout main -- db/structure.sql
```
Expected: File is checked out silently. No "ERROR: Branch locked" message. No files destroyed.

**Step 4: Test that branch switches are still blocked**

Run:
```bash
cd ~/agents/orchestrator/workaxle-core && git checkout -b test-lock-branch 2>/dev/null; git symbolic-ref --short HEAD
```
Expected: Output is `main`. The hook reverts the branch switch.

**Step 5: Commit**

```bash
cd ~/agents/orchestrator/workaxle-core
git add lefthook.yml
git commit -m "fix: make branch-lock hook ignore file checkouts, remove destructive reset"
```

---

### Task 2: Replace `git checkout` in the justfile template

**Files:**
- Modify: `/Users/patrick/Projects/spawn/templates/justfile:124`
- Modify: `/Users/patrick/Projects/spawn/templates/justfile:580`

**Step 1: Fix db-structure-reset (line 124)**

Replace:
```
    git checkout main -- db/structure.sql
```
With:
```
    git show main:db/structure.sql > db/structure.sql
```

**Step 2: Fix file restore in skip-worktree logic (line 580)**

Replace:
```
                    git checkout HEAD -- "$file" 2>/dev/null || {
```
With:
```
                    git show "HEAD:$file" > "$file" 2>/dev/null || {
```

**Step 3: Check for the same pattern in the spawn justfile itself**

File: `/Users/patrick/Projects/spawn/justfile:155`

Replace:
```
                    git checkout HEAD -- "$file" 2>/dev/null || {
```
With:
```
                    git show "HEAD:$file" > "$file" 2>/dev/null || {
```

**Step 4: Run a syntax check on the justfile template**

Run:
```bash
cd /Users/patrick/Projects/spawn && just --list
```
Expected: All recipes listed without parse errors.

**Step 5: Commit**

```bash
cd /Users/patrick/Projects/spawn
git add templates/justfile justfile
git commit -m "fix: replace git checkout with git show to avoid triggering post-checkout hooks"
```

---

### Task 3: Update the live justfile in orchestrator

**Files:**
- Modify: `/Users/patrick/agents/orchestrator/workaxle-core/justfile:263`

**Step 1: Fix db-structure-reset (line 263)**

Replace:
```
    git checkout {{BRANCH}} -- db/structure.sql
```
With:
```
    git show {{BRANCH}}:db/structure.sql > db/structure.sql
```

**Step 2: Search for any other `git checkout` calls in the live justfile**

Run:
```bash
grep -n 'git checkout' ~/agents/orchestrator/workaxle-core/justfile
```
Expected: No matches.

**Step 3: Verify the justfile parses correctly**

Run:
```bash
cd ~/agents/orchestrator/workaxle-core && just --list
```
Expected: All recipes listed without parse errors.

**Step 4: Test the full provisioning flow**

Run:
```bash
cd ~/agents/orchestrator/workaxle-core && just provision
```
Expected: Provisioning completes without branch-lock hook firing. No "ERROR: Branch locked" in output. All provisioned files remain intact.

**Step 5: Commit**

```bash
cd ~/agents/orchestrator/workaxle-core
git add justfile
git commit -m "fix: replace git checkout with git show in db-structure-reset"
```

---

### Task 4: Update branch-lock rule documentation

**Files:**
- Modify: `/Users/patrick/Projects/ruly/rules/workaxle/core/essential/branch-lock.md`
- Modify: `/Users/patrick/Projects/ruly/rules/workaxle/orchestrator/essential/branch-lock.md`

**Step 1: Update core branch-lock rule**

Replace the full content (after frontmatter) with:

```markdown
# Branch Lock

The main agent directory (`~/agents/core/`) is locked to the `main` branch. A `post-checkout` lefthook reverts any branch switch automatically.

The hook distinguishes between branch switches and file-level checkouts:
- **Branch switches** (`git checkout feature-branch`) — blocked and reverted to `main`
- **File checkouts** (`git checkout main -- db/structure.sql`) — allowed, since they don't change the branch

**Never run `git checkout <branch>` or `git switch` in the main agent directory.** Always use worktrees for feature work — they provide full isolation without affecting the parent.

If you need to work on a branch, use `EnterWorktree` or `git worktree add`.
```

**Step 2: Update orchestrator branch-lock rule**

Replace the full content (after frontmatter) with:

```markdown
# Orchestrator Submodule Branch Lock

Each service repository inside `~/agents/orchestrator/` is locked to the `main` branch via a `post-checkout` lefthook. Any branch switch is automatically reverted.

The hook distinguishes between branch switches and file-level checkouts:
- **Branch switches** (`git checkout feature-branch`) — blocked and reverted to `main`
- **File checkouts** (`git checkout main -- db/structure.sql`) — allowed, since they don't change the branch

**Locked repositories:**
- `workaxle-core/`
- `workaxle-desktop/`
- `workaxle-gateway/`
- `workaxle-user-svc/`
- `workaxle-group-svc/`
- `workaxle-company-svc/`
- `audit-svc/`
- `integration-svc/`

**Never run `git checkout <branch>` or `git switch` inside these directories.** Always use worktrees for feature work — they provide full isolation without affecting the parent.

If you need to work on a branch, use `EnterWorktree` or `git worktree add` from within the target submodule directory.
```

**Step 3: Commit**

```bash
cd /Users/patrick/Projects/ruly
git add rules/workaxle/core/essential/branch-lock.md rules/workaxle/orchestrator/essential/branch-lock.md
git commit -m "docs: update branch-lock rules to document file checkout exception"
```

---

### Task 5: Propagate the lefthook fix to other agent directories

The branch-lock `lefthook.yml` may also exist in other agent directories. Check and update them.

**Step 1: Find all branch-lock lefthook files**

Run:
```bash
grep -rl "LOCKED_BRANCH" ~/agents/*/lefthook.yml ~/agents/*/*/lefthook.yml 2>/dev/null
```

**Step 2: For each file found, apply the same fix from Task 1**

Replace the hook content with the smarter version that checks `{3}` and uses `LEFTHOOK=0 git checkout` instead of `git reset --hard`.

**Step 3: Run `lefthook install` in each updated directory**

**Step 4: Commit each repo's changes**

---

### Task 6: End-to-end verification

**Step 1: Create a test worktree from the orchestrator**

Run:
```bash
cd ~/agents/orchestrator/workaxle-core && git worktree add .worktrees/test-e2e test-e2e 2>/dev/null || git worktree add .worktrees/test-e2e -b test-e2e
```

**Step 2: Verify parent directory is untouched**

Run:
```bash
cd ~/agents/orchestrator/workaxle-core && git symbolic-ref --short HEAD
```
Expected: `main`

Run:
```bash
ls ~/agents/orchestrator/workaxle-core/docker-compose.merged.yml
```
Expected: File exists (provisioned files intact).

**Step 3: Run provision in parent to confirm no side effects**

Run:
```bash
cd ~/agents/orchestrator/workaxle-core && just provision
```
Expected: Full provision succeeds. No branch-lock errors. All files remain.

**Step 4: Clean up test worktree**

Run:
```bash
cd ~/agents/orchestrator/workaxle-core && git worktree remove .worktrees/test-e2e --force 2>/dev/null; git branch -D test-e2e 2>/dev/null
```

**Step 5: Verify `just --list` still works**

Run:
```bash
cd ~/agents/orchestrator/workaxle-core && just --list
```
Expected: All recipes listed.
