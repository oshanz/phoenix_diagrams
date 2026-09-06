defmodule PhoenixDiagrams.AssetPlugTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  @opts PhoenixDiagrams.AssetPlug.init([])

  test "serves phoenix.mjs with 200 and js content-type" do
    conn = conn(:get, "/phoenix.mjs") |> PhoenixDiagrams.AssetPlug.call(@opts)

    assert conn.status == 200
    assert conn.resp_body == File.read!(Application.app_dir(:phoenix, "priv/static/phoenix.mjs"))
    assert get_resp_header(conn, "content-type") == ["text/javascript"]
  end

  test "serves phoenix_live_view.esm.js with 200 and js content-type" do
    conn = conn(:get, "/phoenix_live_view.esm.js") |> PhoenixDiagrams.AssetPlug.call(@opts)

    assert conn.status == 200

    assert conn.resp_body ==
             File.read!(
               Application.app_dir(:phoenix_live_view, "priv/static/phoenix_live_view.esm.js")
             )

    assert get_resp_header(conn, "content-type") == ["text/javascript"]
  end

  test "serves bundle.js with 200 and js content-type" do
    conn = conn(:get, "/bundle.js") |> PhoenixDiagrams.AssetPlug.call(@opts)

    assert conn.status == 200

    assert conn.resp_body ==
             File.read!(
               Path.join(
                 :code.priv_dir(:phoenix_diagrams),
                 "static/phoenix_diagrams/build/bundle.js"
               )
             )

    assert get_resp_header(conn, "content-type") == ["text/javascript"]
  end

  test "serves mermaid.js with 200 and js content-type" do
    conn = conn(:get, "/mermaid.js") |> PhoenixDiagrams.AssetPlug.call(@opts)

    assert conn.status == 200

    assert conn.resp_body ==
             File.read!(
               Path.join(
                 :code.priv_dir(:phoenix_diagrams),
                 "static/phoenix_diagrams/build/mermaid.js"
               )
             )

    assert get_resp_header(conn, "content-type") == ["text/javascript"]
  end

  test "serves plantuml.js with 200 and js content-type" do
    conn = conn(:get, "/plantuml.js") |> PhoenixDiagrams.AssetPlug.call(@opts)

    assert conn.status == 200

    assert conn.resp_body ==
             File.read!(
               Path.join(
                 :code.priv_dir(:phoenix_diagrams),
                 "static/phoenix_diagrams/build/plantuml.js"
               )
             )

    assert get_resp_header(conn, "content-type") == ["text/javascript"]
  end

  test "sets a long-lived immutable cache-control header for a versioned request" do
    conn = conn(:get, "/bundle.js?vsn=abc123") |> PhoenixDiagrams.AssetPlug.call(@opts)

    assert [cache_control] = get_resp_header(conn, "cache-control")
    assert cache_control =~ "max-age="
    assert cache_control =~ "immutable"
  end

  test "sets a plain public cache-control header for an unversioned request" do
    conn = conn(:get, "/bundle.js") |> PhoenixDiagrams.AssetPlug.call(@opts)

    assert get_resp_header(conn, "cache-control") == ["public"]
  end

  test "404s an unknown path" do
    conn = conn(:get, "/nope.js") |> PhoenixDiagrams.AssetPlug.call(@opts)

    assert conn.status == 404
  end

  test "404s a nested unknown path" do
    conn = conn(:get, "/sub/dir.js") |> PhoenixDiagrams.AssetPlug.call(@opts)

    assert conn.status == 404
  end

  test "404s a path-traversal attempt" do
    conn = conn(:get, "/..") |> PhoenixDiagrams.AssetPlug.call(@opts)

    assert conn.status == 404
  end
end
