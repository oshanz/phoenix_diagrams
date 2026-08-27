defmodule ExDiag.RouterTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest
  import Plug.Conn

  @endpoint ExDiag.TestEndpoint

  test "GET /diagrams renders ExDiag.RootLayout, not the host default layout" do
    conn = get(build_conn(), "/diagrams")

    assert conn.status == 200
    assert conn.resp_body =~ "<!DOCTYPE html>"
    assert conn.resp_body =~ "/diagrams/ex-diag-assets/phoenix.mjs"
    assert conn.resp_body =~ "/diagrams/ex-diag-assets/phoenix_live_view.esm.js"
    assert conn.resp_body =~ "/diagrams/ex-diag-assets/bundle.js"
    assert conn.resp_body =~ "new LiveSocket(\"/live\", Socket"
    assert conn.resp_body =~ ~r{/ex-diag-assets/bundle\.js\?v=[\w-]+"}
  end

  test "the asset version fingerprint is stable across requests and asset URLs served through it still resolve" do
    conn1 = get(build_conn(), "/diagrams")
    conn2 = get(build_conn(), "/diagrams")

    [version1] = Regex.run(~r{bundle\.js\?v=([\w-]+)"}, conn1.resp_body, capture: :all_but_first)
    [version2] = Regex.run(~r{bundle\.js\?v=([\w-]+)"}, conn2.resp_body, capture: :all_but_first)
    assert version1 == version2

    conn3 = get(build_conn(), "/diagrams/ex-diag-assets/bundle.js?v=#{version1}")
    assert conn3.status == 200
  end

  test "two live_ex_diag mounts at different paths in one router don't collide on live_session" do
    conn1 = get(build_conn(), "/diagrams")
    conn2 = get(build_conn(), "/diagrams2")

    assert conn1.status == 200
    assert conn2.status == 200
    assert conn2.resp_body =~ "/diagrams2/ex-diag-assets/bundle.js"
  end

  test "GET /diagrams/ex-diag-assets/bundle.js is served by the forwarded AssetPlug" do
    conn = get(build_conn(), "/diagrams/ex-diag-assets/bundle.js")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/javascript; charset=utf-8"]
  end
end
