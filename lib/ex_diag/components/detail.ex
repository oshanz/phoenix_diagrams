defmodule ExDiag.Components.Detail do
  @moduledoc false

  use Phoenix.Component

  attr(:selected, :map, default: nil)

  def detail(assigns) do
    ~H"""
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
          <div role="tablist" class="tabs tabs-lift">
            <input
              type="radio"
              name="ex-diag-view-tab"
              role="tab"
              class="tab"
              aria-label="Preview"
              checked="checked"
            />
            <div role="tabpanel" class="tab-content bg-base-100 border-base-300">
              <div
                role="toolbar"
                aria-label="Preview actions"
                class="flex items-center gap-1 rounded-t-box border border-base-300 bg-base-200 px-2 py-1"
              >
                <button
                  id="ex-diag-download"
                  type="button"
                  phx-hook="ExDiagDownload"
                  data-target={"ex-diag-diagram-" <> to_string(@selected.type)}
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
              </div>
              <div
                id={"ex-diag-diagram-" <> to_string(@selected.type)}
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

            <input type="radio" name="ex-diag-view-tab" role="tab" class="tab" aria-label="Code" />
            <div role="tabpanel" class="tab-content bg-base-100 border-base-300">
              <div
                role="toolbar"
                aria-label="Code actions"
                class="flex items-center gap-1 rounded-t-box border border-base-300 bg-base-200 px-2 py-1"
              >
                <button
                  id="ex-diag-copy"
                  type="button"
                  phx-hook="ExDiagCopy"
                  data-target="ex-diag-code"
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
              <pre class="rounded-b-box border border-t-0 border-base-300 bg-base-200 p-4 overflow-auto"><code id="ex-diag-code">{@selected.source}</code></pre>
            </div>
          </div>
        </div>
      </div>
    </main>
    """
  end

  defp diagram_hook(%{type: :plantuml}), do: "ExDiagPlantuml"
  defp diagram_hook(_selected), do: "ExDiagMermaid"

  defp download_filename(entry) do
    base = Path.rootname(entry[:name] || entry.file)

    base
    |> String.replace(~r/[^A-Za-z0-9._-]+/, "-")
    |> Kernel.<>(".svg")
  end
end
