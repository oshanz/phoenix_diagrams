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
    assert has_element?(view, ".drawer-side .menu")
    assert has_element?(view, "#ex-diag-drawer.drawer-toggle")
  end

  test "renders a theme toggle button in the navbar" do
    {:ok, view, _html} = live_isolated(build_conn(), ExDiag.DiagramLive)

    assert has_element?(view, "#ex-diag-theme-toggle[aria-pressed=false]")
    assert has_element?(view, "#ex-diag-root[phx-hook=ExDiagTheme]")
  end

  test "an error entry renders in the sidebar with its file name" do
    {:ok, view, _html} = live_isolated(build_conn(), ExDiag.DiagramLive)

    assert has_element?(view, ".ex-diag-entry-error, .badge-error")
  end

  test "clicking a diagram name selects it and renders the detail pane" do
    {:ok, view, _html} = live_isolated(build_conn(), ExDiag.DiagramLive)

    html =
      view
      |> element("button", "Auth Flow")
      |> render_click()

    assert has_element?(view, "#ex-diag-diagram-mermaid[phx-hook=ExDiagMermaid]")
    assert html =~ "graph TD"
  end

  test "clicking a plantuml diagram name renders the detail pane with the plantuml hook" do
    {:ok, view, _html} = live_isolated(build_conn(), ExDiag.DiagramLive)

    html =
      view
      |> element("button", "Login Sequence")
      |> render_click()

    assert has_element?(view, "#ex-diag-diagram-plantuml[phx-hook=ExDiagPlantuml]")
    assert html =~ "@startuml"
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
