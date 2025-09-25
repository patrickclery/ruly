---
description: Specify required tests that must always run during pre-commit
alwaysApply: true
requires:
  - ../../../commands.md
---

# Test Require Command

## Overview

The `/testing:require` command allows you to specify a list of test files that MUST be run every time `/testing:pre-commit` is called, regardless of what files have changed. This ensures critical tests always pass before committing.

## Usage

```
/testing:require [test_file1] [test_file2] [test_file3] ...
```

### Examples

```bash
# Require specific test files
/testing:require spec/actions/api/v1/companies/users/destroy_action_spec.rb spec/policies/api/v1/companies/user_policy_spec.rb spec/acceptance/api/v1/companies/users_spec.rb

# Add additional tests to the list
/testing:require spec/models/user_spec.rb spec/services/auth_service_spec.rb

# Clear all required tests
/testing:require --clear
```

## How It Works

### Step 1: Store Required Tests

When you run `/testing:require`, the specified test files are stored in a `tmp/required-tests` file:

```bash
# Manage required tests using the extracted script
.ruly/bin/testing/manage-required-tests.sh add $TEST_FILES
```

_See `.ruly/bin/testing/manage-required-tests.sh` for implementation details._

### Step 2: Integration with Pre-Commit

The `/testing:pre-commit` command automatically checks for required tests:

```bash
# Load required tests using the extracted script
source .ruly/bin/testing/load-required-tests.sh
```

_See `.ruly/bin/testing/load-required-tests.sh` for implementation details._

### Step 3: Run Required Tests

Required tests are ALWAYS run, even if their files haven't changed:

```bash
# Run required tests using the extracted script
.ruly/bin/testing/run-required-tests.sh
```

_See `.ruly/bin/testing/run-required-tests.sh` for implementation details._

## Managing Required Tests

### List Current Required Tests

```bash
# List current required tests using the extracted script
.ruly/bin/testing/manage-required-tests.sh list
```

_See `.ruly/bin/testing/manage-required-tests.sh` for implementation details._

### Add Tests to Required List

```bash
# Add new tests using the extracted script
.ruly/bin/testing/manage-required-tests.sh add $NEW_TESTS
```

_See `.ruly/bin/testing/manage-required-tests.sh` for implementation details._

### Remove Tests from Required List

```bash
# Remove test using the extracted script
.ruly/bin/testing/manage-required-tests.sh remove $TEST_TO_REMOVE
```

_See `.ruly/bin/testing/manage-required-tests.sh` for implementation details._

### Clear All Required Tests

```bash
# Clear all tests using the extracted script
.ruly/bin/testing/manage-required-tests.sh clear
```

_See `.ruly/bin/testing/manage-required-tests.sh` for implementation details._

## File Format

The `tmp/required-tests` file contains one test file path per line:

```
spec/actions/api/v1/companies/users/destroy_action_spec.rb
spec/policies/api/v1/companies/user_policy_spec.rb
spec/acceptance/api/v1/companies/users_spec.rb
spec/models/user_spec.rb
spec/services/auth_service_spec.rb
```

## Git Integration

### Should tmp/required-tests be committed?

**No, never commit tmp/required-tests to the repository.**

This file is for local development workflow only and should always be added to `.gitignore`:

```bash
# Add to .gitignore (if not already present)
echo "tmp/required-tests" >> .gitignore
```

**Why keep it local?**

- Each developer may have different critical tests they want to ensure pass
- Required tests may vary based on what feature/area someone is working on
- Prevents conflicts between team members' different testing requirements
- Allows personalized workflow without affecting the team

## Implementation Details

### Command Processing

```ruby
# Parse command arguments
def process_test_require(args)
  if args.include?('--clear')
    clear_required_tests
  elsif args.include?('--list')
    list_required_tests
  else
    add_required_tests(args)
  end
end

# Add tests to required list
def add_required_tests(test_files)
  test_files.each do |file|
    if File.exist?(file)
      File.open('tmp/required-tests', 'a') { |f| f.puts(file) }
    else
      puts "Warning: Test file not found: #{file}"
    end
  end

  # Remove duplicates
  tests = File.readlines('tmp/required-tests').map(&:strip).uniq
  File.write('tmp/required-tests', tests.join("\n"))
end
```

### Pre-Commit Integration

The `/testing:pre-commit` command checks for `tmp/required-tests` and includes them:

```bash
#!/bin/bash

# Load required tests
REQUIRED_TESTS=""
if [ -f tmp/required-tests ]; then
  REQUIRED_TESTS=$(cat tmp/required-tests | tr '\n' ' ')
  echo "📋 Found $(wc -l < tmp/required-tests) required tests"
fi

# Run required tests first (they must pass)
if [ -n "$REQUIRED_TESTS" ]; then
  echo "🔒 Running required tests..."
  make spec T="$REQUIRED_TESTS" || exit 1
fi

# Then run tests for changed files
# ... rest of pre-commit logic ...
```

## Best Practices

### When to Require Tests

Require tests for:

- **Critical business logic** that must never break
- **Integration tests** that verify system boundaries
- **Security-related tests** that ensure safe operations
- **API contracts** that external systems depend on
- **Data integrity tests** that prevent corruption

### Performance Considerations

- Keep the required test list focused on critical tests
- Consider test execution time when adding to the list
- Group related tests to leverage shared setup/teardown
- Use parallel test execution when available

### Team Coordination

When working in a team:

1. Discuss which tests should be required team-wide
2. Document why specific tests are required
3. Review the list periodically to remove obsolete tests
4. Consider different lists for different branches (main vs feature)

## Examples

### Example 1: API Endpoint Protection

```bash
# Require all tests for a critical API endpoint
/testing:require \
  spec/controllers/api/v1/payments_controller_spec.rb \
  spec/requests/api/v1/payments_spec.rb \
  spec/integration/payment_processing_spec.rb
```

### Example 2: Policy and Permission Tests

```bash
# Require authorization tests
/testing:require \
  spec/policies/user_policy_spec.rb \
  spec/policies/admin_policy_spec.rb \
  spec/policies/company_policy_spec.rb
```

### Example 3: Data Model Integrity

```bash
# Require model validation tests
/testing:require \
  spec/models/user_spec.rb \
  spec/models/company_spec.rb \
  spec/models/transaction_spec.rb
```

## Troubleshooting

### Tests Not Running

If required tests aren't running:

1. Check `tmp/required-tests` file exists and has correct paths
2. Verify test files exist at specified paths
3. Ensure `/testing:pre-commit` is using the latest version that checks for required tests

### Performance Issues

If required tests slow down commits:

1. Review the list for unnecessary tests
2. Consider running in parallel: `make spec T="$REQUIRED_TESTS" PARALLEL=true`
3. Use focused test runs during development, full runs before push

### Path Issues

Ensure test paths are relative to project root:

- ✅ Good: `spec/models/user_spec.rb`
- ❌ Bad: `/home/user/project/spec/models/user_spec.rb`
- ❌ Bad: `./spec/models/user_spec.rb`
