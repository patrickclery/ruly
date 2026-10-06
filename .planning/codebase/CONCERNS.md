# Codebase Concerns

**Analysis Date:** 2026-03-22

## Tech Debt

**Unsafe YAML loading:**
- Issue: `YAML.load_file` is used in `lib/ruly/operations/analyzer.rb:68` instead of `YAML.safe_load_file`. This could deserialize arbitrary Ruby objects if contexts.yml is compromised.
- Files: `lib/ruly/operations/analyzer.rb`
- Impact: Security vulnerability if untrusted YAML is processed. Deserialization of malicious objects could lead to arbitrary code execution.
- Fix approach: Replace `YAML.load_file(contexts_file)` with `YAML.safe_load_file(contexts_file, aliases: true)` to match the safe pattern used elsewhere in codebase.

**Network calls without timeout handling:**
- Issue: `Net::HTTP.get_response(uri)` and `Net::HTTP.start(...)` in `lib/ruly/services/github_client.rb:162,287` have no timeout configuration. Requests can hang indefinitely if GitHub API becomes unresponsive.
- Files: `lib/ruly/services/github_client.rb`
- Impact: CLI can freeze when fetching remote files. Long-running processes block user interaction. No connection timeout means potential for indefinite blocking on network issues.
- Fix approach: Add explicit timeout values to Net::HTTP calls: `http.read_timeout = 10` and `http.connect_timeout = 10`. Catch `Net::ReadTimeout` and `Net::ConnectTimeout` exceptions with graceful fallback.

**Process/shell execution without error handling:**
- Issue: Backtick shell execution (`` ` ``) used throughout `lib/ruly/services/github_client.rb` (lines 28, 120, 197, 224, 240) relies on `$CHILD_STATUS.success?` but doesn't handle process execution errors before status check. Tempfile created in `execute_github_graphql` could leak if exception occurs after creation.
- Files: `lib/ruly/services/github_client.rb`
- Impact: Unhandled process errors could fail silently. Tempfiles left behind on exceptions. Commands fail without clear error reporting when `gh` CLI is not installed or authentication fails.
- Fix approach: Wrap shell executions in begin/rescue blocks. Use `Tempfile#close!` in ensure block (line 121). Add validation that `gh` CLI is available before attempting use.

**Module function dependency injection complexity:**
- Issue: Heavy use of Proc parameters for dependency injection across multiple layers (RecipeLoader, SourceProcessor, SubagentProcessor, etc.) makes the call chain difficult to trace and test. Functions like `process_for_squash` accept 6+ keyword arguments with nested Procs.
- Files: `lib/ruly/services/source_processor.rb:22-56`, `lib/ruly/services/subagent_processor.rb:28-63`, `lib/ruly/services/dependency_resolver.rb:11-45`
- Impact: High cognitive load when debugging. Easy to pass wrong Proc or miss required dependencies. Error messages lack context about which stage failed.
- Fix approach: Extract dependency bundles into a Dependency or Context object. Create factory methods that validate all required dependencies before use. Add logging at entry/exit of major processing steps.

## Known Bugs

**Missing file path normalization in dependency resolution:**
- Symptoms: Symlinks or relative paths with `..` segments may not deduplicate correctly when the same file is referenced multiple ways (e.g., `/rules/core.md` and `/rules/./core.md` treated as different files, causing duplication in output).
- Files: `lib/ruly/services/dependency_resolver.rb:79-88`, `lib/ruly/services/source_processor.rb:43`
- Trigger: Use `..` in requires paths or reference files through symlinks
- Workaround: Always use canonical absolute paths in `requires:` frontmatter. Resolve symlinks manually.

**Graph query tempfile left in cwd on exception:**
- Symptoms: Temporary GraphQL query files accumulate in current working directory after failed GitHub API calls
- Files: `lib/ruly/services/github_client.rb:115-131` (execute_github_graphql method)
- Trigger: Network failure or malformed GraphQL response during prefetch
- Workaround: None. Manually delete accumulated `.txt` files from tempdir.

## Security Considerations

**GitHub CLI authentication not validated:**
- Risk: Code assumes `gh` CLI is installed and authenticated. No check before use. Could silently fail or use cached credentials from unintended account.
- Files: `lib/ruly/services/github_client.rb` (lines 28, 120, 197, 224, 240)
- Current mitigation: Exit with warning on GraphQL failures. But REST API failures in `fetch_via_gh_api` may not be obvious.
- Recommendations: Add `verify_gh_cli_setup!` method that runs `gh auth status` and validates user at startup. Store verified state to avoid repeated checks. Fail fast with clear message if `gh` not available.

**Arbitrary shell command execution via repo URLs:**
- Risk: Remote source URLs in recipes are passed to backtick commands without shell escaping. If a recipe contains a malicious GitHub URL, shell injection could occur.
- Files: `lib/ruly/services/github_client.rb:28`, line: `gh api repos/#{owner}/#{repo}/contents/#{path}?ref=#{branch}`
- Current mitigation: URL parts extracted via regex, reducing injection surface. But `branch` and `path` extracted with `Regexp.last_match()` without validation.
- Recommendations: Validate extracted URL components before shell use. Consider using GitHub REST API client library instead of shelling to `gh`. Add integration test with malicious branch names.

**MCP server configs may contain secrets:**
- Risk: `.mcp.json` or `mcp.yml` files could contain API keys for MCP servers. These are not in .gitignore pattern and could be accidentally committed.
- Files: `lib/ruly/services/mcp_manager.rb:65-92` (update_mcp_settings method writes to .mcp.json)
- Current mitigation: No built-in secret detection. Relies on user gitignore discipline.
- Recommendations: Add validation to warn when MCP config written with plaintext credentials. Document that `.mcp.json` must be in `.gitignore`. Consider encrypting MCP config at rest.

## Performance Bottlenecks

**GraphQL query builds unbounded list:**
- Problem: `build_graphql_files_query` creates one query alias per source file without pagination or batching limits. For recipes with 500+ remote files, GraphQL query could exceed GitHub API request body limits.
- Files: `lib/ruly/services/github_client.rb:94-110`
- Cause: No upper limit on file count per GraphQL batch. No fallback to sequential fetches if batch fails.
- Improvement path: Add max query size (e.g., 50 files per query). Implement batching loop. Fall back to individual REST API calls if GraphQL fails.

**Token counting on every file read:**
- Problem: `lib/ruly/operations/stats.rb` and analyzer use `TikToken` to count tokens for every source file to generate statistics. For large recipes (100+ files), this causes visible slowdown.
- Files: `lib/ruly/operations/analyzer.rb:51-61`, `lib/ruly/operations/stats.rb` (throughout)
- Cause: No caching of token counts. Recomputes for every `analyze` or `stats` command.
- Improvement path: Cache token counts in `.ruly.cache/` with file hash. Invalidate when file mtime changes. Skip token counting unless explicitly requested with `--stats` flag.

**Ambiguous link checking is O(n²):**
- Problem: `lib/ruly/checks/ambiguous_links.rb` iterates all sources for anchors, then all sources again for links. For 100+ source files, this is slow.
- Files: `lib/ruly/checks/ambiguous_links.rb:9-26`
- Cause: Two separate passes over sources. Regex scan on every line.
- Improvement path: Single pass: build anchor map while extracting links simultaneously. Use optimized regex compilation.

## Fragile Areas

**Recipe YAML extends inheritance:**
- Files: `lib/ruly/services/recipe_loader.rb:99-150` (resolve_extends! method)
- Why fragile: Multi-level recipe inheritance (recipe A extends B extends C) can create cycles or deeply nested chains that are hard to debug. No depth limit or cycle detection.
- Safe modification: Add cycle detection using visited set before processing extends. Document max nesting depth (suggest 3 levels). Add test for circular extends.
- Test coverage: Missing tests for circular recipe inheritance and deep nesting scenarios.

**Subagent dispatch validation:**
- Files: `lib/ruly/services/subagent_processor.rb:92-98` (validate_no_nested_subagents!, validate_no_subagent_dispatches!)
- Why fragile: Validation inspects frontmatter of loaded sources to detect dispatch markers (`/dispatch`). If markers are in code blocks or comments, validation will incorrectly flag them as errors. False positives block legitimate usage.
- Safe modification: Improve marker detection to skip code blocks. Parse frontmatter first, check only in body. Add allow list for command names that can appear in body.
- Test coverage: Missing tests for dispatch markers in code blocks and comments.

**File write order and atomicity:**
- Files: `lib/ruly/cli.rb:336-355` (write_squash_output, appending taskmaster config)
- Why fragile: Writes output file, then appends taskmaster content in separate `open` call. If process crashes between writes, output is malformed. No backup of previous file.
- Safe modification: Write to temp file first, validate completeness, then move atomically. Or use single file handle for all writes.
- Test coverage: No tests for partial write recovery or atomic file operations.

**Skill requires deduplication detection:**
- Files: `lib/ruly/checks/duplicate_skill_requires.rb:20-50`
- Why fragile: Builds require map by resolving paths and getting realpath. If symlinks point to different targets or if a path can't be resolved, the file silently skips (next without warning). Similar files may not be detected as duplicates.
- Safe modification: Log when a skill's requires can't be resolved. Add `--strict` mode that fails on unresolved requires.
- Test coverage: Missing tests for unresolved symlinks and path resolution failures.

## Scaling Limits

**GitHub GraphQL batch fetches limited to query complexity:**
- Current capacity: ~50-100 files per GraphQL query before hitting GitHub's query complexity limits
- Limit: Recipes with 500+ remote files will timeout or fail during prefetch
- Scaling path: Implement adaptive batching. Reduce batch size if complexity quota exceeded. Fall back to REST API with caching.

**Tempfile usage accumulation:**
- Current capacity: One tempfile per GraphQL query, cleaned up on success
- Limit: On repeated failures, tempfiles accumulate in system temp directory
- Scaling path: Use file finalizers or explicit cleanup on error. Use `Tempfile#unlink` in ensure block consistently.

**Recipe YAML parsing memory growth:**
- Current capacity: Entire recipes.yml loaded into memory for deduplication across recipes
- Limit: For 100+ recipes with large file lists, memory usage grows linearly
- Scaling path: Lazy-load recipe files, parse only referenced recipes. Use streaming YAML parser if available.

## Dependencies at Risk

**tiktoken_ruby version constraint:**
- Risk: Locked to `~> 0.0.9` (allows 0.0.9 to 0.0.x but not 0.1.0+). This is an early version gem. If upstream breaks API or deprecates, upgrade path is unclear.
- Impact: Token counting will fail or give inaccurate counts if upstream changes.
- Migration plan: Pin to exact version (0.0.9) for stability. Monitor upstream for 0.1.0 release. Test token count accuracy against known samples when upgrading.

**Thor CLI framework:**
- Risk: thor ~> 1.2 is stable but relatively heavy dependency for CLI args. If upstream changes flag parsing or output format, could break parsing.
- Impact: Low impact, Thor is well-maintained. But consider if simpler OptionParser would suffice.
- Migration plan: Currently no immediate action needed. Monitor Thor releases for breaking changes.

**webmock for testing:**
- Risk: Used only in test/development. Could mask real network issues if mocks don't match actual GitHub API behavior.
- Impact: Tests pass but real GitHub calls fail due to schema mismatch.
- Migration plan: Add integration tests that call actual GitHub API (gated behind ENV var). Validate webmock mocks against live API periodically.

## Missing Critical Features

**No progress or cancellation support:**
- Problem: Long-running operations (especially prefetch for large recipes) have no progress indication or ability to cancel. User sees nothing for 30+ seconds.
- Blocks: Users can't see what's happening or estimate time. No way to Ctrl+C gracefully mid-operation.

**No caching of GitHub API responses:**
- Problem: Same remote file fetched multiple times if recipe squashed multiple times (e.g., dev vs prod builds). No persistent cache.
- Blocks: Slow rebuild for CI/CD pipelines. Wasted GitHub API quota.

**No validation of recipe file completeness:**
- Problem: Recipe references files that don't exist in project. Only discovered at squash time when file not found.
- Blocks: Recipe broken until missing files added. No early warning.

## Test Coverage Gaps

**Network I/O not fully tested:**
- What's not tested: Net::HTTP timeout behavior, connection failures, and partial response handling
- Files: `lib/ruly/services/github_client.rb`
- Risk: Silent failures or hangs in production. No handling of common network errors (ECONNREFUSED, timeout, etc.).
- Priority: High

**Tempfile cleanup on exceptions:**
- What's not tested: Behavior when GraphQL query fails after tempfile creation. Are tempfiles cleaned up?
- Files: `lib/ruly/services/github_client.rb:115-131`
- Risk: Disk space accumulation over time. Difficult to diagnose without explicit test.
- Priority: Medium

**Recipe YAML extends with cycles:**
- What's not tested: Circular recipe inheritance (A extends B, B extends A) or self-extends
- Files: `lib/ruly/services/recipe_loader.rb`
- Risk: Infinite loop or stack overflow when resolving extensions.
- Priority: Medium

**Shell command escaping:**
- What's not tested: Malicious GitHub URLs or branch names with shell metacharacters in backtick calls
- Files: `lib/ruly/services/github_client.rb`
- Risk: Shell injection if URL validation is bypassed.
- Priority: High

**Symlink deduplication:**
- What's not tested: Behavior when same file referenced via symlink and canonical path
- Files: `lib/ruly/services/dependency_resolver.rb`, `lib/ruly/services/source_processor.rb`
- Risk: File duplication in output when symlinks involved.
- Priority: Medium

**Subagent nesting validation:**
- What's not tested: False positives when dispatch markers appear in code blocks or comments
- Files: `lib/ruly/services/subagent_processor.rb`
- Risk: Legitimate recipes rejected as invalid.
- Priority: Medium

---

*Concerns audit: 2026-03-22*
