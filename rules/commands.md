---
description: Common patterns and utilities for command execution
globs:
alwaysApply: true
---

# Common Command Patterns

## Git Operations

### Basic Git Commands

```bash
# Check status
git status

# Stage changes
git add -A  # Stage all changes
git add <file>  # Stage specific file

# Commit
git commit -m "type: message"

# Push
git push
git push origin <branch>
```

### Commit Message Format

`[TICKET-ID] type(scope): description`

Types: `fix`, `feat`, `refactor`, `docs`, `test`, `chore`

## Testing Commands

### Ruby/RSpec

```bash
# Run specific tests
make spec T="spec/path/to/spec.rb"
bundle exec rspec spec/path/to/spec.rb

# Run with specific line
bundle exec rspec spec/path/to/spec.rb:42

# Run all tests
bundle exec rspec
```

### Code Quality

```bash
# RuboCop
bundle exec rubocop-git  # Changed files only
bundle exec rubocop-git --auto-correct

# Full rubocop
bundle exec rubocop
```

## Common Workflow Patterns

### Pre-Check Pattern

Before any operation:

1. Verify clean working directory
2. Check current branch
3. Ensure tests pass
4. Verify code style

### Error Handling Pattern

```bash
if [ $? -ne 0 ]; then
  echo "❌ Operation failed"
  # Handle error
  exit 1
fi
```

### Progress Indicators

```bash
# Countdown timer
for i in $(seq $WAIT_TIME -1 1); do
  printf "\r⏳ Time remaining: %02d seconds" $i
  sleep 1
done
printf "\r✅ Complete\n"
```

## File Organization

### Debug Scripts

Location: `debug/[TICKET-ID]-[description].rb`

### Test Files

- Specs: `spec/**/*_spec.rb`
- Factories: `spec/factories/*.rb`
- Support: `spec/support/*.rb`

### Temporary Files

Location: `tmp/` (automatically ignored by git)

## Exit Codes

- `0` - Success
- `1` - General failure
- `2` - Missing prerequisites
- `3` - User abort

## Common Checks

### File Existence

```bash
if [ -f "file.txt" ]; then
  # File exists
fi

if [ -d "directory" ]; then
  # Directory exists
fi
```

### String Checks

```bash
if [ -n "$VAR" ]; then
  # Variable is not empty
fi

if [ -z "$VAR" ]; then
  # Variable is empty
fi
```
