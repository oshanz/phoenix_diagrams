defmodule ExDiag.DiagramLive do
  use Phoenix.LiveView

  alias ExDiag.Loader

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
    <div class="ex-diag-layout">
      <nav class="ex-diag-sidebar">
        <p :if={@entries == []}>No diagrams found in {diagrams_path()}</p>
        <div :for={{group, group_entries} <- @groups} class="ex-diag-group">
          <h3>{group}</h3>
          <ul>
            <li :for={entry <- group_entries}>
              <button
                phx-click="select"
                phx-value-key={entry.key}
                class={entry_class(entry, @selected)}
              >
                {entry[:name] || entry.file}
              </button>
            </li>
          </ul>
        </div>
      </nav>
      <main class="ex-diag-detail">
        <p :if={is_nil(@selected)}>Select a diagram from the sidebar.</p>
        <div :if={@selected && Map.has_key?(@selected, :error)} class="ex-diag-error">
          <p><strong>Error loading {@selected.file}:</strong></p>
          <p>{@selected.error}</p>
        </div>
        <div
          :if={@selected && !Map.has_key?(@selected, :error)}
          id="ex-diag-mermaid"
          phx-hook="ExDiagMermaid"
          phx-update="ignore"
          data-source={@selected.source}
        >
          <pre class="mermaid">{@selected.source}</pre>
        </div>
      </main>
    </div>
    """
  end

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
    base =
      if Map.has_key?(entry, :error),
        do: "ex-diag-entry ex-diag-entry-error",
        else: "ex-diag-entry"

    if selected && selected.key == entry.key, do: base <> " selected", else: base
  end
end
