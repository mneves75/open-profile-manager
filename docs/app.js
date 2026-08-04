const revealElements = document.querySelectorAll("[data-reveal]");
const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

if (prefersReducedMotion || !("IntersectionObserver" in window)) {
  revealElements.forEach((element) => element.classList.add("is-visible"));
} else {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      }
    });
  });

  revealElements.forEach((element) => observer.observe(element));
}

document.querySelectorAll("[data-copy-command], [data-copy-target]").forEach((element) => {
  const originalLabel = element.textContent ?? "Copy";
  let resetTimer;

  element.addEventListener("click", async () => {
    const target = document.getElementById(element.dataset.copyTarget ?? "");
    const command = element.dataset.copyCommand ?? target?.textContent?.trim();

    if (command && navigator.clipboard) {
      try {
        await navigator.clipboard.writeText(command);
        window.clearTimeout(resetTimer);
        element.textContent = "Copied";
        element.setAttribute("aria-label", "Install command copied");
        resetTimer = window.setTimeout(() => {
          element.textContent = originalLabel;
          element.setAttribute("aria-label", "Copy install command");
        }, 1500);
      } catch {
        // The install command remains selectable when clipboard access is denied.
      }
    }
  });
});

const videos = document.querySelectorAll("video");
videos.forEach((video) => {
  video.addEventListener("play", () => {
    videos.forEach((otherVideo) => {
      if (otherVideo !== video) {
        otherVideo.pause();
      }
    });
  });
});
