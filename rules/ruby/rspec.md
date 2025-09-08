---
description: RSpec testing patterns and best practices for Ruby applications
globs:
  - '**/spec/**/*.rb'
  - '**/*_spec.rb'
alwaysApply: true
---

# RSpec Testing Best Practices

## 🧪 Core Testing Principles

This guide covers RSpec testing patterns applicable to any Ruby project, with special attention to
Sequel ORM patterns when relevant.

Key principles:

- Test both success and failure scenarios
- Include edge cases in test scaffolds
- Use explicit test data setup
- Prefer `example` blocks over `it` blocks
- Always test data isolation in multi-tenant apps

## 📁 Test Organization

### Directory Structure

```
spec/
├── models/          # Model specs
├── services/        # Service object specs
├── operations/      # Operation specs
├── controllers/     # Controller specs
├── requests/        # Request/integration specs
├── factories/       # Factory definitions
├── support/         # Shared contexts, helpers
└── spec_helper.rb   # RSpec configuration
```

### Basic Spec Structure

```ruby
RSpec.describe SomeClass do
  # Use example instead of it
  example 'does something' do
    expect(subject).to eq(expected)
  end

  # Group related tests
  describe '#method_name' do
    subject { instance.method_name(params) }

    context 'when condition is true' do
      let(:params) { { condition: true } }

      example 'returns expected result' do
        expect(subject).to eq(expected)
      end
    end
  end
end
```

## 🏭 Factory Patterns

### FactoryBot Setup

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { Faker::Name.name }

    trait :admin do
      role { 'admin' }
    end

    trait :with_profile do
      after(:create) do |user|
        create(:profile, user: user)
      end
    end
  end
end
```

### Factory Usage

```ruby
# Create vs Build
let(:user) { create(:user) }          # Persisted to database
let(:new_user) { build(:user) }       # Not persisted

# With traits
let(:admin) { create(:user, :admin) }

# With associations
let(:user_with_profile) { create(:user, :with_profile) }

# Override attributes
let(:custom_user) { create(:user, email: 'custom@example.com') }
```

## 🔍 Testing Patterns

### Subject and Let

```ruby
RSpec.describe UserService do
  subject { described_class.new.call(params) }

  let(:params) { { user_id: user.id } }
  let(:user) { create(:user) }

  # Use let! for setup that must run before examples
  let!(:prerequisite) { create(:required_record) }
end
```

### Shared Examples

```ruby
# spec/support/shared_examples/authenticatable.rb
RSpec.shared_examples 'authenticatable' do
  example 'requires authentication' do
    subject.authenticate_user!
    expect(subject.authenticated?).to be true
  end
end

# Using shared examples
RSpec.describe User do
  it_behaves_like 'authenticatable'
end
```

### Shared Contexts

```ruby
# spec/support/shared_contexts/authenticated_user.rb
RSpec.shared_context 'authenticated user' do
  let(:current_user) { create(:user) }

  before do
    allow(controller).to receive(:current_user).and_return(current_user)
  end
end

# Using shared context
RSpec.describe SomeController do
  include_context 'authenticated user'
end
```

## 🎯 Service & Operation Testing

### Basic Service Testing

```ruby
RSpec.describe UserService do
  let(:service) { described_class.new }

  describe '#call' do
    subject { service.call(params) }

    let(:params) { { user_id: user.id } }
    let(:user) { create(:user) }

    context 'when successful' do
      example 'returns success' do
        expect(subject).to be_success
        expect(subject.value).to eq(expected_result)
      end
    end

    context 'when user not found' do
      let(:params) { { user_id: 0 } }

      example 'returns failure' do
        expect(subject).to be_failure
        expect(subject.error).to eq(:not_found)
      end
    end
  end
end
```

### Testing with Monads

```ruby
RSpec.describe Operations::CreateUser do
  describe '#call' do
    subject { described_class.new.call(params) }

    context 'with valid params' do
      let(:params) { { email: 'test@example.com' } }

      it { is_expected.to be_success }

      example 'creates user' do
        expect { subject }.to change(User, :count).by(1)
      end

      example 'returns user' do
        expect(subject.success).to be_a(User)
        expect(subject.success.email).to eq('test@example.com')
      end
    end

    context 'with invalid params' do
      let(:params) { { email: nil } }

      it { is_expected.to be_failure }

      example 'returns validation errors' do
        expect(subject.failure).to include(:validation_error)
      end
    end
  end
end
```

## 🗄️ Database Testing with Sequel

### Transaction Rollback

```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  config.around(:each) do |example|
    DB.transaction(rollback: :always, savepoint: true) do
      example.run
    end
  end
end
```

### Testing Soft Deletion

```ruby
RSpec.describe SomeModel do
  let!(:active_record) { create(:model) }
  let!(:deleted_record) { create(:model, deleted_at: Time.current) }

  describe '.active' do
    subject { described_class.active }

    example 'excludes deleted records' do
      expect(subject).to include(active_record)
      expect(subject).not_to include(deleted_record)
    end
  end

  describe '#soft_delete' do
    example 'sets deleted_at timestamp' do
      expect { active_record.soft_delete }
        .to change { active_record.deleted_at }
        .from(nil)
        .to(be_within(1.second).of(Time.current))
    end
  end
end
```

### Multi-Tenant Testing

```ruby
context 'with multi-tenant data' do
  let!(:tenant_a) { create(:tenant) }
  let!(:tenant_b) { create(:tenant) }
  let!(:record_a) { create(:model, tenant: tenant_a) }
  let!(:record_b) { create(:model, tenant: tenant_b) }

  example 'isolates data by tenant' do
    result = described_class.for_tenant(tenant_a)

    expect(result).to include(record_a)
    expect(result).not_to include(record_b)
  end
end
```

## 🎮 Controller Testing

### Request Specs (Preferred)

```ruby
RSpec.describe 'Users API', type: :request do
  describe 'GET /users/:id' do
    let(:user) { create(:user) }

    before { get "/users/#{user.id}" }

    example 'returns success' do
      expect(response).to have_http_status(:ok)
    end

    example 'returns user data' do
      json = JSON.parse(response.body)
      expect(json['id']).to eq(user.id)
    end
  end

  describe 'POST /users' do
    let(:valid_params) { { user: { email: 'new@example.com' } } }

    example 'creates user' do
      expect {
        post '/users', params: valid_params
      }.to change(User, :count).by(1)
    end
  end
end
```

## 🔐 Testing Authorization

### Pundit Policy Testing

```ruby
RSpec.describe UserPolicy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  permissions :show? do
    example 'allows user to view themselves' do
      expect(subject).to permit(user, user)
    end

    example 'prevents viewing other users' do
      expect(subject).not_to permit(user, other_user)
    end

    example 'allows admin to view any user' do
      expect(subject).to permit(admin, other_user)
    end
  end
end
```

## 🕐 Time-Dependent Testing

### Freezing Time

```ruby
# Using timecop or Rails time helpers
describe 'time-dependent behavior' do
  around do |example|
    freeze_time { example.run }
  end

  example 'uses frozen time' do
    record = create(:model)
    expect(record.created_at).to eq(Time.current)
  end
end

# Travel to specific time
example 'expires after 30 days' do
  travel_to(31.days.from_now) do
    expect(record).to be_expired
  end
end
```

## 📊 Testing CSV/Export

```ruby
describe 'CSV export' do
  let(:users) { create_list(:user, 3) }

  subject { UserExporter.new.to_csv }

  example 'includes headers' do
    csv = CSV.parse(subject, headers: true)
    expect(csv.headers).to include('Email', 'Name')
  end

  example 'includes all users' do
    csv = CSV.parse(subject, headers: true)
    expect(csv.size).to eq(users.size)

    emails = csv.map { |row| row['Email'] }
    expect(emails).to match_array(users.map(&:email))
  end
end
```

## 🎭 Mocking and Stubbing

### Basic Mocking

```ruby
describe 'external service interaction' do
  let(:api_client) { instance_double(ApiClient) }

  before do
    allow(ApiClient).to receive(:new).and_return(api_client)
    allow(api_client).to receive(:fetch_data).and_return({ status: 'ok' })
  end

  example 'calls external API' do
    expect(api_client).to receive(:fetch_data).with(user_id: 123)

    service.sync_user(123)
  end
end
```

### Stubbing Constants

```ruby
describe 'with stubbed constant' do
  stub_const('ENV', ENV.to_h.merge('FEATURE_FLAG' => 'true'))

  example 'uses stubbed value' do
    expect(ENV['FEATURE_FLAG']).to eq('true')
  end
end
```

## 🚀 Performance Testing

```ruby
describe 'performance' do
  example 'completes within time limit' do
    expect {
      service.process_large_dataset
    }.to perform_under(100).ms
  end

  example 'has acceptable memory usage' do
    expect {
      service.process_large_dataset
    }.to perform_allocation(10000).objects
  end
end
```

## 🎯 Matchers

### Custom Matchers

```ruby
# spec/support/matchers/be_valid_email.rb
RSpec::Matchers.define :be_valid_email do
  match do |actual|
    actual =~ /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
  end
end

# Usage
expect('user@example.com').to be_valid_email
```

### Collection Matchers

```ruby
expect(collection).to all(be_a(User))
expect(collection).to include(user1, user2)
expect(collection).to match_array([user1, user2, user3])
expect(collection).to contain_exactly(1, 2, 3)
```

## 💡 Best Practices

1. **Test Behavior, Not Implementation**

```ruby
# ✅ Good - Tests behavior
example 'sends welcome email' do
  expect { service.register_user(params) }
    .to change { ActionMailer::Base.deliveries.count }.by(1)
end

# ❌ Bad - Tests implementation
example 'calls send_email method' do
  expect(service).to receive(:send_email)
  service.register_user(params)
end
```

2. **Use Descriptive Test Names**

```ruby
# ✅ Good
example 'returns error when email is already taken'

# ❌ Bad
example 'test email validation'
```

3. **Keep Tests Independent**

```ruby
# ✅ Good - Each test sets up its own data
describe 'user creation' do
  example 'creates user' do
    user = create(:user)
    expect(user).to be_persisted
  end
end

# ❌ Bad - Tests depend on order
before(:all) { @user = create(:user) }
```

4. **Test Edge Cases**

```ruby
describe '#divide' do
  example 'handles division by zero' do
    expect { calculator.divide(10, 0) }
      .to raise_error(ZeroDivisionError)
  end

  example 'handles nil inputs' do
    expect(calculator.divide(nil, 5)).to eq(0)
  end
end
```

## 🔧 Configuration

### RSpec Configuration

```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!

  config.order = :random
  Kernel.srand config.seed
end
```
