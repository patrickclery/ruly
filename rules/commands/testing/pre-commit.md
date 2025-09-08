---
description: Run pre-commit checks and fix issues before committing changes
alwaysApply: true
---

# Pre-Commit

## Overview

This command runs a comprehensive set of pre-commit checks to ensure code quality before committing changes. It automatically identifies changed files, runs linting, executes relevant tests, and continues fixing issues until everything passes.

## Process

### Step 1: Load Required Tests

```bash
# Load any required tests that must always run (set by /testing:require command)
REQUIRED_TESTS=""
if [ -f tmp/required-tests ]; then
  REQUIRED_TESTS=$(cat tmp/required-tests | tr '\n' ' ')
  echo "📋 Found $(wc -l < tmp/required-tests) required tests that must pass"
fi
```

### Step 2: Identify Changed Files

```bash
# Get list of files that differ from the base branch
FILES=$(git diff --name-only $(git merge-base HEAD origin/main)..HEAD)

# For Ruby projects, filter to relevant files
RUBY_FILES=$(echo "$FILES" | grep -E '\.(rb|rake|gemspec)$' || true)
SPEC_FILES=$(echo "$FILES" | grep -E '_spec\.rb$' || true)

# Find specs for changed implementation files
IMPLEMENTATION_FILES=$(echo "$FILES" | grep -E '\.rb$' | grep -v '_spec\.rb' || true)
RELATED_SPECS=""
for file in $IMPLEMENTATION_FILES; do
  # Convert lib/foo/bar.rb to spec/foo/bar_spec.rb
  spec_file=$(echo "$file" | sed 's/^lib\//spec\//' | sed 's/\.rb$/_spec.rb/')
  if [ -f "$spec_file" ]; then
    RELATED_SPECS="$RELATED_SPECS $spec_file"
  fi
done
ALL_SPECS="$SPEC_FILES $RELATED_SPECS"
```

### Step 2: Run RuboCop on Changed Files

```bash
# Run rubocop-git to check only changed files
bundle exec rubocop-git

# If there are violations, auto-fix what's possible
if [ $? -ne 0 ]; then
  echo "🔧 Auto-fixing RuboCop violations..."
  bundle exec rubocop-git --auto-correct

  # Check again for remaining violations
  bundle exec rubocop-git
  if [ $? -ne 0 ]; then
    echo "⚠️ Manual fixes required for remaining RuboCop violations"
    # Fix the remaining issues manually
  fi
fi
```

### Step 3: Run Required Tests First

```bash
# Combine required tests with any specs in the git diff
COMBINED_REQUIRED_TESTS="$REQUIRED_TESTS"
if [ -n "$SPEC_FILES" ]; then
  COMBINED_REQUIRED_TESTS="$REQUIRED_TESTS $SPEC_FILES"
  echo "📝 Including $(echo $SPEC_FILES | wc -w) spec files from git diff"
fi

# Run required tests first - these MUST pass
if [ -n "$COMBINED_REQUIRED_TESTS" ]; then
  echo "🔒 Running required tests and modified specs..."
  make spec T="$COMBINED_REQUIRED_TESTS"

  if [ $? -ne 0 ]; then
    echo "❌ Required tests or modified specs failed!"
    echo "These tests must pass before committing:"
    echo "- Required tests from tmp/required-tests"
    echo "- Modified spec files from git diff"
    echo "Fix these tests before proceeding."
    exit 1
  fi
  echo "✅ All required tests and modified specs passed"
fi
```

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
# Final verification run
echo "✅ Running final verification..."

# Ruby
if [ -n "$RUBY_FILES" ]; then
  bundle exec rubocop-git || exit 1
  [ -n "$ALL_SPECS" ] && bundle exec rspec $ALL_SPECS || exit 1
fi

# JavaScript
if [ -n "$JS_FILES" ]; then
  npm run lint -- $JS_FILES || exit 1
  npm test -- --findRelatedTests $JS_FILES || exit 1
fi

# Python
if [ -n "$PY_FILES" ]; then
  flake8 $PY_FILES || exit 1
  pytest $PY_FILES || exit 1
fi

echo "✅ All pre-commit checks passed!"
```

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
