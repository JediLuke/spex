# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 4th July 2025

### Added
- Initial release of Spex framework
- Core DSL with `spex`, `scenario`, `given`, `when_`, `then_`, and `and_` macros
- Clean reporting system with colorized output
- Adapter system for extensible testing environments
- Default adapter for basic testing scenarios
- ScenicMCP adapter for GUI testing with Scenic applications
- Mix task (`mix spex`) for running specifications
- Comprehensive documentation and examples
- Test suite for the framework itself

### Features
- **Clean DSL**: Intuitive Given-When-Then syntax for readable specifications
- **Living Documentation**: Tests that generate human and AI-readable documentation
- **Adapter System**: Pluggable adapters for different testing environments
- **Scenic Integration**: Built-in support for GUI testing with Scenic applications
- **AI-Optimized**: Designed for AI-driven development and autonomous testing
- **Mix Integration**: Run with `mix spex` command
- **Visual Testing**: Screenshot capture and visual validation
- **Professional Output**: Beautiful console output with emojis and formatting

### Developer Experience
- Professional project structure following Elixir/OTP conventions
- Comprehensive test coverage
- ExDoc documentation generation
- Credo and Dialyzer integration for code quality
- Clear examples and usage patterns