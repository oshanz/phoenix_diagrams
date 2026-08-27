defmodule ExDiag.TestEndpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :ex_diag

  socket("/live", Phoenix.LiveView.Socket)

  plug(ExDiag.TestRouter)
end
