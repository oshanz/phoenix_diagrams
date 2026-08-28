defmodule PhoenixDiagrams.Components.Detail do
  @moduledoc false

  use Phoenix.Component

  attr(:selected, :map, default: nil)

  def detail(assigns) do
    ~H"""
    <main class="phoenix-diagrams-detail flex-1 overflow-auto p-6">
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
                  class="btn btn-square btn-ghost btn-sm"
                  aria-label="Download diagram as SVG"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    aria-hidden="true"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1M7 10l5 5 5-5M12 15V3"
                    />
                  </svg>
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
                    class="btn btn-square btn-ghost btn-sm"
                    aria-label="Zoom out"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-5 w-5"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      aria-hidden="true"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M21 21l-4.35-4.35M11 8v0M8 11h6M17 11A6 6 0 105 11a6 6 0 0012 0z"
                      />
                    </svg>
                  </button>
                  <button
                    type="button"
                    data-zoom-action="reset"
                    class="btn btn-square btn-ghost btn-sm"
                    aria-label="Reset zoom"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-5 w-5"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      aria-hidden="true"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M4 4v5h5M20 20v-5h-5M4 9a8 8 0 0113.66-4.66M20 15a8 8 0 01-13.66 4.66"
                      />
                    </svg>
                  </button>
                  <button
                    type="button"
                    data-zoom-action="in"
                    class="btn btn-square btn-ghost btn-sm"
                    aria-label="Zoom in"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-5 w-5"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      aria-hidden="true"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M21 21l-4.35-4.35M11 8v6M8 11h6M17 11A6 6 0 105 11a6 6 0 0012 0z"
                      />
                    </svg>
                  </button>
                </div>
                <button
                  id="phoenix-diagrams-fullscreen"
                  type="button"
                  phx-hook="PhoenixDiagramsFullscreen"
                  data-target={"phoenix-diagrams-preview-" <> to_string(@selected.type)}
                  class="btn btn-square btn-ghost btn-sm"
                  aria-label="View fullscreen"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    aria-hidden="true"
                    data-icon="expand"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M4 8V4m0 0h4M4 4l5 5m11-5h-4m4 0v4m0-4l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"
                    />
                  </svg>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 hidden"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    aria-hidden="true"
                    data-icon="collapse"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 9V5m0 4H5m4 0L4 4m11 5V5m0 4h4m-4 0l5-5M9 15v4m0-4H5m4 0l-5 5m11-5v4m0-4h4m-4 0l5 5"
                    />
                  </svg>
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
                  class="btn btn-square btn-ghost btn-sm"
                  aria-label="Copy diagram source"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    aria-hidden="true"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                    />
                  </svg>
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
