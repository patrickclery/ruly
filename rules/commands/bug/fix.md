---
description: Apply approved fixes for diagnosed bugs
alwaysApply: true
---

# Bug Fix Command

## Overview

The `/bug:fix` command applies fixes for bugs that have been diagnosed and approved. This command should only be run AFTER `/bug:diagnose` has been completed and the proposed fix has been approved.

**IMPORTANT**: Always run `/bug:diagnose` first to understand the root cause. Never apply fixes without investigation and approval.

For detailed patterns and principles, see `@rules/bug/common.md`.

## Usage

```
/bug:fix [TICKET-ID]
```

## Pre-Fix Checklist

Before applying any fix, ensure:

- ✅ `/bug:diagnose` has been run for this ticket
- ✅ Root cause has been identified
- ✅ Fix has been proposed and documented
- ✅ User has explicitly approved the fix
- ✅ **Failing test has been written that reproduces the bug**
- ✅ Rollback plan is in place
- ✅ Impact has been assessed

## TDD Workflow Summary

The fix process MUST follow Test-Driven Development (TDD):

1. **RED**: Write a test that reproduces the bug (it should fail)
2. **GREEN**: Implement the fix (make the test pass)
3. **REFACTOR**: Clean up the fix if needed (tests still pass)

This ensures the fix is correct and prevents regression.

## Fix Process

### Step 1: Write a Failing Test (TDD)

**CRITICAL**: Before implementing any fix, FIRST write a test that reproduces the bug. This ensures:

- The bug is properly understood
- The fix actually addresses the issue
- The bug won't recur (regression test)

```ruby
# spec/regressions/[ticket_id]_spec.rb
RSpec.describe "[TICKET-ID] Regression" do
  describe "the bug behavior" do
    it "reproduces the issue" do
      # Set up the conditions that cause the bug
      setup_bug_conditions

      # This should FAIL before the fix
      expect(buggy_behavior).to eq(expected_correct_behavior)
    end
  end

  describe "the fix" do
    it "resolves the issue" do
      # This test should PASS after the fix is implemented
      setup_bug_conditions
      apply_fix_logic

      expect(result).to eq(expected_correct_behavior)
    end
  end
end
```

**Run the test to confirm it FAILS:**

```bash
bundle exec rspec spec/regressions/[ticket_id]_spec.rb
# Should show: 1 example, 1 failure
```

### Step 2: Create Fix Script

After confirming the test fails, create the fix implementation:

```ruby
# debug/[TICKET-ID]-fix.rb
puts "=== [TICKET-ID] Fix Script ==="
puts "Applying approved fix for: [issue description]"
puts ""
puts "This script will:"
puts "1. [First action]"
puts "2. [Second action]"
puts "3. [Third action]"
puts ""
puts "Press Enter to continue or Ctrl+C to abort..."
gets

# Your fix implementation here
```

### Step 3: Implement Fix with Transaction

Always wrap fixes in a transaction for safety:

```ruby
DB.transaction do
  begin
    puts "Starting fix..."

    # Count affected records before fix
    affected_count = Model.where(condition).count
    puts "Records to fix: #{affected_count}"

    # Apply the fix
    fixed_count = 0
    Model.where(condition).each do |record|
      # Apply fix to each record
      record.update(fixed_field: correct_value)
      fixed_count += 1

      # Progress indicator for large datasets
      if fixed_count % 100 == 0
        puts "  Fixed #{fixed_count}/#{affected_count} records..."
      end
    end

    puts "✅ Fixed #{fixed_count} records"

    # Verify the fix
    remaining = Model.where(condition).count
    if remaining == 0
      puts "✅ All issues resolved"
    else
      raise "Fix incomplete: #{remaining} records still affected"
    end

  rescue => e
    puts "❌ Error during fix: #{e.message}"
    puts "Rolling back transaction..."
    raise
  end
end
```

### Step 4: Data Migration Fixes

For structural fixes requiring migrations:

```ruby
# Create a migration file
# db/migrate/[timestamp]_fix_[ticket_id]_[description].rb

class Fix[TicketId][Description] < ActiveRecord::Migration[7.0]
  def up
    # Document the issue being fixed
    say "Fixing [TICKET-ID]: [description]"

    # Apply the fix
    execute <<-SQL
      -- Your SQL fix here
      UPDATE table_name
      SET column = correct_value
      WHERE condition;
    SQL

    # Verify the fix
    affected = execute("SELECT COUNT(*) FROM table_name WHERE bad_condition").first["count"]
    raise "Fix failed: #{affected} bad records remain" if affected > 0
  end

  def down
    # Provide rollback if possible
    say "Rolling back fix for [TICKET-ID]"
    # Rollback logic
  end
end
```

### Step 5: Apply Code Fixes and Verify Tests Pass

For bugs in application code:

```ruby
# 1. Apply the code fix
# Make the minimal change needed to fix the issue
# Follow the fix strategy from your diagnosis

# 2. Run the regression test - it should now PASS
bundle exec rspec spec/regressions/[ticket_id]_spec.rb
# Should show: 1 example, 0 failures

# 3. Run all related tests to ensure no breakage
bundle exec rspec [affected test files]

# 4. If tests still fail, iterate on the fix
# If tests pass, the fix is verified!
```

### Step 6: Prevent Recurrence

Add validations or constraints to prevent future issues:

```ruby
# Add database constraint
add_index :table_name, :column, unique: true, where: "condition"

# Add model validation
class Model < ApplicationRecord
  validate :prevent_data_corruption

  private

  def prevent_data_corruption
    if [condition that caused bug]
      errors.add(:field, "[TICKET-ID]: [validation message]")
    end
  end
end

# Add service-level checks
class Service
  def perform
    raise "[TICKET-ID]: Invalid state" if [problematic condition]
    # ... rest of service
  end
end
```

## Fix Verification

After applying the fix:

```ruby
puts "=== FIX VERIFICATION ==="

# 1. Confirm original issue is resolved
affected = Model.where(original_bad_condition).count
puts "Remaining affected records: #{affected}"
raise "Fix incomplete!" if affected > 0

# 2. Check for side effects
puts "Checking for side effects..."
# Add specific checks based on the fix

# 3. Performance impact
puts "Checking performance..."
# Verify queries still perform acceptably

# 4. Generate verification report
puts ""
puts "=== VERIFICATION REPORT ==="
puts "✅ Original issue resolved"
puts "✅ No side effects detected"
puts "✅ Performance acceptable"
puts "✅ Prevention measures in place"
```

## Rollback Plan

Always include a rollback strategy:

```ruby
# debug/[TICKET-ID]-rollback.rb
puts "=== [TICKET-ID] Rollback Script ==="
puts "This will undo the fix applied for [TICKET-ID]"
puts "Press Enter to continue or Ctrl+C to abort..."
gets

DB.transaction do
  # Rollback logic
  puts "Rolling back changes..."

  # Restore original state
  Model.where(fixed_condition).update(field: original_value)

  puts "✅ Rollback complete"
end
```

## Documentation

After fix is verified:

1. Update ticket with:
   - Root cause explanation
   - Fix applied
   - Verification results
   - Prevention measures added

2. Document in code:

   ```ruby
   # Fixed [TICKET-ID]: [brief description]
   # Root cause: [explanation]
   # Fix: [what was done]
   ```

3. Add to knowledge base if applicable

## Post-Fix Monitoring

Set up monitoring for the fixed issue:

```ruby
# Create monitoring script
# debug/[TICKET-ID]-monitor.rb

puts "=== Monitoring [TICKET-ID] Fix ==="

# Check if issue has recurred
problematic = Model.where(bad_condition).count
if problematic > 0
  puts "⚠️ WARNING: Issue may have recurred!"
  puts "Found #{problematic} problematic records"
else
  puts "✅ No recurrence detected"
end

# Check prevention measures are working
# ... monitoring logic ...
```

## Important Reminders

- 🧪 **ALWAYS write failing test FIRST** (TDD)
- 🔒 Always use **transactions** for data fixes
- ✅ Ensure test **passes** after fix implementation
- 🔄 Include **rollback** plan
- 📝 **Document** the fix thoroughly
- 🛡️ Add **prevention** measures
- 📊 **Verify** fix effectiveness
- 🔍 **Monitor** for recurrence

## Success Criteria

A successful fix must:

1. Resolve the original issue completely
2. Not introduce new problems
3. Include prevention measures
4. Be documented properly
5. Have a rollback plan
6. Pass all verification checks
