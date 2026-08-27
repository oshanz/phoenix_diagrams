defmodule ExDiag.Components.Navbar do
  @moduledoc false

  use Phoenix.Component

  def navbar(assigns) do
    ~H"""
    <div class="navbar bg-base-200">
      <div class="flex-1 flex items-center">
        <label
          for="ex-diag-drawer"
          aria-label="open sidebar"
          class="btn btn-square btn-ghost drawer-button lg:hidden"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-5 w-5"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            aria-hidden="true"
          >
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </label>
        <span class="ml-2 font-semibold">Diagrams</span>
      </div>
      <div class="flex-none">
        <button
          id="ex-diag-theme-toggle"
          type="button"
          class="btn btn-square btn-ghost"
          aria-label="Toggle color theme"
          aria-pressed="false"
        >
          <svg
            class="ex-diag-theme-icon-light h-5 w-5"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"
            />
          </svg>
          <svg
            class="ex-diag-theme-icon-dark h-5 w-5 hidden"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"
            />
          </svg>
        </button>
      </div>
    </div>
    """
  end
end
