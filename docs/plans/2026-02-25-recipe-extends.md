# Recipe `extends:` Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an `extends:` key to recipes that merges the parent recipe's keys (files, skills, commands, scripts, subagents, mcp_servers, etc.) into the child recipe, allowing recipe inheritance without duplication.

**Architecture:** Recipe resolution happens in `RecipeLoader.load_all_recipes()` after all recipes are loaded from YAML. A new `resolve_extends!` pass walks recipes that declare `extends:`, deep-merges array keys (union) and scalar keys (child wins), strips the `extends:` key, and detects circular references. This runs once before any recipe is consumed by `load_recipe_sources` or `validate_recipe!`.

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

**Array recipes (agent format):** `extends:` is only supported for Hash recipes. Array recipes cannot extend.

**Multi-level inheritance:** `extends:` chains are resolved transitively (A extends B extends C), with circular reference detection.

---

## Task 1: Add `resolve_extends!` method to RecipeLoader

**Files:**
- Modify: `lib/ruly/services/recipe_loader.rb`

### Step 1: Write the failing test

Create a new spec file for the extends feature.

**Files:**
- Create: `spec/ruly/cli_recipe_extends_spec.rb`

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Ruly::Services::RecipeLoader, '.resolve_extends!' do
  describe 'basic extends' do
    it 'merges parent files into child' do
      recipes = {
        'base' => {
          'description' => 'Base recipe',
          'files' => ['rules/base.md']
        },
        'child' => {
          'extends' => 'base',
          'description' => 'Child recipe',
          'files' => ['rules/child.md']
        }
      }

      described_class.resolve_extends!(recipes)

      expect(recipes['child']['files']).to eq(['rules/base.md', 'rules/child.md'])
      expect(recipes['child']['description']).to eq('Child recipe')
      expect(recipes['child']).not_to have_key('extends')
    end
  end
end
```

### Step 2: Run test to verify it fails

Run: `bundle exec rspec spec/ruly/cli_recipe_extends_spec.rb -v`
Expected: FAIL with "undefined method `resolve_extends!'"

### Step 3: Implement `resolve_extends!` in RecipeLoader

Add the following methods to `lib/ruly/services/recipe_loader.rb` inside the `RecipeLoader` module, before the closing `end`:

```ruby
# Array keys that get merged via union (concat + uniq).
ARRAY_MERGE_KEYS = %w[files skills commands scripts sources remote_sources mcp_servers omit_command_prefix].freeze

# Resolve all `extends:` declarations in the recipes hash, in-place.
# Recipes that declare `extends: parent-name` inherit all keys from the parent,
# with array keys unioned and scalar keys overridden by the child.
#
# @param recipes [Hash] all loaded recipes (mutated in place)
# @raise [Ruly::Error] on circular extends references or missing parent
def resolve_extends!(recipes)
  resolved = Set.new

  recipes.each_key do |name|
    resolve_single_extends!(name, recipes, resolved, Set.new)
  end
end

# Recursively resolve extends for a single recipe.
#
# @param name [String] recipe name
# @param recipes [Hash] all recipes
# @param resolved [Set] already fully-resolved recipe names
# @param in_progress [Set] currently being resolved (cycle detection)
def resolve_single_extends!(name, recipes, resolved, in_progress)
  return if resolved.include?(name)

  recipe = recipes[name]
  return unless recipe.is_a?(Hash) && recipe['extends']

  parent_name = recipe['extends']

  if in_progress.include?(name)
    raise Ruly::Error, "Circular extends detected: #{in_progress.to_a.join(' -> ')} -> #{name}"
  end

  unless recipes.key?(parent_name)
    raise Ruly::Error, "Recipe '#{name}' extends '#{parent_name}', but '#{parent_name}' does not exist"
  end

  in_progress.add(name)

  # Resolve parent first (handles transitive extends)
  resolve_single_extends!(parent_name, recipes, resolved, in_progress)

  parent = recipes[parent_name]
  merge_recipe!(recipe, parent)
  recipe.delete('extends')

  in_progress.delete(name)
  resolved.add(name)
end

# Merge parent recipe keys into child recipe (in-place).
# Array keys are unioned (parent first, then child, deduped).
# Subagents are unioned by name (child wins on conflict).
# Scalar keys use child-wins (only set from parent if child doesn't have it).
#
# @param child [Hash] child recipe (mutated)
# @param parent [Hash] parent recipe (read-only)
def merge_recipe!(child, parent)
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

Run: `bundle exec rspec spec/ruly/cli_recipe_extends_spec.rb -v`
Expected: PASS

### Step 5: Commit

```bash
git add spec/ruly/cli_recipe_extends_spec.rb lib/ruly/services/recipe_loader.rb
git commit -m "feat: add resolve_extends! method for recipe inheritance"
```

---

## Task 2: Wire `resolve_extends!` into `load_all_recipes`

**Files:**
- Modify: `lib/ruly/services/recipe_loader.rb:82-100` (the `load_all_recipes` method)

### Step 1: Write the failing integration test

Add to `spec/ruly/cli_recipe_extends_spec.rb`:

```ruby
describe 'integration with load_all_recipes' do
  let(:test_dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(test_dir) }

  it 'resolves extends when loading recipes from YAML' do
    recipes_yml = <<~YAML
      recipes:
        base:
          description: "Base recipe"
          files:
            - rules/base.md
          mcp_servers:
            - task-master-ai
        child:
          extends: base
          description: "Child recipe"
          files:
            - rules/child.md
          mcp_servers:
            - playwright
    YAML

    File.write(File.join(test_dir, 'recipes.yml'), recipes_yml)

    recipes = described_class.load_all_recipes(
      gem_root: test_dir,
      base_recipes_file: File.join(test_dir, 'recipes.yml')
    )

    expect(recipes['child']['files']).to eq(['rules/base.md', 'rules/child.md'])
    expect(recipes['child']['mcp_servers']).to eq(['task-master-ai', 'playwright'])
    expect(recipes['child']).not_to have_key('extends')
    # Parent should be unchanged
    expect(recipes['base']['files']).to eq(['rules/base.md'])
  end
end
```

### Step 2: Run test to verify it fails

Run: `bundle exec rspec spec/ruly/cli_recipe_extends_spec.rb -v`
Expected: FAIL — `extends` key still present, files not merged

### Step 3: Add `resolve_extends!` call to `load_all_recipes`

In `lib/ruly/services/recipe_loader.rb`, modify `load_all_recipes` (around line 99) to call `resolve_extends!` before returning:

```ruby
def load_all_recipes(gem_root:, base_recipes_file: nil)
  recipes = {}

  # Load base recipes
  base_file = base_recipes_file || recipes_file_path(gem_root)
  if File.exist?(base_file)
    base_config = YAML.safe_load_file(base_file, aliases: true) || {}
    recipes.merge!(base_config['recipes'] || {})
  end

  # Load user config recipes (highest priority)
  user_config_file = File.expand_path('~/.config/ruly/recipes.yml')
  if File.exist?(user_config_file)
    user_config = YAML.safe_load_file(user_config_file, aliases: true) || {}
    recipes.merge!(user_config['recipes'] || {})
  end

  resolve_extends!(recipes)

  recipes
end
```

### Step 4: Run test to verify it passes

Run: `bundle exec rspec spec/ruly/cli_recipe_extends_spec.rb -v`
Expected: PASS

### Step 5: Commit

```bash
git add lib/ruly/services/recipe_loader.rb spec/ruly/cli_recipe_extends_spec.rb
git commit -m "feat: wire resolve_extends! into load_all_recipes"
```

---

## Task 3: Comprehensive test coverage

**Files:**
- Modify: `spec/ruly/cli_recipe_extends_spec.rb`

### Step 1: Add edge case tests

Add the following test cases to the spec file:

```ruby
describe 'scalar override (child wins)' do
  it 'child description overrides parent' do
    recipes = {
      'base' => { 'description' => 'Base', 'model' => 'sonnet' },
      'child' => { 'extends' => 'base', 'description' => 'Child', 'model' => 'opus' }
    }

    described_class.resolve_extends!(recipes)

    expect(recipes['child']['description']).to eq('Child')
    expect(recipes['child']['model']).to eq('opus')
  end

  it 'child inherits scalars it does not define' do
    recipes = {
      'base' => { 'description' => 'Base', 'model' => 'sonnet', 'tier' => 'claude_pro' },
      'child' => { 'extends' => 'base', 'description' => 'Child' }
    }

    described_class.resolve_extends!(recipes)

    expect(recipes['child']['model']).to eq('sonnet')
    expect(recipes['child']['tier']).to eq('claude_pro')
  end
end

describe 'array union (deduped, parent first)' do
  it 'unions files without duplicates' do
    recipes = {
      'base' => { 'files' => ['a.md', 'b.md'] },
      'child' => { 'extends' => 'base', 'files' => ['b.md', 'c.md'] }
    }

    described_class.resolve_extends!(recipes)

    expect(recipes['child']['files']).to eq(['a.md', 'b.md', 'c.md'])
  end

  it 'unions mcp_servers' do
    recipes = {
      'base' => { 'mcp_servers' => ['task-master-ai'] },
      'child' => { 'extends' => 'base', 'mcp_servers' => ['playwright'] }
    }

    described_class.resolve_extends!(recipes)

    expect(recipes['child']['mcp_servers']).to eq(['task-master-ai', 'playwright'])
  end

  it 'handles child with no array key (inherits parent array)' do
    recipes = {
      'base' => { 'files' => ['a.md'] },
      'child' => { 'extends' => 'base' }
    }

    described_class.resolve_extends!(recipes)

    expect(recipes['child']['files']).to eq(['a.md'])
  end
end

describe 'subagent merging' do
  it 'unions subagents by name, child wins on conflict' do
    recipes = {
      'base' => {
        'subagents' => [
          { 'name' => 'agent_a', 'recipe' => 'prof-a' },
          { 'name' => 'agent_b', 'recipe' => 'prof-b', 'model' => 'sonnet' }
        ]
      },
      'child' => {
        'extends' => 'base',
        'subagents' => [
          { 'name' => 'agent_b', 'recipe' => 'prof-b', 'model' => 'haiku' },
          { 'name' => 'agent_c', 'recipe' => 'prof-c' }
        ]
      }
    }

    described_class.resolve_extends!(recipes)

    names = recipes['child']['subagents'].map { |s| s['name'] }
    expect(names).to contain_exactly('agent_a', 'agent_b', 'agent_c')

    agent_b = recipes['child']['subagents'].find { |s| s['name'] == 'agent_b' }
    expect(agent_b['model']).to eq('haiku')
  end
end

describe 'transitive extends (A extends B extends C)' do
  it 'resolves multi-level inheritance' do
    recipes = {
      'grandparent' => { 'files' => ['gp.md'], 'mcp_servers' => ['server-a'] },
      'parent' => { 'extends' => 'grandparent', 'files' => ['p.md'] },
      'child' => { 'extends' => 'parent', 'files' => ['c.md'] }
    }

    described_class.resolve_extends!(recipes)

    expect(recipes['child']['files']).to eq(['gp.md', 'p.md', 'c.md'])
    expect(recipes['child']['mcp_servers']).to eq(['server-a'])
    expect(recipes['parent']['files']).to eq(['gp.md', 'p.md'])
  end
end

describe 'circular extends detection' do
  it 'raises error on direct circular reference' do
    recipes = {
      'a' => { 'extends' => 'b' },
      'b' => { 'extends' => 'a' }
    }

    expect { described_class.resolve_extends!(recipes) }.to raise_error(
      Ruly::Error, /Circular extends detected/
    )
  end

  it 'raises error on indirect circular reference' do
    recipes = {
      'a' => { 'extends' => 'b' },
      'b' => { 'extends' => 'c' },
      'c' => { 'extends' => 'a' }
    }

    expect { described_class.resolve_extends!(recipes) }.to raise_error(
      Ruly::Error, /Circular extends detected/
    )
  end
end

describe 'missing parent detection' do
  it 'raises error when parent does not exist' do
    recipes = {
      'child' => { 'extends' => 'nonexistent' }
    }

    expect { described_class.resolve_extends!(recipes) }.to raise_error(
      Ruly::Error, /does not exist/
    )
  end
end

describe 'recipes without extends are unchanged' do
  it 'does not modify recipes that have no extends key' do
    recipes = {
      'standalone' => { 'description' => 'Solo', 'files' => ['a.md'] }
    }

    described_class.resolve_extends!(recipes)

    expect(recipes['standalone']).to eq({ 'description' => 'Solo', 'files' => ['a.md'] })
  end
end

describe 'array recipes are skipped' do
  it 'does not attempt to resolve extends on array recipes' do
    recipes = {
      'base' => { 'files' => ['a.md'] },
      'agent' => ['file1.md', 'file2.md']
    }

    expect { described_class.resolve_extends!(recipes) }.not_to raise_error
    expect(recipes['agent']).to eq(['file1.md', 'file2.md'])
  end
end
```

### Step 2: Run all tests

Run: `bundle exec rspec spec/ruly/cli_recipe_extends_spec.rb -v`
Expected: ALL PASS

### Step 3: Run full test suite to check for regressions

Run: `bundle exec rspec`
Expected: ALL PASS (no regressions)

### Step 4: Commit

```bash
git add spec/ruly/cli_recipe_extends_spec.rb
git commit -m "test: comprehensive coverage for recipe extends feature"
```

---

## Task 4: End-to-end integration test with `ruly squash`

**Files:**
- Modify: `spec/ruly/cli_recipe_extends_spec.rb`

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
      recipes_file: File.join(test_dir, 'recipes.yml'),
      rules_dir: File.join(test_dir, 'rules')
    )

    recipes_content = {
      'base' => {
        'description' => 'Base recipe',
        'files' => ['rules/base.md']
      },
      'child' => {
        'extends' => 'base',
        'description' => 'Child recipe',
        'files' => ['rules/child.md']
      }
    }

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Ruly::CLI).to receive(:load_all_recipes).and_return(
      Ruly::Services::RecipeLoader.send(:resolve_extends_applied, recipes_content)
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

**Note:** Since existing tests mock `load_all_recipes`, the extends resolution needs to happen before mocking. We can either:
1. Have the mock return already-resolved recipes (simpler, shown above with a helper), or
2. Let the real `load_all_recipes` run against a test recipes.yml file.

For the E2E test, option 2 is better. Adjust the test to write a real `recipes.yml`:

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

    recipes_yml = {
      'recipes' => {
        'base' => {
          'description' => 'Base recipe',
          'files' => ['rules/base.md']
        },
        'child' => {
          'extends' => 'base',
          'description' => 'Child recipe',
          'files' => ['rules/child.md']
        }
      }
    }
    File.write(File.join(test_dir, 'recipes.yml'), recipes_yml.to_yaml)

    allow(cli).to receive_messages(
      gem_root: test_dir,
      recipes_file: File.join(test_dir, 'recipes.yml'),
      rules_dir: File.join(test_dir, 'rules')
    )

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Ruly::CLI).to receive(:load_all_recipes).and_return(
      Ruly::Services::RecipeLoader.load_all_recipes(
        gem_root: test_dir,
        base_recipes_file: File.join(test_dir, 'recipes.yml')
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

  it 'parent recipe squash is unaffected' do
    cli.invoke(:squash, ['base'])

    content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
    expect(content).to include('Base Rule')
    expect(content).not_to include('Child Rule')
  end
end
```

### Step 2: Run tests

Run: `bundle exec rspec spec/ruly/cli_recipe_extends_spec.rb -v`
Expected: ALL PASS

### Step 3: Run full suite

Run: `bundle exec rspec`
Expected: ALL PASS

### Step 4: Commit

```bash
git add spec/ruly/cli_recipe_extends_spec.rb
git commit -m "test: add end-to-end squash integration test for extends"
```

---

## Task 5: Update README.md

**Files:**
- Modify: `README.md`

### Step 1: Add `extends:` documentation

Find the recipes section of README.md and add documentation for the `extends:` key. Include:

- What `extends:` does
- Merge semantics (arrays union, scalars child-wins)
- Example YAML
- Transitive inheritance note
- Circular reference detection note

Example content to add:

```markdown
### Recipe Inheritance (`extends:`)

Recipes can extend other recipes using the `extends:` key. The child recipe inherits all keys from the parent, with:

- **Array keys** (`files`, `skills`, `commands`, `scripts`, `sources`, `mcp_servers`, `omit_command_prefix`): Merged via union — parent entries first, then child entries, deduplicated
- **Scalar keys** (`description`, `model`, `tier`): Child wins — parent value only used if child doesn't define it
- **Subagents**: Merged by `name` — child entry overrides parent entry with same name

```yaml
recipes:
  base:
    description: "Base development recipe"
    files:
      - rules/core.md
      - rules/common.md
    mcp_servers:
      - task-master-ai

  extended:
    extends: base
    description: "Extended recipe with extra tools"
    files:
      - rules/extra.md
    mcp_servers:
      - playwright
```

After resolution, `extended` will have:
- `files`: `[rules/core.md, rules/common.md, rules/extra.md]`
- `mcp_servers`: `[task-master-ai, playwright]`
- `description`: `"Extended recipe with extra tools"`

Multi-level inheritance is supported (A extends B extends C). Circular references are detected and produce an error.
```

### Step 2: Commit

```bash
git add README.md
git commit -m "docs: add extends: recipe inheritance documentation"
```

---

## Task 6: Run full validation and final commit

### Step 1: Run full test suite

Run: `bundle exec rspec`
Expected: ALL PASS

### Step 2: Run rubocop

Run: `bundle exec rubocop lib/ruly/services/recipe_loader.rb spec/ruly/cli_recipe_extends_spec.rb`
Expected: No offenses (fix any issues)

### Step 3: Manual smoke test

```bash
cd $(mktemp -d)
# Create a minimal recipes.yml with extends and verify squash works
```

### Step 4: Update installed ruly

Run: `mise install ruby` (per CLAUDE.md instructions)

### Step 5: Final commit if any fixes were needed

```bash
git add -A
git commit -m "chore: final cleanup for recipe extends feature"
```
