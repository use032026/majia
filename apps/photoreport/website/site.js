(() => {
  "use strict";

  const languageKey = "photoreport-site-language";
  const supportedLanguages = new Set(["zh", "en"]);
  const page = document.body.dataset.page || "home";

  function preferredLanguage() {
    const queryLanguage = new URLSearchParams(window.location.search).get("lang");
    if (supportedLanguages.has(queryLanguage)) return queryLanguage;

    try {
      const saved = window.localStorage.getItem(languageKey);
      if (supportedLanguages.has(saved)) return saved;
    } catch (_) {
      // The site remains usable when browser storage is unavailable.
    }

    return navigator.language.toLowerCase().startsWith("zh") ? "zh" : "en";
  }

  function updateInternalLinks(language) {
    document.querySelectorAll("[data-language-link]").forEach((link) => {
      const href = link.getAttribute("href");
      if (!href || href.startsWith("#") || href.startsWith("mailto:")) return;

      try {
        const url = new URL(href, window.location.href);
        if (!["http:", "https:", "file:"].includes(url.protocol)) return;
        if (url.protocol !== "file:" && url.origin !== window.location.origin) return;
        url.searchParams.set("lang", language);
        link.href = url.href;
      } catch (_) {
        // Leave malformed or unsupported links unchanged.
      }
    });
  }

  function setLanguage(language) {
    if (!supportedLanguages.has(language)) return;

    document.documentElement.lang = language === "zh" ? "zh-Hans" : "en";

    document.querySelectorAll("[data-zh][data-en]").forEach((element) => {
      element.textContent = element.dataset[language];
    });

    document.querySelectorAll("[data-language-option]").forEach((button) => {
      button.setAttribute(
        "aria-pressed",
        String(button.dataset.languageOption === language),
      );
    });

    document.querySelectorAll("[data-lang]").forEach((block) => {
      block.hidden = block.dataset.lang !== language;
    });

    document.querySelectorAll("[data-anchor-zh][data-anchor-en]").forEach((link) => {
      const target = link.dataset[`anchor${language === "zh" ? "Zh" : "En"}`];
      const href = link.getAttribute("href") || "";
      if (href.startsWith("#")) {
        link.setAttribute("href", `#${target}`);
        return;
      }

      try {
        const url = new URL(href, window.location.href);
        url.hash = target;
        link.href = url.href;
      } catch (_) {
        // Leave malformed links unchanged.
      }
    });

    const localeSuffix = language === "zh" ? "Zh" : "En";
    const title = document.body.dataset[`title${localeSuffix}`];
    const description = document.body.dataset[`description${localeSuffix}`];
    document.title = title;
    document.querySelector('meta[property="og:title"]').content = title;
    document.querySelectorAll('meta[name="description"], meta[property="og:description"]').forEach((meta) => {
      meta.content = description;
    });
    const languageUrl = document.querySelector(
      `link[rel="alternate"][hreflang="${document.documentElement.lang}"]`,
    ).href;
    document.querySelector('link[rel="canonical"]').href = languageUrl;
    document.querySelector('meta[property="og:url"]').content = languageUrl;

    updateInternalLinks(language);

    try {
      window.localStorage.setItem(languageKey, language);
    } catch (_) {
      // The selected language still applies to this page view.
    }
  }

  setLanguage(preferredLanguage());

  document.querySelectorAll("[data-language-option]").forEach((button) => {
    button.addEventListener("click", () => {
      const language = button.dataset.languageOption;
      setLanguage(language);

      const url = new URL(window.location.href);
      url.searchParams.set("lang", language);
      if (page === "privacy") {
        const oldAnchor = url.hash.slice(1);
        const tocLink = Array.from(document.querySelectorAll(".policy-toc [data-anchor-zh][data-anchor-en]"))
          .find(({ dataset }) => oldAnchor === dataset.anchorZh || oldAnchor === dataset.anchorEn);
        if (tocLink) url.hash = language === "zh" ? tocLink.dataset.anchorZh : tocLink.dataset.anchorEn;
      }
      window.history.replaceState(null, "", url);
      if (url.hash) document.getElementById(url.hash.slice(1))?.scrollIntoView();
    });
  });

  document.querySelectorAll("[data-current-year]").forEach((element) => {
    element.textContent = String(new Date().getFullYear());
  });

  const header = document.querySelector("[data-header]");
  const updateHeader = () => {
    if (!header || page === "privacy") return;
    header.classList.toggle("is-scrolled", window.scrollY > 18);
  };
  updateHeader();
  window.addEventListener("scroll", updateHeader, { passive: true });

  const menuButton = document.querySelector("[data-menu-button]");
  const navigation = document.querySelector("[data-nav]");

  const closeMenu = () => {
    menuButton?.setAttribute("aria-expanded", "false");
    navigation?.classList.remove("is-open");
    document.body.classList.remove("menu-open");
  };

  menuButton?.addEventListener("click", () => {
    const willOpen = menuButton.getAttribute("aria-expanded") !== "true";
    menuButton.setAttribute("aria-expanded", String(willOpen));
    navigation?.classList.toggle("is-open", willOpen);
    document.body.classList.toggle("menu-open", willOpen);
  });

  navigation?.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", closeMenu);
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeMenu();
  });

  const desktopQuery = window.matchMedia("(min-width: 841px)");
  desktopQuery.addEventListener?.("change", (event) => {
    if (event.matches) closeMenu();
  });
})();
