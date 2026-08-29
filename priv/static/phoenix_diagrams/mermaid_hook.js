import mermaid from "mermaid";

const THEME_STORAGE_KEY = "phoenix_diagrams_theme";
const THEME_CHANGED_EVENT = "phoenix-diagrams-theme-changed";

function readStoredTheme() {
  try {
    return window.localStorage.getItem(THEME_STORAGE_KEY);
  } catch {
    return null;
  }
}

function writeStoredTheme(theme) {
  try {
    window.localStorage.setItem(THEME_STORAGE_KEY, theme);
  } catch {
    // localStorage unavailable (private browsing, host restrictions, etc.) - toggle still works in-memory.
  }
}

function systemPrefersDark() {
  return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
}

// Matches the daisyUI "dark" theme colors in input.css (a neutral grey
// palette modeled on KDE Breeze Dark). mermaid's built-in "dark" theme has
// poor text/line contrast against that palette (labels can end up nearly
// invisible), so the dark render uses the "base" theme with these explicit
// variables instead.
const DARK_THEME_VARIABLES = {
  darkMode: true,
  background: "#1b1e20",
  mainBkg: "#31363b",
  primaryColor: "#31363b",
  primaryTextColor: "#eff0f1",
  primaryBorderColor: "#3daee9",
  secondaryColor: "#3a3f44",
  secondaryTextColor: "#eff0f1",
  secondaryBorderColor: "#7f8c8d",
  tertiaryColor: "#232629",
  tertiaryTextColor: "#eff0f1",
  tertiaryBorderColor: "#4d4d4d",
  lineColor: "#95a5a6",
  textColor: "#eff0f1",
  nodeTextColor: "#eff0f1",
  edgeLabelBackground: "#1b1e20",
  clusterBkg: "#232629",
  clusterBorder: "#4d4d4d",
  titleColor: "#eff0f1",
  errorBkgColor: "#3b1c1c",
  errorTextColor: "#f5b7b1",
};

function currentTheme(root) {
  return root.dataset.theme === "dark" ? "dark" : "light";
}

function loadingMarkup() {
  return `<div class="phoenix-diagrams-loading flex items-center justify-center gap-2 p-8 text-base-content/60" role="status">
    <span class="loading loading-spinner loading-sm" aria-hidden="true"></span>
    <span>Rendering diagram…</span>
  </div>`;
}

function errorMarkup(message) {
  return `<div class="phoenix-diagrams-error alert alert-error m-4" role="alert">
    <span><strong>Mermaid render error:</strong> ${escapeHtml(message)}</span>
  </div>`;
}

function escapeHtml(text) {
  const div = document.createElement("div");
  div.textContent = text;
  return div.innerHTML;
}

// Yield two animation frames so the browser actually paints the loading
// markup before the (synchronous, main-thread-blocking) mermaid.render()
// call starts - large diagrams can block the tab for a long time, and
// without this the loading state would never be visible.
function waitForPaint() {
  return new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
}

function resolveTheme() {
  return readStoredTheme() || (systemPrefersDark() ? "dark" : "light");
}

mermaid.initialize({ startOnLoad: false });

export const PhoenixDiagramsMermaid = {
  mounted() {
    this.root = this.el.closest(".phoenix-diagrams-root");
    this.renderQueue = Promise.resolve();
    this.onThemeChanged = () => this.render();
    this.root?.addEventListener(THEME_CHANGED_EVENT, this.onThemeChanged);
    this.render();
  },
  updated() {
    this.render();
  },
  destroyed() {
    this.root?.removeEventListener(THEME_CHANGED_EVENT, this.onThemeChanged);
  },
  // Selecting a diagram and a theme change dispatched in the same LiveView
  // patch can both call render() before the previous mermaid.render() call
  // resolves; mermaid.render() isn't safe to run concurrently against the
  // same target id, so calls are queued to run one at a time.
  render() {
    const source = this.el.dataset.source;
    if (!source) return;

    const theme = this.root ? currentTheme(this.root) : "light";
    const el = this.el;

    this.renderQueue = this.renderQueue
      .then(() => {
        el.innerHTML = loadingMarkup();
        return waitForPaint();
      })
      .then(() => {
        mermaid.initialize(
          theme === "dark"
            ? {
                startOnLoad: false,
                theme: "base",
                themeVariables: DARK_THEME_VARIABLES,
              }
            : { startOnLoad: false, theme: "default" },
        );
        return mermaid.render(`phoenix-diagrams-${this.el.id}-svg`, source);
      })
      .then(({ svg }) => {
        this.el.innerHTML = svg;
      })
      .catch((error) => {
        this.el.innerHTML = errorMarkup(error?.message ?? String(error));
      });
  },
};

// LiveView re-renders (e.g. selecting a diagram) morphdom-patch this element's
// attributes back to whatever the server last rendered, which never includes
// data-theme (it's client-only state). Reapplying it in updated() - which fires
// after every such patch - keeps the chosen theme from getting silently reset.
export const PhoenixDiagramsTheme = {
  mounted() {
    this.applyTheme(resolveTheme());
    this.onClick = (event) => {
      if (!event.target.closest("#phoenix-diagrams-theme-toggle")) return;
      const next = currentTheme(this.el) === "dark" ? "light" : "dark";
      writeStoredTheme(next);
      this.applyTheme(next);
    };
    this.el.addEventListener("click", this.onClick);
  },
  updated() {
    this.applyTheme(resolveTheme());
  },
  destroyed() {
    this.el.removeEventListener("click", this.onClick);
  },
  applyTheme(theme) {
    this.el.dataset.theme = theme;

    const toggle = this.el.querySelector("#phoenix-diagrams-theme-toggle");
    toggle?.setAttribute("aria-pressed", theme === "dark" ? "true" : "false");
    toggle?.querySelector(".phoenix-diagrams-theme-icon-light")?.classList.toggle("hidden", theme === "dark");
    toggle?.querySelector(".phoenix-diagrams-theme-icon-dark")?.classList.toggle("hidden", theme !== "dark");

    this.el.dispatchEvent(new CustomEvent(THEME_CHANGED_EVENT, { detail: { theme } }));
  },
};
