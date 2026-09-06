defmodule PhoenixDiagrams.AssetPlug do
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
    build_files =
      build_dir()
      |> Path.join("*.js")
      |> Path.wildcard()
      |> Enum.sort()

    [
      Application.app_dir(:phoenix, "priv/static/phoenix.mjs"),
      Application.app_dir(:phoenix_live_view, "priv/static/phoenix_live_view.esm.js")
      | build_files
    ]
    |> Enum.map(&File.read!/1)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 10)
  end

  defp build_dir do
    Path.join(:code.priv_dir(:phoenix_diagrams), "static/phoenix_diagrams/build")
  end

  @impl true
  def call(%Plug.Conn{path_info: ["phoenix.mjs"]} = conn, _opts) do
    serve_app_file(conn, :phoenix, "priv/static/phoenix.mjs")
  end

  def call(%Plug.Conn{path_info: ["phoenix_live_view.esm.js"]} = conn, _opts) do
    serve_app_file(conn, :phoenix_live_view, "priv/static/phoenix_live_view.esm.js")
  end

  def call(%Plug.Conn{path_info: [file]} = conn, _opts) do
    case build_asset_path(file) do
      {:ok, path} -> serve_file(conn, path)
      :error -> send_resp(conn, 404, "Not Found")
    end
  end

  def call(conn, _opts) do
    send_resp(conn, 404, "Not Found")
  end

  # bundle.js plus its esbuild code-split chunks (e.g. chunk-<hash>.js), so
  # PhoenixDiagramsPlantuml's dynamic import() of the heavy @plantuml/core
  # module can be served without hardcoding every generated chunk name.
  defp build_asset_path(file) do
    if Regex.match?(~r/^[A-Za-z0-9_.-]+\.js$/, file) and not String.contains?(file, "..") do
      path = Path.join(build_dir(), file)
      if File.regular?(path), do: {:ok, path}, else: :error
    else
      :error
    end
  end

  defp serve_app_file(conn, app, relative_path) do
    path = Application.app_dir(app, relative_path)
    serve_file(conn, path)
  rescue
    _ -> send_resp(conn, 500, "PhoenixDiagrams asset unavailable")
  end

  defp serve_file(conn, path) do
    conn
    |> put_private(:plug_skip_csrf_protection, true)
    |> put_resp_content_type("text/javascript")
    |> put_resp_header("cache-control", @cache_control)
    |> send_resp(200, File.read!(path))
  rescue
    _ -> send_resp(conn, 500, "PhoenixDiagrams asset unavailable")
  end
end
