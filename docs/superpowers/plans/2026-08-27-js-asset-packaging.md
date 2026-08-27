# ExDiag JS Asset Packaging (own-root-layout) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ExDiag's JS fully self-contained — host apps need zero `app.js`/esbuild changes — by giving `DiagramLive` its own root layout that bootstraps its own `LiveSocket`, serving `phoenix.mjs`/`phoenix_live_view.esm.js` straight from the host's resolved deps (no version skew), and bundling ExDiag's own hooks into one `bundle.js`.

**Architecture:** New `ExDiag.AssetPlug` serves three JS files (two proxied from `Application.app_dir/2`, one ExDiag's own esbuild bundle) under `<mount>/ex-diag-assets/*`. New `ExDiag.RootLayout` renders a full HTML document with an inline `<script type="module">` that imports those three files and constructs+connects a `LiveSocket`. `live_ex_diag/2` wraps the existing `live/3` call in a `live_session` using this root layout, keyed by a path hash to avoid `live_session` name collisions across multiple mounts, and forwards `/ex-diag-assets` to the plug.

**Tech Stack:** Elixir/Phoenix/Plug, Phoenix.LiveView, esbuild (new devDependency in `priv/static/ex_diag/package.json`), `Phoenix.ConnTest`/`Plug.Test` for the new tests.

**Spec:** `docs/superpowers/specs/2026-08-27-js-asset-packaging-design.md`

## Global Constraints

- Zero host-side `app.js`/`assets/`/esbuild changes required for a fully working ExDiag page (no imports, no hook registration, no `NODE_PATH` tricks).
- No host-side npm dependency on `mermaid` or `@plantuml/core`.
- `phoenix.mjs`/`phoenix_live_view.esm.js` must be served via `Application.app_dir/2` at request time (never vendored/bundled by ExDiag), so they are byte-identical to whatever version the host app resolved.
- No change to `Loader`, the diagram file format, or the visual design of the diagram browser (`ExDiag.Components.Layout` and children stay as-is).
- Lazy-loading per-diagram-type hooks is out of scope — one combined `bundle.js`, always loaded, is fine.
- Preserving host page chrome on the ExDiag route is explicitly out of scope — it becomes a standalone page via its own root layout.
- `mix precommit` (format, compile --warnings-as-errors, credo --strict, test) must keep passing; the JS build step (`npm run build:js`) is a manual/release-time step, not part of `mix test`.

---

## File Structure

- `lib/ex_diag/asset_plug.ex` (new) — `Plug` module serving the three JS files under `/ex-diag-assets/*`, 404 otherwise.
- `lib/ex_diag/root_layout.ex` (new) — `Phoenix.Component` rendering the standalone HTML document + LiveSocket bootstrap script.
- `lib/ex_diag/router.ex` (modify) — `live_ex_diag/2` macro grows a `live_session` (custom root layout) + `forward "/ex-diag-assets"`; moduledoc usage example drops the `app.js` snippet.
- `priv/static/ex_diag/bundle_entry.js` (new) — re-exports the four existing hooks, esbuild entry point.
- `priv/static/ex_diag/package.json` (modify) — add `esbuild` devDependency + `build:js` script.
- `priv/static/ex_diag/bundle.js` (new, committed build artifact) — output of `npm run build:js`.
- `mix.exs` (modify) — `package.files` gains `priv/static/ex_diag/bundle.js`.
- `test/ex_diag/asset_plug_test.exs` (new) — `Plug.Test`-based coverage of the plug.
- `test/ex_diag/router_test.exs` (new) — `Phoenix.ConnTest` coverage that `GET /diagrams` renders `ExDiag.RootLayout`, plus the two-mounts-one-router collision-guard test (via a second test router).
- `test/support/test_router2.ex` (new) — second router mounting `live_ex_diag` at a different path, for the collision test.
- `demo/config/config.exs` (modify) — remove the `NODE_PATH`/`--external:url` esbuild hack.
- `demo/assets/js/app.js` (modify) — remove the three `ExDiag*` imports and hook map merge.
- `CLAUDE.md` (modify) — update the colocated-hooks and `--external:url` gotchas to reflect the new integration path.

---

## Task 1: `bundle_entry.js` + esbuild `bundle.js` build pipeline

**Files:**
- Create: `priv/static/ex_diag/bundle_entry.js`
- Modify: `priv/static/ex_diag/package.json`
- Create (build artifact, committed): `priv/static/ex_diag/bundle.js`

**Interfaces:**
- Consumes: existing `priv/static/ex_diag/mermaid_hook.js` (exports `ExDiagMermaid`, `ExDiagTheme`), `plantuml_hook.js` (exports `ExDiagPlantuml`), `download_hook.js` (exports `ExDiagDownload`) — unchanged.
- Produces: `priv/static/ex_diag/bundle.js`, an ESM bundle exporting `ExDiagMermaid`, `ExDiagTheme`, `ExDiagPlantuml`, `ExDiagDownload` with `mermaid`/`@plantuml/core` fully inlined (no bare specifiers left unresolved). Task 2/3 import this by URL, not by name, so only the file's existence and its four export names matter to them.

- [ ] **Step 1: Verify existing hook exports**

Run: `grep -n "^export" priv/static/ex_diag/mermaid_hook.js priv/static/ex_diag/plantuml_hook.js priv/static/ex_diag/download_hook.js`
Expected: confirms `ExDiagMermaid`, `ExDiagTheme` from `mermaid_hook.js`; `ExDiagPlantuml` from `plantuml_hook.js`; `ExDiagDownload` from `download_hook.js`. If any name differs from this plan, use the actual name in Step 2 below.

- [ ] **Step 2: Write `bundle_entry.js`**

```js
export {ExDiagMermaid, ExDiagTheme} from "./mermaid_hook";
export {ExDiagPlantuml} from "./plantuml_hook";
export {ExDiagDownload} from "./download_hook";
```

- [ ] **Step 3: Add esbuild devDependency and `build:js` script to `package.json`**

Edit `priv/static/ex_diag/package.json` so it reads:

```json
{
  "scripts": {
    "build:css": "tailwindcss -i input.css -o app.css --minify",
    "build:js": "esbuild bundle_entry.js --bundle --format=esm --outfile=bundle.js --minify --external:url"
  },
  "dependencies": {
    "@plantuml/core": "^1.2026.7",
    "mermaid": "^11.17.2"
  },
  "devDependencies": {
    "@tailwindcss/cli": "^4.3.3",
    "daisyui": "^5.7.22",
    "esbuild": "^0.24.0",
    "tailwindcss": "^4.3.3"
  }
}
```

- [ ] **Step 4: Install and build**

Run (from `priv/static/ex_diag/`):
```bash
cd priv/static/ex_diag && npm install && npm run build:js
```
Expected: `bundle.js` is created in `priv/static/ex_diag/`, no unresolved bare-specifier errors from esbuild.

- [ ] **Step 5: Verify the bundle's exports and that no bare specifiers remain**

Run:
```bash
cd priv/static/ex_diag && grep -n "^export" bundle.js && grep -c "^import " bundle.js
```
Expected: the `export` line lists the four hook names; the `import` count is `0` (fully bundled — esbuild inlines everything into one file for a `--bundle` build with no external deps other than the explicitly-excluded `url`).

- [ ] **Step 6: Commit**

```bash
git add priv/static/ex_diag/bundle_entry.js priv/static/ex_diag/package.json priv/static/ex_diag/package-lock.json priv/static/ex_diag/bundle.js
git commit -m "add esbuild bundle.js pipeline for ExDiag JS hooks"
```

---

## Task 2: `ExDiag.AssetPlug`

**Files:**
- Create: `lib/ex_diag/asset_plug.ex`
- Test: `test/ex_diag/asset_plug_test.exs`

**Interfaces:**
- Consumes: `priv/static/ex_diag/bundle.js` from Task 1 (must exist on disk for the third route to serve real content in tests — if Task 1 hasn't been run in this checkout yet, this task's test for `bundle.js` should still pass against whatever `priv/static/ex_diag/bundle.js` contains, since the plug just streams the file).
- Produces: `ExDiag.AssetPlug`, a `Plug` (arity-2 `init/1` + `call/2`) that Task 3's router macro forwards to via `forward "/ex-diag-assets", ExDiag.AssetPlug`. Routes: `GET /phoenix.mjs`, `GET /phoenix_live_view.esm.js`, `GET /bundle.js` (paths *relative to the forward mount*, i.e. `conn.path_info`), 404 otherwise.

- [ ] **Step 1: Write the failing test file**

```elixir
defmodule ExDiag.AssetPlugTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  @opts ExDiag.AssetPlug.init([])

  test "serves phoenix.mjs with 200 and js content-type" do
    conn = conn(:get, "/phoenix.mjs") |> ExDiag.AssetPlug.call(@opts)

    assert conn.status == 200
    assert conn.resp_body == File.read!(Application.app_dir(:phoenix, "priv/static/phoenix.mjs"))
    assert get_resp_header(conn, "content-type") == ["text/javascript; charset=utf-8"]
  end

  test "serves phoenix_live_view.esm.js with 200 and js content-type" do
    conn = conn(:get, "/phoenix_live_view.esm.js") |> ExDiag.AssetPlug.call(@opts)

    assert conn.status == 200

    assert conn.resp_body ==
             File.read!(Application.app_dir(:phoenix_live_view, "priv/static/phoenix_live_view.esm.js"))

    assert get_resp_header(conn, "content-type") == ["text/javascript; charset=utf-8"]
  end

  test "serves bundle.js with 200 and js content-type" do
    conn = conn(:get, "/bundle.js") |> ExDiag.AssetPlug.call(@opts)

    assert conn.status == 200
    assert conn.resp_body == File.read!(Path.join(:code.priv_dir(:ex_diag), "static/ex_diag/bundle.js"))
    assert get_resp_header(conn, "content-type") == ["text/javascript; charset=utf-8"]
  end

  test "sets a long-lived cache-control header" do
    conn = conn(:get, "/bundle.js") |> ExDiag.AssetPlug.call(@opts)

    assert [cache_control] = get_resp_header(conn, "cache-control")
    assert cache_control =~ "max-age="
  end

  test "404s an unknown path" do
    conn = conn(:get, "/nope.js") |> ExDiag.AssetPlug.call(@opts)

    assert conn.status == 404
  end

  test "404s a nested unknown path" do
    conn = conn(:get, "/sub/dir.js") |> ExDiag.AssetPlug.call(@opts)

    assert conn.status == 404
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_diag/asset_plug_test.exs`
Expected: FAIL — `ExDiag.AssetPlug` is undefined.

- [ ] **Step 3: Write `lib/ex_diag/asset_plug.ex`**

```elixir
defmodule ExDiag.AssetPlug do
  @moduledoc false

  import Plug.Conn

  @behaviour Plug

  @cache_control "public, max-age=31536000, immutable"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{path_info: ["phoenix.mjs"]} = conn, _opts) do
    serve_app_file(conn, :phoenix, "priv/static/phoenix.mjs")
  end

  def call(%Plug.Conn{path_info: ["phoenix_live_view.esm.js"]} = conn, _opts) do
    serve_app_file(conn, :phoenix_live_view, "priv/static/phoenix_live_view.esm.js")
  end

  def call(%Plug.Conn{path_info: ["bundle.js"]} = conn, _opts) do
    path = Path.join(:code.priv_dir(:ex_diag), "static/ex_diag/bundle.js")
    serve_file(conn, path)
  end

  def call(conn, _opts) do
    send_resp(conn, 404, "Not Found")
  end

  defp serve_app_file(conn, app, relative_path) do
    path = Application.app_dir(app, relative_path)
    serve_file(conn, path)
  rescue
    _ -> send_resp(conn, 500, "ExDiag asset unavailable")
  end

  defp serve_file(conn, path) do
    conn
    |> put_resp_content_type("text/javascript")
    |> put_resp_header("cache-control", @cache_control)
    |> send_resp(200, File.read!(path))
  rescue
    _ -> send_resp(conn, 500, "ExDiag asset unavailable")
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ex_diag/asset_plug_test.exs`
Expected: PASS (all 6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ex_diag/asset_plug.ex test/ex_diag/asset_plug_test.exs
git commit -m "add ExDiag.AssetPlug to serve LiveView JS assets with no version skew"
```

---

## Task 3: `ExDiag.RootLayout`

**Files:**
- Create: `lib/ex_diag/root_layout.ex`

**Interfaces:**
- Consumes: nothing from earlier tasks at compile time (it references `/ex-diag-assets/*` paths that Task 4's router macro will make resolvable at request time — the script URLs are computed from `assigns.conn.request_path`, which is not itself an interface dependency, just a runtime value LiveView's `root_layout` rendering always supplies).
- Produces: `ExDiag.RootLayout.root/1`, a function component (module `ExDiag.RootLayout`, function `:root`) that Task 4's `live_session root_layout: {ExDiag.RootLayout, :root}` references by this exact `{module, function}` pair.

- [ ] **Step 1: Write `lib/ex_diag/root_layout.ex`**

```elixir
defmodule ExDiag.RootLayout do
  @moduledoc false

  use Phoenix.Component

  attr(:page_title, :string, default: nil)
  attr(:conn, :map, required: true)
  attr(:inner_content, :any, required: true)

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <title>{@page_title || "Diagrams"}</title>
      </head>
      <body>
        {@inner_content}
        {Phoenix.HTML.raw("<script type=\"module\">" <> bootstrap_script(@conn) <> "</script>")}
      </body>
    </html>
    """
  end

  defp bootstrap_script(conn) do
    base = String.trim_trailing(conn.request_path, "/")

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

Note on assigns: Phoenix.LiveView's root-layout rendering passes `@inner_content`, `@conn` (the plug conn for the dead render), and any assigns forwarded via `live_session`'s layout mechanism automatically — no special wiring needed here beyond declaring the `attr`s used.

- [ ] **Step 2: Compile to catch HEEx/escaping errors early**

Run: `mix compile --warnings-as-errors`
Expected: compiles clean. (Functional verification of the rendered output happens in Task 4's router test, since `RootLayout` needs a real `live_session` mount to exercise via `Phoenix.ConnTest`.)

- [ ] **Step 3: Commit**

```bash
git add lib/ex_diag/root_layout.ex
git commit -m "add ExDiag.RootLayout for standalone LiveSocket bootstrap"
```

---

## Task 4: Router macro changes + collision-guard test + `GET /diagrams` root-layout regression test

**Files:**
- Modify: `lib/ex_diag/router.ex`
- Create: `test/support/test_router2.ex`
- Modify: `test/support/test_endpoint.ex` (mount both routers, or add a second endpoint — see Step 1)
- Create: `test/ex_diag/router_test.exs`

**Interfaces:**
- Consumes: `ExDiag.RootLayout.root/1` (Task 3), `ExDiag.AssetPlug` (Task 2).
- Produces: updated `live_ex_diag/2` macro behavior — any router using it now gets a `live_session ex_diag_<hash>` with the custom root layout, plus a `forward "/ex-diag-assets"` mounted under the same scope path. No new public functions; this is the integration point other tasks assume works.

- [ ] **Step 1: Decide the collision-test router setup**

`Phoenix.LiveViewTest.live/2` requires a conn already routed through a router+endpoint. The existing `ExDiag.TestEndpoint` plugs `ExDiag.TestRouter` directly, so it can't also plug a second router on the same port/path without conflicting. Add a *second* route to the *existing* `ExDiag.TestRouter` instead — this directly exercises "two `live_ex_diag` mounts at different paths in one router" per the spec, without needing a second endpoint.

Modify `test/support/test_router.ex`:

```elixir
defmodule ExDiag.TestRouter do
  @moduledoc false
  use Phoenix.Router
  import ExDiag.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  scope "/", TestRouterWeb do
    pipe_through(:browser)
    live_ex_diag("/diagrams", [])
    live_ex_diag("/diagrams2", [])
  end
end
```

- [ ] **Step 2: Write the failing router test**

```elixir
defmodule ExDiag.RouterTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  @endpoint ExDiag.TestEndpoint

  test "GET /diagrams renders ExDiag.RootLayout, not the host default layout" do
    conn = get(build_conn(), "/diagrams")

    assert conn.status == 200
    assert conn.resp_body =~ "<!DOCTYPE html>"
    assert conn.resp_body =~ "/diagrams/ex-diag-assets/phoenix.mjs"
    assert conn.resp_body =~ "/diagrams/ex-diag-assets/phoenix_live_view.esm.js"
    assert conn.resp_body =~ "/diagrams/ex-diag-assets/bundle.js"
    assert conn.resp_body =~ "new LiveSocket(\"/live\", Socket"
  end

  test "two live_ex_diag mounts at different paths in one router don't collide on live_session" do
    conn1 = get(build_conn(), "/diagrams")
    conn2 = get(build_conn(), "/diagrams2")

    assert conn1.status == 200
    assert conn2.status == 200
    assert conn2.resp_body =~ "/diagrams2/ex-diag-assets/bundle.js"
  end

  test "GET /diagrams/ex-diag-assets/bundle.js is served by the forwarded AssetPlug" do
    conn = get(build_conn(), "/diagrams/ex-diag-assets/bundle.js")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/javascript; charset=utf-8"]
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `mix test test/ex_diag/router_test.exs`
Expected: FAIL — either a compile error (macro not yet updated so `/diagrams2` conflicts aren't the issue, but the assertions on `<!DOCTYPE html>`/asset URLs/`LiveSocket` fail because the current root layout is the plain LiveView dead-render, not `ExDiag.RootLayout`), or `live_session` duplicate-name errors once Step 1's second route is present without Step 4's per-path hashing.

- [ ] **Step 4: Update `lib/ex_diag/router.ex`**

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

  ExDiag renders on its own standalone page — it needs no changes to your
  `app.js`, `assets/`, or esbuild config. Its LiveView client JS, Mermaid
  and PlantUML rendering hooks are all served and bootstrapped
  automatically via a dedicated root layout and asset route mounted
  alongside the LiveView.
  """

  @doc """
  Mounts the ExDiag diagram browser LiveView at `path`.

  `opts` is currently unused and reserved for future per-mount
  configuration.
  """
  defmacro live_ex_diag(path, _opts \\ []) do
    session_name = :"ex_diag_#{:erlang.phash2(path)}"

    quote bind_quoted: [path: path, session_name: session_name] do
      require Phoenix.LiveView.Router
      alias Phoenix.LiveView.Router, as: LiveRouter

      scope path, alias: false do
        LiveRouter.live_session session_name, root_layout: {ExDiag.RootLayout, :root} do
          LiveRouter.live("/", ExDiag.DiagramLive, :index)
        end

        forward("/ex-diag-assets", ExDiag.AssetPlug)
      end
    end
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/ex_diag/router_test.exs`
Expected: PASS (all 3 tests).

- [ ] **Step 6: Run the full existing LiveView test suite to check for regressions**

Run: `mix test test/ex_diag/diagram_live_test.exs`
Expected: PASS unchanged — `live_isolated/2` (used by that file) doesn't route through the router/root-layout, so it's unaffected by this change.

- [ ] **Step 7: Run full suite**

Run: `mix test`
Expected: PASS, all tests green.

- [ ] **Step 8: Commit**

```bash
git add lib/ex_diag/router.ex test/support/test_router.ex test/ex_diag/router_test.exs
git commit -m "wire live_ex_diag to ExDiag.RootLayout and ExDiag.AssetPlug"
```

---

## Task 5: `mix.exs` packaging, demo cleanup, and CLAUDE.md gotcha updates

**Files:**
- Modify: `mix.exs`
- Modify: `demo/config/config.exs`
- Modify: `demo/assets/js/app.js`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: `priv/static/ex_diag/bundle.js` (Task 1) must exist for `mix.exs`'s `package.files` entry to be meaningful.
- Produces: nothing consumed by later tasks — this is the final cleanup task.

- [ ] **Step 1: Add `bundle.js` to `mix.exs` package files**

In `mix.exs`, `defp package do ... files: ~w(...)`, add the new line after the existing `priv/static/ex_diag/app.css` entry:

```elixir
      files: ~w(
        lib
        mix.exs
        README.md
        LICENSE
        usage-rules.md
        .formatter.exs
        priv/static/ex_diag/app.css
        priv/static/ex_diag/bundle.js
        priv/static/ex_diag/mermaid_hook.js
        priv/static/ex_diag/plantuml_hook.js
        priv/static/ex_diag/download_hook.js
      )
```

- [ ] **Step 2: Read `demo/config/config.exs` and remove the `NODE_PATH`/`--external:url` esbuild hack**

Run: `grep -n "NODE_PATH\|external:url\|esbuild" demo/config/config.exs`

Read the matched lines with the Read tool, then remove the `NODE_PATH` env entry and the `--external:url` arg from the esbuild config block for the `default` (or relevant) profile — leave the rest of that esbuild config (entry point, other args) untouched.

- [ ] **Step 3: Read `demo/assets/js/app.js` and remove the ExDiag imports/hook merge**

Run: `grep -n "ExDiag" demo/assets/js/app.js`

Read the matched region, then delete the three `import {ExDiag...}` lines and remove `ExDiagMermaid`, `ExDiagPlantuml`, `ExDiagTheme`, `ExDiagDownload` from the `hooks: {...}` object passed to `LiveSocket` (leave any of the demo app's own hooks in that object untouched).

- [ ] **Step 4: Manually verify the demo app still boots and the diagram browser works standalone**

Check for a port conflict first, then start the demo server:
```bash
ss -tlnp | grep 4000 || true
cd demo && mix phx.server
```
In a browser, visit `http://localhost:4000/diagrams` (or whatever path the demo mounts it at — check `demo/lib/*_web/router.ex` for the actual mount path first) and confirm: the page loads, the sidebar/detail panes render, a Mermaid diagram renders its SVG, clicking the theme toggle switches themes, and downloading a diagram image works. Then stop the server.

- [ ] **Step 5: Update CLAUDE.md gotchas**

Read `CLAUDE.md`'s "Gotchas" section. Update:
- The colocated-hooks gotcha bullet: append a note that this is now moot for host integration since hooks ship pre-bundled in `bundle.js` served by `ExDiag.AssetPlug` — no host `node_modules` resolution is ever needed.
- The `--external:url` gotcha bullet: append a note that this now only applies to ExDiag's own `npm run build:js` (already set via the `package.json` script from Task 1), not to any host app, since hosts no longer bundle `@plantuml/core` themselves.

- [ ] **Step 6: Run full precommit check**

Run: `mix precommit`
Expected: format/compile/credo/test all pass.

- [ ] **Step 7: Commit**

```bash
git add mix.exs demo/config/config.exs demo/assets/js/app.js CLAUDE.md
git commit -m "package bundle.js and drop host-side ExDiag JS wiring from demo"
```

---

## Self-Review Notes

- Spec coverage: asset plug (Task 2), bundle.js pipeline (Task 1), RootLayout (Task 3), router macro + live_session collision guard (Task 4), mix.exs/demo/CLAUDE.md cleanup (Task 5), asset-plug tests + root-layout regression test + collision test (Tasks 2 & 4) — all spec sections covered. Open questions from the spec (HEEx escaping mechanics, cache-control value) are resolved concretely in Task 3/Task 2 rather than left open.
- No placeholders: every step has literal code/commands.
- Type/name consistency checked: `ExDiag.RootLayout.root/1` referenced identically in Task 3 and Task 4's `live_session` call; `ExDiag.AssetPlug` module name and route paths (`phoenix.mjs`, `phoenix_live_view.esm.js`, `bundle.js`) consistent across Tasks 2–4; hook export names (`ExDiagMermaid`, `ExDiagTheme`, `ExDiagPlantuml`, `ExDiagDownload`) consistent across Tasks 1, 3, and the existing hook files.
