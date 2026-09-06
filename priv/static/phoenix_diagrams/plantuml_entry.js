// Separate esbuild entry point so @plantuml/core (TeaVM-compiled, several MB)
// is built as its own single file (build/plantuml.js) rather than inlined
// into build/bundle.js. plantuml_hook.js lazy-imports it on first mount, so
// pages that only render Mermaid diagrams never fetch this file.
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

export { renderToString };
