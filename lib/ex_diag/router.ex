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
