defmodule ExDiag.TestRouter do
  @moduledoc false
  use Phoenix.Router
  import ExDiag.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  @diagrams_path Path.join(__DIR__, "fixtures/ex_diag/live_view")

  scope "/", TestRouterWeb do
    pipe_through(:browser)
    live_ex_diag("/diagrams", diagrams_path: @diagrams_path)
    live_ex_diag("/diagrams2", diagrams_path: @diagrams_path)
  end
end
