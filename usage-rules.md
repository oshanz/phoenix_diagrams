## ExDiag usage

ExDiag embeds a Mermaid/PlantUML diagram browser into a host Phoenix app as a
mountable LiveView. It scans a directory of `.exs` metadata files, each
pointing at a `.mmd` or `.puml` source file, and renders them client-side.

### Mounting it

```elixir
import ExDiag.Router

scope "/" do
  pipe_through :browser
  live_ex_diag "/diagrams", diagrams_path: "priv/diagrams"
end
```

Mounts `ExDiag.DiagramLive` at `GET /diagrams`.

### Diagram source directory

`:diagrams_path` is required — `live_ex_diag/2` raises `ArgumentError` at
compile time if it's missing. There is no default and no application config
fallback.

Each entry is a `.exs` file, `Code.eval_file`'d into a keyword list:

```elixir
[
  group: "Auth",
  name: "Login flow",
  source: "login.mmd"
]
```

`:source` resolves relative to the `.exs` file's directory; its extension
(`.mmd`/`.puml`) determines the diagram type. Any other extension, a missing
key, an unreadable file, or an eval error becomes an inline error entry
instead of crashing the host app.

### Zero host asset wiring

`live_ex_diag` renders on its own standalone page with its own root layout
and `LiveSocket` — the host's `app.js` never loads there. No changes to
`app.js`/`assets/`/esbuild config, and no npm dependency on `mermaid` or
`@plantuml/core`:

- Rendering hooks ship pre-bundled in `priv/static/ex_diag/build/bundle.js`
  with `mermaid`/`@plantuml/core` fully inlined.
- `phoenix.mjs`/`phoenix_live_view.esm.js` are served from the host's own
  resolved deps via `Application.app_dir/2` — no version skew.
- All three are served by `ExDiag.AssetPlug` under `<mount>/ex-diag-assets/*`
  with a `?v=<hash>` cache-busting fingerprint, safe for long-lived
  `cache-control: immutable`.
- Styles are compiled into the library and inlined at render time — no
  Tailwind/daisyUI content-glob changes needed on the host.

The websocket path is fixed at `/live`, matching the standard
`socket("/live", Phoenix.LiveView.Socket)` mount every Phoenix app already
has, independent of where `live_ex_diag` itself is mounted.
