# Boundary Enforcement for Spex Tests

Spex includes a custom Mix compiler (`Mix.Tasks.Compile.Spex`) that integrates
with the [Boundary](https://hex.pm/packages/boundary) library to enforce
**black-box testing** at compile time. When configured, any spex file that tries
to call an internal module directly (instead of going through the approved
testing interface) will produce a compiler warning.

## Table of Contents

1. [Why Boundary Enforcement?](#why-boundary-enforcement)
2. [How It Works](#how-it-works)
3. [Setup Guide](#setup-guide)
4. [Configuring Boundaries in Your App](#configuring-boundaries-in-your-app)
5. [What Gets Checked](#what-gets-checked)
6. [Example: Quillex Setup](#example-quillex-setup)
7. [Troubleshooting](#troubleshooting)

## Why Boundary Enforcement?

Without boundary enforcement, nothing stops a spex test from "reaching in" to
your application's internals:

```elixir
# BAD - This bypasses the GUI entirely
defmodule MyApp.FileSpex do
  use SexySpex

  spex "File operations" do
    scenario "Open a file" do
      when_ "we open a file" do
        # Calling internal API directly - defeats the purpose of spex!
        MyApp.Internal.FileManager.open("/tmp/test.txt")
        :ok
      end
    end
  end
end
```

The whole point of spex is **outside-in, black-box testing** through a GUI
interface like ScenicMCP. If tests can reach into internals, they're just
regular unit tests with extra syntax.

With boundary enforcement, the above code produces a compile-time warning:

```
warning: forbidden reference to MyApp.Internal.FileManager
  (references from MyApp.Spex to MyApp are not allowed)
  test/spex/my_app/file_spex.exs:9
```

## How It Works

The enforcement relies on three things working together:

1. **Boundary library** - Defines which modules can call which other modules
2. **Boundary compiler** (`:boundary`) - Traces all module references during
   compilation
3. **Spex compiler** (`:spex`) - Compiles `.exs` spex files through the same
   tracer, then checks them against your boundary definitions

The compiler order matters. During `mix compile`:

```
:boundary   → Starts CompilerState, registers tracer
:elixir     → Compiles your app with tracer active (records all references)
:app        → Generates .app file, Boundary runs its checks
:spex       → Compiles spex .exs files, re-activates tracer, runs boundary check
```

The spex compiler forces all spex modules into a configured boundary (e.g.,
`MyApp.Spex`). That boundary's `deps` list controls what spex tests are allowed
to call. Anything not in `deps` is a violation.

## Setup Guide

### Step 1: Add Dependencies

In your application's `mix.exs`, add `boundary` and make sure you have
`sexy_spex`:

```elixir
defp deps do
  [
    {:boundary, "~> 0.10", runtime: false},
    {:sexy_spex, path: "../spex", only: [:test, :dev]},
    # ... your other deps
  ]
end
```

### Step 2: Configure Compilers

Add both `:boundary` and `:spex` to your compilers list. `:boundary` must come
**before** `Mix.compilers()` and `:spex` must come **after**:

```elixir
def project do
  [
    compilers: [:boundary] ++ Mix.compilers() ++ [:spex],
    # ...
  ]
end
```

### Step 3: Configure Spex Pattern and Boundary

Tell the spex compiler where your spex files live and which boundary to force
them into:

```elixir
def project do
  [
    compilers: [:boundary] ++ Mix.compilers() ++ [:spex],
    spex: [
      pattern: "test/spex/**/*_spex.exs",
      boundary: MyApp.Spex
    ],
    # ...
  ]
end
```

The `pattern` is a glob that matches your spex files. The `boundary` is the
module name of the boundary all spex modules will be classified into (created in
the next step).

### Step 4: Create Boundary Modules in Your App

You need to define at least two boundary modules in your application's `lib/`
directory.

#### The top-level boundary

Your application needs a top-level boundary. This tells Boundary that your
app's modules are organized:

```elixir
# lib/my_app.ex (or wherever your top-level module is)
defmodule MyApp do
  use Boundary, top_level?: true, deps: [], exports: []
end
```

#### The spex boundary

This is the boundary that all spex modules get forced into. Its `deps` list is
the **allowlist** -- only modules belonging to these boundaries can be called
from spex tests:

```elixir
# lib/my_app/spex_boundary.ex
defmodule MyApp.Spex do
  use Boundary, deps: [], exports: []
end
```

With `deps: []`, spex tests can only call modules from external apps (like
ScenicMCP, ExUnit, etc.) and nothing from within your app. That's maximum
black-box enforcement.

If you have test helpers that spex tests need, add them as a dependency (see
next step).

### Step 5 (Optional): Allow Test Helpers

If you have test helper modules that spex tests should be able to use, create
a boundary for them and add it to the spex boundary's deps:

```elixir
# lib/my_app/test_helpers.ex
defmodule MyApp.TestHelpers do
  use Boundary,
    deps: [],
    exports: [
      SemanticHelpers,    # These are RELATIVE to the boundary module name
      TextAssertions      # i.e. this exports MyApp.TestHelpers.TextAssertions
    ]
end
```

Then reference it from the spex boundary:

```elixir
defmodule MyApp.Spex do
  use Boundary, deps: [MyApp.TestHelpers], exports: []
end
```

**Important:** Boundary exports are **relative** to the boundary module name.
`exports: [SemanticHelpers]` in a boundary called `MyApp.TestHelpers` exports
`MyApp.TestHelpers.SemanticHelpers`. If you accidentally write the full module
path in exports, you'll get double-prefixed names like
`MyApp.TestHelpers.MyApp.TestHelpers.SemanticHelpers`.

### Step 6: Compile and Verify

```bash
MIX_ENV=test mix compile --force
```

You should see boundary violation warnings for any spex files that reference
your app's internal modules. Fix them by going through your testing interface
instead.

## Configuring Boundaries in Your App

### What deps to allow

Think about what spex tests legitimately need:

| Dependency | Why Allow It | How to Allow |
|---|---|---|
| Test helpers | Viewport queries, assertions | Add as boundary dep |
| External test libs | ScenicMCP, ExUnit, etc. | Automatic (different app) |
| Your public API | If you have one | Add the API boundary as dep |

What to **not** allow:

| Module | Why Block It |
|---|---|
| Internal state modules | Tests shouldn't peek at state directly |
| Internal business logic | Tests should go through the GUI |
| Internal data structures | Tests shouldn't depend on implementation details |

### External app modules are not checked

Boundary only enforces boundaries within the same Mix application. Calls to
modules in other apps (like `ScenicMcp.Query`, `ExUnit`, `Process`, etc.) are
**not checked** and are always allowed. This is the desired behavior -- you
want spex tests to freely use ScenicMCP while being blocked from your app's
internals.

### Boundary override vs auto-classification

The `boundary: MyApp.Spex` config option **forces** all spex modules into
that boundary, regardless of their module name. Without it, spex modules would
be auto-classified by their name prefix (e.g., `MyApp.SomeSpex` would fall
under the `MyApp` boundary).

The override is almost always what you want, because spex module names
typically start with your app's name (e.g., `MyApp.LoginSpex`) but shouldn't
have the same access as your app's internal modules.

## What Gets Checked

The spex compiler checks **all module references** in your spex files:

- `alias MyApp.SomeInternal` -- caught
- `MyApp.SomeInternal.some_function()` -- caught
- `%MyApp.SomeStruct{}` -- caught
- `import MyApp.SomeModule` -- caught
- `use MyApp.SomeMacro` -- caught

References to modules in **external apps** are not checked:

- `ScenicMcp.Query.rendered_text()` -- allowed (different app)
- `ExUnit.Assertions.assert/1` -- allowed (different app)
- `Process.sleep/1` -- allowed (stdlib)

## Example: Quillex Setup

Here's the complete setup used by the Quillex text editor:

### mix.exs

```elixir
defmodule QuillEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :quillex,
      compilers: [:boundary] ++ Mix.compilers() ++ [:spex],
      spex: [
        pattern: "test/spex/**/*_spex.exs",
        boundary: Quillex.Spex
      ],
      deps: deps()
      # ...
    ]
  end

  defp deps do
    [
      {:boundary, "~> 0.10", runtime: false},
      {:sexy_spex, path: "../spex", only: [:test, :dev]},
      {:scenic_mcp, "...", only: [:dev, :test]},
      # ...
    ]
  end
end
```

### Boundary definitions

```elixir
# lib/quillex.ex
defmodule Quillex do
  use Boundary, top_level?: true, deps: [], exports: []
end

# lib/spex_integration.ex
defmodule Quillex.Spex do
  use Boundary, deps: [Quillex.TestHelpers], exports: []
end

# lib/test_helpers/boundary.ex
defmodule Quillex.TestHelpers do
  use Boundary,
    deps: [],
    exports: [
      SemanticHelpers,
      TextAssertions,
      SceneHelpers,
      ScriptInspector
    ]
end
```

### What this enforces

Spex tests **can** call:
- `ScenicMcp.Query.rendered_text()` -- external app, not checked
- `ScenicMcp.Probes.send_keys/2` -- external app, not checked
- `Quillex.TestHelpers.SemanticHelpers.some_helper()` -- allowed by deps

Spex tests **cannot** call:
- `Quillex.Buffer.BufferManager.get_state()` -- internal, blocked
- `Quillex.API.FileAPI.open(path)` -- internal, blocked
- `Quillex.Structs.BufState` -- internal, blocked

Attempting to use a blocked module produces:

```
warning: forbidden reference to Quillex.API.FileAPI
  (references from Quillex.Spex to Quillex are not allowed)
  test/spex/quillex/07_integration_v1_spex.exs:185
```

## Troubleshooting

### No boundary warnings appear

1. Make sure `:boundary` is in your compilers list **before** `Mix.compilers()`:
   ```elixir
   compilers: [:boundary] ++ Mix.compilers() ++ [:spex]
   ```

2. Make sure you've defined a top-level boundary with `use Boundary` in your
   app's main module.

3. Run a full recompile: `MIX_ENV=test mix compile --force`

### "forbidden_dep" errors on external modules

If your spex boundary lists an external module (from another app) in `deps`,
you'll get a "forbidden dep" error. Remove external modules from `deps` --
calls to external apps are allowed automatically:

```elixir
# WRONG - ScenicMcp is in a separate app
defmodule MyApp.Spex do
  use Boundary, deps: [ScenicMcp, MyApp.TestHelpers], exports: []
end

# RIGHT - Only list same-app boundaries in deps
defmodule MyApp.Spex do
  use Boundary, deps: [MyApp.TestHelpers], exports: []
end
```

### "unknown_export" with double-prefixed names

Boundary exports are **relative** to the boundary module. Don't use the full
module path:

```elixir
# WRONG - produces MyApp.TestHelpers.MyApp.TestHelpers.SemanticHelpers
defmodule MyApp.TestHelpers do
  use Boundary, exports: [MyApp.TestHelpers.SemanticHelpers]
end

# RIGHT - produces MyApp.TestHelpers.SemanticHelpers
defmodule MyApp.TestHelpers do
  use Boundary, exports: [SemanticHelpers]
end
```

### Spex compiler not running

The spex compiler only runs in `:test` environment. Make sure you're compiling
with `MIX_ENV=test`:

```bash
MIX_ENV=test mix compile --force
```

### "unclassified_module" warnings

These come from the standard Boundary compiler and mean some of your app's
modules aren't inside any boundary. This is separate from spex enforcement.
You can either:

- Add more boundaries to cover those modules
- Ignore these warnings (they don't affect spex enforcement)
