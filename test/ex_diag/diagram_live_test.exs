defmodule ExDiag.DiagramLiveTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  @endpoint ExDiag.TestEndpoint

  test "mount renders sidebar with groups and diagram names" do
    {:ok, view, html} = live_isolated(build_conn(), ExDiag.DiagramLive)

    assert html =~ "Backend"
    assert html =~ "Auth Flow"
    assert has_element?(view, "button", "Auth Flow")
  end

  test "an error entry renders in the sidebar with its file name" do
    {:ok, view, _html} = live_isolated(build_conn(), ExDiag.DiagramLive)

    assert has_element?(view, ".ex-diag-entry-error")
  end

  test "clicking a diagram name selects it and renders the detail pane" do
    {:ok, view, _html} = live_isolated(build_conn(), ExDiag.DiagramLive)

    html =
      view
      |> element("button", "Auth Flow")
      |> render_click()

    assert html =~ "ex-diag-mermaid"
    assert html =~ "graph TD"
  end

  test "clicking an error entry shows its error message instead of a diagram" do
    {:ok, view, _html} = live_isolated(build_conn(), ExDiag.DiagramLive)

    html =
      view
      |> element("button", "Broken One")
      |> render_click()

    assert html =~ "ex-diag-error"
    assert html =~ "missing required key :source"
  end

  test "live_ex_diag mounts the LiveView at the given path" do
    conn = get(build_conn(), "/diagrams")
    {:ok, _view, html} = live(conn)

    assert html =~ "Backend"
  end
end
