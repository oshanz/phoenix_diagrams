defmodule ExDiag.Router do
  @moduledoc """
  Router helpers for mounting the ExDiag diagram browser in a host
  Phoenix application.

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router
        import ExDiag.Router

        scope "/" do
          pipe_through :browser
          live_ex_diag "/diagrams", diagrams_path: "priv/diagrams"
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

  Requires a `:diagrams_path` option pointing at the directory of `.exs`
  diagram definitions to scan — there is no default.

      live_ex_diag "/diagrams", diagrams_path: "priv/diagrams"
  """
  defmacro live_ex_diag(path, opts) do
    diagrams_path =
      Keyword.get(opts, :diagrams_path) ||
        raise ArgumentError, "live_ex_diag/2 requires a :diagrams_path option"

    session_name = :"ex_diag_#{:erlang.phash2(path)}"

    quote bind_quoted: [
            path: path,
            session_name: session_name,
            diagrams_path: diagrams_path
          ] do
      require Phoenix.LiveView.Router
      alias Phoenix.LiveView.Router, as: LiveRouter

      scope path, alias: false do
        LiveRouter.live_session session_name,
          root_layout: {ExDiag.RootLayout, :root},
          session: %{"diagrams_path" => diagrams_path} do
          LiveRouter.live("/", ExDiag.DiagramLive, :index)
        end

        forward("/ex-diag-assets", ExDiag.AssetPlug)
      end
    end
  end
end
