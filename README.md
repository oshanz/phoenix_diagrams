# PhoenixDiagrams

Do you have Mermaid or PlantUML diagrams spread across your codebase? PhoenixDiagrams
collects them into a simple catalog view inside your Phoenix app. You
just point it to a directory of diagram definitions, and it does the rest.
Everything is rendered on the client side.

## Features

- [x] Mermaid diagram rendering
- [x] PlantUML rendering — no Java or PlantUML server required
- [x] Pan and zoom on rendered diagrams
- [x] Copy diagram source to clipboard
- [x] Download rendered diagram as an image
- [x] Dev-only live reload — editing a diagram file updates the view

## Installation

```elixir
def deps do
  [
    {:phoenix_diagrams, "~> 0.1.0"}
  ]
end
```

## Usage

There are two steps to get started: mount the router, and then add some
diagrams.

### 1. Mount the router

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  import PhoenixDiagrams.Router

  scope "/" do
    pipe_through :browser
    live_phoenix_diagrams "/diagrams", diagrams_path: "priv/diagrams"
  end
end
```

This mounts `PhoenixDiagrams.DiagramLive` at `/diagrams`. Keep in mind that
`:diagrams_path` is required. There is no default value.

### 2. Add diagram definitions

Now give PhoenixDiagrams something to show. It scans the directory you set in
`:diagrams_path` for `.exs` files. Each file should evaluate to a keyword
list, like this:

```elixir
# priv/phoenix_diagrams/backend/overview.exs
[
  group: "Backend",
  name: "System Overview",
  source: Path.join(__DIR__, "overview.mmd")
]
```

`source` points to a `.mmd` (Mermaid) or `.puml` (PlantUML) file. That's all
you need. Add as many `.exs` files as you like, group them however you want,
and they will appear in the sidebar.

## Development

```sh
mix deps.get              # install deps
mix precommit             # format + compile (warnings-as-errors) + credo + test
cd demo && mix phx.server # try it in a real Phoenix app
```
