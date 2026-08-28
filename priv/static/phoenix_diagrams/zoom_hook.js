const MIN_SCALE = 0.25;
const MAX_SCALE = 3;
const SCALE_STEP = 1.2;

export const PhoenixDiagramsZoom = {
  mounted() {
    this.scale = 1;
    this.dragging = false;

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

    this.onMouseDown = (event) => {
      if (event.button !== 0 || event.target.closest("[data-zoom-action]")) return;

      this.dragging = true;
      this.dragStartX = event.clientX;
      this.dragStartY = event.clientY;
      this.scrollStartLeft = this.container.scrollLeft;
      this.scrollStartTop = this.container.scrollTop;
      this.container.classList.remove("cursor-grab");
      this.container.classList.add("cursor-grabbing");
      event.preventDefault();
    };
    this.onMouseMove = (event) => {
      if (!this.dragging) return;

      this.container.scrollLeft = this.scrollStartLeft - (event.clientX - this.dragStartX);
      this.container.scrollTop = this.scrollStartTop - (event.clientY - this.dragStartY);
    };
    this.onMouseUp = () => {
      if (!this.dragging) return;

      this.dragging = false;
      this.container.classList.remove("cursor-grabbing");
      this.container.classList.add("cursor-grab");
    };

    // The diagram element carries phx-update="ignore", so switching between
    // two diagrams of the same type patches only its data-source attribute,
    // never the toolbar's own markup — updated() would not fire for that.
    // Watch the attribute directly instead.
    this.onSourceChange = () => this.resetView();
    this.observer = new MutationObserver(this.onSourceChange);

    this.onFullscreenChange = () => this.resetView();
    document.addEventListener("fullscreenchange", this.onFullscreenChange);

    this.attachTarget();
  },
  updated() {
    this.attachTarget();
  },
  destroyed() {
    this.el.removeEventListener("click", this.onClick);
    document.removeEventListener("fullscreenchange", this.onFullscreenChange);
    this.observer.disconnect();
    this.detachContainer();
  },
  attachTarget() {
    const target = document.getElementById(this.el.dataset.target);
    if (target === this.target) return;

    this.observer.disconnect();
    this.target = target;
    this.attachContainer(target?.parentElement);
    if (!target) return;

    this.observer.observe(target, { attributes: true, attributeFilter: ["data-source"] });
    this.resetView();
  },
  resetView() {
    this.setScale(1);
    if (this.container) {
      this.container.scrollLeft = 0;
      this.container.scrollTop = 0;
    }
  },
  attachContainer(container) {
    if (container === this.container) return;

    this.detachContainer();
    this.container = container;
    if (!this.container) return;

    this.dragging = false;
    this.container.classList.add("cursor-grab");
    this.container.addEventListener("mousedown", this.onMouseDown);
    this.container.addEventListener("mousemove", this.onMouseMove);
    this.container.addEventListener("mouseup", this.onMouseUp);
    this.container.addEventListener("mouseleave", this.onMouseUp);
  },
  detachContainer() {
    if (!this.container) return;

    this.container.removeEventListener("mousedown", this.onMouseDown);
    this.container.removeEventListener("mousemove", this.onMouseMove);
    this.container.removeEventListener("mouseup", this.onMouseUp);
    this.container.removeEventListener("mouseleave", this.onMouseUp);
    this.container = null;
  },
  setScale(scale) {
    this.scale = Math.min(MAX_SCALE, Math.max(MIN_SCALE, scale));

    if (!this.target) return;

    this.target.style.transform = `scale(${this.scale})`;
    this.target.style.transformOrigin = "top left";
  },
};
