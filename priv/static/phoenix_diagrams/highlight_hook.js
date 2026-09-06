import Prism from "prismjs";
import "prismjs/components/prism-mermaid";
import "prismjs/components/prism-plant-uml";

const LANGUAGES = {
  mermaid: Prism.languages.mermaid,
  plantuml: Prism.languages.plantuml,
};

export const PhoenixDiagramsCodeHighlight = {
  mounted() {
    this.highlight();
  },
  updated() {
    this.highlight();
  },
  highlight() {
    const language = LANGUAGES[this.el.dataset.language] || LANGUAGES.mermaid;
    this.el.innerHTML = Prism.highlight(this.el.textContent, language, this.el.dataset.language);
  },
};
