- always update the ~/.config/ruly/recipes.yml and /Users/patrick/Projects/chezmoi/config/ruly/recipes.yml when you change things it references (they should be identical)
- Every time the slash commands are updated, make sure to update the slash command section of README.md
- When changing `ruly` CLI commands (squash, clean, analyze, mcp, etc.), always update README.md to reflect the changes
- NEVER edit `CLAUDE.local.md` — it is generated output from `ruly squash` and will be overwritten. Fix the source rules in ./rules/ instead.
- When I ask to change rules, don't change the rules in .claude/ always look in ./rules/
- When I ask to create a skill, add it to `rules/{tag}/skills/{skill-name}.md` (Ruly searches for skills in that structure)
- Skills in rules/ are regular `.md` files, NOT `SKILL.md` - Ruly converts them to SKILL.md format on squash
- Always use `git mv` to move/rename files instead of deleting and re-creating them (preserves git history)
- When deleting/moving/renaming files in rules/, always search for references to update:
  - `requires:` frontmatter in other rule files
  - Recipe files (recipes.yml, ~/.config/ruly/recipes.yml)
  - Section anchor links that may have changed
- When I say "commit" or "commit all", commit and push ALL modified files in BOTH repos (don't assume any changes are unrelated):
  1. The rules submodule (./rules) → https://github.com/patrickclery/rules
  2. The parent ruly repo → https://github.com/patrickclery/ruly (update submodule reference)
- Always use **Mermaid** for diagrams/flowcharts in rules (never graphviz/dot). Exception: Jira/Confluence don't support Mermaid, so use ASCII diagrams there instead.

# Claude Code Instructions

## Ruly Recipe and MCP Configuration Patterns

**Import Ruly recipe configuration patterns and MCP server guidelines.**
@./.claude/ruly-recipes-mcp-patterns.md


- When testing out `ruly squash ...`, always run it from a `mktmpdir` and not the main project directory
- always update ruly after any changes. for instance, /Users/patrick/.local/share/mise/installs/ruby/3.3.3/bin/ruly is out of sync right now
- Whenever you want token counts for recipes, run `ruly stats` and read the results from `stats.md`
- After any changes to the `core` recipe (either `recipes.yml` or any file it references), run: `cd ~/agents/core && ruly squash --deepclean core`. **Do this before ending the session — check whether any file you modified is referenced by the core recipe.**

## CRITICAL: Never Reference Filenames in Rules

**Filenames do not exist after `ruly squash`.** When rules are squashed, all files are merged into a single output. References to filenames like `preview-common.md` or `accounts.md` will be meaningless.

**ALWAYS use markdown section links instead, and ensure the referenced file is in `requires:`.**

### BAD (filename references)

```markdown
See `preview-common.md` for details.
Follow the workflow in `accounts.md`.
Review `preview-common.md` before submitting.
```

### GOOD (section anchor links + requires)

```yaml
---
requires:
  - ../jira/preview-common.md
  - ../accounts.md
---
```

```markdown
See [Jira Draft Preview Workflow](#jira-draft-preview-workflow) for details.
Follow the workflow in [Jira Accounts](#jira-accounts).
Review [Jira Draft Preview Workflow](#jira-draft-preview-workflow) before submitting.
```

**Why this matters:** After squashing, the section headers remain as anchor targets, but filenames disappear completely. The `requires:` frontmatter ensures the referenced content is included in the squashed output.

## CRITICAL: Never Reference Commands by Name in Rules

**Command names like `/create` or `/merge-to-develop` do not exist after `ruly squash`.** When referencing related commands, use section anchor links instead.

### BAD (command references)

```markdown
- `/pr:review-feedback-loop` - Handle review feedback
- `/create-branch` - Create feature branches
- See `/create-develop` for creating PRs against develop
```

### GOOD (section anchor links + requires)

```yaml
---
requires:
  - ./review-feedback-loop.md
  - ./create-branch.md
  - ./create-develop.md
---
```

```markdown
- [PR Review Feedback Loop](#pr-review-feedback-loop) - Handle review feedback
- [Create Feature Branches](#create-feature-branches) - Create branches with proper naming
- See [Create PR Against Develop](#create-pr-against-develop) for creating PRs against develop
```

**Why this matters:** Slash commands are just file names with `/` prefix - they disappear after squashing just like filenames do.

<!-- GSD:project-start source:PROJECT.md -->
## Project

**Ruly**

Ruly is a Ruby gem and CLI tool that compiles modular markdown rule files into agent-specific instruction documents (CLAUDE.md, .cursorrules, etc.). It uses a recipe system to compose the right rules for the right context, with dependency resolution, remote GitHub file fetching, and multi-agent support.

**Core Value:** Rules get squashed correctly into agent instruction files every time — reliable, deterministic compilation is the foundation everything else depends on.

### Constraints

- **Runtime**: Ruby 3.3.0+ required
- **CLI dependency**: Relies on `gh` CLI for GitHub integration
- **Token counting**: Uses `tiktoken_ruby` which has native extensions
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Ruby 3.3.0+ - Core CLI and rule processing engine (`lib/ruly/`)
- TypeScript 5 - Site documentation frontend (`site/`)
- YAML - Recipe and configuration definitions (`recipes.yml`, `.ruly.yml`)
- Markdown - Rule files and documentation source (`rules/`)
- JavaScript/Node.js - Site build tooling and formatting scripts
## Runtime
- Ruby 3.3.0 or later - Primary runtime for ruly gem and CLI
- Node.js - For site/documentation build and formatting tools
- Bundler - Ruby dependency management
- npm - Node.js dependency management
- Lockfile: Both `Gemfile.lock` and `package-lock.json` present
## Frameworks
- Thor 1.2+ - CLI framework for ruly command-line interface (`lib/ruly/cli.rb`)
- tiktoken_ruby 0.0.9 - Token counting for OpenAI models (`lib/ruly/operations/analyzer.rb`)
- Next.js 16.1.6 - React-based static site for documentation (`site/`)
- React 19.2.3 - UI library for site
- Tailwind CSS 4 - CSS utility framework (`site/postcss.config.mjs`)
- TypeScript - Type safety for site code
- RuboCop 1.0+ - Ruby linting with custom configs (AllCops: NewCops: enable)
- rubocop-obsession - Additional RuboCop rules
- rubocop-performance - Performance-focused RuboCop rules
- rubocop-rake - Rake-specific RuboCop rules
- rubocop-rspec - RSpec-specific RuboCop rules
- sevencop - Additional RuboCop rules
- ESLint 9 - JavaScript/TypeScript linting
- Prettier 3.6.2 - Code formatting (YAML, Markdown, JavaScript)
- RSpec 3.0+ - Ruby testing framework
- WebMock 3.0+ - HTTP mocking for tests
- Rake 13.0+ - Ruby task automation
- Lefthook 1.0+ - Git hooks framework (`lefthook.yml`)
- markdown-table-prettify 3.6.0 - Markdown table formatting
## Key Dependencies
- tiktoken_ruby 0.0.9 - Token counting for LLM context optimization (`lib/ruly/operations/analyzer.rb`)
- Thor 1.2+ - CLI framework
- base64 - Standard library replacement for Ruby 3.4+ (`lib/ruly/services/github_client.rb`)
- YAML - Built-in YAML parsing for recipe and MCP configuration
- JSON - Built-in JSON parsing for GitHub API responses
- Net::HTTP - Built-in HTTP client for remote file fetching
- URI - Built-in URI parsing and manipulation
- Tempfile - Temporary file handling for GraphQL queries
- FileUtils - File system operations throughout
- yalphabetize - YAML alphabetization utility (require: false)
## Configuration
- Environment variables:
- No `.env` file usage detected
- RuboCop config: `.rubocop.yml`
- Prettier config: `.prettierrc.json`
- ESLint config: `site/eslint.config.mjs`
- YAML linting: `.yamllint.yml`
- Tailwind CSS: `site/tailwind.config.ts` (via postcss)
- Ruly config: `.ruly.yml`
- Output mode: Static export (`output: "export"`)
- Base path: `/ruly` for GitHub Pages hosting
- Image optimization disabled for static export
## Platform Requirements
- Ruby 3.3.0 or later
- Bundler for dependency management
- Node.js and npm for site development
- gh CLI (GitHub CLI) for GitHub API operations
- Ruby 3.3.0+ runtime for published gem
- Published on RubyGems with MFA required
- Deployed as standalone gem (can be installed via bundler or directly)
- Site deployed as static HTML (Next.js export)
- gh CLI (GitHub CLI) - For fetching remote rule files from GitHub repositories
- Markdown-to-table tool - For markdown table formatting
- Rake - For running development tasks
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- Ruby files: `snake_case.rb` (e.g., `dependency_resolver.rb`, `recipe_loader.rb`)
- Spec files: `{name}_spec.rb` (e.g., `cli_spec.rb`, `ambiguous_links_spec.rb`)
- Classes map to files: `ClassName` → `class_name.rb`
- Instance methods: `snake_case` (e.g., `def squash(recipe_name)`)
- Class methods: `snake_case` (e.g., `def self.call(...)`)
- Private/protected: same convention, marked with `private` or `protected` keyword
- Boolean methods: trailing `?` (e.g., `def empty?`)
- Destructive methods: trailing `!` (e.g., `def validate!`)
- Local variables: `snake_case` (e.g., `recipe_config`, `local_sources`)
- Constants: `SCREAMING_SNAKE_CASE` (e.g., `SETTINGS_FILE = '.claude/settings.local.json'`)
- Symbols: colon prefix with snake_case (e.g., `:type`, `:path`, `:content`)
- Classes: `PascalCase` (e.g., `class AmbiguousLinks`, `class Analyzer`)
- Modules: `PascalCase` (e.g., `module DependencyResolver`, `module Services`)
- Namespaces: module nesting follows directory structure (e.g., `Ruly::Services::RecipeLoader`)
## Code Style
- Tool: `prettier` with custom config (`~/.prettierrc.json`)
- Ruby printWidth: 120 characters (Layout/LineLength: Max 120)
- YAML/Markdown printWidth: 100 characters
- Trailing comma: `none` (JavaScript style, not applied to Ruby)
- Quote style: single quotes for strings in Ruby
- Tabs: spaces (2 spaces per indentation level)
- Tool: `rubocop` with custom rules (`.rubocop.yml`)
- Plugins: `rubocop-obsession`, `rubocop-performance`, `rubocop-rake`, `rubocop-rspec`, `sevencop`
- Key rules enforced:
## Import Organization
## Error Handling
- `StandardError` for general parsing/IO failures that should be caught broadly
- `Ruly::Error` for domain-specific failures (missing skills, invalid config)
- `Thor::Error` for CLI-level errors that should exit with proper CLI error messages
- `NotImplementedError` for abstract base class methods that must be overridden
## Logging
- `puts` for normal command output (dry-run info, summaries, file creation)
- `puts` in error blocks to display user-facing error messages
- Only use `if ENV['DEBUG']` for verbose diagnostic output
## Comments
- Document public API intentions in method docstrings
- Explain non-obvious algorithmic choices
- Flag critical behavior with comments (e.g., "CRITICAL: Always return to original directory")
## Function Design
- `invoke_clean_if_requested(recipe_name)`
- `load_sources(recipe_name)`
- `process_squash_sources(sources, agent)`
- `validate_squash_dispatches(local_sources, recipe_config, recipe_name)`
- `write_squash_output(...)`
- `post_squash(...)`
- Maximum 3-4 positional parameters; use keyword arguments for optional/multiple
- Keyword arguments preferred for clarity
- Block parameter `&block` used rarely; `...` (Ruby 2.7+ argument forwarding) preferred
- Hash with consistent structure for operations:
- Check class in `operations/base.rb` for pattern
- Single value for pure functions (e.g., `def format_number(num)`)
## Module Design
- Modules use `module_function` to expose methods as both module and instance methods
- Example from `frontmatter_parser.rb`:
- All methods are `module_function` (no instance state)
- Callable as `Module.method_name` or `module.method_name`
- Used for: `DependencyResolver`, `FrontmatterParser`, `Display`, `SettingsManager`, `ScriptManager`
## Class Structure Order
## Hash and Symbol Usage
- Modern syntax required: `{key: value}` not `{:key => value}`
- Symbol keys for all programmatic hashes
- String keys only for data loaded from YAML/JSON
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- CLI-driven command dispatch via Thor framework
- Pipeline-based recipe compilation (squash operation)
- Modular service layer for concerns like recipe loading, source processing, dependency resolution, and GitHub integration
- Two-phase recipe system: base recipe definitions + user configuration overrides
- Dependency resolution with circular-reference detection for `requires:` and `skills:` frontmatter
- Support for local markdown files and remote GitHub repositories as sources
- Multi-agent output support (Claude, Cursor, Shell-GPT, etc.)
## Layers
- Purpose: Entry point for all user commands; translates command-line arguments to operations
- Location: `lib/ruly/cli.rb`
- Contains: Command definitions using Thor DSL, option parsing, command orchestration
- Depends on: Operations, Services, Checks modules
- Used by: Users via `ruly` binary (`bin/ruly`)
- Purpose: Encapsulated, reusable business logic for complex tasks (analysis, stats, squashing)
- Location: `lib/ruly/operations/`
- Contains: Base class (`operations/base.rb`), Analyzer (`operations/analyzer.rb`), Stats (`operations/stats.rb`)
- Depends on: Services (RecipeLoader, SourceProcessor, GitHub integration)
- Used by: CLI commands for task execution
- Purpose: Stateless, reusable utilities for specific concerns
- Location: `lib/ruly/services/`
- Contains: 14 service modules including:
- Depends on: External libraries (YAML, JSON, GitHub API)
- Used by: CLI and Operations layers
- Purpose: Post-squash validation to catch errors in compiled output
- Location: `lib/ruly/checks/`
- Contains: Base class, AmbiguousLinks check, DuplicateSkillRequires check
- Depends on: Services (FrontmatterParser, DependencyResolver)
- Used by: CLI post-squash (called from `cli.rb` post_squash method)
## Data Flow
- Processed files tracked via Set (source key = realpath for local, full URL for remote)
- Sources queue maintained during iteration for dependency resolution
- Recipe configuration merged from base + user config
- Script mappings maintained to rewrite references in output
## Key Abstractions
- Purpose: A named collection of rule sources and configuration
- Examples: `core`, `auth0`, `workaxle-bug`, `agile`
- Pattern: YAML hash with keys: `files`, `skills`, `commands`, `scripts`, `sources`, `description`, `mcp_servers`, `subagents`, `hooks`, `omit_command_prefix`
- Location: `recipes.yml` (base), `~/.config/ruly/recipes.yml` (user override)
- Purpose: Reference to a single rule file or directory
- Examples:
- Pattern: Processed sources include `:content`, `:original_content`, `:path` keys
- Purpose: YAML metadata at top of markdown files controlling behavior
- Keys:
- Purpose: Delegate recipe squashing to another agent in a subdirectory
- Pattern: `{name: 'context_grabber', recipe: 'context-grabber', model: 'haiku', cwd: '...'}`
- Used for: Context gathering, issue analysis, specialized tasks
## Entry Points
- Location: `bin/ruly`
- Triggers: User runs `ruly <command> [args]`
- Responsibilities: Load bundler, require lib/ruly, invoke CLI
- Location: `lib/ruly/cli.rb` (Thor subclass)
- Triggers: Entry point for all commands (squash, import, clean, analyze, mcp, stats, init, etc.)
- Responsibilities: Parse options, invoke corresponding private methods
- Command: `ruly squash [RECIPE] [OPTIONS]`
- Implementation: `CLI#squash` method (lines 37-77 in cli.rb)
- Flow:
## Error Handling
- **Recipe validation:** Check recipes.yml exists, requested recipe exists → exit 1 with message
- **File resolution:** Missing local files skipped (warn in verbose mode), missing skills raise Ruly::Error
- **GitHub integration:** Failed GraphQL/REST calls warn and continue (graceful degradation)
- **Dispatch validation:** Unregistered dispatches raise Ruly::Error with suggestion for fix
- **Frontmatter parsing:** Invalid YAML caught, returns empty hash with warning if DEBUG set
- **Post-squash checks:** Non-fatal warnings for ambiguous links, failures for duplicate skill requires
## Cross-Cutting Concerns
- Uses `puts` for user-facing output
- Verbose output controlled by `--verbose` flag and `DEBUG` environment variable
- Icons used for visual distinction (🔄, ✨, ✅, ❌, 📚, 🔍, 📝, etc.)
- Frontmatter: YAML safe_load with error handling
- Paths: Realpath normalization to handle symlinks and relative paths
- Dispatches: Matched against registered subagent names
- Ambiguous links: Check for markdown links in squashed output
- Skill dependencies: Duplicate requires detected across skill requires
- GitHub: Uses local `gh` CLI for authentication (no token in code)
- GraphQL/REST: Environment-based credentials handled by `gh` CLI
- Location: `~/.cache/ruly/` (user) or `cache/` (gem)
- Key: `{agent}/{recipe_name}.md`
- Invalidation: Manual (no TTL, cache reused on exact recipe match)
- Used: After successful squash with `--cache` flag
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
