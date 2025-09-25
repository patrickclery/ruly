---
description: Run pre-commit checks and fix issues before committing changes
alwaysApply: true
requires:
  - ../../../commands.md
---

# Pre-Commit

## Overview

This command runs a comprehensive set of pre-commit checks to ensure code quality before committing changes. It automatically identifies changed files, runs linting, executes relevant tests, and continues fixing issues until everything passes.

## Process

### Step 1: Load Required Tests

```bash
# Load required tests using the extracted script
source .ruly/bin/testing/load-required-tests.sh
```

_See `.ruly/bin/testing/load-required-tests.sh` for implementation details._

### Step 2: Identify Changed Files

```bash
# Detect changed files using the extracted script
source .ruly/bin/testing/detect-changed-files.sh
```

_See `.ruly/bin/testing/detect-changed-files.sh` for implementation details._

### Step 2: Run RuboCop on Changed Files

```bash
# Run RuboCop with auto-fix using the extracted script
.ruly/bin/testing/run-rubocop.sh
```

_See `.ruly/bin/testing/run-rubocop.sh` for implementation details._

### Step 3: Run Required Tests First

```bash
# Run required tests plus any specs from git diff
.ruly/bin/testing/run-required-tests.sh $SPEC_FILES
```

_See `.ruly/bin/testing/run-required-tests.sh` for implementation details._

### Step 4: Run Tests for Changed Files

```bash
# Run specs for all changed and related files
if [ -n "$ALL_SPECS" ]; then
  echo "🧪 Running specs for changed files..."
  bundle exec rspec $ALL_SPECS

  if [ $? -ne 0 ]; then
    echo "❌ Test failures detected. Fixing..."
    # Analyze failures and fix issues
    # Re-run until all tests pass
  fi
fi

# Also run any integration tests if critical files changed
if echo "$FILES" | grep -qE '(config/|db/|Gemfile)'; then
  echo "🔄 Running full test suite due to critical file changes..."
  bundle exec rspec
fi
```

### Step 5: Additional Language-Specific Checks

#### For JavaScript/TypeScript Projects

```bash
JS_FILES=$(echo "$FILES" | grep -E '\.(js|jsx|ts|tsx)$' || true)
if [ -n "$JS_FILES" ]; then
  # Run ESLint
  npm run lint -- $JS_FILES

  # Run tests for changed files
  npm test -- --findRelatedTests $JS_FILES
fi
```

#### For Python Projects

```bash
PY_FILES=$(echo "$FILES" | grep -E '\.py$' || true)
if [ -n "$PY_FILES" ]; then
  # Run Black formatter
  black $PY_FILES

  # Run Flake8 linter
  flake8 $PY_FILES

  # Run pytest for changed files
  pytest $PY_FILES
fi
```

### Step 6: Verify Everything Passes

```bash
# Run final verification using the extracted script
.ruly/bin/testing/final-verification.sh
```

_See `.ruly/bin/testing/final-verification.sh` for implementation details._

### Step 7: Commit and Push Changes

```bash
# Stage all changes
git add -A

# Create commit with descriptive message
git commit -m "fix: Address linting and test failures

- Fixed RuboCop violations in changed files
- Updated tests to pass with new changes
- Resolved all pre-commit check issues"

# Push to remote
git push
```

## Workflow Loop

The command continues working until all checks pass:

1. **Identify Issues** → Run linters and tests
2. **Fix Issues** → Auto-fix where possible, manual fixes where needed
3. **Verify Fixes** → Re-run checks
4. **Repeat** → Continue until everything passes
5. **Commit** → Stage, commit, and push changes

## Exit Conditions

### Success

- ✅ All RuboCop checks pass
- ✅ All related tests pass
- ✅ No linting errors
- ✅ Changes committed and pushed

### Failure

- ❌ Unable to fix a critical issue
- ❌ Tests reveal fundamental problems
- ❌ Manual intervention required

## Usage

```
/testing:pre-commit
```

This will automatically:

1. Identify all changed files
2. Run appropriate linters and tests
3. Fix issues iteratively
4. Commit and push when everything passes

## Configuration

The command respects project-specific configurations:

- `.rubocop.yml` for Ruby style rules
- `.eslintrc` for JavaScript linting
- `pyproject.toml` or `setup.cfg` for Python tools
- `.prettierrc` for code formatting

## Notes

- The command focuses only on changed files for efficiency
- It includes related test files even if they weren't directly modified
- Auto-fixable issues are corrected automatically
- Manual intervention is requested only when necessary
- The process ensures a clean commit history with passing CI
