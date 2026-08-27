defmodule ExDiag.RootLayout do
  @moduledoc false

  use Phoenix.Component

  attr(:page_title, :string, default: nil)
  attr(:conn, :map, required: true)
  attr(:inner_content, :any, required: true)

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <title>{@page_title || "Diagrams"}</title>
      </head>
      <body>
        {@inner_content}
        {Phoenix.HTML.raw("<script type=\"module\">" <> bootstrap_script(@conn) <> "</script>")}
      </body>
    </html>
    """
  end

  defp bootstrap_script(conn) do
    base = String.trim_trailing(conn.request_path, "/")
    v = ExDiag.AssetPlug.asset_version()

    """
    import {Socket} from "#{base}/ex-diag-assets/phoenix.mjs?v=#{v}";
    import {LiveSocket} from "#{base}/ex-diag-assets/phoenix_live_view.esm.js?v=#{v}";
    import {ExDiagMermaid, ExDiagTheme, ExDiagPlantuml, ExDiagDownload, ExDiagCopy} from "#{base}/ex-diag-assets/bundle.js?v=#{v}";

    const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
    const liveSocket = new LiveSocket("/live", Socket, {
      params: {_csrf_token: csrfToken},
      hooks: {ExDiagMermaid, ExDiagTheme, ExDiagPlantuml, ExDiagDownload, ExDiagCopy},
    });
    liveSocket.connect();
    """
  end
end
