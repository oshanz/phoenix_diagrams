export const ExDiagCopy = {
  mounted() {
    this.onClick = () => this.copy();
    this.el.addEventListener("click", this.onClick);
  },
  destroyed() {
    this.el.removeEventListener("click", this.onClick);
  },
  copy() {
    const targetId = this.el.dataset.target;
    const target = targetId && document.getElementById(targetId);
    const text = target?.textContent;
    if (!text) return;

    navigator.clipboard?.writeText(text);
  },
};
