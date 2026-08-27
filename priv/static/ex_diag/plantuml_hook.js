import "@plantuml/core/viz-global.js";
import { renderToString } from "@plantuml/core";
import "./c4.min.js";

// @plantuml/core doesn't bundle "heavy" stdlibs like C4-PlantUML (see its
// README). For `!include <C4/...>`, the engine lazily fetches "<name>.min.js"
// via a <script src> resolved *relative to the current page URL* (not the
// package/bundle location) - see plantuml.js's EH9/A4n/EL7. In a host app
// mounted under an arbitrary path, that request has no reliable route to
// land on, so it 404s and the include fails ("Fatal parsing error"). c4.min.js
// (vendored above) self-installs window.PLANTUML_STDLIB_JSON.c4 as a side
// effect; marking window.__pl_script_state accordingly makes the engine's own
// loaded-check (EL7) short-circuit so it never attempts that fetch.
window.__pl_script_state = window.__pl_script_state || {};
window.__pl_script_state["c4.min.js"] = { state: "loaded", ok: [], err: [] };

function currentTheme(root) {
  return root?.dataset.theme === "dark" ? "dark" : "light";
}

export const ExDiagPlantuml = {
  mounted() {
    this.root = this.el.closest(".ex-diag-root");
    this.renderQueue = Promise.resolve();
    this.onThemeChanged = () => this.render();
    this.root?.addEventListener("ex-diag-theme-changed", this.onThemeChanged);
    this.render();
  },
  updated() {
    this.render();
  },
  destroyed() {
    this.root?.removeEventListener("ex-diag-theme-changed", this.onThemeChanged);
  },
  // See ExDiagMermaid.render in mermaid_hook.js: mounted()/updated() can both
  // fire within the same LiveView patch, and the engine shares internal state
  // across renders, so renders are queued to run one at a time.
  render() {
    const source = this.el.dataset.source;
    if (!source) return;

    const el = this.el;
    // renderToString has no dark-mode option (only PlantUML's render(...,
    // {dark}) does) - the SVG is always rendered with dark text on a light
    // background. Give it an explicit light backdrop so that text stays
    // legible against the app's dark theme instead of turning invisible.
    el.style.backgroundColor = currentTheme(this.root) === "dark" ? "#fff" : "";

    this.renderQueue = this.renderQueue.then(
      () =>
        new Promise((resolve) => {
          renderToString(
            source.split(/\r\n|\r|\n/),
            (svg) => {
              el.innerHTML = svg;
              resolve();
            },
            (message) => {
              el.innerHTML = "";
              el.textContent = `PlantUML render error: ${message}`;
              resolve();
            },
          );
        }),
    );
  },
};
