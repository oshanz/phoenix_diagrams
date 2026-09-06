// @plantuml/core (TeaVM-compiled) is multiple MB and only needed by pages
// that actually render a PlantUML diagram. It's built as its own entry point
// (plantuml_entry.js -> build/plantuml.js) and fetched lazily here on first
// mount instead of bloating every page's bundle.js.
let plantumlPromise = null;

function loadPlantuml() {
  if (!plantumlPromise) {
    plantumlPromise = import(new URL("./plantuml.js", import.meta.url)).then(
      (m) => m.renderToString,
    );
  }
  return plantumlPromise;
}

function currentTheme(root) {
  return root?.dataset.theme === "dark" ? "dark" : "light";
}

function loadingMarkup() {
  return `<div class="phoenix-diagrams-loading flex items-center justify-center gap-2 p-8 text-base-content/60" role="status">
    <span class="loading loading-spinner loading-sm" aria-hidden="true"></span>
    <span>Rendering diagram…</span>
  </div>`;
}

function waitForPaint() {
  return new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
}

export const PhoenixDiagramsPlantuml = {
  mounted() {
    this.root = this.el.closest(".phoenix-diagrams-root");
    this.renderQueue = Promise.resolve();
    this.onThemeChanged = () => this.render();
    this.root?.addEventListener("phoenix-diagrams-theme-changed", this.onThemeChanged);
    this.render();
  },
  updated() {
    this.render();
  },
  destroyed() {
    this.root?.removeEventListener("phoenix-diagrams-theme-changed", this.onThemeChanged);
  },
  // See PhoenixDiagramsMermaid.render in mermaid_hook.js: mounted()/updated() can both
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
      .then(() => loadPlantuml())
      .then(
        (renderToString) =>
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
