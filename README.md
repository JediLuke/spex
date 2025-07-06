# Spex

[![Hex.pm](https://img.shields.io/hexpm/v/spex.svg)](https://hex.pm/packages/spex)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/spex)

**Executable Specifications for AI-Driven Development**

Spex is a framework for writing executable specifications that serve as both tests and living documentation, optimized for AI-driven development workflows.

## Features

- **Clean DSL**: Intuitive Given-When-Then syntax for readable specifications
- **ExUnit Foundation**: Built on ExUnit with additional AI-optimized features
- **Scenic Integration**: Built-in helpers for GUI testing with Scenic applications
- **AI-Optimized**: Manual mode, semantic helpers, and step-by-step execution
- **Mix Integration**: Run with `mix spex` command only

## Installation

Add `sexy_spex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sexy_spex, "~> 0.1.0"}
  ]
end
```

## Quick Start

### 1. Write Your First Spex

Create a file `test/spex/user_registration_spex.exs`:

```elixir
defmodule MyApp.UserRegistrationSpex do
  use Spex

  setup_all do
    # Start your application or setup shared state
    {:ok, %{base_url: "http://localhost:4000"}}
  end

  spex "user can register successfully",
    description: "Validates the user registration flow",
    tags: [:user_management, :registration] do
    
    scenario "with valid data", context do
      given_ "valid user registration data", context do
        user_data = %{
          email: "test@example.com",
          password: "secure_password123",
          name: "Test User"
        }
        assert valid_registration_data?(user_data)
        Map.put(context, :user_data, user_data)
      end

      when_ "user submits registration", context do
        {:ok, user} = MyApp.Users.register(context.user_data)
        assert user.email == context.user_data.email
        Map.put(context, :user, user)
      end

      then_ "user account is created and can login", context do
        assert {:ok, _session} = MyApp.Auth.login(
          context.user_data.email, 
          context.user_data.password
        )
      end
    end
  end
end
```

### 2. Run Your Spex

```bash
# Run all spex files
mix spex

# Run specific spex file
mix spex test/spex/user_registration_spex.exs

# Run with verbose output
mix spex --verbose

# Run in manual mode (step-by-step)
mix spex --manual
```

**Important**: Spex files can ONLY be run with `mix spex`, not `mix test`. This ensures proper compilation and application lifecycle management.

### 3. See Beautiful Output

```
🎯 Running Spex: user can register successfully
==================================================
   Validates the user registration flow
   Tags: #user_management #registration

  📋 Scenario: with valid data
    Given: valid user registration data
    When: user submits registration
    Then: user account is created and can login
  ✅ Scenario passed: with valid data

✅ Spex completed: user can register successfully
```

## GUI Testing with Scenic

For Scenic applications, use the built-in helpers:

```elixir
defmodule MyGUI.LoginSpex do
  use Spex

  setup_all do
    # Start Scenic application with MCP server
    Spex.Helpers.start_scenic_app(:my_gui_app)
  end

  spex "user can login via GUI", context do
    scenario "successful login flow", context do
      given_ "the application is running", context do
        assert Spex.Helpers.application_running?(:my_gui_app)
        assert Spex.Helpers.can_connect_to_scenic_mcp?(context.port)
      end

      when_ "user enters valid credentials", context do
        # Use scenic_mcp tools for interaction
        ScenicMcp.send_keys(text: "user@example.com")
        ScenicMcp.send_keys(key: "tab")
        ScenicMcp.send_keys(text: "password123")
        ScenicMcp.send_keys(key: "enter")
      end

      then_ "user is logged in successfully", context do
        # Take screenshot for verification
        ScenicMcp.take_screenshot(filename: "logged_in_dashboard")
        viewport_state = ScenicMcp.Probes.viewport_state()
        assert viewport_state.name == :main_viewport
      end
    end
  end
end
```

## Framework Helpers

Spex provides semantic helpers for common patterns:

```elixir
# Start Scenic applications with MCP server
Spex.Helpers.start_scenic_app(:quillex)
Spex.Helpers.start_scenic_app(:flamelex, port: 8888)

# Test connectivity
Spex.Helpers.can_connect_to_scenic_mcp?(9999)
Spex.Helpers.application_running?(:my_app)

# Automatically handles:
# - Compilation (Mix.Task.run("compile"))
# - Application startup and cleanup
# - MCP server waiting and connection testing
```

## Manual Mode - Interactive Testing

Run spex in manual mode for step-by-step execution:

```bash
mix spex --manual
```

**Manual mode gives you:**
- 🎯 Pause between each Given/When/Then/And step
- 🐚 Drop into IEx shell for debugging (`iex` command)
- 📸 Take screenshots and inspect state
- ❌ Quit anytime (`q` command)

Perfect for:
- Debugging failing tests step-by-step
- Understanding how your app responds to actions
- Creating visual documentation of workflows
- Training and demonstration purposes

## Architecture

### Built on ExUnit

Spex is 100% built on ExUnit but provides a controlled execution environment:

```elixir
# When you write:
use Spex

# You get:
use ExUnit.Case, async: false  # Standard ExUnit test case
import Spex.DSL               # spex/scenario/given_/when_/then_
```

### Execution Flow

```
mix spex → Mix.Tasks.Spex → ExUnit.start() → Load spex files → ExUnit.run()
```

### Core Modules

- **`Spex`** - Main module with `use` macro and helpers
- **`Spex.DSL`** - Given-When-Then macros
- **`Spex.Helpers`** - Semantic helper functions
- **`Spex.StepExecutor`** - Manual mode and execution control
- **`Mix.Tasks.Spex`** - Mix task with lifecycle management

## Philosophy

Spex bridges the gap between human requirements and AI validation by providing:

- **Executable Documentation**: Specifications that run as tests
- **AI-Readable Format**: Structured, semantic test descriptions
- **Visual Evidence**: Screenshot capture and state validation  
- **Interactive Control**: Manual mode for human oversight
- **Semantic Helpers**: Functions that read like human language

This enables AI systems to write, execute, and understand tests while maintaining human readability and control.

## 📚 Documentation

- **[Getting Started Guide](docs/GETTING_STARTED.md)** - New to Spex? Start here
- **[How-To Guide](docs/HOW_TO_GUIDE.md)** - Problem-solving for specific tasks
- **[Technical Reference](docs/TECHNICAL_REFERENCE.md)** - Complete API documentation
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Solutions for common problems

## Contributing

We welcome contributions! Please see the documentation in `/docs` for details.

## License

This project is licensed under the MIT License.

## Inspiration

Spex is inspired by:
- Behavior-Driven Development (BDD)
- Specification by Example
- AI-driven development workflows
- The Elixir/OTP philosophy of observable, testable systems

Perfect for teams building the future of AI-assisted software development.