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

function loadingMarkup() {
  return `<div class="ex-diag-loading flex items-center justify-center gap-2 p-8 text-base-content/60" role="status">
    <span class="loading loading-spinner loading-sm" aria-hidden="true"></span>
    <span>Rendering diagram…</span>
  </div>`;
}

function waitForPaint() {
  return new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
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
    const dark = currentTheme(this.root) === "dark";

    this.renderQueue = this.renderQueue
      .then(() => {
        el.innerHTML = loadingMarkup();
        return waitForPaint();
      })
      .then(
        () =>
          new Promise((resolve) => {
            // renderToString's 4th argument isn't in the published API docs
            // (only render(lines, targetId, {dark}) is documented as
            // dark-mode-aware) but the engine checks it the same way
            // internally, so it works for the callback-based string API too.
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
              { dark },
            );
          }),
      );
  },
};
