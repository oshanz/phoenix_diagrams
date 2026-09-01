defmodule PhoenixDiagrams.Components.Layout do
  @moduledoc false

  use Phoenix.Component

  import PhoenixDiagrams.Components.Navbar
  import PhoenixDiagrams.Components.Detail
  import PhoenixDiagrams.Components.Sidebar

  @phoenix_diagrams_css Path.join(
                          :code.priv_dir(:phoenix_diagrams),
                          "static/phoenix_diagrams/build/app.css"
                        )
                        |> File.read!()
  @external_resource Path.join(
                       :code.priv_dir(:phoenix_diagrams),
                       "static/phoenix_diagrams/build/app.css"
                     )

  @initial_theme_script """
  (function () {
    var root = document.currentScript.parentElement;
    var stored = null;
    try {
      stored = window.localStorage.getItem("phoenix_diagrams_theme");
    } catch (e) {}
    var prefersDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
    root.dataset.theme = stored || (prefersDark ? "dark" : "light");

    var storedWidth = null;
    var storedCollapsed = null;
    try {
      storedWidth = window.localStorage.getItem("phoenix_diagrams_sidebar_width");
      storedCollapsed = window.localStorage.getItem("phoenix_diagrams_sidebar_collapsed");
    } catch (e) {}
    var width = parseInt(storedWidth, 10);
    if (!isFinite(width)) width = 288;
    width = Math.min(500, Math.max(200, width));
    root.style.setProperty("--phoenix-diagrams-sidebar-width", width + "px");
    root.dataset.sidebarCollapsed = storedCollapsed === "true" ? "true" : "false";
  })();
  """

  attr(:entries, :list, required: true)
  attr(:groups, :list, required: true)
  attr(:selected, :map, default: nil)
  attr(:diagrams_path, :string, required: true)

  def layout(assigns) do
    ~H"""
    {Phoenix.HTML.raw("<style>" <> phoenix_diagrams_css() <> "</style>")}
    <div
      id="phoenix-diagrams-root"
      phx-hook="PhoenixDiagramsTheme"
      class="phoenix-diagrams-root drawer lg:drawer-open h-screen overflow-hidden"
    >
      {Phoenix.HTML.raw("<script>" <> initial_theme_script() <> "</script>")}
      <input id="phoenix-diagrams-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content flex flex-col h-full min-h-0">
        <.navbar selected={@selected} />
        <p class="sr-only" role="status">
          {(@selected && (@selected[:name] || @selected.file)) || "No diagram selected"}
        </p>
        <.detail selected={@selected} />
      </div>
      <.sidebar entries={@entries} groups={@groups} selected={@selected} diagrams_path={@diagrams_path} />
    </div>
    """
  end

  defp phoenix_diagrams_css, do: @phoenix_diagrams_css
  defp initial_theme_script, do: @initial_theme_script
end
