defmodule PhoenixDiagrams.DiagramLiveTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  @endpoint PhoenixDiagrams.TestEndpoint
  @diagrams_path Path.join(__DIR__, "../support/fixtures/phoenix_diagrams/live_view")

  test "mount renders sidebar with groups and diagram names" do
    {:ok, view, html} = live(get(build_conn(), "/diagrams"))

    assert html =~ "Backend"
    assert html =~ "Auth Flow"
    assert has_element?(view, "button", "Auth Flow")
    assert has_element?(view, ".drawer-side .menu")
    assert has_element?(view, "#phoenix-diagrams-drawer.drawer-toggle")
  end

  test "renders a theme toggle button in the navbar" do
    {:ok, view, _html} = live(get(build_conn(), "/diagrams"))

    assert has_element?(view, "#phoenix-diagrams-theme-toggle[aria-pressed=false]")
    assert has_element?(view, "#phoenix-diagrams-root[phx-hook=PhoenixDiagramsTheme]")
  end

  test "an error entry renders in the sidebar with its file name" do
    {:ok, view, _html} = live(get(build_conn(), "/diagrams"))

    assert has_element?(view, ".phoenix-diagrams-entry-error, .badge-error")
  end

  test "clicking a diagram name selects it, patches the url, and renders the detail pane" do
    {:ok, view, _html} = live(get(build_conn(), "/diagrams"))

    html =
      view
      |> element("button", "Auth Flow")
      |> render_click()

    assert has_element?(
             view,
             "#phoenix-diagrams-diagram-mermaid[phx-hook=PhoenixDiagramsMermaid]"
           )

    assert html =~ "graph TD"

    assert has_element?(
             view,
             "#phoenix-diagrams-download[phx-hook=PhoenixDiagramsDownload][data-target='phoenix-diagrams-diagram-mermaid']"
           )

    assert has_element?(view, "#phoenix-diagrams-share[phx-hook=PhoenixDiagramsShare]")
    assert_patch(view, "/diagrams?d=" <> diagram_id("auth.exs"))
  end

  test "clicking a plantuml diagram name renders the detail pane with the plantuml hook" do
    {:ok, view, _html} = live(get(build_conn(), "/diagrams"))

    html =
      view
      |> element("button", "Login Sequence")
      |> render_click()

    assert has_element?(
             view,
             "#phoenix-diagrams-diagram-plantuml[phx-hook=PhoenixDiagramsPlantuml]"
           )

    assert html =~ "@startuml"
  end

  test "clicking an error entry shows its error message instead of a diagram" do
    {:ok, view, _html} = live(get(build_conn(), "/diagrams"))

    html =
      view
      |> element("button", "Broken One")
      |> render_click()

    assert html =~ "phoenix-diagrams-error"
    assert html =~ "missing required key :source"
  end

  test "live_phoenix_diagrams mounts the LiveView at the given path" do
    conn = get(build_conn(), "/diagrams")
    {:ok, _view, html} = live(conn)

    assert html =~ "Backend"
  end

  test "mounting with a ?d= param selects that diagram directly" do
    {:ok, view, html} = live(get(build_conn(), "/diagrams?d=#{diagram_id("login.exs")}"))

    assert html =~ "@startuml"

    assert has_element?(
             view,
             "#phoenix-diagrams-diagram-plantuml[phx-hook=PhoenixDiagramsPlantuml]"
           )
  end

  test "mounting with an unknown ?d= param shows a not-found state" do
    {:ok, _view, html} = live(get(build_conn(), "/diagrams?d=deadbeef"))

    assert html =~ "phoenix-diagrams-not-found"
    refute html =~ "graph TD"
  end

  defp diagram_id(relative_file) do
    entry = %{key: Path.join(@diagrams_path, relative_file)}
    PhoenixDiagrams.DiagramLive.diagram_id(entry, @diagrams_path)
  end
end
