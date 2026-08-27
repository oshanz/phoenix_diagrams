import mermaid from "mermaid";

const THEME_STORAGE_KEY = "ex_diag_theme";
const THEME_CHANGED_EVENT = "ex-diag-theme-changed";

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

function currentTheme(root) {
  return root.dataset.theme === "dark" ? "dark" : "light";
}

function resolveTheme() {
  return readStoredTheme() || (systemPrefersDark() ? "dark" : "light");
}

mermaid.initialize({ startOnLoad: false });

export const ExDiagMermaid = {
  mounted() {
    this.root = this.el.closest(".ex-diag-root");
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

    this.renderQueue = this.renderQueue
      .then(() => {
        mermaid.initialize({ startOnLoad: false, theme: theme === "dark" ? "dark" : "default" });
        return mermaid.render(`ex-diag-${this.el.id}-svg`, source);
      })
      .then(({ svg }) => {
        this.el.innerHTML = svg;
      });
  },
};

// LiveView re-renders (e.g. selecting a diagram) morphdom-patch this element's
// attributes back to whatever the server last rendered, which never includes
// data-theme (it's client-only state). Reapplying it in updated() - which fires
// after every such patch - keeps the chosen theme from getting silently reset.
export const ExDiagTheme = {
  mounted() {
    this.applyTheme(resolveTheme());
    this.onClick = (event) => {
      if (!event.target.closest("#ex-diag-theme-toggle")) return;
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

    const toggle = this.el.querySelector("#ex-diag-theme-toggle");
    toggle?.setAttribute("aria-pressed", theme === "dark" ? "true" : "false");
    toggle?.querySelector(".ex-diag-theme-icon-light")?.classList.toggle("hidden", theme === "dark");
    toggle?.querySelector(".ex-diag-theme-icon-dark")?.classList.toggle("hidden", theme !== "dark");

    this.el.dispatchEvent(new CustomEvent(THEME_CHANGED_EVENT, { detail: { theme } }));
  },
};
