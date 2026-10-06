# Architecture

**Analysis Date:** 2026-03-22

## Pattern Overview

**Overall:** Command-based Pipeline Architecture with Modular Service Layer

**Key Characteristics:**
- CLI-driven command dispatch via Thor framework
- Pipeline-based recipe compilation (squash operation)
- Modular service layer for concerns like recipe loading, source processing, dependency resolution, and GitHub integration
- Two-phase recipe system: base recipe definitions + user configuration overrides
- Dependency resolution with circular-reference detection for `requires:` and `skills:` frontmatter
- Support for local markdown files and remote GitHub repositories as sources
- Multi-agent output support (Claude, Cursor, Shell-GPT, etc.)

## Layers

**CLI Layer:**
- Purpose: Entry point for all user commands; translates command-line arguments to operations
- Location: `lib/ruly/cli.rb`
- Contains: Command definitions using Thor DSL, option parsing, command orchestration
- Depends on: Operations, Services, Checks modules
- Used by: Users via `ruly` binary (`bin/ruly`)

**Operations Layer:**
- Purpose: Encapsulated, reusable business logic for complex tasks (analysis, stats, squashing)
- Location: `lib/ruly/operations/`
- Contains: Base class (`operations/base.rb`), Analyzer (`operations/analyzer.rb`), Stats (`operations/stats.rb`)
- Depends on: Services (RecipeLoader, SourceProcessor, GitHub integration)
- Used by: CLI commands for task execution

**Services Layer:**
- Purpose: Stateless, reusable utilities for specific concerns
- Location: `lib/ruly/services/`
- Contains: 14 service modules including:
  - `recipe_loader.rb` - Load and validate recipes from YAML
  - `source_processor.rb` - Main squash pipeline: iterate sources, resolve dependencies, deduplicate
  - `dependency_resolver.rb` - Resolve `requires:` and `skills:` references
  - `github_client.rb` - Fetch remote files via GraphQL, REST, and CLI
  - `frontmatter_parser.rb` - Parse and strip YAML frontmatter
  - `script_manager.rb` - Manage shell scripts and command files
  - `subagent_processor.rb` - Process recipe subagents
  - `mcp_manager.rb` - Generate MCP server configurations
  - `settings_manager.rb` - Manage recipe settings and hooks
  - `display.rb` - Format and display output
  - `squash_helpers.rb` - Dispatch validation, recipe-tag scanning
  - `toc_generator.rb` - Generate table of contents
  - `recipe_introspector.rb` - Scan directories and create recipes
  - `shell_command_checker.rb` - Validate shell commands in rules
- Depends on: External libraries (YAML, JSON, GitHub API)
- Used by: CLI and Operations layers

**Checks Layer:**
- Purpose: Post-squash validation to catch errors in compiled output
- Location: `lib/ruly/checks/`
- Contains: Base class, AmbiguousLinks check, DuplicateSkillRequires check
- Depends on: Services (FrontmatterParser, DependencyResolver)
- Used by: CLI post-squash (called from `cli.rb` post_squash method)

## Data Flow

**Main Squash Pipeline:**

1. **Recipe Loading** (CLI → RecipeLoader)
   - Load base `recipes.yml` from gem root
   - Load user `~/.config/ruly/recipes.yml` (highest priority override)
   - Validate requested recipe exists
   - Resolve `extends:` recipe inheritance

2. **Source Collection** (RecipeLoader → sources array)
   - Process `files:` entries (local or GitHub URLs)
   - Process `skills:` entries (GitHub URLs only, must exist)
   - Process `commands:` entries (local files in `.claude/commands/`)
   - Process `scripts:` entries (shell scripts to copy)
   - Process `sources:` entries (legacy remote files)
   - Scan for files tagged with recipe name in `recipes:` frontmatter

3. **Source Processing** (SourceProcessor → local_sources, command_files, skill_files)
   - Prefetch all remote files via GitHub GraphQL in batch
   - Iterate sources in order, maintaining queue for dependency resolution
   - For each source:
     - Check if already processed (deduplication by realpath)
     - Read content (local file or prefetched remote)
     - Parse frontmatter
     - Resolve `requires:` dependencies (queue new sources)
     - Resolve `skills:` dependencies (queue new sources, validate existence)
     - Strip metadata from content (unless `--front-matter` specified)
     - Append resolved content to appropriate output list
   - Return four lists: local_sources, command_files, bin_files, skill_files

4. **Output Writing**
   - For Claude/Cursor agents: write merged markdown
     - Optional: prepend table of contents
     - Rewrite script references using script mappings
     - Add anchor IDs if TOC enabled
   - For Shell-GPT agent: write JSON format
   - Create `.ruly.yml` metadata file

5. **Post-Squash Tasks**
   - Update `.gitignore` or `.git/info/exclude` if requested
   - Save to cache (if recipe + cache flag)
   - Save command files to `.claude/commands/`
   - Save skill files to `./.skills/` or custom location
   - Update MCP settings from `mcp_servers:` in recipe
   - Propagate hooks to subagent directories
   - Run validation checks (AmbiguousLinks, DuplicateSkillRequires)
   - Process subagents recursively (load subagent recipes)

**State Management:**
- Processed files tracked via Set (source key = realpath for local, full URL for remote)
- Sources queue maintained during iteration for dependency resolution
- Recipe configuration merged from base + user config
- Script mappings maintained to rewrite references in output

## Key Abstractions

**Recipe:**
- Purpose: A named collection of rule sources and configuration
- Examples: `core`, `auth0`, `workaxle-bug`, `agile`
- Pattern: YAML hash with keys: `files`, `skills`, `commands`, `scripts`, `sources`, `description`, `mcp_servers`, `subagents`, `hooks`, `omit_command_prefix`
- Location: `recipes.yml` (base), `~/.config/ruly/recipes.yml` (user override)

**Source:**
- Purpose: Reference to a single rule file or directory
- Examples:
  - Local: `{path: 'rules/core.md', type: 'local'}`
  - Remote: `{path: 'https://github.com/owner/repo/blob/main/file.md', type: 'remote'}`
- Pattern: Processed sources include `:content`, `:original_content`, `:path` keys

**Frontmatter:**
- Purpose: YAML metadata at top of markdown files controlling behavior
- Keys:
  - `requires:` - Local file paths that must be included first
  - `skills:` - Remote GitHub file URLs to include as skills
  - `recipes:` - Recipe names that trigger conditional inclusion
  - `essential:` - Boolean; included when `--essential` flag used
  - `dispatches:` - Subagent names to target for content
  - `scripts:` - Script files to copy to `.claude/scripts/`
  - Claude Code directives: `name`, `description`, `permissionMode`, `allowed_tools`

**Subagent:**
- Purpose: Delegate recipe squashing to another agent in a subdirectory
- Pattern: `{name: 'context_grabber', recipe: 'context-grabber', model: 'haiku', cwd: '...'}`
- Used for: Context gathering, issue analysis, specialized tasks

## Entry Points

**Ruly CLI Binary:**
- Location: `bin/ruly`
- Triggers: User runs `ruly <command> [args]`
- Responsibilities: Load bundler, require lib/ruly, invoke CLI

**CLI.start:**
- Location: `lib/ruly/cli.rb` (Thor subclass)
- Triggers: Entry point for all commands (squash, import, clean, analyze, mcp, stats, init, etc.)
- Responsibilities: Parse options, invoke corresponding private methods

**Main squash flow:**
- Command: `ruly squash [RECIPE] [OPTIONS]`
- Implementation: `CLI#squash` method (lines 37-77 in cli.rb)
- Flow:
  1. Guard home directory check
  2. Invoke clean if requested
  3. Load sources from recipe
  4. Collect scripts from sources
  5. Check shell commands
  6. Use cache if available and valid
  7. Process sources through pipeline
  8. Validate squash dispatches
  9. Optionally dry-run display
  10. Write output file
  11. Post-squash tasks (git ignore, cache, commands, skills, MCP, hooks, subagents)
  12. Run validation checks
  13. Display summary

## Error Handling

**Strategy:** Fail-fast with descriptive error messages and exit codes

**Patterns:**

- **Recipe validation:** Check recipes.yml exists, requested recipe exists → exit 1 with message
- **File resolution:** Missing local files skipped (warn in verbose mode), missing skills raise Ruly::Error
- **GitHub integration:** Failed GraphQL/REST calls warn and continue (graceful degradation)
- **Dispatch validation:** Unregistered dispatches raise Ruly::Error with suggestion for fix
- **Frontmatter parsing:** Invalid YAML caught, returns empty hash with warning if DEBUG set
- **Post-squash checks:** Non-fatal warnings for ambiguous links, failures for duplicate skill requires

**Error context:** Errors include source filename, path, and actionable suggestions

## Cross-Cutting Concerns

**Logging:**
- Uses `puts` for user-facing output
- Verbose output controlled by `--verbose` flag and `DEBUG` environment variable
- Icons used for visual distinction (🔄, ✨, ✅, ❌, 📚, 🔍, 📝, etc.)

**Validation:**
- Frontmatter: YAML safe_load with error handling
- Paths: Realpath normalization to handle symlinks and relative paths
- Dispatches: Matched against registered subagent names
- Ambiguous links: Check for markdown links in squashed output
- Skill dependencies: Duplicate requires detected across skill requires

**Authentication:**
- GitHub: Uses local `gh` CLI for authentication (no token in code)
- GraphQL/REST: Environment-based credentials handled by `gh` CLI

**Caching:**
- Location: `~/.cache/ruly/` (user) or `cache/` (gem)
- Key: `{agent}/{recipe_name}.md`
- Invalidation: Manual (no TTL, cache reused on exact recipe match)
- Used: After successful squash with `--cache` flag

---

*Architecture analysis: 2026-03-22*
