export const PhoenixDiagramsShare = {
  mounted() {
    this.onClick = () => this.share();
    this.el.addEventListener("click", this.onClick);
  },
  destroyed() {
    this.el.removeEventListener("click", this.onClick);
    clearTimeout(this.resetTimer);
  },
  share() {
    this.animateClick();

    navigator.clipboard
      ?.writeText(window.location.href)
      .then(() => this.showCopied());
  },
  animateClick() {
    this.el.classList.remove("phoenix-diagrams-share-clicked");
    // eslint-disable-next-line no-unused-expressions
    this.el.offsetWidth; // restart the animation if clicked again mid-animation
    this.el.classList.add("phoenix-diagrams-share-clicked");
  },
  showCopied() {
    const originalTip = this.originalTip ?? (this.originalTip = this.el.dataset.tip);

    this.el.dataset.tip = "Copied!";
    this.el.classList.add("tooltip-open");

    clearTimeout(this.resetTimer);
    this.resetTimer = setTimeout(() => {
      this.el.dataset.tip = originalTip;
      this.el.classList.remove("tooltip-open");
    }, 1500);
  },
};
