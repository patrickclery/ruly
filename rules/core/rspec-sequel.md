---
description:
globs:
alwaysApply: true
---

# RSpec Testing with Sequel - Comprehensive Guide

## 🗄️ Core Testing Principles

This project uses **Sequel**, not ActiveRecord. All database testing should follow Sequel patterns
with special attention to soft-deleted records.

### Critical Testing Rule: Always Include Deleted Records in Test Scaffolds

When testing operations that return multiple records, **ALWAYS** create deleted records in your test
scaffold to ensure they are properly excluded from results.

```ruby
# ✅ CORRECT - Include deleted records in test setup
RSpec.describe SomeOperation do
  let!(:company) { create :company }
  let!(:active_record) { create :some_model, company: company }
  let!(:deleted_record) { create :some_model, company: company, deleted_at: Time.current }
  let!(:external_company_record) { create :some_model, company: create(:company) }

  example 'returns only active records from correct company' do
    result = operation.call(company: company)
    expect(result.success.count).to eq(1)
    expect(result.success).to include(active_record)
    expect(result.success).not_to include(deleted_record)
    expect(result.success).not_to include(external_company_record)
  end
end

# ❌ WRONG - Missing deleted records test
RSpec.describe SomeOperation do
  let!(:active_record) { create :some_model }

  example 'returns records' do
    result = operation.call
    expect(result.success).to include(active_record)
    # This test doesn't verify deleted records are excluded!
  end
end
```

## 🔍 Query Testing Patterns

### Dataset vs Model Methods

Always test that operations use `.dataset` methods to properly handle soft-deleted records:

```ruby
# Test that operations use proper dataset methods
example 'uses dataset methods to exclude deleted records' do
  # Create both active and deleted records
  let!(:active_employee) { create :employee, company: company }
  let!(:deleted_employee) { create :employee, company: company, deleted_at: Time.current }

  result = operation.call(company: company)

  # Verify only active records are returned
  expect(result.success).to include(active_employee)
  expect(result.success).not_to include(deleted_employee)
end
```

### Company Scoping Tests

Always include cross-company tests to verify proper data isolation:

```ruby
context 'when data exists in multiple companies' do
  let!(:company_a) { create :company }
  let!(:company_b) { create :company }
  let!(:record_a) { create :some_model, company: company_a }
  let!(:record_b) { create :some_model, company: company_b }
  let!(:deleted_record_a) { create :some_model, company: company_a, deleted_at: Time.current }

  example 'returns only active records from specified company' do
    result = operation.call(company: company_a)

    expect(result.success).to include(record_a)
    expect(result.success).not_to include(record_b)
    expect(result.success).not_to include(deleted_record_a)
  end
end
```

## 🏭 Factory Usage Patterns

### Company-Scoped Factories

Always explicitly specify company associations:

```ruby
# ✅ Correct - Explicit company association
let!(:employee) { create :employee, company: company }
let!(:deleted_employee) { create :employee, company: company, deleted_at: Time.current }

# ❌ Wrong - Implicit company creation
let!(:employee) { create :employee }
```

### User-Company Relationships

Remember that [User](/app/models/user.rb) doesn't have direct company association:

```ruby
# ✅ Correct - User through Employee/Manager
let!(:user) { create :user }
let!(:employee) { create :employee, user: user, company: company }

# ❌ Wrong - User factory doesn't accept company
let!(:user) { create :user, company: company }
```

## 🔐 Policy Testing with Deleted Records

Policy tests must include deleted records to ensure authorization works correctly:

```ruby
RSpec.describe Api::V1::SomePolicy do
  let(:company) { create :company }
  let(:user) { create :user }
  let(:manager) { create :manager, user: user, company: company }
  let!(:active_record) { create :some_model, company: company }
  let!(:deleted_record) { create :some_model, company: company, deleted_at: Time.current }

  permissions :index? do
    context 'when user has access' do
      before { setup_permissions }

      example 'permits access to active records only' do
        expect(described_class).to permit(user, active_record)
        expect(described_class).not_to permit(user, deleted_record)
      end
    end
  end
end
```

## 🧪 Service & Operation Testing

### Standard Test Structure for Multi-Record Operations

```ruby
RSpec.describe SomeService do
  let(:service) { described_class.new }
  let!(:company) { create :company }

  # ALWAYS include these test records:
  let!(:active_record_1) { create :some_model, company: company, name: 'Active 1' }
  let!(:active_record_2) { create :some_model, company: company, name: 'Active 2' }
  let!(:deleted_record) { create :some_model, company: company, name: 'Deleted', deleted_at: Time.current }
  let!(:external_record) { create :some_model, company: create(:company), name: 'External' }

  describe '#call' do
    subject { service.call(company: company) }

    example 'returns only active records from specified company' do
      expect(subject).to be_success

      result_records = subject.success
      expect(result_records.count).to eq(2)
      expect(result_records).to include(active_record_1, active_record_2)
      expect(result_records).not_to include(deleted_record, external_record)
    end

    context 'when all records are deleted' do
      before do
        active_record_1.update(deleted_at: Time.current)
        active_record_2.update(deleted_at: Time.current)
      end

      example 'returns empty result' do
        expect(subject).to be_success
        expect(subject.success).to be_empty
      end
    end
  end
end
```

## 🔄 Supervisor Relationship Testing

For supervisor-related tests, always include effective dating and deletion scenarios:

```ruby
context 'supervisor relationships with deleted records' do
  let!(:supervisor_manager) { create :manager, company: company }
  let!(:employee) { create :employee, company: company }
  let!(:active_supervision) { create :employees_supervisor, employee: employee, manager: supervisor_manager }
  let!(:deleted_supervision) { create :employees_supervisor, employee: employee, manager: supervisor_manager, deleted_at: Time.current }

  example 'only considers active supervision relationships' do
    result = operation.call(supervisor: supervisor_manager)

    # Verify only employees with active supervision are included
    expect(result.success).to include(employee)

    # Verify the query excludes deleted supervision records
    expect(employee.supervisors_dataset.not_deleted.count).to eq(1)
    expect(employee.supervisors_dataset.count).to eq(2) # includes deleted
  end
end
```

## 📊 Export & CSV Testing

When testing exports, verify deleted records are excluded:

```ruby
example 'exports only active records' do
  # Setup: active and deleted records
  let!(:active_employee) { create :employee, company: company, code: 'ACTIVE001' }
  let!(:deleted_employee) { create :employee, company: company, code: 'DELETED001', deleted_at: Time.current }

  response = action.call(company_id: company.id)
  parsed_csv = CSV.parse(response.body, headers: true)

  expect(parsed_csv.size).to eq(1)
  expect(parsed_csv.first['code']).to eq('ACTIVE001')

  # Verify deleted employee is not in export
  codes = parsed_csv.map { |row| row['code'] }
  expect(codes).not_to include('DELETED001')
end
```

## 🐛 Debugging Test Failures

### Test Data Persistence for Investigation

When tests fail due to Sequel object mismatches:

```ruby
# Add to .env.test.local temporarily
PERSIST_TEST_DATA=true

# Then investigate with psql
# psql test_db -c "SELECT id, name, deleted_at FROM some_models WHERE company_id = X;"

# Remove PERSIST_TEST_DATA after debugging
```

### Common Debugging Patterns

```ruby
# Debug dataset queries in specs
let(:debug_query) do
  SomeModel.dataset
    .where(company_id: company.id)
    .tap { |ds| puts "SQL: #{ds.sql}" }
    .tap { |ds| puts "Count: #{ds.count}" }
    .tap { |ds| puts "Not deleted count: #{ds.not_deleted.count}" }
end
```

## 🎯 Best Practices Checklist

### For Every Multi-Record Operation Test:

- [ ] Create active records for the target company
- [ ] Create deleted records for the target company
- [ ] Create records for external companies
- [ ] Verify only active records from target company are returned
- [ ] Test edge case where all records are deleted
- [ ] Include supervisor relationship tests if applicable
- [ ] Test cross-company data isolation

### For Policy Tests:

- [ ] Test authorization against both active and deleted records
- [ ] Verify deleted records are not accessible
- [ ] Include supervisor relationship scenarios
- [ ] Test cross-company access restrictions

### For Export Tests:

- [ ] Verify deleted records are excluded from exports
- [ ] Test with mixed active/deleted data
- [ ] Verify correct row counts
- [ ] Check cross-company data isolation

## 🔗 Related Files

- [EmployeesSupervisor Model](/app/models/employees_supervisor.rb) - Soft deletion patterns
- [BulkDelegateSupervisorsOperation](/app/operations/employees/bulk_delegate_supervisors_operation.rb) -
  Example of proper `.not_deleted` usage
- [User Model](/app/models/user.rb) - User-company relationship patterns
- [Employee Model](/app/models/employee.rb) - Company scoping examples

## 💡 Key Takeaways

1. **Always include deleted records in test scaffolds** - This is the most critical rule
2. **Test company data isolation** - Multi-tenant applications require this
3. **Use explicit company associations** - Don't rely on implicit factory behavior
4. **Verify `.not_deleted` usage** - Operations should exclude soft-deleted records
5. **Test edge cases** - What happens when all records are deleted?
6. **Debug with dataset queries** - Use Sequel's dataset methods for investigation
