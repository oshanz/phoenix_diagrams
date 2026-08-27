defmodule ExDiag.AssetPlugTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  @opts ExDiag.AssetPlug.init([])

  test "serves phoenix.mjs with 200 and js content-type" do
    conn = conn(:get, "/phoenix.mjs") |> ExDiag.AssetPlug.call(@opts)

    assert conn.status == 200
    assert conn.resp_body == File.read!(Application.app_dir(:phoenix, "priv/static/phoenix.mjs"))
    assert get_resp_header(conn, "content-type") == ["text/javascript; charset=utf-8"]
  end

  test "serves phoenix_live_view.esm.js with 200 and js content-type" do
    conn = conn(:get, "/phoenix_live_view.esm.js") |> ExDiag.AssetPlug.call(@opts)

    assert conn.status == 200

    assert conn.resp_body ==
             File.read!(
               Application.app_dir(:phoenix_live_view, "priv/static/phoenix_live_view.esm.js")
             )

    assert get_resp_header(conn, "content-type") == ["text/javascript; charset=utf-8"]
  end

  test "serves bundle.js with 200 and js content-type" do
    conn = conn(:get, "/bundle.js") |> ExDiag.AssetPlug.call(@opts)

    assert conn.status == 200

    assert conn.resp_body ==
             File.read!(Path.join(:code.priv_dir(:ex_diag), "static/ex_diag/bundle.js"))

    assert get_resp_header(conn, "content-type") == ["text/javascript; charset=utf-8"]
  end

  test "sets a long-lived cache-control header" do
    conn = conn(:get, "/bundle.js") |> ExDiag.AssetPlug.call(@opts)

    assert [cache_control] = get_resp_header(conn, "cache-control")
    assert cache_control =~ "max-age="
  end

  test "404s an unknown path" do
    conn = conn(:get, "/nope.js") |> ExDiag.AssetPlug.call(@opts)

    assert conn.status == 404
  end

  test "404s a nested unknown path" do
    conn = conn(:get, "/sub/dir.js") |> ExDiag.AssetPlug.call(@opts)

    assert conn.status == 404
  end
end
