# ExDiag Viewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build ExDiag — a Phoenix/LiveView library that mounts a diagram browser (sidebar + Mermaid detail view) into a host app's router, reading diagram metadata/source from `.exs`/`.mmd` files scanned from a configurable directory.

**Architecture:** `ExDiag.Loader` scans a directory of `.exs` metadata files each pointing at a `.mmd` source file, producing a list of entry maps (valid or error). `ExDiag.DiagramLive` mounts, calls the loader fresh on every mount, renders a grouped sidebar, and shows the selected diagram's Mermaid source in a detail pane rendered client-side via a JS hook. `ExDiag.Router.live_ex_diag/2` is the macro host apps call to mount it. A `demo/` sibling Phoenix app exercises it manually.

**Tech Stack:** Elixir, Phoenix, Phoenix LiveView, ExUnit, `Phoenix.LiveViewTest`, mermaid.js (client-side, loaded as a bundled JS hook asset).

**Spec:** `docs/superpowers/specs/2026-08-27-ex-diag-viewer-design.md`

## Global Constraints

- No env-gating logic inside ExDiag — host app decides where/whether to call `live_ex_diag` (spec: "Purpose").
- `Loader.scan/1` re-scans and re-reads files on every call — no caching (spec: "Loader", "Scan timing").
- One broken `.exs`/`.mmd` file must never crash the scan or the mount — it becomes an error entry (spec: "Error Handling").
- Default scan directory: `priv/ex_diag/` under the host app's root, overridable via `config :ex_diag, :diagrams_path` (spec: "Loader").
- `source` in `.exs` files is a file path only, never inline Mermaid text (spec: "Source field").
- Diagram format is Mermaid only for v1 (spec: "Out of Scope").
- Run `mix precommit` (format, compile --warnings-as-errors, credo --strict, test) before considering `ex_diag` work complete — `demo/` is excluded from this alias (spec: "Demo Project").

---

## File Structure

- `lib/ex_diag/loader.ex` — scans a directory for `.exs` diagram metadata files, evaluates and validates them, reads their `.mmd` source, returns entry maps.
- `lib/ex_diag/router.ex` — `live_ex_diag/2` macro (already scaffolded, needs real implementation).
- `lib/ex_diag/diagram_live.ex` — the LiveView: mount, sidebar, selection, detail pane, error rendering.
- `priv/static/ex_diag/mermaid_hook.js` — the `ExDiagMermaid` JS hook, imported by host apps into their own `app.js`.
- `test/support/fixtures/ex_diag/` — fixture `.exs`/`.mmd` files used by `Loader` and `DiagramLive` tests.
- `test/support/test_router.ex` — a minimal router module used only in tests, mounts `live_ex_diag "/diagrams", []`.
- `test/ex_diag/loader_test.exs` — `Loader` unit tests.
- `test/ex_diag/diagram_live_test.exs` — `DiagramLive` LiveView tests.
- `demo/` — sibling runnable Phoenix app depending on `ex_diag` via relative path, with sample diagrams under `demo/priv/ex_diag/`.

---

### Task 1: `ExDiag.Loader`

**Files:**
- Create: `lib/ex_diag/loader.ex`
- Create: `test/support/fixtures/ex_diag/valid/overview.exs`
- Create: `test/support/fixtures/ex_diag/valid/overview.mmd`
- Create: `test/support/fixtures/ex_diag/missing_key/broken.exs`
- Create: `test/support/fixtures/ex_diag/missing_source/broken.exs`
- Create: `test/support/fixtures/ex_diag/eval_error/broken.exs`
- Create: `test/support/fixtures/ex_diag/mixed/good.exs`
- Create: `test/support/fixtures/ex_diag/mixed/good.mmd`
- Create: `test/support/fixtures/ex_diag/mixed/bad.exs`
- Test: `test/ex_diag/loader_test.exs`

**Interfaces:**
- Produces: `ExDiag.Loader.scan/1`, taking a directory path (`String.t()`) and returning a list of maps. A valid entry: `%{key: String.t(), group: String.t(), name: String.t(), source: String.t()}` (`source` is the Mermaid text content, `key` is the absolute `.exs` file path used as a stable identifier). An error entry: `%{key: String.t(), group: String.t() | nil, name: String.t() | nil, error: String.t(), file: String.t()}`.

- [ ] **Step 1: Write the fixture files**

`test/support/fixtures/ex_diag/valid/overview.mmd`:
```
graph TD
  A[Client] --> B[Server]
```

`test/support/fixtures/ex_diag/valid/overview.exs`:
```elixir
[
  group: "Backend",
  name: "System Overview",
  source: Path.join(__DIR__, "overview.mmd")
]
```

`test/support/fixtures/ex_diag/missing_key/broken.exs`:
```elixir
[
  group: "Backend",
  source: Path.join(__DIR__, "does_not_matter.mmd")
]
```

`test/support/fixtures/ex_diag/missing_source/broken.exs`:
```elixir
[
  group: "Backend",
  name: "Missing Source",
  source: Path.join(__DIR__, "nonexistent.mmd")
]
```

`test/support/fixtures/ex_diag/eval_error/broken.exs`:
```elixir
this is not valid elixir syntax [[[
```

`test/support/fixtures/ex_diag/mixed/good.mmd`:
```
graph TD
  A --> B
```

`test/support/fixtures/ex_diag/mixed/good.exs`:
```elixir
[
  group: "Mixed",
  name: "Good One",
  source: Path.join(__DIR__, "good.mmd")
]
```

`test/support/fixtures/ex_diag/mixed/bad.exs`:
```elixir
[
  group: "Mixed",
  name: "Bad One"
]
```

- [ ] **Step 2: Write the failing tests**

```elixir
defmodule ExDiag.LoaderTest do
  use ExUnit.Case, async: true

  alias ExDiag.Loader

  @fixtures Path.join(__DIR__, "../support/fixtures/ex_diag")

  test "loads a valid diagram entry" do
    [entry] = Loader.scan(Path.join(@fixtures, "valid"))

    assert entry.group == "Backend"
    assert entry.name == "System Overview"
    assert entry.source =~ "graph TD"
    assert entry.key =~ "overview.exs"
    refute Map.has_key?(entry, :error)
  end

  test "missing required key produces an error entry" do
    [entry] = Loader.scan(Path.join(@fixtures, "missing_key"))

    assert entry.group == "Backend"
    assert entry.name == nil
    assert entry.error =~ "missing required key :name"
    assert entry.file =~ "broken.exs"
  end

  test "missing source file produces an error entry" do
    [entry] = Loader.scan(Path.join(@fixtures, "missing_source"))

    assert entry.group == "Backend"
    assert entry.name == "Missing Source"
    assert entry.error =~ "could not read source file"
  end

  test "eval error in the exs file produces an error entry" do
    [entry] = Loader.scan(Path.join(@fixtures, "eval_error"))

    assert entry.group == nil
    assert entry.name == nil
    assert entry.error =~ "failed to evaluate"
  end

  test "a mix of valid and invalid files loads both, isolated from each other" do
    entries = Loader.scan(Path.join(@fixtures, "mixed"))

    assert length(entries) == 2
    good = Enum.find(entries, &(&1.name == "Good One"))
    bad = Enum.find(entries, &Map.has_key?(&1, :error))

    assert good.source =~ "graph TD"
    assert bad.error =~ "missing required key :source"
  end

  test "missing directory returns an empty list" do
    assert Loader.scan(Path.join(@fixtures, "does_not_exist")) == []
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `mix test test/ex_diag/loader_test.exs`
Expected: FAIL — `ExDiag.Loader` module/`scan/1` undefined.

- [ ] **Step 4: Implement `ExDiag.Loader`**

```elixir
defmodule ExDiag.Loader do
  @moduledoc """
  Scans a directory of `.exs` diagram metadata files and reads each
  one's referenced `.mmd` source into a list of entry maps.
  """

  @type entry :: %{
          key: String.t(),
          group: String.t(),
          name: String.t(),
          source: String.t()
        }

  @type error_entry :: %{
          key: String.t(),
          group: String.t() | nil,
          name: String.t() | nil,
          error: String.t(),
          file: String.t()
        }

  @spec scan(String.t()) :: [entry() | error_entry()]
  def scan(path) do
    path
    |> Path.join("**/*.exs")
    |> Path.wildcard()
    |> Enum.map(&load_file/1)
  end

  defp load_file(file) do
    case eval_file(file) do
      {:error, message} ->
        error_entry(file, nil, nil, message)

      {:ok, opts} ->
        build_entry(file, opts)
    end
  end

  defp eval_file(file) do
    {opts, _bindings} = Code.eval_file(file)
    {:ok, opts}
  rescue
    e -> {:error, "failed to evaluate #{file}: #{Exception.message(e)}"}
  end

  defp build_entry(file, opts) when is_list(opts) do
    group = Keyword.get(opts, :group)
    name = Keyword.get(opts, :name)
    source_path = Keyword.get(opts, :source)

    cond do
      is_nil(group) ->
        error_entry(file, group, name, "missing required key :group in #{file}")

      is_nil(name) ->
        error_entry(file, group, name, "missing required key :name in #{file}")

      is_nil(source_path) ->
        error_entry(file, group, name, "missing required key :source in #{file}")

      true ->
        read_source(file, group, name, source_path)
    end
  end

  defp build_entry(file, _opts) do
    error_entry(file, nil, nil, "#{file} did not evaluate to a keyword list")
  end

  defp read_source(file, group, name, source_path) do
    case File.read(source_path) do
      {:ok, mermaid} ->
        %{key: file, group: group, name: name, source: mermaid}

      {:error, reason} ->
        message = "could not read source file #{source_path}: #{:file.format_error(reason)}"
        error_entry(file, group, name, message)
    end
  end

  defp error_entry(file, group, name, message) do
    %{key: file, group: group, name: name, error: message, file: file}
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/ex_diag/loader_test.exs`
Expected: PASS (6 tests, 0 failures)

- [ ] **Step 6: Commit**

```bash
git add lib/ex_diag/loader.ex test/ex_diag/loader_test.exs test/support/fixtures/ex_diag
git commit -m "feat: add ExDiag.Loader for scanning diagram metadata files"
```

---

### Task 2: `ExDiag.DiagramLive` — mount and sidebar

**Files:**
- Create: `lib/ex_diag/diagram_live.ex`
- Create: `test/support/test_router.ex`
- Create: `test/support/test_endpoint.ex`
- Create: `test/ex_diag/diagram_live_test.exs`

**Interfaces:**
- Consumes: `ExDiag.Loader.scan/1` from Task 1, returning `[ExDiag.Loader.entry() | ExDiag.Loader.error_entry()]`.
- Produces: `ExDiag.DiagramLive` — a `Phoenix.LiveView` module with `mount/3`, `handle_event/3` for `"select"`, and `render/1`. Assigns: `:entries` (raw list from `Loader.scan/1`), `:groups` (list of `{group_name, [entry]}` tuples in first-seen order), `:selected` (an entry map or `nil`).

- [ ] **Step 1: Add test support router and endpoint**

`test/support/test_endpoint.ex`:
```elixir
defmodule ExDiag.TestEndpoint do
  use Phoenix.Endpoint, otp_app: :ex_diag

  socket "/live", Phoenix.LiveView.Socket

  plug ExDiag.TestRouter
end
```

`test/support/test_router.ex`:
```elixir
defmodule ExDiag.TestRouter do
  use Phoenix.Router
  import Phoenix.LiveView.Router
  import ExDiag.Router

  pipeline :browser do
    plug :accepts, ["html"]
  end

  scope "/" do
    pipe_through :browser
    live_ex_diag "/diagrams", []
  end
end
```

Add to `config/test.exs` (create it if it doesn't exist):
```elixir
import Config

config :ex_diag, ExDiag.TestEndpoint,
  url: [host: "localhost"],
  secret_key_base: String.duplicate("a", 64),
  live_view: [signing_salt: String.duplicate("b", 8)],
  server: false

config :ex_diag, :diagrams_path, Path.join(__DIR__, "../test/support/fixtures/ex_diag/live_view")
```

Ensure `test/test_helper.exs` starts the endpoint:
```elixir
{:ok, _} = Application.ensure_all_started(:phoenix)
{:ok, _} = ExDiag.TestEndpoint.start_link()
ExUnit.start()
```

Fixture directory `test/support/fixtures/ex_diag/live_view/` (used by the LiveView tests):

`test/support/fixtures/ex_diag/live_view/auth.mmd`:
```
graph TD
  A[Login] --> B[Session]
```

`test/support/fixtures/ex_diag/live_view/auth.exs`:
```elixir
[
  group: "Backend",
  name: "Auth Flow",
  source: Path.join(__DIR__, "auth.mmd")
]
```

`test/support/fixtures/ex_diag/live_view/broken.exs`:
```elixir
[
  group: "Backend",
  name: "Broken One"
]
```

- [ ] **Step 2: Write the failing test for mount and sidebar**

```elixir
defmodule ExDiag.DiagramLiveTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  @endpoint ExDiag.TestEndpoint

  test "mount renders sidebar with groups and diagram names" do
    {:ok, view, html} = live_isolated(build_conn(), ExDiag.DiagramLive)

    assert html =~ "Backend"
    assert html =~ "Auth Flow"
    assert has_element?(view, "button", "Auth Flow")
  end

  test "an error entry renders in the sidebar with its file name" do
    {:ok, view, _html} = live_isolated(build_conn(), ExDiag.DiagramLive)

    assert has_element?(view, ".ex-diag-entry-error")
  end

  defp build_conn do
    Phoenix.ConnTest.build_conn()
  end
end
```

Add `import Plug.Test` support: at the top of the test file add `use ExDiag.TestEndpoint` is unnecessary; instead use `Phoenix.ConnTest` which requires `@endpoint` module attribute (already set) — add `import Phoenix.ConnTest` alongside `import Phoenix.LiveViewTest`.

- [ ] **Step 3: Run test to verify it fails**

Run: `mix test test/ex_diag/diagram_live_test.exs`
Expected: FAIL — `ExDiag.DiagramLive` undefined.

- [ ] **Step 4: Implement `ExDiag.DiagramLive` (mount + sidebar only, no selection/detail yet)**

```elixir
defmodule ExDiag.DiagramLive do
  use Phoenix.LiveView

  alias ExDiag.Loader

  @impl true
  def mount(_params, _session, socket) do
    entries = Loader.scan(diagrams_path())
    {:ok, assign(socket, entries: entries, groups: group_entries(entries), selected: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ex-diag-layout">
      <nav class="ex-diag-sidebar">
        <p :if={@entries == []}>No diagrams found in {diagrams_path()}</p>
        <div :for={{group, group_entries} <- @groups} class="ex-diag-group">
          <h3>{group}</h3>
          <ul>
            <li :for={entry <- group_entries}>
              <button
                phx-click="select"
                phx-value-key={entry.key}
                class={entry_class(entry, @selected)}
              >
                {entry[:name] || entry.file}
              </button>
            </li>
          </ul>
        </div>
      </nav>
      <main class="ex-diag-detail">
        <p>Select a diagram from the sidebar.</p>
      </main>
    </div>
    """
  end

  defp diagrams_path do
    Application.get_env(:ex_diag, :diagrams_path, Path.join(File.cwd!(), "priv/ex_diag"))
  end

  defp group_entries(entries) do
    entries
    |> Enum.reduce({[], %{}}, fn entry, {order, groups} ->
      group = entry[:group] || "Errors"

      if Map.has_key?(groups, group) do
        {order, Map.update!(groups, group, &(&1 ++ [entry]))}
      else
        {order ++ [group], Map.put(groups, group, [entry])}
      end
    end)
    |> then(fn {order, groups} -> Enum.map(order, &{&1, Map.fetch!(groups, &1)}) end)
  end

  defp entry_class(entry, selected) do
    base = if Map.has_key?(entry, :error), do: "ex-diag-entry ex-diag-entry-error", else: "ex-diag-entry"
    if selected && selected.key == entry.key, do: base <> " selected", else: base
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/ex_diag/diagram_live_test.exs`
Expected: PASS (2 tests, 0 failures)

- [ ] **Step 6: Commit**

```bash
git add lib/ex_diag/diagram_live.ex test/support test/ex_diag/diagram_live_test.exs config/test.exs test/test_helper.exs
git commit -m "feat: add ExDiag.DiagramLive mount and sidebar rendering"
```

---

### Task 3: `ExDiag.DiagramLive` — selection, detail pane, Mermaid hook

**Files:**
- Modify: `lib/ex_diag/diagram_live.ex`
- Modify: `test/ex_diag/diagram_live_test.exs`
- Create: `priv/static/ex_diag/mermaid_hook.js`

**Interfaces:**
- Produces: `handle_event("select", %{"key" => key}, socket)` — sets `:selected` to the matching entry from `:entries` (or leaves it as-is if no match). Detail pane renders a Mermaid error message for error entries, or a `phx-hook="ExDiagMermaid"` container for valid entries.

- [ ] **Step 1: Write the failing tests**

Add to `test/ex_diag/diagram_live_test.exs`:
```elixir
  test "clicking a diagram name selects it and renders the detail pane" do
    {:ok, view, _html} = live_isolated(build_conn(), ExDiag.DiagramLive)

    html =
      view
      |> element("button", "Auth Flow")
      |> render_click()

    assert html =~ "ex-diag-mermaid"
    assert html =~ "graph TD"
  end

  test "clicking an error entry shows its error message instead of a diagram" do
    {:ok, view, _html} = live_isolated(build_conn(), ExDiag.DiagramLive)

    html =
      view
      |> element("button", "Broken One")
      |> render_click()

    assert html =~ "ex-diag-error"
    assert html =~ "missing required key :source"
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/ex_diag/diagram_live_test.exs`
Expected: FAIL — clicking doesn't change the detail pane yet (still shows "Select a diagram...").

- [ ] **Step 3: Implement selection and detail pane**

Replace the `render/1` `<main>` block and add `handle_event/3` in `lib/ex_diag/diagram_live.ex`:

```elixir
  @impl true
  def handle_event("select", %{"key" => key}, socket) do
    case Enum.find(socket.assigns.entries, &(&1.key == key)) do
      nil -> {:noreply, socket}
      entry -> {:noreply, assign(socket, :selected, entry)}
    end
  end
```

```elixir
      <main class="ex-diag-detail">
        <p :if={is_nil(@selected)}>Select a diagram from the sidebar.</p>
        <div :if={@selected && Map.has_key?(@selected, :error)} class="ex-diag-error">
          <p><strong>Error loading {@selected.file}:</strong></p>
          <p>{@selected.error}</p>
        </div>
        <div
          :if={@selected && !Map.has_key?(@selected, :error)}
          id="ex-diag-mermaid"
          phx-hook="ExDiagMermaid"
          phx-update="ignore"
          data-source={@selected && @selected.source}
        >
          <pre class="mermaid">{@selected && @selected.source}</pre>
        </div>
      </main>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/ex_diag/diagram_live_test.exs`
Expected: PASS (4 tests, 0 failures)

- [ ] **Step 5: Add the Mermaid JS hook asset**

`priv/static/ex_diag/mermaid_hook.js`:
```javascript
import mermaid from "mermaid";

mermaid.initialize({ startOnLoad: false });

export const ExDiagMermaid = {
  mounted() {
    this.render();
  },
  updated() {
    this.render();
  },
  render() {
    const source = this.el.dataset.source;
    const pre = this.el.querySelector("pre.mermaid");
    if (!source || !pre) return;

    mermaid.render(`ex-diag-${this.el.id}-svg`, source).then(({ svg }) => {
      this.el.innerHTML = svg;
    });
  },
};
```

This module is not compiled/bundled by ExDiag itself (it has no JS build step) — it is imported by the host app's own `app.js` per the host-app README instructions added in Task 5.

- [ ] **Step 6: Run the full test suite and precommit check**

Run: `mix precommit`
Expected: format, compile (no warnings), credo --strict, and all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/ex_diag/diagram_live.ex test/ex_diag/diagram_live_test.exs priv/static/ex_diag/mermaid_hook.js
git commit -m "feat: add diagram selection, detail pane, and Mermaid JS hook"
```

---

### Task 4: `ExDiag.Router.live_ex_diag/2`

**Files:**
- Modify: `lib/ex_diag/router.ex`
- Modify: `test/ex_diag/diagram_live_test.exs`

**Interfaces:**
- Consumes: `ExDiag.DiagramLive` from Task 2/3.
- Produces: `ExDiag.Router.live_ex_diag(path, opts)` macro, usable inside any module that `use Phoenix.Router` and `import Phoenix.LiveView.Router`. `opts` is accepted but unused in v1 (reserved for future per-mount overrides).

Note: `test/support/test_router.ex` already calls `live_ex_diag "/diagrams", []` (Task 2) — until this task, that only worked because `ExDiag.Router.live_ex_diag/2` had an empty body that compiled but didn't actually mount a route. This task makes it functional; add a test confirming the route actually resolves.

- [ ] **Step 1: Write the failing test**

Add to `test/ex_diag/diagram_live_test.exs`:
```elixir
  test "live_ex_diag mounts the LiveView at the given path" do
    conn = Phoenix.ConnTest.build_conn() |> Plug.Test.init_test_session(%{})
    {:ok, _view, html} = live(conn, "/diagrams")

    assert html =~ "Backend"
  end
```

Add `import Phoenix.LiveViewTest, only: [live: 2]` is already covered by the existing `import Phoenix.LiveViewTest`; also add `plug ExDiag.TestRouter` conn needs to go through the endpoint, so use `Phoenix.ConnTest.build_conn()` configured with `@endpoint` (already set at module top).

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_diag/diagram_live_test.exs`
Expected: FAIL — no route matches `/diagrams` (macro body is currently empty).

- [ ] **Step 3: Implement the macro**

```elixir
defmodule ExDiag.Router do
  @moduledoc """
  Router helpers for mounting the ExDiag diagram browser in a host
  Phoenix application.

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router
        import ExDiag.Router

        scope "/" do
          pipe_through :browser
          live_ex_diag "/diagrams", []
        end
      end
  """

  @doc """
  Mounts the ExDiag diagram browser LiveView at `path`.

  `opts` is currently unused and reserved for future per-mount
  configuration.
  """
  defmacro live_ex_diag(path, _opts \\ []) do
    quote bind_quoted: [path: path] do
      Phoenix.LiveView.Router.live(path, ExDiag.DiagramLive, :index)
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ex_diag/diagram_live_test.exs`
Expected: PASS (5 tests, 0 failures)

- [ ] **Step 5: Run precommit**

Run: `mix precommit`
Expected: all checks pass.

- [ ] **Step 6: Commit**

```bash
git add lib/ex_diag/router.ex test/ex_diag/diagram_live_test.exs
git commit -m "feat: implement live_ex_diag router macro"
```

---

### Task 5: Demo Phoenix app

**Files:**
- Create: `demo/mix.exs`
- Create: `demo/config/config.exs`
- Create: `demo/config/dev.exs`
- Create: `demo/lib/demo/application.ex`
- Create: `demo/lib/demo_web/endpoint.ex`
- Create: `demo/lib/demo_web/router.ex`
- Create: `demo/assets/js/app.js`
- Create: `demo/priv/ex_diag/overview.exs`
- Create: `demo/priv/ex_diag/overview.mmd`
- Create: `demo/priv/ex_diag/auth_flow.exs`
- Create: `demo/priv/ex_diag/auth_flow.mmd`
- Create: `demo/priv/ex_diag/broken.exs`
- Modify: `.formatter.exs` (exclude `demo/` from the root project's formatter if it collides — verify in Step 5)

**Interfaces:**
- Consumes: `ExDiag.Router.live_ex_diag/2` (Task 4), `priv/static/ex_diag/mermaid_hook.js` (Task 3).
- Produces: a runnable app at `demo/`, no interfaces consumed by other ExDiag code (leaf task).

- [ ] **Step 1: Generate the demo app**

Run from the repo root:
```bash
mix archive.install hex phx_new --force
mix phx.new demo --no-ecto --no-mailer --no-dashboard --app demo --module Demo
```
When prompted "Fetch and install dependencies?", answer `n` — dependencies are wired up manually in the next step to point `ex_diag` at the parent directory.

- [ ] **Step 2: Point the demo app at the local `ex_diag`**

Edit `demo/mix.exs`, in `defp deps do`, add:
```elixir
{:ex_diag, path: "../"}
```

Run:
```bash
cd demo && mix deps.get && cd ..
```

- [ ] **Step 3: Mount the diagram browser in the demo router**

Edit `demo/lib/demo_web/router.ex`, add near the top:
```elixir
import ExDiag.Router
```
And inside the existing `scope "/", DemoWeb do pipe_through :browser end` block (or a new scope), add:
```elixir
live_ex_diag "/diagrams", []
```

- [ ] **Step 4: Wire up the Mermaid JS hook**

Edit `demo/assets/js/app.js`. Add near the top, alongside the existing `LiveSocket` setup:
```javascript
import { ExDiagMermaid } from "../../../priv/static/ex_diag/mermaid_hook";
```
Add `mermaid` as an npm dependency and register the hook in the `LiveSocket` constructor's `hooks` option:
```bash
cd demo/assets && npm install mermaid && cd ../..
```
```javascript
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: { ExDiagMermaid },
});
```

- [ ] **Step 5: Add sample diagrams**

`demo/priv/ex_diag/overview.mmd`:
```
graph TD
  Client --> API
  API --> Database
```

`demo/priv/ex_diag/overview.exs`:
```elixir
[
  group: "Architecture",
  name: "System Overview",
  source: Path.join(__DIR__, "overview.mmd")
]
```

`demo/priv/ex_diag/auth_flow.mmd`:
```
sequenceDiagram
  User->>API: Login
  API->>DB: Verify credentials
  DB-->>API: OK
  API-->>User: Session token
```

`demo/priv/ex_diag/auth_flow.exs`:
```elixir
[
  group: "Architecture",
  name: "Auth Flow",
  source: Path.join(__DIR__, "auth_flow.mmd")
]
```

`demo/priv/ex_diag/broken.exs` (deliberately missing `:source`, to visually confirm error rendering):
```elixir
[
  group: "Architecture",
  name: "Broken Example"
]
```

- [ ] **Step 6: Run the demo app and manually verify**

Run:
```bash
cd demo && mix setup && mix phx.server
```
Visit `http://localhost:4000/diagrams`. Confirm:
- Sidebar shows an "Architecture" group with "System Overview", "Auth Flow", and "Broken Example".
- Clicking "System Overview" or "Auth Flow" renders the corresponding Mermaid diagram.
- Clicking "Broken Example" shows the error message ("missing required key :source...").

Stop the server (Ctrl+C) once confirmed.

- [ ] **Step 7: Exclude `demo/` from the root `mix precommit` alias**

Check `demo/` isn't picked up by the root project's `mix test`/`credo`/`format` — Mix projects don't recurse into subdirectories automatically, so no exclusion config should be needed. Verify by running from the repo root:
```bash
mix precommit
```
Expected: passes and does not attempt to compile/test anything under `demo/`.

- [ ] **Step 8: Commit**

```bash
git add demo .gitignore
git commit -m "chore: add demo app for manually exercising ExDiag"
```

---

## Self-Review Notes

- **Spec coverage:** Router macro (Task 4), Loader scan/discovery/error-handling (Task 1), DiagramLive mount/sidebar/selection/detail/error rendering (Tasks 2–3), Mermaid client rendering via JS hook (Task 3), demo project (Task 5) — all spec sections covered. Env-gating and auth are explicitly out of scope per spec and not implemented here.
- **Type consistency:** `entry.key` (the `.exs` file path) is used consistently as the selection identifier across `Loader`, `DiagramLive`'s `phx-value-key`, and `handle_event("select", ...)`. Error entries always carry `:file` (used for display) — no task introduces a conflicting field name.
- **No placeholders:** all steps contain runnable code or exact shell commands.
