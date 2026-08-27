import mermaid from "mermaid";

mermaid.initialize({ startOnLoad: false });

export const ExDiagMermaid = {
  mounted() {
    this.render();
  },
  updated() {
    this.render();
  },
  render() {
    const source = this.el.dataset.source;
    const pre = this.el.querySelector("pre.mermaid");
    if (!source || !pre) return;

    mermaid.render(`ex-diag-${this.el.id}-svg`, source).then(({ svg }) => {
      this.el.innerHTML = svg;
    });
  },
};
