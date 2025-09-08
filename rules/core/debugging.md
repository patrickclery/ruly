---
description: Comprehensive debugging guide and workflow
globs:
alwaysApply: true
---

# Debugging Guide

## 🐛 Bug Investigation Workflow

This guide outlines the complete process for investigating, fixing, and deploying bug fixes.

### Phase 1: Initial Investigation

1. **Analyze the issue** - Fetch Jira ticket details, understand the problem
2. **Create debug script** - Follow naming conventions below
3. **Reproduce locally** - Verify the issue exists
4. **Identify root cause** - Understand what's causing the problem

### Phase 2: Local Environment Setup

⚠️ **CRITICAL: Database Operations Require Confirmation** ⚠️

**NEVER run these commands without explicit user confirmation:**

- `make db-restore-remote` - Imports remote database (20+ minutes)
- `make db-reset` - Resets local database (destructive)
- `make db-drop` - Drops database completely (destructive)
- `make reset` - Full application reset (destructive)

These operations **completely destroy/replace your local database** and cannot be undone.

### Phase 3: Fix Development

1. **Locate problematic code** based on debug findings
2. **Implement minimal fix** following existing patterns
3. **Verify with debug script** - Confirm fix resolves issue
4. **Run tests** - Ensure no regressions

### Phase 4: Testing & Pull Request

1. Run specs: `make spec T="spec/path/to/spec.rb"`
2. Check code style: `make rubocop-git`
3. Create PRs against both main and develop branches
4. Include debug script for verification

## 📝 Debug Scripts

### Naming Convention

Debug scripts must follow this format:

```
WA-XXXX-NN-description.rb
```

Where:

- `WA-XXXX` = Jira ticket number
- `NN` = Incremental number (01, 02, 03...)
- `description` = Brief description

Examples:

- `WA-1234-01-investigate.rb`
- `WA-1234-02-compare-users.rb`
- `WA-1234-03-verify-fix.rb`

### Script Structure

```ruby
#!/usr/bin/env rails runner
# frozen_string_literal: true

puts "=== WA-XXXX Investigation Script ==="
puts "READ-ONLY analysis of [issue description]"
puts "=" * 50

# 1. Identify affected records
affected = Model.where(condition).all
puts "Affected records: #{affected.count}"

# 2. Analyze patterns (read-only)
# ... analysis code ...

# 3. Report findings
puts "=== ROOT CAUSE ANALYSIS ==="
puts "Issue: [description]"
puts "Affected: [count] records"
puts "Likely cause: [analysis]"

# NO DATABASE MODIFICATIONS IN INVESTIGATION SCRIPTS
```

### Running Debug Scripts

```bash
make rails-r T=debug/WA-XXXX-NN-description.rb
```

## 🔍 Specialized Debugging

### Sequel Database Debugging

→ See `@rules/ruby/sequel.md#debugging-patterns`

- Dataset methods for including soft-deleted records
- SQL query visualization
- Schema investigation

### Policy & Authorization Debugging

→ See `@rules/core/policies.md`

- Testing policies directly
- User permission debugging
- Supervisor relationship checks

### RSpec Debugging

→ See `@rules/core/rspec-debugging-guide.md`

- Test isolation techniques
- Database state debugging

### Bug Investigation Principles

→ See `@rules/bug/common.md`

- Read-only investigation methodology
- Root cause analysis patterns

## 🔐 Authentication Debugging

### JWT Token Decoding

```ruby
auth_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

begin
  decoded_token = JWT.decode(auth_token, nil, false).first
  user_id = decoded_token['sub']
  company_id = decoded_token['companyId']

  puts "User ID: #{user_id}"
  puts "Company ID: #{company_id}"
  puts "Token expires: #{Time.at(decoded_token['exp'])}"
rescue => e
  puts "Failed to decode JWT: #{e.message}"
end

# Find user and company from token
user = User.find_by(auth_id: user_id)
company = Company.find(company_id)

puts "User: #{user&.email || 'Not found'}"
puts "Company: #{company&.name || 'Not found'}"
```

## 🌐 gRPC Action Debugging

### Creating gRPC Debug Scripts

```ruby
#!/usr/bin/env rails runner
# frozen_string_literal: true

puts "=== gRPC Action Debug Script ==="
puts "=" * 50

# --- Setup ---
company = Company.find(company_id)
raise "Company not found" if company.nil?

user = User.find_by(auth_id: 'user_auth_id')
raise "User not found" if user.nil?

puts "Company: #{company.name} (ID: #{company.id})"
puts "User: #{user.email} (ID: #{user.id})"

# --- Construct gRPC Request ---
include Grpc::Helpers::Values

request = RequestProtoClass.new(
  # Use gRPC helpers for proper protobuf construction
  date_field: date_value(Date.current),
  date_range_field: daterange_value(start_date..end_date),
  timestamp_field: timestamp_value(Time.current)
)

puts "\nConstructed gRPC Request:"
ap request.to_h

# --- Execute Action ---
action_context = {company: company, user: user}
action_instance = ActionClass.new(context: action_context)

result = action_instance.call(request)

# --- Output Result ---
if result.success?
  puts "\n✅ Action completed successfully:"
  ap result.success.to_h
else
  puts "\n❌ Action failed:"
  ap result.failure
end
```

### gRPC Helper Methods

- `date_value(date)` - Convert Ruby Date to protobuf
- `daterange_value(range)` - Convert date range to protobuf
- `timestamp_value(time)` - Convert Ruby Time to protobuf
- Always include `Grpc::Helpers::Values` module
- Use `{company:, user:}` hash pattern for action context

## 🔧 Quick Reference

### Output Methods

- `ap object` - Use amazing_print for complex objects
- `puts string` - Regular text output
- `puts Niceql::Prettifier.prettify_sql(sql)` - Pretty SQL

### Common Commands

- `make rails-console` - Rails console
- `make rails-r T=script.rb` - Run script
- `make spec T="spec/file_spec.rb"` - Run tests
- `make rubocop-git` - Code style check

### Debug Script Locations

- Store in `debug/` directory
- Use ticket-based naming
- Keep investigation and fix scripts separate
- Document findings in comments

### Database Best Practices

- **NEVER** modify data during investigation
- Always use read-only queries first
- Get approval before any data fixes
- Use dataset methods for Sequel queries

## 📋 Related Commands

- `/bug:diagnose` - Read-only bug investigation command
- `/bug:fix` - Apply approved fixes command
- `/debug:grpc` - Generate gRPC debug scripts from curl
- `/pr:create` - Create pull requests with proper format
