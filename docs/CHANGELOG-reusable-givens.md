# Changes: Reusable Givens, Context Refactor, and CI Output

This document describes the changes introduced in the `feature/reusable-givens` branch.

## Overview

This set of changes adds three major capabilities to Spex:

1. **Reusable given statements** registered as named functions and shared via plain Elixir `import`
2. **Unified step return contract** — every step block returns `{:ok, context}`
3. **CI-friendly output modes** — Reporter quiet by default, JSONL failure output, and custom formatters

---

## 1. Reusable Given Statements

### Problem

Previously, every `given_` step required an inline block. If multiple scenarios shared the same preconditions (e.g., "a logged-in user", "an empty database"), the setup code had to be duplicated in each scenario.

### Solution

Givens can now be registered by name with `register_given`, then invoked by atom. Givens defined in a shared module are pulled into a spex with a normal Elixir `import`.

### New Modules

- **`SexySpex.Givens`** (`lib/sexy_spex/givens.ex`) — A `use`-able module for shared given libraries. Imports the `register_given/3` macro from `SexySpex.DSL`. No dispatcher, no `__before_compile__` hook, no compile-time accumulator.

- **`SexySpex.Runtime`** (`lib/sexy_spex/runtime.ex`) — Validates step return values via `process_step_result/2`.

### How It Works

**Defining a given** — `register_given :name, context do … end` compiles to a public function `def name(context) do … end`. The block must return `{:ok, context}`.

**Invoking a given** — `given_ :name` expands to a local function call `name(context)`, which Elixir resolves the usual way: local definitions first, then imports. The returned context replaces the current context (no implicit merging).

**Sharing across modules** — A shared module uses `use SexySpex.Givens` and registers givens with `register_given`. Consumer modules pull them in with normal Elixir `import` — no dedicated `import_givens` macro.

### Usage Examples

```elixir
defmodule MyApp.UserSpex do
  use SexySpex

  register_given :logged_in_user, context do
    {:ok, Map.put(context, :user, %{id: 1, name: "Test User"})}
  end

  register_given :admin_privileges, context do
    {:ok, Map.put(context, :role, :admin)}
  end

  spex "admin dashboard" do
    scenario "admin sees all users" do
      given_ :logged_in_user
      given_ :admin_privileges

      then_ "admin flag is set", context do
        assert context.role == :admin
        {:ok, context}
      end
    end
  end
end
```

```elixir
defmodule MyApp.SharedGivens do
  use SexySpex.Givens

  register_given :logged_in_user, context do
    {:ok, Map.put(context, :user, %{id: 1, name: "Test User"})}
  end
end

defmodule MyApp.ProfileSpex do
  use SexySpex
  import MyApp.SharedGivens

  spex "profile page" do
    scenario "user sees their profile" do
      given_ :logged_in_user
      # context.user is available
    end
  end
end
```

---

## 2. Unified Step Return Contract

### Problem

The previous DSL had four different return rules across step macro forms (atom givens merged, context-less blocks discarded their return, `then_/3` accepted both `:ok` and `{:ok, ctx}`, etc.). This was the "magic" called out in the upstream review — same syntax, different semantics depending on the form.

### Solution

Every step block — `given_`, `when_`, `then_`, `and_`, atom or block — returns `{:ok, context}`. Bare `:ok` is rejected. There is no implicit context pass-through and no map-merge.

### What Changed

- Context-less block forms (`given_ "desc" do … end`, etc.) **removed**. All inline forms require an explicit context parameter.
- The atom-given map-merge behavior **removed**. Whatever the registered given returns IS the new context.
- `SexySpex.Runtime.process_step_result/2` collapsed to a single rule: `{:ok, %{}}` passes, anything else raises.
- `process_context_step_result/3` deleted — same rule applies everywhere.
- `execute_given/3` deleted — `given_ :atom` now expands to a direct local function call.

### Step Variants (After)

| Form | Return |
|------|--------|
| `given_ :atom` | The registered function returns `{:ok, context}` |
| `given_ "desc", context do … end` | Block returns `{:ok, context}` |
| `when_  "desc", context do … end` | Block returns `{:ok, context}` |
| `then_  "desc", context do … end` | Block returns `{:ok, context}` |
| `and_   "desc", context do … end` | Block returns `{:ok, context}` |

If a step doesn't change context, return `{:ok, context}` explicitly.

---

## 3. CI-Friendly Output Modes

### Quiet by Default / `--verbose`

The `SexySpex.Reporter` (the emoji-decorated step-by-step log) is now **quiet by default**. Pass `--verbose` to enable it. Only ExUnit's own formatter output is shown by default — clean for CI.

```bash
mix spex                # quiet (Reporter suppressed)
mix spex --verbose      # full Reporter output
```

### JSONL Output (`--jsonl` / `-j`)

Writes test failures as newline-delimited JSON to a file (default: `spex_failures.jsonl`). Each failure record includes:

- `spex` — specification name
- `scenario` — scenario name
- `steps` — array of BDD steps with type, description, and pass/fail status
- `error` — message, file, line, and stacktrace

```bash
mix spex --jsonl                     # Writes to spex_failures.jsonl
mix spex --jsonl custom_output.jsonl # Writes to custom path
```

### Custom Formatters (`--formatter` / `-f`)

Replaces the default `ExUnit.CLIFormatter` with a custom formatter module. Repeatable.

```bash
mix spex --formatter MyApp.CustomFormatter
mix spex --formatter ExUnit.CLIFormatter --formatter MyApp.JSONFormatter
```

### Stale Tracking (`--stale` / `--force`)

`mix spex --stale` runs only spex files that have changed (or depend on a changed module) since the last run, via `Mix.Compilers.Test.require_and_run`. `--force` reruns everything even when nothing is stale.

### Reporter State Tracking

`SexySpex.Reporter` tracks execution state (current spex, scenario, steps) in the process dictionary so JSONL failure output is enriched with the BDD context — which Given/When/Then steps passed before the failure occurred.

---

## Files Changed

| File | Change |
|------|--------|
| `lib/sexy_spex.ex` | `__using__` simplified — no givens accumulator, no `__before_compile__` |
| `lib/sexy_spex/dsl.ex` | `register_given/3` macro; `given_ :atom` expands to a direct local call; context-less block forms removed; runtime helpers collapsed |
| `lib/sexy_spex/givens.ex` | Thin `use` module — imports `register_given/3` from `SexySpex.DSL` |
| `lib/sexy_spex/runtime.ex` | Single `process_step_result/2` clause |
| `lib/sexy_spex/reporter.ex` | Quiet by default, JSONL output, state tracking |
| `lib/mix/tasks/spex.ex` | `--verbose`, `--jsonl`, `--formatter`, `--stale`, `--force` options |
| `lib/sexy_spex/step_executor.ex` | 4-arg `execute_step` that threads context as function parameter |
| `mix.exs` | Added `jason` dependency |

### Test Files

| File | Coverage |
|------|----------|
| `test/spex/givens_spex.exs` | Atom-based givens — single, chained, mixed |
| `test/spex/imported_givens_spex.exs` | Givens imported from a shared module via plain `import` |
| `test/spex/givens_error_spex.exs` | Return-contract enforcement (`:ok` raises, garbage raises) |
| `test/spex/shared_givens.ex` | `SexySpex.TestSharedGivens` shared module |
| `test/spex_framework_test.exs` | Context isolation, lifecycle, DSL availability |
| `test/reporter_test.exs` | Reporter quiet mode and JSONL output |
| `test/spex_task_test.exs` | Mix task option parsing and execution |
| `test/spex_stale_test.exs` | `--stale` / `--force` integration with `Mix.Compilers.Test` |
