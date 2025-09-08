# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-08-19

### Added

- Initial release of Ruly as a Ruby gem
- `ruly import` command to generate CLAUDE.local.md with @import statements
- `ruly squash` command to combine all markdown files into one
- `ruly list-recipes` command to list available recipe collections
- `ruly init` command to initialize ruly in a project
- `ruly version` command to show the version
- Recipe-based compilation system with YAML configuration
- Support for Claude and Cursor AI assistants
- Caching system for recipe compilation
- Command file separation for Claude assistant

### Changed

- Migrated from shell script installer to Ruby gem distribution
- Changed from symlink-based system to gem-based distribution
- Made `ruly` available in PATH when installed as a gem

### Removed

- Shell script installer (install.sh)
- Symlink-based global rules system
- Direct file system manipulation approach
