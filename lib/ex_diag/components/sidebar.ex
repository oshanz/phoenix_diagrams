defmodule ExDiag.Components.Sidebar do
  @moduledoc false

  use Phoenix.Component

  attr(:entries, :list, required: true)
  attr(:groups, :list, required: true)
  attr(:selected, :map, default: nil)
  attr(:diagrams_path, :string, required: true)

  def sidebar(assigns) do
    ~H"""
    <div class="drawer-side">
      <label for="ex-diag-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
      <nav aria-label="Diagrams" class="ex-diag-sidebar menu bg-base-200 min-h-full w-72 p-4 gap-1">
        <p :if={@entries == []} class="px-2 text-sm text-base-content/60">
          No diagrams found in {@diagrams_path}
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
    """
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
