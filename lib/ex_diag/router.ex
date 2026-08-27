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

  ExDiag ships its own styles (inlined at render time, no host CSS required).
  Its Mermaid and PlantUML rendering hooks ship as static files and must be
  registered in your `app.js`:

      import {ExDiagMermaid, ExDiagTheme} from "ex_diag/priv/static/ex_diag/mermaid_hook"
      import {ExDiagPlantuml} from "ex_diag/priv/static/ex_diag/plantuml_hook"
      import {ExDiagDownload} from "ex_diag/priv/static/ex_diag/download_hook"

      let liveSocket = new LiveSocket("/live", Socket, {
        hooks: {...myHooks, ExDiagMermaid, ExDiagPlantuml, ExDiagTheme, ExDiagDownload}
      })

  The vendored PlantUML engine's Graphviz layout module falls back to a
  Node-only code path that references the `url` builtin; add
  `--external:url` to your `esbuild` args so bundling doesn't fail trying to
  resolve it (that branch never runs in the browser).
  """

  @doc """
  Mounts the ExDiag diagram browser LiveView at `path`.

  `opts` is currently unused and reserved for future per-mount
  configuration.
  """
  defmacro live_ex_diag(path, _opts \\ []) do
    quote bind_quoted: [path: path] do
      require Phoenix.LiveView.Router
      alias Phoenix.LiveView.Router, as: LiveRouter

      scope path, alias: false do
        LiveRouter.live("/", ExDiag.DiagramLive, :index)
      end
    end
  end
end
