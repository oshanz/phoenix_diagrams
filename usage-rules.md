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

### Wiring the JS hooks (required)

ExDiag's `priv/static/ex_diag/` ships the hook source files, but not their
`node_modules` (gitignored, not published) — the host app must add `mermaid`
and `@plantuml/core` as its own npm dependencies so its bundler can resolve
the bare `import mermaid from "mermaid"` / `import ... from "@plantuml/core"`
specifiers inside the hooks. Then import and register the two hooks from
`priv/static/ex_diag/`:

```js
import ExDiagMermaid from "../../deps/ex_diag/priv/static/ex_diag/mermaid_hook.js"
import ExDiagPlantuml from "../../deps/ex_diag/priv/static/ex_diag/plantuml_hook.js"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ExDiagMermaid, ExDiagPlantuml, ...otherHooks }
})
```

If the host app's esbuild bundles `@plantuml/core`'s TeaVM output, add
`--external:url` to the esbuild args — its UMD build has an unreachable
Node-only `require("url")` branch that esbuild otherwise tries to statically
resolve at build time. This never executes in the browser; it's a bundler
quirk, not a real runtime dependency.

### Styling

ExDiag inlines its own compiled daisyUI (light/dark) CSS at render time — the
host app does not need to add ExDiag's classes to its own Tailwind/daisyUI
build or content globs.
