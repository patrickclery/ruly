# Codebase Structure

**Analysis Date:** 2026-03-22

## Directory Layout

```
ruly/
├── bin/
│   └── ruly                           # CLI executable entry point
├── lib/
│   └── ruly/
│       ├── version.rb                 # Version constant
│       ├── checks.rb                  # Checks module loader
│       ├── checks/
│       │   ├── base.rb                # Base check class
│       │   ├── ambiguous_links.rb     # Post-squash link validation
│       │   └── duplicate_skill_requires.rb  # Skill dependency validation
│       ├── cli.rb                     # Main CLI class (Thor-based)
│       ├── operations.rb              # Operations module loader
│       ├── operations/
│       │   ├── base.rb                # Base operation class
│       │   ├── analyzer.rb            # Token analysis operation
│       │   └── stats.rb               # Token stats generation
│       ├── services.rb                # Services module loader
│       ├── services/
│       │   ├── dependency_resolver.rb # Resolve requires:/skills: dependencies
│       │   ├── display.rb             # Output formatting and display
│       │   ├── frontmatter_parser.rb  # YAML frontmatter parsing
│       │   ├── git_ignore_manager.rb  # .gitignore update logic
│       │   ├── github_client.rb       # GitHub API integration (GraphQL/REST/CLI)
│       │   ├── mcp_manager.rb         # MCP server configuration generation
│       │   ├── recipe_introspector.rb # Directory scanning and recipe generation
│       │   ├── recipe_loader.rb       # Recipe YAML loading and validation
│       │   ├── repo_config_reader.rb  # Project config reading
│       │   ├── script_manager.rb      # Shell script collection and copying
│       │   ├── settings_manager.rb    # Settings and hooks management
│       │   ├── shell_command_checker.rb # Shell command validation
│       │   ├── source_processor.rb    # Main squash pipeline
│       │   ├── squash_helpers.rb      # Dispatch validation, recipe scanning
│       │   ├── subagent_processor.rb  # Subagent recipe processing
│       │   └── toc_generator.rb       # Table of contents and anchor generation
│       └── ruly.rb                    # Module definition and requires
├── rules/                             # User rules directory (markdown rule files)
│   ├── [tag]/                         # Organized by topic/tag
│   │   ├── core.md                    # Core rules for topic
│   │   ├── skills/                    # Skill definitions
│   │   │   └── [skill-name].md
│   │   ├── commands/                  # CLI commands for topic
│   │   │   └── [command-name].md
│   │   ├── bin/                       # Shell scripts for topic
│   │   │   └── [script-name].sh
│   │   └── [subtopic]/                # Nested subtopics
│   └── ...
├── recipes.yml                        # Base recipe definitions
├── .ruly.yml                          # Squash metadata (generated)
├── Gemfile / Gemfile.lock             # Ruby dependencies
├── ruly.gemspec                       # Gem specification
├── README.md                          # User documentation
├── CHANGELOG.md                       # Release notes
├── .rubocop.yml                       # Ruby style config
├── .eslintrc.json                     # JavaScript linting (for prettier)
├── .prettierrc.json                   # Markdown formatting
├── .rspec                             # RSpec configuration
├── spec/                              # Test suite
│   └── ruly/
│       ├── cli_spec.rb                # CLI command tests
│       ├── cli_scripts_spec.rb        # Script handling tests
│       ├── cli_skills_frontmatter_spec.rb
│       ├── cli_requires_spec.rb
│       ├── cli_mcp_spec.rb
│       ├── operations/
│       │   └── stats_spec.rb
│       └── ...
├── .planning/                         # GSD planning directory (generated)
│   └── codebase/                      # Architecture documentation
│       ├── ARCHITECTURE.md
│       └── STRUCTURE.md
└── docs/                              # Additional documentation
    ├── claude-code-proxy.md
    └── omit_command_prefix.md
```

## Directory Purposes

**bin/:**
- Purpose: Executable entry point
- Contains: Single `ruly` bash wrapper that loads Ruby and invokes CLI

**lib/ruly/:**
- Purpose: Core gem library
- Contains: All production Ruby code organized into modules

**lib/ruly/checks/:**
- Purpose: Post-squash validation checks
- Contains: Check implementations that run after output file is written
- Key files:
  - `ambiguous_links.rb`: Scans markdown for problematic link patterns
  - `duplicate_skill_requires.rb`: Validates skill dependencies not duplicated

**lib/ruly/operations/:**
- Purpose: Encapsulated complex business logic
- Contains: Operation classes (not CLI commands) for reusable workflows
- Key files:
  - `analyzer.rb`: Token counting and recipe analysis
  - `stats.rb`: Generate stats.md file with token data

**lib/ruly/services/:**
- Purpose: Stateless utilities for specific concerns
- Contains: 14 service modules handling concerns like recipe loading, GitHub integration
- Key files:
  - `source_processor.rb`: Main squash pipeline (349 lines)
  - `recipe_loader.rb`: Recipe validation and loading (486 lines)
  - `github_client.rb`: Remote file fetching (348 lines)
  - `script_manager.rb`: Script collection and copying (428 lines)
  - `subagent_processor.rb`: Subagent recipe processing (392 lines)
  - `dependency_resolver.rb`: Requires/skills resolution

**rules/:**
- Purpose: User-created rule files (markdown + scripts)
- Contains: Organized by topic tags (e.g., `auth0/`, `comms/`, `workaxle/`)
- Structure pattern:
  - `{tag}/core.md` - Primary rules for topic
  - `{tag}/skills/` - Skill definitions (referenced by `skills:` frontmatter)
  - `{tag}/commands/` - Markdown command files (referenced by `commands:` in recipes)
  - `{tag}/bin/` - Shell scripts (referenced by `scripts:` in recipes)
  - `{tag}/{subtopic}/` - Nested organization for complex topics

**spec/:**
- Purpose: Test suite
- Contains: RSpec tests for CLI, operations, services
- Pattern: Test file mirrors source structure (e.g., `spec/ruly/cli_spec.rb` tests `lib/ruly/cli.rb`)

**docs/:**
- Purpose: Additional documentation and guides
- Contains: Implementation notes, proxy documentation, etc.

## Key File Locations

**Entry Points:**
- `bin/ruly` - CLI binary executable
- `lib/ruly.rb` - Module loader and requires (loads version, checks, cli)
- `lib/ruly/cli.rb` - Thor CLI class with all commands

**Configuration:**
- `recipes.yml` - Base recipe definitions (project-checked-in recipes)
- `~/.config/ruly/recipes.yml` - User override recipes (highest priority, not in repo)
- `.ruly.yml` - Squash metadata (generated, should gitignore)
- `ruly.gemspec` - Gem specification

**Core Logic:**
- `lib/ruly/services/recipe_loader.rb` - Load and merge recipes
- `lib/ruly/services/source_processor.rb` - Squash pipeline
- `lib/ruly/services/dependency_resolver.rb` - Resolve requires:/skills:
- `lib/ruly/services/github_client.rb` - Fetch remote files
- `lib/ruly/services/frontmatter_parser.rb` - Parse YAML frontmatter
- `lib/ruly/operations/analyzer.rb` - Token analysis

**Testing:**
- `spec/ruly/cli_spec.rb` - Main CLI tests (776 lines)
- `spec/ruly/operations/stats_spec.rb` - Stats operation tests (1076 lines)
- `spec/ruly/cli_requires_spec.rb` - Requires resolution tests (475 lines)
- `spec/ruly/cli_skills_frontmatter_spec.rb` - Skills handling tests (477 lines)

## Naming Conventions

**Files:**
- Ruby source: `snake_case.rb` (e.g., `source_processor.rb`)
- Markdown rules: `kebab-case.md` (e.g., `deploy-service.md`)
- Shell scripts: `kebab-case.sh` (e.g., `countdown-timer.sh`)
- Tests: `{component}_spec.rb` (e.g., `cli_spec.rb`)
- Generated: `.{agent}.md` (e.g., `CLAUDE.local.md`, `.cursor.md`)

**Directories:**
- Tag/feature directories: `snake_case/` (e.g., `workaxle/`, `comms/`)
- Subdirectories within tags: lowercase, dash-separated (e.g., `pr/`, `ms-teams/`)
- Special directories: dot-prefixed (e.g., `.claude/`, `.cursor/`)

**Ruby Classes:**
- Classes: `PascalCase` (e.g., `CLI`, `Analyzer`)
- Modules: `PascalCase` (e.g., `RecipeLoader`, `SourceProcessor`)
- Constants: `UPPER_SNAKE_CASE` (e.g., `MERGE_SKIP_KEYS`)
- Methods: `snake_case`

**Methods:**
- Query methods: suffix with `?` (e.g., `cached?`, `verbose?`)
- Command methods: verb at start (e.g., `process_squash_sources`, `resolve_requires`)
- Private methods: prefixed (no leading underscore, just after `private` keyword)

## Where to Add New Code

**New Feature (affects squash pipeline):**
- Primary code: Add service module to `lib/ruly/services/` or extend existing service
- Tests: Create test file in `spec/ruly/` mirroring service structure
- CLI integration: Add methods to `lib/ruly/cli.rb` or option flags if needed
- Example: New remote source type → extend `github_client.rb` and `source_processor.rb`

**New CLI Command:**
- Implementation: Add `desc` and `option` declarations + method in `lib/ruly/cli.rb`
- Pattern: Use Thor DSL, extract logic to Operations or Services
- Example: `ruly analyze` command is at line 165 in cli.rb, calls `Operations::Analyzer`

**New Rule File (users adding rules):**
- Implementation: `rules/{tag}/{category}.md` with YAML frontmatter
- Skills: `rules/{tag}/skills/{skill-name}.md` (referenced by `skills:`)
- Commands: `rules/{tag}/commands/{cmd-name}.md` (referenced by `commands:`)
- Scripts: `rules/{tag}/bin/{script-name}.sh` (referenced by `scripts:`)

**New Service Module:**
- Location: `lib/ruly/services/{concern}.rb`
- Pattern: Use `module_function` for stateless methods, document with YARD
- Integration: Load in `lib/ruly/services.rb` with `require_relative` statement

**New Post-Squash Check:**
- Location: `lib/ruly/checks/{check_name}.rb`
- Implementation: Inherit from `Base`, implement `call` class method
- Registration: Add to array in `Checks.run_all` method in `lib/ruly/checks.rb`

**New Operation:**
- Location: `lib/ruly/operations/{operation_name}.rb`
- Implementation: Inherit from `Base`, implement `call` instance method
- Integration: Call from CLI, return hash with `:success`, `:data`, `:error` keys

## Special Directories

**`.claude/`:**
- Purpose: Generated Claude-specific configuration
- Generated: By `ruly squash` command
- Committed: Typically no (added to .gitignore)
- Contains:
  - `CLAUDE.local.md` - Merged rule output
  - `commands/` - Command files copied from recipes
  - `scripts/` - Shell scripts from rule `scripts:` declarations

**`.cursor/`:**
- Purpose: Generated Cursor-specific configuration
- Generated: By `ruly squash -a cursor`
- Committed: No
- Structure: Same as `.claude/`

**`cache/`:**
- Purpose: Cached squash outputs for fast recipe reuse
- Generated: By `ruly squash --cache`
- Committed: No (added to .gitignore)
- Location: `cache/{agent}/{recipe_name}.md`

**`.planning/codebase/`:**
- Purpose: GSD (Goal-Seeking Developer) planning documents
- Generated: By `ruly squash` or planning tools
- Committed: Typically yes (useful for onboarding)
- Contains: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, etc.

**`rules/`:**
- Purpose: Source of truth for all rules
- Generated: No (user-managed)
- Committed: Yes
- Structure: Organized by tag, contains `.md` files and optional `skills/`, `commands/`, `bin/` subdirs

---

*Structure analysis: 2026-03-22*
