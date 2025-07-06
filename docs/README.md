# Spex Documentation

This directory contains comprehensive documentation for the Spex framework.

## Documentation Structure

- **[Getting Started Guide](GETTING_STARTED.md)** - New to Spex? Start here with installation, basic concepts, and your first spex
- **[How-To Guide](HOW_TO_GUIDE.md)** - Problem-solving for specific tasks and common workflows  
- **[Technical Reference](TECHNICAL_REFERENCE.md)** - Complete API documentation and configuration options
- **[Troubleshooting](TROUBLESHOOTING.md)** - Solutions for common problems and debugging strategies
- **[Spex by Example](SPEX_BY_EXAMPLE.md)** - Real-world examples and patterns

## Quick Navigation

### New Users
1. Start with [Getting Started Guide](GETTING_STARTED.md)
2. Try the examples in [Spex by Example](SPEX_BY_EXAMPLE.md)
3. Reference [How-To Guide](HOW_TO_GUIDE.md) for specific tasks

### Experienced Users
- [Technical Reference](TECHNICAL_REFERENCE.md) for API details
- [Troubleshooting](TROUBLESHOOTING.md) for problem-solving
- [How-To Guide](HOW_TO_GUIDE.md) for advanced patterns

## Contributing to Documentation

When updating documentation:
1. Keep examples current with the latest framework version
2. Remove references to deprecated features (like the old adapter system)
3. Use semantic helper functions (`Spex.Helpers.*`) in examples
4. Ensure all examples can be run with `mix spex` only

## Framework Architecture

Spex is built on ExUnit with additional AI-optimized features:

```
mix spex → ExUnit.start() → Load spex files → ExUnit.run()
```

Key modules:
- `Spex` - Main module and helpers
- `Spex.DSL` - Given-When-Then macros  
- `Spex.Helpers` - Semantic helper functions
- `Mix.Tasks.Spex` - Mix task with lifecycle management