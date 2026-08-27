export const ExDiagDownload = {
  mounted() {
    this.onClick = () => this.download();
    this.el.addEventListener("click", this.onClick);
  },
  destroyed() {
    this.el.removeEventListener("click", this.onClick);
  },
  download() {
    const targetId = this.el.dataset.target;
    const filename = this.el.dataset.filename || "diagram.svg";
    const target = targetId && document.getElementById(targetId);
    const svg = target?.querySelector("svg");
    if (!svg) return;

    const source = new XMLSerializer().serializeToString(svg);
    const blob = new Blob([source], { type: "image/svg+xml" });
    const url = URL.createObjectURL(blob);

    const link = document.createElement("a");
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
  },
};
