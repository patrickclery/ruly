---
description: Common patterns and principles for bug investigation and fixing
globs:
alwaysApply: true
---

# Common Bug Investigation and Fix Patterns

## Core Principles

### 1. Read-Only Investigation First

- **NEVER** make database modifications to fix bugs during investigation
- Use only read-only methods (SELECT queries, `.where()`, `.first`, `.count`, etc.)
- Create debug scripts that analyze and report on data state without changing it

### 2. Investigation Before Fix

- Always investigate the **root cause** of data corruption/inconsistency
- Understand **how** the corruption occurred, not just what is corrupted
- Look for patterns, timing, related changes, or system events that caused the issue

### 3. Propose and Wait for Approval

- If a database fix is needed, **propose the solution and STOP**
- Wait for explicit user approval before making any database changes
- Document the proposed fix clearly with expected impact

## Investigation Methodology

### For Data Integrity Issues

1. **Identify the inconsistency** - What data is out of sync?
2. **Scope the problem** - How many records are affected?
3. **Timeline analysis** - When did the corruption occur?
4. **Root cause analysis** - What process/code caused the corruption?
5. **Prevention strategy** - How to prevent future occurrences?

## Specialized Debugging

For detailed debugging patterns, see:

- **Sequel Debugging**: `@rules/ruby/sequel.md#debugging-patterns`
- **Policy & Authorization**: `@rules/core/policies.md`
- **Complete Workflow**: `@rules/core/debugging.md`

## What NOT to Do

- ❌ Create/update/delete records during investigation
- ❌ Run data migrations or fixes without approval
- ❌ Assume the fix without understanding the cause
- ❌ Skip investigation and jump to "quick fixes"

## Debug Scripts

For complete debug script guidelines, naming conventions, and examples, see:
→ `@rules/core/debugging.md#debug-scripts`

## Testing and Debugging

### RSpec Best Practices

1. Run individual test files: `bundle exec rspec spec/path/to/test_spec.rb:line_number`
2. Use `--format documentation` for detailed test output
3. Check database schema before writing queries
4. Use factory traits for test data setup
5. Test both success and failure paths thoroughly

### Common Error Patterns

- `PG::InFailedSqlTransaction` indicates a previous error in the transaction
- Fix the root cause (usually column name issues) to resolve subsequent transaction errors
- Pay attention to method signatures in private methods
- Tests call methods with specific argument counts - ensure they match

### Service Layer Testing

- For simple queries in services, prefer direct model queries: `Model.where(...)`
- Avoid using finders that expect authenticated user context in background services
- Use `authenticated_user: true` context for tests that need authentication
