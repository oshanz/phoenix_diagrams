## PhoenixDiagrams usage

Embeds a Mermaid/PlantUML diagram browser into a host Phoenix app as a mountable LiveView. It scans a directory of `.exs` metadata files, each pointing at a `.mmd`/`.puml` source file, and renders them client-side.

### Mounting it

```elixir
import PhoenixDiagrams.Router

scope "/" do
  pipe_through :browser
  live_phoenix_diagrams "/diagrams", diagrams_path: "priv/diagrams"
end
```

Mounts `PhoenixDiagrams.DiagramLive` at `GET /diagrams`. `:diagrams_path` is required — raises `ArgumentError` at compile time if missing, no default/app-config fallback.

### Diagram source directory

Each entry is a `.exs` file, `Code.eval_file`'d into a keyword list:

```elixir
[
  group: "Auth",
  name: "Login flow",
  source: "login.mmd"
]
```

`:source` resolves relative to the `.exs` file's directory; its extension (`.mmd`/`.puml`) determines the diagram type. Any other extension, a missing key, an unreadable file, or an eval error becomes an inline error entry instead of crashing the host app.

### Zero host asset wiring

`live_phoenix_diagrams` renders on its own standalone page with its own root layout and `LiveSocket` — the host's `app.js` never loads there. No changes to `app.js`/`assets/`/esbuild config, and no npm dependency on `mermaid` or `@plantuml/core`:

- Rendering hooks ship pre-bundled in `priv/static/phoenix_diagrams/build/bundle.js`, with `mermaid`/`@plantuml/core` fully inlined.
- `phoenix.mjs`/`phoenix_live_view.esm.js` are served from the host's own resolved deps via `Application.app_dir/2` — no version skew.
- All three are served by `PhoenixDiagrams.AssetPlug` under `<mount>/phoenix-diagrams-assets/*` with a `?v=<hash>` cache-busting fingerprint, safe for long-lived `cache-control: immutable`.
- Styles are compiled into the library and inlined at render time — no Tailwind/daisyUI content-glob changes needed on the host.

The websocket path is fixed at `/live`, matching the standard `socket("/live", Phoenix.LiveView.Socket)` mount every Phoenix app already has, independent of where `live_phoenix_diagrams` is mounted.
