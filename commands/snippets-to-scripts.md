---
description: Extract inline bash snippets from markdown files into reusable shell scripts
alwaysApply: false
---

# Snippets to Scripts

## Overview

The `/snippets-to-scripts` command scans markdown files for bash code snippets and extracts them into standalone shell scripts in the `rules/bin/` directory. This promotes code reuse, maintainability, and testability.

## Usage

```
/snippets-to-scripts [file-pattern] [options]
```

### Arguments

- `file-pattern` - Glob pattern for files to scan (default: `**/*.md`)
- `--output-dir` - Directory for generated scripts (default: `rules/bin/`)
- `--dry-run` - Preview changes without creating files
- `--min-lines` - Minimum lines for extraction (default: 5)
- `--interactive` - Prompt for each extraction

### Examples

```bash
# Extract from all markdown files
/snippets-to-scripts

# Extract from specific directory
/snippets-to-scripts "workaxle-rules/commands/**/*.md"

# Preview what would be extracted
/snippets-to-scripts --dry-run

# Extract only larger snippets
/snippets-to-scripts --min-lines=10
```

## Process

### Step 1: Scan for Snippets

The command searches for bash/sh code blocks in markdown:

```ruby
# Find all bash snippets in markdown files
snippets = []
Dir.glob(file_pattern).each do |file|
  content = File.read(file)
  
  # Match bash code blocks
  content.scan(/^```(?:bash|sh|shell)\n(.*?)^```/m) do |match|
    code = match[0]
    line_num = content[0..content.index(match[0])].count("\n")
    
    snippets << {
      file: file,
      line: line_num,
      code: code,
      context: extract_context(content, line_num)
    }
  end
end
```

### Step 2: Analyze Snippets

Determine which snippets should become scripts:

```ruby
extractable = snippets.select do |snippet|
  # Skip if too short
  next false if snippet[:code].lines.count < min_lines
  
  # Skip if it's just a single command
  next false if single_command?(snippet[:code])
  
  # Skip if it's example usage/documentation
  next false if example_usage?(snippet[:code])
  
  # Good candidates:
  # - Multi-step processes
  # - Reusable functions
  # - Complex pipelines
  # - Repeated patterns
  true
end
```

### Step 3: Generate Script Names

Create meaningful script names from context:

```ruby
def generate_script_name(snippet)
  context = snippet[:context]
  file_path = snippet[:file]
  
  # Extract from heading or description
  if context[:heading] =~ /Step \d+: (.+)/
    name = $1.downcase.gsub(/\s+/, '-')
  elsif file_path =~ /commands\/(\w+)\/(\w+)\.md/
    name = "#{$1}-#{$2}"
  else
    # Generate from code purpose
    name = analyze_purpose(snippet[:code])
  end
  
  # Ensure uniqueness
  "#{name}.sh"
end
```

### Step 4: Extract Common Patterns

Identify and extract common snippet patterns:

#### Pattern: File Change Detection
```bash
# Original snippet
FILES=$(git diff --name-only $(git merge-base HEAD origin/main)..HEAD)
RUBY_FILES=$(echo "$FILES" | grep -E '\.(rb|rake|gemspec)$' || true)
SPEC_FILES=$(echo "$FILES" | grep -E '_spec\.rb$' || true)
```

Becomes `rules/bin/detect-changed-files.sh`:
```bash
#!/bin/bash
# Detect changed files by type from current branch

BASE_BRANCH="${1:-origin/main}"
FILES=$(git diff --name-only $(git merge-base HEAD "$BASE_BRANCH")..HEAD)

# Export for use in other scripts
export CHANGED_FILES="$FILES"
export RUBY_FILES=$(echo "$FILES" | grep -E '\.(rb|rake|gemspec)$' || true)
export SPEC_FILES=$(echo "$FILES" | grep -E '_spec\.rb$' || true)
export JS_FILES=$(echo "$FILES" | grep -E '\.(js|jsx|ts|tsx)$' || true)
export PY_FILES=$(echo "$FILES" | grep -E '\.py$' || true)

# Output if running directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
  echo "Changed files detected:"
  [ -n "$RUBY_FILES" ] && echo "  Ruby: $(echo $RUBY_FILES | wc -w) files"
  [ -n "$JS_FILES" ] && echo "  JavaScript: $(echo $JS_FILES | wc -w) files"
  [ -n "$PY_FILES" ] && echo "  Python: $(echo $PY_FILES | wc -w) files"
fi
```

#### Pattern: Test Runner
```bash
# Original snippet
if [ -n "$REQUIRED_TESTS" ]; then
  echo "🔒 Running required tests..."
  make spec T="$REQUIRED_TESTS"
  if [ $? -ne 0 ]; then
    echo "❌ Required tests failed!"
    exit 1
  fi
fi
```

Becomes `rules/bin/run-required-tests.sh`:
```bash
#!/bin/bash
# Run required tests from tmp/required-tests

REQUIRED_TESTS=""
if [ -f tmp/required-tests ]; then
  REQUIRED_TESTS=$(cat tmp/required-tests | tr '\n' ' ')
fi

if [ -n "$REQUIRED_TESTS" ]; then
  echo "🔒 Running $(echo $REQUIRED_TESTS | wc -w) required tests..."
  make spec T="$REQUIRED_TESTS"
  
  if [ $? -ne 0 ]; then
    echo "❌ Required tests failed!"
    exit 1
  fi
  
  echo "✅ All required tests passed"
else
  echo "📋 No required tests configured"
fi
```

#### Pattern: Countdown Timer
```bash
# Original snippet
for i in $(seq $WAIT_TIME -1 1); do
  printf "\r⏳ Time remaining: %02d seconds" $i
  sleep 1
done
```

Becomes `rules/bin/countdown-timer.sh`:
```bash
#!/bin/bash
# Display countdown timer with custom message

WAIT_TIME="${1:-30}"
MESSAGE="${2:-Time remaining}"

echo "⏱️ Starting ${WAIT_TIME} second countdown..."
for i in $(seq $WAIT_TIME -1 1); do
  printf "\r⏳ %s: %02d seconds" "$MESSAGE" $i
  sleep 1
done
printf "\r✅ %s: Complete!        \n" "$MESSAGE"
```

### Step 5: Update Original Files

Replace inline snippets with script references:

```ruby
def update_markdown_file(file, replacements)
  content = File.read(file)
  
  replacements.each do |replacement|
    original = replacement[:original]
    script_path = replacement[:script_path]
    script_name = File.basename(script_path)
    
    # Create usage example
    usage_example = generate_usage_example(script_path)
    
    # Replace with reference
    new_content = <<~MD
      ```bash
      # Run the #{script_name.sub('.sh', '')} script
      #{usage_example}
      ```
      
      _See `#{script_path}` for implementation details._
    MD
    
    content.sub!(original, new_content)
  end
  
  File.write(file, content)
end
```

### Step 6: Generate Script Documentation

Add documentation to extracted scripts:

```bash
#!/bin/bash
# Generated from: workaxle-rules/commands/testing/pre-commit.md#L151-172
# Purpose: Final verification of all pre-commit checks
# Usage: ./rules/bin/final-verification.sh [ruby_files] [js_files] [py_files]
#
# This script performs final verification of linting and tests before commit.
# It checks Ruby, JavaScript, and Python files based on provided arguments.

RUBY_FILES="$1"
JS_FILES="$2"
PY_FILES="$3"

echo "✅ Running final verification..."

# ... rest of extracted code ...
```

## Detection Patterns

### Extractable Snippets

The command identifies these patterns as good extraction candidates:

1. **Multi-step processes** - Sequential operations with error handling
2. **Conditional workflows** - Complex if/then logic flows
3. **Loop operations** - Iteration over files or results
4. **Reusable functions** - Code that could be parameterized
5. **Common patterns** - Code repeated across multiple files

### Non-Extractable Snippets

These patterns are NOT extracted:

1. **Single commands** - Simple one-liners
2. **Example usage** - Documentation examples
3. **Configuration** - Environment-specific settings
4. **Inline comments** - Explanatory code
5. **Variable definitions** - Simple assignments

## Output Structure

Generated scripts follow this structure:

```
rules/bin/
├── pre-commit/
│   ├── detect-changed-files.sh
│   ├── run-rubocop.sh
│   ├── run-tests.sh
│   └── final-verification.sh
├── testing/
│   ├── run-required-tests.sh
│   └── manage-required-tests.sh
├── pr/
│   ├── resolve-comments.sh
│   └── monitor-workflow.sh
└── common/
    ├── countdown-timer.sh
    ├── check-status.sh
    └── git-helpers.sh
```

## Script Templates

### Basic Script Template
```bash
#!/bin/bash
# Generated from: [source-file]#[line-range]
# Purpose: [extracted-purpose]
# Usage: [script-name] [arguments]

set -e  # Exit on error

# [Extracted code with parameterization]
```

### Function Library Template
```bash
#!/bin/bash
# Common functions extracted from multiple sources
# Source this file: source rules/bin/common/functions.sh

function countdown_timer() {
  local wait_time="${1:-30}"
  local message="${2:-Time remaining}"
  # ... implementation ...
}

function check_command_status() {
  if [ $? -ne 0 ]; then
    echo "❌ $1"
    exit 1
  fi
  echo "✅ $1"
}
```

## Benefits

1. **Reusability** - Scripts can be called from multiple places
2. **Testability** - Scripts can be unit tested independently
3. **Maintainability** - Single source of truth for logic
4. **Versioning** - Scripts can be versioned and tracked
5. **Documentation** - Scripts are self-documenting with usage info
6. **Parameterization** - Hardcoded values become configurable

## Configuration

### Extraction Rules

Configure which snippets to extract in `.ruly/snippets-config.yml`:

```yaml
extraction:
  min_lines: 5
  max_lines: 100
  patterns:
    - multi_step_process
    - error_handling
    - loops
  
  ignore:
    - single_commands
    - examples
    - documentation

naming:
  style: kebab-case
  prefix_with_category: true
  
output:
  directory: rules/bin
  organize_by_category: true
  generate_index: true
```

## Error Handling

The command handles these scenarios:

1. **Duplicate scripts** - Prompts for name resolution
2. **Syntax errors** - Validates bash syntax before extraction
3. **Missing context** - Skips snippets without clear purpose
4. **File conflicts** - Backs up existing scripts before overwriting

## Examples

### Example 1: Extract from specific command

```bash
/snippets-to-scripts "workaxle-rules/commands/testing/pre-commit.md"
```

Output:
```
📋 Found 8 bash snippets in 1 file
✅ Extracted 6 snippets into scripts:
  - rules/bin/pre-commit/load-required-tests.sh
  - rules/bin/pre-commit/detect-changed-files.sh
  - rules/bin/pre-commit/run-rubocop.sh
  - rules/bin/pre-commit/run-required-tests.sh
  - rules/bin/pre-commit/run-all-tests.sh
  - rules/bin/pre-commit/final-verification.sh
📝 Updated workaxle-rules/commands/testing/pre-commit.md with script references
```

### Example 2: Dry run to preview

```bash
/snippets-to-scripts --dry-run
```

Output:
```
🔍 Scanning for bash snippets...
📋 Would extract 42 snippets from 15 files:

workaxle-rules/commands/testing/pre-commit.md:
  Line 16-23 → rules/bin/testing/load-required-tests.sh
  Line 27-46 → rules/bin/testing/detect-changed-files.sh
  ...

workaxle-rules/commands/pr/review-feedback-loop.md:
  Line 41-47 → rules/bin/common/countdown-timer.sh
  ...

No files were modified (dry run mode)
```

### Example 3: Interactive extraction

```bash
/snippets-to-scripts --interactive
```

Output:
```
Found snippet in workaxle-rules/commands/testing/pre-commit.md:16-23
Purpose: Load required tests from tmp/required-tests

Extract as script? (y/n/skip): y
Script name [load-required-tests.sh]: 
Category [testing]: 
✅ Extracted to rules/bin/testing/load-required-tests.sh

Found snippet in workaxle-rules/commands/testing/pre-commit.md:27-46
Purpose: Detect changed files by type
...
```

## Integration

After extraction, scripts can be:

1. **Sourced in other scripts**: `source rules/bin/common/functions.sh`
2. **Called directly**: `./rules/bin/pre-commit/run-tests.sh`
3. **Used in commands**: Reference in markdown as examples
4. **Tested independently**: Create test suites for scripts
5. **Version controlled**: Track changes to extracted scripts

## Notes

- Extracted scripts maintain original logic while adding parameterization
- Original markdown files are updated to reference the new scripts
- Scripts are made executable automatically (`chmod +x`)
- A manifest file tracks which scripts came from which sources
- Scripts can be re-extracted if source snippets change significantly