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

- `lib/phoenix_diagrams/router.ex` — `live_phoenix_diagrams/2` macro. Host apps call `live_phoenix_diagrams "/some/path", diagrams_path: "priv/diagrams"` inside a router `scope`, mounting `PhoenixDiagrams.DiagramLive` at `"/"` under that path. `:diagrams_path` is required — raises `ArgumentError` at compile time if missing, no default/app-config fallback — and is threaded through `live_session`'s `session:` map, not `Application.get_env`.
- `lib/phoenix_diagrams/diagram_live.ex` — the LiveView. On mount reads `diagrams_path` from the session, calls `PhoenixDiagrams.Loader.scan/1`, and assigns `entries`/`groups`/`selected`/`diagrams_path`; `handle_event("select", ...)` swaps `selected`. Markup is delegated to `PhoenixDiagrams.Components.Layout`.
- `lib/phoenix_diagrams/components/` — `Phoenix.Component` view layer: `Layout` (outer shell, inlines compiled `app.css`, composes the rest), `Navbar` (theme toggle), `Sidebar` (grouped entry list, drives `select`), `Detail` (renders the selected entry via a `phx-hook` chosen from `entry.type` — `"PhoenixDiagramsMermaid"`/`"PhoenixDiagramsPlantuml"` — with `phx-update="ignore"`). All `@moduledoc false`, internal to the LiveView.
- `lib/phoenix_diagrams/loader.ex` — scans `<path>/**/*.exs`, each `Code.eval_file`'d into a keyword list with `:group`, `:name`, `:source` (extension determines `entry.type`, `:mermaid`/`:plantuml`). Malformed/missing-key/unreadable/unsupported-extension files become error entries (`%{error: ...}`) rather than raising. Touch this when changing the diagram-definition file format.
- `lib/phoenix_diagrams/root_layout.ex` — standalone HTML root layout `DiagramLive` renders under; bootstraps its own `LiveSocket` (fixed at `/live`), loading `phoenix.mjs`/`phoenix_live_view.esm.js` from the host's resolved deps via `Application.app_dir/2` plus the bundled hooks script. The host's own `app.js`/root layout/hooks registration is never involved.
- `lib/phoenix_diagrams/asset_plug.ex` — serves `phoenix.mjs`, `phoenix_live_view.esm.js`, and `bundle.js` under `<mount>/phoenix-diagrams-assets/*` with `cache-control: immutable`, made safe by a `?v=<hash>` fingerprint (`asset_version/0`, SHA-256 over all three, cached in `:persistent_term`) that `RootLayout` appends to each URL — don't drop that query param without loosening the cache header.
- `priv/static/phoenix_diagrams/` — self-contained npm project (gitignored `node_modules`/`package-lock.json`) bundling `mermaid` and `@plantuml/core` (TeaVM-compiled, client-side, no Java/server) via `mermaid_hook.js`/`plantuml_hook.js`. Only its `build/app.css` and `build/bundle.js` output is packaged/served — rebuild with `npm run build:css`/`npm run build:js` after editing sources.
- Test setup (`test/support/`): `PhoenixDiagrams.TestRouter`/`TestEndpoint` stand in for a host app. `test/support/fixtures/phoenix_diagrams/` holds fixture diagram directories (`valid`, `mixed`, `missing_key`, `missing_source`, `eval_error`, `live_view`) for the Loader's success/error paths — add new fixtures there rather than inline `.exs`/`.mmd` in test bodies.

## Design Principles

- **Self-contained, zero host-asset coupling.** Must render/function without the host editing its own `app.css`/`app.js`. Styles are compiled here and inlined; JS hooks are vendored and pre-bundled — no host-side implementation code or host-managed npm dependency.
- **Never crash the host page on bad input.** Malformed diagram definitions become inline error entries, not exceptions.
- **daisyUI for structure, not host theming.** The library ships its own light/dark daisyUI themes so it looks correct regardless of host design system.
- **Target WCAG 2.1 AA.** Proper ARIA (`aria-label`/`aria-current`/`role="status"`/`role="img"`, `aria-hidden` on decorative icons); verify contrast/focus manually in `demo/` since that isn't checkable from markup alone.

## Gotchas

- HEEx treats `<style>`/`<script>` as verbatim tags — `{@assign}` inside a literal `<style>...</style>` is NOT interpolated. Emit the whole tag as one expression: `{Phoenix.HTML.raw("<style>" <> css <> "</style>")}`.
- Module attributes (`@foo`) aren't visible inside `~H` templates (that syntax reads assigns) — wrap in a private function and call it, e.g. `{my_attr()}`.
- Colocated hooks don't work for host consumption here (the colocated build dir's `node_modules` symlinks to the *host's* `assets/node_modules`, not this repo's vendored one) — moot since hooks ship pre-bundled via `AssetPlug` instead.
- `phx-update="ignore"` only freezes an element's *children*, not its own attributes (e.g. `data-source`), which still get patched on re-render. Reapply client-only state (e.g. a `data-theme` toggle) in the hook's `updated()` callback.
- A parent hook's `updated()` and a child hook's `mounted()` can both fire within the same patch, in either order. If both trigger the same async work (e.g. `mermaid.render()`) they can run concurrently against the same target id. Serialize through a promise queue on the hook instance.
- To manually verify a JS-hook-driven UI change, `curl`ing `demo/` only shows pre-hook server-rendered HTML — use chrome-devtools MCP tools against a running `mix phx.server` instead.
- `@plantuml/core`'s `viz-global.js` has an unreachable Node-only branch (`require("url")`) esbuild still tries to resolve — `build:js` already passes `--external:url`.
- `Plug.CSRFProtection` raises on a plain `GET` if the response looks like JS/JSON and the request isn't XHR-flagged (trips on `<script type="module">` fetched via `curl` or a host's `protect_from_forgery`) — `AssetPlug` must `put_private(:plug_skip_csrf_protection, true)` before sending JS.
- `@plantuml/core`'s `renderToString/3` (used to match the Mermaid hook's `innerHTML`-setting shape) has no dark-mode option — only `render/3` does. PlantUML diagrams always render light-mode; Mermaid still themes correctly.
- Before `mix phx.server` in `demo/`, check `ss -tlnp | grep 4000` first — a server the user already has running will conflict, and a code-reloader `config.exs` reload error means it needs restarting, not just retrying.
- `esbuild --minify` (identifier renaming) corrupts `@plantuml/core`'s TeaVM output when bundling `bundle.js` — produces a syntax error that silently breaks *every* hook, not just PlantUML's. `build:js` uses `--minify-whitespace` only. Verify any rebuilt bundle with `node --input-type=module --check < bundle.js` before committing.
