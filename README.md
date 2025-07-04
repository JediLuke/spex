# Spex

[![Hex.pm](https://img.shields.io/hexpm/v/spex.svg)](https://hex.pm/packages/spex)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/spex)

**Executable Specifications for AI-Driven Development**

Spex is a framework for writing executable specifications that serve as both tests and living documentation, optimized for AI-driven development workflows.

## Features

- **Clean DSL**: Intuitive Given-When-Then syntax for readable specifications
- **Living Documentation**: Tests that generate human and AI-readable documentation
- **Adapter System**: Pluggable adapters for different testing environments
- **Scenic Integration**: Built-in support for GUI testing with Scenic applications
- **AI-Optimized**: Designed for AI-driven development and autonomous testing
- **Mix Integration**: Run with `mix spex` command

## Installation

Add `spex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:spex, "~> 0.1.0"}
  ]
end
```

## Quick Start

### 1. Write Your First Spex

Create a file `test/spex/user_registration_spex.exs`:

```elixir
defmodule MyApp.UserRegistrationSpex do
  use Spex

  spex "user can register successfully",
    description: "Validates the user registration flow",
    tags: [:user_management, :registration] do
    
    scenario "with valid data" do
      given "valid user registration data" do
        user_data = %{
          email: "test@example.com",
          password: "secure_password123",
          name: "Test User"
        }
        assert valid_registration_data?(user_data)
      end

      when_ "user submits registration" do
        {:ok, user} = MyApp.Users.register(user_data)
        assert user.email == user_data.email
      end

      then_ "user account is created and can login" do
        assert {:ok, _session} = MyApp.Auth.login(user_data.email, user_data.password)
      end
    end

    scenario "with invalid email" do
      given "invalid email format" do
        invalid_data = %{email: "not-an-email", password: "secure123"}
        refute valid_email?(invalid_data.email)
      end

      when_ "user attempts registration" do
        result = MyApp.Users.register(invalid_data)
        assert {:error, changeset} = result
      end

      then_ "registration fails with validation error" do
        assert "invalid email format" in error_messages(changeset)
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

# Run only spex (skip regular tests)
mix spex --only-spex
```

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

  📋 Scenario: with invalid email
    Given: invalid email format
    When: user attempts registration
    Then: registration fails with validation error
  ✅ Scenario passed: with invalid email

✅ Spex completed: user can register successfully
```

## GUI Testing with Scenic

For Scenic applications, use the ScenicMCP adapter:

```elixir
defmodule MyGUI.LoginSpex do
  use Spex

  # Configure the ScenicMCP adapter
  setup_all do
    Application.put_env(:spex, :adapter, Spex.Adapters.ScenicMCP)
    Application.put_env(:spex, :port, 9999)
    :ok
  end

  spex "user can login via GUI" do
    scenario "successful login flow" do
      given "the login screen is displayed" do
        alias Spex.Adapters.ScenicMCP
        assert ScenicMCP.wait_for_app(9999)
        {:ok, _} = ScenicMCP.take_screenshot("login_screen")
      end

      when_ "user enters valid credentials" do
        {:ok, _} = ScenicMCP.send_text("user@example.com")
        {:ok, _} = ScenicMCP.send_key("tab")
        {:ok, _} = ScenicMCP.send_text("password123")
        {:ok, _} = ScenicMCP.send_key("enter")
      end

      then_ "user is logged in successfully" do
        {:ok, screenshot} = ScenicMCP.take_screenshot("logged_in_dashboard")
        assert File.exists?(screenshot.filename)
      end
    end
  end
end
```

## Configuration

Configure spex in your `config/config.exs`:

```elixir
config :spex,
  adapter: Spex.Adapters.ScenicMCP,
  screenshot_dir: "test/screenshots",
  port: 9999
```

## AI-Driven Development

Spex is designed for AI-driven development workflows where AI systems can:

1. **Write Specifications**: AI understands requirements and writes executable spex
2. **Execute Tests**: AI runs spex against live applications
3. **Analyze Results**: AI interprets test results and generates reports
4. **Iterate Development**: AI uses feedback to improve implementations

Example AI workflow:

```elixir
# AI-generated spex based on requirements
defmodule ShoppingCart.CheckoutSpex do
  use Spex
  
  spex "checkout process completes successfully" do
    scenario "user with items in cart" do
      given "user has items in shopping cart" do
        # AI generates test setup based on understanding
        user = create_user_with_cart_items(3)
        assert length(user.cart.items) == 3
      end
      
      when_ "user proceeds through checkout" do
        # AI simulates user interaction
        {:ok, order} = ShoppingCart.checkout(user, payment_info())
        assert order.status == :pending_payment
      end
      
      then_ "order is created and payment processed" do
        # AI validates expected outcomes
        assert order.total > 0
        assert {:ok, _receipt} = PaymentProcessor.process(order)
      end
    end
  end
end
```

## Architecture

### Core Modules

- **`Spex`** - Main module providing the `use` macro and setup
- **`Spex.DSL`** - Domain-specific language macros (spex, scenario, given, when_, then_)
- **`Spex.Reporter`** - Handles output formatting and progress reporting

### Adapter System

- **`Spex.Adapters.Default`** - Basic adapter for standard testing
- **`Spex.Adapters.ScenicMCP`** - Adapter for Scenic GUI applications with MCP integration

### Mix Integration

- **`Mix.Tasks.Spex`** - Mix task for running spex from command line

## Philosophy

Spex bridges the gap between human requirements and AI validation by providing:

- **Executable Documentation**: Specifications that run as tests
- **AI-Readable Format**: Structured data that AI can understand and generate
- **Visual Evidence**: Screenshot capture and state validation
- **Iterative Feedback**: Continuous validation loops for development

This enables a new paradigm where AI actively participates in the development process, understanding requirements, testing implementations, and providing feedback for improvement.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Inspiration

Spex is inspired by:
- Specification by Example (Gojko Adzic)
- Behavior-Driven Development (BDD)
- AI-driven development workflows
- The Elixir/OTP philosophy of "let it crash" and observable systems

Perfect for teams building the future of AI-assisted software development.