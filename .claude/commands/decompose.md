---
name: decompose
description: Decompose a markdown file into a directory of section-based files with anchor links
---

# /decompose Command

## Overview

The `/decompose` command splits a markdown file into a directory of separate files based on its section headers. It uses `git mv` to preserve history, moving the original file to become the index file (`_common-{tag}.md`) that references all extracted sections via anchor links.

## Usage

```
/decompose <file> <directory>
```

## Arguments

- `<file>` - The markdown file to decompose
- `<directory>` - The name for the output directory (e.g., "standards", "patterns")

## Examples

```bash
# Decompose common.md into a "standards" directory
/decompose rules/workaxle/core/frameworks/common.md standards

# Decompose debugging.md into a "troubleshooting" directory
/decompose rules/bug/debugging.md troubleshooting
```

## Example Transformation

**Before** (`rules/core/common.md`):
```markdown
---
description: Common Ruby patterns
globs:
  - '**/*.rb'
---

# Ruby Language Patterns

## Code Style

Content about code style...

## Error Handling

Content about error handling...

## Testing

Content about testing...
```

**After decomposition** into `standards/`:

```
rules/core/standards/
├── _common-ruby-language-patterns.md  # Index (original file, moved via git mv)
├── code-style.md                      # Extracted section
├── error-handling.md                  # Extracted section
└── testing.md                         # Extracted section
```

`standards/_common-ruby-language-patterns.md` (index):
```yaml
---
description: Common Ruby patterns
globs:
  - '**/*.rb'
requires:
  - ./code-style.md
  - ./error-handling.md
  - ./testing.md
---
```
```markdown
# Ruby Language Patterns

## Code Style

See [Code Style](#code-style) for code style patterns.

## Error Handling

See [Error Handling](#error-handling) for error handling patterns.

## Testing

See [Testing](#testing) for testing patterns.
```

`standards/code-style.md`:
```markdown
---
description: Code style guidelines
alwaysApply: false
---

# Code Style

Content about code style...
```

## Index File Naming

The index file is named `_common-{tag}.md` where `{tag}` is derived from:

1. **Primary**: The H1 (`#`) header text, slugified (kebab-case)
   - `# Ruby Language Patterns` → `_common-ruby-language-patterns.md`
   - `# Debugging Methodology` → `_common-debugging-methodology.md`

2. **Fallback**: If no H1 header, use the `description` from frontmatter, slugified

3. **Last resort**: Use the original filename as the tag

## Process

### Step 1: Parse the File

1. Read the input file
2. Extract existing frontmatter (to preserve)
3. Identify the H1 header (for the `{tag}` in `_common-{tag}.md`)
4. Identify all H2 section headers (for extraction)
5. For each H2 header, capture:
   - The header text (e.g., "Code Style")
   - All content until the next H2 header (including nested H3, H4, etc.)

### Step 2: Generate Preview

Show the user what will happen:

```
╔══════════════════════════════════════════════════════════════╗
║                    DECOMPOSITION PREVIEW                     ║
╠══════════════════════════════════════════════════════════════╣
║ Source: rules/core/common.md                                 ║
║ Target directory: rules/core/standards/                      ║
║ Sections found: 3                                            ║
╠══════════════════════════════════════════════════════════════╣
║ GIT MV (preserves history):                                  ║
║   common.md → standards/_common-ruby-language-patterns.md    ║
╠══════════════════════════════════════════════════════════════╣
║ EXTRACTED FILES:                                             ║
║   standards/code-style.md         (from "## Code Style")     ║
║   standards/error-handling.md     (from "## Error Handling") ║
║   standards/testing.md            (from "## Testing")        ║
╚══════════════════════════════════════════════════════════════╝
```

### Step 3: Wait for Confirmation

Accept ONLY "decompose it" (case-insensitive, exact match).

**If user says anything else:** Ask for clarification or cancel.

### Step 4: Execute Decomposition

After confirmation:

1. **Create directory**: `mkdir -p {directory}/`

2. **Move original file with git**:
   ```bash
   git mv {file} {directory}/_common-{tag}.md
   ```
   This preserves git history for the file.

3. **Create extracted files**: For each H2 section, create a file in the new directory
   - Filename: kebab-case slug of the header (e.g., "## Error Handling" → `error-handling.md`)
   - Content: Section header (promoted to H1) + all content until next H2
   - Frontmatter: Add `description` and `alwaysApply: false`

4. **Update index file**: Modify the moved file to contain:
   - Preserved original frontmatter
   - Added `requires:` listing all extracted files (relative paths with `./`)
   - The H1 header
   - H2 stubs with anchor links: `See [Section Name](#section-anchor)`

### Step 5: Report Results

```
✅ Decomposition complete!

Created directory: rules/core/standards/

Git moved:
  common.md → standards/_common-ruby-language-patterns.md

Created files:
  • code-style.md (45 lines)
  • error-handling.md (32 lines)
  • testing.md (28 lines)
```

## Slug Generation Rules

Convert header text to filename slug (kebab-case):

1. Remove emoji characters
2. Convert to lowercase
3. Replace spaces with hyphens
4. Remove special characters (keep alphanumeric and hyphens)
5. Remove leading/trailing hyphens
6. Collapse multiple hyphens to single

**Examples:**
- "## Code Style" → `code-style.md`
- "## 🛡️ Guard Clauses" → `guard-clauses.md`
- "# Ruby Language Patterns" → `_common-ruby-language-patterns.md`
- "## API v2 Changes" → `api-v2-changes.md`

## Anchor Generation Rules

Convert header text to anchor (for linking after `ruly squash`):

1. Remove emoji characters
2. Convert to lowercase
3. Replace spaces with hyphens
4. Remove special characters (keep alphanumeric and hyphens)

**Examples:**
- "## Code Style" → `#code-style`
- "## Error Handling" → `#error-handling`

## Important Rules

### DO:

- ✅ Show preview before making any changes
- ✅ Wait for explicit "decompose it" confirmation
- ✅ Use `git mv` to move the original file (preserves history)
- ✅ Name index file `_common-{tag}.md` where tag is from H1 header
- ✅ Preserve all content within sections (including nested headers)
- ✅ Use relative paths (`./`) in `requires:` frontmatter
- ✅ Preserve existing frontmatter from the original file

### DO NOT:

- ❌ Execute without showing preview first
- ❌ Accept vague confirmations (only "decompose it")
- ❌ Delete the original file (use `git mv` instead)
- ❌ Delete or overwrite the target directory (other decomposed files may exist there)
- ❌ Use generic names without the tag (e.g., just `_common.md`)
- ❌ Strip nested headers from extracted content
- ❌ Use absolute paths in `requires:` frontmatter

## Edge Cases

### Directory Already Exists

This is normal - multiple files can be decomposed into the same directory. Just add new files alongside existing ones:
```
ℹ️ Directory exists: standards/
   Adding new files alongside existing content.
```

**Only warn if a specific file would be overwritten:**
```
⚠️ File already exists: standards/error-handling.md
   Overwrite? (yes/no)
```

### File Not Under Git Control

If the file is not tracked by git, fall back to regular `mv`:
```
ℹ️ File not under git control. Using regular move instead of git mv.
```

### File Has Only One H2 Section

Report that decomposition may not be useful:
```
ℹ️ File has only one section. Decomposition would create just one file.
   Continue anyway? (yes/no)
```

### File Has No H2 Sections

Report that no sections were found:
```
⚠️ No H2 (##) sections found. Nothing to decompose.
```

### No H1 Header for Tag

If the file has no H1 header:
1. Use the `description` from frontmatter, slugified
2. If no description, use the original filename as the tag

### Content Before First H2

If there's content between the H1 and first H2 (e.g., an intro paragraph), include it in the index file above the section stubs.

### Existing Frontmatter

Merge existing frontmatter with the new `requires:` field in the index file. Preserve all original fields.
