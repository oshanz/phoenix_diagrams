defmodule PhoenixDiagrams.DiagramLive do
  use Phoenix.LiveView

  alias PhoenixDiagrams.Loader

  @impl true
  def mount(_params, %{"diagrams_path" => diagrams_path} = session, socket) do
    entries = Loader.scan(diagrams_path)

    if connected?(socket), do: watch(diagrams_path)

    {:ok,
     assign(socket,
       entries: entries,
       groups: group_entries(entries),
       diagrams_path: diagrams_path,
       app_version: session["app_version"],
       search: "",
       url_version: nil,
       version_notice_dismissed: false
     )}
  end

  @impl true
  def handle_params(params, uri, socket) do
    selected =
      select_entry(socket.assigns.entries, socket.assigns.diagrams_path, params["d"])

    {:noreply,
     assign(socket,
       selected: selected,
       path: URI.parse(uri).path,
       url_version: params["v"],
       version_notice_dismissed: false
     )}
  end

  @impl true
  def handle_event("select", %{"key" => key}, socket) do
    case Enum.find(socket.assigns.entries, &(&1.key == key)) do
      nil ->
        {:noreply, socket}

      entry ->
        id = diagram_id(entry, socket.assigns.diagrams_path)
        slug = diagram_slug(entry)
        to = "#{socket.assigns.path}?d=#{slug}-#{id}" <> version_query(socket.assigns.app_version)
        {:noreply, push_patch(socket, to: to)}
    end
  end

  @impl true
  def handle_event("dismiss_version_notice", _params, socket) do
    {:noreply, assign(socket, version_notice_dismissed: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply,
     assign(socket, search: query, groups: group_entries(socket.assigns.entries, query))}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply, assign(socket, search: "", groups: group_entries(socket.assigns.entries))}
  end

  @impl true
  def handle_info({:file_event, _watcher_pid, {_path, _events}}, socket) do
    entries = Loader.scan(socket.assigns.diagrams_path)
    previous_key = is_map(socket.assigns.selected) && socket.assigns.selected.key

    selected =
      Enum.find(entries, &(&1.key == previous_key)) ||
        Enum.find(entries, &(!Map.has_key?(&1, :error)))

    {:noreply,
     assign(socket,
       entries: entries,
       groups: group_entries(entries, socket.assigns.search),
       selected: selected
     )}
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
    hash = String.slice(id, -8, 8)
    Enum.find(entries, &(diagram_id(&1, diagrams_path) == hash)) || :not_found
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

  @doc false
  def diagram_slug(entry) do
    name = entry[:name] || Path.basename(entry.file, Path.extname(entry.file))

    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp version_query(nil), do: ""
  defp version_query(app_version), do: "&v=#{URI.encode_www_form(app_version)}"

  defp group_entries(entries, query \\ "") do
    entries
    |> Enum.filter(&matches_search?(&1, query))
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

  defp matches_search?(_entry, ""), do: true

  defp matches_search?(entry, query) do
    (entry[:name] || entry.file)
    |> String.downcase()
    |> String.contains?(String.downcase(query))
  end
end
