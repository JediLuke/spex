# 🚀 Getting Started with SexySpex

**SexySpex** is an AI-driven testing framework for Scenic GUI applications. It lets you write executable specifications that serve as both tests and living documentation, specifically designed for visual applications that need real interaction testing.

## Table of Contents

1. [What is SexySpex?](#what-is-sexyspex)
2. [Why Use SexySpex?](#why-use-sexyspex)
3. [Installation](#installation)
4. [Your First Spex](#your-first-spex)
5. [Understanding Given/When/Then](#understanding-givenwhentheng)
6. [Command Line Options](#command-line-options)
7. [Speed Modes & Manual Control](#speed-modes--manual-control)
8. [Common Patterns](#common-patterns)
9. [Next Steps](#next-steps)

## What is SexySpex?

SexySpex combines:
- **Behavior-Driven Development (BDD)** with Given/When/Then syntax
- **Visual Testing** through automated screenshots
- **AI Integration** via Model Context Protocol (MCP)
- **Interactive Testing** with manual step-through modes

Think of it as "Cucumber for GUI applications" but specifically designed for AI-driven development workflows.

## Why Use SexySpex?

### Traditional Testing Problems
```elixir
# Traditional unit test - doesn't test real user interactions
test "text input works" do
  assert TextInput.process("hello") == "hello"
end
```

### SexySpex Approach
```elixir
# Spex - tests the actual GUI interaction
spex "user can type text in the editor" do
  given "an empty editor buffer" do
    {:ok, _} = ScenicMCP.take_screenshot("empty_editor")
  end
  
  when_ "user types 'Hello World'" do
    {:ok, _} = ScenicMCP.send_text("Hello World")
  end
  
  then_ "the text appears in the buffer" do
    {:ok, _} = ScenicMCP.take_screenshot("text_entered")
    # Screenshot provides visual evidence
  end
end
```

**Benefits:**
- ✅ Tests actual user interactions
- ✅ Visual evidence through screenshots
- ✅ Self-documenting specifications
- ✅ AI can drive and validate tests
- ✅ Debugging through step-by-step observation

## Installation

### 1. Add Spex to Your Project

Add to your `mix.exs`:

```elixir
defp deps do
  [
    {:sexy_spex, path: "../spex", only: [:test, :dev]},
    {:scenic_mcp, path: "../scenic_mcp", only: [:dev, :test]},
    # ... your other deps
  ]
end
```

### 2. Update Application Config

In your `mix.exs`, ensure scenic_mcp is included:

```elixir
def application do
  [
    extra_applications: [:scenic_mcp],
    # ... other config
  ]
end
```

### 3. Create Test Directory

```bash
mkdir -p test/spex
mkdir -p test/screenshots
```

### 4. Install Dependencies

```bash
mix deps.get
mix compile
```

## Your First Spex

Let's create a simple spex to test basic application functionality.

### Create `test/spex/hello_world_spex.exs`

```elixir
defmodule MyApp.HelloWorldSpex do
  use SexySpex
  
  @moduledoc """
  Your first spex - validates basic application interaction.
  """
  
  # Configure for Scenic MCP testing
  setup_all do
    Application.put_env(:sexy_spex, :adapter, SexySpex.Adapters.ScenicMCP)
    Application.put_env(:sexy_spex, :port, 9999)
    Application.put_env(:sexy_spex, :screenshot_dir, "test/screenshots")
    
    File.mkdir_p!("test/screenshots")
    :ok
  end
  
  spex "Basic application interaction",
    description: "Validates the app starts and responds to input",
    tags: [:smoke_test, :basic_interaction] do
    
    alias SexySpex.Adapters.ScenicMCP
    
    scenario "Application is running and accessible" do
      given "the application should be started" do
        assert ScenicMCP.wait_for_app(9999, 5), "App must be running"
      end
      
      then_ "we can connect and take a screenshot" do
        {:ok, screenshot} = ScenicMCP.take_screenshot("app_running")
        assert File.exists?(screenshot.filename)
      end
    end
    
    scenario "Basic text input works" do
      given "the application is ready" do
        {:ok, _} = ScenicMCP.take_screenshot("before_input")
      end
      
      when_ "we send some text" do
        {:ok, _} = ScenicMCP.send_text("Hello Spex!")
      end
      
      then_ "we can capture the result" do
        {:ok, _} = ScenicMCP.take_screenshot("after_input")
      end
    end
  end
end
```

### Run Your First Spex

```bash
# The spex framework handles everything automatically
mix spex test/spex/hello_world_spex.exs --verbose
```

**What happens:**
1. 🚀 Starts your application automatically
2. ⏳ Waits for MCP server to be ready
3. 📝 Loads and runs your spex
4. 📸 Captures screenshots as evidence
5. 🧹 Cleans up when done

## Understanding Given/When/Then

Spex uses the classic BDD pattern with three phases:

### `given` - Setup/Preconditions
Sets up the initial state for your test.

```elixir
given "an empty text editor" do
  {:ok, _} = ScenicMCP.send_key("a", ["ctrl"])  # Select all
  {:ok, _} = ScenicMCP.send_key("delete")       # Delete
  {:ok, _} = ScenicMCP.take_screenshot("empty_editor")
end
```

### `when_` - Actions/Events
Performs the action you want to test.

```elixir
when_ "user types a document" do
  {:ok, _} = ScenicMCP.send_text("# My Document\n\nThis is a test.")
  {:ok, _} = ScenicMCP.send_key("enter")
end
```

### `then_` - Assertions/Outcomes
Verifies the expected result occurred.

```elixir
then_ "the document appears formatted" do
  {:ok, screenshot} = ScenicMCP.take_screenshot("formatted_document")
  assert File.exists?(screenshot.filename)
  
  # You can also inspect the application state
  {:ok, viewport} = ScenicMCP.inspect_viewport()
  assert viewport.active
end
```

### Multiple Scenarios

You can have multiple scenarios in one spex:

```elixir
spex "Text editing functionality" do
  scenario "Basic typing" do
    given "empty editor" do ... end
    when_ "type text" do ... end
    then_ "text appears" do ... end
  end
  
  scenario "Copy and paste" do
    given "text is selected" do ... end
    when_ "copy and paste" do ... end  
    then_ "text is duplicated" do ... end
  end
end
```

## Command Line Options

### Basic Usage

```bash
# Run all spex files
mix spex

# Run specific file
mix spex test/spex/my_feature_spex.exs

# Run with pattern matching
mix spex --pattern "**/login_*_spex.exs"
```

### Speed Control

```bash
# Fast execution (100ms delays)
mix spex --speed fast

# Normal speed (500ms delays) - default
mix spex --speed normal

# Slow for observation (2000ms delays)
mix spex --speed slow

# Manual step-by-step control
mix spex --speed manual
# or
mix spex --manual
```

### Advanced Options

```bash
# Verbose output with detailed information
mix spex --verbose

# Keep GUI open after tests for debugging
mix spex --watch

# Run only spex tests (skip regular ExUnit tests)
mix spex --only-spex

# Custom timeout (default: 60 seconds)
mix spex --timeout 120000

# Target different application/port
mix spex --app-path ../my-other-app --port 8888
```

### Combining Options

```bash
# Manual mode with verbose output for debugging
mix spex --manual --verbose --watch

# Fast automated run of specific pattern
mix spex --pattern "**/smoke_*" --speed fast --verbose
```

## Speed Modes & Manual Control

### Automated Modes

| Mode | Delay | Use Case |
|------|-------|----------|
| `fast` | 100ms | CI/automated testing |
| `normal` | 500ms | Regular development |
| `slow` | 2000ms | Observation/debugging |

### Manual Mode - Complete Control

Manual mode gives you **step-by-step control between DSL blocks**:

```bash
mix spex --manual
```

**Important:** Manual mode pauses **between `given_`, `when_`, `then_`, and `and_` blocks**, not between individual lines of code within each block.

**What you get:**
1. **Application boots** and waits for your input
2. **Before each DSL block**, you see what will happen next
3. **Interactive prompt** with options:
   - `[ENTER]` - Continue to next block
   - `[s] + ENTER` - Take manual screenshot
   - `[i] + ENTER` - Inspect viewport
   - `[q] + ENTER` - Quit

**For fine-grained control over individual actions**, break your steps into smaller blocks:
```elixir
# Instead of one large block:
when_ "user interacts with form" do
  send_text("username")    # No pause here
  send_key("tab")          # No pause here  
  send_text("password")    # No pause here
end

# Use smaller blocks for manual control:
when_ "user enters username" do
  send_text("username")
end
# Manual pause here

and_ "user moves to password field" do
  send_key("tab")
end  
# Manual pause here

and_ "user enters password" do
  send_text("password")
end
```

**Example manual session:**
```
🎮 MANUAL MODE ACTIVATED
Press ENTER when ready to start the spex tests...

🎯 NEXT ACTION: Send text 'Hello World'
🎮 [ENTER] Continue | [s] Screenshot | [i] Inspect | [q] Quit: s
📸 Screenshot saved: manual_step_1625847291.png

🎮 [ENTER] Continue | [s] Screenshot | [i] Inspect | [q] Quit: 
▶️ Continuing...
🤖 MCP: Sending text 'Hello World'

🎯 NEXT ACTION: Take screenshot 'after_typing'
🎮 [ENTER] Continue | [s] Screenshot | [i] Inspect | [q] Quit:
```

## Common Patterns

### Pattern 1: Smoke Test

```elixir
spex "Application health check" do
  scenario "Basic functionality works" do
    given "app is running" do
      assert ScenicMCP.app_running?()
    end
    
    when_ "we interact with core features" do
      {:ok, _} = ScenicMCP.send_text("test")
      {:ok, _} = ScenicMCP.send_key("enter")
    end
    
    then_ "app remains responsive" do
      {:ok, viewport} = ScenicMCP.inspect_viewport()
      assert viewport.active
    end
  end
end
```

### Pattern 2: User Journey

```elixir
spex "Complete user workflow" do
  scenario "User creates and saves document" do
    given "clean application state" do
      {:ok, _} = ScenicMCP.send_key("n", ["ctrl"])  # New file
      {:ok, _} = ScenicMCP.take_screenshot("new_file")
    end
    
    when_ "user writes content" do
      {:ok, _} = ScenicMCP.send_text("# My Document\n\nContent here.")
      {:ok, _} = ScenicMCP.take_screenshot("content_written")
    end
    
    and_ "saves the file" do
      {:ok, _} = ScenicMCP.send_key("s", ["ctrl"])
      {:ok, _} = ScenicMCP.take_screenshot("file_saved")
    end
    
    then_ "document is preserved" do
      # Verify file exists, content persisted, etc.
    end
  end
end
```

### Pattern 3: Error Handling

```elixir
spex "Error scenarios" do
  scenario "Invalid input is handled gracefully" do
    given "normal application state" do
      {:ok, _} = ScenicMCP.take_screenshot("normal_state")
    end
    
    when_ "invalid input is provided" do
      {:ok, _} = ScenicMCP.send_key("f12")  # Unexpected key
      {:ok, _} = ScenicMCP.send_text("\x00\x01")  # Invalid chars
    end
    
    then_ "application remains stable" do
      {:ok, viewport} = ScenicMCP.inspect_viewport()
      assert viewport.active, "App should handle invalid input gracefully"
      {:ok, _} = ScenicMCP.take_screenshot("after_invalid_input")
    end
  end
end
```

### Pattern 4: Visual Validation

```elixir
spex "Visual consistency" do
  scenario "UI elements render correctly" do
    given "application in standard state" do
      {:ok, baseline} = ScenicMCP.take_screenshot("ui_baseline")
    end
    
    when_ "no changes are made" do
      Process.sleep(1000)  # Let any animations settle
    end
    
    then_ "UI remains consistent" do
      {:ok, comparison} = ScenicMCP.take_screenshot("ui_comparison")
      # In a real implementation, you could compare screenshots
      assert File.exists?(comparison.filename)
    end
  end
end
```

## Next Steps

### 1. Write Your First Real Spex
Start with a simple smoke test for your application's core functionality.

### 2. Explore Manual Mode
Use `mix spex --manual` to step through and understand how your app behaves.

### 3. Build a Test Suite
Create spex for:
- Smoke tests (basic functionality)
- User journeys (complete workflows)  
- Edge cases (error handling)
- Visual validation (UI consistency)

### 4. Integrate with Development Workflow
- Run fast spex in CI: `mix spex --speed fast`
- Use manual mode for debugging: `mix spex --manual --watch`
- Create specific test patterns: `mix spex --pattern "**/integration_*"`

### 5. Advanced Features
- Learn about custom adapters
- Integrate with other testing tools
- Create reusable spex modules

## Further Reading

- [Technical Reference](TECHNICAL_REFERENCE.md) - Complete API documentation
- [How-To Guides](docs/how-to/) - Solution-oriented guides
- [Examples](examples/) - Real-world spex examples
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

---

**Ready to start?** Create your first spex and run:

```bash
mix spex --manual --verbose
```

Watch your application come to life through AI-driven testing! 🚀