// Separate esbuild entry point so mermaid (several MB) is built as its own
// single file (build/mermaid.js) rather than inlined into build/bundle.js.
// mermaid_hook.js lazy-imports it on first mount, so pages that only render
// PlantUML diagrams never fetch this file.
import mermaid from "mermaid";

mermaid.initialize({ startOnLoad: false });

export default mermaid;
