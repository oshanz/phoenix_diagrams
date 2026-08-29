const WIDTH_STORAGE_KEY = "phoenix_diagrams_sidebar_width";
const COLLAPSED_STORAGE_KEY = "phoenix_diagrams_sidebar_collapsed";
const MIN_WIDTH = 200;
const MAX_WIDTH = 500;
const DEFAULT_WIDTH = 288; // 18rem, matches the previous fixed w-72

function readStored(key) {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeStored(key, value) {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // localStorage unavailable (private browsing, host restrictions, etc.) - still works in-memory.
  }
}

function clampWidth(width) {
  return Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, width));
}

// Mirrors the inline bootstrap script in layout.ex that applies these
// before first paint, to avoid a flash of the default width/expanded state.
export function resolveSidebarWidth() {
  const stored = parseInt(readStored(WIDTH_STORAGE_KEY), 10);
  return clampWidth(Number.isFinite(stored) ? stored : DEFAULT_WIDTH);
}

export function resolveSidebarCollapsed() {
  return readStored(COLLAPSED_STORAGE_KEY) === "true";
}

// Attached to the sidebar nav itself (not the shared root, which already
// carries PhoenixDiagramsTheme - LiveView allows only one phx-hook per
// element). Reaches up to the root for the width/collapsed CSS state so the
// drawer-side wrapper's layout (sized to this nav) responds too. The toggle
// button itself lives in the navbar, not this nav, so it's looked up
// document-wide rather than scoped to this.el.
export const PhoenixDiagramsSidebar = {
  mounted() {
    this.root = this.el.closest(".phoenix-diagrams-root");
    this.container = this.el.closest(".phoenix-diagrams-sidebar-side");
    this.applyWidth(resolveSidebarWidth());
    this.applyCollapsed(resolveSidebarCollapsed());

    this.onToggleClick = () => {
      this.applyCollapsed(!this.collapsed);
      writeStored(COLLAPSED_STORAGE_KEY, String(this.collapsed));
    };
    this.toggle = document.getElementById("phoenix-diagrams-sidebar-toggle");
    this.toggle?.addEventListener("click", this.onToggleClick);

    this.resizer = this.container?.querySelector(".phoenix-diagrams-sidebar-resizer");
    this.onResizerPointerDown = (event) => {
      if (this.collapsed) return;
      event.preventDefault();
      this.dragStartX = event.clientX;
      this.dragStartWidth = this.width;
      this.resizer.setPointerCapture(event.pointerId);
      this.resizer.addEventListener("pointermove", this.onResizerPointerMove);
      this.resizer.addEventListener("pointerup", this.onResizerPointerUp);
    };
    this.onResizerPointerMove = (event) => {
      const next = clampWidth(this.dragStartWidth + (event.clientX - this.dragStartX));
      this.applyWidth(next);
    };
    this.onResizerPointerUp = (event) => {
      this.resizer.releasePointerCapture(event.pointerId);
      this.resizer.removeEventListener("pointermove", this.onResizerPointerMove);
      this.resizer.removeEventListener("pointerup", this.onResizerPointerUp);
      writeStored(WIDTH_STORAGE_KEY, String(this.width));
    };
    this.resizer?.addEventListener("pointerdown", this.onResizerPointerDown);
  },
  // LiveView re-renders morphdom-patch this element's attributes back to
  // whatever the server last rendered, which never includes these - they're
  // client-only state. Reapplying in updated() keeps them from resetting.
  updated() {
    this.applyWidth(this.width ?? resolveSidebarWidth());
    this.applyCollapsed(this.collapsed ?? resolveSidebarCollapsed());
  },
  destroyed() {
    this.toggle?.removeEventListener("click", this.onToggleClick);
    this.resizer?.removeEventListener("pointerdown", this.onResizerPointerDown);
    this.resizer?.removeEventListener("pointermove", this.onResizerPointerMove);
    this.resizer?.removeEventListener("pointerup", this.onResizerPointerUp);
  },
  applyWidth(width) {
    this.width = width;
    (this.root ?? this.el).style.setProperty("--phoenix-diagrams-sidebar-width", `${width}px`);
  },
  applyCollapsed(collapsed) {
    this.collapsed = collapsed;
    const target = this.root ?? this.el;
    target.dataset.sidebarCollapsed = String(collapsed);
    this.toggle?.setAttribute("aria-expanded", String(!collapsed));
  },
};
