document.addEventListener("DOMContentLoaded", () => {
  if (window.lucide) {
    window.lucide.createIcons();
  }

  const toggle = document.querySelector(".nav-toggle");
  const navigation = document.querySelector(".site-nav");

  if (toggle && navigation) {
    toggle.addEventListener("click", () => {
      const open = navigation.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", String(open));
      toggle.setAttribute("aria-label", open ? "关闭导航" : "打开导航");
    });

    navigation.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => {
        navigation.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
        toggle.setAttribute("aria-label", "打开导航");
      });
    });
  }

  const year = document.querySelector("#current-year");
  if (year) {
    year.textContent = String(new Date().getFullYear());
  }

  document.querySelectorAll(".microsoft-store-link").forEach((link) => {
    link.addEventListener("click", (event) => {
      event.preventDefault();

      const fallbackUrl = link.dataset.webFallback;
      if (!fallbackUrl) {
        window.location.href = link.href;
        return;
      }

      let fallbackTimer;
      const cancelFallback = () => {
        window.clearTimeout(fallbackTimer);
        document.removeEventListener("visibilitychange", handleVisibilityChange);
        window.removeEventListener("blur", cancelFallback);
      };
      const handleVisibilityChange = () => {
        if (document.hidden) {
          cancelFallback();
        }
      };

      document.addEventListener("visibilitychange", handleVisibilityChange);
      window.addEventListener("blur", cancelFallback);
      fallbackTimer = window.setTimeout(() => {
        cancelFallback();
        window.location.assign(fallbackUrl);
      }, 1800);

      try {
        window.location.href = link.href;
      } catch {
        cancelFallback();
        window.location.assign(fallbackUrl);
      }
    });
  });
});
