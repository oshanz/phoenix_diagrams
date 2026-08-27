# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ExDiag — an Elixir/Phoenix LiveView library that embeds a Mermaid diagram browser into a host Phoenix application. A host app mounts it via a router macro, ExDiag scans a directory of `.exs` metadata files that each point at a `.mmd` Mermaid source file, and renders them in a sidebar/detail LiveView with client-side Mermaid rendering.

`demo/` is a full Phoenix app used to exercise the library manually; it is a separate Mix project with its own `mix.exs` and dependencies (including Tailwind/esbuild asset pipeline), not part of the `ex_diag` app itself.

## Commands

Run these from the repo root (they operate on the `ex_diag` library, not `demo/`):

- Install deps: `mix deps.get`
- Run tests: `mix test` (single file: `mix test test/ex_diag/loader_test.exs`, single test: `mix test test/ex_diag/loader_test.exs:6`)
- Format: `mix format`
- Lint: `mix credo --strict`
- Full precommit check (format, compile with warnings-as-errors, credo --strict, test): `mix precommit`

Always run `mix precommit` before considering a change complete — it's the defined alias for this repo's full check.

The `demo/` app has its own independent toolchain (`cd demo && mix phx.server`, etc.) for manually verifying UI changes in a real Phoenix app; it is not exercised by `mix test` at the root.

## Architecture

- `lib/ex_diag/router.ex` — `live_ex_diag/2` macro. Host apps `import ExDiag.Router` and call `live_ex_diag "/some/path", []` inside a router `scope`, which mounts `ExDiag.DiagramLive` at `"/"` under that path.
- `lib/ex_diag/diagram_live.ex` — the LiveView itself. On mount it calls `ExDiag.Loader.scan/1` against a configurable diagrams path (`Application.get_env(:ex_diag, :diagrams_path, ...)`, defaulting to `priv/ex_diag` under cwd) and renders a two-pane layout: a grouped sidebar of diagram entries and a detail pane that renders the selected entry's Mermaid source via a `phx-hook="ExDiagMermaid"` JS hook (`phx-update="ignore"`, since the hook owns that DOM).
- `lib/ex_diag/loader.ex` — scans `<path>/**/*.exs` files. Each `.exs` file is expected to `Code.eval_file` into a keyword list with `:group`, `:name`, and `:source` (a path to a `.mmd` file). Loader returns a list of entry maps; malformed/missing-key/unreadable files become error entries (`%{error: ...}`) rather than raising, and `DiagramLive` renders those inline instead of crashing. This is the layer to touch when changing the diagram-definition file format.
- `priv/static/ex_diag/` — a self-contained npm project bundling `mermaid` (plus its dependencies like `cytoscape`, `dagre-d3-es`, `d3`, `katex`) and `mermaid_hook.js`, the source for the `ExDiagMermaid` phx-hook that a host app's asset pipeline needs to pick up.
- Test setup (`test/support/`): `ExDiag.TestRouter` and `ExDiag.TestEndpoint` stand in for a host Phoenix app so the router macro and LiveView can be exercised via `Phoenix.LiveViewTest` without a real consuming application. `test/support/fixtures/ex_diag/` holds fixture diagram directories (`valid`, `mixed`, `missing_key`, `missing_source`, `eval_error`, `live_view`) exercising the Loader's success/error paths — add new fixture subdirectories there rather than inline `.exs`/`.mmd` files in test bodies.
