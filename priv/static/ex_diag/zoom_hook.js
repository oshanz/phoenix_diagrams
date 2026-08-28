const MIN_SCALE = 0.25;
const MAX_SCALE = 3;
const SCALE_STEP = 1.2;

export const ExDiagZoom = {
  mounted() {
    this.scale = 1;
    this.onClick = (event) => {
      const button = event.target.closest("[data-zoom-action]");
      if (!button) return;

      switch (button.dataset.zoomAction) {
        case "in":
          this.setScale(this.scale * SCALE_STEP);
          break;
        case "out":
          this.setScale(this.scale / SCALE_STEP);
          break;
        case "reset":
          this.setScale(1);
          break;
      }
    };
    this.el.addEventListener("click", this.onClick);
  },
  destroyed() {
    this.el.removeEventListener("click", this.onClick);
  },
  setScale(scale) {
    this.scale = Math.min(MAX_SCALE, Math.max(MIN_SCALE, scale));

    const target = document.getElementById(this.el.dataset.target);
    if (!target) return;

    target.style.transform = `scale(${this.scale})`;
    target.style.transformOrigin = "top left";
  },
};
