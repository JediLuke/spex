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
  scenario "typing into an empty buffer" do
    given_ "an empty editor buffer", context do
      {:ok, _} = ScenicMCP.take_screenshot("empty_editor")
      {:ok, context}
    end

    when_ "user types 'Hello World'", context do
      {:ok, _} = ScenicMCP.send_text("Hello World")
      {:ok, context}
    end

    then_ "the text appears in the buffer", context do
      {:ok, _} = ScenicMCP.take_screenshot("text_entered")
      # Screenshot provides visual evidence
      {:ok, context}
    end
  end
end
```

**Benefits:**
- Tests actual user interactions
- Visual evidence through screenshots
- Self-documenting specifications
- AI can drive and validate tests
- Debugging through step-by-step observation

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
      given_ "the application should be started", context do
        assert ScenicMCP.wait_for_app(9999, 5), "App must be running"
        {:ok, context}
      end

      then_ "we can connect and take a screenshot", context do
        {:ok, screenshot} = ScenicMCP.take_screenshot("app_running")
        assert File.exists?(screenshot.filename)
        {:ok, context}
      end
    end

    scenario "Basic text input works" do
      given_ "the application is ready", context do
        {:ok, _} = ScenicMCP.take_screenshot("before_input")
        {:ok, context}
      end

      when_ "we send some text", context do
        {:ok, _} = ScenicMCP.send_text("Hello Spex!")
        {:ok, context}
      end

      then_ "we can capture the result", context do
        {:ok, _} = ScenicMCP.take_screenshot("after_input")
        {:ok, context}
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
1. Starts your application automatically
2. Waits for MCP server to be ready
3. Loads and runs your spex
4. Captures screenshots as evidence
5. Cleans up when done

## Understanding Given/When/Then

Spex uses the classic BDD pattern. **Every step block returns `{:ok, context}`** — no exceptions. If a step doesn't change context, return `{:ok, context}` explicitly.

### `given_` - Setup/Preconditions

```elixir
given_ "an empty text editor", context do
  {:ok, _} = ScenicMCP.send_key("a", [:ctrl])  # Select all
  {:ok, _} = ScenicMCP.send_key("delete")       # Delete
  {:ok, _} = ScenicMCP.take_screenshot("empty_editor")
  {:ok, context}
end
```

### `when_` - Actions/Events

```elixir
when_ "user types a document", context do
  {:ok, _} = ScenicMCP.send_text("# My Document\n\nThis is a test.")
  {:ok, _} = ScenicMCP.send_key("enter")
  {:ok, context}
end
```

### `then_` - Assertions/Outcomes

```elixir
then_ "the document appears formatted", context do
  {:ok, screenshot} = ScenicMCP.take_screenshot("formatted_document")
  assert File.exists?(screenshot.filename)

  {:ok, viewport} = ScenicMCP.inspect_viewport()
  assert viewport.active
  {:ok, context}
end
```

### Reusable givens

For preconditions used across many scenarios, register them once with `register_given` and invoke by atom:

```elixir
defmodule MyApp.EditorSpex do
  use SexySpex

  register_given :empty_editor, context do
    {:ok, _} = ScenicMCP.send_key("a", [:ctrl])
    {:ok, _} = ScenicMCP.send_key("delete")
    {:ok, context}
  end

  spex "editor behavior" do
    scenario "typing" do
      given_ :empty_editor

      when_ "user types text", context do
        {:ok, _} = ScenicMCP.send_text("hello")
        {:ok, context}
      end

      then_ "text appears", context do
        {:ok, _} = ScenicMCP.take_screenshot("typed")
        {:ok, context}
      end
    end
  end
end
```

To share givens across files, put them in a module that uses `SexySpex.Givens` and `import` it normally:

```elixir
defmodule MyApp.SharedGivens do
  use SexySpex.Givens

  register_given :empty_editor, context do
    {:ok, _} = ScenicMCP.send_key("a", [:ctrl])
    {:ok, _} = ScenicMCP.send_key("delete")
    {:ok, context}
  end
end

defmodule MyApp.AnotherSpex do
  use SexySpex
  import MyApp.SharedGivens

  spex "..." do
    scenario "..." do
      given_ :empty_editor
      # ...
    end
  end
end
```

### Multiple Scenarios

```elixir
spex "Text editing functionality" do
  scenario "Basic typing" do
    given_ "empty editor", context do
      # ...
      {:ok, context}
    end

    when_ "type text", context do
      # ...
      {:ok, context}
    end

    then_ "text appears", context do
      # ...
      {:ok, context}
    end
  end

  scenario "Copy and paste" do
    given_ "text is selected", context do
      # ...
      {:ok, context}
    end

    when_ "copy and paste", context do
      # ...
      {:ok, context}
    end

    then_ "text is duplicated", context do
      # ...
      {:ok, context}
    end
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
# Fast execution (no delays) - default
mix spex --speed fast

# Medium speed (1s delays between steps)
mix spex --speed medium

# Slow for observation (2.5s delays between steps)
mix spex --speed slow

# Manual step-by-step control
mix spex --manual
```

### Output

```bash
# Reporter is quiet by default. Add --verbose for the step-by-step log.
mix spex --verbose

# Only run spex files that have changed since last run
mix spex --stale

# Force everything to rerun even when not stale
mix spex --stale --force

# Custom timeout (default: 60 seconds)
mix spex --timeout 120000
```

### Combining Options

```bash
# Manual mode with verbose output for debugging
mix spex --manual --verbose

# Medium speed run of specific pattern
mix spex --pattern "**/smoke_*" --speed medium --verbose
```

## Speed Modes & Manual Control

### Automated Modes

| Mode | Delay | Use Case |
|------|-------|----------|
| `fast` | 0ms | CI/automated testing (default) |
| `medium` | 1s | Regular development |
| `slow` | 2.5s | Observation/debugging |

### Manual Mode - Complete Control

Manual mode gives you **step-by-step control between DSL blocks**:

```bash
mix spex --manual
```

**Important:** Manual mode pauses **between `given_`, `when_`, `then_`, and `and_` blocks**, not between individual lines of code within each block.

**For fine-grained control over individual actions**, break your steps into smaller blocks:

```elixir
# Instead of one large block:
when_ "user interacts with form", context do
  send_text("username")    # No pause here
  send_key("tab")          # No pause here
  send_text("password")    # No pause here
  {:ok, context}
end

# Use smaller blocks for manual control:
when_ "user enters username", context do
  send_text("username")
  {:ok, context}
end
# Manual pause here

and_ "user moves to password field", context do
  send_key("tab")
  {:ok, context}
end
# Manual pause here

and_ "user enters password", context do
  send_text("password")
  {:ok, context}
end
```

## Common Patterns

### Pattern 1: Smoke Test

```elixir
spex "Application health check" do
  scenario "Basic functionality works" do
    given_ "app is running", context do
      assert ScenicMCP.app_running?()
      {:ok, context}
    end

    when_ "we interact with core features", context do
      {:ok, _} = ScenicMCP.send_text("test")
      {:ok, _} = ScenicMCP.send_key("enter")
      {:ok, context}
    end

    then_ "app remains responsive", context do
      {:ok, viewport} = ScenicMCP.inspect_viewport()
      assert viewport.active
      {:ok, context}
    end
  end
end
```

### Pattern 2: User Journey

```elixir
spex "Complete user workflow" do
  scenario "User creates and saves document" do
    given_ "clean application state", context do
      {:ok, _} = ScenicMCP.send_key("n", [:ctrl])  # New file
      {:ok, _} = ScenicMCP.take_screenshot("new_file")
      {:ok, context}
    end

    when_ "user writes content", context do
      {:ok, _} = ScenicMCP.send_text("# My Document\n\nContent here.")
      {:ok, _} = ScenicMCP.take_screenshot("content_written")
      {:ok, context}
    end

    and_ "saves the file", context do
      {:ok, _} = ScenicMCP.send_key("s", [:ctrl])
      {:ok, _} = ScenicMCP.take_screenshot("file_saved")
      {:ok, context}
    end

    then_ "document is preserved", context do
      # Verify file exists, content persisted, etc.
      {:ok, context}
    end
  end
end
```

### Pattern 3: Error Handling

```elixir
spex "Error scenarios" do
  scenario "Invalid input is handled gracefully" do
    given_ "normal application state", context do
      {:ok, _} = ScenicMCP.take_screenshot("normal_state")
      {:ok, context}
    end

    when_ "invalid input is provided", context do
      {:ok, _} = ScenicMCP.send_key("f12")
      {:ok, _} = ScenicMCP.send_text("\x00\x01")
      {:ok, context}
    end

    then_ "application remains stable", context do
      {:ok, viewport} = ScenicMCP.inspect_viewport()
      assert viewport.active, "App should handle invalid input gracefully"
      {:ok, _} = ScenicMCP.take_screenshot("after_invalid_input")
      {:ok, context}
    end
  end
end
```

### Pattern 4: Visual Validation

```elixir
spex "Visual consistency" do
  scenario "UI elements render correctly" do
    given_ "application in standard state", context do
      {:ok, baseline} = ScenicMCP.take_screenshot("ui_baseline")
      {:ok, Map.put(context, :baseline, baseline)}
    end

    when_ "no changes are made", context do
      Process.sleep(1000)  # Let any animations settle
      {:ok, context}
    end

    then_ "UI remains consistent", context do
      {:ok, comparison} = ScenicMCP.take_screenshot("ui_comparison")
      assert File.exists?(comparison.filename)
      {:ok, context}
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
- Use medium speed for development: `mix spex --speed medium --verbose`
- Use manual mode for debugging: `mix spex --manual`
- Re-run only changed spex: `mix spex --stale`

### 5. Advanced Features
- Register reusable givens with `register_given`
- Share givens across modules via `use SexySpex.Givens` + plain `import`

## Further Reading

- [Technical Reference](TECHNICAL_REFERENCE.md) - Complete API documentation
- [How-To Guide](HOW_TO_GUIDE.md) - Solution-oriented guide
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions

---

**Ready to start?** Create your first spex and run:

```bash
mix spex --manual --verbose
```
