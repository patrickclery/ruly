# Explicit Profile Keys for Skills, Commands, and Bins

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace path-based auto-inference of skills, commands, and bin files with explicit profile-level keys (`skills`, `commands`, `bins`). Files not in these explicit keys get squashed into CLAUDE.local.md regardless of their directory path.

**Architecture:** Add three new keys to the profile YAML schema. Tag sources with their category at load time. Replace all path-based detection in the processing pipeline with marker-based categorization. Keep the `skills:` frontmatter mechanism (it's already explicit, not auto-inferred).

**Tech Stack:** Ruby, RSpec, YAML

---

## Summary of Changes

### Current behavior (auto-inference)

| Detection | Trigger | Code location |
|-----------|---------|---------------|
| Skills | Path contains `/skills/` | `source_processor.rb:219,261,294` |
| Commands | Path contains `/commands/` | `source_processor.rb:218,260,293` |
| Bins | Path matches `bin/*.sh` | `source_processor.rb:208` |

### New behavior (explicit keys)

| Category | Profile key | Frontmatter | Path detection |
|----------|-----------|-------------|----------------|
| Skills | `skills:` | `skills:` (kept) | **Removed** |
| Commands | `commands:` | N/A | **Removed** |
| Bins | `scripts:` | N/A | **Removed** |

### New profile schema

```yaml
profile-name:
  description: "..."
  files:
    - /path/to/rule.md          # Always squashed into CLAUDE.local.md
    - /path/to/skills/foo.md    # Also squashed (no auto-detection)
  skills:
    - /path/to/skill.md         # Output as .claude/skills/{name}/SKILL.md
    - /path/to/skills-dir/      # Directory expansion (all .md files → skills)
  commands:
    - /path/to/command.md       # Output as .claude/commands/{name}.md
    - /path/to/commands-dir/    # Directory expansion (all .md files → commands)
  scripts:
    - /path/to/script.sh        # Output as .claude/scripts/{name}.sh
    - /path/to/bin-dir/         # Directory expansion (all .sh files → bins)
  mcp_servers: [...]            # Unchanged
  subagents: [...]              # Unchanged
```

---

## Task 1: Add profile-level key processing in ProfileLoader

**Files:**
- Modify: `lib/ruly/services/profile_loader.rb:17-43` (load_profile_sources)
- Test: `spec/ruly/cli_profile_explicit_keys_spec.rb` (new)

### Step 1: Write the failing test

Create `spec/ruly/cli_profile_explicit_keys_spec.rb`:

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

  describe 'profile-level skills key' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'core'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'my-skills'))

      File.write(File.join(test_dir, 'rules', 'core', 'main.md'), <<~MD)
        # Main Rule
        Some content.
      MD

      File.write(File.join(test_dir, 'rules', 'my-skills', 'deploy.md'), <<~MD)
        ---
        description: Deploy skill
        ---
        # Deploy
        Deploy steps.
      MD

      allow(cli).to receive_messages(
        gem_root: test_dir,
        profiles_file: File.join(test_dir, 'profiles.yml'),
        rules_dir: File.join(test_dir, 'rules')
      )

      profiles_content = {
        'test_profile' => {
          'description' => 'Test with explicit skills key',
          'files' => ['rules/core/main.md'],
          'skills' => ['rules/my-skills/deploy.md']
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'outputs files in skills key as SKILL.md' do
      cli.invoke(:squash, ['test_profile'])

      expect(File.exist?('.claude/skills/deploy/SKILL.md')).to be(true)
      expect(File.read('.claude/skills/deploy/SKILL.md')).to include('Deploy steps')
    end

    it 'does not include skills key files in main output' do
      cli.invoke(:squash, ['test_profile'])

      content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
      expect(content).not_to include('Deploy steps')
      expect(content).to include('Main Rule')
    end
  end

  describe 'files in /skills/ path without skills key are squashed' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'core', 'skills'))

      File.write(File.join(test_dir, 'rules', 'core', 'skills', 'debug.md'), <<~MD)
        # Debug Skill
        Debug content that should be squashed.
      MD

      allow(cli).to receive_messages(
        gem_root: test_dir,
        profiles_file: File.join(test_dir, 'profiles.yml'),
        rules_dir: File.join(test_dir, 'rules')
      )

      profiles_content = {
        'test_profile' => {
          'description' => 'Test without explicit skills key',
          'files' => ['rules/core/skills/debug.md']
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'squashes files in /skills/ path into main output when in files key' do
      cli.invoke(:squash, ['test_profile'])

      content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
      expect(content).to include('Debug content that should be squashed')
    end

    it 'does not create SKILL.md for files in files key' do
      cli.invoke(:squash, ['test_profile'])

      expect(File.exist?('.claude/skills/debug/SKILL.md')).to be(false)
    end
  end

  describe 'profile-level commands key' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'core'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'my-commands'))

      File.write(File.join(test_dir, 'rules', 'core', 'main.md'), <<~MD)
        # Main Rule
        Some content.
      MD

      File.write(File.join(test_dir, 'rules', 'my-commands', 'deploy.md'), <<~MD)
        # Deploy Command
        Deploy command content.
      MD

      allow(cli).to receive_messages(
        gem_root: test_dir,
        profiles_file: File.join(test_dir, 'profiles.yml'),
        rules_dir: File.join(test_dir, 'rules')
      )

      profiles_content = {
        'test_profile' => {
          'description' => 'Test with explicit commands key',
          'files' => ['rules/core/main.md'],
          'commands' => ['rules/my-commands/deploy.md']
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'outputs files in commands key to .claude/commands/' do
      cli.invoke(:squash, ['test_profile'])

      expect(File.exist?('.claude/commands/deploy.md')).to be(true)
      expect(File.read('.claude/commands/deploy.md')).to include('Deploy command content')
    end

    it 'does not include commands key files in main output' do
      cli.invoke(:squash, ['test_profile'])

      content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
      expect(content).not_to include('Deploy command content')
      expect(content).to include('Main Rule')
    end
  end

  describe 'profile-level bins key' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'core'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'my-bin'))

      File.write(File.join(test_dir, 'rules', 'core', 'main.md'), <<~MD)
        # Main Rule
        Some content.
      MD

      File.write(File.join(test_dir, 'rules', 'my-bin', 'deploy.sh'), "#!/bin/bash\necho deploy")

      allow(cli).to receive_messages(
        gem_root: test_dir,
        profiles_file: File.join(test_dir, 'profiles.yml'),
        rules_dir: File.join(test_dir, 'rules')
      )

      profiles_content = {
        'test_profile' => {
          'description' => 'Test with explicit bins key',
          'files' => ['rules/core/main.md'],
          'bins' => ['rules/my-bin/deploy.sh']
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'copies files in bins key to .claude/scripts/' do
      cli.invoke(:squash, ['test_profile'])

      expect(File.exist?('.claude/scripts/deploy.sh')).to be(true)
      expect(File.executable?('.claude/scripts/deploy.sh')).to be(true)
    end
  end

  describe 'directory expansion for explicit keys' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'core'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'all-skills'))

      File.write(File.join(test_dir, 'rules', 'core', 'main.md'), '# Main')

      File.write(File.join(test_dir, 'rules', 'all-skills', 'a.md'), <<~MD)
        ---
        description: Skill A
        ---
        # Skill A
        Content A.
      MD

      File.write(File.join(test_dir, 'rules', 'all-skills', 'b.md'), <<~MD)
        ---
        description: Skill B
        ---
        # Skill B
        Content B.
      MD

      allow(cli).to receive_messages(
        gem_root: test_dir,
        profiles_file: File.join(test_dir, 'profiles.yml'),
        rules_dir: File.join(test_dir, 'rules')
      )

      profiles_content = {
        'test_profile' => {
          'description' => 'Test with skills directory',
          'files' => ['rules/core/main.md'],
          'skills' => [File.join(test_dir, 'rules', 'all-skills/')]
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'expands directories in skills key to individual skill files' do
      cli.invoke(:squash, ['test_profile'])

      expect(File.exist?('.claude/skills/a/SKILL.md')).to be(true)
      expect(File.exist?('.claude/skills/b/SKILL.md')).to be(true)
    end
  end
end
```

### Step 2: Run tests to verify they fail

Run: `bundle exec rspec spec/ruly/cli_profile_explicit_keys_spec.rb -v`
Expected: FAIL — `skills`, `commands`, `bins` keys not yet processed

### Step 3: Implement profile key processing in ProfileLoader

In `lib/ruly/services/profile_loader.rb`, update `load_profile_sources` to call new methods:

```ruby
def load_profile_sources(profile_name, gem_root:, base_profiles_file: nil,
                        profiles: nil, scan_files_for_profile_tags: nil)
  profiles ||= begin
    validate_profiles_file!(gem_root:)
    load_all_profiles(base_profiles_file:, gem_root:)
  end
  profile = validate_profile!(profile_name, profiles)

  sources = []

  process_profile_files(profile, sources, gem_root:)
  process_profile_skills(profile, sources, gem_root:)
  process_profile_commands(profile, sources, gem_root:)
  process_profile_bins(profile, sources, gem_root:)
  process_profile_sources(profile, sources, gem_root:)
  process_legacy_remote_sources(profile, sources)

  # Scan for files with matching profile tags in frontmatter
  if scan_files_for_profile_tags
    tagged_sources = scan_files_for_profile_tags.call(profile_name)
    existing_paths = sources.to_set { |s| s[:path] }
    tagged_sources.each do |tagged_source|
      sources << tagged_source unless existing_paths.include?(tagged_source[:path])
    end
  end

  [sources, profile]
end
```

Add three new methods:

```ruby
# Processes the 'skills' key from a profile config.
def process_profile_skills(profile, sources, gem_root:)
  return if profile.is_a?(Array)

  profile['skills']&.each do |file|
    full_path = find_rule_file(file, gem_root:)
    if full_path
      if File.directory?(full_path)
        find_markdown_files_recursively(full_path).each do |md_file|
          sources << {path: md_file, type: 'local', category: :skill}
        end
      else
        sources << {path: file, type: 'local', category: :skill}
      end
    else
      puts "\u26A0\uFE0F  Warning: Skill file not found: #{file}"
    end
  end
end

# Processes the 'commands' key from a profile config.
def process_profile_commands(profile, sources, gem_root:)
  return if profile.is_a?(Array)

  profile['commands']&.each do |file|
    full_path = find_rule_file(file, gem_root:)
    if full_path
      if File.directory?(full_path)
        find_markdown_files_recursively(full_path).each do |md_file|
          sources << {path: md_file, type: 'local', category: :command}
        end
      else
        sources << {path: file, type: 'local', category: :command}
      end
    else
      puts "\u26A0\uFE0F  Warning: Command file not found: #{file}"
    end
  end
end

# Processes the 'bins' key from a profile config.
def process_profile_bins(profile, sources, gem_root:)
  return if profile.is_a?(Array)

  profile['bins']&.each do |file|
    full_path = find_rule_file(file, gem_root:)
    if full_path
      if File.directory?(full_path)
        Dir.glob(File.join(full_path, '**', '*.sh')).each do |sh_file|
          relative = sh_file.start_with?(gem_root) ? sh_file.sub("#{gem_root}/", '') : sh_file
          sources << {path: relative, type: 'local', category: :bin}
        end
      else
        sources << {path: file, type: 'local', category: :bin}
      end
    else
      puts "\u26A0\uFE0F  Warning: Bin file not found: #{file}"
    end
  end
end
```

### Step 4: Run tests to verify they still fail (need SourceProcessor changes)

Run: `bundle exec rspec spec/ruly/cli_profile_explicit_keys_spec.rb -v`
Expected: Still failing — SourceProcessor doesn't use category markers yet

### Step 5: Commit

```bash
git add lib/ruly/services/profile_loader.rb spec/ruly/cli_profile_explicit_keys_spec.rb
git commit -m "feat: add skills, commands, bins key processing in ProfileLoader"
```

---

## Task 2: Replace path-based detection with marker-based in SourceProcessor

**Files:**
- Modify: `lib/ruly/services/source_processor.rb:196-227` (process_local_file)
- Modify: `lib/ruly/services/source_processor.rb:238-266` (display_prefetched_remote)
- Modify: `lib/ruly/services/source_processor.rb:276-298` (process_remote_file)

### Step 1: Write the failing test (already written in Task 1)

The test from Task 1 ("files in /skills/ path without skills key are squashed") covers this change.

### Step 2: Update `process_local_file`

Replace the path-based detection at lines 208, 218-219 with marker-based:

```ruby
def process_local_file(source, index, total, agent,
                       find_rule_file:, keep_frontmatter: false, verbose: false)
  prefix = source[:from_requires] ? "\u{1F4DA} Required" : "\u{1F4C1} Local"
  print "  [#{index + 1}/#{total}] #{prefix}: #{source[:path]}..." if verbose
  file_path = find_rule_file.call(source[:path])

  unless file_path
    verbose ? puts(' \u{274C} not found') : warn("  \u{26A0}\u{FE0F}  File not found: #{source[:path]}")
    return nil
  end

  # Use explicit category markers instead of path-based auto-detection
  is_bin = source[:category] == :bin

  if is_bin
    puts " \u{2705} (bin)" if verbose
    return {data: {relative_path: source[:path], source_path: file_path}, is_bin: true}
  end

  content = File.read(file_path, encoding: 'UTF-8')
  original_content = content
  content = Services::FrontmatterParser.strip_metadata(content, keep_frontmatter:)
  is_command = source[:category] == :command
  is_skill = source[:category] == :skill || source[:from_skills]

  tokens = count_tokens(content)
  formatted_tokens = format_token_count(tokens)

  print_file_progress(formatted_tokens, from_requires: source[:from_requires], is_command:, is_skill:,
                                        verbose:)
  {data: {content:, original_content:, path: source[:path]}, is_command:, is_skill:}
end
```

### Step 3: Update `display_prefetched_remote`

Replace lines 260-261:

```ruby
is_command = source[:category] == :command
is_skill = source[:category] == :skill || source[:from_skills]
```

### Step 4: Update `process_remote_file`

Replace lines 293-294:

```ruby
is_command = source[:category] == :command
is_skill = source[:category] == :skill || source[:from_skills]
```

### Step 5: Run tests

Run: `bundle exec rspec spec/ruly/cli_profile_explicit_keys_spec.rb -v`
Expected: PASS

### Step 6: Run existing tests to check for regressions

Run: `bundle exec rspec spec/ -v`
Expected: Some tests in `cli_skills_frontmatter_spec.rb` and `cli_bin_files_spec.rb` will fail because they rely on path-based auto-detection. We'll fix these in Task 4.

### Step 7: Commit

```bash
git add lib/ruly/services/source_processor.rb
git commit -m "feat: replace path-based auto-detection with marker-based categorization"
```

---

## Task 3: Relax skill path validation in DependencyResolver

**Files:**
- Modify: `lib/ruly/services/dependency_resolver.rb:102-111` (validate_skill!)

### Step 1: Write the failing test

Add to `spec/ruly/cli_profile_explicit_keys_spec.rb`:

```ruby
describe 'skills: frontmatter referencing files outside /skills/ directory' do
  before do
    FileUtils.mkdir_p(File.join(test_dir, 'rules', 'core'))
    FileUtils.mkdir_p(File.join(test_dir, 'rules', 'shared'))

    File.write(File.join(test_dir, 'rules', 'shared', 'helper-skill.md'), <<~MD)
      ---
      description: Helper skill
      ---
      # Helper Skill
      Helper content.
    MD

    File.write(File.join(test_dir, 'rules', 'core', 'main.md'), <<~MD)
      ---
      skills:
        - ../shared/helper-skill.md
      ---
      # Main Rule
      References a skill.
    MD

    allow(cli).to receive_messages(
      gem_root: test_dir,
      profiles_file: File.join(test_dir, 'profiles.yml'),
      rules_dir: File.join(test_dir, 'rules')
    )

    profiles_content = {
      'test_profile' => {
        'description' => 'Test with skill outside /skills/',
        'files' => ['rules/core/main.md']
      }
    }

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
    # rubocop:enable RSpec/AnyInstance
  end

  it 'allows skills: frontmatter to reference files outside /skills/ directory' do
    expect { cli.invoke(:squash, ['test_profile']) }.not_to raise_error
  end

  it 'creates SKILL.md for frontmatter-referenced skills' do
    cli.invoke(:squash, ['test_profile'])
    expect(File.exist?('.claude/skills/helper-skill/SKILL.md')).to be(true)
  end
end
```

### Step 2: Run test to verify it fails

Run: `bundle exec rspec spec/ruly/cli_profile_explicit_keys_spec.rb -t "allows skills: frontmatter" -v`
Expected: FAIL with "must be in a /skills/ directory"

### Step 3: Update `validate_skill!` to remove path restriction

In `lib/ruly/services/dependency_resolver.rb`, replace the `validate_skill!` method:

```ruby
def validate_skill!(skill_path, resolved, source, _find_rule_file)
  raise Ruly::Error, "Skill file not found: '#{skill_path}' referenced from '#{source[:path]}'" unless resolved
end
```

### Step 4: Run tests

Run: `bundle exec rspec spec/ruly/cli_profile_explicit_keys_spec.rb -v`
Expected: PASS

### Step 5: Update `save_skill_files` to handle skills without `/skills/` in path

The `save_skill_files` method in `script_manager.rb:377` uses `file[:path].split('/skills/').last` to derive the skill name. This will break for files not in a `/skills/` directory. Update it to fall back to the filename:

In `lib/ruly/services/script_manager.rb`, update `save_skill_files`:

```ruby
def save_skill_files(skill_files, find_rule_file:, parse_frontmatter:, strip_metadata:)
  return if skill_files.empty?

  skill_files.each do |file|
    skill_name = if file[:path].include?('/skills/')
                   file[:path].split('/skills/').last.sub(/\.md$/, '')
                 else
                   File.basename(file[:path], '.md')
                 end
    skill_dir = ".claude/skills/#{skill_name}"
    FileUtils.mkdir_p(skill_dir)

    content = compile_skill_with_requires(file, find_rule_file:, parse_frontmatter:, strip_metadata:)
    File.write(File.join(skill_dir, 'SKILL.md'), content)
  end
end
```

Also update `extract_skill_names` in `subagent_processor.rb:217-219`:

```ruby
def extract_skill_names(skill_files)
  skill_files.map do |file|
    if file[:path].include?('/skills/')
      file[:path].split('/skills/').last.sub(/\.md$/, '')
    else
      File.basename(file[:path], '.md')
    end
  end
end
```

### Step 6: Run tests

Run: `bundle exec rspec spec/ruly/cli_profile_explicit_keys_spec.rb -v`
Expected: PASS

### Step 7: Commit

```bash
git add lib/ruly/services/dependency_resolver.rb lib/ruly/services/script_manager.rb lib/ruly/services/subagent_processor.rb spec/ruly/cli_profile_explicit_keys_spec.rb
git commit -m "feat: relax skill path validation, support skills from any directory"
```

---

## Task 4: Fix existing tests that relied on path-based auto-detection

**Files:**
- Modify: `spec/ruly/cli_skills_frontmatter_spec.rb`
- Modify: `spec/cli_bin_files_spec.rb`

### Step 1: Run all tests

Run: `bundle exec rspec spec/ -v`
Expected: Identify which tests fail

### Step 2: Fix `cli_skills_frontmatter_spec.rb`

The frontmatter `skills:` tests should still pass because `from_skills: true` is set on resolved skill sources. Verify and fix any failures.

The key change: the test "when skills: references a file not in a /skills/ directory" should now PASS (not raise error), since we relaxed the validation. Update this test:

```ruby
context 'when skills: references a file not in a /skills/ directory' do
  # ...setup unchanged...

  it 'allows skill references to files outside /skills/ directory' do
    expect { cli.invoke(:squash, ['test_bad_path']) }.not_to raise_error
  end

  it 'creates SKILL.md for files outside /skills/ directory' do
    cli.invoke(:squash, ['test_bad_path'])
    expect(File.exist?('.claude/skills/helpers/SKILL.md')).to be(true)
  end
end
```

### Step 3: Fix `cli_bin_files_spec.rb`

Bins are no longer auto-detected by path. Update the profile to use `scripts:` key:

```ruby
let(:profile_content) do
  <<~YAML
    profiles:
      test_with_bin:
        description: "Test profile with bin files"
        scripts:
          - rules/bin/
  YAML
end
```

Also update the bin file detection tests to reflect the new behavior (no auto-detection).

### Step 4: Run all tests

Run: `bundle exec rspec spec/ -v`
Expected: ALL PASS

### Step 5: Commit

```bash
git add spec/ruly/cli_skills_frontmatter_spec.rb spec/cli_bin_files_spec.rb
git commit -m "fix: update tests for explicit profile keys (remove path auto-detection)"
```

---

## Task 5: Update `MERGE_SKIP_KEYS` and Display

**Files:**
- Modify: `lib/ruly/cli.rb:15` (MERGE_SKIP_KEYS)
- Modify: `lib/ruly/services/display.rb:141-156` (collect_profile_display_files)

### Step 1: Update `MERGE_SKIP_KEYS`

In `lib/ruly/cli.rb`, update line 15:

```ruby
MERGE_SKIP_KEYS = %w[files sources skills commands bins].freeze
```

### Step 2: Update `collect_profile_display_files`

In `lib/ruly/services/display.rb`, update to include new keys:

```ruby
def collect_profile_display_files(config)
  all_files = Array(config['files']).dup
  all_files.concat(Array(config['skills']))
  all_files.concat(Array(config['commands']))
  all_files.concat(Array(config['bins']))
  config['sources']&.each do |source|
    if source.is_a?(Hash)
      if source['github']
        source['rules']&.each { |rule| all_files << "https://github.com/#{source['github']}/#{rule}" }
      elsif source['local']
        all_files.concat(source['local'])
      end
    else
      all_files << source
    end
  end
  all_files.concat(config['remote_sources']) if config['remote_sources']
  all_files
end
```

### Step 3: Run tests

Run: `bundle exec rspec spec/ -v`
Expected: ALL PASS

### Step 4: Commit

```bash
git add lib/ruly/cli.rb lib/ruly/services/display.rb
git commit -m "feat: add skills/commands/bins to MERGE_SKIP_KEYS and display"
```

---

## Task 6: Update profiles.yml to use explicit keys

**Files:**
- Modify: `/Users/patrick/Projects/ruly/profiles.yml`
- Modify: `/Users/patrick/.config/ruly/profiles.yml` (must match)

### Step 1: Audit current profiles for files that need moving

Scan all profiles for files currently in `files:` that have `/skills/`, `/commands/`, or `bin/` in their paths. These need to be moved to the appropriate explicit key.

**Files with `/skills/` in path (currently auto-detected as skills):**

Check each profile — files like `rules/bug/skills/debugging.md` or `rules/github/pr/skills/pr-review-loop.md` that are in `files:`. These may be intentionally squashed (not skills) or may need moving.

**Decision rule:** If a file was being used as a Claude Code skill (output as SKILL.md), move it to `skills:`. If it was meant to be squashed content (inlined into CLAUDE.local.md), leave it in `files:`.

Looking at the profiles:
- Most `/skills/` files in `files:` are intentionally squashed (e.g., `rules/bug/skills/debugging.md` appears in many profiles as squashed content)
- Files in `core-engineer-skilled` profile's `files:` that are explicitly labeled "Compiled Skills (loaded on demand via Skill tool)" should move to `skills:`

**Files with `/commands/` in path (currently auto-detected as commands):**

All files with `/commands/` in path under `files:` are currently auto-detected as commands. Move them to `commands:` key.

**Files with `bin/` in path:**

No profiles currently list bin files directly in `files:` — they come through directory expansion. The `scripts:` key handles this now.

### Step 2: Update `profiles.yml`

For each profile, move files from `files:` to the appropriate key. Example for the `core` profile:

```yaml
core:
  description: "WorkAxle development dispatcher - routes tasks to specialized subagents"
  omit_command_prefix:
    - comms/github
    - github
    - comms
  files:
    # === WorkAxle Core ===
    - /Users/patrick/Projects/ruly/rules/workaxle/core.md
    # ... (non-command, non-skill files stay here)
  skills:
    - /Users/patrick/Projects/ruly/rules/github/pr/skills/pr-review-loop.md
    - /Users/patrick/Projects/ruly/rules/git/skills/rebase-and-squash.md
  commands:
    - /Users/patrick/Projects/ruly/rules/github/pr/commands/create.md
    - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-develop.md
    - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-dual.md
    - /Users/patrick/Projects/ruly/rules/comms/commands/refresh-context.md
  # ... rest unchanged
```

**Important:** Apply this pattern to EVERY profile in the file. Check each file path and move to the correct key.

### Step 3: Copy updated profiles.yml to user config

```bash
cp /Users/patrick/Projects/ruly/profiles.yml /Users/patrick/.config/ruly/profiles.yml
```

Wait — the user config may differ. Read both files and reconcile.

### Step 4: Test with a squash from a temp directory

```bash
cd $(mktemp -d)
ruly squash --profile core --dry-run --verbose
```

Verify that:
- Command files show as "Would create command files"
- Skill files show as "Would create skill files"
- Files in `files:` show as regular rules

### Step 5: Commit

```bash
git add profiles.yml
git commit -m "chore: migrate profiles.yml to explicit skills/commands/bins keys"
```

---

## Task 7: Update the local directory processing to not auto-include bins

**Files:**
- Modify: `lib/ruly/services/profile_loader.rb:267-287` (process_local_directory)

### Step 1: Remove auto-inclusion of `bin/*.sh` files from directory expansion

Currently `process_local_directory` auto-includes `bin/**/*.sh` files. Since bins now need explicit `scripts:` key, remove this:

```ruby
def process_local_directory(directory_path, sources, gem_root:)
  Dir.glob(File.join(directory_path, '**', '*.md')).each do |file|
    relative_path = if file.start_with?(gem_root)
                      file.sub("#{gem_root}/", '')
                    else
                      file
                    end
    sources << {path: relative_path, type: 'local'}
  end
  # Removed: auto-inclusion of bin/*.sh files
end
```

### Step 2: Run tests

Run: `bundle exec rspec spec/ -v`
Expected: ALL PASS (bin tests already updated in Task 4)

### Step 3: Commit

```bash
git add lib/ruly/services/profile_loader.rb
git commit -m "feat: remove auto-inclusion of bin/*.sh from directory expansion"
```

---

## Task 8: Handle `commands:` relative path calculation

**Files:**
- Modify: `lib/ruly/services/script_manager.rb:241-286` (save_command_files)

### Step 1: Update command path calculation for non-`/commands/` paths

Currently `get_command_relative_path` assumes the file path contains `/commands/`. For files specified via the profile `commands:` key, the path might not contain `/commands/`. Update to handle this:

```ruby
def get_command_relative_path(file_path, omit_prefix = nil)
  if file_path.include?('/commands/')
    # existing logic unchanged
    # ...
  else
    # For files from profile commands: key, use basename
    File.basename(file_path)
  end
end
```

This already works as the existing fallback (line 322: `File.basename(file_path)`). Verify with tests.

### Step 2: Run tests

Run: `bundle exec rspec spec/ruly/cli_profile_explicit_keys_spec.rb -v`
Expected: PASS

### Step 3: Commit (if changes needed)

```bash
git add lib/ruly/services/script_manager.rb
git commit -m "fix: handle command paths without /commands/ directory"
```

---

## Task 9: Final integration testing

### Step 1: Run the full test suite

Run: `bundle exec rspec spec/ -v`
Expected: ALL PASS

### Step 2: Test end-to-end with a real profile

```bash
cd $(mktemp -d)
RULY_HOME=/Users/patrick/Projects/ruly ruly squash --profile core --verbose
```

Verify:
- Skills are in `.claude/skills/`
- Commands are in `.claude/commands/`
- Main output in `CLAUDE.local.md` contains only `files:` content
- No auto-detection warnings

### Step 3: Reinstall ruly

```bash
cd /Users/patrick/Projects/ruly && bundle exec rake install
```

### Step 4: Final commit

```bash
git add -A
git commit -m "feat: explicit profile keys for skills, commands, and bins

Replaces path-based auto-inference with explicit profile keys:
- skills: → .claude/skills/{name}/SKILL.md
- commands: → .claude/commands/{name}.md
- scripts: → .claude/scripts/{name}.sh

Files in 'files:' are always squashed into main output regardless of path.
Frontmatter 'skills:' references still work (already explicit, not auto-inferred).
Skill path validation relaxed — skills can live in any directory."
```
