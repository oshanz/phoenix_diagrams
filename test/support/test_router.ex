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
  end
end
