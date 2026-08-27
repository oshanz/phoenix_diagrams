defmodule ExDiag.DiagramLive do
  use Phoenix.LiveView

  alias ExDiag.Loader

  @impl true
  def mount(_params, %{"diagrams_path" => diagrams_path}, socket) do
    entries = Loader.scan(diagrams_path)
    selected = Enum.find(entries, &(!Map.has_key?(&1, :error)))

    {:ok,
     assign(socket,
       entries: entries,
       groups: group_entries(entries),
       selected: selected,
       diagrams_path: diagrams_path
     )}
  end

  @impl true
  def handle_event("select", %{"key" => key}, socket) do
    case Enum.find(socket.assigns.entries, &(&1.key == key)) do
      nil -> {:noreply, socket}
      entry -> {:noreply, assign(socket, :selected, entry)}
    end
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
end
