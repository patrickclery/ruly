# Skill Requires Deduplication Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Stop inlining `requires:` into skills when the required file is already in the profile, and warn when a file is inlined into multiple skills but missing from the profile.

**Architecture:** Pass the set of profile-resolved file paths into `compile_skill_with_requires` so it can skip already-present dependencies. Add a post-squash check that detects files inlined into 2+ skills and suggests promoting them to the profile.

**Tech Stack:** Ruby, RSpec, existing Ruly checks framework

---

### Task 1: Add failing test — skip requires already in profile

**Files:**
- Create: `spec/ruly/cli_skill_requires_dedup_spec.rb`

**Step 1: Write the failing test**

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Ruly::CLI, type: :cli do
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

  describe 'skill requires deduplication against profile' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'comms', 'skills'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'shared'))

      # Shared file that will be in the profile AND required by skills
      File.write(File.join(test_dir, 'rules', 'shared', 'accounts.md'), <<~MD)
        ---
        description: Team account IDs
        ---
        # Team Directory

        | Name | ID |
        |------|-----|
        | Alice | 123 |
        | Bob | 456 |
      MD

      # Skill that requires accounts.md
      File.write(File.join(test_dir, 'rules', 'comms', 'skills', 'send-dm.md'), <<~MD)
        ---
        name: Send DM
        description: Send a DM
        requires:
          - ../../shared/accounts.md
        ---
        # Send DM

        Look up recipient in [Team Directory](#team-directory).
      MD

      # Rule file that references the skill
      File.write(File.join(test_dir, 'rules', 'comms', 'messaging.md'), <<~MD)
        ---
        description: Messaging commands
        skills:
          - ./skills/send-dm.md
        ---
        # Messaging

        Use skills to send messages.
      MD

      allow(cli).to receive_messages(gem_root: test_dir,
                                     recipes_file: File.join(test_dir, 'recipes.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))
    end

    context 'when a skill requires a file already in the profile' do
      before do
        recipes_content = {
          'test_recipe' => {
            'description' => 'Test recipe',
            'files' => [
              'rules/shared/accounts.md',    # In profile
              'rules/comms/messaging.md'      # Has skill with requires: accounts.md
            ]
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'does not inline the required file into the skill' do
        cli.invoke(:squash, ['test_recipe'])

        skill_content = File.read('.claude/skills/send-dm/SKILL.md', encoding: 'UTF-8')
        # Should NOT contain the accounts content since it's in the profile
        expect(skill_content).not_to include('Team Directory')
        expect(skill_content).not_to include('Alice')
        # But should still have the skill's own content
        expect(skill_content).to include('Send DM')
        expect(skill_content).to include('Look up recipient')
      end

      it 'includes the required file in the profile' do
        cli.invoke(:squash, ['test_recipe'])

        profile_content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
        expect(profile_content).to include('Team Directory')
        expect(profile_content).to include('Alice')
      end
    end

    context 'when a skill requires a file NOT in the profile' do
      before do
        # Profile does NOT include accounts.md
        recipes_content = {
          'test_recipe' => {
            'description' => 'Test recipe',
            'files' => [
              'rules/comms/messaging.md'  # Has skill, but accounts.md NOT in profile
            ]
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'still inlines the required file into the skill' do
        cli.invoke(:squash, ['test_recipe'])

        skill_content = File.read('.claude/skills/send-dm/SKILL.md', encoding: 'UTF-8')
        expect(skill_content).to include('Team Directory')
        expect(skill_content).to include('Alice')
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/patrick/Projects/ruly && bundle exec rspec spec/ruly/cli_skill_requires_dedup_spec.rb -v`
Expected: FAIL — the "does not inline" test fails because `compile_skill_with_requires` currently always inlines.

---

### Task 2: Pass profile paths into `save_skill_files` and `compile_skill_with_requires`

**Files:**
- Modify: `lib/ruly/services/script_manager.rb:386-428`
- Modify: `lib/ruly/cli.rb:390-393`

**Step 1: Update `save_skill_files` signature to accept `profile_paths:`**

In `lib/ruly/services/script_manager.rb`, update `save_skill_files` to accept and forward a `profile_paths:` keyword:

```ruby
def save_skill_files(skill_files, find_rule_file:, parse_frontmatter:, strip_metadata:, profile_paths: Set.new)
  return if skill_files.empty?

  skill_files.each do |file|
    skill_name = derive_skill_name(file[:path])
    skill_dir = ".claude/skills/#{skill_name}"
    FileUtils.mkdir_p(skill_dir)

    content = compile_skill_with_requires(file, find_rule_file:, parse_frontmatter:, strip_metadata:,
                                          profile_paths:)
    File.write(File.join(skill_dir, 'SKILL.md'), content)
  end
end
```

**Step 2: Update `compile_skill_with_requires` to skip profile-present files**

Replace the method body in `lib/ruly/services/script_manager.rb:405-428`:

```ruby
def compile_skill_with_requires(file, find_rule_file:, parse_frontmatter:, strip_metadata:,
                                profile_paths: Set.new)
  original = file[:original_content] || file[:content]
  frontmatter, = parse_frontmatter.call(original)
  requires = frontmatter.is_a?(Hash) ? (frontmatter['requires'] || []) : []

  return file[:content] if requires.empty?

  source_full_path = find_rule_file.call(file[:path])
  return file[:content] unless source_full_path

  source_dir = File.dirname(source_full_path)
  compiled_parts = [file[:content]]

  requires.each do |required_path|
    resolved_path = File.expand_path(required_path, source_dir)
    next unless File.file?(resolved_path)

    # Skip if this file is already in the profile
    canonical = begin
      File.realpath(resolved_path)
    rescue StandardError
      resolved_path
    end
    next if profile_paths.include?(canonical)

    raw_content = File.read(resolved_path, encoding: 'UTF-8')
    stripped = strip_metadata.call(raw_content)
    compiled_parts << stripped
  end

  compiled_parts.join("\n\n---\n\n")
end
```

**Step 3: Update `cli.rb` to build and pass `profile_paths`**

In `lib/ruly/cli.rb`, update the `save_skill_files` wrapper (lines 390-393) to accept and pass `profile_paths`:

```ruby
def save_skill_files(skill_files, profile_paths: Set.new)
  Services::ScriptManager.save_skill_files(skill_files, find_rule_file: method(:find_rule_file),
                                                        parse_frontmatter: Services::FrontmatterParser.method(:parse),
                                                        strip_metadata: Services::FrontmatterParser.method(:strip_metadata),
                                                        profile_paths:)
end
```

Then update `post_squash` (line 367) to build the profile paths set from `local_sources` and pass it:

```ruby
def post_squash(output_file, agent, recipe_name, recipe_config,
                local_sources, command_files, skill_files, script_files)
  update_git_ignores(output_file, agent, command_files)
  save_to_cache(output_file, recipe_name, agent) if recipe_name && options[:cache]
  if agent == 'claude' && !command_files.empty?
    Services::ScriptManager.save_command_files(command_files, recipe_config,
                                               gem_root:)
  end

  if agent == 'claude' && !skill_files.empty?
    profile_paths = build_profile_paths(local_sources)
    save_skill_files(skill_files, profile_paths:)
  end

  # ... rest unchanged
end
```

Add the helper method in `cli.rb`:

```ruby
def build_profile_paths(local_sources)
  paths = Set.new
  local_sources.each do |source|
    full_path = find_rule_file(source[:path])
    next unless full_path

    canonical = begin
      File.realpath(full_path)
    rescue StandardError
      full_path
    end
    paths.add(canonical)
  end
  paths
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/patrick/Projects/ruly && bundle exec rspec spec/ruly/cli_skill_requires_dedup_spec.rb -v`
Expected: All tests PASS

**Step 5: Run full test suite**

Run: `cd /Users/patrick/Projects/ruly && bundle exec rspec`
Expected: All existing tests still pass

**Step 6: Commit**

```bash
git add lib/ruly/services/script_manager.rb lib/ruly/cli.rb spec/ruly/cli_skill_requires_dedup_spec.rb
git commit -m "feat: skip inlining skill requires already present in profile"
```

---

### Task 3: Wire profile paths through `SubagentProcessor`

**Files:**
- Modify: `lib/ruly/services/subagent_processor.rb:185`
- Modify: `lib/ruly/cli.rb:419-428` (the `process_subagents` method)

The subagent processor also calls `save_skill_files` (line 185). It needs to pass the subagent's own `local_sources` as the profile paths, since the subagent's agent file IS its profile.

**Step 1: Write the failing test**

Add to `spec/ruly/cli_skill_requires_dedup_spec.rb`:

```ruby
describe 'skill requires deduplication in subagents' do
  before do
    FileUtils.mkdir_p(File.join(test_dir, 'rules', 'agent', 'skills'))
    FileUtils.mkdir_p(File.join(test_dir, 'rules', 'shared'))
    FileUtils.mkdir_p(File.join(test_dir, 'rules', 'parent'))

    # Shared file
    File.write(File.join(test_dir, 'rules', 'shared', 'accounts.md'), <<~MD)
      ---
      description: Team account IDs
      ---
      # Team Directory

      | Name | ID |
      |------|-----|
      | Alice | 123 |
    MD

    # Skill requiring accounts
    File.write(File.join(test_dir, 'rules', 'agent', 'skills', 'post-comment.md'), <<~MD)
      ---
      name: Post Comment
      description: Post a Jira comment
      requires:
        - ../../shared/accounts.md
      ---
      # Post Comment

      Look up user in [Team Directory](#team-directory).
    MD

    # Agent rule referencing the skill
    File.write(File.join(test_dir, 'rules', 'agent', 'comms.md'), <<~MD)
      ---
      description: Communication rules
      skills:
        - ./skills/post-comment.md
      ---
      # Communication

      Handle all comms tasks.
    MD

    # Agent rule that includes accounts (profile content for subagent)
    File.write(File.join(test_dir, 'rules', 'shared', 'agent-base.md'), <<~MD)
      ---
      description: Base agent rules
      requires:
        - ./accounts.md
      ---
      # Agent Base

      Base content for agents.
    MD

    # Parent rule
    File.write(File.join(test_dir, 'rules', 'parent', 'main.md'), <<~MD)
      ---
      description: Parent rules
      ---
      # Parent

      Parent content.
    MD

    allow(cli).to receive_messages(gem_root: test_dir,
                                   recipes_file: File.join(test_dir, 'recipes.yml'),
                                   rules_dir: File.join(test_dir, 'rules'))
  end

  context 'when subagent profile includes a file also required by its skill' do
    before do
      recipes_content = {
        'comms-recipe' => {
          'description' => 'Comms recipe',
          'files' => [
            'rules/shared/agent-base.md',  # requires accounts.md → in subagent profile
            'rules/agent/comms.md'          # has skill requiring accounts.md
          ]
        },
        'parent_recipe' => {
          'description' => 'Parent',
          'files' => ['rules/parent/main.md'],
          'subagents' => [
            { 'name' => 'comms', 'recipe' => 'comms-recipe' }
          ]
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'does not inline accounts into the subagent skill' do
      cli.invoke(:squash, ['parent_recipe'])

      skill_content = File.read('.claude/skills/post-comment/SKILL.md', encoding: 'UTF-8')
      expect(skill_content).not_to include('Team Directory')
      expect(skill_content).to include('Post Comment')
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/patrick/Projects/ruly && bundle exec rspec spec/ruly/cli_skill_requires_dedup_spec.rb -v`
Expected: FAIL — subagent path doesn't pass `profile_paths` yet.

**Step 3: Update SubagentProcessor to pass profile paths**

In `lib/ruly/services/subagent_processor.rb`, update `generate_agent_file` (around line 185):

Change the `save_skill_files` signature in the deps hash and calling code. The `save_skill_files` proc in `cli.rb` already accepts `profile_paths:`, so update the call site in `subagent_processor.rb:185`:

```ruby
# In generate_agent_file, after load_agent_sources:
profile_paths = build_subagent_profile_paths(local_sources, deps[:find_rule_file])
deps[:save_skill_files].call(skill_files, profile_paths:) unless skill_files.empty?
```

Add the helper:

```ruby
def build_subagent_profile_paths(local_sources, find_rule_file)
  paths = Set.new
  local_sources.each do |source|
    full_path = find_rule_file.call(source[:path])
    next unless full_path

    canonical = begin
      File.realpath(full_path)
    rescue StandardError
      full_path
    end
    paths.add(canonical)
  end
  paths
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/patrick/Projects/ruly && bundle exec rspec spec/ruly/cli_skill_requires_dedup_spec.rb -v`
Expected: All PASS

**Step 5: Run full test suite**

Run: `cd /Users/patrick/Projects/ruly && bundle exec rspec`
Expected: All tests pass

**Step 6: Commit**

```bash
git add lib/ruly/services/subagent_processor.rb spec/ruly/cli_skill_requires_dedup_spec.rb
git commit -m "feat: wire profile path dedup through subagent skill compilation"
```

---

### Task 4: Add post-squash check for duplicate skill requires

**Files:**
- Create: `lib/ruly/checks/duplicate_skill_requires.rb`
- Modify: `lib/ruly/checks.rb`

This check runs after squashing and warns when a file is inlined into 2+ skills, suggesting it should be added to the profile.

**Step 1: Write the failing test**

Create `spec/ruly/checks/duplicate_skill_requires_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Ruly::Checks::DuplicateSkillRequires do
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
    let(:find_rule_file) { ->(path) { File.join(test_dir, path) } }
    let(:parse_frontmatter) { Ruly::Services::FrontmatterParser.method(:parse) }

    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'shared'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'comms', 'skills'))

      File.write(File.join(test_dir, 'rules', 'shared', 'accounts.md'), <<~MD)
        ---
        description: Team accounts
        ---
        # Accounts

        Account data here.
      MD
    end

    context 'when a file is required by 2+ skills and not in profile' do
      it 'returns a warning suggesting promotion to profile' do
        skill_files = [
          {
            path: 'rules/comms/skills/send-dm.md',
            content: '# Send DM',
            original_content: "---\nrequires:\n  - ../../shared/accounts.md\n---\n# Send DM"
          },
          {
            path: 'rules/comms/skills/post-comment.md',
            content: '# Post Comment',
            original_content: "---\nrequires:\n  - ../../shared/accounts.md\n---\n# Post Comment"
          }
        ]

        result = described_class.call(skill_files,
                                      find_rule_file:,
                                      parse_frontmatter:,
                                      profile_paths: Set.new)

        expect(result[:passed]).to be(true) # Warnings don't fail the build
        expect(result[:warnings]).not_to be_empty
        expect(result[:warnings].first[:file]).to include('accounts.md')
        expect(result[:warnings].first[:skills].size).to eq(2)
      end
    end

    context 'when a file is required by 2+ skills but IS in profile' do
      it 'returns no warnings' do
        accounts_path = File.realpath(File.join(test_dir, 'rules', 'shared', 'accounts.md'))

        skill_files = [
          {
            path: 'rules/comms/skills/send-dm.md',
            content: '# Send DM',
            original_content: "---\nrequires:\n  - ../../shared/accounts.md\n---\n# Send DM"
          },
          {
            path: 'rules/comms/skills/post-comment.md',
            content: '# Post Comment',
            original_content: "---\nrequires:\n  - ../../shared/accounts.md\n---\n# Post Comment"
          }
        ]

        result = described_class.call(skill_files,
                                      find_rule_file:,
                                      parse_frontmatter:,
                                      profile_paths: Set.new([accounts_path]))

        expect(result[:warnings]).to be_empty
      end
    end

    context 'when a file is required by only 1 skill' do
      it 'returns no warnings' do
        skill_files = [
          {
            path: 'rules/comms/skills/send-dm.md',
            content: '# Send DM',
            original_content: "---\nrequires:\n  - ../../shared/accounts.md\n---\n# Send DM"
          }
        ]

        result = described_class.call(skill_files,
                                      find_rule_file:,
                                      parse_frontmatter:,
                                      profile_paths: Set.new)

        expect(result[:warnings]).to be_empty
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/patrick/Projects/ruly && bundle exec rspec spec/ruly/checks/duplicate_skill_requires_spec.rb -v`
Expected: FAIL — `Ruly::Checks::DuplicateSkillRequires` doesn't exist yet

**Step 3: Implement `DuplicateSkillRequires` check**

Create `lib/ruly/checks/duplicate_skill_requires.rb`:

```ruby
# frozen_string_literal: true

module Ruly
  module Checks
    # Warns when a file is required by multiple skills but not in the profile.
    # Suggests promoting the file to the recipe's files: list to avoid duplication.
    class DuplicateSkillRequires < Base
      class << self
        def call(skill_files, find_rule_file:, parse_frontmatter:, profile_paths: Set.new)
          require_map = build_require_map(skill_files, find_rule_file:, parse_frontmatter:)
          warnings = detect_duplicates(require_map, profile_paths)

          result = build_result(warnings:)
          report(warnings) if warnings.any?
          result
        end

        private

        def build_require_map(skill_files, find_rule_file:, parse_frontmatter:)
          require_map = Hash.new { |h, k| h[k] = [] }

          skill_files.each do |file|
            original = file[:original_content] || file[:content]
            frontmatter, = parse_frontmatter.call(original)
            requires = frontmatter.is_a?(Hash) ? (frontmatter['requires'] || []) : []
            next if requires.empty?

            source_full_path = find_rule_file.call(file[:path])
            next unless source_full_path

            source_dir = File.dirname(source_full_path)

            requires.each do |required_path|
              resolved = File.expand_path(required_path, source_dir)
              next unless File.file?(resolved)

              canonical = begin
                File.realpath(resolved)
              rescue StandardError
                resolved
              end

              skill_name = Services::ScriptManager.derive_skill_name(file[:path])
              require_map[canonical] << skill_name
            end
          end

          require_map
        end

        def detect_duplicates(require_map, profile_paths)
          require_map.filter_map do |file_path, skills|
            next if skills.size < 2
            next if profile_paths.include?(file_path)

            {
              file: file_path,
              skills:
            }
          end
        end

        def report(warnings)
          puts "\n💡 Skill requires optimization suggestion:"
          puts '   These files are inlined into multiple skills but not in the profile.'
          puts "   Adding them to the recipe's files: list would eliminate duplication.\n\n"

          warnings.each do |warning|
            puts "   📄 #{warning[:file]}"
            puts "      └─ inlined into #{warning[:skills].size} skills: #{warning[:skills].join(', ')}"
          end

          puts "\n   Add these files to the recipe's `files:` list to deduplicate."
          puts ''
        end
      end
    end
  end
end
```

**Step 4: Register the check in `lib/ruly/checks.rb`**

Add the require and update `run_all` to accept and pass skill-specific args:

```ruby
# frozen_string_literal: true

require_relative 'checks/base'
require_relative 'checks/ambiguous_links'
require_relative 'checks/duplicate_skill_requires'

module Ruly
  module Checks
    def self.run_all(local_sources, command_files = [], skill_files: [],
                     find_rule_file: nil, parse_frontmatter: nil, profile_paths: Set.new)
      check_classes = [
        AmbiguousLinks
      ]

      results = check_classes.map do |check_class|
        result = check_class.call(local_sources, command_files)
        result[:passed]
      end

      # Skill-specific checks (only if we have the deps)
      if skill_files.any? && find_rule_file && parse_frontmatter
        DuplicateSkillRequires.call(skill_files, find_rule_file:, parse_frontmatter:,
                                                 profile_paths:)
      end

      results.all?
    end
  end
end
```

**Step 5: Run test to verify it passes**

Run: `cd /Users/patrick/Projects/ruly && bundle exec rspec spec/ruly/checks/duplicate_skill_requires_spec.rb -v`
Expected: All PASS

**Step 6: Run full test suite**

Run: `cd /Users/patrick/Projects/ruly && bundle exec rspec`
Expected: All tests pass

**Step 7: Commit**

```bash
git add lib/ruly/checks/duplicate_skill_requires.rb lib/ruly/checks.rb spec/ruly/checks/duplicate_skill_requires_spec.rb
git commit -m "feat: warn when skill requires are duplicated across multiple skills"
```

---

### Task 5: Wire the check into `post_squash`

**Files:**
- Modify: `lib/ruly/cli.rb:359-374` (`post_squash` method)

**Step 1: Write a failing integration test**

Add to `spec/ruly/cli_skill_requires_dedup_spec.rb`:

```ruby
context 'when squashing produces duplicate skill requires' do
  before do
    # Second skill also requiring accounts
    File.write(File.join(test_dir, 'rules', 'comms', 'skills', 'post-comment.md'), <<~MD)
      ---
      name: Post Comment
      description: Post a comment
      requires:
        - ../../shared/accounts.md
      ---
      # Post Comment

      Look up user in [Team Directory](#team-directory).
    MD

    # Update messaging to reference both skills
    File.write(File.join(test_dir, 'rules', 'comms', 'messaging.md'), <<~MD)
      ---
      description: Messaging commands
      skills:
        - ./skills/send-dm.md
        - ./skills/post-comment.md
      ---
      # Messaging

      Use skills to send messages.
    MD

    # Profile does NOT include accounts.md
    recipes_content = {
      'test_recipe' => {
        'description' => 'Test recipe',
        'files' => ['rules/comms/messaging.md']
      }
    }

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
    # rubocop:enable RSpec/AnyInstance
  end

  it 'outputs a warning about duplicate requires' do
    output = capture(:stdout) { cli.invoke(:squash, ['test_recipe']) }
    expect(output).to include('optimization suggestion')
    expect(output).to include('accounts.md')
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/patrick/Projects/ruly && bundle exec rspec spec/ruly/cli_skill_requires_dedup_spec.rb -v`
Expected: FAIL — `post_squash` doesn't call the check yet

**Step 3: Update `post_squash` to pass skill data into `Checks.run_all`**

In `lib/ruly/cli.rb`, update `post_squash` line 373:

```ruby
Ruly::Checks.run_all(local_sources, command_files,
                     skill_files:,
                     find_rule_file: method(:find_rule_file),
                     parse_frontmatter: Services::FrontmatterParser.method(:parse),
                     profile_paths: build_profile_paths(local_sources))
```

Note: `build_profile_paths` was already added in Task 2.

**Step 4: Run test to verify it passes**

Run: `cd /Users/patrick/Projects/ruly && bundle exec rspec spec/ruly/cli_skill_requires_dedup_spec.rb -v`
Expected: All PASS

**Step 5: Run full test suite**

Run: `cd /Users/patrick/Projects/ruly && bundle exec rspec`
Expected: All tests pass

**Step 6: Commit**

```bash
git add lib/ruly/cli.rb spec/ruly/cli_skill_requires_dedup_spec.rb
git commit -m "feat: wire duplicate skill requires check into post-squash pipeline"
```

---

### Task 6: Manual verification with real comms recipe

**Step 1: Run squash in a temp dir with the comms recipe**

```bash
cd $(mktemp -d) && ruly squash comms
```

**Step 2: Verify skills no longer contain duplicated content**

Check that `accounts.md` content is NOT in skills that require it (since it's in the comms profile):

```bash
grep -l "Team Directory" .claude/skills/*/SKILL.md
```

Expected: No matches (or only skills whose requires aren't in the profile).

**Step 3: Verify the warning fires for any remaining duplicates**

Look at the squash output for the optimization suggestion message.

**Step 4: Commit (if any recipe adjustments needed)**

Only if the manual test reveals recipe config changes are needed.

---

### Task 7: Update the installed ruly binary

**Step 1: Rebuild and install**

```bash
cd /Users/patrick/Projects/ruly && mise install ruby
```

**Step 2: Verify the installed version has the changes**

```bash
which ruly && ruly --version
```

**Step 3: Final commit**

```bash
git add -A
git commit -m "chore: update ruly gem after skill requires dedup feature"
```
