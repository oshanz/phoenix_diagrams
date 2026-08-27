# ExDiag

An Elixir/Phoenix LiveView library that embeds a Mermaid/PlantUML diagram
browser into a host Phoenix application. Point it at a directory of diagram
definitions and it mounts a sidebar/detail LiveView that renders them
client-side — no host CSS wiring, no Java/PlantUML server required.

## Installation

Add `ex_diag` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_diag, "~> 0.1.0"}
  ]
end
```

## Usage

### 1. Mount the router

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  import ExDiag.Router

  scope "/" do
    pipe_through :browser
    live_ex_diag "/diagrams", []
  end
end
```

This mounts `ExDiag.DiagramLive` at `/diagrams` — that's it. No changes to
your `app.js`, `assets/`, or esbuild config, and no npm dependency on
`mermaid` or `@plantuml/core`. The route renders on its own standalone page
with its own root layout, which bootstraps its own `LiveSocket` and serves
its JS (styles are compiled into the library and inlined at render time
too). See `CLAUDE.md` for how that's wired if you're curious.

### 2. Add diagram definitions

ExDiag scans a directory (`priv/ex_diag` under your app's `cwd` by default,
configurable via `config :ex_diag, :diagrams_path, "..."`) for `.exs` files.
Each one evaluates to a keyword list describing one diagram:

```elixir
# priv/ex_diag/backend/overview.exs
[
  group: "Backend",
  name: "System Overview",
  source: Path.join(__DIR__, "overview.mmd")
]
```

`source` points at a `.mmd` (Mermaid) or `.puml` (PlantUML) file — the
extension determines how it's rendered. Diagrams are grouped in the sidebar
by their `:group` key. A malformed or unreadable definition shows up as an
inline error in the browser instead of crashing your app.

## Development

This repository contains the `ex_diag` library itself. `demo/` is a
separate, full Phoenix application (its own `mix.exs`, deps, and
Tailwind/esbuild asset pipeline) used to manually exercise the library — it
is not part of the library and isn't run by `mix test`.

Common commands, run from the repo root:

```sh
mix deps.get              # install deps
mix test                  # run tests
mix format                # format code
mix credo --strict        # lint
mix precommit             # format + compile (warnings-as-errors) + credo + test
```

To try the library in a real Phoenix app:

```sh
cd demo
mix phx.server
```

See `CLAUDE.md` for architecture notes and known gotchas.

## License

TODO: Add license information.
