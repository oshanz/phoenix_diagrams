defmodule ExDiag.AssetPlug do
  @moduledoc false

  import Plug.Conn

  @behaviour Plug

  @cache_control "public, max-age=31536000, immutable"

  @impl true
  def init(opts), do: opts

  @doc false
  def asset_version do
    case :persistent_term.get({__MODULE__, :version}, nil) do
      nil ->
        version = compute_version()
        :persistent_term.put({__MODULE__, :version}, version)
        version

      version ->
        version
    end
  end

  defp compute_version do
    [
      Application.app_dir(:phoenix, "priv/static/phoenix.mjs"),
      Application.app_dir(:phoenix_live_view, "priv/static/phoenix_live_view.esm.js"),
      Path.join(:code.priv_dir(:ex_diag), "static/ex_diag/build/bundle.js")
    ]
    |> Enum.map(&File.read!/1)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 10)
  end

  @impl true
  def call(%Plug.Conn{path_info: ["phoenix.mjs"]} = conn, _opts) do
    serve_app_file(conn, :phoenix, "priv/static/phoenix.mjs")
  end

  def call(%Plug.Conn{path_info: ["phoenix_live_view.esm.js"]} = conn, _opts) do
    serve_app_file(conn, :phoenix_live_view, "priv/static/phoenix_live_view.esm.js")
  end

  def call(%Plug.Conn{path_info: ["bundle.js"]} = conn, _opts) do
    path = Path.join(:code.priv_dir(:ex_diag), "static/ex_diag/build/bundle.js")
    serve_file(conn, path)
  end

  def call(conn, _opts) do
    send_resp(conn, 404, "Not Found")
  end

  defp serve_app_file(conn, app, relative_path) do
    path = Application.app_dir(app, relative_path)
    serve_file(conn, path)
  rescue
    _ -> send_resp(conn, 500, "ExDiag asset unavailable")
  end

  defp serve_file(conn, path) do
    conn
    |> put_private(:plug_skip_csrf_protection, true)
    |> put_resp_content_type("text/javascript")
    |> put_resp_header("cache-control", @cache_control)
    |> send_resp(200, File.read!(path))
  rescue
    _ -> send_resp(conn, 500, "ExDiag asset unavailable")
  end
end
