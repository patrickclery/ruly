# Technology Stack

**Analysis Date:** 2026-03-22

## Languages

**Primary:**
- Ruby 3.3.0+ - Core CLI and rule processing engine (`lib/ruly/`)
- TypeScript 5 - Site documentation frontend (`site/`)
- YAML - Recipe and configuration definitions (`recipes.yml`, `.ruly.yml`)
- Markdown - Rule files and documentation source (`rules/`)

**Secondary:**
- JavaScript/Node.js - Site build tooling and formatting scripts

## Runtime

**Environment:**
- Ruby 3.3.0 or later - Primary runtime for ruly gem and CLI
- Node.js - For site/documentation build and formatting tools

**Package Manager:**
- Bundler - Ruby dependency management
- npm - Node.js dependency management
- Lockfile: Both `Gemfile.lock` and `package-lock.json` present

## Frameworks

**Core:**
- Thor 1.2+ - CLI framework for ruly command-line interface (`lib/ruly/cli.rb`)
- tiktoken_ruby 0.0.9 - Token counting for OpenAI models (`lib/ruly/operations/analyzer.rb`)

**Frontend/Documentation:**
- Next.js 16.1.6 - React-based static site for documentation (`site/`)
- React 19.2.3 - UI library for site
- Tailwind CSS 4 - CSS utility framework (`site/postcss.config.mjs`)
- TypeScript - Type safety for site code

**Development/Code Quality:**
- RuboCop 1.0+ - Ruby linting with custom configs (AllCops: NewCops: enable)
- rubocop-obsession - Additional RuboCop rules
- rubocop-performance - Performance-focused RuboCop rules
- rubocop-rake - Rake-specific RuboCop rules
- rubocop-rspec - RSpec-specific RuboCop rules
- sevencop - Additional RuboCop rules
- ESLint 9 - JavaScript/TypeScript linting
- Prettier 3.6.2 - Code formatting (YAML, Markdown, JavaScript)

**Testing:**
- RSpec 3.0+ - Ruby testing framework
- WebMock 3.0+ - HTTP mocking for tests

**Build/Dev:**
- Rake 13.0+ - Ruby task automation
- Lefthook 1.0+ - Git hooks framework (`lefthook.yml`)
- markdown-table-prettify 3.6.0 - Markdown table formatting

## Key Dependencies

**Critical:**
- tiktoken_ruby 0.0.9 - Token counting for LLM context optimization (`lib/ruly/operations/analyzer.rb`)
  - Required for `stats` command and recipe analysis
  - Enables token budget calculations for recipe compilation
- Thor 1.2+ - CLI framework
  - Powers entire command interface (squash, clean, import, analyze, etc.)
  - Required for option parsing and command routing

**Core Ruby (Ruby 3.4+ compat):**
- base64 - Standard library replacement for Ruby 3.4+ (`lib/ruly/services/github_client.rb`)
  - Used for Base64 decoding of GitHub API responses

**Infrastructure:**
- YAML - Built-in YAML parsing for recipe and MCP configuration
  - Recipe loader: `lib/ruly/services/recipe_loader.rb`
  - MCP manager: `lib/ruly/services/mcp_manager.rb`
- JSON - Built-in JSON parsing for GitHub API responses
  - GitHub client: `lib/ruly/services/github_client.rb`
- Net::HTTP - Built-in HTTP client for remote file fetching
  - GitHub integration: `lib/ruly/services/github_client.rb`
- URI - Built-in URI parsing and manipulation
- Tempfile - Temporary file handling for GraphQL queries
- FileUtils - File system operations throughout

**Development Only:**
- yalphabetize - YAML alphabetization utility (require: false)

## Configuration

**Environment:**
- Environment variables:
  - `DEBUG` - Enables debug output in GitHub client and other services
  - Not other environment-specific configuration detected (not secrets-based)
- No `.env` file usage detected

**Build:**
- RuboCop config: `.rubocop.yml`
  - NewCops enabled globally
  - Custom Layout/ClassStructure configuration
  - Custom rule severity and autocorrect settings
- Prettier config: `.prettierrc.json`
  - Formats YAML, Markdown, and JavaScript files
- ESLint config: `site/eslint.config.mjs`
- YAML linting: `.yamllint.yml`
- Tailwind CSS: `site/tailwind.config.ts` (via postcss)
- Ruly config: `.ruly.yml`
  - Agent: claude
  - Output: CLAUDE.local.md
  - Recipe: workaxle_core_local
  - Version: 0.1.0

**Next.js Configuration (`site/next.config.ts`):**
- Output mode: Static export (`output: "export"`)
- Base path: `/ruly` for GitHub Pages hosting
- Image optimization disabled for static export

## Platform Requirements

**Development:**
- Ruby 3.3.0 or later
- Bundler for dependency management
- Node.js and npm for site development
- gh CLI (GitHub CLI) for GitHub API operations
  - Used in `lib/ruly/services/github_client.rb`
  - Required for GraphQL and REST API calls
  - Required for repository cloning fallback

**Production:**
- Ruby 3.3.0+ runtime for published gem
- Published on RubyGems with MFA required
- Deployed as standalone gem (can be installed via bundler or directly)
- Site deployed as static HTML (Next.js export)
  - Deployable to GitHub Pages or any static hosting

**Optional CLI Dependencies:**
- gh CLI (GitHub CLI) - For fetching remote rule files from GitHub repositories
- Markdown-to-table tool - For markdown table formatting
- Rake - For running development tasks

---

*Stack analysis: 2026-03-22*
