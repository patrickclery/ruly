---
description: Monad patterns using dry-monads in Ruby applications
globs:
  - '**/*.rb'
  - '**/services/**'
  - '**/operations/**'
  - '**/actions/**'
alwaysApply: true
---

# Monad Patterns with dry-monads

## 🎯 Core Principles

This guide covers monad patterns using the `dry-monads` gem for functional error handling in Ruby
applications.

Key principles:

- Service objects should return Result monads (Success/Failure)
- Use monads for explicit error handling
- Use `do` notation for clean, readable operation chains
- Service/operation classes must initialize with no params for dry-container compatibility

## 📦 Basic Setup

### Including Monads

```ruby
class MyOperation
  # noinspection RubyResolve (for RubyMine compatibility)
  include Dry::Monads[:result, :maybe, :do]

  def call(params)
    # Operation logic
  end
end
```

## 🚂 Do Notation - The Recommended Approach

### Using Do Notation

```ruby
class CreateUserOperation
  include Dry::Monads[:result, :do]

  def call(params)
    # Do notation automatically unwraps Success values
    # When a Failure is yielded, the method returns immediately with that Failure
    validated_params = yield validate(params)
    user = yield create_user(validated_params)
    yield send_welcome_email(user)

    Success(user)
  end

  private

  def validate(params)
    if params[:email].present?
      Success(params)
    else
      Failure(:invalid_params)
    end
  end

  def create_user(params)
    user = User.create(params)
    if user.persisted?
      Success(user)
    else
      Failure(user.errors)
    end
  end

  def send_welcome_email(user)
    # Email logic
    Success(user)
  rescue => e
    Failure([:email_error, e.message])
  end
end
```

## 🔗 Dependency Injection with Monads

### With dry-container

```ruby
class MyOperation
  include Dry::Monads[:result, :do]
  include App::Import[
    user_service: 'services.users.update',
    email_service: 'services.email.sender'
  ]

  def call(params)
    user = yield user_service.call(params)
    yield email_service.call(user)

    Success(user)
  end
end
```

### Service Initialization Pattern

```ruby
# ✅ Correct - No params in initializer for dry-container
class UserService
  include Dry::Monads[:result]

  def initialize
    # No parameters here
  end

  def call(user_id:)
    # Service logic
  end
end

# ❌ Wrong - Parameters in initializer break dry-container
class UserService
  def initialize(dependency)
    @dependency = dependency
  end
end
```

## 🎭 Maybe Monad Usage

### Handling Nil Values with Do Notation

```ruby
class FindUserOperation
  include Dry::Monads[:maybe, :result, :do]

  def call(user_id)
    user = User.find_by(id: user_id)

    if user
      update_last_seen(user)
      Success(user)
    else
      Failure(:user_not_found)
    end
  end

  private

  def update_last_seen(user)
    user.update(last_seen_at: Time.current)
    user
  end
end
```

### Simple Maybe Usage

```ruby
def get_user_email(user_id)
  user = User.find_by(id: user_id)
  user&.profile&.email || 'no-email@example.com'
end
```

## 🔀 Pattern Matching

### Case Statements with Monads

```ruby
def handle_result(operation_result)
  case operation_result
  in Success(user)
    render json: user
  in Failure(:not_found)
    render status: 404
  in Failure(errors)
    render json: { errors: errors }, status: 422
  end
end
```

### Simple Result Handling

```ruby
result = operation.call(params)

if result.success?
  handle_success(result.value!)
else
  handle_failure(result.failure)
end
```

## 🏭 Service Object Patterns

### Standard Service Structure

```ruby
class MyService
  include Dry::Monads[:result, :do]

  def call(params)
    # Always return Success or Failure
    valid_params = yield validate_params(params)
    result = yield perform_action(valid_params)

    Success(result)
  end

  private

  def validate_params(params)
    # Validation logic
    Success(params)
  end

  def perform_action(params)
    # Business logic
    Success(result)
  rescue StandardError => e
    Failure([:error, e.message])
  end
end
```

### Instance Variable Pattern

See `@rules/ruby/common.md#instance-variables` for instance variable patterns in services.

## 🧪 Testing Monads

### RSpec Matchers

```ruby
RSpec.describe MyService do
  let(:service) { described_class.new }

  describe '#call' do
    subject { service.call(params) }

    context 'when successful' do
      let(:params) { { valid: true } }

      it { is_expected.to be_success }

      it 'returns expected value' do
        expect(subject.success).to eq(expected_value)
      end
    end

    context 'when failure' do
      let(:params) { { valid: false } }

      it { is_expected.to be_failure }

      it 'returns error' do
        expect(subject.failure).to eq(:validation_error)
      end
    end
  end
end
```

### Testing Monad Chains

```ruby
it 'chains operations correctly' do
  allow(validator).to receive(:call).and_return(Success(valid_data))
  allow(processor).to receive(:call).and_return(Success(processed_data))

  result = service.call(params)

  expect(result).to be_success
  expect(result.success).to eq(processed_data)
end
```

## 🎯 Best Practices

### Early Returns

See `@rules/ruby/common.md#early-returns` for early return patterns. With monads:

```ruby
def call(params)
  return Failure(:invalid) unless valid?(params)
  return Failure(:unauthorized) unless authorized?

  Success(process(params))
end
```

### Consistent Error Types

Use symbols or structured errors:

```ruby
# ✅ Good - Consistent error structure
Failure([:validation_error, { field: :email, message: 'invalid' }])

# ❌ Bad - Inconsistent error types
Failure('Something went wrong')
```

### Don't Mix Return Types

Always return monads:

```ruby
# ✅ Good
def find_user(id)
  user = User.find_by(id: id)
  user ? Success(user) : Failure(:not_found)
end

# ❌ Bad - Mixed return types
def find_user(id)
  User.find_by(id: id) || Failure(:not_found)
end
```

## 💡 Common Patterns

### Transaction Wrapper

```ruby
def call(params)
  DB.transaction do
    yield create_record(params)
    yield update_related(params)
    Success(:completed)
  end
rescue => e
  Failure([:transaction_failed, e.message])
end
```

### Validation Chain with Do Notation

```ruby
class ValidationService
  include Dry::Monads[:result, :do]

  def call(params)
    params = yield validate_presence(params)
    params = yield validate_format(params)
    params = yield validate_uniqueness(params)
    result = yield process(params)

    Success(result)
  end
end
```

### Error Accumulation

```ruby
def validate_all(params)
  errors = []
  errors << :missing_email unless params[:email]
  errors << :missing_name unless params[:name]

  errors.empty? ? Success(params) : Failure(errors)
end
```

## 🔗 Integration Tips

### Controller Integration

```ruby
def create
  result = MyOperation.new.call(params)

  if result.success?
    render json: result.value!
  else
    render json: { error: result.failure }, status: 422
  end
end
```

### Background Jobs

```ruby
class MyJob
  def perform(params)
    result = MyOperation.new.call(params)

    if result.failure?
      Rails.logger.error("Job failed: #{result.failure}")
      raise StandardError, result.failure
    end
  end
end
```

### Service Composition

```ruby
class CompositeService
  include Dry::Monads[:result, :do]

  def call(params)
    user = yield UserService.new.call(params)
    profile = yield ProfileService.new.call(user: user)
    yield NotificationService.new.call(user: user)

    Success([user, profile])
  end
end
```
