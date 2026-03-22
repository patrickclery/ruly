# Coding Conventions

**Analysis Date:** 2025-03-22

## Naming Patterns

**Files:**
- Ruby files: `snake_case.rb` (e.g., `dependency_resolver.rb`, `recipe_loader.rb`)
- Spec files: `{name}_spec.rb` (e.g., `cli_spec.rb`, `ambiguous_links_spec.rb`)
- Classes map to files: `ClassName` → `class_name.rb`

**Functions/Methods:**
- Instance methods: `snake_case` (e.g., `def squash(recipe_name)`)
- Class methods: `snake_case` (e.g., `def self.call(...)`)
- Private/protected: same convention, marked with `private` or `protected` keyword
- Boolean methods: trailing `?` (e.g., `def empty?`)
- Destructive methods: trailing `!` (e.g., `def validate!`)

**Variables:**
- Local variables: `snake_case` (e.g., `recipe_config`, `local_sources`)
- Constants: `SCREAMING_SNAKE_CASE` (e.g., `SETTINGS_FILE = '.claude/settings.local.json'`)
- Symbols: colon prefix with snake_case (e.g., `:type`, `:path`, `:content`)

**Types/Classes:**
- Classes: `PascalCase` (e.g., `class AmbiguousLinks`, `class Analyzer`)
- Modules: `PascalCase` (e.g., `module DependencyResolver`, `module Services`)
- Namespaces: module nesting follows directory structure (e.g., `Ruly::Services::RecipeLoader`)

## Code Style

**Formatting:**
- Tool: `prettier` with custom config (`~/.prettierrc.json`)
- Ruby printWidth: 120 characters (Layout/LineLength: Max 120)
- YAML/Markdown printWidth: 100 characters
- Trailing comma: `none` (JavaScript style, not applied to Ruby)
- Quote style: single quotes for strings in Ruby
- Tabs: spaces (2 spaces per indentation level)

**Linting:**
- Tool: `rubocop` with custom rules (`.rubocop.yml`)
- Plugins: `rubocop-obsession`, `rubocop-performance`, `rubocop-rake`, `rubocop-rspec`, `sevencop`
- Key rules enforced:
  - `Style/FrozenStringLiteralComment`: `# frozen_string_literal: true` required at file top
  - `Style/HashSyntax`: modern hash syntax (keys: values not :keys => values)
  - `Layout/ClassStructure`: enforced class member ordering (module_inclusion → constants → associations → methods)
  - `Metrics/MethodLength`: max 30 lines per method
  - `Metrics/ClassLength`: max 500 lines per class
  - `Metrics/CyclomaticComplexity`: max 15
  - `RSpec/ContextWording`: context blocks must start with "when", "with", or "without"
  - `RSpec/ExampleWording`: examples must use "should" or imperative verbs

**Frozen String Literal:**
Every Ruby file must start with:
```ruby
# frozen_string_literal: true
```

## Import Organization

**Order:**
1. Standard library requires (e.g., `require 'fileutils'`, `require 'json'`)
2. Third-party gem requires (e.g., `require 'yaml'`, `require 'thor'`)
3. Relative requires (e.g., `require_relative 'version'`)

**Pattern from codebase:**
```ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'yaml'
require 'thor'

require_relative 'version'
require_relative 'operations'
require_relative 'services'

module Ruly
  class CLI < Thor
    # ...
  end
end
```

**Path Aliases:**
No path aliases used. Uses relative requires from gem root structure.

## Error Handling

**Patterns:**

**1. Custom exception hierarchy:**
```ruby
module Ruly
  class Error < StandardError; end
end
```
Raised for skill file validation failures:
```ruby
# from dependency_resolver.rb
raise Ruly::Error, "Skill file not found: '#{skill_path}' referenced from '#{source[:path]}'"
```

**2. Graceful degradation with rescue:**
```ruby
# from frontmatter_parser.rb
begin
  frontmatter = YAML.safe_load(yaml_match[1]) || {}
rescue StandardError => e
  puts "\u26a0\ufe0f  Warning: Failed to parse frontmatter: #{e.message}" if ENV['DEBUG']
  [{}, content]
end
```

**3. Thor-based CLI errors:**
```ruby
# from recipe_loader.rb
raise Thor::Error, "Recipe '#{recipe_name}' not found"
```

**4. Validation methods raise NotImplementedError in base classes:**
```ruby
# from operations/base.rb
def call
  raise NotImplementedError, 'Subclasses must implement #call'
end
```

**When to use StandardError vs custom:**
- `StandardError` for general parsing/IO failures that should be caught broadly
- `Ruly::Error` for domain-specific failures (missing skills, invalid config)
- `Thor::Error` for CLI-level errors that should exit with proper CLI error messages
- `NotImplementedError` for abstract base class methods that must be overridden

## Logging

**Framework:** `puts` for command-line output (no external logging library)

**Patterns:**

**Output formatting with emojis:**
```ruby
puts "\n🔍 Dry run mode - no files will be created/modified\n\n"
puts "Would create: #{output_file}"
puts "✅ Generated #{output_file}"
puts "❌ Error: #{error_message}"
puts "⚠️  Warning message"
```

**Debug logging with ENV flag:**
```ruby
# from frontmatter_parser.rb
puts "\u26a0\ufe0f  Warning: Failed to parse frontmatter: #{e.message}" if ENV['DEBUG']
```

**When to log:**
- `puts` for normal command output (dry-run info, summaries, file creation)
- `puts` in error blocks to display user-facing error messages
- Only use `if ENV['DEBUG']` for verbose diagnostic output

## Comments

**When to Comment:**
- Document public API intentions in method docstrings
- Explain non-obvious algorithmic choices
- Flag critical behavior with comments (e.g., "CRITICAL: Always return to original directory")

**JSDoc/YARD-style Documentation:**
Used for public methods and class-level intent:

```ruby
# from analyzer.rb
# Format and display stats result from Operations::Stats
# @param result [Hash] Result hash from Operations::Stats#call
def self.display_stats_result(result)
  # ...
end

# from dependency_resolver.rb
# Resolve all `requires:` entries from a source's frontmatter.
def resolve_requires_for_source(source, content, processed_files, _all_sources,
                                find_rule_file:, gem_root:)
  # ...
end
```

**Inline comments:**
Used sparingly for critical sections:
```ruby
# from cli_spec.rb
# CRITICAL: Always return to original directory before ANY cleanup
# This prevents bundler from losing its working directory
Dir.chdir(original_dir)
```

## Function Design

**Size:** Max 30 lines (enforced by `Metrics/MethodLength: Max: 30`)

Large operations are decomposed into focused private methods. For example, `squash` in `cli.rb` (556 lines) delegates to:
- `invoke_clean_if_requested(recipe_name)`
- `load_sources(recipe_name)`
- `process_squash_sources(sources, agent)`
- `validate_squash_dispatches(local_sources, recipe_config, recipe_name)`
- `write_squash_output(...)`
- `post_squash(...)`

**Parameters:**
- Maximum 3-4 positional parameters; use keyword arguments for optional/multiple
- Keyword arguments preferred for clarity
- Block parameter `&block` used rarely; `...` (Ruby 2.7+ argument forwarding) preferred

Example from `base.rb`:
```ruby
class << self
  def call(...)
    new(...).call
  end
end
```

**Return Values:**
- Hash with consistent structure for operations:
  ```ruby
  {
    success: true/false,
    data: {...},
    error: nil/message
  }
  ```
- Check class in `operations/base.rb` for pattern
- Single value for pure functions (e.g., `def format_number(num)`)

## Module Design

**Exports:**
- Modules use `module_function` to expose methods as both module and instance methods
- Example from `frontmatter_parser.rb`:
  ```ruby
  module FrontmatterParser
    module_function

    def parse(content)
      # ...
    end
  end
  ```

**Stateless service modules:**
- All methods are `module_function` (no instance state)
- Callable as `Module.method_name` or `module.method_name`
- Used for: `DependencyResolver`, `FrontmatterParser`, `Display`, `SettingsManager`, `ScriptManager`

**Barrel Files:**
Not used. Each module/class has its own file; imports are explicit relative requires.

## Class Structure Order

Follows `Layout/ClassStructure` rubocop rules. Within classes:

1. Module inclusion (`include`, `prepend`, `extend`)
2. Constants
3. Associations (n/a for most of this codebase)
4. Attribute macros (`attr_accessor`, `attr_reader`)
5. Public class methods
6. `initialize` method
7. Public instance methods
8. Protected methods
9. Private methods

Example from `analyzer.rb`:
```ruby
class Analyzer < Base
  attr_reader :recipe_name, :recipes_file, :gem_root, :tier_override, :contexts

  def self.display_stats_result(result)
    # ...
  end

  def initialize(gem_root:, recipes_file:, ...)
    # ...
  end

  def call
    # ...
  end

  private

  def load_contexts
    # ...
  end
end
```

## Hash and Symbol Usage

**Hash syntax:**
- Modern syntax required: `{key: value}` not `{:key => value}`
- Symbol keys for all programmatic hashes
- String keys only for data loaded from YAML/JSON

Example:
```ruby
result = {
  data:,
  error:,
  success:
}

# Versus loaded from YAML:
frontmatter = YAML.safe_load(yaml_match[1]) || {}
# Keys are strings: frontmatter['requires'], frontmatter['skills']
```

**Symbol arrays:**
Percent notation when more than 1 symbol:
```ruby
%i[type path content]  # Good
[:type, :path, :content]  # Also acceptable
```

---

*Convention analysis: 2025-03-22*
