export const PhoenixDiagramsFullscreen = {
  mounted() {
    this.onClick = () => this.toggle();
    this.onFullscreenChange = () => this.syncIcon();
    this.el.addEventListener("click", this.onClick);
    document.addEventListener("fullscreenchange", this.onFullscreenChange);
    this.syncIcon();
  },
  destroyed() {
    this.el.removeEventListener("click", this.onClick);
    document.removeEventListener("fullscreenchange", this.onFullscreenChange);
  },
  toggle() {
    const targetId = this.el.dataset.target;
    const target = targetId && document.getElementById(targetId);
    if (!target) return;

    if (document.fullscreenElement === target) {
      document.exitFullscreen?.();
    } else {
      target.requestFullscreen?.();
    }
  },
  syncIcon() {
    const targetId = this.el.dataset.target;
    const isFullscreen = document.fullscreenElement?.id === targetId;
    const expandIcon = this.el.querySelector('[data-icon="expand"]');
    const collapseIcon = this.el.querySelector('[data-icon="collapse"]');
    expandIcon?.classList.toggle("hidden", isFullscreen);
    collapseIcon?.classList.toggle("hidden", !isFullscreen);
    this.el.setAttribute(
      "aria-label",
      isFullscreen ? "Exit fullscreen" : "View fullscreen",
    );
  },
};
