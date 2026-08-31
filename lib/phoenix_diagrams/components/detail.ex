defmodule PhoenixDiagrams.Components.Detail do
  @moduledoc false

  use Phoenix.Component

  alias PhoenixDiagrams.Components.Icons

  attr(:selected, :map, default: nil)

  def detail(assigns) do
    ~H"""
    <main class="phoenix-diagrams-detail flex-1 overflow-auto">
      <div :if={is_nil(@selected)} class="hero min-h-[50vh]">
        <div class="hero-content text-center">
          <p class="text-base-content/60">Select a diagram from the sidebar.</p>
        </div>
      </div>
      <div
        :if={@selected && Map.has_key?(@selected, :error)}
        role="alert"
        class="phoenix-diagrams-error alert alert-error"
      >
        <span><strong>Error loading {@selected.file}:</strong> {@selected.error}</span>
      </div>
      <div
        :if={@selected && !Map.has_key?(@selected, :error)}
        class="card bg-base-100 shadow-sm border border-base-300"
      >
        <div class="card-body">
          <div role="tablist" class="tabs tabs-lift">
            <input
              type="radio"
              name="phoenix-diagrams-view-tab"
              role="tab"
              class="tab"
              aria-label="Preview"
              checked="checked"
            />
            <div
              id={"phoenix-diagrams-preview-" <> to_string(@selected.type)}
              role="tabpanel"
              class="phoenix-diagrams-preview tab-content bg-base-100 border-base-300 overflow-auto cursor-grab"
            >
              <%!-- PhoenixDiagramsZoom toggles this container between cursor-grab and cursor-grabbing while panning --%>
              <div
                role="toolbar"
                aria-label="Preview actions"
                class="flex items-center gap-1 rounded-t-box border border-base-300 bg-base-200 px-2 py-1"
              >
                <button
                  id="phoenix-diagrams-download"
                  type="button"
                  phx-hook="PhoenixDiagramsDownload"
                  data-target={"phoenix-diagrams-diagram-" <> to_string(@selected.type)}
                  data-filename={download_filename(@selected)}
                  class="btn btn-square btn-ghost btn-sm tooltip tooltip-bottom"
                  data-tip="Download diagram as SVG"
                  aria-label="Download diagram as SVG"
                >
                  <Icons.arrow_down_tray class="h-5 w-5" />
                </button>
                <button
                  id="phoenix-diagrams-share"
                  type="button"
                  phx-hook="PhoenixDiagramsShare"
                  class="btn btn-square btn-ghost btn-sm tooltip tooltip-bottom"
                  data-tip="Copy shareable link"
                  aria-label="Copy shareable link"
                >
                  <Icons.share class="h-5 w-5" />
                </button>
                <div
                  id="phoenix-diagrams-zoom"
                  phx-hook="PhoenixDiagramsZoom"
                  data-target={"phoenix-diagrams-diagram-" <> to_string(@selected.type)}
                  role="group"
                  aria-label="Zoom controls"
                  class="flex items-center gap-1"
                >
                  <button
                    type="button"
                    data-zoom-action="out"
                    class="btn btn-square btn-ghost btn-sm tooltip tooltip-bottom"
                    data-tip="Zoom out"
                    aria-label="Zoom out"
                  >
                    <Icons.magnifying_glass_minus class="h-5 w-5" />
                  </button>
                  <button
                    type="button"
                    data-zoom-action="reset"
                    class="btn btn-square btn-ghost btn-sm tooltip tooltip-bottom"
                    data-tip="Reset zoom"
                    aria-label="Reset zoom"
                  >
                    <Icons.arrow_path class="h-5 w-5" />
                  </button>
                  <button
                    type="button"
                    data-zoom-action="in"
                    class="btn btn-square btn-ghost btn-sm tooltip tooltip-bottom"
                    data-tip="Zoom in"
                    aria-label="Zoom in"
                  >
                    <Icons.magnifying_glass_plus class="h-5 w-5" />
                  </button>
                </div>
                <button
                  id="phoenix-diagrams-fullscreen"
                  type="button"
                  phx-hook="PhoenixDiagramsFullscreen"
                  data-target={"phoenix-diagrams-preview-" <> to_string(@selected.type)}
                  class="btn btn-square btn-ghost btn-sm tooltip tooltip-bottom"
                  data-tip="View fullscreen"
                  aria-label="View fullscreen"
                >
                  <Icons.arrows_pointing_out class="h-5 w-5" data-icon="expand" />
                  <Icons.arrows_pointing_in class="h-5 w-5 hidden" data-icon="collapse" />
                </button>
              </div>
              <div
                id={"phoenix-diagrams-diagram-" <> to_string(@selected.type)}
                phx-hook={diagram_hook(@selected)}
                phx-update="ignore"
                role="img"
                aria-label={"Diagram: " <> (@selected[:name] || @selected.file)}
                data-source={@selected.source}
                class="rounded-b-box border border-t-0 border-base-300 p-4"
              >
                <pre class="mermaid">{@selected.source}</pre>
              </div>
            </div>

            <input type="radio" name="phoenix-diagrams-view-tab" role="tab" class="tab" aria-label="Code" />
            <div role="tabpanel" class="tab-content bg-base-100 border-base-300">
              <div
                role="toolbar"
                aria-label="Code actions"
                class="flex items-center gap-1 rounded-t-box border border-base-300 bg-base-200 px-2 py-1"
              >
                <button
                  id="phoenix-diagrams-copy"
                  type="button"
                  phx-hook="PhoenixDiagramsCopy"
                  data-target="phoenix-diagrams-code"
                  class="btn btn-square btn-ghost btn-sm tooltip"
                  data-tip="Copy diagram source"
                  aria-label="Copy diagram source"
                >
                  <Icons.document_duplicate class="h-5 w-5" />
                </button>
              </div>
              <pre class="rounded-b-box border border-t-0 border-base-300 bg-base-200 p-4 overflow-auto"><code id="phoenix-diagrams-code">{@selected.source}</code></pre>
            </div>
          </div>
        </div>
      </div>
    </main>
    """
  end

  defp diagram_hook(%{type: :plantuml}), do: "PhoenixDiagramsPlantuml"
  defp diagram_hook(_selected), do: "PhoenixDiagramsMermaid"

  defp download_filename(entry) do
    base = Path.rootname(entry[:name] || entry.file)

    base
    |> String.replace(~r/[^A-Za-z0-9._-]+/, "-")
    |> Kernel.<>(".svg")
  end
end
