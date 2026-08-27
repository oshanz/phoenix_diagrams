## ExDiag usage

ExDiag embeds a Mermaid/PlantUML diagram browser into a host Phoenix app as a
mountable LiveView. It scans a directory of `.exs` metadata files, each
pointing at a `.mmd` or `.puml` source file, and renders them client-side.

### Mounting it

In the host app's router, inside a `scope`:

```elixir
import ExDiag.Router

scope "/" do
  pipe_through :browser
  live_ex_diag "/diagrams", []
end
```

This mounts `ExDiag.DiagramLive` at `GET /diagrams`.

### Diagram source directory

ExDiag scans `Application.get_env(:ex_diag, :diagrams_path, ...)`, defaulting
to `priv/ex_diag` under the host app's cwd. Configure it explicitly if using a
different location:

```elixir
config :ex_diag, diagrams_path: "priv/diagrams"
```

Each entry is a `.exs` file that `Code.eval_file`s into a keyword list:

```elixir
[
  group: "Auth",
  name: "Login flow",
  source: "login.mmd"
]
```

`:source` must resolve to a `.mmd` (Mermaid) or `.puml` (PlantUML) file
relative to the `.exs` file's directory — the extension determines the
diagram type. Any other extension, a missing key, an unreadable file, or an
eval error becomes an inline error entry in the UI instead of crashing the
host page — it will never take down the whole diagram browser or the host
app.

### JS and styling (zero host wiring)

`live_ex_diag` renders on its own standalone page: `ExDiag.DiagramLive` gets
its own root layout (`ExDiag.RootLayout`) instead of the host's, with an
inline `<script type="module">` that constructs and connects its own
`LiveSocket` — the host's own `app.js`/`LiveSocket` never loads on this page.
Because of that, the host needs **no changes at all** to `app.js`,
`assets/`, or its esbuild config, and **no** npm dependency on `mermaid` or
`@plantuml/core`:

- The rendering hooks (`ExDiagMermaid`, `ExDiagTheme`, `ExDiagPlantuml`,
  `ExDiagDownload`) ship pre-bundled in `priv/static/ex_diag/bundle.js` (built
  via `npm run build:js` in that directory) with `mermaid`/`@plantuml/core`
  fully inlined — nothing to resolve in the host's own `node_modules`.
- `phoenix.mjs`/`phoenix_live_view.esm.js` are served straight from
  `Application.app_dir/2` at request time — i.e. whichever
  `phoenix`/`phoenix_live_view` version the host app itself resolved, so
  there's no version-skew risk against a vendored copy.
- All three files are served by `ExDiag.AssetPlug`, forwarded under
  `<mount>/ex-diag-assets/*` by the `live_ex_diag` macro alongside the
  LiveView itself, with a `?v=<hash>` cache-busting fingerprint so a
  long-lived `cache-control: immutable` header is still safe across
  `ex_diag` upgrades.
- Styles are compiled into the library and inlined at render time — the host
  does not need to add ExDiag's classes to its own Tailwind/daisyUI build or
  content globs.

The websocket path is fixed at `/live`, matching the standard
`socket("/live", Phoenix.LiveView.Socket)` mount every Phoenix app already
has — independent of wherever `live_ex_diag` itself is mounted.
