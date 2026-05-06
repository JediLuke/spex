# 📖 Spex How-To Guide

This guide provides solutions to common problems and tasks when using SexySpex. Each section answers a specific "How do I...?" question.

## Table of Contents

1. [Setup & Configuration](#setup--configuration)
2. [Writing Effective Spex](#writing-effective-spex)
3. [Debugging & Troubleshooting](#debugging--troubleshooting)
4. [Visual Testing](#visual-testing)
5. [Integration Workflows](#integration-workflows)
6. [Advanced Patterns](#advanced-patterns)

## Setup & Configuration

### How do I set up Spex for a new project?

**Problem:** Starting fresh with Spex in a new Scenic application.

**Solution:**

1. **Add dependencies to `mix.exs`:**
```elixir
defp deps do
  [
    {:sexy_spex, path: "../spex", only: [:test, :dev]},
    {:scenic_mcp, path: "../scenic_mcp", only: [:dev, :test]},
    # ... your other deps
  ]
end

def application do
  [
    extra_applications: [:scenic_mcp],
    # ... other config
  ]
end
```

2. **Create test structure:**
```bash
mkdir -p test/spex
mkdir -p test/screenshots
```

3. **Create basic config file `test/spex/spex_helper.exs`:**
```elixir
# Common setup for all spex files
Application.put_env(:sexy_spex, :adapter, SexySpex.Adapters.ScenicMCP)
Application.put_env(:sexy_spex, :port, 9999)
Application.put_env(:sexy_spex, :screenshot_dir, "test/screenshots")

File.mkdir_p!("test/screenshots")
```

4. **Create your first spex file `test/spex/smoke_test_spex.exs`:**
```elixir
defmodule MyApp.SmokeTestSpex do
  use SexySpex
  
  setup_all do
    Code.require_file("test/spex/spex_helper.exs")
    :ok
  end
  
  spex "Application starts correctly" do
    alias SexySpex.Adapters.ScenicMCP

    scenario "Basic connectivity" do
      given_ "the application should be running", context do
        assert ScenicMCP.wait_for_app(9999, 10)
        {:ok, context}
      end

      then_ "we can take a screenshot", context do
        {:ok, _} = ScenicMCP.take_screenshot("smoke_test")
        {:ok, context}
      end
    end
  end
end
```

### How do I configure different ports or directories?

**Problem:** Your app runs on a different port or you want custom screenshot locations.

**Solution:**

```elixir
# In your spex file or config
setup_all do
  Application.put_env(:sexy_spex, :adapter, SexySpex.Adapters.ScenicMCP)
  Application.put_env(:sexy_spex, :port, 8888)  # Custom port
  Application.put_env(:sexy_spex, :screenshot_dir, "tmp/screenshots")  # Custom directory
  
  File.mkdir_p!("tmp/screenshots")
  :ok
end
```

Or via command line:
```bash
mix spex --port 8888 --app-path ../my-other-app
```

### How do I run Spex in CI/automated environments?

**Problem:** Running spex tests in GitHub Actions, Jenkins, etc.

**Solution:**

```bash
# Use fast mode and no watch mode
mix spex --speed fast --verbose --timeout 120000

# For headless environments, ensure your app can start without GUI
MIX_ENV=test mix spex --only-spex --speed fast
```

Example GitHub Actions workflow:
```yaml
- name: Run Spex Tests
  run: |
    mix deps.get
    mix compile
    # Start your app in background if needed
    mix spex --speed fast --timeout 180000
```

## Writing Effective Spex

### How do I write clear, maintainable spex?

**Problem:** Spex becoming hard to read or maintain.

**Best Practices:**

1. **Use descriptive names:**
```elixir
# Good
spex "User can create and save documents" do
  scenario "New document creation workflow" do

# Bad  
spex "Test 1" do
  scenario "Document stuff" do
```

2. **Keep scenarios focused:**
```elixir
# Good - single responsibility
scenario "Text input works correctly" do
  given_ "empty editor", context do ... ; {:ok, context} end
  when_ "user types text", context do ... ; {:ok, context} end
  then_ "text appears", context do ... ; {:ok, context} end
end

scenario "File saving works correctly" do
  given_ "document with content", context do ... ; {:ok, context} end
  when_ "user saves file", context do ... ; {:ok, context} end
  then_ "file is saved", context do ... ; {:ok, context} end
end

# Bad - doing too much
scenario "Complete editing workflow" do
  # 20 lines of mixed concerns
end
```

3. **Use meaningful screenshots:**
```elixir
# Good - descriptive names
{:ok, _} = ScenicMCP.take_screenshot("user_login_form_displayed")
{:ok, _} = ScenicMCP.take_screenshot("after_successful_login")

# Bad - generic names
{:ok, _} = ScenicMCP.take_screenshot("test1")
{:ok, _} = ScenicMCP.take_screenshot("test2")
```

### How do I handle setup and teardown?

**Problem:** Need to reset state between scenarios or clean up after tests.

**IMPORTANT: Understanding setup vs setup_all timing**

- **setup_all**: Runs **ONCE** when the test module loads, **before ALL spex** in the file
- **setup**: Runs **before EACH individual spex** (each `spex "..."` block), **NOT before scenarios or Given/When/Then steps**

**Timeline Example:**
```elixir
defmodule MyApp.ExampleSpex do
  use SexySpex
  
  setup_all do
    IO.puts("🚀 setup_all: Runs ONCE when module loads")
    Application.ensure_all_started(:my_app)
    {:ok, %{shared_data: "available to all spex"}}
  end
  
  setup do
    IO.puts("🔧 setup: Runs before EACH spex block")
    {:ok, %{fresh_data: "reset for each spex"}}
  end
  
  spex "first test" do              # setup runs here!
    scenario "first scenario" do     # NO setup here
      # context has both shared_data and fresh_data
    end
    scenario "second scenario" do    # NO setup here
      # Same context as first scenario
    end
  end
  
  spex "second test" do             # setup runs again here!
    scenario "third scenario" do     # NO setup here  
      # fresh_data is reset, shared_data is the same
    end
  end
end
```

**Output Timeline:**
```
🚀 setup_all: Runs ONCE when module loads
🔧 setup: Runs before EACH spex block
  [first test scenarios run - all scenarios share same context]
🔧 setup: Runs before EACH spex block
  [second test scenarios run - fresh context]
```

**Practical Solution:**

```elixir
defmodule MyApp.FeatureSpex do
  use SexySpex
  
  # Runs ONCE - start expensive resources
  setup_all do
    # Start application once for all tests
    Application.ensure_all_started(:my_app)
    
    # Cleanup when ALL tests are done
    on_exit(fn -> Application.stop(:my_app) end)
    
    {:ok, %{app_name: "my_app", port: 9999}}
  end
  
  # Runs before EACH spex - reset state
  setup do
    # Reset to clean state for each spex
    alias SexySpex.Adapters.ScenicMCP
    {:ok, _} = ScenicMCP.send_key("n", [:ctrl])  # New file
    {:ok, _} = ScenicMCP.send_key("a", [:ctrl])  # Select all
    {:ok, _} = ScenicMCP.send_key("delete")       # Clear
    
    {:ok, %{timestamp: DateTime.utc_now()}}
  end
  
  spex "Feature A testing" do
    # This spex gets fresh context from setup
    scenario "scenario 1" do
      # Shares context with other scenarios in this spex
    end
    scenario "scenario 2" do  
      # Same context as scenario 1
    end
  end
  
  spex "Feature B testing" do
    # This spex gets NEW fresh context from setup running again
    scenario "scenario 3" do
      # Fresh timestamp, clean application state
    end
  end
end
```

### How do I pass data between test steps?

**Problem:** Need to share data between Given-When-Then steps in a scenario.

**IMPORTANT: Context flows within scenarios, but setup timing affects what's available**

- **Within a scenario**: Given/When/Then steps can pass data to each other
- **Between scenarios in same spex**: All scenarios share the same setup context
- **Between different spex blocks**: Each spex gets fresh setup context

**Solution:**

Use context passing to share data between steps, similar to ExUnit's setup callbacks.

**Important:** Every step with context must return `{:ok, context}`. There is no `:ok` shorthand — if a step doesn't change context, return `{:ok, context}` explicitly.

```elixir
spex "User workflow with data sharing" do
  scenario "Creating and using a document" do
    given_ "a new document is created", context do
      document_name = "MyDocument_#{:rand.uniform(1000)}"
      ScenicMCP.send_text(document_name)
      ScenicMCP.send_key("enter")

      updated_context =
        context
        |> Map.put(:document_name, document_name)
        |> Map.put(:creation_time, DateTime.utc_now())

      {:ok, updated_context}
    end
    
    when_ "content is added to the document", context do
      # Use data from previous step
      content = "Created at #{context.creation_time}"
      ScenicMCP.send_text(content)
      
      # Add more data to context
      {:ok, Map.put(context, :content, content)}
    end
    
    then_ "the document can be saved with correct data", context do
      # Verify using data from all previous steps
      ScenicMCP.send_key("s", [:ctrl])
      
      assert String.contains?(context.document_name, "MyDocument")
      assert String.length(context.content) > 0
      
      {:ok, _} = ScenicMCP.take_screenshot("saved_#{context.document_name}")

      # No context changes — still must return {:ok, context}
      {:ok, context}
    end
  end
end
```

**Without context (still flows context, just ignored):**
```elixir
scenario "Simple workflow without data sharing" do
  given_ "setup state", context do
    prepare_test()
    {:ok, context}
  end

  when_ "action occurs", context do
    perform_action()
    {:ok, context}
  end

  then_ "result is verified", context do
    verify_result()
    {:ok, context}
  end
end
```

**Key Benefits:**
- **Data Flow**: Variables flow naturally between test steps
- **Cleaner Tests**: No need to re-fetch or recreate data
- **Better Assertions**: Can verify data across the entire scenario
- **Documentation**: Context shows what data the test cares about

### How do I handle context return values correctly?

**Problem:** Getting `ArgumentError` about "Step must return {:ok, context}" when running spex.

**Solution:**

Every step block — `given_`, `when_`, `then_`, `and_`, and registered givens — must return `{:ok, context}`. There is no implicit pass-through and no `:ok` shorthand. If a step doesn't change context, return `{:ok, context}` explicitly.

#### Valid Return Values

**Pass context through unchanged:**
```elixir
given_ "application is running", context do
  assert MyApp.started?()
  {:ok, context}
end
```

**Update context:**
```elixir
when_ "user creates a document", context do
  document = create_document("test.txt")
  {:ok, Map.put(context, :document, document)}
end
```

**Multiple updates:**
```elixir
given_ "test data is prepared", context do
  user = create_user()
  session = login(user)

  updated =
    context
    |> Map.put(:user, user)
    |> Map.put(:session, session)
    |> Map.put(:timestamp, DateTime.utc_now())

  {:ok, updated}
end
```

#### Invalid Return Values (Will Raise Error)

```elixir
# All of these raise ArgumentError:

given_ "bad example 1", context do
  create_user()  # returns %User{} — not {:ok, context}
end

when_ "bad example 2", context do
  true  # boolean
end

then_ "bad example 3", context do
  Map.put(context, :key, "value")  # bare map
end

and_ "bad example 4", context do
  :ok  # bare :ok is not allowed — must be {:ok, context}
end

then_ "bad example 5", context do
  {:error, "boom"}  # wrong tuple shape
end
```

#### Migration from earlier versions

Earlier versions accepted bare `:ok` (which kept context unchanged) and atom-given returns of `{:ok, %{partial}}` (which were merged into context). Both behaviors are removed. Migration:

```elixir
# Before:
then_ "verify result", context do
  assert context.data.status == :ok
  :ok
end

# After:
then_ "verify result", context do
  assert context.data.status == :ok
  {:ok, context}
end

# Before — atom givens returned partial map that got merged:
register_given :admin_role, context do
  {:ok, %{role: :admin}}
end

# After — return the full context explicitly:
register_given :admin_role, context do
  {:ok, Map.put(context, :role, :admin)}
end
```

### How do I test complex user workflows?

**Problem:** Need to test multi-step processes like "create account → login → use app → logout".

**Solution:**

```elixir
spex "Complete user onboarding workflow" do
  alias SexySpex.Adapters.ScenicMCP
  
  scenario "New user complete journey" do
    given_ "application is at welcome screen", context do
      {:ok, _} = ScenicMCP.take_screenshot("welcome_screen")
      {:ok, context}
    end

    when_ "user starts registration process", context do
      {:ok, _} = ScenicMCP.send_text("newuser@example.com")
      {:ok, _} = ScenicMCP.send_key("tab")
      {:ok, _} = ScenicMCP.send_text("SecurePassword123")
      {:ok, _} = ScenicMCP.send_key("enter")
      {:ok, _} = ScenicMCP.take_screenshot("registration_submitted")
      {:ok, context}
    end

    and_ "completes profile setup", context do
      {:ok, _} = ScenicMCP.send_text("John Doe")
      {:ok, _} = ScenicMCP.send_key("tab")
      {:ok, _} = ScenicMCP.send_text("Software Developer")
      {:ok, _} = ScenicMCP.send_key("enter")
      {:ok, _} = ScenicMCP.take_screenshot("profile_completed")
      {:ok, context}
    end

    and_ "uses core application features", context do
      {:ok, _} = ScenicMCP.send_text("My first document")
      {:ok, _} = ScenicMCP.send_key("s", [:ctrl])
      {:ok, _} = ScenicMCP.take_screenshot("document_saved")
      {:ok, context}
    end

    then_ "user has successfully onboarded", context do
      {:ok, viewport} = ScenicMCP.inspect_viewport()
      assert viewport.active
      {:ok, _} = ScenicMCP.take_screenshot("onboarding_complete")
      {:ok, context}
    end
  end
end
```

## Debugging & Troubleshooting

### How do I debug failing spex?

**Problem:** Spex is failing and you need to understand why.

**Debug Strategies:**

1. **Use manual mode for step-by-step debugging:**
```bash
mix spex test/spex/failing_test_spex.exs --manual --verbose
```

2. **Add diagnostic screenshots:**
```elixir
scenario "Debug failing interaction" do
  given_ "setup state", context do
    {:ok, _} = ScenicMCP.take_screenshot("debug_01_initial_state")
    {:ok, context}
  end

  when_ "problematic action", context do
    {:ok, _} = ScenicMCP.take_screenshot("debug_02_before_action")
    {:ok, _} = ScenicMCP.send_text("problematic text")
    {:ok, _} = ScenicMCP.take_screenshot("debug_03_after_action")
    {:ok, context}
  end

  then_ "expected result", context do
    {:ok, viewport} = ScenicMCP.inspect_viewport()
    IO.inspect(viewport, label: "DEBUG VIEWPORT")
    {:ok, _} = ScenicMCP.take_screenshot("debug_04_final_state")
    {:ok, context}
  end
end
```

3. **Use watch mode to keep app open:**
```bash
mix spex --watch --verbose
# App stays running after tests for manual inspection
```

### How do I handle timing issues?

**Problem:** Tests fail because actions happen too fast or the app needs time to update.

**Solution:**

```elixir
scenario "Handling async operations" do
  when_ "triggering slow operation", context do
    {:ok, _} = ScenicMCP.send_key("f5")  # Refresh

    # Wait for operation to complete
    Process.sleep(2000)

    # Or retry until condition is met
    wait_for_condition(fn ->
      {:ok, viewport} = ScenicMCP.inspect_viewport()
      viewport.active
    end, timeout: 10_000)

    {:ok, context}
  end
end

# Helper function
defp wait_for_condition(condition_fn, opts \\ []) do
  timeout = Keyword.get(opts, :timeout, 5000)
  start_time = :os.system_time(:millisecond)
  
  wait_loop(condition_fn, start_time, timeout)
end

defp wait_loop(condition_fn, start_time, timeout) do
  if condition_fn.() do
    :ok
  else
    current_time = :os.system_time(:millisecond)
    if current_time - start_time > timeout do
      raise "Condition not met within timeout"
    else
      Process.sleep(100)
      wait_loop(condition_fn, start_time, timeout)
    end
  end
end
```

### How do I deal with flaky tests?

**Problem:** Tests sometimes pass, sometimes fail.

**Solution:**

1. **Add retries for unreliable operations:**
```elixir
defp retry_action(action_fn, max_attempts \\ 3) do
  retry_action(action_fn, max_attempts, 1)
end

defp retry_action(action_fn, max_attempts, attempt) do
  try do
    action_fn.()
  rescue
    error ->
      if attempt < max_attempts do
        Process.sleep(1000)
        retry_action(action_fn, max_attempts, attempt + 1)
      else
        reraise error, __STACKTRACE__
      end
  end
end

scenario "Reliable operation" do
  when_ "performing unreliable action", context do
    retry_action(fn ->
      {:ok, _} = ScenicMCP.send_key("f12")
      {:ok, viewport} = ScenicMCP.inspect_viewport()
      assert viewport.active
    end)

    {:ok, context}
  end
end
```

2. **Use longer timeouts in slow environments:**
```bash
mix spex --timeout 300000  # 5 minutes
```

## Visual Testing

### How do I compare screenshots between test runs?

**Problem:** Want to detect visual regressions.

**Solution:**

```elixir
spex "Visual regression testing" do
  scenario "UI consistency check" do
    given_ "application in known state", context do
      reset_to_standard_state()
      {:ok, _} = ScenicMCP.take_screenshot("baseline_ui")
      {:ok, context}
    end

    when_ "no changes should occur", context do
      {:ok, _} = ScenicMCP.send_key("tab")
      {:ok, _} = ScenicMCP.send_key("tab")
      {:ok, context}
    end

    then_ "UI remains identical", context do
      {:ok, _} = ScenicMCP.take_screenshot("comparison_ui")

      baseline_path = "test/screenshots/baseline_ui.png"
      comparison_path = "test/screenshots/comparison_ui.png"

      assert File.exists?(baseline_path)
      assert File.exists?(comparison_path)
      # TODO: Implement actual image comparison
      # assert images_are_similar?(baseline_path, comparison_path)
      {:ok, context}
    end
  end
end
```

### How do I test responsive layouts?

**Problem:** Need to test how UI adapts to different screen sizes.

**Solution:**

```elixir
spex "Responsive layout testing" do
  scenario "UI adapts to different window sizes" do
    given_ "application at standard size", context do
      {:ok, _} = ScenicMCP.take_screenshot("standard_size")
      {:ok, context}
    end

    when_ "window is resized to mobile dimensions", context do
      # {:ok, _} = ScenicMCP.resize_window(400, 600)
      {:ok, _} = ScenicMCP.take_screenshot("mobile_size")
      {:ok, context}
    end

    and_ "window is resized to tablet dimensions", context do
      # {:ok, _} = ScenicMCP.resize_window(768, 1024)
      {:ok, _} = ScenicMCP.take_screenshot("tablet_size")
      {:ok, context}
    end

    then_ "layouts adapt appropriately", context do
      {:ok, viewport} = ScenicMCP.inspect_viewport()
      assert viewport.active
      {:ok, context}
    end
  end
end
```

## Integration Workflows

### How do I integrate Spex with my development workflow?

**Problem:** Want to use SexySpex effectively during development.

**Development Workflow:**

```bash
# 1. During feature development - manual mode for exploration
mix spex test/spex/new_feature_spex.exs --manual --watch

# 2. Quick validation - fast automated run
mix spex --pattern "**/smoke_*" --speed fast

# 3. Full test suite before commit
mix spex --verbose

# 4. CI environment - fast and reliable
mix spex --speed fast --timeout 300000
```

### How do I organize spex files?

**Problem:** Growing test suite needs organization.

**Recommended Structure:**
```
test/spex/
├── smoke/
│   ├── basic_functionality_spex.exs
│   └── app_startup_spex.exs
├── features/
│   ├── text_editing_spex.exs
│   ├── file_operations_spex.exs
│   └── user_preferences_spex.exs
├── integration/
│   ├── complete_workflows_spex.exs
│   └── cross_feature_spex.exs
├── visual/
│   ├── ui_consistency_spex.exs
│   └── responsive_layout_spex.exs
└── edge_cases/
    ├── error_handling_spex.exs
    └── performance_spex.exs
```

**Run by category:**
```bash
mix spex --pattern "**/smoke/*"      # Quick health checks
mix spex --pattern "**/features/*"   # Feature-specific tests  
mix spex --pattern "**/integration/*" # End-to-end workflows
```

### How do I share spex between team members?

**Problem:** Ensuring consistent spex execution across team.

**Solution:**

1. **Create shared configuration:**
```elixir
# test/spex/shared_config.exs
defmodule SpexConfig do
  def setup_common do
    Application.put_env(:sexy_spex, :adapter, SexySpex.Adapters.ScenicMCP)
    Application.put_env(:sexy_spex, :port, 9999)
    Application.put_env(:sexy_spex, :screenshot_dir, "test/screenshots")
    
    File.mkdir_p!("test/screenshots")
  end
  
  def wait_for_standard_state do
    alias SexySpex.Adapters.ScenicMCP
    
    # Common wait patterns
    assert ScenicMCP.wait_for_app(9999, 10)
    {:ok, _} = ScenicMCP.send_key("n", [:ctrl])  # New file
    Process.sleep(1000)  # Let UI settle
  end
end
```

2. **Document team conventions:**
```elixir
# In each spex file
defmodule MyApp.FeatureSpex do
  use SexySpex
  
  setup_all do
    Code.require_file("test/spex/shared_config.exs")
    SpexConfig.setup_common()
    :ok
  end
  
  setup do
    SpexConfig.wait_for_standard_state()
    :ok
  end
  
  # Team convention: always take before/after screenshots
  spex "Feature description" do
    scenario "What it tests" do
      given_ "starting state", context do
        {:ok, _} = ScenicMCP.take_screenshot("#{@scenario}_before")
        {:ok, context}
      end

      when_ "action occurs", context do
        # ... test actions
        {:ok, context}
      end

      then_ "result is verified", context do
        {:ok, _} = ScenicMCP.take_screenshot("#{@scenario}_after")
        {:ok, context}
      end
    end
  end
end
```

## Advanced Patterns

### How do I create reusable given statements?

**Problem:** Same setup code is duplicated across multiple scenarios and spex files.

**Solution: register givens by atom and invoke them with `given_ :name`**

```elixir
defmodule MyApp.UserSpex do
  use SexySpex

  register_given :logged_in_user, context do
    user = %{id: 1, name: "Test User", email: "test@example.com"}
    {:ok, Map.put(context, :user, user)}
  end

  register_given :admin_privileges, context do
    {:ok, Map.put(context, :role, :admin)}
  end

  register_given :empty_database, context do
    MyApp.Repo.delete_all(MyApp.User)
    {:ok, context}
  end

  spex "User dashboard" do
    scenario "admin sees all users" do
      given_ :logged_in_user
      given_ :admin_privileges

      then_ "admin data is available", context do
        assert context.user.name == "Test User"
        assert context.role == :admin
        {:ok, context}
      end
    end

    scenario "regular user view" do
      given_ :logged_in_user

      then_ "user data is available", context do
        assert context.user != nil
        {:ok, context}
      end
    end
  end
end
```

**Key behaviors:**
- `register_given :name, context do … end` compiles to `def name(context)` — a normal public function
- The block must return `{:ok, context}` — the returned context replaces the current context (no merge)
- `given_ :name` resolves `name/1` via standard Elixir scoping (local def first, then imports)
- Multiple registered givens can be chained — each builds on the previous context

### How do I share givens across multiple spex files?

**Problem:** Need the same setup code in different spex modules.

**Solution: a `SexySpex.Givens` module + plain `import`**

1. **Create a shared givens module:**
```elixir
# test/spex/support/shared_givens.ex
defmodule MyApp.SharedGivens do
  use SexySpex.Givens

  register_given :logged_in_user, context do
    {:ok, Map.put(context, :user, %{id: 1, name: "Test User"})}
  end

  register_given :with_test_data, context do
    {:ok,
     context
     |> Map.put(:users, [%{id: 1}, %{id: 2}])
     |> Map.put(:products, [%{id: 1, name: "Widget"}])}
  end

  register_given :clean_state, context do
    MyApp.reset_all()
    {:ok, context}
  end
end
```

2. **Use them with a normal `import`:**
```elixir
# test/spex/user_spex.exs
Code.require_file("support/shared_givens.ex", __DIR__)

defmodule MyApp.UserSpex do
  use SexySpex
  import MyApp.SharedGivens

  register_given :local_setup, context do
    {:ok, Map.put(context, :local, true)}
  end

  spex "User features" do
    scenario "with shared setup" do
      given_ :logged_in_user
      given_ :with_test_data
      given_ :local_setup

      then_ "all data available", context do
        assert context.user != nil
        assert context.users != nil
        assert context.local == true
        {:ok, context}
      end
    end
  end
end
```

3. **Reuse in another spex file:**
```elixir
# test/spex/product_spex.exs
Code.require_file("support/shared_givens.ex", __DIR__)

defmodule MyApp.ProductSpex do
  use SexySpex
  import MyApp.SharedGivens

  spex "Product features" do
    scenario "with same shared setup" do
      given_ :logged_in_user
      given_ :with_test_data

      then_ "products available", context do
        assert length(context.products) > 0
        {:ok, context}
      end
    end
  end
end
```

Local definitions shadow imports — the same way any imported function would. There's nothing spex-specific about the resolution.

### How do I mix atom givens with inline givens?

**Problem:** Some setup is reusable, but you also need scenario-specific setup.

**Solution:**

```elixir
defmodule MyApp.MixedSpex do
  use SexySpex

  register_given :base_user, context do
    {:ok, Map.put(context, :user, %{id: 1, name: "Test User"})}
  end

  spex "Mixed setup approaches" do
    scenario "combining reusable and inline" do
      given_ :base_user

      given_ "specific document for this test", context do
        doc = %{id: 42, title: "Test Doc", owner_id: context.user.id}
        {:ok, Map.put(context, :document, doc)}
      end

      then_ "both are available", context do
        assert context.user.id == 1
        assert context.document.owner_id == context.user.id
        {:ok, context}
      end
    end
  end
end
```

### How do I create reusable scenario macros?

**Problem:** Need to reuse entire scenarios, not just givens.

**Solution:**

```elixir
# test/spex/shared_scenarios.exs
defmodule SharedScenarios do
  defmacro login_scenario do
    quote do
      scenario "User login process" do
        alias SexySpex.Adapters.ScenicMCP

        given_ "user is at login screen", context do
          {:ok, _} = ScenicMCP.take_screenshot("login_screen")
          {:ok, context}
        end

        when_ "user enters valid credentials", context do
          {:ok, _} = ScenicMCP.send_text("user@example.com")
          {:ok, _} = ScenicMCP.send_key("tab")
          {:ok, _} = ScenicMCP.send_text("password123")
          {:ok, _} = ScenicMCP.send_key("enter")
          {:ok, context}
        end

        then_ "user is logged in", context do
          {:ok, _} = ScenicMCP.take_screenshot("logged_in")
          {:ok, context}
        end
      end
    end
  end
end

# Usage in multiple spex files
defmodule MyApp.DashboardSpex do
  use SexySpex
  require SharedScenarios
  
  spex "Dashboard functionality" do
    SharedScenarios.login_scenario()
    
    scenario "Dashboard-specific tests" do
      # ... specific tests
    end
  end
end
```

### How do I test error conditions?

**Problem:** Need to verify application handles errors gracefully.

**Solution:**

```elixir
spex "Error handling validation" do
  scenario "Invalid input handling" do
    given_ "application in normal state", context do
      {:ok, _} = ScenicMCP.take_screenshot("normal_state")
      {:ok, context}
    end

    when_ "invalid input is provided", context do
      invalid_inputs = [
        "\x00\x01\x02",
        "A" <> String.duplicate("x", 10000),
        "🚀" <> String.duplicate("💥", 100)
      ]

      Enum.each(invalid_inputs, fn input ->
        {:ok, _} = ScenicMCP.send_text(input)
        {:ok, _} = ScenicMCP.send_key("enter")
        Process.sleep(100)
      end)

      {:ok, context}
    end

    then_ "application remains stable", context do
      {:ok, viewport} = ScenicMCP.inspect_viewport()
      assert viewport.active, "App should handle invalid input gracefully"
      {:ok, _} = ScenicMCP.take_screenshot("after_invalid_input")
      {:ok, context}
    end
  end

  scenario "Memory pressure handling" do
    when_ "application is stressed with rapid actions", context do
      for _i <- 1..100 do
        {:ok, _} = ScenicMCP.send_text("test")
        {:ok, _} = ScenicMCP.send_key("backspace")
      end

      {:ok, context}
    end

    then_ "application maintains performance", context do
      {:ok, viewport} = ScenicMCP.inspect_viewport()
      assert viewport.active
      {:ok, context}
    end
  end
end
```

### How do I test performance characteristics?

**Problem:** Want to validate application responsiveness.

**Solution:**

```elixir
spex "Performance validation" do
  scenario "Response time under normal load" do
    when_ "user performs common actions", context do
      start_time = :os.system_time(:millisecond)

      {:ok, _} = ScenicMCP.send_text("Performance test document")
      {:ok, _} = ScenicMCP.send_key("enter")
      {:ok, _} = ScenicMCP.send_key("s", [:ctrl])

      end_time = :os.system_time(:millisecond)
      {:ok, Map.put(context, :response_time, end_time - start_time)}
    end

    then_ "actions complete within reasonable time", context do
      assert context.response_time < 2000,
             "Actions took #{context.response_time}ms, expected < 2000ms"

      {:ok, viewport} = ScenicMCP.inspect_viewport()
      assert viewport.active
      {:ok, context}
    end
  end
end
```

---

This how-to guide should help you solve common problems and implement effective testing patterns with SexySpex. For more specific issues, check the [Troubleshooting Guide](TROUBLESHOOTING.md) or [Technical Reference](TECHNICAL_REFERENCE.md).