defmodule PhoenixDiagrams.AssetPlug do
  @moduledoc false

  import Plug.Conn

  @behaviour Plug

  @phoenix_static Plug.Static.init(
                    at: "/",
                    from: {:phoenix, "priv/static"},
                    only: ["phoenix.mjs"]
                  )
  @phoenix_live_view_static Plug.Static.init(
                              at: "/",
                              from: {:phoenix_live_view, "priv/static"},
                              only: ["phoenix_live_view.esm.js"]
                            )
  @build_static Plug.Static.init(
                  at: "/",
                  from: {:phoenix_diagrams, "priv/static/phoenix_diagrams/build"},
                  only: ["bundle.js", "mermaid.js", "plantuml.js"]
                )

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
    serve(conn, @phoenix_static)
  end

  def call(%Plug.Conn{path_info: ["phoenix_live_view.esm.js"]} = conn, _opts) do
    serve(conn, @phoenix_live_view_static)
  end

  def call(conn, _opts) do
    serve(conn, @build_static)
  end

  # Plug.Static handles path-traversal safety, content-type lookup, and both
  # ETag and `?vsn=`-versioned cache-control - see RootLayout.bootstrap_script,
  # which appends `?vsn=<hash>` to these URLs so the versioned (long-lived,
  # immutable) cache path is used instead of the default ETag one. Each
  # config's `:only` list restricts it to exactly the file(s) it should ever
  # serve, so an unmatched or malicious path leaves the conn untouched
  # (state: :unset) rather than raising or falling through to the filesystem.
  defp serve(conn, static_opts) do
    conn
    |> put_private(:plug_skip_csrf_protection, true)
    |> Plug.Static.call(static_opts)
    |> reply_or_404()
  end

  defp reply_or_404(%Plug.Conn{state: :unset} = conn), do: send_resp(conn, 404, "Not Found")
  defp reply_or_404(conn), do: conn
end
