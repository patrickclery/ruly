# Agent Frontmatter: Skills, mcpServers, and Nested Subagent Elimination

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Three related changes to align ruly with Claude Code's native agent frontmatter: (1) add `mcpServers:` to agent frontmatter, collected from both recipes.yml and rule-file frontmatter, (2) add `skills:` to agent frontmatter with validation, treating `skills:` in rule frontmatter like a validated `requires:`, and (3) error if a subagent recipe itself has subagents — forcing conversion to skills instead.

**Architecture:** Rule files gain two new frontmatter fields: `mcp_servers:` (MCP server requirements) and `skills:` (relative paths to skill files, resolved like `requires:`). During squash, these are collected, validated (skills error on invalid references, unlike the silent skip of `requires:`), and emitted in agent frontmatter as `mcpServers:` and `skills:`. Nested subagent recipes are refactored: sub-subagent `.md` files move from `/agents/` to `/skills/` directories, parent rules reference them via `skills:`, and `subagents:` are removed from parent recipes.

**Tech Stack:** Ruby (Ruly gem), YAML (recipes.yml), RSpec (tests)

---

## Context: Current vs Target Agent Frontmatter

### Current
```yaml
---
name: context_grabber
description: Orchestrates context fetching and summarization
tools: Bash, Read, Write, Edit, Glob, Grep
model: sonnet
permissionMode: bypassPermissions
---
```

### Target
```yaml
---
name: context_grabber
description: Orchestrates context fetching and summarization
tools: Bash, Read, Write, Edit, Glob, Grep
model: sonnet
skills: [context-downloader-jira, context-downloader-github, context-downloader-teams, context-summarizer]
mcpServers: [teams]
permissionMode: bypassPermissions
---
```

### Current vs Target Subagent Tree (core recipe)
```
CURRENT (23 flat agent files):                 TARGET (12 agents + skills):
.claude/agents/                                .claude/agents/
├── context_grabber.md                         ├── context_grabber.md  (skills: [...])
├── context_downloader_jira.md   ← removed     .claude/skills/
├── context_downloader_github.md ← removed     ├── context-downloader-jira/SKILL.md
├── context_downloader_teams.md  ← removed     ├── context-downloader-github/SKILL.md
├── context_summarizer.md        ← removed     ├── context-downloader-teams/SKILL.md
├── comms.md                                   ├── context-summarizer/SKILL.md
├── ms_teams_dm.md               ← removed     ├── ms-teams-dm/SKILL.md
├── mattermost_dm.md             ← removed     ├── mattermost-dm/SKILL.md
├── jira_comment.md              ← removed     ├── jira-comment/SKILL.md
├── ...                                        └── ...
```

---

## Phase 1: Infrastructure

### Task 1: Collect `mcp_servers:` from rule-file frontmatter

**Files:**
- Create: `spec/ruly/cli_rule_mcp_spec.rb`
- Modify: `lib/ruly/cli.rb` (frontmatter processing, ~line 1919)

**Step 1: Write the failing test**

```ruby
# spec/ruly/cli_rule_mcp_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Ruly::CLI, 'rule-level mcp_servers', type: :cli do
  let(:cli) { described_class.new }
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
    allow(cli).to receive_messages(
      gem_root: test_dir,
      recipes_file: File.join(test_dir, 'recipes.yml'),
      rules_dir: File.join(test_dir, 'rules')
    )
  end

  describe 'mcp_servers in rule frontmatter' do
    before do
      # Rule file with mcp_servers in frontmatter
      File.write(File.join(test_dir, 'rules', 'teams-rule.md'), <<~MD)
        ---
        mcp_servers:
          - teams
        ---
        # Teams Rule
        Use teams MCP to send messages.
      MD

      File.write(File.join(test_dir, 'rules', 'basic-rule.md'), '# Basic Rule')

      recipes_content = {
        'test' => {
          'description' => 'Test recipe',
          'files' => [
            "#{test_dir}/rules/teams-rule.md",
            "#{test_dir}/rules/basic-rule.md"
          ],
          'subagents' => [
            { 'name' => 'worker', 'recipe' => 'worker-recipe' }
          ]
        },
        'worker-recipe' => {
          'description' => 'Worker',
          'files' => ["#{test_dir}/rules/basic-rule.md"]
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'strips mcp_servers from rule content' do
      cli.invoke(:squash, ['test'])

      content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
      expect(content).not_to include('mcp_servers:')
      expect(content).to include('Teams Rule')
    end

    it 'collects mcp_servers for .mcp.json' do
      cli.invoke(:squash, ['test'])

      expect(File.exist?('.mcp.json')).to be(true)
      mcp = JSON.parse(File.read('.mcp.json', encoding: 'UTF-8'))
      expect(mcp['mcpServers']).to have_key('teams')
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/ruly/cli_rule_mcp_spec.rb -v`
Expected: FAIL — `mcp_servers:` not stripped from output AND not collected for `.mcp.json`

**Step 3: Implement rule-level MCP collection**

**3a. Add `mcp_servers:` to the metadata stripping (line ~1990):**

In `strip_metadata_from_frontmatter`, add after the `essential` strip:
```ruby
# Remove the mcp_servers field (same format as requires)
frontmatter = frontmatter.gsub(/^mcp_servers:.*?(?=^\w|\z)/m, '')
```

Also in the default (non-keep_frontmatter) path, `mcp_servers` is not a Claude Code directive, so it's already stripped. Good.

**3b. Collect MCP servers from rule frontmatter during source processing:**

Add a new method to collect MCP servers from processed sources. In the squash flow, after `process_sources_for_squash` returns, iterate over `local_sources` and extract MCP servers from their `original_content` frontmatter:

```ruby
def collect_mcp_servers_from_sources(local_sources)
  servers = []
  local_sources.each do |source|
    next unless source[:original_content]

    frontmatter, = parse_frontmatter(source[:original_content])
    mcp = frontmatter['mcp_servers']
    servers.concat(Array(mcp)) if mcp
  end
  servers.uniq
end
```

**3c. Merge rule-level MCP servers with recipe-level ones:**

In the main squash flow (around line 280), after collecting recipe-level MCP servers, also collect from sources:
```ruby
source_mcp_servers = collect_mcp_servers_from_sources(local_sources)
if source_mcp_servers.any?
  recipe_config['mcp_servers'] = (Array(recipe_config['mcp_servers']) + source_mcp_servers).uniq
  puts "🔌 Collected MCP servers from rules: #{source_mcp_servers.join(', ')}"
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/ruly/cli_rule_mcp_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add spec/ruly/cli_rule_mcp_spec.rb lib/ruly/cli.rb
git commit -m "feat: collect mcp_servers from rule-file frontmatter

Rules can now declare MCP server requirements in frontmatter:
  mcp_servers:
    - teams
These are automatically collected during squash, merged with
recipe-level servers, and added to .mcp.json."
```

---

### Task 2: Add `mcpServers:` to agent frontmatter

**Files:**
- Modify: `spec/ruly/cli_rule_mcp_spec.rb` (add agent frontmatter test)
- Modify: `lib/ruly/cli.rb` (`write_agent_frontmatter` ~line 2900)

**Step 1: Write the failing test**

Add to the spec file:

```ruby
describe 'mcpServers in agent frontmatter' do
  before do
    File.write(File.join(test_dir, 'rules', 'agent-rule.md'), <<~MD)
      ---
      mcp_servers:
        - Ref
      ---
      # Agent Rule
    MD

    recipes_content = {
      'parent' => {
        'description' => 'Parent recipe',
        'files' => ["#{test_dir}/rules/basic-rule.md"],
        'mcp_servers' => ['teams'],
        'subagents' => [
          { 'name' => 'worker', 'recipe' => 'worker-recipe' }
        ]
      },
      'worker-recipe' => {
        'description' => 'Worker',
        'files' => ["#{test_dir}/rules/agent-rule.md"],
        'mcp_servers' => ['playwright']
      }
    }

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
    # rubocop:enable RSpec/AnyInstance
  end

  it 'includes mcpServers in agent frontmatter from recipe' do
    cli.invoke(:squash, ['parent'])

    content = File.read('.claude/agents/worker.md', encoding: 'UTF-8')
    expect(content).to match(/^mcpServers:/)
    expect(content).to include('playwright')
  end

  it 'includes mcpServers from rule-file frontmatter' do
    cli.invoke(:squash, ['parent'])

    content = File.read('.claude/agents/worker.md', encoding: 'UTF-8')
    expect(content).to include('Ref')
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/ruly/cli_rule_mcp_spec.rb -v`
Expected: FAIL — no `mcpServers:` in agent frontmatter

**Step 3: Implement `mcpServers:` in agent frontmatter**

**3a. Collect MCP servers during agent file generation:**

In `generate_agent_file` (line ~2850), after loading agent sources, collect rule-level MCPs:
```ruby
def generate_agent_file(agent_name, recipe_name, recipe_config, parent_recipe_name,
                        subagent_config: {}, parent_recipe_config: {})
  agent_file = ".claude/agents/#{agent_name}.md"
  local_sources, command_files = load_agent_sources(recipe_name, recipe_config)

  # Collect MCP servers from recipe config + rule frontmatter
  source_mcp = collect_mcp_servers_from_sources(local_sources)
  all_mcp = (Array(recipe_config['mcp_servers']) + source_mcp).uniq

  context = build_agent_context(agent_name, recipe_name, recipe_config, parent_recipe_name, local_sources,
                                subagent_config:, parent_recipe_config:, mcp_servers: all_mcp)
  # ...
end
```

**3b. Update `build_agent_context` to include mcp_servers:**

```ruby
def build_agent_context(agent_name, recipe_name, recipe_config, parent_recipe_name, local_sources,
                        subagent_config: {}, parent_recipe_config: {}, mcp_servers: [])
  {
    # ... existing fields ...
    mcp_servers:,
    # ...
  }
end
```

**3c. Update `write_agent_frontmatter` to emit mcpServers:**

```ruby
def write_agent_frontmatter(output, context)
  output.puts '---'
  output.puts "name: #{context[:agent_name]}"
  output.puts "description: #{context[:description]}"
  output.puts 'tools: Bash, Read, Write, Edit, Glob, Grep'
  output.puts "model: #{context[:model]}"
  if context[:mcp_servers]&.any?
    output.puts "mcpServers: [#{context[:mcp_servers].join(', ')}]"
  end
  output.puts 'permissionMode: bypassPermissions'
  output.puts "# Auto-generated from recipe: #{context[:recipe_name]}"
  output.puts "# Do not edit manually - regenerate using 'ruly squash #{context[:parent_recipe_name]}'"
  output.puts '---'
  output.puts
end
```

**3d. Remove the body-text MCP section** (`write_agent_mcp_servers`) — it's now in frontmatter.

Update `write_agent_file` to remove the call:
```ruby
def write_agent_file(agent_file, context)
  File.open(agent_file, 'w') do |output|
    write_agent_frontmatter(output, context)
    write_agent_content(output, context)
    # REMOVED: write_agent_mcp_servers — now in frontmatter
    write_agent_footer(output, context[:timestamp], context[:recipe_name])
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/ruly/cli_rule_mcp_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add spec/ruly/cli_rule_mcp_spec.rb lib/ruly/cli.rb
git commit -m "feat: add mcpServers to agent frontmatter

Uses the native Claude Code mcpServers field instead of listing
MCP servers in the markdown body. Merges servers from recipe config
and rule-file frontmatter."
```

---

### Task 3: Add `skills:` frontmatter resolution with validation

**Files:**
- Create: `spec/ruly/cli_skills_frontmatter_spec.rb`
- Modify: `lib/ruly/cli.rb` (add `resolve_skills_for_source`, update processing pipeline)

**Step 1: Write the failing test**

```ruby
# spec/ruly/cli_skills_frontmatter_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Ruly::CLI, 'skills frontmatter', type: :cli do
  let(:cli) { described_class.new }
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
    FileUtils.mkdir_p(File.join(test_dir, 'rules', 'skills'))
    allow(cli).to receive_messages(
      gem_root: test_dir,
      recipes_file: File.join(test_dir, 'recipes.yml'),
      rules_dir: File.join(test_dir, 'rules')
    )
  end

  describe 'skills: resolves referenced skill files' do
    before do
      # Skill file
      File.write(File.join(test_dir, 'rules', 'skills', 'my-tool.md'), <<~MD)
        ---
        name: my-tool
        description: A useful tool
        ---
        # My Tool Instructions
        Do the thing.
      MD

      # Rule file referencing the skill
      File.write(File.join(test_dir, 'rules', 'orchestrator.md'), <<~MD)
        ---
        skills:
          - ./skills/my-tool.md
        ---
        # Orchestrator
        You orchestrate things.
      MD

      recipes_content = {
        'test' => {
          'description' => 'Test recipe',
          'files' => ["#{test_dir}/rules/orchestrator.md"],
          'subagents' => [
            { 'name' => 'worker', 'recipe' => 'worker-recipe' }
          ]
        },
        'worker-recipe' => {
          'description' => 'Worker',
          'files' => ["#{test_dir}/rules/orchestrator.md"]
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'generates skill file to .claude/skills/' do
      cli.invoke(:squash, ['test'])

      expect(File.exist?('.claude/skills/my-tool/SKILL.md')).to be(true)
    end

    it 'skill file contains the skill content' do
      cli.invoke(:squash, ['test'])

      content = File.read('.claude/skills/my-tool/SKILL.md', encoding: 'UTF-8')
      expect(content).to include('My Tool Instructions')
    end

    it 'strips skills: from squashed output' do
      cli.invoke(:squash, ['test'])

      content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
      expect(content).not_to include('skills:')
      expect(content).to include('Orchestrator')
    end
  end

  describe 'skills: validation errors' do
    it 'errors on invalid skill reference' do
      File.write(File.join(test_dir, 'rules', 'bad-ref.md'), <<~MD)
        ---
        skills:
          - ./skills/nonexistent.md
        ---
        # Bad Rule
      MD

      recipes_content = {
        'test' => {
          'description' => 'Test',
          'files' => ["#{test_dir}/rules/bad-ref.md"]
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
      # rubocop:enable RSpec/AnyInstance

      expect { cli.invoke(:squash, ['test']) }.to raise_error(/skill.*nonexistent/i)
    end

    it 'errors if skill reference is not in a /skills/ path' do
      File.write(File.join(test_dir, 'rules', 'not-a-skill.md'), '# Not a skill')
      File.write(File.join(test_dir, 'rules', 'bad-path.md'), <<~MD)
        ---
        skills:
          - ./not-a-skill.md
        ---
        # Bad Path Rule
      MD

      recipes_content = {
        'test' => {
          'description' => 'Test',
          'files' => ["#{test_dir}/rules/bad-path.md"]
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
      # rubocop:enable RSpec/AnyInstance

      expect { cli.invoke(:squash, ['test']) }.to raise_error(/skill.*must be in.*skills/i)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/ruly/cli_skills_frontmatter_spec.rb -v`
Expected: FAIL — skills not resolved, no validation

**Step 3: Implement skills frontmatter resolution**

**3a. Add `skills:` to metadata stripping (line ~1996):**

```ruby
# Remove the skills field (same format as requires)
frontmatter = frontmatter.gsub(/^skills:.*?(?=^\w|\z)/m, '')
```

**3b. Add `resolve_skills_for_source` method (near `resolve_requires_for_source`):**

```ruby
def resolve_skills_for_source(source, content, processed_files)
  frontmatter, = parse_frontmatter(content)
  skills = frontmatter['skills'] || []
  return [] if skills.empty?

  # Normalize to array
  skills = [skills] if skills.is_a?(String)

  skill_sources = []

  skills.each do |skill_path|
    resolved = resolve_required_path(source, skill_path)

    unless resolved
      raise Ruly::Error,
            "Invalid skill reference '#{skill_path}' in #{source[:path]}: file not found"
    end

    # Validate it resolves to a /skills/ path
    resolved_full = find_rule_file(resolved[:path])
    unless resolved_full&.include?('/skills/')
      raise Ruly::Error,
            "Invalid skill reference '#{skill_path}' in #{source[:path]}: must be in a /skills/ directory"
    end

    source_key = get_source_key(resolved)
    next if processed_files.include?(source_key)

    # Mark as skill source (so it goes to skill_files, not local_sources)
    skill_sources << resolved.merge(from_skills_frontmatter: true)
  end

  skill_sources
end
```

**3c. Call `resolve_skills_for_source` in the processing pipeline:**

In `process_single_source_with_requires` (around line 1860), after resolving requires, also resolve skills from the original content. The resolved skill sources should be added to the processing queue alongside required sources.

Find where `resolve_requires_for_source` is called and add skills resolution alongside it. The skill sources should be processed like any other source — they'll be identified as skills by the `/skills/` path check at line 1921.

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/ruly/cli_skills_frontmatter_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add spec/ruly/cli_skills_frontmatter_spec.rb lib/ruly/cli.rb
git commit -m "feat: add skills: frontmatter for validated skill references

Rule files can now declare skill dependencies in frontmatter:
  skills:
    - ./skills/my-tool.md
Unlike requires: (which silently skips invalid refs), skills:
raises an error if the reference is invalid or not in a /skills/
directory. Referenced skills are generated to .claude/skills/."
```

---

### Task 4: Add `skills:` to agent frontmatter

**Files:**
- Modify: `spec/ruly/cli_skills_frontmatter_spec.rb` (add agent frontmatter test)
- Modify: `lib/ruly/cli.rb` (`write_agent_frontmatter`, `generate_agent_file`)

**Step 1: Write the failing test**

Add to the spec file:

```ruby
describe 'skills: in agent frontmatter' do
  before do
    File.write(File.join(test_dir, 'rules', 'skills', 'fetcher.md'), <<~MD)
      ---
      name: fetcher
      description: Fetches data
      ---
      # Fetcher
      Fetch the data.
    MD

    File.write(File.join(test_dir, 'rules', 'agent-rule.md'), <<~MD)
      ---
      skills:
        - ./skills/fetcher.md
      ---
      # Agent Rule
      You orchestrate fetching.
    MD

    recipes_content = {
      'parent' => {
        'description' => 'Parent',
        'files' => ["#{test_dir}/rules/agent-rule.md"],
        'subagents' => [
          { 'name' => 'my_agent', 'recipe' => 'agent-recipe' }
        ]
      },
      'agent-recipe' => {
        'description' => 'Agent with skills',
        'files' => ["#{test_dir}/rules/agent-rule.md"]
      }
    }

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
    # rubocop:enable RSpec/AnyInstance
  end

  it 'includes skills in agent frontmatter' do
    cli.invoke(:squash, ['parent'])

    content = File.read('.claude/agents/my_agent.md', encoding: 'UTF-8')
    expect(content).to match(/^skills:/)
    expect(content).to include('fetcher')
  end

  it 'generates the skill file alongside the agent' do
    cli.invoke(:squash, ['parent'])

    expect(File.exist?('.claude/skills/fetcher/SKILL.md')).to be(true)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/ruly/cli_skills_frontmatter_spec.rb -v`
Expected: FAIL — no `skills:` in agent frontmatter

**Step 3: Implement skills in agent frontmatter**

**3a. Collect skill names during agent source loading:**

In `load_agent_sources`, also return the list of skill files (which have the skill names):
```ruby
def load_agent_sources(recipe_name, recipe_config)
  sources, = load_recipe_sources(recipe_name)
  local_sources, command_files, _bin_files, skill_files = process_sources_for_squash(sources, 'claude', recipe_config, {})
  [local_sources, command_files, skill_files]
end
```

**3b. Extract skill names from skill files:**

```ruby
def extract_skill_names(skill_files)
  skill_files.map do |file|
    # Extract from path: /rules/skills/my-tool.md -> my-tool
    file[:path].split('/skills/').last.sub(/\.md$/, '')
  end
end
```

**3c. Pass skill names through to agent context:**

In `generate_agent_file`:
```ruby
local_sources, command_files, skill_files = load_agent_sources(recipe_name, recipe_config)
skill_names = extract_skill_names(skill_files)

# Save skill files for the agent
save_skill_files(skill_files) unless skill_files.empty?

context = build_agent_context(..., skill_names:, ...)
```

**3d. Update `write_agent_frontmatter`:**

```ruby
if context[:skill_names]&.any?
  output.puts "skills: [#{context[:skill_names].join(', ')}]"
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/ruly/cli_skills_frontmatter_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add spec/ruly/cli_skills_frontmatter_spec.rb lib/ruly/cli.rb
git commit -m "feat: add skills: to agent frontmatter

Agent files now include skills: [name1, name2] in frontmatter,
collected from skill files referenced by the agent's recipe.
Claude Code natively injects skill content into agent context."
```

---

### Task 5: Error if subagent recipe has subagents

**Files:**
- Create: `spec/ruly/cli_nested_subagent_validation_spec.rb`
- Modify: `lib/ruly/cli.rb` (`process_subagents` ~line 2799)

**Step 1: Write the failing test**

```ruby
# spec/ruly/cli_nested_subagent_validation_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Ruly::CLI, 'nested subagent validation', type: :cli do
  let(:cli) { described_class.new }
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
    File.write(File.join(test_dir, 'rules', 'rule.md'), '# Rule')

    allow(cli).to receive_messages(
      gem_root: test_dir,
      recipes_file: File.join(test_dir, 'recipes.yml'),
      rules_dir: File.join(test_dir, 'rules')
    )
  end

  describe 'rejects subagent recipes with their own subagents' do
    before do
      recipes_content = {
        'parent' => {
          'description' => 'Parent',
          'files' => ["#{test_dir}/rules/rule.md"],
          'subagents' => [
            { 'name' => 'nested_one', 'recipe' => 'child-with-subagents' }
          ]
        },
        'child-with-subagents' => {
          'description' => 'Child that itself has subagents',
          'files' => ["#{test_dir}/rules/rule.md"],
          'subagents' => [
            { 'name' => 'grandchild', 'recipe' => 'grandchild-recipe' }
          ]
        },
        'grandchild-recipe' => {
          'description' => 'Grandchild',
          'files' => ["#{test_dir}/rules/rule.md"]
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'raises an error with actionable message' do
      expect { cli.invoke(:squash, ['parent']) }.to raise_error(
        /child-with-subagents.*subagents.*skills/i
      )
    end
  end

  describe 'allows subagent recipes without subagents' do
    before do
      recipes_content = {
        'parent' => {
          'description' => 'Parent',
          'files' => ["#{test_dir}/rules/rule.md"],
          'subagents' => [
            { 'name' => 'leaf', 'recipe' => 'leaf-recipe' }
          ]
        },
        'leaf-recipe' => {
          'description' => 'Leaf subagent (no own subagents)',
          'files' => ["#{test_dir}/rules/rule.md"]
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'generates the agent file without error' do
      expect { cli.invoke(:squash, ['parent']) }.not_to raise_error
      expect(File.exist?('.claude/agents/leaf.md')).to be(true)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/ruly/cli_nested_subagent_validation_spec.rb -v`
Expected: FAIL — no error raised (currently generates nested agents silently)

**Step 3: Implement the validation**

In `process_subagents` (line ~2829), after loading the subagent recipe and before generating:

```ruby
# Validate: subagent recipes must NOT have their own subagents
if subagent_recipe.is_a?(Hash) && subagent_recipe['subagents'].is_a?(Array) && subagent_recipe['subagents'].any?
  sub_names = subagent_recipe['subagents'].map { |s| s['name'] }.join(', ')
  raise Ruly::Error,
        "Recipe '#{recipe_name}' (subagent '#{agent_name}') has its own subagents (#{sub_names}). " \
        "Claude Code subagents cannot spawn other subagents. " \
        "Convert them to skills and reference via 'skills:' in the rule frontmatter instead."
end
```

Also **remove the recursive `process_subagents` call** (lines 2839-2842) — it's now dead code since nested subagents are rejected:

```ruby
# REMOVED: Recursive processing of nested subagents
# Nested subagents are no longer supported — use skills instead.
# if subagent_recipe.is_a?(Hash) && subagent_recipe['subagents']
#   process_subagents(subagent_recipe, parent_recipe_name, visited:, top_level: false)
# end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/ruly/cli_nested_subagent_validation_spec.rb -v`
Expected: PASS

**Step 5: Run existing tests to check for regressions**

Run: `bundle exec rspec spec/ruly/ -v`

Note: If existing tests rely on nested subagent generation (via recursive process_subagents), they'll need updating. The `cli_agent_recipes_spec.rb` tests don't test nesting, so should pass.

**Step 6: Commit**

```bash
git add spec/ruly/cli_nested_subagent_validation_spec.rb lib/ruly/cli.rb
git commit -m "feat: error if subagent recipe has its own subagents

Claude Code subagents cannot spawn other subagents, so nested
subagent recipes are now rejected with a clear error message
directing users to convert to skills instead."
```

---

## Phase 2: Recipe Refactoring

### Task 6: Convert context-grabber sub-subagents to skills

**Files:**
- Move: `rules/comms/context/agents/context-downloader-jira.md` → `rules/comms/context/skills/context-downloader-jira.md`
- Move: `rules/comms/context/agents/context-downloader-github.md` → `rules/comms/context/skills/context-downloader-github.md`
- Move: `rules/comms/context/agents/context-downloader-teams.md` → `rules/comms/context/skills/context-downloader-teams.md`
- Move: `rules/comms/context/agents/context-summarizer.md` → `rules/comms/context/skills/context-summarizer.md`
- Modify: `rules/comms/context/agents/context-grabber.md` (add `skills:` frontmatter)
- Modify: `recipes.yml` (remove subagents from context-grabber, remove sub-subagent recipes)

**Step 1: Move agent files to skills directory**

```bash
cd /Users/patrick/Projects/ruly/rules
mkdir -p comms/context/skills
git mv comms/context/agents/context-downloader-jira.md comms/context/skills/context-downloader-jira.md
git mv comms/context/agents/context-downloader-github.md comms/context/skills/context-downloader-github.md
git mv comms/context/agents/context-downloader-teams.md comms/context/skills/context-downloader-teams.md
git mv comms/context/agents/context-summarizer.md comms/context/skills/context-summarizer.md
```

**Step 2: Add `name:` to each skill file's frontmatter**

Each file needs a `name:` field (skills convention). Also add `mcp_servers:` where applicable.

For `context-downloader-teams.md`:
```yaml
---
name: context-downloader-teams
description: Downloads Teams thread context for a ticket
mcp_servers:
  - teams
---
```

For `context-downloader-jira.md`:
```yaml
---
name: context-downloader-jira
description: Downloads Jira context for a ticket
---
```

For `context-downloader-github.md`:
```yaml
---
name: context-downloader-github
description: Downloads GitHub PR context for a ticket
---
```

For `context-summarizer.md`:
```yaml
---
name: context-summarizer
description: Summarizes cached context files into concise summary
---
```

**Step 3: Update context-grabber.md with skills: references**

```yaml
---
description: Orchestrates parallel context downloading and summarization
skills:
  - ../skills/context-downloader-jira.md
  - ../skills/context-downloader-github.md
  - ../skills/context-downloader-teams.md
  - ../skills/context-summarizer.md
---
```

Also update the body text: change "Dispatch downloaders in parallel" to "Execute the downloader skills directly" (since the agent now has the skill knowledge inline via Claude Code's `skills:` injection).

**Step 4: Update recipes.yml — remove subagents from context-grabber**

```yaml
context-grabber:
  description: "Orchestrates context fetching and summarization"
  files:
    - /Users/patrick/Projects/ruly/rules/comms/context/agents/context-grabber.md
    - /Users/patrick/Projects/ruly/rules/comms/commands/context-fetching.md
  # subagents: REMOVED — converted to skills via frontmatter
```

**Step 5: Remove standalone sub-subagent recipes from recipes.yml**

Delete these recipe entries (they're now skill files, not recipes):
- `context-downloader-jira`
- `context-downloader-github`
- `context-downloader-teams`
- `context-summarizer`

**Step 6: Update `~/.config/ruly/recipes.yml` to match**

**Step 7: Commit**

```bash
git add -A rules/comms/context/
git add recipes.yml
git commit -m "refactor: convert context-grabber sub-subagents to skills

context-downloader-jira/github/teams and context-summarizer are
now skills referenced via frontmatter, not subagent recipes."
```

---

### Task 7: Convert comms sub-subagents to skills

**Files:**
- Move: `rules/comms/ms-teams/agents/ms-teams-dm.md` → `rules/comms/ms-teams/skills/ms-teams-dm.md`
- Move: `rules/comms/mattermost/agents/mattermost-dm.md` → `rules/comms/mattermost/skills/mattermost-dm.md`
- Move: `rules/comms/jira/agents/jira-comment.md` → `rules/comms/jira/skills/jira-comment.md`
- Move: `rules/comms/jira/agents/jira-bug-report.md` → `rules/comms/jira/skills/jira-bug-report.md`
- Move: `rules/comms/jira/agents/jira-ready-for-qa.md` → `rules/comms/jira/skills/jira-ready-for-qa.md`
- Move: `rules/comms/jira/agents/jira-epic.md` → `rules/comms/jira/skills/jira-epic.md`
- Move: `rules/comms/jira/agents/jira-initiative.md` → `rules/comms/jira/skills/jira-initiative.md`
- Move: `rules/comms/jira/agents/jira-story.md` → `rules/comms/jira/skills/jira-story.md`

**Step 1: Move files and add name/mcp_servers frontmatter**

Same pattern as Task 6. Key MCP requirements:
- `ms-teams-dm.md` → `mcp_servers: [teams]`
- `mattermost-dm.md` → `mcp_servers: [mattermost]`
- Jira agents → no MCP (uses `jira` CLI, not MCP)

**Step 2: Create a shared comms skill reference file or update comms recipe files**

The comms recipe's rule files need `skills:` frontmatter referencing all the moved skills. The exact approach depends on which rule file in the comms recipe is the "orchestrator" — likely needs a new file or additions to existing ones.

**Step 3: Update recipes.yml — remove subagents from comms, jira, full, agile recipes**

All recipes that referenced these as subagents need updating:
- `comms` recipe
- `jira` recipe
- `full` recipe
- `agile` recipe

**Step 4: Remove standalone sub-subagent recipes from recipes.yml**

Delete: `ms-teams-dm`, `mattermost-dm`, `jira-comment`, `jira-bug-report`, `jira-ready-for-qa`, `jira-epic`, `jira-initiative`, `jira-story`

**Step 5: Update both recipe config files + commit**

---

### Task 8: Convert core-debugger/engineer sub-subagents to skills

**Files:**
- The `core-debugging` recipe is special — it's BOTH a direct subagent of `core` AND a sub-subagent of `core-debugger`/`core-engineer`/`bug-diagnose`/`bug-fix`.

**Decision:** `core-debugging` stays as a standalone recipe (it's used as a direct subagent). The parent recipes (`core-debugger`, `core-engineer`, `bug-diagnose`, `bug-fix`) add it as a `skills:` reference instead of a subagent.

The skill file already exists at `rules/bug/skills/debugging.md`. The recipes just need to reference it.

**Step 1: Update core-debugger recipe rule files**

Add `skills:` to the core-debugger orchestrator file referencing `bug/skills/debugging.md`.

**Step 2: Remove `subagents:` from core-debugger, core-engineer, bug-diagnose, bug-fix recipes in recipes.yml**

These recipes lose their `subagents:` field entirely. The capabilities previously provided by sub-subagents are now available via skills.

**Step 3: Verify `core-debugging` still works as direct subagent of core**

`core-debugging` recipe has NO subagents of its own, so the validation in Task 5 passes.

**Step 4: Commit**

---

### Task 9: Update both recipe config files

**Step 1: Ensure recipes.yml and ~/.config/ruly/recipes.yml match**

```bash
cp /Users/patrick/Projects/ruly/recipes.yml /Users/patrick/.config/ruly/recipes.yml
cp /Users/patrick/Projects/ruly/recipes.yml /Users/patrick/Projects/chezmoi/config/ruly/recipes.yml
```

**Step 2: Search for any remaining references to deleted recipes**

```bash
grep -r "context-downloader\|ms-teams-dm\|mattermost-dm\|jira-comment\|jira-bug-report\|jira-ready-for-qa\|jira-epic\|jira-initiative\|jira-story" rules/ recipes.yml
```

Fix any stale references.

---

### Task 10: E2E verification, docs, and rebuild

**Step 1: Run full test suite**

```bash
bundle exec rspec -v
```

**Step 2: E2E test with core recipe**

```bash
cd $(mktemp -d) && /Users/patrick/Projects/ruly/bin/ruly squash --deepclean core
```

Expected:
- 12 agent files in `.claude/agents/` (NO sub-subagent agent files)
- Skill files in `.claude/skills/` for each converted sub-subagent
- Agent frontmatter includes `skills:` and `mcpServers:`
- `.mcp.json` includes all MCP servers (from recipes + rule frontmatter)
- NO validation errors about nested subagents

**Step 3: Verify agent frontmatter**

```bash
head -15 .claude/agents/context_grabber.md
```

Expected:
```yaml
---
name: context_grabber
description: Orchestrates context fetching and summarization
tools: Bash, Read, Write, Edit, Glob, Grep
model: sonnet
skills: [context-downloader-jira, context-downloader-github, context-downloader-teams, context-summarizer]
mcpServers: [teams]
permissionMode: bypassPermissions
---
```

**Step 4: Update README.md**

Document:
- `mcp_servers:` in rule frontmatter
- `skills:` in rule frontmatter (validated, like requires but stricter)
- `mcpServers:` and `skills:` in agent frontmatter
- Nested subagent error and the migration path to skills

**Step 5: Rebuild and install**

```bash
cd /Users/patrick/Projects/ruly && gem build ruly.gemspec && gem install ruly-*.gem
```

**Step 6: Commit all remaining changes**

```bash
git add -A
git commit -m "docs: document skills/mcpServers frontmatter and nested subagent rules"
```

---

## Summary of All Changes

| File | Change |
|------|--------|
| `lib/ruly/cli.rb` | Add `collect_mcp_servers_from_sources`, `resolve_skills_for_source`, `extract_skill_names`. Update `strip_metadata_from_frontmatter` (+`mcp_servers`, `skills`), `write_agent_frontmatter` (+`mcpServers`, `skills`), `generate_agent_file` (collect MCPs, skills), `process_subagents` (validation, remove recursion), `load_agent_sources` (return skill_files), `write_agent_file` (remove `write_agent_mcp_servers` call) |
| `spec/ruly/cli_rule_mcp_spec.rb` | NEW — tests for rule-level MCP collection + mcpServers frontmatter |
| `spec/ruly/cli_skills_frontmatter_spec.rb` | NEW — tests for skills: resolution, validation, agent frontmatter |
| `spec/ruly/cli_nested_subagent_validation_spec.rb` | NEW — tests for nested subagent rejection |
| `rules/comms/context/agents/*.md` → `rules/comms/context/skills/*.md` | Move 4 downloader/summarizer files |
| `rules/comms/ms-teams/agents/*.md` → `rules/comms/ms-teams/skills/*.md` | Move Teams DM |
| `rules/comms/mattermost/agents/*.md` → `rules/comms/mattermost/skills/*.md` | Move Mattermost DM |
| `rules/comms/jira/agents/*.md` → `rules/comms/jira/skills/*.md` | Move 5+ Jira agents |
| `recipes.yml` | Remove `subagents:` from 6+ recipes, delete 12+ sub-subagent recipe entries |
| `~/.config/ruly/recipes.yml` | Mirror changes |
| `README.md` | Document new frontmatter fields and migration |

## New Rule Frontmatter Fields

```yaml
---
# Existing fields
name: my-skill                    # Claude Code: skill/command name
description: Does the thing       # Claude Code: used for matching
model: haiku                      # Claude Code: model specification
permissionMode: bypassPermissions # Claude Code: permission level

# NEW fields (processed by ruly, stripped from output)
mcp_servers:                      # MCP servers this rule requires
  - teams
  - Ref
skills:                           # Skill file dependencies (validated, error if invalid)
  - ./skills/my-tool.md
  - ../shared/skills/helper.md
requires:                         # File dependencies (silently skips invalid)
  - ../common.md
---
```
