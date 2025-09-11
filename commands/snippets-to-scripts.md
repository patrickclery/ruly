---
description: Extract bash code snippets from markdown files into reusable shell scripts
alwaysApply: true
---

# Snippets to Scripts

## Overview

The `/snippets-to-scripts` command is a Ruly tool that scans markdown files in any repository for bash code snippets and extracts them into standalone shell scripts. This promotes code reuse, maintainability, and testability across your projects.

## Path Strategy

When extracting scripts from a target repository:

- **Extraction Location:** Scripts are created in the target repo (default: `bin/` or specified via `--output-dir`)
- **Documentation References:** Updated to use consistent paths (default: `bin/ruly/` or specified via `--reference-path`)
- **Installation Path:** Where scripts will be deployed in production environments

This allows:
- Scripts to be extracted and stored in the target repository
- Documentation to reference the final installation paths
- Flexible deployment strategies per project

## Usage

```
/snippets-to-scripts [file-pattern] [options]
```

### Arguments

- `file-pattern` - Glob pattern for files to scan (default: `**/*.md`)
- `--output-dir` - Where to create extracted scripts (default: `bin/`)
- `--reference-path` - Path to use in documentation references (default: `bin/ruly/`)
- `--dry-run` - Preview changes without creating files
- `--min-lines` - Minimum lines for extraction (default: 5)
- `--interactive` - Prompt for each extraction
- `--target-repo` - Path to target repository (default: current directory)

### Examples

```bash
# Extract from all markdown files in current repo
/snippets-to-scripts

# Extract from specific directory
/snippets-to-scripts "docs/**/*.md"

# Extract with custom output and reference paths
/snippets-to-scripts --output-dir="scripts/extracted" --reference-path="bin/project"

# Preview what would be extracted
/snippets-to-scripts --dry-run

# Extract from another repository
/snippets-to-scripts --target-repo="../other-project" "**/*.md"

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
# Original snippet becomes a call to:
source bin/ruly/testing/detect-changed-files.sh
```

Script created at `[output-dir]/testing/detect-changed-files.sh`

#### Pattern: Test Runner
```bash
# Original snippet becomes a call to:
bin/ruly/testing/run-required-tests.sh
```

Script created at `[output-dir]/testing/run-required-tests.sh`

#### Pattern: Countdown Timer
```bash
# Original snippet becomes a call to:
bin/ruly/common/countdown-timer.sh 30 "Custom message"
```

Script created at `[output-dir]/common/countdown-timer.sh`

### Step 5: Update Original Files

Replace inline snippets with script references:

```ruby
def update_markdown_file(file, replacements)
  content = File.read(file)
  
  replacements.each do |replacement|
    original = replacement[:original]
    output_path = replacement[:output_path]      # Where script is created
    reference_path = replacement[:reference_path] # Path used in documentation
    script_name = File.basename(reference_path)
    
    # Create usage example with installation path
    usage_example = generate_usage_example(install_path)
    
    # Replace with reference using installation path
    new_content = <<~MD
      ```bash
      # Run the #{script_name.sub('.sh', '')} script
      #{usage_example}
      ```
      
      _See `#{install_path}` for implementation details._
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
# Generated from: [source-file]#[line-range]
# Purpose: [extracted-purpose]
# Usage: [reference-path]/[script-name] [arguments]
#
# Extracted to: [output-dir]/[category]/[script-name]
# Referenced as: [reference-path]/[category]/[script-name]
#
# [Description of what the script does]

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

Example structure when extracting with default settings:

```
[target-repo]/
├── bin/                         # Default output directory
│   ├── common/
│   │   └── countdown-timer.sh
│   ├── testing/
│   │   ├── detect-changed-files.sh
│   │   ├── run-rubocop.sh
│   │   ├── run-tests.sh
│   │   └── final-verification.sh
│   └── MANIFEST.md
└── docs/
    └── *.md                     # Updated to reference bin/ruly/ paths
```

Documentation will reference scripts using the reference path (e.g., `bin/ruly/testing/script.sh`)

## Script Templates

### Basic Script Template
```bash
#!/bin/bash
# Generated from: [source-file]#[line-range]
# Purpose: [extracted-purpose]
# Usage: [reference-path]/[category]/[script-name] [arguments]
#
# Location: [output-dir]/[category]/[script-name]
# Referenced as: [reference-path]/[category]/[script-name]

set -e  # Exit on error

# [Extracted code with parameterization]
```

### Function Library Template
```bash
#!/bin/bash
# Common functions extracted from multiple sources
# Source this file: source [reference-path]/common/functions.sh
#
# Location: [output-dir]/common/functions.sh
# Referenced as: [reference-path]/common/functions.sh

function countdown_timer() {
  local wait_time="${1:-30}"
  local message="${2:-Time remaining}"
  # ... implementation ...
}
```

## Benefits

1. **Reusability** - Scripts can be called from multiple places
2. **Testability** - Scripts can be unit tested independently
3. **Maintainability** - Single source of truth for logic
4. **Versioning** - Scripts can be versioned and tracked
5. **Documentation** - Scripts are self-documenting with usage info
6. **Parameterization** - Hardcoded values become configurable
7. **Installation** - Clean separation between repo and installed locations

## Configuration

### Extraction Rules

Configure extraction in the target repository's `.ruly/snippets-config.yml`:

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
  output_dir: bin            # Where to create scripts
  reference_path: bin/ruly   # Path used in documentation
  organize_by_category: true
  generate_manifest: true
```

## Integration

After extraction, scripts in the target repository can be:

1. **Version controlled**: Commit extracted scripts to the repository
2. **Deployed**: Install to production environments at the reference path
3. **Sourced in other scripts**: `source [reference-path]/common/functions.sh`
4. **Called directly**: `[reference-path]/testing/run-tests.sh`
5. **Used in commands**: Reference in markdown documentation
6. **Tested independently**: Create test suites for scripts

## Deployment Flow

After extracting scripts in your target repository:

1. **Review extracted scripts** in the output directory
2. **Commit scripts** to version control
3. **Deploy to environments** at the reference path location
4. **Ensure executable permissions** are maintained

Example deployment script for the target repository:

```bash
#!/bin/bash
# Deploy extracted scripts to production location

SOURCE_DIR="bin"              # Where scripts were extracted
DEPLOY_DIR="/usr/local/bin/ruly"  # Production location

# Create deployment directory
sudo mkdir -p "$DEPLOY_DIR"

# Copy scripts maintaining structure
sudo cp -r "$SOURCE_DIR"/* "$DEPLOY_DIR/"

# Ensure scripts are executable
sudo find "$DEPLOY_DIR" -name "*.sh" -exec chmod +x {} \;

echo "✅ Scripts deployed to $DEPLOY_DIR"
```

## Notes

- This is a Ruly tool for processing any repository's markdown files
- Extracted scripts maintain original logic while adding parameterization
- Documentation is updated to reference the specified reference path
- Scripts are created in the target repository's output directory
- Scripts are made executable automatically (`chmod +x`)
- A manifest file tracks which scripts came from which sources
- Scripts can be re-extracted if source snippets change significantly
- The tool is repository-agnostic and works with any project structure