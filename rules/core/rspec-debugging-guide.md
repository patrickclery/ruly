---
description:
globs:
alwaysApply: true
---

# RSpec Testing and Debugging Guide

## Common Database Schema Issues

### Column Name Mismatches

When working with [EmployeesSupervisor](/app/models/employees_supervisor.rb):

- **CRITICAL**: Use `delegated_user_id` not `delegated` or `is_delegated`
- Always check the actual database schema in [migrations](/db/migrate) before assuming column names
- The model doesn't have an `is_active` column - use other criteria for filtering active records

For comprehensive debugging patterns, see:

- `@rules/bug/common.md` - Database schema investigation patterns
- `/bug-diagnose` - Command for investigating test failures

## Service Layer Testing

### Method Signature Issues

- Pay attention to method signatures in private methods
- Tests call methods with specific argument counts - ensure they match
- Example: `get_employees_to_delegate(manager_id, filter)` not
  `get_employees_to_delegate(manager_id, filter, company)`

### Authentication Context in Services

- [SupervisorAssignmentFinder](/app/finders/supervisor_assignment_finder.rb) requires full user
  authentication
- For simple queries in services, prefer direct model queries: `EmployeesSupervisor.where(...)`
- Avoid using finders that expect authenticated user context in background services

## RPC Controller Testing

### Authentication Setup

- Use `authenticated_user: true` context for tests that need authentication
- Set `let(:authenticated_user) { user }` to provide the authenticated user
- Unauthenticated tests should NOT have the `authenticated_user` context

## Key Files for RPC Testing

- Controller:
  [app/controllers/gruf/grpc/supervisor_assignment_controller.rb](/app/controllers/gruf/grpc/supervisor_assignment_controller.rb)

## Testing Best Practices

1. Run individual test files: `bundle exec rspec spec/path/to/test_spec.rb:line_number`
2. Use `--format documentation` for detailed test output
3. Check database schema before writing queries
4. Use factory traits for test data setup
5. Test both success and failure paths thoroughly

For detailed test failure investigation, use `/bug-diagnose` command.
