defmodule PhoenixDiagrams.TestRouter do
  @moduledoc false
  use Phoenix.Router
  import PhoenixDiagrams.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  @diagrams_path Path.join(__DIR__, "fixtures/phoenix_diagrams/live_view")

  scope "/", TestRouterWeb do
    pipe_through(:browser)
    live_phoenix_diagrams("/diagrams", diagrams_path: @diagrams_path)
    live_phoenix_diagrams("/diagrams2", diagrams_path: @diagrams_path)
  end
end
