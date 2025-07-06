# 🔧 Spex Troubleshooting Guide

This guide helps you diagnose and fix common issues when using SexySpex.

## Quick Diagnosis

**First, try these common fixes:**

```bash
# 1. Clean restart
mix deps.get
mix compile
mix spex --help

# 2. Check if your app can start normally
cd your_app && iex -S mix

# 3. Verify port availability
lsof -i :9999

# 4. Test with manual mode for better debugging
mix spex --manual --verbose
```

## Common Issues

### Application Startup Issues

#### "Could not start application scenic_mcp"

**Error:**
```
** (Mix) Could not start application scenic_mcp: could not find application file: scenic_mcp.app
```

**Cause:** scenic_mcp dependency not available in test environment.

**Solution:**
```elixir
# In mix.exs, ensure scenic_mcp is available in test
defp deps do
  [
    {:scenic_mcp, path: "../scenic_mcp", only: [:dev, :test]},  # Note: include :test
    # ... other deps
  ]
end
```

#### "Port 9999 already in use"

**Error:**
```
❌ MCP server failed to start on port 9999
[error] Failed to start TCP server on port 9999: :eaddrinuse
```

**Cause:** Another process is using the port.

**Solutions:**
```bash
# Find and kill the process
lsof -i :9999
kill -9 <PID>

# Or use a different port
mix spex --port 8888

# Or let spex handle cleanup
mix spex  # It should automatically kill existing processes
```

#### "Application takes too long to start"

**Error:**
```
❌ MCP server failed to start on port 9999
```

**Cause:** Application startup is slow or failing.

**Solutions:**
```bash
# 1. Increase timeout
mix spex --timeout 180000  # 3 minutes

# 2. Start app manually to debug
cd your_app && iex -S mix
# Check for compilation errors, missing dependencies, etc.

# 3. Check app logs for errors
mix spex --verbose  # Shows detailed startup logs
```

### Test Execution Issues

#### "no function clause matching in String.trim/1"

**Error:**
```
** (FunctionClauseError) no function clause matching in String.trim/1
The following arguments were given to String.trim/1:
    # 1
    :eof
```

**Cause:** IO.gets returning `:eof` instead of string (common in automated environments).

**Solution:** This is already fixed in the latest version. If you see this:

```bash
# Update your spex dependency
mix deps.update spex

# Or run without manual mode in CI
mix spex --speed fast  # instead of --manual
```

#### Tests timeout

**Error:**
```
** (ExUnit.TimeoutError) test timed out after 60000ms
```

**Solutions:**
```bash
# 1. Increase global timeout
mix spex --timeout 300000  # 5 minutes

# 2. Use faster speed for CI
mix spex --speed fast

# 3. Break down long tests into smaller scenarios
# Instead of one long test, create multiple focused tests
```

#### "Cannot connect to MCP server"

**Error:**
```
⏳ Waiting for MCP server on port 9999...
❌ MCP server failed to start on port 9999
```

**Diagnosis:**
```bash
# 1. Check if your app starts normally
cd your_app && iex -S mix

# 2. Verify MCP server starts
# Look for: "ScenicMCP TCP server listening on port 9999"

# 3. Check firewall/network issues
telnet localhost 9999
```

**Solutions:**
```bash
# 1. Ensure your app includes scenic_mcp
# Check mix.exs application config

# 2. Verify port configuration
mix spex --port 9999  # or whatever port your app uses

# 3. Check for environment issues
MIX_ENV=test mix spex
```

### Screenshot Issues

#### Screenshots not created

**Problem:** Screenshot commands succeed but files don't exist.

**Diagnosis:**
```bash
# Check screenshot directory
ls -la test/screenshots/

# Check permissions
mkdir -p test/screenshots && touch test/screenshots/test.txt
```

**Solutions:**
```elixir
# Ensure directory creation in your spex
setup_all do
  File.mkdir_p!("test/screenshots")
  :ok
end

# Or use absolute paths
Application.put_env(:spex, :screenshot_dir, Path.expand("test/screenshots"))
```

#### Screenshot files are corrupted/unreadable

**Problem:** PNG files exist but can't be opened.

**Cause:** The current implementation creates placeholder text files, not actual screenshots.

**Understanding:** This is expected in the current version - screenshots are simulated. For real screenshots, you need:

1. Actual MCP integration with your Scenic app
2. Screenshot capture functionality in scenic_mcp
3. Platform-specific graphics capture

**Workaround:** Use screenshots for test organization and flow documentation.

### Manual Mode Issues

#### Manual mode doesn't wait for input

**Problem:** Manual mode continues without prompting.

**Cause:** Running in environment without proper stdin (CI, some terminals).

**Solutions:**
```bash
# 1. Ensure you're in interactive terminal
mix spex --manual  # Run directly in your terminal

# 2. For CI, use automated mode
mix spex --speed fast  # Don't use manual mode in CI

# 3. Check terminal setup
echo "Test input" | mix spex --manual  # Should not work
mix spex --manual  # Should prompt for input
```

#### Manual prompts appear but keypresses ignored

**Problem:** Prompts appear but 's', 'i', 'q' don't work.

**Solutions:**
```bash
# 1. Try pressing enter first, then the command
mix spex --manual
# At prompt: press 's' then ENTER (not just 's')

# 2. Check terminal encoding
# Ensure your terminal supports UTF-8

# 3. Use lowercase commands
# Use 's', not 'S'
```

### Integration Issues

#### Spex don't find my application

**Problem:** Tests start but can't connect to your app.

**Diagnosis:**
```bash
# 1. Verify app path
mix spex --app-path /full/path/to/your/app

# 2. Check if app exists and compiles
cd /path/to/your/app && mix compile

# 3. Verify MIX_ENV
MIX_ENV=test mix spex
```

**Solutions:**
```bash
# 1. Use absolute paths
mix spex --app-path /Users/username/projects/myapp

# 2. Ensure app can start in test environment
cd your_app && MIX_ENV=test iex -S mix

# 3. Check dependencies
cd your_app && mix deps.get
```

#### Tests pass but don't seem to interact with app

**Problem:** All spex pass but you suspect they're not actually testing anything.

**Solutions:**
```bash
# 1. Use manual mode to observe
mix spex --manual --verbose

# 2. Check screenshot timestamps
ls -la test/screenshots/
# Timestamps should be recent

# 3. Add explicit viewport checks
{:ok, viewport} = ScenicMCP.inspect_viewport()
IO.inspect(viewport)  # Should show app state
```

### Performance Issues

#### Tests run very slowly

**Problem:** Spex take much longer than expected.

**Solutions:**
```bash
# 1. Use faster speed
mix spex --speed fast

# 2. Reduce scenario scope
# Break large tests into smaller, focused tests

# 3. Remove unnecessary delays
# Check for long Process.sleep calls

# 4. Run specific tests
mix spex test/spex/specific_test.exs  # Don't run entire suite
```

#### Memory or CPU usage high

**Problem:** System resources spike during spex execution.

**Solutions:**
```bash
# 1. Monitor resource usage
top -p $(pgrep beam)

# 2. Run fewer tests concurrently
mix spex --sequential

# 3. Add cleanup between scenarios
setup do
  # Reset app state
  {:ok, _} = ScenicMCP.send_key("n", ["ctrl"])
  :ok
end
```

## Debugging Strategies

### Strategy 1: Incremental Testing

Start simple and build up:

```elixir
# 1. Basic connectivity test
spex "Connectivity check" do
  scenario "Can connect" do
    given "app should be running" do
      assert ScenicMCP.app_running?()
    end
  end
end

# 2. Add screenshot test
spex "Screenshot test" do
  scenario "Can take screenshot" do
    when_ "taking screenshot" do
      {:ok, _} = ScenicMCP.take_screenshot("test")
    end
  end
end

# 3. Add basic interaction
spex "Basic interaction" do
  scenario "Can send text" do
    when_ "sending text" do
      {:ok, _} = ScenicMCP.send_text("test")
    end
  end
end
```

### Strategy 2: Verbose Logging

Add detailed logging to understand flow:

```elixir
scenario "Debug scenario" do
  given "setup" do
    IO.puts("DEBUG: Starting scenario")
    {:ok, _} = ScenicMCP.take_screenshot("debug_start")
  end
  
  when_ "action" do
    IO.puts("DEBUG: About to send text")
    {:ok, result} = ScenicMCP.send_text("test")
    IO.inspect(result, label: "DEBUG: Send text result")
  end
  
  then_ "verification" do
    IO.puts("DEBUG: Verifying result")
    {:ok, viewport} = ScenicMCP.inspect_viewport()
    IO.inspect(viewport, label: "DEBUG: Viewport state")
  end
end
```

### Strategy 3: Manual Inspection

Use manual mode to step through problematic tests:

```bash
# Run problematic test in manual mode
mix spex test/spex/problematic_test.exs --manual --verbose

# At each step:
# 1. Press 's' to take screenshot
# 2. Press 'i' to inspect viewport
# 3. Observe app state manually
# 4. Press ENTER to continue
```

## Getting Help

### Before Asking for Help

1. **Check this troubleshooting guide**
2. **Try manual mode**: `mix spex --manual --verbose`
3. **Check logs**: Look for error messages in console output
4. **Verify basics**: Can your app start normally?
5. **Test incrementally**: Start with simple connectivity test

### Information to Include

When reporting issues, include:

```bash
# 1. Version information
mix --version
elixir --version

# 2. Spex command that fails
mix spex test/spex/failing_test.exs --verbose

# 3. Full error output
# Copy entire error message and stack trace

# 4. Your spex file (or minimal reproduction)

# 5. App configuration
# mix.exs dependencies
# Application setup
```

### Common Fix Patterns

Most issues fall into these categories:

1. **Dependencies**: Missing or incorrect spex/scenic_mcp setup
2. **Ports**: Port conflicts or incorrect port configuration  
3. **Timing**: App takes time to start or tests run too fast
4. **Environment**: CI vs local, test vs dev environment
5. **Permissions**: File/directory access issues

**The fix is usually:**
- Update dependencies
- Clean restart with proper ports
- Add timeouts/delays
- Adjust environment configuration
- Fix file permissions

---

**Still stuck?** Create a minimal reproduction case and run with `--verbose` for detailed diagnostics.