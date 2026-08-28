defmodule PhoenixDiagrams.TestEndpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :phoenix_diagrams

  socket("/live", Phoenix.LiveView.Socket)

  plug(PhoenixDiagrams.TestRouter)
end
