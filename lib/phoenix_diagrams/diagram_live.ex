defmodule PhoenixDiagrams.DiagramLive do
  use Phoenix.LiveView

  alias PhoenixDiagrams.Loader

  @impl true
  def mount(_params, %{"diagrams_path" => diagrams_path}, socket) do
    entries = Loader.scan(diagrams_path)
    selected = Enum.find(entries, &(!Map.has_key?(&1, :error)))

    if connected?(socket), do: watch(diagrams_path)

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

  @impl true
  def handle_info({:file_event, _watcher_pid, {_path, _events}}, socket) do
    entries = Loader.scan(socket.assigns.diagrams_path)
    previous_key = socket.assigns.selected && socket.assigns.selected.key

    selected =
      Enum.find(entries, &(&1.key == previous_key)) ||
        Enum.find(entries, &(!Map.has_key?(&1, :error)))

    {:noreply,
     assign(socket, entries: entries, groups: group_entries(entries), selected: selected)}
  end

  def handle_info({:file_event, _watcher_pid, :stop}, socket), do: {:noreply, socket}

  # Dev-only live reload: `:file_system` is a `only: :dev` dependency, so it
  # (and this watcher) is compiled out of any release build entirely.
  if Code.ensure_loaded?(FileSystem) do
    defp watch(diagrams_path) do
      case FileSystem.start_link(dirs: [Path.expand(diagrams_path)]) do
        {:ok, pid} -> FileSystem.subscribe(pid)
        {:error, _reason} -> :ok
        :ignore -> :ok
      end
    end
  else
    defp watch(_diagrams_path), do: :ok
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
