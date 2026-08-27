# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ExDiag — an Elixir/Phoenix LiveView library that embeds a Mermaid/PlantUML diagram browser into a host Phoenix application. A host app mounts it via a router macro, ExDiag scans a directory of `.exs` metadata files that each point at a `.mmd` (Mermaid) or `.puml` (PlantUML) source file, and renders them in a sidebar/detail LiveView with client-side rendering.

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
- `lib/ex_diag/diagram_live.ex` — the LiveView itself. On mount it calls `ExDiag.Loader.scan/1` against a configurable diagrams path (`Application.get_env(:ex_diag, :diagrams_path, ...)`, defaulting to `priv/ex_diag` under cwd) and assigns `entries`/`groups`/`selected`; the `handle_event("select", ...)` clause swaps `selected` on sidebar clicks. The actual markup is delegated to `ExDiag.Components.Layout`.
- `lib/ex_diag/components/` — `Phoenix.Component`-based view layer split out of `DiagramLive`: `Layout` is the outer shell (inlines the compiled `app.css` via `Phoenix.HTML.raw`, embeds the initial dark/light theme script, composes the other three), `Navbar` (theme toggle), `Sidebar` (grouped entry list, drives the `select` event), and `Detail` (renders the selected entry's source via a `phx-hook` chosen from `entry.type` — `"ExDiagMermaid"` or `"ExDiagPlantuml"` — with `phx-update="ignore"` since the hook owns that DOM). All are `@moduledoc false` — they're internal to the LiveView, not a public API.
- `lib/ex_diag/loader.ex` — scans `<path>/**/*.exs` files. Each `.exs` file is expected to `Code.eval_file` into a keyword list with `:group`, `:name`, and `:source` (a path to a `.mmd` or `.puml` file — the extension determines `entry.type`, `:mermaid` or `:plantuml`; any other extension becomes an error entry). Loader returns a list of entry maps; malformed/missing-key/unreadable/unsupported-extension files become error entries (`%{error: ...}`) rather than raising, and `DiagramLive` renders those inline instead of crashing. This is the layer to touch when changing the diagram-definition file format.
- `priv/static/ex_diag/` — a self-contained npm project bundling `mermaid` (plus its dependencies like `cytoscape`, `dagre-d3-es`, `d3`, `katex`), `@plantuml/core` (a TeaVM-compiled build of PlantUML that renders entirely client-side, no Java/server), and `mermaid_hook.js`/`plantuml_hook.js`, the sources for the `ExDiagMermaid`/`ExDiagPlantuml` phx-hooks that a host app's asset pipeline needs to pick up.
- Test setup (`test/support/`): `ExDiag.TestRouter` and `ExDiag.TestEndpoint` stand in for a host Phoenix app so the router macro and LiveView can be exercised via `Phoenix.LiveViewTest` without a real consuming application. `test/support/fixtures/ex_diag/` holds fixture diagram directories (`valid`, `mixed`, `missing_key`, `missing_source`, `eval_error`, `live_view`) exercising the Loader's success/error paths — add new fixture subdirectories there rather than inline `.exs`/`.mmd` files in test bodies.

## Design Principles

- **Self-contained, zero host-asset coupling.** ExDiag must render and function correctly without the host app editing its own `app.css`/`app.js`. Styles are compiled here and inlined at render time; JS hooks are vendored here and only need one import line in the host's hooks list — never require host-side implementation code or a host-managed npm dependency.
- **Never crash the host page on bad input.** Malformed diagram definitions (missing keys, unreadable files, eval errors) become error entries rendered inline (see `Loader`/`DiagramLive`), not exceptions — a broken `.exs` in one group must not take down the whole diagram browser.
- **daisyUI for structure, not host theming.** Use daisyUI component classes (`drawer`, `menu`, `card`, `alert`, etc.) for layout/behavior; the library ships both light/dark daisyUI themes itself so it looks correct regardless of the host's own design system.
- **Target WCAG 2.1 AA.** `DiagramLive` markup should carry proper ARIA (`aria-label`/`aria-current`/`role="status"`/`role="img"` for the rendered mermaid SVG, `aria-hidden` on decorative icons) — verify with `mix test` plus a manual pass in `demo/` for color contrast and focus visibility, which aren't checkable from markup alone.

## Gotchas

- HEEx treats `<style>`/`<script>` as verbatim tags — `{@assign}` inside a literal `<style>...</style>` in template source is NOT interpolated. Emit the whole tag as one expression instead: `{Phoenix.HTML.raw("<style>" <> css <> "</style>")}`.
- Module attributes (`@foo`) are not visible as `@foo` inside `~H` templates (that syntax reads assigns, not attributes) — wrap in a private function and call it, e.g. `{my_attr()}`.
- Colocated hooks (`Phoenix.LiveView.ColocatedHook`) defined in this library don't work well for host consumption: the dependency's own `mix.exs` would need `compilers: [:phoenix_live_view] ++ Mix.compilers()` to generate a manifest, and even then the colocated build dir's `node_modules` symlinks to the *host* app's `assets/node_modules`, not this repo's vendored one — so a hook needing an npm package (e.g. mermaid) won't resolve it. This is now moot for host integration: hooks ship pre-bundled in `priv/static/ex_diag/build/bundle.js` (built via `npm run build:js`) and are served by `ExDiag.AssetPlug` under `<mount>/ex-diag-assets/bundle.js` — no host `node_modules` resolution is ever needed, and the host never registers hooks itself (`ExDiag.RootLayout` bootstraps its own `LiveSocket`).
- `priv/static/ex_diag/` is a self-contained npm project (node_modules + package-lock.json gitignored) vendoring both `mermaid` and the Tailwind+daisyUI CSS build; compiled output goes to `priv/static/ex_diag/build/` (`app.css`, `bundle.js`), the only files the runtime and Hex package actually reference. Rebuild CSS with `npm run build:css` there after editing `input.css` or `DiagramLive`'s markup.
- `phx-update="ignore"` only freezes an element's *children* from morphdom patching — the element's own attributes (e.g. `data-source`) still get updated on every LiveView patch. Don't assume JS-set attributes on an ignored element (or any element) survive re-renders unless nothing server-side ever re-renders it; reapply client-only state (e.g. a `data-theme` toggle) in the hook's `updated()` callback.
- A parent hook's `updated()` and a child hook's `mounted()` can both fire within the same LiveView patch, in either order. If both can trigger the same async work (e.g. `mermaid.render()`), they can run concurrently against the same target id and corrupt the output. Serialize such calls through a promise queue on the hook instance rather than assuming one-at-a-time.
- To manually verify a JS-hook-driven UI change, `curl`ing `demo/` only shows the server-rendered HTML before hooks run — use the chrome-devtools MCP tools (`new_page`/`click`/`take_screenshot`/`evaluate_script`) against a running `mix phx.server` to see actual post-hook DOM/rendering state.
- `@plantuml/core`'s `viz-global.js` is a UMD/Emscripten build with an unreachable Node-only branch (`require("url")`) that esbuild still tries to statically resolve when bundled. This now only matters for ExDiag's own `npm run build:js` (`priv/static/ex_diag/package.json` already passes `--external:url`) — host apps no longer bundle `@plantuml/core` themselves, so they don't need this flag.
- `Plug.CSRFProtection` raises `InvalidCrossOriginRequestError` on a plain `GET` if the response content-type looks like JS/JSON and the request isn't XHR and CSRF protection isn't explicitly skipped — this trips even for a same-origin `<script type="module">` import fetched via `curl` (no `Sec-Fetch-*` headers) or through a host's `protect_from_forgery` pipeline. `ExDiag.AssetPlug` must `put_private(:plug_skip_csrf_protection, true)` before sending its JS responses.
- `@plantuml/core`'s `renderToString(lines, onSuccess, onError)` (used so the hook can set `innerHTML` itself, matching the Mermaid hook's shape) has no documented dark-mode option — only its `render(lines, targetId, {dark})` counterpart does. PlantUML diagrams currently always render light-mode; `ExDiagMermaid` still themes correctly.
- Before starting `mix phx.server` in `demo/` to manually verify a change, check `ss -tlnp | grep 4000` (or similar) first — a server the user already has running (possibly with a browser tab open) will conflict, and a Phoenix code-reloader `config.exs` reload error means an already-running server needs restarting, not just retrying.
- `ExDiag.AssetPlug` sets `cache-control: public, max-age=31536000, immutable` on its three JS routes — safe only because `ExDiag.RootLayout` appends a `?v=<hash>` fingerprint (from `ExDiag.AssetPlug.asset_version/0`, a SHA-256 over all three served files, computed once per BEAM run and cached in `:persistent_term`) to each script URL. Don't drop the `?v=` query param from a script `src` without also loosening the cache header — otherwise a host upgrading `ex_diag` (or `phoenix`/`phoenix_live_view`) won't see the new JS in already-cached browsers for up to a year.
- `esbuild --minify` (identifier renaming, part of the combined `--minify` flag) corrupts `@plantuml/core`'s TeaVM-compiled output when bundling `priv/static/ex_diag/build/bundle.js`: the minifier's scope-hoisting renames collide with hand-written statement labels in that code, producing a bundle with a genuine JS syntax error (`Undefined label 'X'`) that fails to parse in the browser — so *every* hook silently fails to register, not just PlantUML's. Verify any rebuilt `bundle.js` with `node --input-type=module --check < bundle.js` before committing. `package.json`'s `build:js` script uses `--minify-whitespace` only (no `--minify-syntax`/`--minify-identifiers`) to avoid this.
