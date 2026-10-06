# External Integrations

**Analysis Date:** 2026-03-22

## APIs & External Services

**GitHub:**
- GitHub REST API - Fetching rule files from remote repositories
  - Client: `lib/ruly/services/github_client.rb`
  - Methods: `fetch_github_markdown_files()`, `fetch_via_gh_api()`
  - Auth: GitHub CLI (gh) authentication
- GitHub GraphQL API - Batch fetching multiple files from repositories
  - Client: `lib/ruly/services/github_client.rb`
  - Methods: `fetch_github_files_graphql()`, `execute_github_graphql()`
  - Query builder: `build_graphql_files_query()`
  - Auth: GitHub CLI (gh) authentication
- GitHub.com URL handling - Normalization and URL processing
  - Converts standard github.com URLs to raw.githubusercontent.com
  - Supports shallow cloning as fallback fetch mechanism
  - Client: `lib/ruly/services/github_client.rb`

**AI/LLM Services:**
- OpenAI (indirect) - Token counting only
  - SDK: tiktoken_ruby 0.0.9
  - Usage: `lib/ruly/operations/analyzer.rb` (Analyzer class)
  - Purpose: Calculate token budgets for recipe compilation and analysis
  - Not authenticated in code - token counting is local only

**Raw HTTP Fetching:**
- Generic URL HTTP client - For non-GitHub remote file fetching
  - Client: `lib/ruly/services/github_client.rb`
  - Method: `fetch_remote_content()`, `fetch_url()`
  - Uses: Net::HTTP with proper User-Agent headers
  - Headers: `Accept: application/vnd.github.v3+json` for GitHub API

## Data Storage

**Databases:**
- None detected - Ruly is stateless CLI tool

**File Storage:**
- Local filesystem only
  - Rule files: `rules/` directory structure
  - Recipes: `recipes.yml` in project root and `~/.config/ruly/recipes.yml`
  - Generated output: `CLAUDE.local.md` (default output file)
  - MCP config: `mcp.json` or `mcp.yml` in working directory
  - Temporary files: `/tmp/ruly_fetch_{PID}/` for cloned repositories
    - Auto-cleaned with `FileUtils.rm_rf()` after use

**Caching:**
- File-based caching of squash operations
  - Location: `.ruly.cache` or recipe-specific cache
  - Method: `cached?()` in CLI
  - Usage: Optional cache flag in squash command (`--cache`)
  - No persistent service-based caching

## Authentication & Identity

**Auth Provider:**
- GitHub CLI (gh) - Implicit authentication
  - Not explicitly configured in Ruly code
  - Ruly shelled out to `gh` CLI which handles authentication
  - User must have GitHub CLI configured with valid credentials
  - Commands used: `gh api`, `gh repo clone`, `gh repo view`

**No Direct Service Auth:**
- No API keys stored in code
- No OAuth flows implemented
- No service credentials in configuration

## Monitoring & Observability

**Error Tracking:**
- None - Stateless CLI with no external error reporting

**Logs:**
- Console output only
- Debug mode via `ENV['DEBUG']` flag
  - Enables debug output in: `lib/ruly/services/github_client.rb`
  - Outputs API calls, response parsing, and fetch attempts
- Warning messages: Unicode emoji-based visual indicators
  - ⚠️ for warnings
  - ✅ for successes
  - 🔄 for processing
- No log file persistence detected

## CI/CD & Deployment

**Hosting:**
- RubyGems - Gem hosting and distribution
  - Package: ruly
  - MFA required for publishing

**CI Pipeline:**
- Lefthook - Git hooks for local development
  - Config: `lefthook.yml`
  - Purpose: Pre-commit checks
- No external CI/CD service detected in code

**Deployment:**
- Manual gem release to RubyGems
- Documentation site (Next.js) deployable as static export
- No automated deployment pipeline in code

## Environment Configuration

**Required env vars:**
- `DEBUG` (optional) - Enables debug logging in GitHub operations
  - Checked in: `lib/ruly/services/github_client.rb`
- `HOME` (implicit) - For detecting user home directory
  - Used for config file locations: `~/.config/ruly/`

**Secrets location:**
- GitHub CLI authentication - Stored in user's gh CLI config
  - Location: `~/.config/gh/` or platform-specific equivalent
  - Managed by GitHub CLI, not by Ruly
- No other secrets detected in codebase

**Configuration files:**
- `~/.config/ruly/recipes.yml` - User recipes (must sync with project `recipes.yml`)
- `~/.config/ruly/mcp.json` - MCP server definitions
- `.ruly.yml` - Project-level Ruly configuration
- `mcp.yml` - Legacy MCP configuration (deprecated, replaced by `mcp.json`)

## Webhooks & Callbacks

**Incoming:**
- None - Ruly is a CLI tool, not a server

**Outgoing:**
- None - No external webhooks or callbacks

## GitHub-Specific Integration Details

**Remote File Fetching Strategy:**
1. First attempt: GitHub REST API via `gh api` (fastest)
2. Fallback: Shallow clone via `gh repo clone` with `--depth=1`
   - Temporary location: `/tmp/ruly_fetch_{process_id}/`
   - Auto-cleaned after extraction

**Batch Operations:**
- GraphQL multi-file fetch optimization
  - Groups remote sources by repository
  - Batch fetches multiple files in single GraphQL query
  - Falls back to individual fetching on failure

**URL Normalization:**
- Supports GitHub shorthand: `github:owner/repo/path` → full URL
- Converts blob URLs to raw.githubusercontent.com for direct content fetch
- Handles tree/directory URLs with directory listing

**Repository Metadata:**
- Fetches default branch via: `gh repo view {owner}/{repo} --json defaultBranchRef`
- Used for fallback branch resolution in cloning

---

*Integration audit: 2026-03-22*
