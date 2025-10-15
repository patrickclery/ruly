# PRD: Recipe Subagents Feature for Ruly

## Overview

Add support for generating Claude Code agent files from recipes in `ruly`, a Ruby-based project management tool. This feature extends the existing `ruly squash` command to automatically generate `.claude/agents/{name}.md` files when a recipe defines subagents, with proper MCP server configuration.

## Problem Statement

Currently, to create a Claude Code agent in `ruly`, users must:

1. Manually create agent markdown files in `.claude/agents/`
2. Manually configure MCP servers in `.mcp.json`
3. Manually keep agent content synchronized with recipe changes

This is error-prone and doesn't leverage the existing Ruby-based recipe system and `ruly squash` command.

## Proposed Solution

Extend the existing `ruly squash` command to support a `subagents` key in recipes. When a recipe is squashed, if it contains a `subagents` array, each referenced recipe will be squashed into `.claude/agents/{name}.md` instead of (or in addition to) the main output. A recipe can serve as either:

- **Root node**: Squashed into the main output (e.g., `CLAUDE.md`)
- **Subagent**: Squashed into `.claude/agents/{name}.md` when referenced by another recipe's `subagents` key

## User Stories

### Story 1: Define Subagents in Recipe

**As a** developer
**I want to** define subagents in my recipe configuration
**So that** I can automatically generate agent files without manual creation

**Acceptance Criteria:**

- Can define `subagents` array in any recipe
- Each subagent requires `name` and `recipe` fields
- Configuration validates that referenced recipe exists

### Story 2: Generate Agent Files

**As a** developer
**I want** subagent recipes to be squashed into agent files
**So that** agents have all the context they need from the recipe

**Acceptance Criteria:**

- Generates `.claude/agents/{name}.md` file for each subagent
- Agent file contains all content from referenced recipe (files, sources, etc.)
- Agent file includes proper YAML frontmatter with:
  - `name`: Agent identifier
  - `description`: When to invoke this agent
  - `tools`: Set to `inherit`
  - `model`: Set to `inherit`
  - Generation metadata in comments
- Agent file body contains squashed recipe content and usage instructions

### Story 3: MCP Server Integration

**As a** developer
**I want** subagent MCP servers to be added to the main `.mcp.json`
**So that** agents have access to required tools

**Acceptance Criteria:**

- MCP servers from subagent recipe are added to main `.mcp.json`
- No duplicate MCP server entries
- MCP server configuration is preserved

### Story 4: Prevent Infinite Loops

**As a** developer
**I want** protection against circular recipe references
**So that** the system doesn't crash or hang

**Acceptance Criteria:**

- Detects circular references (Recipe A → Recipe B → Recipe A)
- Prevents infinite recursion when processing subagents
- Shows clear error message when circular reference detected

## Technical Specification

### Configuration Schema

The `ruly` recipe configuration in `~/.config/ruly/recipes.yml` will support the following schema:

```yaml
recipes:
  parent_recipe:
    description: Main recipe description
    files:
      - /path/to/file1.md
      - /path/to/file2.md
    mcp_servers:
      - github
      - atlassian
    subagents:
      - name: agent_name        # Required: Name of the agent file (without .md)
        recipe: recipe_key      # Required: Recipe key to squash into agent
        # Future: Optional fields for customization
        # tools: Read, Write, Bash  # Override default tools
        # model: opus               # Override default model
      - name: another_agent
        recipe: another_recipe
```

**Initial Implementation**: In the first version, `tools` and `model` will default to `inherit`. Future enhancements will allow per-subagent customization.

### Ruby Implementation Components

The implementation will extend existing components and add new subagent-specific classes:

**Extended Components:**

- `Ruly::Squasher` - Extend to detect and process `subagents` key during squash operation

**New Components:**

- `Ruly::Subagent::Generator` - Generate agent markdown files from recipes
- `Ruly::Subagent::McpMerger` - Merge MCP server configurations
- `Ruly::Subagent::CircularReferenceDetector` - Prevent infinite loops in recipe references
- `Ruly::Subagent::Validator` - Validate subagent configuration

### Ruby Gem Dependencies

```ruby
# Gemfile additions
gem 'dry-validation', '~> 1.10'  # Schema validation
gem 'dry-struct', '~> 1.6'       # Type-safe recipe objects
gem 'tty-prompt', '~> 0.23'      # CLI prompts for validation errors
```

### Project File Structure

```
lib/ruly/
├── squasher.rb                   # Existing - extend to handle subagents
├── subagent/
│   ├── generator.rb              # Ruly::Subagent::Generator
│   ├── mcp_merger.rb             # Ruly::Subagent::McpMerger
│   ├── circular_reference_detector.rb  # Ruly::Subagent::CircularReferenceDetector
│   └── validator.rb              # Ruly::Subagent::Validator
└── errors.rb                     # Custom exception classes

spec/ruly/subagent/
├── generator_spec.rb
├── mcp_merger_spec.rb
├── circular_reference_detector_spec.rb
└── validator_spec.rb
```

**Note**: The existing `Ruly::Squasher` class will be extended to detect and process `subagents` during the normal squash operation.

### Agent File Format

Generated `.claude/agents/{name}.md` files follow the Claude Code subagent format with YAML frontmatter:

```markdown
---
name: {agent_name}
description: {recipe.description}
tools: inherit  # Inherits all tools from parent Claude Code session
model: inherit  # Uses same model as parent session
# Auto-generated from recipe: {recipe_key}
# Do not edit manually - regenerate using 'ruly squash {parent_recipe}'
---

# {Agent Name (title case from subagent.name)}

{recipe.description}

## Recipe Content

{squashed content from all recipe files and sources}

## MCP Servers

This subagent has access to the following MCP servers:
{list of mcp_servers from recipe}

---
*Last generated: {timestamp}*
*Source recipe: {recipe_key}*
```

### Frontmatter Fields

- `name`: Agent identifier (from `subagent.name` in recipe)
- `description`: When to invoke this subagent (from `recipe.description`)
- `tools`: Set to `inherit` by default (can be customized per subagent in future)
- `model`: Set to `inherit` by default (uses parent session's model)

### MCP Server Merging

When processing subagents:

1. Collect all `mcp_servers` from subagent recipe
2. Merge with existing `.mcp.json` entries
3. Preserve existing server configurations
4. Add new servers with default configuration

### Circular Reference Prevention

Ruby implementation integrated with `Ruly::Squasher`:

```ruby
module Ruly
  class Squasher
    def squash(recipe_name)
      recipe = load_recipe(recipe_name)

      # Main squash logic (existing)
      output = generate_squashed_content(recipe)
      write_output(output)

      # Process subagents if present
      if recipe.subagents&.any?
        detector = Subagent::CircularReferenceDetector.new
        detector.process_subagents(recipe)
      end
    end
  end

  module Subagent
    class CircularReferenceDetector
      def process_subagents(recipe, visited = Set.new)
        if visited.include?(recipe.key)
          raise CircularReferenceError, "Circular reference detected in recipe chain"
        end

        visited.add(recipe.key)

        recipe.subagents.each do |subagent|
          target_recipe = load_recipe(subagent['recipe'])

          # Recursively check for circular references
          if target_recipe.subagents&.any?
            process_subagents(target_recipe, visited.dup)
          end

          # Generate subagent file
          Generator.generate_agent_file(subagent['name'], target_recipe)
          McpMerger.merge_servers(target_recipe.mcp_servers)
        end

        visited.delete(recipe.key)
      end
    end
  end
end
```

## Implementation Plan

### Phase 1: Extend Squash Command (Ruby)

- Modify `Ruly::Squasher#squash` to detect `subagents` key in recipe
- Add logic to process subagents after main recipe squash
- Ensure backward compatibility - squash works the same without subagents
- Add `Ruly::Subagent::Validator` to validate subagent configuration

### Phase 2: Agent File Generation (Ruby)

- Create `Ruly::Subagent::Generator` class
- Reuse existing recipe squashing logic from `Ruly::Squasher`
- Generate files in project's `.claude/agents/` directory
- Add YAML frontmatter following Claude Code subagent format:
  - `name`: From subagent configuration
  - `description`: From recipe description (when to invoke)
  - `tools`: Default to `inherit`
  - `model`: Default to `inherit`
  - Comments for source recipe and generation timestamp
- Generate markdown body with squashed recipe content

### Phase 3: MCP Integration (Ruby)

- Create `Ruly::Subagent::McpMerger` to merge MCP server configurations
- Use JSON gem to read/write `.mcp.json` files
- Preserve existing server configurations using deep merge
- Collect MCP servers from all subagent recipes

### Phase 4: Circular Reference Detection (Ruby)

- Implement `Ruly::Subagent::CircularReferenceDetector` class
- Use Ruby Set for visited recipe tracking
- Create custom `CircularReferenceError` exception class
- Generate clear error messages with recipe chain path
- Integrate into squash command flow

### Phase 5: Testing & Documentation (RSpec)

- RSpec unit tests for each new component class
- Integration tests with sample recipe YAML files
- Test that existing `ruly squash` behavior is unchanged
- Test circular reference detection edge cases
- Update `README.md` with subagent examples
- Add inline documentation using YARD comments

## Testing Strategy

### Unit Tests (RSpec)

```ruby
# spec/ruly/subagent/generator_spec.rb
RSpec.describe Ruly::Subagent::Generator do
  describe '#generate_agent_file' do
    let(:recipe) { build(:recipe, :with_files) }
    let(:agent_name) { 'test_agent' }

    it 'creates agent file in .claude/agents/' do
      expect {
        described_class.generate_agent_file(agent_name, recipe)
      }.to change { File.exist?(".claude/agents/#{agent_name}.md") }.to(true)
    end

    it 'includes recipe description in agent file' do
      described_class.generate_agent_file(agent_name, recipe)
      content = File.read(".claude/agents/#{agent_name}.md")
      expect(content).to include(recipe.description)
    end
  end
end
```

### Integration Tests

```ruby
# spec/integration/subagent_generation_spec.rb
RSpec.describe 'Subagent Generation via Squash', type: :integration do
  let(:recipes_yml) do
    <<~YAML
      recipes:
        parent:
          description: Parent recipe
          subagents:
            - name: child_agent
              recipe: child
        child:
          description: Child recipe
          files:
            - /path/to/file.md
    YAML
  end

  before do
    File.write('~/.config/ruly/recipes.yml', recipes_yml)
  end

  it 'generates subagents when squashing recipe with subagents' do
    expect {
      Ruly::CLI.start(['squash', 'parent'])
    }.to change {
      Dir['.claude/agents/*.md'].count
    }.by(1)
  end

  it 'does not generate subagents when squashing recipe without subagents' do
    expect {
      Ruly::CLI.start(['squash', 'child'])
    }.not_to change {
      Dir['.claude/agents/*.md'].count
    }
  end
end
```

### Circular Reference Tests

```ruby
RSpec.describe Ruly::Subagent::CircularReferenceDetector do
  it 'raises error on circular reference' do
    recipes = {
      'a' => { subagents: [{ name: 'b_agent', recipe: 'b' }] },
      'b' => { subagents: [{ name: 'a_agent', recipe: 'a' }] }
    }

    expect {
      described_class.new(recipes).process_subagents(recipes['a'])
    }.to raise_error(Ruly::CircularReferenceError)
  end
end
```

## Example Usage

### CLI Usage

The existing `ruly squash` command automatically processes subagents:

```bash
# Squash a recipe - automatically generates subagents if defined
ruly squash workaxle_core_local

# The squash command will:
# 1. Squash workaxle_core_local recipe to main output
# 2. Detect subagents array in recipe
# 3. For each subagent, squash the referenced recipe to .claude/agents/{name}.md
# 4. Merge MCP servers from all subagent recipes into .mcp.json

# No separate command needed - subagents are processed as part of squash
```

### Input Configuration

```yaml
# ~/.config/ruly/recipes.yml
recipes:
  jira:
    description: Jira workflow and commands
    mcp_servers:
      - atlassian
    files:
      - /Users/patrick/Projects/ruly/rules/workaxle/atlassian/accounts.md
      - /Users/patrick/Projects/ruly/rules/workaxle/atlassian/jira/workflow.md

  workaxle_core_local:
    description: Main WorkAxle development environment
    mcp_servers:
      - github
      - circleci
    files:
      - /Users/patrick/Projects/ruly/rules/workaxle/core/common.md
    subagents:
      - name: jira_bot
        recipe: jira
      - name: pr_helper
        recipe: github_pr
```

### Output Files

**`.claude/agents/jira_bot.md`:**

```markdown
---
name: jira_bot
description: Jira workflow and commands - invoke for Jira ticket management, workflow automation, and status tracking
tools: inherit
model: inherit
# Auto-generated from recipe: jira
# Do not edit manually - regenerate using 'ruly squash workaxle_core_local'
---

# Jira Bot

Specialized subagent for Jira workflow and commands. This agent provides comprehensive support for Jira ticket management, status tracking, and workflow automation.

## Recipe Content

### Atlassian Accounts

{content from /Users/patrick/Projects/ruly/rules/workaxle/atlassian/accounts.md}

### Jira Workflow

{content from /Users/patrick/Projects/ruly/rules/workaxle/atlassian/jira/workflow.md}

## MCP Servers

This subagent has access to the following MCP servers:
- atlassian

## Usage

Invoke this subagent when you need to:
- Create, update, or transition Jira tickets
- Query Jira for ticket status or information
- Automate Jira workflows
- Generate reports from Jira data

---
*Last generated: 2025-01-14 10:30:00*
*Source recipe: jira*
```

**`.mcp.json`:**

```json
{
  "mcpServers": {
    "github": { /* existing config */ },
    "circleci": { /* existing config */ },
    "atlassian": { /* merged from jira recipe */ }
  }
}
```

## Error Handling

### Ruby Exception Classes

```ruby
module Ruly
  class SubagentError < StandardError; end
  class CircularReferenceError < SubagentError; end
  class RecipeNotFoundError < SubagentError; end
  class InvalidConfigurationError < SubagentError; end
end
```

### Circular Reference Error

```
Ruly::CircularReferenceError: Circular recipe reference detected
Recipe chain: workaxle_core_local → jira_bot → some_recipe → jira_bot
Please remove circular reference from ~/.config/ruly/recipes.yml
```

### Missing Recipe Error

```
Ruly::RecipeNotFoundError: Subagent recipe 'unknown_recipe' not found
Referenced in: workaxle_core_local.subagents[0]
Available recipes: jira, workaxle_core_local, github_pr

Run 'ruly list-recipes' to see all available recipes
```

### Invalid Configuration Error

```
Ruly::InvalidConfigurationError: Invalid subagent configuration
Recipe: workaxle_core_local
Issue: Missing required field 'name' in subagents[1]

Expected format:
  subagents:
    - name: agent_name
      recipe: recipe_key
```

## Non-Goals (Initial Release)

- Nested subagents (subagents cannot define their own subagents - prevented by design)
- Dynamic agent generation at runtime (generation happens during `ruly squash`)
- Agent file editing synchronization back to recipes (one-way generation only)
- Per-subagent `tools` and `model` customization (deferred to future enhancement)
- Custom instructions per subagent (all use recipe description and content)
- Automatic regeneration on recipe changes (manual `ruly squash` required)
- Separate CLI commands for subagent management (integrated into `squash` command)

## Success Metrics

- Zero manual agent file creation required for `ruly` users
- Subagents automatically generated when running `ruly squash` on recipes with `subagents` key
- Existing `ruly squash` behavior unchanged for recipes without `subagents`
- No circular reference bugs in production through robust Ruby exception handling
- Clear, actionable error messages guide users to fix configuration issues
- RSpec test coverage ≥ 90% for all subagent-related classes
- Subagent generation adds < 100ms overhead to squash command per subagent

## Future Enhancements

- **Agent-specific overrides**: Allow custom `tools` and `model` fields in recipe YAML:
  ```yaml
  subagents:
    - name: specialized_agent
      recipe: base_recipe
      tools: Read, Write, Bash  # Override inherited tools
      model: opus              # Use specific model
  ```
- **Custom instructions per agent**: Add `instructions` field to append agent-specific guidance
- **Conditional agent generation**: Based on environment variables or project type
- **Agent versioning and rollback**: Git integration to track agent file history
- **Agent testing framework**: RSpec matchers for validating generated subagents
- **Hot-reload**: Watch `recipes.yml` for changes and auto-regenerate via file watcher
- **Squash command enhancements**:
  - `ruly squash --subagents-only` - Only generate subagents, skip main squash
  - `ruly squash --skip-subagents` - Skip subagent generation
  - `ruly squash --dry-run` - Show what would be generated
- **Utility commands**:
  - `ruly list-subagents` - List all generated subagents with metadata
  - `ruly doctor` - Validate subagent health and configuration
- **Subagent template system**: Common agent patterns (tester, reviewer, documenter)
- **Subagent invocation analytics**: Track which subagents are used most frequently
