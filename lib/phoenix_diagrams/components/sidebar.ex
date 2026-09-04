defmodule PhoenixDiagrams.Components.Sidebar do
  @moduledoc false

  use Phoenix.Component

  alias PhoenixDiagrams.Components.Icons

  attr(:entries, :list, required: true)
  attr(:groups, :list, required: true)
  attr(:selected, :any, default: nil)
  attr(:diagrams_path, :string, required: true)
  attr(:search, :string, default: "")

  def sidebar(assigns) do
    ~H"""
    <div class="drawer-side phoenix-diagrams-sidebar-side">
      <label for="phoenix-diagrams-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
      <nav
        id="phoenix-diagrams-sidebar"
        phx-hook="PhoenixDiagramsSidebar"
        aria-label="Diagrams"
        class="phoenix-diagrams-sidebar menu bg-base-200 min-h-full p-4 gap-1"
      >
        <div class="flex items-center gap-2 h-11 px-2">
          <Icons.logo class="h-5 w-5 shrink-0" />
          <span class="font-semibold">Diagrams</span>
        </div>
        <form
          :if={@entries != []}
          id="phoenix-diagrams-search-form"
          phx-change="search"
          class="px-2 pb-2"
        >
          <div class="relative">
            <input
              type="search"
              name="q"
              value={@search}
              placeholder="Search diagrams…"
              aria-label="Search diagrams"
              phx-debounce="300"
              class="input input-sm input-bordered w-full pr-8"
            />
            <button
              :if={@search != ""}
              type="button"
              phx-click="clear_search"
              aria-label="Clear search"
              class="absolute right-2 top-1/2 -translate-y-1/2 text-base-content/60 hover:text-base-content"
            >
              ✕
            </button>
          </div>
        </form>
        <p :if={@entries == []} class="px-2 text-sm text-base-content/60">
          No diagrams found in {@diagrams_path}
        </p>
        <p :if={@entries != [] && @groups == []} class="px-2 text-sm text-base-content/60">
          No diagrams match "{@search}"
        </p>
        <li :for={{group, group_entries} <- @groups}>
          <h2 class="menu-title">{group}</h2>
          <ul>
            <li :for={entry <- group_entries}>
              <button
                phx-click="select"
                phx-value-key={entry.key}
                aria-current={is_map(@selected) && @selected.key == entry.key && "true"}
                class={["min-w-0" | List.wrap(entry_class(entry, @selected))]}
              >
                <span
                  :if={Map.has_key?(entry, :error)}
                  class="badge badge-error badge-xs"
                  aria-hidden="true"
                ></span>
                <span :if={Map.has_key?(entry, :error)} class="sr-only">Error loading:</span>
                <span class="truncate">{entry[:name] || entry.file}</span>
              </button>
            </li>
          </ul>
        </li>
      </nav>
      <div class="phoenix-diagrams-sidebar-resizer" aria-hidden="true"></div>
    </div>
    """
  end

  defp entry_class(entry, selected) do
    active? = is_map(selected) && selected.key == entry.key

    [
      Map.has_key?(entry, :error) && "phoenix-diagrams-entry-error text-error",
      active? && "menu-active"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
  end
end
