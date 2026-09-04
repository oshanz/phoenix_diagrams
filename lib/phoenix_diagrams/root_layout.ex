defmodule PhoenixDiagrams.RootLayout do
  @moduledoc false

  use Phoenix.Component

  @logo_svg_path Path.join(__DIR__, "icons/logo.svg")
  @external_resource @logo_svg_path
  @favicon_href "data:image/svg+xml," <>
                  (@logo_svg_path
                   |> File.read!()
                   |> String.replace("currentColor", "#4f46e5")
                   |> URI.encode(&(&1 not in [?<, ?>, ?", ?#, ?%])))

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
        <link rel="icon" type="image/svg+xml" href={favicon_href()} />
        <title>{@page_title || "Diagrams"}</title>
      </head>
      <body>
        {@inner_content}
        {Phoenix.HTML.raw("<script type=\"module\">" <> bootstrap_script(@conn) <> "</script>")}
      </body>
    </html>
    """
  end

  defp favicon_href, do: @favicon_href

  defp bootstrap_script(conn) do
    base = String.trim_trailing(conn.request_path, "/")
    v = PhoenixDiagrams.AssetPlug.asset_version()

    """
    import {Socket} from "#{base}/phoenix-diagrams-assets/phoenix.mjs?v=#{v}";
    import {LiveSocket} from "#{base}/phoenix-diagrams-assets/phoenix_live_view.esm.js?v=#{v}";
    import {PhoenixDiagramsMermaid, PhoenixDiagramsTheme, PhoenixDiagramsPlantuml, PhoenixDiagramsDownload, PhoenixDiagramsCopy, PhoenixDiagramsShare, PhoenixDiagramsFullscreen, PhoenixDiagramsZoom, PhoenixDiagramsSidebar} from "#{base}/phoenix-diagrams-assets/bundle.js?v=#{v}";

    const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
    const liveSocket = new LiveSocket("/live", Socket, {
      params: {_csrf_token: csrfToken},
      hooks: {PhoenixDiagramsMermaid, PhoenixDiagramsTheme, PhoenixDiagramsPlantuml, PhoenixDiagramsDownload, PhoenixDiagramsCopy, PhoenixDiagramsShare, PhoenixDiagramsFullscreen, PhoenixDiagramsZoom, PhoenixDiagramsSidebar},
    });
    liveSocket.connect();
    """
  end
end
