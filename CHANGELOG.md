# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-07-06

### Added
- Initial release of Spex framework
- Given-When-Then DSL for executable specifications
- Built on ExUnit with AI-optimized features
- `Spex.Helpers` module with semantic helper functions
- `mix spex` command for running specifications
- Manual mode with interactive step-by-step execution
- Built-in support for Scenic GUI testing
- Context flow between test steps
- Framework setup helpers for application lifecycle management
- Comprehensive documentation and examples

### Features
- **Core DSL**: `spex`, `scenario`, `given_`, `when_`, `then_`, `and_` macros
- **Semantic Helpers**: `start_scenic_app/2`, `can_connect_to_scenic_mcp?/1`, `application_running?/1`
- **Manual Mode**: Interactive testing with IEx shell integration
- **Mix Integration**: Dedicated `mix spex` command with proper lifecycle management
- **GUI Testing**: Built-in helpers for Scenic applications with MCP server integration
- **Documentation**: Comprehensive guides in `/docs` directory

### Architecture
- Built on ExUnit for reliability and compatibility
- Controlled execution environment via `mix spex` only
- Automatic compilation and application lifecycle management
- Clean separation between framework and user code