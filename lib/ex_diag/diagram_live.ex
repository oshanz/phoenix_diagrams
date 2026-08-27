defmodule ExDiag.DiagramLive do
  use Phoenix.LiveView

  alias ExDiag.Loader

  @ex_diag_css Path.join(:code.priv_dir(:ex_diag), "static/ex_diag/app.css") |> File.read!()
  @external_resource Path.join(:code.priv_dir(:ex_diag), "static/ex_diag/app.css")

  @impl true
  def mount(_params, _session, socket) do
    entries = Loader.scan(diagrams_path())
    {:ok, assign(socket, entries: entries, groups: group_entries(entries), selected: nil)}
  end

  @impl true
  def handle_event("select", %{"key" => key}, socket) do
    case Enum.find(socket.assigns.entries, &(&1.key == key)) do
      nil -> {:noreply, socket}
      entry -> {:noreply, assign(socket, :selected, entry)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    {Phoenix.HTML.raw("<style>" <> ex_diag_css() <> "</style>")}
    <div id="ex-diag-root" phx-hook="ExDiagTheme" class="ex-diag-root drawer lg:drawer-open">
      <input id="ex-diag-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content flex flex-col">
        <div class="navbar bg-base-200">
          <div class="flex-1 flex items-center">
            <label
              for="ex-diag-drawer"
              aria-label="open sidebar"
              class="btn btn-square btn-ghost drawer-button lg:hidden"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </label>
            <span class="ml-2 font-semibold">Diagrams</span>
          </div>
          <div class="flex-none">
            <button
              id="ex-diag-theme-toggle"
              type="button"
              class="btn btn-square btn-ghost"
              aria-label="Toggle color theme"
              aria-pressed="false"
            >
              <svg
                class="ex-diag-theme-icon-light h-5 w-5"
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"
                />
              </svg>
              <svg
                class="ex-diag-theme-icon-dark h-5 w-5 hidden"
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"
                />
              </svg>
            </button>
          </div>
        </div>
        <p class="sr-only" role="status">
          {(@selected && (@selected[:name] || @selected.file)) || "No diagram selected"}
        </p>
        <main class="ex-diag-detail flex-1 overflow-auto p-6">
          <div :if={is_nil(@selected)} class="hero min-h-[50vh]">
            <div class="hero-content text-center">
              <p class="text-base-content/60">Select a diagram from the sidebar.</p>
            </div>
          </div>
          <div
            :if={@selected && Map.has_key?(@selected, :error)}
            role="alert"
            class="ex-diag-error alert alert-error"
          >
            <span><strong>Error loading {@selected.file}:</strong> {@selected.error}</span>
          </div>
          <div
            :if={@selected && !Map.has_key?(@selected, :error)}
            class="card bg-base-100 shadow-sm border border-base-300"
          >
            <div class="card-body">
              <h2 class="card-title">{@selected[:name] || @selected.file}</h2>
              <div
                id="ex-diag-diagram"
                phx-hook={diagram_hook(@selected)}
                phx-update="ignore"
                role="img"
                aria-label={"Diagram: " <> (@selected[:name] || @selected.file)}
                data-source={@selected.source}
              >
                <pre class="mermaid">{@selected.source}</pre>
              </div>
            </div>
          </div>
        </main>
      </div>
      <div class="drawer-side">
        <label for="ex-diag-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <nav aria-label="Diagrams" class="ex-diag-sidebar menu bg-base-200 min-h-full w-72 p-4 gap-1">
          <p :if={@entries == []} class="px-2 text-sm text-base-content/60">
            No diagrams found in {diagrams_path()}
          </p>
          <li :for={{group, group_entries} <- @groups}>
            <h2 class="menu-title">{group}</h2>
            <ul>
              <li :for={entry <- group_entries}>
                <button
                  phx-click="select"
                  phx-value-key={entry.key}
                  aria-current={@selected && @selected.key == entry.key && "true"}
                  class={entry_class(entry, @selected)}
                >
                  <span
                    :if={Map.has_key?(entry, :error)}
                    class="badge badge-error badge-xs"
                    aria-hidden="true"
                  ></span>
                  <span :if={Map.has_key?(entry, :error)} class="sr-only">Error loading:</span>
                  {entry[:name] || entry.file}
                </button>
              </li>
            </ul>
          </li>
        </nav>
      </div>
    </div>
    """
  end

  defp diagram_hook(%{type: :plantuml}), do: "ExDiagPlantuml"
  defp diagram_hook(_selected), do: "ExDiagMermaid"

  defp ex_diag_css, do: @ex_diag_css

  defp diagrams_path do
    Application.get_env(:ex_diag, :diagrams_path, Path.join(File.cwd!(), "priv/ex_diag"))
  end

  defp group_entries(entries) do
    entries
    |> Enum.reduce({[], %{}}, fn entry, {order, groups} ->
      group = entry[:group] || "Errors"

      if Map.has_key?(groups, group) do
        {order, Map.update!(groups, group, &(&1 ++ [entry]))}
      else
        {order ++ [group], Map.put(groups, group, [entry])}
      end
    end)
    |> then(fn {order, groups} -> Enum.map(order, &{&1, Map.fetch!(groups, &1)}) end)
  end

  defp entry_class(entry, selected) do
    active? = selected && selected.key == entry.key

    [
      Map.has_key?(entry, :error) && "ex-diag-entry-error text-error",
      active? && "menu-active"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
  end
end
