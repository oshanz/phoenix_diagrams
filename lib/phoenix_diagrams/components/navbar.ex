defmodule PhoenixDiagrams.Components.Navbar do
  @moduledoc false

  use Phoenix.Component

  alias PhoenixDiagrams.Components.Icons

  attr(:selected, :map, default: nil)

  def navbar(assigns) do
    ~H"""
    <div class="navbar bg-base-200">
      <div class="flex-1 flex items-center">
        <label
          for="phoenix-diagrams-drawer"
          aria-label="open sidebar"
          class="btn btn-square btn-ghost drawer-button lg:hidden"
        >
          <Icons.bars_3 class="my-1.5 inline-block h-5 w-5" />
        </label>
        <button
          id="phoenix-diagrams-sidebar-toggle"
          type="button"
          class="btn btn-square btn-ghost hidden lg:inline-flex"
          aria-label="Toggle sidebar"
          aria-controls="phoenix-diagrams-sidebar"
          aria-expanded="true"
        >
          <svg
            class="phoenix-diagrams-collapse-icon my-1.5 inline-block h-5 w-5"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            aria-hidden="true"
          >
            <rect x="3" y="3" width="18" height="18" rx="2" stroke-width="2" />
            <path d="M9 3v18" stroke-width="2" />
            <rect x="4" y="4" width="4.5" height="16" rx="1" fill="currentColor" stroke="none" />
          </svg>
        </button>
        <span class="ml-2 font-semibold">{navbar_title(@selected)}</span>
      </div>
      <div class="flex-none">
        <button
          id="phoenix-diagrams-theme-toggle"
          type="button"
          class="btn btn-square btn-ghost"
          aria-label="Toggle color theme"
          aria-pressed="false"
        >
          <Icons.sun class="phoenix-diagrams-theme-icon-light h-5 w-5" />
          <Icons.moon class="phoenix-diagrams-theme-icon-dark h-5 w-5 hidden" />
        </button>
      </div>
    </div>
    """
  end

  defp navbar_title(nil), do: "Diagrams"
  defp navbar_title(selected), do: selected[:name] || selected.file
end
