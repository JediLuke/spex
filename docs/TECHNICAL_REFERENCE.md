# 📚 Spex Framework - Technical Reference

*Following the "5 Types of Documentation" framework for comprehensive coverage*

## 🎯 **1. TUTORIALS** (Learning-Oriented)

### **Getting Started with Spex**

**Your First Spex in 5 Minutes:**

1. **Add to your project:**
```elixir
# mix.exs
{:sexy_spex, path: "../spex", only: [:test, :dev]}
```

2. **Create your first spex:**
```elixir
# test/spex/calculator_spex.exs
defmodule Calculator.BasicSpex do
  use SexySpex
  
  spex "calculator can add numbers" do
    scenario "adding two positive numbers" do
      given_ "two numbers" do
        a = 5
        b = 3
      end
      
      when_ "we add them" do
        result = Calculator.add(a, b)
      end
      
      then_ "we get the sum" do
        assert result == 8
      end
    end
  end
end
```

3. **Run it:**
```bash
mix spex test/spex/calculator_spex.exs
```

**Tutorial: GUI Testing with Scenic**

Step-by-step guide for testing Scenic applications...
*(See README.md for complete GUI testing tutorial)*

## 🛠 **2. HOW-TO GUIDES** (Problem-Oriented)

### **How to Test File Operations**
```elixir
spex "file save functionality" do
  scenario "save to new file" do
    given_ "unsaved content" do
      ScenicMCP.send_text("My document content")
    end
    
    when_ "user saves with Ctrl+S" do
      ScenicMCP.send_key("s", [:ctrl])
      # Handle save dialog...
    end
    
    then_ "file is saved successfully" do
      # Verification logic...
    end
  end
end
```

### **How to Test Visual Changes**
```elixir
spex "UI updates correctly" do
  scenario "theme change" do
    given "light theme is active" do
      {:ok, before} = ScenicMCP.take_screenshot("light_theme")
    end
    
    when_ "user switches to dark theme" do
      ScenicMCP.send_key("t", ["ctrl", "shift"])  # Toggle theme
    end
    
    then_ "UI changes to dark theme" do
      {:ok, after} = ScenicMCP.take_screenshot("dark_theme")
      # Could add image comparison here
    end
  end
end
```

### **How to Create Custom Adapters**
```elixir
defmodule MyApp.CustomAdapter do
  @behaviour SexySpex.Adapter
  
  def setup do
    # Initialize your testing environment
  end
  
  def take_screenshot(filename) do
    # Your screenshot implementation
  end
  
  # Implement other required callbacks...
end
```

## 📖 **3. EXPLANATION** (Understanding-Oriented)

### **Why Spex Exists**

**The Problem:** Traditional testing often creates a gap between requirements, tests, and documentation. Tests become stale, documentation gets outdated, and requirements are lost in translation.

**The Solution:** Spex provides *executable specifications* - tests that are written in business language and serve as living documentation. They:

- Express requirements in readable Given-When-Then format
- Execute as actual tests to validate functionality  
- Generate visual evidence through screenshots
- Remain synchronized with the codebase by necessity

**AI-Driven Development:** Spex is optimized for AI systems that can:
- Understand requirements written in natural language
- Generate executable specifications automatically
- Run tests against live applications
- Analyze results and iterate improvements

### **Architecture Philosophy**

**Adapter Pattern:** Different testing environments need different approaches:
- **Default Adapter**: Basic testing without external dependencies
- **ScenicMCP Adapter**: GUI testing with visual feedback
- **Custom Adapters**: Extensible for any testing scenario

**Reporter System:** Clean separation between test execution and output formatting allows:
- Consistent visual output across different test types
- Easy customization of reporting format
- Integration with external reporting systems

**DSL Design:** The macro-based DSL provides:
- Compile-time validation of test structure
- Runtime flexibility for dynamic scenarios
- Clean integration with ExUnit for familiar testing patterns

### **When to Use Spex vs ExUnit**

**Use Spex When:**
- Writing acceptance tests or integration tests
- Need visual evidence (screenshots)
- Testing GUI applications
- Requirements need to be readable by non-developers
- AI is involved in test generation or execution

**Use ExUnit When:**
- Writing unit tests for pure functions
- Testing internal implementation details
- Performance is critical (minimal overhead needed)
- No need for business-readable format

### **How the Spex Tag System Works**

When you `use SexySpex` in a test module, it automatically adds `@moduletag spex: true` to the entire module. This leverages ExUnit's built-in tag filtering system:

```elixir
defmodule MyApp.IntegrationSpex do
  use SexySpex  # This adds @moduletag spex: true automatically
  
  spex "user workflow" do
    # This creates a regular ExUnit test tagged with :spex
  end
end
```

**Running Spex Tests:**
- `mix test` - Runs all tests EXCEPT those tagged with `:spex` (ExUnit excludes them by default)
- `mix test --include spex` - Includes tests tagged with `:spex` in addition to regular tests
- `mix test --only spex` - Runs ONLY tests tagged with `:spex`
- `mix spex` - Custom task that starts the application and runs spex tests

This design allows spex tests to be excluded by default (since they may require special setup like GUI applications) while still being easily runnable when needed.

## 📋 **4. REFERENCE** (Information-Oriented)

### **Complete API Reference**

#### **Core Modules**

##### `Spex`
**Main entry point for the framework**

- `__using__/1` - Macro to set up spex environment
- `setup/1` - Initialize adapters and configuration

##### `SexySpex.DSL`  
**Domain-specific language macros**

- `spex/2` - Define a specification
  - **Parameters:** `name` (string), `opts` (keyword list)
  - **Options:** `:description`, `:tags`, `:context`
- `scenario/2` - Define a test scenario within a spex
- `given_/2` - Set up preconditions  
- `when_/2` - Define the action being tested
- `then_/2` - Define expected outcomes
- `and_/2` - Additional context or cleanup steps

**Note on Step Types:** The `given_`, `when_`, `then_`, and `and_` macros are functionally identical - they all execute code blocks and report their step type to the reporter. The only difference is the label in the output (e.g., "Given: ...", "When: ...", etc.). The naming follows BDD conventions for readability, but you can technically use them in any order. Each macro simply:
1. Reports the step type and description to `SexySpex.Reporter`
2. Executes the provided code block via `SexySpex.StepExecutor`
3. Continues to the next step

**Context Handling:** When using the 2-arity versions (with context), steps must return:
- `:ok` - Keep context unchanged
- `{:ok, context}` - Pass updated context to next step
- Any other return value raises `ArgumentError` with helpful guidance

This design keeps the implementation simple while providing semantic structure for test scenarios and preventing accidental context loss.

##### Manual Mode and Step Control

**Important:** Manual mode pauses **between DSL blocks**, not between individual lines of code within each block.

**Execution Flow:**
```elixir
scenario "example flow" do
  given_ "setup" do
    # All code here executes without pause
    line1()
    line2()
    line3()
  end
  # PAUSE HAPPENS HERE in manual mode
  
  when_ "action" do
    # All code here executes without pause
    action1()
    action2()
  end
  # PAUSE HAPPENS HERE in manual mode
  
  then_ "verification" do
    # All code here executes without pause
    assert1()
    assert2()
  end
end
```

**For Fine-Grained Control:** Break actions into smaller DSL blocks:
```elixir
# Instead of:
when_ "complex user interaction" do
  send_text("Hello")      # No pause
  send_key("backspace")   # No pause  
  send_text(" World")     # No pause
end

# Use multiple blocks:
when_ "user types Hello" do
  send_text("Hello")
end
# Pause here

and_ "user corrects text" do
  send_key("backspace")
end
# Pause here

and_ "user completes with World" do
  send_text(" World")
end
```

##### `SexySpex.Reporter`
**Output formatting and progress tracking**

- `start_spex/2` - Begin reporting for a specification
- `spex_passed/1` - Report successful completion
- `spex_failed/2` - Report failure with error details
- `start_scenario/1` - Begin scenario reporting
- `scenario_passed/1` - Report scenario success
- `scenario_failed/2` - Report scenario failure
- `step/2` - Report individual Given-When-Then steps

#### **Adapters**

##### Adapter Architecture

**You must explicitly specify an adapter** - there is no default adapter. This ensures clear intent about your testing environment.

**Required Adapter Functions:**
- `defaults/0` - Returns default configuration map
- `setup/1` - Initialize adapter with configuration

##### `SexySpex.Adapters.ScenicMCP`  
**Scenic GUI testing adapter**

- `setup/0` - Verify MCP server connection
- `app_running?/1` - Check TCP connection to MCP server
- `wait_for_app/2` - Wait for MCP server to be ready
- `execute_command/2` - Send commands via MCP protocol
- `send_text/1` - Send text input to application
- `send_key/2` - Send keyboard input with modifiers
- `take_screenshot/1` - Capture application screenshots
- `inspect_viewport/0` - Get application state information

#### **Mix Tasks**

##### `Mix.Tasks.Spex`
**Command-line interface for running spex**

**Usage:** `mix spex [options] [files]`

**Options:**
- `--only-spex` - Run only spex tests (skip ExUnit)
- `--pattern PATTERN` - File pattern to match (default: test/spex/**/*_spex.exs)
- `--verbose` - Show detailed output
- `--timeout MS` - Test timeout in milliseconds
- `--help` - Show help message

**Examples:**
```bash
mix spex                                    # Run all spex
mix spex test/spex/user_login_spex.exs     # Run specific file
mix spex --pattern "**/integration_*.exs" # Pattern matching
mix spex --verbose --timeout 120000       # Verbose with 2min timeout
```

### **Configuration Reference**

**Application Configuration:**
```elixir
config :sexy_spex,
  adapter: SexySpex.Adapters.ScenicMCP,   # Default: SexySpex.Adapters.Default
  screenshot_dir: "test/screenshots", # Default: "."
  port: 9999                          # Default: 9999 (for ScenicMCP)
```

**Runtime Configuration:**
```elixir
# In test setup
Application.put_env(:sexy_spex, :adapter, SexySpex.Adapters.ScenicMCP)
Application.put_env(:sexy_spex, :screenshot_dir, "tmp/screenshots")
```

### **Error Reference**

**Common Errors and Solutions:**

1. **`could not load spex.ex. Reason: enoent`**
   - **Cause:** Wrong path in `Code.require_file/2`
   - **Solution:** Check relative paths, use `{:sexy_spex, path: ".."}` in deps

2. **`No Scenic MCP server detected on port 9999`**
   - **Cause:** Scenic application not running with MCP enabled
   - **Solution:** Start app with `iex -S mix`, verify scenic_mcp in deps

3. **`Spex failed: module MySpex is not loaded`**
   - **Cause:** Compilation errors in spex file
   - **Solution:** Check syntax, ensure all modules are available

## ⚡ **5. TROUBLESHOOTING** (Problem-Solving)

### **Common Issues**

#### **Spex Files Won't Load**
```bash
# Error: could not load test/spex/my_spex.exs
```

**Debugging Steps:**
1. Check file syntax: `elixir -c test/spex/my_spex.exs`
2. Verify spex dependency: `mix deps.get && mix deps.compile`
3. Check file paths in `Code.require_file/2`
4. Ensure all required modules are available

#### **ScenicMCP Connection Fails**
```bash
# Error: No Scenic MCP server detected
```

**Debugging Steps:**
1. Verify app is running: `ps aux | grep beam`
2. Check port is open: `lsof -i :9999`
3. Test connection manually: `telnet localhost 9999`
4. Check scenic_mcp dependency in target app
5. Verify MCP server starts with app

#### **Screenshots Not Generated**
```bash
# Error: Screenshot file does not exist
```

**Debugging Steps:**
1. Check screenshot directory exists and is writable
2. Verify adapter configuration
3. Test with absolute paths
4. Check disk space availability
5. Review adapter implementation

#### **Tests Pass but Features Don't Work**
```bash
# Spex passes but feature is broken
```

**Debugging Steps:**
1. Add more granular assertions
2. Take screenshots at each step
3. Add viewport inspection calls
4. Test manually to verify expected behavior
5. Add visual validation (OCR, image comparison)

### **Performance Issues**

#### **Slow Test Execution**
- Reduce screenshot frequency
- Optimize sleep/wait times
- Run spex in parallel where possible
- Use mocking for expensive operations

#### **Memory Usage**
- Clean up screenshot files after tests
- Avoid keeping large objects in test state
- Use streaming for large data sets

### **Integration Issues**

#### **CI/CD Pipeline Integration**
```yaml
# Example GitHub Actions
- name: Run Spex Tests
  run: |
    mix deps.get
    mix spex --only-spex
    
- name: Archive Screenshots
  uses: actions/upload-artifact@v2
  with:
    name: spex-screenshots
    path: test/screenshots/
```

#### **IDE Integration**
- Configure test runner to recognize `.exs` files in `test/spex/`
- Set up screenshot viewer for test artifacts
- Configure syntax highlighting for spex DSL

---

## 📚 **Additional Resources**

- **Hex Documentation:** https://hexdocs.pm/spex
- **GitHub Repository:** (Your repo URL)
- **Examples:** See `test/spex/` directory for working examples
- **Support:** Create issues on GitHub for questions/bugs

---

*This technical reference covers all aspects of the Spex framework from learning to troubleshooting, ensuring developers can effectively use spex for AI-driven development workflows.*