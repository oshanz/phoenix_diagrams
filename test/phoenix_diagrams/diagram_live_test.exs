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

  test "does not render an app version when :app_version is not configured" do
    {:ok, view, _html} = live(get(build_conn(), "/diagrams"))

    refute has_element?(view, "span.opacity-60")
  end

  test "renders the configured app version in the navbar" do
    {:ok, _view, html} = live(get(build_conn(), "/diagrams-versioned"))

    assert html =~ "v1.2.3"
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
    assert_patch(view, "/diagrams?d=auth-flow-" <> diagram_id("auth.exs"))
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

  test "mounting with a slug-prefixed ?d= param still resolves the diagram" do
    {:ok, view, html} =
      live(get(build_conn(), "/diagrams?d=login-sequence-#{diagram_id("login.exs")}"))

    assert html =~ "@startuml"

    assert has_element?(
             view,
             "#phoenix-diagrams-diagram-plantuml[phx-hook=PhoenixDiagramsPlantuml]"
           )
  end

  test "clicking a diagram when app_version is configured appends v= to the patched url" do
    {:ok, view, _html} = live(get(build_conn(), "/diagrams-versioned"))

    view
    |> element("button", "Auth Flow")
    |> render_click()

    assert_patch(view, "/diagrams-versioned?d=auth-flow-" <> diagram_id("auth.exs") <> "&v=1.2.3")
  end

  test "a matching ?v= param shows no version mismatch notice" do
    {:ok, view, html} =
      live(
        get(
          build_conn(),
          "/diagrams-versioned?d=auth-flow-#{diagram_id("auth.exs")}&v=1.2.3"
        )
      )

    refute html =~ "phoenix-diagrams-version-notice"
  end

  test "a mismatched ?v= param shows a dismissible banner" do
    {:ok, view, html} =
      live(
        get(
          build_conn(),
          "/diagrams-versioned?d=auth-flow-#{diagram_id("auth.exs")}&v=0.9.0"
        )
      )

    assert html =~ "phoenix-diagrams-version-notice"

    html =
      view
      |> element("button[aria-label='Dismiss version notice']")
      |> render_click()

    refute html =~ "phoenix-diagrams-version-notice"
  end

  test "renders a search input in the sidebar" do
    {:ok, _view, html} = live(get(build_conn(), "/diagrams"))

    assert html =~ ~s(phx-change="search")
  end

  test "typing in the search box filters the diagram list by name" do
    {:ok, view, _html} = live(get(build_conn(), "/diagrams"))

    html =
      view
      |> form("#phoenix-diagrams-search-form", %{"q" => "Auth"})
      |> render_change()

    assert html =~ "Auth Flow"
    refute html =~ "Login Sequence"
  end

  test "an empty search shows all diagrams again" do
    {:ok, view, _html} = live(get(build_conn(), "/diagrams"))

    view
    |> form("#phoenix-diagrams-search-form", %{"q" => "Auth"})
    |> render_change()

    html =
      view
      |> form("#phoenix-diagrams-search-form", %{"q" => ""})
      |> render_change()

    assert html =~ "Auth Flow"
    assert html =~ "Login Sequence"
  end

  test "search matching nothing shows an empty-results message" do
    {:ok, view, _html} = live(get(build_conn(), "/diagrams"))

    html =
      view
      |> form("#phoenix-diagrams-search-form", %{"q" => "nonexistent-xyz"})
      |> render_change()

    assert html =~ "No diagrams match"
  end

  test "clicking the clear button resets the search and shows all diagrams" do
    {:ok, view, _html} = live(get(build_conn(), "/diagrams"))

    view
    |> form("#phoenix-diagrams-search-form", %{"q" => "Auth"})
    |> render_change()

    assert has_element?(view, "button[aria-label='Clear search']")

    html =
      view
      |> element("button[aria-label='Clear search']")
      |> render_click()

    assert html =~ "Auth Flow"
    assert html =~ "Login Sequence"
    refute has_element?(view, "button[aria-label='Clear search']")
  end

  defp diagram_id(relative_file) do
    entry = %{key: Path.join(@diagrams_path, relative_file)}
    PhoenixDiagrams.DiagramLive.diagram_id(entry, @diagrams_path)
  end
end
