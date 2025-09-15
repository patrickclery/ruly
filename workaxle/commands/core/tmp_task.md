---
description: Create a temporary rake task with operation, spec, and proper options
globs:
alwaysApply: false
---

# /tmp-task Command

Create a temporary rake task for data fixes, audits, or cleanup tasks with dry-run mode, silent mode, and company filtering.

## Quick Start

```
/tmp-task delete_orphaned_records "Remove orphaned records from the database"
```

## Core Pattern

### 1. Operation (`app/operations/tmp/[task_name]_operation.rb`)

```ruby
module Tmp
  # rubocop:disable Rails/Output
  class [TaskName]Operation
    include Dry::Monads[:result]

    def call(company_ids: nil, fix: false, silent: false)
      @silent = silent
      @fix = fix

      affected_records = find_affected_records(company_ids)

      return Success(processed: 0, found: 0) if affected_records.empty?

      processed_count = process_affected_records(affected_records)

      Success(processed: processed_count, found: affected_records.count)
    end

    private

    def find_affected_records(company_ids = nil)
      query = Model.dataset.where(deleted_at: nil)

      if company_ids
        query = query.where(company_id: Array(company_ids))
      end

      query.all
    end

    def process_affected_records(affected_records)
      affected_records.count do |record|
        if @fix
          record.update(field: new_value)
          true
        else
          false
        end
      end
    end
  end
  # rubocop:enable Rails/Output
end
```

### 2. Rake Task (`lib/tasks/tmp/[task_name].rake`)

```ruby
namespace :tmp do
  desc '[TASK DESCRIPTION]'
  task [task_name]: :environment do
    company_ids = if ENV['COMPANY_IDS']
                    ENV['COMPANY_IDS'].split(',').map(&:to_i)
                  elsif ENV['COMPANY_ID']
                    [ENV['COMPANY_ID'].to_i]
                  end

    result = Tmp::[TaskName]Operation.new.call(
      fix: ENV['FIX'] == 'true',
      company_ids:,
      silent: ENV['SILENT'] == 'true'
    )

    if result.success?
      puts "Found: #{result.success[:found]} | Processed: #{result.success[:processed]}" unless ENV['SILENT'] == 'true'
    else
      puts "Task failed: #{result.failure}" unless ENV['SILENT'] == 'true'
      exit 1
    end
  end
end
```

### 3. Spec (`spec/operations/tmp/[task_name]_operation_spec.rb`)

```ruby
RSpec.describe Tmp::[TaskName]Operation do
  let(:operation) { described_class.new }
  let(:company) { create(:company) }

  describe '#call' do
    context 'in dry run mode' do
      subject { operation.call(fix: false, silent: true) }

      it 'does not modify records' do
        expect { subject }.not_to change { record.reload.field }
      end
    end

    context 'when applying fixes' do
      subject { operation.call(fix: true, silent: true) }

      it 'modifies records' do
        expect { subject }.to change { record.reload.field }
      end
    end

    context 'with company filter' do
      subject { operation.call(fix: true, company_ids: [company.id], silent: true) }

      it 'only processes records in specified company' do
        # test implementation
      end
    end
  end
end
```

## Usage

```bash
# Dry run (see what would be changed)
bundle exec rake tmp:[task_name] FIX=false

# Apply changes
bundle exec rake tmp:[task_name] FIX=true

# Silent mode
bundle exec rake tmp:[task_name] FIX=true SILENT=true

# Company filtering
bundle exec rake tmp:[task_name] FIX=true COMPANY_IDS=1,2,3
```

## Key Requirements

- **Operation Interface**: `call(company_ids: nil, fix: false, silent: false)`
- **Return Value**: `Success(processed: count, found: total)` or variant like `Success(deleted: count, found: total)`
- **Dataset Methods**: Use `.dataset` for Sequel queries to handle soft-deleted records
- **Company Filtering**: Pass `nil` for all companies, array of IDs for specific companies
- **Output Control**: Respect `@silent` flag for output suppression
- **No Data Changes in Dry Run**: Check `@fix` flag before any updates