---
name: ruly:compress
description: Analyze markdown rules to find redundancies and make them more DRY
---

# /ruly:compress Command

## Overview

The `/ruly:compress` command analyzes Claude Code markdown rule files to identify redundancies, repeated patterns, and opportunities to make the documentation more DRY (Don't Repeat Yourself). It suggests consolidation strategies and can optionally apply the improvements.

## Usage

```
/ruly:compress <directories/files...>
```

## Arguments

- `<directories/files...>` - One or more markdown files or directories containing rule files to analyze

## Examples

```bash
# Analyze a single file
/ruly:compress rules/workaxle/core/essential/common.md

# Analyze an entire directory
/ruly:compress rules/workaxle/core/

# Analyze multiple directories
/ruly:compress rules/workaxle/core/ rules/workaxle/pr/

# Analyze all rules
/ruly:compress rules/
```

## Analysis Process

### 1. Pattern Detection

The command identifies:

- **Duplicate content blocks** - Exact or near-exact text appearing in multiple files
- **Similar code examples** - Code snippets with minor variations that could use a template
- **Repeated explanations** - Concepts explained multiple times across files
- **Common patterns** - Frequently used structures that could be extracted
- **Cross-references** - Multiple files referencing the same concept

### 2. Redundancy Types

#### Content Duplication
```markdown
# Found in 3 files:
"Always use Make commands, never run commands directly"
→ Suggestion: Create central command reference
```

#### Pattern Repetition
```ruby
# Found in 5 files with slight variations:
Employee.dataset.not_deleted.where(company:)
→ Suggestion: Extract to common query pattern
```

#### Concept Re-explanation
```markdown
# Soft-delete handling explained in:
- essential/common.md (full explanation)
- testing/specs.md (partial explanation)
- services/patterns.md (brief mention)
→ Suggestion: Single source with references
```

### 3. Compression Strategies

#### Strategy 1: Extract Common Patterns
- Create a central `patterns/` directory for reusable patterns
- Reference patterns instead of duplicating them
- Use YAML frontmatter `requires:` to include shared content

#### Strategy 2: Use Template Files
- Create template files for common structures
- Reference templates with parameters
- Reduce boilerplate across similar files

#### Strategy 3: Consolidate Related Content
- Merge closely related files with high overlap
- Create subsections instead of separate files
- Improve navigation with better structure

#### Strategy 4: Create Reference Sheets
- Extract all commands to a single reference
- Create lookup tables for common patterns
- Build quick reference guides

## Output Format

### Analysis Report

```markdown
# Compression Analysis Report

## Summary
- Files analyzed: 45
- Total lines: 3,250
- Duplicate content: 520 lines (16%)
- Potential reduction: ~400 lines

## High-Priority Redundancies

### 1. Make Command Instructions (87 occurrences)
**Files:** common.md, development.md, quick-reference.md...
**Current:** Each file repeats "Always use Make commands"
**Suggested:** Single source in development-commands.md
**Savings:** ~150 lines

### 2. Sequel Dataset Patterns (45 occurrences)
**Files:** sequel.md, common.md, testing.md...
**Pattern:** `.dataset.not_deleted.where(company:)`
**Suggested:** Extract to sequel-patterns.md
**Savings:** ~90 lines

### 3. Soft-Delete Explanations (23 occurrences)
**Files:** Multiple files explain soft-delete handling
**Suggested:** Consolidate in soft-delete-pattern.md
**Savings:** ~75 lines

## Recommended Actions

1. **Create Central References**
   - [ ] commands-reference.md - All Make commands
   - [ ] sequel-patterns.md - Common query patterns
   - [ ] testing-checklist.md - Testing requirements

2. **Merge Similar Files**
   - [ ] Combine debugging.md and debugging-patterns.md
   - [ ] Merge migration files into single guide

3. **Extract Shared Sections**
   - [ ] Move error handling patterns to dedicated file
   - [ ] Create single source for authentication patterns

## Implementation Plan

### Phase 1: Extract (No Breaking Changes)
- Create new reference files
- Add cross-references from existing files
- Gradually migrate content

### Phase 2: Consolidate
- Merge highly redundant files
- Update requires: sections
- Clean up duplicates

### Phase 3: Optimize
- Implement template system
- Create lookup tables
- Build comprehensive index
```

### Interactive Mode

When compression opportunities are found, the command can offer to:

1. **Generate diff** - Show what changes would be made
2. **Create PR** - Open a pull request with improvements
3. **Apply locally** - Make changes directly
4. **Export report** - Save analysis to file

## Compression Rules

### DO Compress:
- Exact duplicate paragraphs
- Repeated code patterns with minor variations
- Multiple explanations of the same concept
- Boilerplate text that could be templated
- Common command sequences

### DON'T Compress:
- Context-specific examples that aid understanding
- Intentional repetition for emphasis
- Quick reference sections designed for easy lookup
- File-specific configuration or setup

## Advanced Features

### Custom Patterns

Define custom patterns to detect in `.ruly.yml`:

```yaml
compression:
  patterns:
    - name: "make_command"
      regex: "make [a-z-]+"
      suggest: "reference:commands-reference.md"

    - name: "sequel_dataset"
      regex: "\.dataset\.(not_deleted|active)"
      suggest: "pattern:sequel-queries.md"
```

### Similarity Threshold

Configure how similar content must be to be considered duplicate:

```yaml
compression:
  similarity_threshold: 0.85  # 85% similar
  min_block_size: 3  # Minimum lines to consider
```

### Exclusions

Exclude files or patterns from compression:

```yaml
compression:
  exclude:
    - "**/README.md"  # Don't compress READMEs
    - "**/examples/*"  # Keep examples verbose
```

## Integration with Other Commands

Works well with:
- `/ruly:lint` - Check for style issues after compression
- `/ruly:validate` - Ensure references still work
- `/ruly:stats` - Compare before/after metrics

## Benefits

1. **Reduced Maintenance** - Single source of truth
2. **Faster Updates** - Change once, apply everywhere
3. **Better Consistency** - Standardized patterns
4. **Smaller Context** - Less tokens for Claude
5. **Improved Navigation** - Clear structure

## Example Workflow

```bash
# 1. Analyze current state
/ruly:compress rules/ --analyze-only

# 2. Review suggestions
# Opens interactive report

# 3. Apply safe compressions
/ruly:compress rules/ --apply-safe

# 4. Test changes
/ruly:validate rules/

# 5. Apply remaining compressions
/ruly:compress rules/ --apply-all

# 6. Verify and commit
git diff
git commit -m "Compress rules documentation"
```