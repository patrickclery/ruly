---
description: Diagnose bugs through read-only investigation without making any fixes
alwaysApply: true
---

# Bug Diagnosis Command

## Overview

The `/bug:diagnose` command performs a thorough **read-only** investigation of bugs to identify root causes without making any database modifications.

**IMPORTANT**: This command is for investigation ONLY. No fixes will be applied. See `/bug:fix` command for applying fixes after diagnosis.

For detailed patterns and principles, see `@rules/bug/common.md`.

## Usage

```
/bug:diagnose [TICKET-ID] [ISSUE-DESCRIPTION]
```

## Investigation Process

### Step 1: Create Debug Script

Create a debug script in the `debug/` folder named after the Jira ticket:

```ruby
# debug/[TICKET-ID].rb
puts "=== [TICKET-ID] Debug Script ==="

# Your debugging code here
```

Run with: `make rails-r T=debug/[TICKET-ID].rb`

### Step 2: Identify the Problem

Use **read-only** queries to understand the issue:

```ruby
# Identify affected records
affected_records = Model.dataset.where(condition).all
puts "Affected records: #{affected_records.count}"

# Check for data inconsistencies
puts "Checking data integrity..."
```

### Step 3: Scope the Impact

Determine how widespread the issue is:

```ruby
# Count affected records by type/status
by_status = affected_records.group_by(&:status)
by_status.each do |status, records|
  puts "#{status}: #{records.count} records"
end

# Check related tables for cascade effects
related_affected = RelatedModel.where(model_id: affected_records.map(&:id))
puts "Related records affected: #{related_affected.count}"
```

### Step 4: Timeline Analysis

Determine when the issue occurred:

```ruby
# Find when corruption started
first_corrupted = affected_records.min_by(&:created_at)
last_corrupted = affected_records.max_by(&:created_at)

puts "First occurrence: #{first_corrupted.created_at}"
puts "Last occurrence: #{last_corrupted.created_at}"

# Check for system events around that time
puts "Checking deployments, migrations, or system changes..."
```

### Step 5: Root Cause Analysis

Identify what caused the issue:

```ruby
# Correlate with user actions
user_actions = UserActivity.where(
  created_at: first_corrupted.created_at..last_corrupted.created_at
)

# Check for code changes
puts "Recent code changes that might be related:"
# Review git history for relevant files

# Look for patterns
common_attributes = affected_records.map(&:attributes).reduce(:&)
puts "Common attributes: #{common_attributes}"
```

### Step 6: Generate Diagnosis Report

Output a comprehensive diagnosis:

```ruby
puts "=== DIAGNOSIS REPORT ==="
puts "Ticket: [TICKET-ID]"
puts "Issue: [Clear description of the problem]"
puts ""
puts "SCOPE:"
puts "- Affected records: #{affected_records.count}"
puts "- First occurrence: #{first_corrupted.created_at}"
puts "- Last occurrence: #{last_corrupted.created_at}"
puts ""
puts "ROOT CAUSE:"
puts "[Your analysis of what caused the issue]"
puts ""
puts "IMPACT:"
puts "- [List of impacts on the system]"
puts ""
puts "PREVENTION:"
puts "- [How to prevent this in the future]"
puts ""
puts "PROPOSED FIX:"
puts "[Description of the fix that would resolve this]"
puts "NOTE: Run /bug-fix to apply the fix after approval"
```

## Special Debugging Scenarios

### Database Schema Issues

When encountering column errors:

```ruby
# Check actual table structure
puts "Table columns:"
puts Model.columns.map(&:name).join(", ")

# Verify expected vs actual schema
expected_columns = %w[id name status created_at updated_at]
missing = expected_columns - Model.columns.map(&:name)
puts "Missing columns: #{missing}" if missing.any?
```

### Authorization/Policy Issues

See `@rules/bug/common.md` for policy debugging patterns.

### Supervisor Relationships

See `@rules/bug/common.md` for supervisor relationship debugging.

### Test Failures

For RSpec failures:

```ruby
# Identify test data setup issues
test_user = User.find_by(auth_id: 'test_auth_id')
puts "Test user exists: #{test_user.present?}"
puts "Test user attributes: #{test_user.attributes}" if test_user

# Check factory definitions match schema
puts "Factory attributes vs actual columns comparison..."
```

## Output Requirements

The diagnosis must include:

1. **Clear Problem Statement** - What is broken?
2. **Scope Assessment** - How many records/users affected?
3. **Timeline** - When did it start/stop?
4. **Root Cause** - Why did it happen?
5. **Impact Analysis** - What are the consequences?
6. **Prevention Strategy** - How to avoid recurrence?
7. **Fix Proposal** - What needs to be done? (But don't do it!)

## Important Reminders

- 🚫 **NO DATABASE MODIFICATIONS** during diagnosis
- 📖 Use **dataset methods** for Sequel queries (see `@rules/bug/common.md`)
- 🔍 Always investigate **root cause**, not just symptoms
- 📊 Provide **quantitative data** in your diagnosis
- 💡 Propose fix but **WAIT FOR APPROVAL** before implementing

## Next Steps

After diagnosis is complete and approved:

```
/bug-fix [TICKET-ID]
```

This will implement the proposed fix from the diagnosis.
