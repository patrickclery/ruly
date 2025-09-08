---
description: Sequel ORM patterns and best practices for Ruby applications
globs:
  - '**/*.rb'
  - '**/Gemfile'
  - 'db/**/*'
alwaysApply: true
---

# Sequel Database Patterns & Best Practices

## 🗄️ Core Principles

This guide covers **Sequel ORM** patterns that can be applied to any Ruby project using Sequel
instead of ActiveRecord.

Key principles:

- 🔍 Use explicit table and column names in WHERE queries
- 📊 Use `dataset.where` for debugging to include soft-deleted records
- 🔄 Use `dataset.in_batches` for batch processing
- ✅ Use `!model_record.new?` instead of `model_record.persisted?`
- ✅ Use `model_dataset.present?` instead of `model_dataset.exists?`

## 🔍 Query Best Practices

### Explicit Table and Column Names

Always use explicit table and column names in Sequel WHERE queries:

```ruby
# ✅ Good - Explicit table and column references
where(Sequel[:table][:column] => value)
join(Sequel[:table], {id: :table_id})

# ❌ Bad - Implicit column references
where(column: value)
join(:table, id: :table_id)
```

### Multi-Tenant Data Scoping

When dealing with multi-tenant applications:

```ruby
# ✅ Correct - Scoped queries
Model.where(Sequel[:models][:tenant_id] => tenant.id)
```

### Postgres Date Range Queries

Working with PostgreSQL daterange columns:

```ruby
# ✅ Correct syntax for daterange overlap
where(Sequel[:table][:daterange_column].pg_range.contains(Sequel.cast(Date.current, :date)))

# Examples with effective_dates columns
dataset.where(
  Sequel[:records][:effective_dates].pg_range.contains(
    Sequel.cast(specific_date, :date)
  )
)
```

### Dataset Access Patterns

```ruby
# Access related records via dataset methods
model.associations_dataset.where(active: true)
model.related_dataset.where(date: Date.current)
```

## 🔄 Batch Processing

### Iteration Through Large Datasets

Use `.in_batches` extension for memory-efficient processing:

```ruby
# ✅ Good - Memory efficient batch processing
dataset.in_batches do |batch|
  # Process batch
end

# ✅ Good - With custom batch size
dataset.in_batches(of: 100) do |batch|
  # Process batch
end

# ❌ Bad - Loads all records into memory
dataset.all.each do |record|
  # Don't do this for large datasets
end
```

## ⚙️ Sequel Extensions & Plugins

### Extension Configuration

Configure Sequel extensions in your application setup:

```ruby
# Database extensions
Sequel::Model.db.extension :pg_json
Sequel::Model.db.extension :pg_array
Sequel::Model.db.extension :pg_range

# Model plugins
Sequel::Model.plugin :timestamps
Sequel::Model.plugin :validation_helpers
```

### Custom Extensions

Create custom extensions in `lib/sequel/extensions/`:

```ruby
# lib/sequel/extensions/in_batches.rb
module Sequel
  module Extensions
    module InBatches
      # Custom batch processing implementation
    end
  end
end
```

## 🛠️ Debugging Patterns

### Always Use Dataset Methods

When debugging, **always use dataset methods** to see all records including soft-deleted:

```ruby
# ✅ Good - shows all records including soft-deleted
Employee.dataset.where(code: '123')
employee.branches_dataset.all
employee.supervisors_dataset.where(id: manager.id).exists?

# ❌ Avoid - may miss soft-deleted records
Employee.where(code: '123')
employee.branches
employee.supervisors.include?(manager)
```

### SQL Query Visualization

For readable SQL output during debugging:

```ruby
# Pretty print SQL queries
dataset = Employee.dataset.where(active: true)
puts dataset.sql

# With formatting (requires niceql gem)
puts Niceql::Prettifier.prettify_sql(dataset.sql)

# Log all query execution
DB.loggers << Logger.new($stdout)

# Check query plan
DB.run("EXPLAIN ANALYZE #{dataset.sql}")
```

### Dataset Debugging

```ruby
# Inspect dataset without executing
dataset = Model.where(condition: value)
puts "SQL: #{dataset.sql}"
puts "Count: #{dataset.count}"

# Check for soft-deleted records
puts "Including deleted: #{dataset.count}"
puts "Active only: #{dataset.where(deleted_at: nil).count}"
puts "Soft-deleted: #{dataset.exclude(deleted_at: nil).count}"

# Find orphaned records
orphaned = Model.left_join(:related_table, id: :related_id)
                .where(Sequel[:related_table][:id] => nil)
puts "Orphaned records: #{orphaned.count}"
```

### Common Investigation Queries

```ruby
# Count inconsistencies
Model.where(condition).count

# Audit trail analysis
Model.where(updated_at: 1.day.ago..Time.current)
     .order(:updated_at)
     .select(:id, :updated_at, :updated_by)

# Find duplicates
Model.group(:field)
     .having { count.function.* > 1 }
     .select(:field, Sequel.function(:count, :*).as(:count))

# Check data integrity
Model.dataset
     .join(:related, id: :related_id)
     .where(Sequel[:related][:status] => nil)
```

### Database Schema Investigation

```ruby
# Check actual column names in database
DB.schema(:table_name).each do |column, info|
  puts "#{column}: #{info[:db_type]}"
end

# Check indexes
DB.indexes(:table_name).each do |name, details|
  puts "#{name}: #{details[:columns]}"
end

# Verify foreign key constraints
DB.foreign_key_list(:table_name).each do |fk|
  puts "#{fk[:columns]} -> #{fk[:table]}.#{fk[:key]}"
end
```

## 📋 Common Patterns

### Soft Deletion

Implement soft deletion patterns:

```ruby
# Model plugin for soft deletion
module Sequel
  module Plugins
    module SoftDelete
      module DatasetMethods
        def not_deleted
          where(deleted_at: nil)
        end

        def deleted
          exclude(deleted_at: nil)
        end
      end
    end
  end
end

# Usage
Model.dataset.not_deleted
Model.dataset.deleted
```

### Time-based Queries

For models with effective dating:

```ruby
# Current effective records
Model.dataset.where do
  (effective_from <= Date.current) &
  ((effective_to >= Date.current) | (effective_to =~ nil))
end

# Specific date checks
Model.dataset.where(
  Sequel[:models][:effective_dates].pg_range.contains(
    Sequel.cast(specific_date, :date)
  )
)
```

### Complex Conditions

```ruby
# Use Sequel expressions for complex conditions
dataset.where(
  Sequel.&(
    Sequel[:models][:status] => 'active',
    Sequel[:models][:created_at] > 1.month.ago
  )
)

# OR conditions
dataset.where(
  Sequel.|({status: 'active'}, {priority: 'high'})
)
```

### Association Patterns

```ruby
# Explicit dataset queries for better control
model.associations_dataset
  .where(Sequel[:associations][:date] >= Date.current)
  .order(:date)

# Eager loading to prevent N+1
Model.eager(:association).where(condition: value)
```

## 🔒 Security Best Practices

- Always use parameterized queries (Sequel handles this automatically)
- Scope queries appropriately in multi-tenant applications
- Use dataset-level filtering over in-memory filtering for performance
- Be explicit about table joins and conditions

## 🧪 Testing with Sequel

### Test Data Setup

```ruby
# Transaction rollback for test isolation
around(:each) do |example|
  DB.transaction(rollback: :always, savepoint: true) do
    example.run
  end
end
```

### Factory Patterns

```ruby
# Ensure factories respect Sequel patterns
FactoryBot.define do
  factory :model do
    # Use Sequel model creation
    to_create { |instance| instance.save }
  end
end
```

### Dataset Testing

```ruby
# Test dataset methods
expect(Model.dataset.not_deleted.count).to eq(5)
expect(Model.dataset.deleted.count).to eq(2)

# Verify SQL generation
expect(Model.where(field: value).sql).to include('WHERE')
```

## 💡 Performance Tips

1. **Use `select` to limit columns**: `Model.select(:id, :name)`
2. **Prefer `exists?` checks**: `dataset.where(condition).exists?`
3. **Use `limit` for single record**: `dataset.first` instead of `dataset.all[0]`
4. **Batch updates**: `Model.where(condition).update(field: value)`
5. **Use prepared statements** for frequently executed queries

## 🔗 Common Gotchas

1. **Association vs Dataset**: Use `_dataset` suffix for query building
2. **Validation**: Sequel validations run on `save`, not `valid?`
3. **Callbacks**: Different callback names than ActiveRecord
4. **Primary Keys**: Explicitly set if not using `id`
5. **JSON columns**: Require explicit casting in some databases
