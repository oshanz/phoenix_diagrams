# ExDiag JS asset packaging: own-root-layout design

Status: approved, not yet implemented
Date: 2026-08-27

## Context

ExDiag's design principle is "self-contained, zero host-asset coupling" — a
host app should not need to edit its own `app.css`/`app.js` for ExDiag to
render and function. CSS already meets this bar (`ExDiag.Components.Layout`
inlines the compiled `app.css` at render time). JS does not: today a host
must manually add three `import` lines into their own `app.js` pointing at
`priv/static/ex_diag/*.js` inside the `ex_diag` dependency, and merge four
hook names into their `LiveSocket`'s `hooks:` map. Worse, `mermaid_hook.js`
contains a bare `import mermaid from "mermaid"` that isn't actually
resolved by anything ExDiag ships — it only resolves today because the
`demo/` app's esbuild config sets `NODE_PATH` to reach into
`priv/static/ex_diag/node_modules`. This works for `demo/` (which sits
next to the library in this repo) but is not something a real Hex/path
dependency consumer could rely on without copying that same config trick.

This is a pre-release cleanup (no shipped consumers yet, no backward
compatibility constraint) to fix packaging before the first release.

## Goals

- A host app needs **zero** changes to its own `app.js`, `assets/`, or
  esbuild config to get a fully working ExDiag page — no imports, no hook
  registration, no `NODE_PATH` tricks.
- No host-side npm dependency on `mermaid` or `@plantuml/core`.
- No version-skew risk between ExDiag's LiveView JS client and the
  `phoenix_live_view` server version the host actually resolved.

## Non-goals

- Lazy-loading only the hook needed per diagram type (Mermaid vs
  PlantUML). Out of scope for this pass — one combined bundle for all
  hooks, always loaded, is acceptable for now.
- Preserving any shared host page chrome (nav bar, footer, etc.) on the
  ExDiag route. The diagram browser becomes a standalone page.
- Any change to the Loader, diagram file format, or the visual design of
  the diagram browser itself.

## Why "own root layout" instead of "inject a script tag into the host's layout"

A router-mounted LiveView (`live_ex_diag "/diagrams", []` compiles to a
normal `Phoenix.LiveView.Router.live/3` call) is rendered inside the
**host's own root layout** by default — the same `<html>`/`<head>`/`<body>`
wrapper every other page in the host app shares, already containing the
host's own `app.js` (with the host's own `phoenix`/`phoenix_live_view`
client and `LiveSocket`). Because it's the same document and the same
socket connection managing the whole page, there is no supported way to
register a LiveView hook into a `LiveSocket` the host has already
constructed, from content rendered *inside* that same page. The only way
to close that gap entirely is to stop sharing the host's root layout: give
`DiagramLive` **its own** root layout, with its own `<script type="module">`
that constructs its own `LiveSocket` from scratch. This was decided
interactively; the alternative (host adds one line merging
`window.ExDiagHooks` into their existing hooks map) was rejected in favor
of true zero-touch integration.

Committing to an own root layout has a direct consequence: the host's
`app.js` (and therefore the host's copy of the `phoenix`/`phoenix_live_view`
JS clients) never loads on this page at all. `DiagramLive` would render
once as static HTML and never connect, hooks or no hooks, unless ExDiag's
own root layout supplies a working `LiveSocket` bootstrap itself. So this
design necessarily takes on responsibility for bootstrapping the LiveView
connection, not just the diagram-rendering hooks.

## Avoiding LiveView client version skew

`phoenix_live_view` (and `phoenix`) are not npm-registry packages — their
JS clients ship inside their own Hex package's `priv/static/`, and are
normally referenced by a host's `app.js` via a relative path into
`deps/phoenix_live_view/priv/static/...`. LiveView enforces protocol
compatibility between its client and server; a vendored/bundled copy of
the client at a version ExDiag doesn't control would drift from whatever
`phoenix_live_view` version the host's `mix.exs` actually resolves (ExDiag
only requires `~> 1.2`, a range).

Confirmed in this repo's `deps/`: both packages already ship native ESM
builds suitable for browser `<script type="module">` import, independent
of any bundler:

- `deps/phoenix/priv/static/phoenix.mjs`
- `deps/phoenix_live_view/priv/static/phoenix_live_view.esm.js`

Because Elixir/OTP applications are global per running VM, code inside
ExDiag can call `Application.app_dir(:phoenix, "priv/static/phoenix.mjs")`
and `Application.app_dir(:phoenix_live_view, "priv/static/phoenix_live_view.esm.js")`
and always get back the file for **whichever version the host app actually
loaded** — not a version ExDiag bundles, pins, or has to keep releasing
against. Serving these two files directly, rather than vendoring or
bundling them, eliminates the version-skew risk structurally.

## Architecture

### 1. Asset-serving plug

New module `ExDiag.AssetPlug` (`lib/ex_diag/asset_plug.ex`), a small custom
`Plug` (not `Plug.Static`, since two of the three files it serves live
outside ExDiag's own `priv/`):

- `GET <mount>/ex-diag-assets/phoenix.mjs` → reads and serves
  `Application.app_dir(:phoenix, "priv/static/phoenix.mjs")`
- `GET <mount>/ex-diag-assets/phoenix_live_view.esm.js` → reads and serves
  `Application.app_dir(:phoenix_live_view, "priv/static/phoenix_live_view.esm.js")`
- `GET <mount>/ex-diag-assets/bundle.js` → serves ExDiag's own
  `priv/static/ex_diag/bundle.js` (see below)

Each response sets `content-type: text/javascript` and a long-lived
`cache-control` (these are versioned by the host's own dependency
resolution / ExDiag's own release, not user content, so aggressive caching
is safe). 404 for any other path. Read file contents once at plug-init
time isn't safe (host could recompile/upgrade deps without restarting the
BEAM only in rare hot-upgrade setups) — read from disk per-request, same
as `Plug.Static` does; this is a low-traffic internal tooling route, not a
perf-sensitive path.

### 2. `bundle.js` build pipeline

`priv/static/ex_diag/` gains a new entry point, `bundle_entry.js`, that
exports the four existing hooks (no change to `mermaid_hook.js`,
`plantuml_hook.js`, `download_hook.js`, or the theme hook's logic — only
how they're packaged):

```js
export {ExDiagMermaid, ExDiagTheme} from "./mermaid_hook";
export {ExDiagPlantuml} from "./plantuml_hook";
export {ExDiagDownload} from "./download_hook";
```

`package.json` gains `esbuild` as a devDependency and a new script:

```json
"build:js": "esbuild bundle_entry.js --bundle --format=esm --outfile=bundle.js --minify --external:url"
```

This bundles `mermaid` and `@plantuml/core` (and their transitive deps:
`cytoscape`, `dagre-d3-es`, `d3`, `katex`) fully into `bundle.js` — it must
resolve with no unbundled bare specifiers left over, since nothing will
run a bundler on it again downstream. `phoenix`/`phoenix_live_view` are
**not** inputs to this bundle — they're served separately per the plug
above, and `bundle_entry.js` never imports them.

`bundle.js` is a committed build artifact (same pattern as `app.css`
today): run `npm run build:js` after editing any hook source, commit the
output. `mix.exs`'s `package.files` list gains
`priv/static/ex_diag/bundle.js` alongside the existing `app.css`.

### 3. `ExDiag.RootLayout`

New module `lib/ex_diag/root_layout.ex`, a `Phoenix.Component` rendering a
full HTML document (not the inner drawer/sidebar markup — that stays in
`ExDiag.Components.Layout`, unchanged):

```elixir
defmodule ExDiag.RootLayout do
  @moduledoc false
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <title>{assigns[:page_title] || "Diagrams"}</title>
      </head>
      <body>
        {@inner_content}
        <script type="module">
          {Phoenix.HTML.raw(bootstrap_script(assigns))}
        </script>
      </body>
    </html>
    """
  end

  defp bootstrap_script(assigns) do
    base = String.trim_trailing(assigns.conn.request_path, "/")

    """
    import {Socket} from "#{base}/ex-diag-assets/phoenix.mjs";
    import {LiveSocket} from "#{base}/ex-diag-assets/phoenix_live_view.esm.js";
    import {ExDiagMermaid, ExDiagTheme, ExDiagPlantuml, ExDiagDownload} from "#{base}/ex-diag-assets/bundle.js";

    const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
    const liveSocket = new LiveSocket("/live", Socket, {
      params: {_csrf_token: csrfToken},
      hooks: {ExDiagMermaid, ExDiagTheme, ExDiagPlantuml, ExDiagDownload},
    });
    liveSocket.connect();
    """
  end
end
```

(Exact HEEx escaping mechanics for the inline `<script type="module">`
follow the existing `<style>`/raw-tag pattern already used in
`ExDiag.Components.Layout` — see the CLAUDE.md gotcha about verbatim
tags; this is not a new problem, just applied to a second tag type.)

The websocket path is left as `"/live"` — that's the LiveView socket
mount path, standard across the whole host app (see existing
`ExDiag.TestEndpoint`'s `socket("/live", Phoenix.LiveView.Socket)`); it is
independent of where the HTTP page itself is mounted and is not something
ExDiag needs to own or vary.

`page_title` is intentionally left as a simple optional assign for now,
not wired to anything — good enough for a standalone tooling page; can be
revisited later if desired.

### 4. Router macro changes

`live_ex_diag/2` in `lib/ex_diag/router.ex` changes from a plain `live/3`
call to:

```elixir
defmacro live_ex_diag(path, _opts \\ []) do
  session_name = :"ex_diag_#{:erlang.phash2(path)}"

  quote bind_quoted: [path: path, session_name: session_name] do
    require Phoenix.LiveView.Router
    alias Phoenix.LiveView.Router, as: LiveRouter

    scope path, alias: false do
      LiveRouter.live_session session_name, root_layout: {ExDiag.RootLayout, :root} do
        LiveRouter.live("/", ExDiag.DiagramLive, :index)
      end

      forward "/ex-diag-assets", ExDiag.AssetPlug
    end
  end
end
```

`session_name` is derived from `:erlang.phash2(path)` (computed at macro
expansion time, since `path` is a compile-time literal in normal usage) so
that mounting `live_ex_diag` at two different paths in the same router
doesn't collide on `live_session`'s uniqueness requirement. This is a
real scenario worth guarding even though today's docs only show a single
mount.

No change is needed to the pipeline the host wraps `live_ex_diag` in
(`pipe_through :browser` etc. in the router example) — CSRF protection,
session handling, etc. still come from the host's existing pipeline; only
the **root layout** is swapped, not the plug pipeline.

### 5. Removed/updated files

- `demo/config/config.exs`: remove the `NODE_PATH` esbuild env hack and
  the `--external:url` flag (no longer needed once the host never bundles
  `@plantuml/core` or `mermaid` itself).
- `demo/assets/js/app.js`: remove the three `ExDiag*` imports and the
  `hooks: {...}` merge — demo becomes a real example of a host needing
  zero ExDiag-specific JS.
- `lib/ex_diag/router.ex` moduledoc: rewrite the usage example to drop the
  `app.js` snippet entirely.
- CLAUDE.md gotchas: the colocated-hooks note and the `--external:url`
  note both become historical/no-op for the new integration path (the
  `--external:url` constraint still exists in principle for anyone who
  did bundle `@plantuml/core` themselves, but no host will anymore) —
  update during implementation, not as part of this spec.

## Request flow (happy path)

1. Browser requests `GET /diagrams`.
2. Host's router pipeline runs (session, CSRF, etc.), then
   `live_session :ex_diag_<hash>` renders `ExDiag.DiagramLive` inside
   `ExDiag.RootLayout.root/1` instead of the host's root layout.
3. The dead-render HTML includes the `<script type="module">` bootstrap
   inline.
4. Browser parses the document, executes the module script: fetches
   `phoenix.mjs`, `phoenix_live_view.esm.js`, and `bundle.js` from
   `/diagrams/ex-diag-assets/*` (served by `ExDiag.AssetPlug`, mounted
   relative to this specific `live_ex_diag` scope).
5. `phoenix.mjs`/`phoenix_live_view.esm.js` are byte-identical to what the
   host's own `deps/` folder contains for this app, because they're read
   from `Application.app_dir/2` at request time, not vendored.
6. Script constructs and connects a `LiveSocket` scoped to this page,
   with the four ExDiag hooks registered — the page finishes connecting
   and hooks fire normally.

## Error handling

- `ExDiag.AssetPlug` returns 404 for any path under `/ex-diag-assets/`
  other than the three known filenames — same "never crash the host"
  posture as the Loader.
- If `Application.app_dir/2` raises (e.g. `:phoenix_live_view` not
  loaded — shouldn't happen since it's a direct dependency, but a
  defensive read), the plug should catch and return 500 with a short
  plain-text body rather than crash the whole page render; this affects
  only the ExDiag route, never other host pages.

## Testing

- `test/support/ExDiag.TestRouter`/`TestEndpoint` need no structural
  change — `live_session`/custom `root_layout` are transparent to
  `Phoenix.LiveViewTest`'s `live/2` helper.
- New test coverage needed:
  - `ExDiag.AssetPlug` serves all three files with 200 + correct
    content-type, and 404s an unknown path, using a plain `Plug.Test`
    conn (no LiveView needed for this).
  - A `Phoenix.ConnTest` request to `GET /diagrams` renders
    `ExDiag.RootLayout` (assert on `<!DOCTYPE html>` and the presence of
    the module script / asset URLs) rather than the host's default root
    layout — regression guard for the whole point of this change.
  - Two `live_ex_diag` mounts at different paths in one router (extend
    `ExDiag.TestRouter` or add a second test router) to cover the
    `live_session` naming collision fix.
- `mix precommit` (format, compile --warnings-as-errors, credo --strict,
  test) remains the full local check; no new tooling is required to run
  it (the JS build step is a manual/release-time step like `build:css`
  already is, not part of `mix test`).

## Open questions for implementation time (not blocking spec approval)

- Exact HEEx interpolation mechanics for emitting the inline
  `<script type="module">` safely (the CLAUDE.md verbatim-tag gotcha
  applies) — a small implementation detail, not an architectural one.
- Whether `ExDiag.AssetPlug` should set `cache-control: public,
  max-age=...` and, if so, what value — low-stakes, decide during
  implementation.
