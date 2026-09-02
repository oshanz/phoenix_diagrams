# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PhoenixDiagrams — an Elixir/Phoenix LiveView library that embeds a Mermaid/PlantUML diagram browser into a host Phoenix application. A host app mounts it via a router macro, PhoenixDiagrams scans a directory of `.exs` metadata files that each point at a `.mmd` (Mermaid) or `.puml` (PlantUML) source file, and renders them in a sidebar/detail LiveView with client-side rendering.

`demo/` is a full Phoenix app used to exercise the library manually; it is a separate Mix project with its own `mix.exs` and dependencies (including Tailwind/esbuild asset pipeline), not part of the `phoenix_diagrams` app itself. It is not exercised by `mix test`.

## Commands

Run these from the repo root (they operate on the `phoenix_diagrams` library, not `demo/`):

- Install deps: `mix deps.get`
- Run tests: `mix test` (single file: `mix test test/phoenix_diagrams/loader_test.exs`, single test: `mix test test/phoenix_diagrams/loader_test.exs:6`)
- Format: `mix format`
- Lint: `mix credo --strict`
- Full precommit check (format, compile with warnings-as-errors, credo --strict, test): `mix precommit`

Always run `mix precommit` before considering a change complete.

The `demo/` app has its own independent toolchain (`cd demo && mix phx.server`) for manually verifying UI changes in a real Phoenix app.

## Architecture

- `lib/phoenix_diagrams/router.ex` — `live_phoenix_diagrams/2` macro mounting `PhoenixDiagrams.DiagramLive` plus an asset-plug `forward`. `:diagrams_path` is required (raises at compile time if missing) and is threaded through `live_session`'s `session:` map, not `Application.get_env`.
- `lib/phoenix_diagrams/diagram_live.ex` — the LiveView. Scans `diagrams_path` via `Loader.scan/1` on mount; when `connected?/1`, starts a `:file_system` watcher for dev live-reload (compiled out of release builds via `Code.ensure_loaded?(FileSystem)`, since `:file_system` is an `only: :dev` dep). The selected diagram is resolved from an `?d=<id>` query param (`diagram_id/2`, an 8-char SHA-256 hash of the relative path) via `handle_params/3`, so diagrams are directly linkable; `select` events `push_patch` to that URL rather than assigning `selected` directly.
- `lib/phoenix_diagrams/components/` — `Phoenix.Component` view layer (`@moduledoc false`, internal): `Layout`, `Navbar`, `Sidebar` (resizable via `PhoenixDiagramsSidebar` hook), `Detail` (tabbed Preview/Code; toolbar actions — download/share/zoom/fullscreen/copy — each its own `phx-hook`; diagram renders via `"PhoenixDiagramsMermaid"`/`"PhoenixDiagramsPlantuml"` with `phx-update="ignore"`), `Icons`.
- `lib/phoenix_diagrams/components/icons.ex` + `icons/*.svg` — icons vendored one-per-file from heroicons v2.2.0, not the `:heroicons` Hex package (that name commonly collides with a host app's own `mix phx.new`-generated dependency). Add an icon by dropping an svg in `icons/` and listing its name in `@outline`/`@solid`.
- `lib/phoenix_diagrams/loader.ex` — scans `<path>/**/*.exs`, each `Code.eval_file`'d into a keyword list with `:group`/`:name`/`:source`. Malformed/missing-key/unreadable/unsupported-extension files become error entries rather than raising. Touch this when changing the diagram-definition file format.
- `lib/phoenix_diagrams/root_layout.ex` — standalone root layout bootstrapping its own `LiveSocket` (fixed at `/live`) and registering all client hooks; the host's own `app.js`/root layout is never involved.
- `lib/phoenix_diagrams/asset_plug.ex` — serves `phoenix.mjs`/`phoenix_live_view.esm.js`/`bundle.js` under `<mount>/phoenix-diagrams-assets/*`, fingerprinted with a `?v=<hash>` (`asset_version/0`) that `RootLayout` appends — don't drop that query param without loosening the `immutable` cache header.
- `priv/static/phoenix_diagrams/` — self-contained npm project bundling `mermaid` and `@plantuml/core` (TeaVM-compiled, client-side). `bundle_entry.js` is the esbuild entry pulling in one hook file per feature. Only `build/app.css`/`build/bundle.js` are packaged — rebuild with `npm run build:css`/`build:js` after editing sources.
- `test/support/` — `TestRouter`/`TestEndpoint` stand in for a host app; `fixtures/phoenix_diagrams/` holds fixture diagram dirs for the Loader's success/error paths — add new fixtures there rather than inline `.exs`/`.mmd`/`.puml` in test bodies.

## Design Principles

- **Self-contained, zero host-asset coupling.** Must render/function without the host editing its own `app.css`/`app.js`. Styles are compiled here and inlined; JS hooks are vendored and pre-bundled — no host-side implementation code or host-managed npm dependency.
- **Never crash the host page on bad input.** Malformed diagram definitions become inline error entries, not exceptions.
- **daisyUI for structure, not host theming.** The library ships its own light/dark daisyUI themes so it looks correct regardless of host design system.
- **Target WCAG 2.1 AA.** Proper ARIA (`aria-label`/`aria-current`/`role="status"`/`role="img"`, `aria-hidden` on decorative icons); verify contrast/focus manually in `demo/` since that isn't checkable from markup alone.

## Gotchas

- HEEx treats `<style>`/`<script>` as verbatim tags — `{@assign}` inside a literal `<style>...</style>` is NOT interpolated. Emit the whole tag as one expression: `{Phoenix.HTML.raw("<style>" <> css <> "</style>")}`.
- Module attributes (`@foo`) aren't visible inside `~H` templates (that syntax reads assigns) — wrap in a private function and call it, e.g. `{my_attr()}`.
- `phx-update="ignore"` only freezes an element's *children*, not its own attributes (e.g. `data-source`), which still get patched on re-render. Reapply client-only state (e.g. a `data-theme` toggle) in the hook's `updated()` callback.
- A parent hook's `updated()` and a child hook's `mounted()` can both fire within the same patch, in either order. If both trigger the same async work (e.g. `mermaid.render()`) they can run concurrently against the same target id. Serialize through a promise queue on the hook instance.
- To manually verify a JS-hook-driven UI change, `curl`ing `demo/` only shows pre-hook server-rendered HTML — use chrome-devtools MCP tools against a running `mix phx.server` instead.
- `Plug.CSRFProtection` raises on a plain `GET` if the response looks like JS/JSON and the request isn't XHR-flagged — `AssetPlug` must `put_private(:plug_skip_csrf_protection, true)` before sending JS.
- `@plantuml/core`'s `renderToString/3` has no dark-mode option — only `render/3` does. PlantUML diagrams always render light-mode; Mermaid still themes correctly.
- `esbuild --minify` (identifier renaming) corrupts `@plantuml/core`'s TeaVM output — `build:js` uses `--minify-whitespace` only. Verify any rebuilt bundle with `node --input-type=module --check < bundle.js` before committing.
