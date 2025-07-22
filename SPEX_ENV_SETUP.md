# Spex Test Environment Setup Guide

## The Problem

When running `mix spex`, the task needs to run in the test environment to ensure:
1. Test-only dependencies are available
2. Test-specific code paths (like `test/support`) are compiled
3. Test configurations are loaded

## The Solution

Add the following to your project's `mix.exs`:

```elixir
def project do
  [
    app: :your_app,
    version: "0.1.0",
    elixir: "~> 1.12",
    # ... other config ...
    
    # Add this line to ensure spex runs in test environment
    preferred_cli_env: [
      spex: :test
    ]
  ]
end
```

## Why This Works

1. **preferred_cli_env** tells Mix which environment to use for specific tasks
2. When you run `mix spex`, Mix will automatically:
   - Set the environment to `:test`
   - Recompile the project in test mode if needed
   - Load test-specific code paths
   - Make test-only dependencies available

## Alternative: Manual Environment Setting

If you can't modify `mix.exs`, you can manually set the environment:

```bash
MIX_ENV=test mix spex
```

However, the `preferred_cli_env` approach is recommended as it ensures consistency.

## Verification

To verify your setup is correct:

1. Run `mix spex` in your project
2. Check that test helpers and support modules are available
3. Ensure test-only dependencies can be used

## What the Spex Task Does

The updated `mix spex` task now:
1. Runs `Mix.Task.run("compile")` to ensure proper compilation
2. Runs `Mix.Task.run("app.start")` to start all applications
3. Loads and executes spex files with ExUnit

This mimics the behavior of `mix test` but for spex files.