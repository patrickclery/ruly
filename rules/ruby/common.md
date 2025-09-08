---
description: Common Ruby patterns shared across all Ruby files
globs:
  - '**/*.rb'
alwaysApply: true
---

# Common Ruby Patterns

## Code Style

### Line Length

- Keep lines under 120 characters
- Break long method chains into multiple lines

### Variable Naming

```ruby
# ✅ Good - Descriptive names
user_authentication_token = generate_token
employee_monthly_salary = calculate_salary(employee)

# ❌ Bad - Ambiguous names
token = generate_token
sal = calculate_salary(emp)
```

## Early Returns

```ruby
# ✅ Good - Early returns for clarity
def process(user)
  return nil unless user
  return false unless user.active?
  return :limited if user.limited_access?

  perform_action(user)
end
```

## Instance Variables

```ruby
attr_reader :config, :logger

def initialize
  @config = load_config
  @logger = setup_logger
end

def process
  # Use without @ when attr_reader is defined
  logger.info("Processing with #{config}")
end
```

## Memoization

```ruby
def result
  @result ||= begin
    perform_calculation
  end
end

# For nil/false values
def nullable_result
  return @nullable_result if defined?(@nullable_result)
  @nullable_result = compute_nullable
end
```

## Guard Clauses

```ruby
def calculate_discount(user, amount)
  raise ArgumentError, 'User required' unless user
  raise ArgumentError, 'Amount must be positive' unless amount&.positive?

  return 0 unless user.eligible_for_discount?

  amount * discount_rate(user)
end
```

## Constants and Magic Numbers

```ruby
# ✅ Good - Named constants
MAX_REQUESTS_PER_MINUTE = 60
COOLDOWN_PERIOD = 5.minutes
DEFAULT_BURST_SIZE = 10

# ❌ Bad - Magic numbers
if requests_in_window < 60  # What does 60 mean?
```

## Safe Navigation

```ruby
# Use &. for nil safety
user&.profile&.email

# With default values
user&.name || 'Anonymous'
```

## Error Handling

```ruby
def process
  # Business logic
rescue StandardError => e
  Rails.logger.error("Processing failed: #{e.message}")
  raise
end
```
