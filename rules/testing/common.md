---
description: Common testing patterns and best practices
globs:
alwaysApply: true
---

# Common Testing Patterns

## Test Organization

### File Structure

```
spec/
├── models/
├── services/
├── controllers/
├── requests/
├── factories/
└── support/
```

## Running Tests

See `@rules/commands.md#testing-commands` for test execution commands.

## Test Writing Principles

### Arrange-Act-Assert Pattern

```ruby
it "does something" do
  # Arrange
  setup_test_data

  # Act
  result = perform_action

  # Assert
  expect(result).to eq(expected)
end
```

### Test Isolation

- Each test should be independent
- Use database transactions for cleanup
- Reset global state between tests

## Common Matchers

### Equality

```ruby
expect(actual).to eq(expected)
expect(actual).to be(expected)  # Object identity
```

### Collections

```ruby
expect(collection).to include(item)
expect(collection).to be_empty
expect(collection).to have(3).items
```

### Exceptions

```ruby
expect { code }.to raise_error(ErrorClass)
expect { code }.not_to raise_error
```

## Factory Patterns

```ruby
# Create persisted record
create(:user)

# Build without saving
build(:user)

# With traits
create(:user, :admin)

# With attributes
create(:user, email: "test@example.com")
```

## Debugging Tests

### Output in Tests

```ruby
puts "Debug: #{variable.inspect}"
pp complex_object  # Pretty print
```

### Running Single Tests

```bash
# Run specific file
bundle exec rspec spec/models/user_spec.rb

# Run specific example
bundle exec rspec spec/models/user_spec.rb:42

# Run with documentation format
bundle exec rspec --format documentation
```

## Performance Considerations

- Use `let` for lazy evaluation
- Use `let!` sparingly (eager evaluation)
- Prefer factories over fixtures
- Mock external services

## Common Pitfalls

- Don't test implementation details
- Avoid testing private methods directly
- Don't over-mock (test behavior, not structure)
- Keep tests focused and small
