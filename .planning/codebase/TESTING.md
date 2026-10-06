# Testing Patterns

**Analysis Date:** 2025-03-22

## Test Framework

**Runner:**
- RSpec 3.x
- Config: `spec/spec_helper.rb`

**Assertion Library:**
- Built-in RSpec expect syntax
- No external assertion libraries

**Run Commands:**
```bash
bundle exec rspec                 # Run all tests
bundle exec rspec --watch        # Watch mode
bundle exec rspec spec/ruly/cli_spec.rb  # Run specific file
bundle exec rspec --format documentation  # Verbose output
```

## Test File Organization

**Location:**
- Tests co-located with code structure under `spec/` directory
- Mirrors `lib/ruly/` structure exactly
- Example: `lib/ruly/checks/ambiguous_links.rb` → `spec/ruly/checks/ambiguous_links_spec.rb`

**Naming:**
- Files: `{name}_spec.rb`
- One spec file per class/module
- Integration tests in `spec/integration/`

**Structure:**
```
spec/
├── spec_helper.rb              # RSpec configuration
├── integration/
│   └── ruly_cli_spec.rb        # End-to-end CLI tests
└── ruly/
    ├── checks/
    │   ├── ambiguous_links_spec.rb
    │   └── duplicate_skill_requires_spec.rb
    ├── operations/
    │   └── stats_spec.rb
    ├── cli_spec.rb
    ├── settings_manager_spec.rb
    ├── repo_config_reader_spec.rb
    └── ... (29 spec files total)
```

## Test Structure

**Suite Organization:**

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Ruly::Checks::AmbiguousLinks do
  let(:test_dir) { Dir.mktmpdir }

  around do |example|
    original_dir = Dir.pwd
    begin
      Dir.chdir(test_dir)
      example.run
    ensure
      Dir.chdir(original_dir)
      FileUtils.rm_rf(test_dir) if test_dir && Dir.exist?(test_dir)
    end
  end

  describe '.call' do
    context 'when there are no ambiguous links' do
      it 'returns passed: true for sources with unique headers' do
        # Test implementation
      end
    end

    context 'when there are ambiguous links' do
      it 'returns passed: false when a link references an anchor that exists in multiple files' do
        # Test implementation
      end
    end
  end
end
```

**Patterns:**

**1. Temporary directory handling with around hook:**
- Used for tests requiring filesystem operations
- Creates tmpdir via `Dir.mktmpdir`
- Changes working directory for test
- Always restores original directory before cleanup (prevents bundler issues)

```ruby
around do |example|
  original_dir = Dir.pwd
  begin
    Dir.chdir(test_dir)
    example.run
  ensure
    Dir.chdir(original_dir)
    FileUtils.rm_rf(test_dir) if test_dir && Dir.exist?(test_dir)
  end
end
```

**2. Setup with before/let blocks:**
```ruby
let(:cli) { described_class.new }
let(:test_dir) { Dir.mktmpdir }

before do
  # Create test rules directory
  FileUtils.mkdir_p(File.join(test_dir, 'rules'))

  # Create test rule files
  File.write(File.join(test_dir, 'rules', 'test.md'), '# Test Rule')

  # Mock gem_root
  allow(cli).to receive_messages(gem_root: test_dir)
end

after do
  FileUtils.rm_rf(test_dir)
end
```

**3. Nested context/describe blocks by feature:**
```ruby
describe '#convert_to_raw_url' do
  it 'converts GitHub blob URLs to raw URLs' do
    # Test
  end

  it 'leaves raw GitHub URLs unchanged' do
    # Test
  end
end

describe '#load_recipe_sources' do
  # Different describe block for different feature
end
```

**4. RSpec context for conditional behavior:**
```ruby
context 'when recipe has hooks' do
  # Setup specific to this context
  let(:recipe_config) do
    {
      'hooks' => { ... }
    }
  end

  it 'creates .claude/settings.local.json with hooks' do
    # Tests specific to this condition
  end
end

context 'when recipe has no hooks or model' do
  # Different setup
  it 'does not create settings.local.json' do
    # Tests different behavior
  end
end
```

## Mocking

**Framework:** RSpec's built-in `allow/expect` with `instance_double`

**Patterns:**

**1. Method stubs with return values:**
```ruby
allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
```

**2. Instance doubles for objects:**
```ruby
mock_response = instance_double(Net::HTTPResponse, body: '# Content', code: '200')
allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
```

**3. Verification of calls:**
```ruby
expect(Net::HTTP).to receive(:get_response) do |uri|
  expect(uri.to_s).to eq('https://raw.githubusercontent.com/user/repo/main/file.md')
  mock_response
end

content = cli.send(:fetch_remote_content, 'https://github.com/user/repo/blob/main/file.md')
expect(content).to eq('# GitHub Content')
```

**4. Mocking multiple values with receive_messages:**
```ruby
allow(cli).to receive_messages(
  gem_root: test_dir,
  recipes_file: File.join(test_dir, 'recipes.yml'),
  rules_dir: File.join(test_dir, 'rules')
)
```

**5. Exception handling in mocks:**
```ruby
allow(Net::HTTP).to receive(:get_response).and_raise(StandardError.new('Network error'))

content = cli.send(:fetch_remote_content, 'https://example.com/file.md')
expect(content).to be_nil
```

**What to Mock:**
- External HTTP calls (use `instance_double` for responses)
- File system access (create test files in tmpdir instead when possible, only mock when testing error paths)
- Method calls on `described_class` to test class methods
- Instance methods via `allow/expect` when testing interactions

**What NOT to Mock:**
- Pure functions without side effects (call the real implementation)
- File I/O when testing actual file handling (use real tmpdir files instead)
- YAML/JSON parsing (test with real data)
- String/Array/Hash methods (always call real methods)

## Fixtures and Factories

**Test Data:**
No FactoryBot or fixture files. Data created inline in tests:

```ruby
# From cli_spec.rb - creating recipe config inline
let(:recipes_content) do
  {
    'recipes' => {
      'test_legacy' => {
        'files' => ['rules/local.md'],
        'remote_sources' => ['https://example.com/remote.md']
      },
      'test_local' => {
        'files' => ['rules/test.md']
      }
    }
  }
end

before do
  File.write(File.join(test_dir, 'recipes.yml'), recipes_content.to_yaml)
end
```

**Test files created programmatically:**
```ruby
# From ambiguous_links_spec.rb
local_sources = [
  {
    content: "# File 1\n\n## Introduction\n\nWelcome to file 1.",
    path: 'rules/file1.md'
  },
  {
    content: "# File 2\n\n## Overview\n\nWelcome to file 2.",
    path: 'rules/file2.md'
  }
]

result = described_class.call(local_sources, [])
expect(result[:passed]).to be(true)
```

**Location:**
- Test data defined in `let` blocks or as local variables in test blocks
- No separate fixture directories or files
- YAML/JSON test data written directly to tmpdir files when needed

## Coverage

**Requirements:** No coverage enforcement (no threshold set in codebase)

**View Coverage:**
```bash
# RSpec supports coverage reporting via simplecov (if installed)
# Not configured in this project
```

## Test Types

**Unit Tests:**
- Scope: Single class/module in isolation
- Approach: Mock dependencies, test one behavior per test
- Example: `spec/ruly/checks/ambiguous_links_spec.rb` tests `AmbiguousLinks.call` with various source combinations
- 20+ unit test files in `spec/ruly/`

**Integration Tests:**
- Scope: Multiple components working together
- Approach: Use real filesystem via tmpdir, real YAML parsing, actual file I/O
- Location: `spec/integration/ruly_cli_spec.rb`
- Tests like: loading recipes, processing sources, file output
- Example:
  ```ruby
  # From integration spec
  sources, = cli.send(:load_recipe_sources, 'local_only')
  expect(sources.size).to eq(2)
  expect(sources.all? { |s| s[:type] == 'local' }).to be(true)
  ```

**E2E Tests:**
- Not used - integration tests cover command-line behavior

## Common Patterns

**Async Testing:**
Not applicable - this is a synchronous CLI tool with no async operations.

**Error Testing:**

**1. Testing for raised exceptions:**
```ruby
# Not commonly used - typically test behavior after rescue
# When testing error path:
expect do
  described_class.call(invalid_input)
end.to raise_error(Ruly::Error, /Skill file not found/)
```

**2. Testing graceful error handling:**
```ruby
it 'returns nil for failed requests' do
  mock_response = instance_double(Net::HTTPResponse, body: 'Not Found', code: '404')
  allow(Net::HTTP).to receive(:get_response).and_return(mock_response)

  content = cli.send(:fetch_remote_content, 'https://example.com/missing.md')
  expect(content).to be_nil
end

it 'handles network errors gracefully' do
  allow(Net::HTTP).to receive(:get_response).and_raise(StandardError.new('Network error'))

  content = cli.send(:fetch_remote_content, 'https://example.com/file.md')
  expect(content).to be_nil
end
```

**3. Testing exit behavior:**
```ruby
# Not extensively used - CLI tests focus on method behavior
# RSpec::ExitStatus can be used for script-level testing
```

## RSpec Configuration

**From `spec_helper.rb`:**

```ruby
RSpec.configure do |config|
  # Persistence across runs for --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec monkey-patching (no 'should' syntax, only expect)
  config.disable_monkey_patching!

  # Use expect syntax (not should)
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
```

**Key settings:**
- Expect syntax only (no monkey-patching with `should`)
- Example persistence file for failed test tracking
- RSpec 3.x configuration

## Test Execution Notes

**Critical setup pattern for tests with working directory changes:**

Always use `around` hook with proper cleanup ordering:
```ruby
around do |example|
  original_dir = Dir.pwd
  begin
    Dir.chdir(test_dir)
    example.run
  ensure
    # CRITICAL: Always restore Dir BEFORE cleanup
    Dir.chdir(original_dir)
    FileUtils.rm_rf(test_dir) if test_dir && Dir.exist?(test_dir)
  end
end
```

This prevents "bundler losing its working directory" issues that can cause intermittent failures.

**Test isolation:**
- Each test gets its own tmpdir via `Dir.mktmpdir`
- Tests do not depend on file system state from other tests
- Cleanup happens automatically via ensure block

---

*Testing analysis: 2025-03-22*
