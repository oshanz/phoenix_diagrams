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
