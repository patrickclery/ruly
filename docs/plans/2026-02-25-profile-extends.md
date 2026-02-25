# Profile `extends:` Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an `extends:` key to profiles that merges the parent profile's keys (files, skills, commands, scripts, subagents, mcp_servers, etc.) into the child profile, allowing profile inheritance without duplication.

**Architecture:** Profile resolution happens in `ProfileLoader.load_all_profiles()` after all profiles are loaded from YAML. A new `resolve_extends!` pass walks profiles that declare `extends:`, deep-merges array keys (union) and scalar keys (child wins), strips the `extends:` key, and detects circular references. This runs once before any profile is consumed by `load_profile_sources` or `validate_profile!`.

**Tech Stack:** Ruby, RSpec, YAML

---

## Merge Semantics

| Key type | Merge behavior | Example |
|----------|---------------|---------|
| `description` | Child wins (override) | Child keeps its own description |
| `model` | Child wins (override) | Child's model takes priority |
| `tier` | Child wins (override) | Child's tier takes priority |
| `omit_command_prefix` | Union (concat + uniq) | Both parent and child prefixes apply |
| `files` | Union (parent first, then child, deduped) | Child adds files on top of parent's |
| `skills` | Union (parent first, then child, deduped) | Same |
| `commands` | Union (parent first, then child, deduped) | Same |
| `scripts` | Union (parent first, then child, deduped) | Same |
| `sources` | Union (parent first, then child, deduped) | Same |
| `remote_sources` | Union (parent first, then child, deduped) | Same |
| `mcp_servers` | Union (parent first, then child, deduped) | Same |
| `subagents` | Union by `name` (child entry wins if same name) | Child can override a subagent |
| Any other key | Child wins (override) | Unknown keys default to child-wins |

**Array profiles (agent format):** `extends:` is only supported for Hash profiles. Array profiles cannot extend.

**Multi-level inheritance:** `extends:` chains are resolved transitively (A extends B extends C), with circular reference detection.

---

## Task 1: Add `resolve_extends!` method to ProfileLoader

**Files:**
- Modify: `lib/ruly/services/profile_loader.rb`

### Step 1: Write the failing test

Create a new spec file for the extends feature.

**Files:**
- Create: `spec/ruly/cli_profile_extends_spec.rb`

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Ruly::Services::ProfileLoader, '.resolve_extends!' do
  describe 'basic extends' do
    it 'merges parent files into child' do
      profiles = {
        'base' => {
          'description' => 'Base profile',
          'files' => ['rules/base.md']
        },
        'child' => {
          'extends' => 'base',
          'description' => 'Child profile',
          'files' => ['rules/child.md']
        }
      }

      described_class.resolve_extends!(profiles)

      expect(profiles['child']['files']).to eq(['rules/base.md', 'rules/child.md'])
      expect(profiles['child']['description']).to eq('Child profile')
      expect(profiles['child']).not_to have_key('extends')
    end
  end
end
```

### Step 2: Run test to verify it fails

Run: `bundle exec rspec spec/ruly/cli_profile_extends_spec.rb -v`
Expected: FAIL with "undefined method `resolve_extends!'"

### Step 3: Implement `resolve_extends!` in ProfileLoader

Add the following methods to `lib/ruly/services/profile_loader.rb` inside the `ProfileLoader` module, before the closing `end`:

```ruby
# Array keys that get merged via union (concat + uniq).
ARRAY_MERGE_KEYS = %w[files skills commands scripts sources remote_sources mcp_servers omit_command_prefix].freeze

# Resolve all `extends:` declarations in the profiles hash, in-place.
# Profiles that declare `extends: parent-name` inherit all keys from the parent,
# with array keys unioned and scalar keys overridden by the child.
#
# @param profiles [Hash] all loaded profiles (mutated in place)
# @raise [Ruly::Error] on circular extends references or missing parent
def resolve_extends!(profiles)
  resolved = Set.new

  profiles.each_key do |name|
    resolve_single_extends!(name, profiles, resolved, Set.new)
  end
end

# Recursively resolve extends for a single profile.
#
# @param name [String] profile name
# @param profiles [Hash] all profiles
# @param resolved [Set] already fully-resolved profile names
# @param in_progress [Set] currently being resolved (cycle detection)
def resolve_single_extends!(name, profiles, resolved, in_progress)
  return if resolved.include?(name)

  profile = profiles[name]
  return unless profile.is_a?(Hash) && profile['extends']

  parent_name = profile['extends']

  if in_progress.include?(name)
    raise Ruly::Error, "Circular extends detected: #{in_progress.to_a.join(' -> ')} -> #{name}"
  end

  unless profiles.key?(parent_name)
    raise Ruly::Error, "Profile '#{name}' extends '#{parent_name}', but '#{parent_name}' does not exist"
  end

  in_progress.add(name)

  # Resolve parent first (handles transitive extends)
  resolve_single_extends!(parent_name, profiles, resolved, in_progress)

  parent = profiles[parent_name]
  merge_profile!(profile, parent)
  profile.delete('extends')

  in_progress.delete(name)
  resolved.add(name)
end

# Merge parent profile keys into child profile (in-place).
# Array keys are unioned (parent first, then child, deduped).
# Subagents are unioned by name (child wins on conflict).
# Scalar keys use child-wins (only set from parent if child doesn't have it).
#
# @param child [Hash] child profile (mutated)
# @param parent [Hash] parent profile (read-only)
def merge_profile!(child, parent)
  parent.each do |key, parent_value|
    next if key == 'extends'

    if key == 'subagents'
      child[key] = merge_subagents(parent_value, child[key])
    elsif ARRAY_MERGE_KEYS.include?(key)
      child_value = child[key] || []
      child[key] = (Array(parent_value) + Array(child_value)).uniq
    elsif !child.key?(key)
      child[key] = parent_value
    end
  end
end

# Merge subagent arrays by name, child entries win on conflict.
#
# @param parent_subagents [Array<Hash>, nil]
# @param child_subagents [Array<Hash>, nil]
# @return [Array<Hash>]
def merge_subagents(parent_subagents, child_subagents)
  parent_list = Array(parent_subagents)
  child_list = Array(child_subagents)

  merged = {}
  parent_list.each { |s| merged[s['name']] = s if s['name'] }
  child_list.each { |s| merged[s['name']] = s if s['name'] }
  merged.values
end
```

### Step 4: Run test to verify it passes

Run: `bundle exec rspec spec/ruly/cli_profile_extends_spec.rb -v`
Expected: PASS

### Step 5: Commit

```bash
git add spec/ruly/cli_profile_extends_spec.rb lib/ruly/services/profile_loader.rb
git commit -m "feat: add resolve_extends! method for profile inheritance"
```

---

## Task 2: Wire `resolve_extends!` into `load_all_profiles`

**Files:**
- Modify: `lib/ruly/services/profile_loader.rb:82-100` (the `load_all_profiles` method)

### Step 1: Write the failing integration test

Add to `spec/ruly/cli_profile_extends_spec.rb`:

```ruby
describe 'integration with load_all_profiles' do
  let(:test_dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(test_dir) }

  it 'resolves extends when loading profiles from YAML' do
    profiles_yml = <<~YAML
      profiles:
        base:
          description: "Base profile"
          files:
            - rules/base.md
          mcp_servers:
            - task-master-ai
        child:
          extends: base
          description: "Child profile"
          files:
            - rules/child.md
          mcp_servers:
            - playwright
    YAML

    File.write(File.join(test_dir, 'profiles.yml'), profiles_yml)

    profiles = described_class.load_all_profiles(
      gem_root: test_dir,
      base_profiles_file: File.join(test_dir, 'profiles.yml')
    )

    expect(profiles['child']['files']).to eq(['rules/base.md', 'rules/child.md'])
    expect(profiles['child']['mcp_servers']).to eq(['task-master-ai', 'playwright'])
    expect(profiles['child']).not_to have_key('extends')
    # Parent should be unchanged
    expect(profiles['base']['files']).to eq(['rules/base.md'])
  end
end
```

### Step 2: Run test to verify it fails

Run: `bundle exec rspec spec/ruly/cli_profile_extends_spec.rb -v`
Expected: FAIL — `extends` key still present, files not merged

### Step 3: Add `resolve_extends!` call to `load_all_profiles`

In `lib/ruly/services/profile_loader.rb`, modify `load_all_profiles` (around line 99) to call `resolve_extends!` before returning:

```ruby
def load_all_profiles(gem_root:, base_profiles_file: nil)
  profiles = {}

  # Load base profiles
  base_file = base_profiles_file || profiles_file_path(gem_root)
  if File.exist?(base_file)
    base_config = YAML.safe_load_file(base_file, aliases: true) || {}
    profiles.merge!(base_config['profiles'] || {})
  end

  # Load user config profiles (highest priority)
  user_config_file = File.expand_path('~/.config/ruly/profiles.yml')
  if File.exist?(user_config_file)
    user_config = YAML.safe_load_file(user_config_file, aliases: true) || {}
    profiles.merge!(user_config['profiles'] || {})
  end

  resolve_extends!(profiles)

  profiles
end
```

### Step 4: Run test to verify it passes

Run: `bundle exec rspec spec/ruly/cli_profile_extends_spec.rb -v`
Expected: PASS

### Step 5: Commit

```bash
git add lib/ruly/services/profile_loader.rb spec/ruly/cli_profile_extends_spec.rb
git commit -m "feat: wire resolve_extends! into load_all_profiles"
```

---

## Task 3: Comprehensive test coverage

**Files:**
- Modify: `spec/ruly/cli_profile_extends_spec.rb`

### Step 1: Add edge case tests

Add the following test cases to the spec file:

```ruby
describe 'scalar override (child wins)' do
  it 'child description overrides parent' do
    profiles = {
      'base' => { 'description' => 'Base', 'model' => 'sonnet' },
      'child' => { 'extends' => 'base', 'description' => 'Child', 'model' => 'opus' }
    }

    described_class.resolve_extends!(profiles)

    expect(profiles['child']['description']).to eq('Child')
    expect(profiles['child']['model']).to eq('opus')
  end

  it 'child inherits scalars it does not define' do
    profiles = {
      'base' => { 'description' => 'Base', 'model' => 'sonnet', 'tier' => 'claude_pro' },
      'child' => { 'extends' => 'base', 'description' => 'Child' }
    }

    described_class.resolve_extends!(profiles)

    expect(profiles['child']['model']).to eq('sonnet')
    expect(profiles['child']['tier']).to eq('claude_pro')
  end
end

describe 'array union (deduped, parent first)' do
  it 'unions files without duplicates' do
    profiles = {
      'base' => { 'files' => ['a.md', 'b.md'] },
      'child' => { 'extends' => 'base', 'files' => ['b.md', 'c.md'] }
    }

    described_class.resolve_extends!(profiles)

    expect(profiles['child']['files']).to eq(['a.md', 'b.md', 'c.md'])
  end

  it 'unions mcp_servers' do
    profiles = {
      'base' => { 'mcp_servers' => ['task-master-ai'] },
      'child' => { 'extends' => 'base', 'mcp_servers' => ['playwright'] }
    }

    described_class.resolve_extends!(profiles)

    expect(profiles['child']['mcp_servers']).to eq(['task-master-ai', 'playwright'])
  end

  it 'handles child with no array key (inherits parent array)' do
    profiles = {
      'base' => { 'files' => ['a.md'] },
      'child' => { 'extends' => 'base' }
    }

    described_class.resolve_extends!(profiles)

    expect(profiles['child']['files']).to eq(['a.md'])
  end
end

describe 'subagent merging' do
  it 'unions subagents by name, child wins on conflict' do
    profiles = {
      'base' => {
        'subagents' => [
          { 'name' => 'agent_a', 'profile' => 'prof-a' },
          { 'name' => 'agent_b', 'profile' => 'prof-b', 'model' => 'sonnet' }
        ]
      },
      'child' => {
        'extends' => 'base',
        'subagents' => [
          { 'name' => 'agent_b', 'profile' => 'prof-b', 'model' => 'haiku' },
          { 'name' => 'agent_c', 'profile' => 'prof-c' }
        ]
      }
    }

    described_class.resolve_extends!(profiles)

    names = profiles['child']['subagents'].map { |s| s['name'] }
    expect(names).to contain_exactly('agent_a', 'agent_b', 'agent_c')

    agent_b = profiles['child']['subagents'].find { |s| s['name'] == 'agent_b' }
    expect(agent_b['model']).to eq('haiku')
  end
end

describe 'transitive extends (A extends B extends C)' do
  it 'resolves multi-level inheritance' do
    profiles = {
      'grandparent' => { 'files' => ['gp.md'], 'mcp_servers' => ['server-a'] },
      'parent' => { 'extends' => 'grandparent', 'files' => ['p.md'] },
      'child' => { 'extends' => 'parent', 'files' => ['c.md'] }
    }

    described_class.resolve_extends!(profiles)

    expect(profiles['child']['files']).to eq(['gp.md', 'p.md', 'c.md'])
    expect(profiles['child']['mcp_servers']).to eq(['server-a'])
    expect(profiles['parent']['files']).to eq(['gp.md', 'p.md'])
  end
end

describe 'circular extends detection' do
  it 'raises error on direct circular reference' do
    profiles = {
      'a' => { 'extends' => 'b' },
      'b' => { 'extends' => 'a' }
    }

    expect { described_class.resolve_extends!(profiles) }.to raise_error(
      Ruly::Error, /Circular extends detected/
    )
  end

  it 'raises error on indirect circular reference' do
    profiles = {
      'a' => { 'extends' => 'b' },
      'b' => { 'extends' => 'c' },
      'c' => { 'extends' => 'a' }
    }

    expect { described_class.resolve_extends!(profiles) }.to raise_error(
      Ruly::Error, /Circular extends detected/
    )
  end
end

describe 'missing parent detection' do
  it 'raises error when parent does not exist' do
    profiles = {
      'child' => { 'extends' => 'nonexistent' }
    }

    expect { described_class.resolve_extends!(profiles) }.to raise_error(
      Ruly::Error, /does not exist/
    )
  end
end

describe 'profiles without extends are unchanged' do
  it 'does not modify profiles that have no extends key' do
    profiles = {
      'standalone' => { 'description' => 'Solo', 'files' => ['a.md'] }
    }

    described_class.resolve_extends!(profiles)

    expect(profiles['standalone']).to eq({ 'description' => 'Solo', 'files' => ['a.md'] })
  end
end

describe 'array profiles are skipped' do
  it 'does not attempt to resolve extends on array profiles' do
    profiles = {
      'base' => { 'files' => ['a.md'] },
      'agent' => ['file1.md', 'file2.md']
    }

    expect { described_class.resolve_extends!(profiles) }.not_to raise_error
    expect(profiles['agent']).to eq(['file1.md', 'file2.md'])
  end
end
```

### Step 2: Run all tests

Run: `bundle exec rspec spec/ruly/cli_profile_extends_spec.rb -v`
Expected: ALL PASS

### Step 3: Run full test suite to check for regressions

Run: `bundle exec rspec`
Expected: ALL PASS (no regressions)

### Step 4: Commit

```bash
git add spec/ruly/cli_profile_extends_spec.rb
git commit -m "test: comprehensive coverage for profile extends feature"
```

---

## Task 4: End-to-end integration test with `ruly squash`

**Files:**
- Modify: `spec/ruly/cli_profile_extends_spec.rb`

### Step 1: Write the failing E2E test

```ruby
describe 'end-to-end squash with extends' do
  let(:cli) { Ruly::CLI.new }
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

  before do
    FileUtils.mkdir_p(File.join(test_dir, 'rules'))
    File.write(File.join(test_dir, 'rules', 'base.md'), '# Base Rule')
    File.write(File.join(test_dir, 'rules', 'child.md'), '# Child Rule')

    allow(cli).to receive_messages(
      gem_root: test_dir,
      profiles_file: File.join(test_dir, 'profiles.yml'),
      rules_dir: File.join(test_dir, 'rules')
    )

    profiles_content = {
      'base' => {
        'description' => 'Base profile',
        'files' => ['rules/base.md']
      },
      'child' => {
        'extends' => 'base',
        'description' => 'Child profile',
        'files' => ['rules/child.md']
      }
    }

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Ruly::CLI).to receive(:load_all_profiles).and_return(
      Ruly::Services::ProfileLoader.send(:resolve_extends_applied, profiles_content)
    )
    # rubocop:enable RSpec/AnyInstance
  end

  it 'squash output includes content from both parent and child files' do
    cli.invoke(:squash, ['child'])

    content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
    expect(content).to include('Base Rule')
    expect(content).to include('Child Rule')
  end
end
```

**Note:** Since existing tests mock `load_all_profiles`, the extends resolution needs to happen before mocking. We can either:
1. Have the mock return already-resolved profiles (simpler, shown above with a helper), or
2. Let the real `load_all_profiles` run against a test profiles.yml file.

For the E2E test, option 2 is better. Adjust the test to write a real `profiles.yml`:

```ruby
describe 'end-to-end squash with extends', type: :cli do
  let(:cli) { Ruly::CLI.new }
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

  before do
    FileUtils.mkdir_p(File.join(test_dir, 'rules'))
    File.write(File.join(test_dir, 'rules', 'base.md'), '# Base Rule')
    File.write(File.join(test_dir, 'rules', 'child.md'), '# Child Rule')

    profiles_yml = {
      'profiles' => {
        'base' => {
          'description' => 'Base profile',
          'files' => ['rules/base.md']
        },
        'child' => {
          'extends' => 'base',
          'description' => 'Child profile',
          'files' => ['rules/child.md']
        }
      }
    }
    File.write(File.join(test_dir, 'profiles.yml'), profiles_yml.to_yaml)

    allow(cli).to receive_messages(
      gem_root: test_dir,
      profiles_file: File.join(test_dir, 'profiles.yml'),
      rules_dir: File.join(test_dir, 'rules')
    )

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Ruly::CLI).to receive(:load_all_profiles).and_return(
      Ruly::Services::ProfileLoader.load_all_profiles(
        gem_root: test_dir,
        base_profiles_file: File.join(test_dir, 'profiles.yml')
      )
    )
    # rubocop:enable RSpec/AnyInstance
  end

  it 'squash output includes content from both parent and child files' do
    cli.invoke(:squash, ['child'])

    content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
    expect(content).to include('Base Rule')
    expect(content).to include('Child Rule')
  end

  it 'parent profile squash is unaffected' do
    cli.invoke(:squash, ['base'])

    content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
    expect(content).to include('Base Rule')
    expect(content).not_to include('Child Rule')
  end
end
```

### Step 2: Run tests

Run: `bundle exec rspec spec/ruly/cli_profile_extends_spec.rb -v`
Expected: ALL PASS

### Step 3: Run full suite

Run: `bundle exec rspec`
Expected: ALL PASS

### Step 4: Commit

```bash
git add spec/ruly/cli_profile_extends_spec.rb
git commit -m "test: add end-to-end squash integration test for extends"
```

---

## Task 5: Update README.md

**Files:**
- Modify: `README.md`

### Step 1: Add `extends:` documentation

Find the profiles section of README.md and add documentation for the `extends:` key. Include:

- What `extends:` does
- Merge semantics (arrays union, scalars child-wins)
- Example YAML
- Transitive inheritance note
- Circular reference detection note

Example content to add:

```markdown
### Profile Inheritance (`extends:`)

Profiles can extend other profiles using the `extends:` key. The child profile inherits all keys from the parent, with:

- **Array keys** (`files`, `skills`, `commands`, `scripts`, `sources`, `mcp_servers`, `omit_command_prefix`): Merged via union — parent entries first, then child entries, deduplicated
- **Scalar keys** (`description`, `model`, `tier`): Child wins — parent value only used if child doesn't define it
- **Subagents**: Merged by `name` — child entry overrides parent entry with same name

```yaml
profiles:
  base:
    description: "Base development profile"
    files:
      - rules/core.md
      - rules/common.md
    mcp_servers:
      - task-master-ai

  extended:
    extends: base
    description: "Extended profile with extra tools"
    files:
      - rules/extra.md
    mcp_servers:
      - playwright
```

After resolution, `extended` will have:
- `files`: `[rules/core.md, rules/common.md, rules/extra.md]`
- `mcp_servers`: `[task-master-ai, playwright]`
- `description`: `"Extended profile with extra tools"`

Multi-level inheritance is supported (A extends B extends C). Circular references are detected and produce an error.
```

### Step 2: Commit

```bash
git add README.md
git commit -m "docs: add extends: profile inheritance documentation"
```

---

## Task 6: Run full validation and final commit

### Step 1: Run full test suite

Run: `bundle exec rspec`
Expected: ALL PASS

### Step 2: Run rubocop

Run: `bundle exec rubocop lib/ruly/services/profile_loader.rb spec/ruly/cli_profile_extends_spec.rb`
Expected: No offenses (fix any issues)

### Step 3: Manual smoke test

```bash
cd $(mktemp -d)
# Create a minimal profiles.yml with extends and verify squash works
```

### Step 4: Update installed ruly

Run: `mise install ruby` (per CLAUDE.md instructions)

### Step 5: Final commit if any fixes were needed

```bash
git add -A
git commit -m "chore: final cleanup for profile extends feature"
```
