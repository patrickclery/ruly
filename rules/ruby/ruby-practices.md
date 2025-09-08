---
description: General Ruby development best practices and patterns
globs:
  - '**/*.rb'
  - '**/Gemfile'
  - '**/Rakefile'
alwaysApply: true
---

# Ruby Development Best Practices

## 🎯 Core Principles

This guide covers general Ruby development patterns and best practices applicable to any Ruby
project.

Key principles:

- 💡 Use explicit, descriptive variable names
- 🎨 Follow consistent coding style
- ⚡ Prioritize performance where applicable
- 🔒 Security-first approach
- 🧩 Encourage modular design
- 📊 Replace magic numbers with constants
- 🎯 Consider edge cases
- ✔️ Use assertions to validate assumptions

## 📝 Code Style Guidelines

See `@rules/ruby/common.md` for code style patterns.

### Method Length

Keep methods focused and under 10 lines when possible:

```ruby
# ✅ Good - Single responsibility
def calculate_total(items)
  validate_items(items)
  sum_item_prices(items)
end

private

def validate_items(items)
  raise ArgumentError if items.empty?
end

def sum_item_prices(items)
  items.sum(&:price)
end
```

## 🏗️ Architecture Patterns

### Service Objects

```ruby
class ServiceObject
  def self.call(...)
    new(...).call
  end

  def call
    # Implementation
  end
end

# Usage
ServiceObject.call(params)
```

### Common Patterns

See `@rules/ruby/common.md` for:

- Instance variables and attr_reader usage
- Early returns vs nested conditionals

## 🔒 Security Best Practices

### Input Validation

```ruby
def process_user_input(params)
  # Whitelist parameters
  allowed = params.slice(:name, :email, :age)

  # Validate types
  raise ArgumentError unless allowed[:age].is_a?(Integer)

  # Sanitize strings
  allowed[:name] = sanitize(allowed[:name])

  allowed
end
```

### Safe Navigation

See `@rules/ruby/common.md#safe-navigation`.

### Constant Time Comparisons

```ruby
# For sensitive comparisons (passwords, tokens)
require 'rack/utils'

def secure_compare(a, b)
  Rack::Utils.secure_compare(a.to_s, b.to_s)
end
```

## ⚡ Performance Patterns

See `@rules/ruby/common.md#memoization` for memoization patterns.

### Lazy Evaluation

```ruby
# Use Enumerator::Lazy for large collections
large_collection
  .lazy
  .select { |x| expensive_check(x) }
  .map { |x| transform(x) }
  .first(10)
```

### Symbol vs String Keys

```ruby
# ✅ Prefer symbols for hash keys when possible
config = { timeout: 30, retries: 3 }

# Use strings when keys are dynamic
user_input = { params['key'] => params['value'] }
```

## 🧪 Defensive Programming

### Type Checking

```ruby
def process(items)
  raise ArgumentError, 'items must be an Array' unless items.is_a?(Array)
  raise ArgumentError, 'items cannot be empty' if items.empty?

  items.each do |item|
    validate_item(item)
    process_item(item)
  end
end
```

### Guard Clauses

See `@rules/ruby/common.md#guard-clauses`.

### Assertions

```ruby
def complex_calculation(data)
  # Validate assumptions
  raise 'Unexpected state' unless data[:status] == 'ready'

  result = perform_calculation(data)

  # Post-condition check
  raise 'Invalid result' unless valid_result?(result)

  result
end
```

## 📊 Constants and Magic Numbers

See `@rules/ruby/common.md#constants-and-magic-numbers`.

## 🎯 Edge Case Handling

```ruby
def divide_equally(total, recipients)
  # Handle edge cases explicitly
  return [] if recipients.nil? || recipients.empty?
  return [total] if recipients.size == 1
  return recipients.map { 0 } if total.zero?

  # Handle floating point precision
  share = (total.to_f / recipients.size).round(2)
  shares = Array.new(recipients.size - 1, share)

  # Ensure total is preserved
  last_share = (total - shares.sum).round(2)
  shares << last_share
end
```

## 🧩 Modular Design

### Module Extraction

```ruby
# Extract shared behavior into modules
module Timestampable
  def touch
    self.updated_at = Time.current
    save
  end

  def recently_updated?
    updated_at > 1.hour.ago
  end
end

class User
  include Timestampable
end
```

### Dependency Injection

```ruby
class EmailService
  def initialize(mailer: DefaultMailer.new, logger: Rails.logger)
    @mailer = mailer
    @logger = logger
  end

  def send_email(recipient, subject, body)
    @logger.info("Sending email to #{recipient}")
    @mailer.deliver(recipient, subject, body)
  end
end
```

## 🔧 Debugging Helpers

### Inspection Methods

```ruby
class ComplexObject
  def inspect
    "#<#{self.class.name} id=#{id} status=#{status}>"
  end

  def to_debug
    {
      class: self.class.name,
      id: id,
      attributes: attributes,
      associations: loaded_associations
    }
  end
end
```

### Debug Output

```ruby
def debug_info(label, object)
  return unless Rails.env.development?

  puts "=== #{label} ==="
  puts object.inspect
  puts "=================="
end
```

## 💡 Ruby Idioms

### Tap for Side Effects

```ruby
def create_user(params)
  User.new(params).tap do |user|
    user.generate_auth_token
    user.set_defaults
    user.save!
  end
end
```

### Fetch with Defaults

```ruby
# With default value
config.fetch(:timeout, 30)

# With block for expensive defaults
cache.fetch(:result) { expensive_calculation }
```

### Safe Array/Hash Access

```ruby
# Array
array.dig(0, :nested, :value)

# Hash
hash.fetch(:key, default_value)
hash.fetch(:key) { compute_default }
```

## 🔗 Method Chaining

```ruby
class FluentBuilder
  def initialize
    @config = {}
  end

  def with_timeout(seconds)
    @config[:timeout] = seconds
    self  # Return self for chaining
  end

  def with_retries(count)
    @config[:retries] = count
    self
  end

  def build
    validate_config!
    @config
  end

  private

  def validate_config!
    raise 'Timeout required' unless @config[:timeout]
  end
end

# Usage
config = FluentBuilder.new
  .with_timeout(30)
  .with_retries(3)
  .build
```

## 📚 Documentation Patterns

### Method Documentation

```ruby
# @param user [User] the user to process
# @param options [Hash] processing options
# @option options [Boolean] :async (false) process asynchronously
# @return [Result] the processing result
# @raise [ArgumentError] if user is invalid
def process_user(user, options = {})
  # Implementation
end
```

### TODO Comments

```ruby
# TODO: Optimize this query for large datasets
# FIXME: Handle nil case properly
# NOTE: This is intentionally synchronous for data consistency
```
