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
          <div class="flex items-center justify-between gap-2">
            <h2 class="card-title">{@selected[:name] || @selected.file}</h2>
            <button
              id="ex-diag-download"
              type="button"
              phx-hook="ExDiagDownload"
              data-target={"ex-diag-diagram-" <> to_string(@selected.type)}
              data-filename={download_filename(@selected)}
              class="btn btn-sm btn-ghost"
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
          >
            <pre class="mermaid">{@selected.source}</pre>
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
