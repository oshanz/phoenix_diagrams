# ExDiag — Diagram Viewer Design

Date: 2026-08-27

## Purpose

ExDiag is a Phoenix/LiveView library that lets a host Phoenix application
host a live-updating UML/architecture diagram viewer, intended for use in
dev and staging environments. Diagram source is authored as Mermaid text
files in the host app, described by small per-diagram metadata files, and
browsed through a sidebar (grouped list) + single-diagram detail view.

Environment gating (i.e. keeping this out of production) is the host app's
responsibility — they simply choose where and whether to call the router
macro. ExDiag itself does not check `Mix.env()` or require any special
config to disable itself in prod.

## Components

### 1. `ExDiag.Router.live_ex_diag/2`

A macro the host app invokes from its own `Router` module to mount the
diagram browser LiveView at a path of their choosing:

```elixir
scope "/" do
  pipe_through :browser
  live_ex_diag "/diagrams", []
end
```

`opts` is reserved for future use (e.g. a custom `:diagrams_path` override
per-mount) but v1 only needs the path. The macro expands to a standard
`live/3` (or `live_session`) call mounting `ExDiag.DiagramLive`.

### 2. `ExDiag.Loader`

Responsible for discovering and reading diagram definitions at mount time.

- **Discovery directory**: defaults to `priv/ex_diag/` in the host app,
  overridable via `config :ex_diag, :diagrams_path, "some/other/dir"`.
- **Scan**: recursively finds all `*.exs` files under that directory.
- **Per-file format**: each `.exs` file, when evaluated, returns a keyword
  list:

  ```elixir
  [
    group: "Backend",
    name: "Auth Flow",
    source: "priv/diagrams/auth.mmd"
  ]
  ```

  - `group` (required, string) — the sidebar section this diagram is
    listed under.
  - `name` (required, string) — the diagram's display name within its
    group.
  - `source` (required, string) — path to a `.mmd` file, resolved
    relative to the host application's root (via `Application.app_dir/2`
    or `File.cwd!/0` — matching how the host app resolves its own `priv`
    paths).

- **Evaluation**: files are evaluated with `Code.eval_file/1`. No caching
  — `Loader.scan/1` runs fresh on every `ExDiag.DiagramLive` mount, so
  edits to `.exs` metadata or `.mmd` source files are picked up on the
  next page load/refresh with no server restart required.
- **Output**: a list of diagram entries. Each successfully-loaded entry is
  `%{group: String.t(), name: String.t(), source: String.t()}` (mermaid
  text, already read from the `.mmd` file). A `.exs` file that fails to
  evaluate, is missing a required key, or whose `source` file doesn't
  exist produces an error entry instead:
  `%{group: String.t() | nil, name: String.t() | nil, error: String.t(), file: Path.t()}`
  — using whatever `group`/`name` were successfully parsed (or `nil` if
  the eval itself failed), plus a human-readable error message and the
  offending file's path. One bad file must never crash the scan or the
  mount — it degrades to a visibly broken entry.

### 3. `ExDiag.DiagramLive`

The LiveView that renders the browser UI.

- **Mount**: calls `ExDiag.Loader.scan/1`, assigns the resulting list of
  entries (grouped by `group`) and no diagram selected initially (or the
  first successfully-loaded diagram, TBD at implementation time — default
  to none selected, showing an empty state with instructions).
- **Sidebar**: renders one section per distinct `group`, listing `name`
  for each diagram in that group. Error entries render in their group
  with a visibly different (error) style, using `file` as the label if
  `name` is `nil`.
- **Selection**: clicking a diagram name sets a `:selected` assign to
  that diagram's identity (e.g. its source file path, used as a stable
  key) and re-renders the detail pane.
- **Detail pane**: for a normal entry, renders a container `div` with the
  diagram's mermaid text embedded (e.g. as a data attribute or the div's
  text content) and a JS hook that calls `mermaid.render` against it on
  mount/update. For an error entry, renders the error message and file
  path instead of attempting to render anything.
- **Mermaid rendering**: client-side via mermaid.js, loaded as a static
  JS asset bundled with ExDiag (via a Phoenix Component / JS hook
  co-located with the LiveView) and a `Phoenix.LiveView.JS` hook that
  triggers re-render on `phx:update`.

## Data Flow

```
mount
  -> Loader.scan(diagrams_path)
  -> [%{group, name, source} | %{group, name/nil, error, file}]
  -> assign(:entries, grouped_by_group)
  -> render sidebar from :entries

click diagram name
  -> assign(:selected, diagram_key)
  -> render detail pane for selected entry
  -> JS hook renders mermaid source client-side
```

## Error Handling

- Directory missing entirely: `Loader.scan/1` returns an empty list; the
  LiveView shows an empty state ("No diagrams found in `<path>`") rather
  than raising.
- Individual `.exs` file eval error (syntax error, runtime error): caught,
  converted to an error entry with the exception message.
- Missing required key(s) in the keyword list: caught, converted to an
  error entry naming which key(s) are missing.
- `source` path does not resolve to a readable file: caught, converted to
  an error entry.
- These failures are isolated per-file — one broken diagram definition
  never prevents the rest of the diagrams from loading and rendering.

## Testing

- **`ExDiag.Loader` unit tests** (`test/ex_diag/loader_test.exs`) using
  fixture `.exs`/`.mmd` files under `test/support/fixtures/ex_diag/`:
  - valid file loads correctly with expected group/name/source content
  - `.exs` file missing a required key produces an error entry
  - `.exs` file pointing at a nonexistent `.mmd` file produces an error
    entry
  - `.exs` file with a syntax/eval error produces an error entry
  - directory with a mix of valid and invalid files returns both,
    isolated from each other
  - empty/missing directory returns an empty list
- **`ExDiag.DiagramLive` tests** (`test/ex_diag/diagram_live_test.exs`)
  using `Phoenix.LiveViewTest` against a test host router that mounts
  `live_ex_diag`:
  - mount renders sidebar with groups/names from fixture diagrams
  - clicking a diagram name updates the detail pane to that diagram
  - an error entry renders its error state instead of a diagram

## Demo Project

A minimal, runnable Phoenix app is included in this repo under `demo/` to
manually exercise the diagram viewer during development — separate from
the ExUnit test suite.

- Generated via `mix phx.new demo --no-ecto --no-mailer` (or hand-trimmed
  equivalent) inside the repo root, depending on `ex_diag` via a relative
  path: `{:ex_diag, path: "../"}`.
- Its router mounts `live_ex_diag "/diagrams", []` behind `:browser`.
- `demo/priv/ex_diag/` ships a handful of sample `.exs` + `.mmd` files
  covering: multiple groups, multiple diagrams per group, and one
  deliberately broken entry (missing key or bad path) to visually confirm
  error-entry rendering.
- Run with `cd demo && mix setup && mix phx.server`, then visit
  `/diagrams` in a browser.
- `demo/` is excluded from the root `mix precommit` alias (it's not a
  library dependency of `ex_diag`) but gets its own minimal `mix.exs`
  under the same repo, and its own `deps`/`_build` stay out of the root
  `.gitignore`'d paths as usual.
- Not published as part of the `ex_diag` hex package (irrelevant until
  packaging is addressed, out of scope for v1 regardless).

## Out of Scope (v1)

- Environment-based access gating (host app's responsibility).
- PlantUML or other non-Mermaid diagram formats.
- Editing diagrams from the browser (view-only).
- Caching / performance optimization of the scan (acceptable for a
  dev/staging tool with small diagram counts).
- Auth/permissions on the diagram viewer route (host app's responsibility,
  same as env gating).
