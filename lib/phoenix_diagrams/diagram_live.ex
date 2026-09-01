defmodule PhoenixDiagrams.DiagramLive do
  use Phoenix.LiveView

  alias PhoenixDiagrams.Loader

  @impl true
  def mount(_params, %{"diagrams_path" => diagrams_path}, socket) do
    entries = Loader.scan(diagrams_path)

    if connected?(socket), do: watch(diagrams_path)

    {:ok,
     assign(socket,
       entries: entries,
       groups: group_entries(entries),
       diagrams_path: diagrams_path
     )}
  end

  @impl true
  def handle_params(params, uri, socket) do
    selected =
      select_entry(socket.assigns.entries, socket.assigns.diagrams_path, params["d"])

    {:noreply, assign(socket, selected: selected, path: URI.parse(uri).path)}
  end

  @impl true
  def handle_event("select", %{"key" => key}, socket) do
    case Enum.find(socket.assigns.entries, &(&1.key == key)) do
      nil ->
        {:noreply, socket}

      entry ->
        id = diagram_id(entry, socket.assigns.diagrams_path)
        {:noreply, push_patch(socket, to: "#{socket.assigns.path}?d=#{id}")}
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

  defp select_entry(entries, _diagrams_path, nil), do: default_entry(entries)

  defp select_entry(entries, diagrams_path, id) do
    Enum.find(entries, &(diagram_id(&1, diagrams_path) == id)) || default_entry(entries)
  end

  defp default_entry(entries), do: Enum.find(entries, &(!Map.has_key?(&1, :error)))

  @doc false
  def diagram_id(entry, diagrams_path) do
    entry.key
    |> Path.relative_to(diagrams_path)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 8)
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
