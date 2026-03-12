# Squash Verbose Output Refactor

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `ruly squash` output concise by default, showing only recipe/subagent/error/summary info; move per-file details behind `-v`/`--verbose`.

**Architecture:** Add a `--verbose` flag to the squash CLI option, thread a `verbose?` helper through the output methods, and gate per-file lines behind it. No structural changes to processing logic — only output gating.

**Tech Stack:** Ruby, Thor CLI framework, RSpec

---

## Default (non-verbose) output target

```
🧹 Cleaned up files:
   - .claude/
   - CLAUDE.local.md
   - .mcp.json

📚 Processing 27 sources (use -v for details)...
🔌 Updated .mcp.json with MCP servers

🤖 Processing subagents...
  → bug (14 sources)
  → feature (35 sources)
  → context_fetcher (3 sources)
  → core_debugging (9 sources)
  → comms (22 sources)
  → merger (10 sources)
  → dashboard (3 sources)
  → pr_readiness (4 sources)
  → architect (21 sources)
✅ Generated 9 subagent(s)

✅ Successfully generated CLAUDE.local.md using squash mode with 'core' recipe
📊 Combined 27 files
📏 Output size: 53065 bytes
🧮 Token count: 12,769 / 200,000 (6.4%) 🟢
📁 Saved 8 command files to .claude/commands/ (with subdirectories)
🎯 Saved 2 skill files to .claude/skills/
```

Errors/warnings always print regardless of verbosity.

---

### Task 1: Add `--verbose` flag and `verbose?` helper

**Files:**
- Modify: `lib/ruly/cli.rb:56` (add option before method def)
- Modify: `lib/ruly/cli.rb` (add `verbose?` helper near other helpers)

**Step 1: Add the CLI option**

Add after line 56 (after `option :home_override`):

```ruby
option :verbose, aliases: '-v', default: false, desc: 'Show detailed per-file processing output', type: :boolean
```

**Step 2: Add `verbose?` helper method**

Add a private helper method near the other utility methods (around the `print_summary` area):

```ruby
def verbose?
  options[:verbose] || ENV['DEBUG']
end
```

**Step 3: Run tests to verify nothing broke**

Run: `bundle exec rspec spec/ruly/cli_spec.rb --no-color 2>&1 | tail -5`
Expected: All existing tests still pass.

**Step 4: Commit**

```bash
git add lib/ruly/cli.rb
git commit -m "feat: add --verbose/-v flag to squash command"
```

---

### Task 2: Gate per-file output in `process_sources_for_squash`

**Files:**
- Modify: `lib/ruly/cli.rb:1646` (source count line)

**Step 1: Change the "Processing N sources" line to show hint when not verbose**

Replace line 1646:
```ruby
puts "\n📚 Processing #{sources.length} sources..."
```
with:
```ruby
if verbose?
  puts "\n📚 Processing #{sources.length} sources..."
else
  puts "\n📚 Processing #{sources.length} sources (use -v for details)..."
end
```

**Step 2: Commit**

```bash
git add lib/ruly/cli.rb
git commit -m "feat: add verbose hint to source count line"
```

---

### Task 3: Gate per-file output in local file processing

**Files:**
- Modify: `lib/ruly/cli.rb:1886-1928` (`process_local_file_with_progress`)

**Step 1: Wrap the print/puts lines in verbose check**

The method currently prints per-file progress unconditionally. Gate all the `print`/`puts` output lines behind `verbose?`, but keep the error case (`❌ not found`) always visible.

In `process_local_file_with_progress`, change:

```ruby
print "  [#{index + 1}/#{total}] #{prefix}: #{source[:path]}..."
```

Wrap this and the subsequent status `puts` calls (lines 1889-1921) in `if verbose?`. The `❌ not found` on line 1925 should always print.

Result should look like:

```ruby
def process_local_file_with_progress(source, index, total, agent, keep_frontmatter: false)
  prefix = source[:from_requires] ? '📚 Required' : '📁 Local'
  print "  [#{index + 1}/#{total}] #{prefix}: #{source[:path]}..." if verbose?
  file_path = find_rule_file(source[:path])

  if file_path
    is_bin = source[:path].match?(%r{bin/.*\.sh$}) || file_path.match?(%r{bin/.*\.sh$})

    if is_bin
      puts ' ✅ (bin)' if verbose?
      {data: {relative_path: source[:path], source_path: file_path}, is_bin: true}
    else
      content = File.read(file_path, encoding: 'UTF-8')
      original_content = content
      content = strip_metadata_from_frontmatter(content, keep_frontmatter:)
      is_command = agent == 'claude' && (file_path.include?('/commands/') || source[:path].include?('/commands/'))
      is_skill = agent == 'claude' && source[:path].include?('/skills/')

      tokens = count_tokens(content)
      formatted_tokens = tokens.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')

      if verbose?
        if is_skill
          puts " ✅ (skill, #{formatted_tokens} tokens)"
        elsif is_command
          puts " ✅ (command, #{formatted_tokens} tokens)"
        elsif source[:from_requires]
          puts " ✅ (from requires, #{formatted_tokens} tokens)"
        else
          puts " ✅ (#{formatted_tokens} tokens)"
        end
      end
      {data: {content:, original_content:, path: source[:path]}, is_command:, is_skill:}
    end
  else
    # Errors always print
    puts " ❌ not found" if verbose?
    $stderr.puts "  ⚠️  File not found: #{source[:path]}" unless verbose?
    nil
  end
end
```

**Step 2: Run tests**

Run: `bundle exec rspec spec/ruly/cli_spec.rb --no-color 2>&1 | tail -5`
Expected: All tests still pass.

**Step 3: Commit**

```bash
git add lib/ruly/cli.rb
git commit -m "feat: gate local file progress output behind --verbose"
```

---

### Task 4: Gate per-file output in remote file processing

**Files:**
- Modify: `lib/ruly/cli.rb:1997-2036` (`display_prefetched_remote`)
- Modify: `lib/ruly/cli.rb:2038-2076` (`process_remote_file_with_progress`)

**Step 1: Gate `display_prefetched_remote` output**

Same pattern as Task 3. Wrap the `print` (line 2011) and subsequent `puts` lines (2025-2033) in `if verbose?`.

**Step 2: Gate `process_remote_file_with_progress` output**

Same pattern. Wrap `print` (line 2056) and subsequent `puts` lines (2071-2076) in `if verbose?`. Keep error output (fetch failures) always visible.

**Step 3: Gate batch fetch output**

In `prefetch_remote_files` (around line 1715), wrap the batch fetching progress lines in `if verbose?`:
```ruby
puts "  🔄 Batch fetching #{repo_sources.size} files from #{repo_key}..." if verbose?
# ...
puts "    ✅ Successfully fetched #{batch_content.size} files" if verbose?
```

Keep the `⚠️ Batch fetch failed` warning always visible.

**Step 4: Run tests**

Run: `bundle exec rspec spec/ruly/cli_spec.rb --no-color 2>&1 | tail -5`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add lib/ruly/cli.rb
git commit -m "feat: gate remote file progress output behind --verbose"
```

---

### Task 5: Gate requires discovery output

**Files:**
- Modify: `lib/ruly/cli.rb:1864` (`process_single_source_with_requires`)

**Step 1: Gate the "Found N requires" line**

Change line 1864:
```ruby
puts "    → Found #{required_sources.length} requires, adding to queue..."
```
to:
```ruby
puts "    → Found #{required_sources.length} requires, adding to queue..." if verbose?
```

**Step 2: Commit**

```bash
git add lib/ruly/cli.rb
git commit -m "feat: gate requires discovery output behind --verbose"
```

---

### Task 6: Slim subagent output in non-verbose mode

**Files:**
- Modify: `lib/ruly/cli.rb:2769-2802` (`process_subagents`)
- Modify: `lib/ruly/cli.rb:2916` (`save_subagent_commands`)

**Step 1: Change subagent processing to show compact output**

In `process_subagents`, the current verbose per-agent line is:
```
  → Generating bug.md from 'bug' recipe
```

In non-verbose mode, show just the agent name and source count instead. The source count is available after `load_agent_sources` runs in `generate_agent_file`. To avoid restructuring, pass verbose through and show a compact line.

Replace lines 2784 in `process_subagents`:
```ruby
puts "  → Generating #{agent_name}.md from '#{recipe_name}' recipe"
```
with:
```ruby
if verbose?
  puts "  → Generating #{agent_name}.md from '#{recipe_name}' recipe"
else
  print "  → #{agent_name}"
end
```

**Step 2: Gate the per-subagent "Saved N command files" output**

Change line 2916:
```ruby
puts "    📁 Saved #{command_files.size} command file(s) to .claude/commands/#{agent_name}/"
```
to:
```ruby
puts "    📁 Saved #{command_files.size} command file(s) to .claude/commands/#{agent_name}/" if verbose?
```

**Step 3: Add newline after compact subagent list**

After the `recipe_config['subagents'].each` block ends (before the "Generated N subagent(s)" line), add:
```ruby
puts unless verbose? # newline after compact agent list
```

**Step 4: Keep warnings always visible**

The `⚠️  Warning:` lines (2791, 2812, 2918) should always print — no changes needed there.

**Step 5: Run tests**

Run: `bundle exec rspec spec/ruly/cli_spec.rb --no-color 2>&1 | tail -5`
Expected: All tests pass.

**Step 6: Commit**

```bash
git add lib/ruly/cli.rb
git commit -m "feat: slim subagent output in non-verbose mode"
```

---

### Task 7: Gate MCP output

**Files:**
- Modify: `lib/ruly/cli.rb:2685-2709` (`update_mcp_settings`)
- Modify: `lib/ruly/cli.rb:285` (MCP propagation line)

**Step 1: Gate MCP detail output**

The MCP update confirmation lines should show in non-verbose mode (they're just one line each), but the propagation detail can be gated. Actually, the MCP lines are brief enough to keep. Leave them as-is — they're just 1-2 lines total.

No changes needed here. Skip this task.

---

### Task 8: Write a test for verbose vs non-verbose output

**Files:**
- Modify: `spec/ruly/cli_spec.rb`

**Step 1: Add a test for default (non-verbose) output**

Add a new describe block to `cli_spec.rb`:

```ruby
describe '#squash verbose output' do
  before do
    # Create a minimal rules file
    FileUtils.mkdir_p('rules')
    File.write('rules/test.md', "# Test Rule\nSome content here.")

    # Create a minimal recipe
    File.write('recipes.yml', {
      'recipes' => {
        'test-verbose' => {
          'files' => ["#{test_dir}/rules/test.md"]
        }
      }
    }.to_yaml)
  end

  it 'does not show per-file details without --verbose' do
    output = capture_output { cli.invoke(:squash, ['test-verbose']) }
    expect(output).to include('Processing')
    expect(output).to include('use -v for details')
    expect(output).not_to match(/\[1\//)  # No [1/N] file listings
  end

  it 'shows per-file details with --verbose' do
    verbose_cli = described_class.new([], {verbose: true})
    output = capture_output { verbose_cli.invoke(:squash, ['test-verbose']) }
    expect(output).to match(/\[1\//)  # Has [1/N] file listings
  end
end
```

**Step 2: Run the new test**

Run: `bundle exec rspec spec/ruly/cli_spec.rb -e 'verbose output' --no-color 2>&1 | tail -10`
Expected: Both tests pass.

**Step 3: Run full test suite**

Run: `bundle exec rspec --no-color 2>&1 | tail -5`
Expected: All tests pass.

**Step 4: Commit**

```bash
git add spec/ruly/cli_spec.rb lib/ruly/cli.rb
git commit -m "test: add verbose output tests for squash command"
```

---

### Task 9: Update README.md

**Files:**
- Modify: `README.md`

**Step 1: Add `-v`/`--verbose` to the squash command documentation**

Find the squash command section in README.md and add the new flag to the options table/list.

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add --verbose flag to squash command docs"
```

---

### Task 10: Update installed ruly binary

**Step 1: Rebuild and install**

Run: `cd /Users/patrick/Projects/ruly && bundle exec rake install 2>&1 || gem build ruly.gemspec && gem install ruly-*.gem`

**Step 2: Verify**

Run: `ruly squash --help | grep verbose`
Expected: Shows the `--verbose` / `-v` option.

**Step 3: Manual smoke test**

Run from a temp dir:
```bash
cd $(mktemp -d) && ruly squash --deepclean core 2>&1 | head -20
```
Expected: Compact output without per-file details.

Then with verbose:
```bash
cd $(mktemp -d) && ruly squash --deepclean -v core 2>&1 | head -40
```
Expected: Full per-file output as before.
