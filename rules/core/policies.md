---
description: Policy and authorization debugging patterns
globs:
alwaysApply: true
---

# Policy & Authorization Debugging

## Policy Testing Patterns

When debugging authorization issues, test the policy directly to understand what's happening:

```ruby
# Create test data
user = User.find_by(auth_id: 'test_user')
record = SomeModel.find(123)

# Test policy directly
policy = SomePolicy.new(user, record)
puts "Can update?: #{policy.update?}"
puts "Can destroy?: #{policy.destroy?}"
puts "Can create?: #{policy.create?}"

# Debug specific policy methods
puts "Is admin?: #{policy.admin_or_owner?}"
puts "Is owner?: #{policy.owner?}"
puts "Has permission?: #{policy.has_permission?}"
```

## User Permission Debugging

### Branch and Location Permissions

```ruby
user = User.find_by(auth_id: 'user_auth_id')
branch = Branch.find(branch_id)

# Check management permissions
puts "Can manage branch?: #{user.allow_to_manage?(branch: branch)}"
puts "Can manage location?: #{user.allow_to_manage?(location: branch.location)}"

# Check specific role permissions
puts "Is admin?: #{user.admin?}"
puts "Is manager?: #{user.manager?}"
puts "Has role?: #{user.has_role?('specific_role')}"
```

### Employee Supervision

```ruby
# Check if user supervises an employee
employee = Employee.find_by(code: 'emp123')
manager = Manager.find_by(user: User.find_by(auth_id: 'mgr123'))

puts "Supervises employee?: #{user.supervises?(employee)}"
puts "Is supervisor?: #{employee.supervisors.include?(manager)}"

# Check supervision relationships
puts "Supervisor exists?: #{employee.supervisors_dataset.where(id: manager.id).exists?}"
puts "Effective supervisor?: #{employee.supervisors_dataset.effective.where(id: manager.id).exists?}"

# Check supervision date ranges
supervision = employee.supervisors_dataset.where(id: manager.id).first
if supervision
  puts "Supervision period: #{supervision.effective_dates}"
  puts "Currently active?: #{supervision.effective_dates.include?(Date.current)}"
end
```

## Debugging Authorization Failures

### Step-by-Step Policy Debugging

```ruby
# When a policy check fails, break it down:
policy = SomePolicy.new(user, record)

# 1. Check basic user attributes
puts "User ID: #{user.id}"
puts "User auth_id: #{user.auth_id}"
puts "User roles: #{user.roles.map(&:name).join(', ')}"

# 2. Check record ownership
puts "Record owner: #{record.user_id}"
puts "User owns record?: #{record.user_id == user.id}"

# 3. Check organizational hierarchy
puts "User branch: #{user.branch&.name}"
puts "Record branch: #{record.branch&.name}"
puts "Same branch?: #{user.branch_id == record.branch_id}"

# 4. Check specific permissions
puts "Admin?: #{user.admin?}"
puts "Can manage branch?: #{user.allow_to_manage?(branch: record.branch)}"

# 5. Test the final policy result
puts "Policy allows update?: #{policy.update?}"
```

### Common Authorization Issues

1. **Soft-deleted associations**: Use dataset methods to include soft-deleted records

```ruby
# Check including soft-deleted supervisors
employee.supervisors_dataset.where(id: manager.id).exists?
```

2. **Date range issues**: Check effective dates

```ruby
# Verify date ranges overlap
supervision.effective_dates.include?(Date.current)
```

3. **Role hierarchy**: Verify role inheritance

```ruby
# Check all roles including inherited
user.all_roles.map(&:name)
```

## Testing Policies in Specs

```ruby
RSpec.describe SomePolicy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:record) { create(:some_model, user: user) }

  permissions :update? do
    it 'allows owner to update' do
      expect(subject).to permit(user, record)
    end

    it 'prevents other users from updating' do
      expect(subject).not_to permit(other_user, record)
    end

    it 'allows admin to update any record' do
      expect(subject).to permit(admin, record)
    end
  end
end
```

## Quick Reference

- Always test policies directly when debugging authorization
- Check user roles and permissions separately from policy logic
- Verify supervision relationships including effective dates
- Use dataset methods to include soft-deleted records
- Break down complex policy checks into individual components
- Test both positive and negative cases
