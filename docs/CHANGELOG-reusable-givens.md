# Changes: Reusable Givens, Context Refactor, and CI Output

This document describes the changes introduced in the `feature/reusable-givens` branch.

## Overview

This set of changes adds three major capabilities to Spex:

1. **Reusable given statements** with module-level registration and cross-module sharing
2. **Context passing refactor** to use function arguments instead of closure capture
3. **CI-friendly output modes** including quiet mode, JSONL failure output, and custom formatters

---

## 1. Reusable Given Statements

### Problem

Previously, every `given_` step required an inline block. If multiple scenarios shared the same preconditions (e.g., "a logged-in user", "an empty database"), the setup code had to be duplicated in each scenario.

### Solution

Givens can now be registered at the module level using atom names, then invoked by reference. They can also be defined in shared modules and imported across spex files.

### New Modules

- **`SexySpex.Givens`** (`lib/sexy_spex/givens.ex`) — A `use`-able module for defining shared given libraries. Provides the `given/2` macro, `__before_compile__` hook, and generates `__givens__/0` and `__call_given__/2` functions.

- **`SexySpex.Runtime`** (`lib/sexy_spex/runtime.ex`) — Runtime functions extracted from the DSL module. Contains `execute_given/3` (dispatches to local or imported givens), `process_step_result/2`, and `process_context_step_result/3`.

### How It Works

**Defining a given** — The `given :name do ... end` macro registers the atom in a `@sexy_spex_givens` accumulator and compiles the block into a `defp __sexy_spex_given_<name>__(context)` function. At compile time, `__before_compile__` generates a public `__call_given__/2` dispatch function with a clause for each registered name.

**Invoking a given** — `given_ :name` calls `SexySpex.Runtime.execute_given/3`, which first checks the current module's `__givens__/0` list, then falls through to any imported modules via `__imported_givens_modules__/0`. The result must be `{:ok, %{...}}`, which gets merged into the existing context.

**Sharing across modules** — A shared module uses `use SexySpex.Givens` and defines givens with the same `given :name do ... end` syntax. Consumer modules use `import_givens MySharedModule` to make those givens available.

### Usage Examples

```elixir
# Defining reusable givens inline
defmodule MyApp.UserSpex do
  use SexySpex

  given :logged_in_user do
    {:ok, %{user: %{id: 1, name: "Test User"}}}
  end

  given :admin_privileges do
    {:ok, Map.put(context, :role, :admin)}
  end

  spex "admin dashboard" do
    scenario "admin sees all users" do
      given_ :logged_in_user
      given_ :admin_privileges

      then_ "admin flag is set", context do
        assert context.role == :admin
        :ok
      end
    end
  end
end
```

```elixir
# Shared givens module
defmodule MyApp.SharedGivens do
  use SexySpex.Givens

  given :logged_in_user do
    {:ok, %{user: %{id: 1, name: "Test User"}}}
  end
end

# Importing shared givens
defmodule MyApp.ProfileSpex do
  use SexySpex
  import_givens MyApp.SharedGivens

  spex "profile page" do
    scenario "user sees their profile" do
      given_ :logged_in_user
      # context.user is available from SharedGivens
    end
  end
end
```

### Return Value Contract

- `{:ok, %{key: value}}` — Merged into the existing context via `Map.merge/2`
- `:ok` — **Not allowed** for atom-based givens. Raises `ArgumentError` with guidance.

---

## 2. Context Passing Refactor

### Problem

Context was previously captured via closure, which caused Elixir compiler warnings about unused variables and made the data flow less explicit.

### Solution

Context is now passed as a function argument to step callbacks, matching the pattern used by ExUnit's `setup` blocks. Internally, the DSL uses `var!(spex_context)` (instead of the previous `var!(context)`) to avoid shadowing user-defined `context` variables.

### What Changed

- `scenario` initializes `var!(spex_context)` from the ExUnit context
- Each step macro (`given_`, `when_`, `then_`, `and_`) passes `spex_context` into `SexySpex.StepExecutor.execute_step/4` as a function argument
- Steps that receive context use the user's named variable (e.g., `context` in `when_ "action", context do ... end`) as the function parameter
- `SexySpex.Runtime.process_step_result/2` and `process_context_step_result/3` validate return values

### Step Variants

Each step type (`given_`, `when_`, `then_`, `and_`) has three forms:

| Form | Context | Return | Example |
|------|---------|--------|---------|
| `given_ :atom` | Implicit | `{:ok, %{}}` (merged) | `given_ :logged_in_user` |
| `given_ "desc" do ... end` | Not received | Ignored (context passes through) | `given_ "setup" do ... end` |
| `given_ "desc", ctx do ... end` | Received as `ctx` | Must return `{:ok, context}` | `given_ "setup", ctx do {:ok, Map.put(ctx, :k, v)} end` |

---

## 3. CI-Friendly Output Modes

### Quiet Mode (`--quiet` / `-q`)

Suppresses all `SexySpex.Reporter` output (the emoji-decorated step-by-step log). Only ExUnit's own formatter output is shown. Useful in CI pipelines where you want clean pass/fail output.

```bash
mix spex --quiet
```

### JSONL Output (`--jsonl` / `-j`)

Writes test failures as newline-delimited JSON to a file (default: `spex_failures.jsonl`). Each failure record includes:

- `spex` — The specification name
- `scenario` — The scenario name
- `steps` — Array of BDD steps with type, description, and pass/fail status
- `error` — Message, file, line, and stacktrace

```bash
mix spex --jsonl                     # Writes to spex_failures.jsonl
mix spex --jsonl custom_output.jsonl # Writes to custom path
```

Example JSONL output:

```json
{"type":"failure","spex":"user login","scenario":"invalid password","steps":[{"type":"Given","description":"a registered user","status":"passed"},{"type":"When","description":"entering wrong password","status":"failed"}],"error":{"message":"Expected true, got false","file":"test/spex/login_spex.exs","line":42}}
```

### Custom Formatters (`--formatter` / `-f`)

Replaces the default `ExUnit.CLIFormatter` with a custom formatter module. Can be specified multiple times for multiple formatters.

```bash
mix spex --formatter MyApp.CustomFormatter
mix spex --formatter ExUnit.CLIFormatter --formatter MyApp.JSONFormatter
```

### Reporter State Tracking

The `SexySpex.Reporter` module now tracks execution state (current spex, scenario, and steps) in the process dictionary. This state is used to enrich JSONL failure output with BDD step context, so failures include which Given/When/Then steps passed before the failure occurred.

---

## Files Changed

| File | Change |
|------|--------|
| `lib/sexy_spex.ex` | Added `@sexy_spex_givens` and `@sexy_spex_imported_givens` module attributes, added `@before_compile SexySpex.DSL` |
| `lib/sexy_spex/dsl.ex` | Added `given/2` (atom registration), `import_givens/1`, `__before_compile__/1`. Refactored all step macros to use `var!(spex_context)` and function-argument context passing |
| `lib/sexy_spex/givens.ex` | **New** — Shared givens module with `use SexySpex.Givens` |
| `lib/sexy_spex/runtime.ex` | **New** — Runtime functions: `execute_given/3`, `process_step_result/2`, `process_context_step_result/3` |
| `lib/sexy_spex/reporter.ex` | Added quiet mode, JSONL output, state tracking, stacktrace parameter |
| `lib/mix/tasks/spex.ex` | Added `--quiet`, `--jsonl`, `--formatter` options with aliases |
| `lib/sexy_spex/step_executor.ex` | Added 4-argument `execute_step` that passes context as function parameter |
| `mix.exs` | Added `jason` dependency |
| `docs/HOW_TO_GUIDE.md` | Three new how-to sections for reusable givens |
| `docs/TECHNICAL_REFERENCE.md` | API reference for new macros and modules |

### Test Files Added

| File | Coverage |
|------|----------|
| `test/spex/givens_spex.exs` | Single, chained, and mixed atom-based givens |
| `test/spex/import_givens_spex.exs` | Imported givens from shared module |
| `test/spex/givens_error_spex.exs` | Return value handling (`:ok` vs `{:ok, map}`) |
| `test/spex/shared_givens.ex` | `SexySpex.TestSharedGivens` shared module |
| `test/spex_framework_test.exs` | Expanded with context isolation and givens tests |
| `test/reporter_test.exs` | Reporter quiet mode and JSONL output |
| `test/spex_task_test.exs` | Mix task option parsing and execution |
