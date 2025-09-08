---
description:
globs:
alwaysApply: true
---

# Testing & Specs - Complete Guide

## 🚀 Spec Execution

## 🧪 Testing Rules

### Running Specs

- Run associated spec file after any code changes
- Verify fixes by re-running specs after making changes to fix failures
- Command format: `make spec T="$TEST_FILES"`
  - `$TEST_FILES` is the relative path from root
  - Example: `make spec T="spec/models/user_spec.rb"`
  - Whenever the specs pass, run `make rubocop-git` (without any other params)
  - **Policy Dependencies:** Ensure the `record` passed to the policy in the spec matches what the
    policy method expects (e.g., `Api::V1::ShiftPolicy` expects a `Shift` record).

### Running Failed Examples

- **Toggle Commands:**
  - `FAILED` → Enables running only failed examples
    - Response: "FAILED EXAMPLES ONLY ENABLED"
    - Format: `make spec T="spec_file.rb:line1:line2"`
    - Example: `make spec T="user_spec.rb:123:456"`
  - `RUNALL` → Enables running all examples
    - Response: "RUN ALL EXAMPLES ENABLED"
    - Format: `make spec T="spec_file.rb"`

### Running Tests

- **Command**: `make spec T="$TEST_FILES"` where `$TEST_FILES` is relative path from root
- **Example**: `make spec T="spec/models/user_spec.rb"`
- **After Passing**: Always run `make rubocop-git` (never `make rubocop`)

### Failed Examples Control

- **Failed Only**: Use `FAILED` toggle to run only failed examples with line numbers
- **Run All**: Use `RUNALL` toggle to run all examples

### Focused Testing

```bash
# Target specific line numbers
make spec T="spec/policies/api/v1/some_policy_spec.rb:123"

# Filter by test description
make spec T="spec/policies/api/v1/some_policy_spec.rb" -e "supervisor"
```

## 📁 Test Organization

### Test Structure

- **Acceptance Tests**: [spec/acceptance/](/spec/acceptance) - End-to-end API testing
- **Unit Tests**: Organized by component type (models, services, operations, etc.)
- **Use `example` blocks** instead of `it` blocks

## 🔧 gRPC Protobuf Helpers

### Using Values Helpers

Always use [lib/grpc/helpers/values.rb](/lib/grpc/helpers/values.rb) helpers instead of manually
constructing protobuf objects:

```ruby
# ✅ Correct - Use daterange_value helper
let(:effective_dates_proto) do
  daterange_value(Date.current + 5.days..Date.current + 35.days)
end

# ❌ Wrong - Manual protobuf construction
let(:effective_dates_proto) do
  Common::DateRange.new({
    end: Google::Type::Date.new({
      day: (Date.current + 35.days).day,
      month: (Date.current + 35.days).month,
      year: (Date.current + 35.days).year
    }),
    start: Google::Type::Date.new({
      day: (Date.current + 5.days).day,
      month: (Date.current + 5.days).month,
      year: (Date.current + 5.days).year
    })
  })
end

# ❌ Wrong - Unnecessary wrapping
let(:effective_dates_proto) do
  Common::DateRange.new(daterange_value(range))
end
```

### Available Helper Methods

Include `Grpc::Helpers::Values` in your RPC specs to access:

- **`daterange_value(range)`**: Converts Ruby range to protobuf DateRange
- **`date_value(date)`**: Converts Date to protobuf Google::Type::Date
- **`timestamp_value(time)`**: Converts Time to protobuf Timestamp
- **`time_of_day_value(time)`**: Converts Time to protobuf TimeOfDay
- **`struct_value(hash)`**: Converts Hash to protobuf Struct

### Pattern for RPC Specs

```ruby
RSpec.describe Grpc::SomeController, type: :controller do
  include Grpc::Helpers::Values  # Include the helpers

  let(:request_proto) do
    Svc::Core::SomeRequest.new(
      # Use helpers directly, no manual wrapping needed
      period: daterange_value(start_date..end_date),
      created_at: timestamp_value(Time.current),
      filter_ids: { in: [1, 2, 3] }  # Simple hash for ID filters
    )
  end
end
```

### Benefits of Using Helpers

- **Cleaner Code**: Reduces 10+ lines to 1 line
- **Consistency**: Follows established patterns across the codebase
- **Maintainability**: Changes to protobuf structure only affect helpers
- **Readability**: Intent is clearer with helper names

## 🏭 Factory Patterns

### Company-Scoped Factory Usage

When creating test data that involves companies:

```ruby
# ✅ Correct - Explicit company association
let!(:employee) { create :employee, company: company, user: user }

# ✅ Correct - Avoid creating unintended companies
let!(:job) { create :job, company: company }

# ✅ Critical for cross-company tests
let!(:external_company) { create :company, name: 'External Corp' }
let!(:external_employee) { create :employee, company: external_company }
```

### Cross-Company Testing

Always include tests that verify data isolation between companies:

```ruby
context 'when data exists in an external company' do
  let!(:external_company) { create :company }
  let!(:shared_user) { create :user, :with_profile }
  let!(:company_employee) { create :employee, user: shared_user, company: company }
  let!(:external_employee) { create :employee, user: shared_user, company: external_company }

  example 'does not include data from external company' do
    # Test that only company-scoped data appears
  end
end
```

## 🔐 Policy Testing Patterns

### Basic Policy Spec Structure

Policy specs follow the Pundit testing pattern using the `permissions` helper:

```ruby
RSpec.describe Api::V1::SomePolicy do
  let(:user) { create :user }
  let(:record) { create :some_model }

  permissions :action? do
    it { expect(described_class).not_to permit(user, record) }

    context 'when user has permission' do
      # setup permission scenario
      it { expect(described_class).to permit(user, record) }
    end
  end
end
```

### Supervisor Testing Pattern

For supervisor relationship testing, use this pattern:

```ruby
context 'when user is a supervisor of the employee in a different location' do
  let(:supervisor_user) { create :user }
  let(:supervisor_manager) { create :manager, user: supervisor_user, company:, access_level: Manager::MANAGER_LEVEL }

  # Create employee in different branch than supervisor manages
  let(:employee_branch) { create :branch, company: }
  let(:employee) { create :employee, company:, branch: employee_branch }
  let(:record) { create :model, employee:, branch: employee_branch }

  before do
    # Set up supervision relationship
    employee.add_supervisor(supervisor_manager)
  end

  it { expect(described_class).to permit(supervisor_manager.user, record) }
end
```

### Manager Access Levels

Always specify manager access level in policy tests:

- `Manager::MANAGER_LEVEL` for regular managers
- `Manager::OWNER_LEVEL` for owners
- `Manager::ADMIN_LEVEL` for admins

### Policy Dependencies

Ensure the `record` passed to policies matches what the policy expects:

- `Api::V1::ShiftPolicy` expects a `Shift` record
- Match policy dependencies in spec setup

## 📊 Export & CSV Testing

When testing exports, verify:

- Correct row counts (`parsed_csv.size`)
- Expected data presence/absence
- Cross-company data isolation
- Proper column indexing (account for all columns including gender, etc.)

```ruby
# Example CSV testing pattern
example 'exports correct data' do
  response = action.call(params)
  parsed_csv = CSV.parse(response.body, headers: true)

  expect(parsed_csv.size).to eq(expected_count)
  expect(parsed_csv.first['column_name']).to eq(expected_value)
end
```

## 🔄 Service & Job Testing

### Service Object Testing

```ruby
RSpec.describe SomeService do
  let(:service) { described_class.new }

  describe '#call' do
    subject { service.call(params) }

    context 'when successful' do
      it { is_expected.to be_success }

      it 'returns expected result' do
        expect(subject.success).to eq(expected_result)
      end
    end

    context 'when failure' do
      it { is_expected.to be_failure }

      it 'returns error message' do
        expect(subject.failure).to eq(expected_error)
      end
    end
  end
end
```

### Background Job Testing

```ruby
RSpec.describe SomeJob do
  describe '#perform' do
    let(:job_params) { { param1: 'value1' } }

    it 'processes successfully' do
      expect { described_class.new.perform(job_params) }.not_to raise_error
    end

    it 'calls expected services' do
      expect_any_instance_of(SomeService).to receive(:call)
      described_class.new.perform(job_params)
    end
  end
end
```

## 🎯 Best Practices

### General Guidelines

- Use `example` blocks instead of `it` blocks
- Always test cross-company data isolation
- Include supervisor relationship testing for policies
- Test both success and failure scenarios for services
- Use explicit factory associations with `company:` parameter
- Run `make rubocop-git` after specs pass

### Supervisor Testing Requirements

- Use `employee.add_supervisor(manager)` to create effective relationships
- Test cross-location supervisor scenarios
- Verify effective dating on supervisor relationships
- Include supervision checks in policy authorization tests
