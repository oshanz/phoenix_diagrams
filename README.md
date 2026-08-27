# ExDiag

An Elixir/Phoenix LiveView library that embeds a Mermaid/PlantUML diagram
browser into a host Phoenix application. Point it at a directory of diagram
definitions and it mounts a sidebar/detail LiveView that renders them
client-side — no host CSS wiring, no Java/PlantUML server required.

## Installation

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
    live_ex_diag "/diagrams", diagrams_path: "priv/diagrams"
  end
end
```

This mounts `ExDiag.DiagramLive` at `/diagrams` — no changes to your `app.js`
or asset pipeline needed. See `usage-rules.md` and `CLAUDE.md` for how that's
wired. `:diagrams_path` is required — there's no default.

### 2. Add diagram definitions

ExDiag scans the directory given via `:diagrams_path` for `.exs` files, each
evaluating to a keyword list:

```elixir
# priv/ex_diag/backend/overview.exs
[
  group: "Backend",
  name: "System Overview",
  source: Path.join(__DIR__, "overview.mmd")
]
```

`source` points at a `.mmd` (Mermaid) or `.puml` (PlantUML) file. Diagrams
are grouped in the sidebar by `:group`. A malformed or unreadable definition
shows up as an inline error instead of crashing your app.

## Development

This repo is the `ex_diag` library. `demo/` is a separate Phoenix app (its
own `mix.exs`/deps/asset pipeline) for manually exercising it — not run by
`mix test`.

```sh
mix deps.get              # install deps
mix precommit             # format + compile (warnings-as-errors) + credo + test
cd demo && mix phx.server # try it in a real Phoenix app
```

See `CLAUDE.md` for architecture notes and known gotchas.

## License

TODO: Add license information.
