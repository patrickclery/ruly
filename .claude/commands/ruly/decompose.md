---
name: ruly:decompose
description: Decompose a markdown file into smaller section-based files with automatic anchor linking
---

# /ruly:decompose Command

## Overview

The `/ruly:decompose` command analyzes a markdown file and splits it into smaller, focused files based on its section headers. The original file is modified to reference the extracted sections via markdown anchor links, and the `requires:` frontmatter is automatically updated.

## Usage

```
/ruly:decompose <file-path> [--level N] [--min-lines N]
```

## Arguments

- `<file-path>` - The markdown file to decompose (required)
- `--level N` - Header level to split on (default: 2, meaning `##` headers)
- `--min-lines N` - Minimum lines in a section to extract (default: 10)

## Examples

```bash
# Decompose a file at level 2 headers (##)
/ruly:decompose rules/workaxle/core/common.md

# Split on level 3 headers (###)
/ruly:decompose rules/bug/debugging.md --level 3

# Only extract sections with 20+ lines
/ruly:decompose rules/workaxle/core.md --min-lines 20
```

## Process

### Step 1: Parse the Source File

1. Read the source markdown file
2. Extract existing frontmatter (preserve it)
3. Identify all headers at the specified level
4. Calculate section boundaries

### Step 2: Identify Extractable Sections

For each section at the target header level:
1. Count lines in the section (including subsections)
2. If lines >= min-lines threshold, mark for extraction
3. Generate a slug from the header text (e.g., "Debugging Methodology" -> "debugging-methodology")

### Step 3: Create Extracted Files

For each extractable section:

**File naming:** `{original-basename}-{section-slug}.md`

Example: `common.md` with section "## Quick Reference" -> `common-quick-reference.md`

**File content:**
```markdown
---
description: [Section header text]
alwaysApply: false
---

# [Section Header]

[Section content including all subsections]
```

### Step 4: Modify Original File

Replace extracted section content with an anchor link reference:

**Before:**
```markdown
## Debugging Methodology

Long content about debugging...
Multiple paragraphs...
Code examples...
```

**After:**
```markdown
## Debugging Methodology

See [Debugging Methodology](#debugging-methodology) in the extracted file.

For details, refer to the full section in [common-debugging-methodology.md](#debugging-methodology).
```

### Step 5: Update requires: Frontmatter

Add all extracted files to the `requires:` array in the original file's frontmatter:

**Before:**
```yaml
---
description: Common patterns
alwaysApply: false
---
```

**After:**
```yaml
---
description: Common patterns
alwaysApply: false
requires:
  - common-debugging-methodology.md
  - common-quick-reference.md
---
```

## Output

The command produces:

1. **Modified original file** - With section placeholders and updated `requires:`
2. **Extracted section files** - One per extracted section
3. **Summary report** - Shows what was extracted

### Example Summary

```
=== Decomposition Summary ===
Source: rules/workaxle/core/common.md

Extracted sections:
  1. common-debugging-methodology.md (45 lines)
  2. common-quick-reference.md (28 lines)
  3. common-service-patterns.md (67 lines)

Original file updated:
  - 3 sections replaced with anchor links
  - requires: frontmatter updated with 3 entries

Total reduction: 140 lines -> 35 lines (75% reduction)
```

## Anchor Link Format

**CRITICAL:** Use markdown anchor links that work after `ruly squash`:

```markdown
See [Section Name](#section-name-slug) for details.
```

The anchor slug is generated from the header text:
- Lowercase
- Spaces -> hyphens
- Remove special characters
- Example: "Quick Reference (Commands)" -> `#quick-reference-commands`

## Edge Cases

### Preserving Context

When a section is extracted, include a brief context note in the original:

```markdown
## Debugging Methodology

> **Extracted:** Full content in [Debugging Methodology](#debugging-methodology).

[Optional 1-2 sentence summary if needed for context]
```

### Nested Headers

When extracting a `##` section, include ALL nested `###`, `####`, etc. headers in the extracted file.

### Frontmatter Preservation

- Preserve all existing frontmatter fields
- Only modify/add the `requires:` array
- Maintain YAML formatting

### Already Extracted Sections

If a section only contains an anchor link reference, skip it (already extracted).

## Integration

Works well with:
- `/ruly:compress` - Analyze for redundancies before decomposing
- `/ruly:validate` - Verify anchor links after decomposition
- `ruly squash` - Combines files while maintaining anchor targets

## Verification

After running, verify:
1. All extracted files exist
2. Original file has correct anchor links
3. `requires:` frontmatter includes all extracted files
4. Run `ruly squash --recipe <recipe>` to verify anchors resolve
