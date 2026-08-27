defmodule ExDiag.Components.Layout do
  @moduledoc false

  use Phoenix.Component

  import ExDiag.Components.Navbar
  import ExDiag.Components.Detail
  import ExDiag.Components.Sidebar

  @ex_diag_css Path.join(:code.priv_dir(:ex_diag), "static/ex_diag/app.css") |> File.read!()
  @external_resource Path.join(:code.priv_dir(:ex_diag), "static/ex_diag/app.css")

  @initial_theme_script """
  (function () {
    var root = document.currentScript.parentElement;
    var stored = null;
    try {
      stored = window.localStorage.getItem("ex_diag_theme");
    } catch (e) {}
    var prefersDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
    root.dataset.theme = stored || (prefersDark ? "dark" : "light");
  })();
  """

  attr(:entries, :list, required: true)
  attr(:groups, :list, required: true)
  attr(:selected, :map, default: nil)
  attr(:diagrams_path, :string, required: true)

  def layout(assigns) do
    ~H"""
    {Phoenix.HTML.raw("<style>" <> ex_diag_css() <> "</style>")}
    <div id="ex-diag-root" phx-hook="ExDiagTheme" class="ex-diag-root drawer lg:drawer-open">
      {Phoenix.HTML.raw("<script>" <> initial_theme_script() <> "</script>")}
      <input id="ex-diag-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content flex flex-col">
        <.navbar />
        <p class="sr-only" role="status">
          {(@selected && (@selected[:name] || @selected.file)) || "No diagram selected"}
        </p>
        <.detail selected={@selected} />
      </div>
      <.sidebar entries={@entries} groups={@groups} selected={@selected} diagrams_path={@diagrams_path} />
    </div>
    """
  end

  defp ex_diag_css, do: @ex_diag_css
  defp initial_theme_script, do: @initial_theme_script
end
