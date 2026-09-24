(() => {
  "use strict";

  const languageKey = "plotproof-site-language";
  const supportedLanguages = new Set(["zh", "en"]);
  const page = document.body.dataset.page || "home";

  const pageMetadata = {
    home: {
      zh: {
        title: "PlotProof Lab 图证实验室 — 把“看起来”变成“有证据”",
        description:
          "PlotProof Lab 是离线优先的数据识读实验工具。先判断，再改变一个变量，对照同一数据的不同表达。",
      },
      en: {
        title: "PlotProof Lab — Turn first impressions into evidence",
        description:
          "PlotProof Lab is an offline-first data-literacy lab. Commit a judgment, change one variable, and compare two views of the same data.",
      },
    },
    privacy: {
      zh: {
        title: "PlotProof Lab 隐私政策",
        description:
          "了解 PlotProof Lab 如何处理本地学习记录、语言偏好、版本化题目包和网站访问信息。",
      },
      en: {
        title: "PlotProof Lab Privacy Policy",
        description:
          "Learn how PlotProof Lab handles local learning records, language preferences, versioned lesson packs, and website access data.",
      },
    },
  };

  function resolveInitialLanguage() {
    const queryLanguage = new URLSearchParams(window.location.search).get("lang");
    if (supportedLanguages.has(queryLanguage)) return queryLanguage;

    try {
      const savedLanguage = window.localStorage.getItem(languageKey);
      if (supportedLanguages.has(savedLanguage)) return savedLanguage;
    } catch (_) {
      // Language switching still works when browser storage is unavailable.
    }

    return navigator.language.toLowerCase().startsWith("zh") ? "zh" : "en";
  }

  function updateInternalLinks(language) {
    document.querySelectorAll("[data-language-link]").forEach((link) => {
      const href = link.getAttribute("href");
      if (!href || href.startsWith("#") || href.startsWith("mailto:")) return;

      try {
        const url = new URL(href, window.location.href);
        if (url.protocol !== "file:" && url.origin !== window.location.origin) return;
        url.searchParams.set("lang", language);
        link.href = url.href;
      } catch (_) {
        // Preserve the original URL if it cannot be parsed.
      }
    });
  }

  function setLanguage(language, persist = true) {
    if (!supportedLanguages.has(language)) return;

    document.documentElement.lang = language === "zh" ? "zh-CN" : "en";
    document.querySelectorAll("[data-zh][data-en]").forEach((element) => {
      element.textContent = element.dataset[language];
    });
    document.querySelectorAll("[data-lang-choice]").forEach((button) => {
      button.setAttribute(
        "aria-pressed",
        String(button.dataset.langChoice === language),
      );
    });
    document.querySelectorAll("[data-policy-language]").forEach((block) => {
      block.hidden = block.dataset.policyLanguage !== language;
    });

    const metadata = pageMetadata[page]?.[language];
    if (metadata) {
      document.title = metadata.title;
      const description = document.querySelector('meta[name="description"]');
      if (description) description.content = metadata.description;
    }

    updateInternalLinks(language);
    if (persist) {
      try {
        window.localStorage.setItem(languageKey, language);
      } catch (_) {
        // Keep the current-page selection even if persistence is unavailable.
      }
    }
  }

  setLanguage(resolveInitialLanguage(), false);

  document.querySelectorAll("[data-lang-choice]").forEach((button) => {
    button.addEventListener("click", () => setLanguage(button.dataset.langChoice));
  });

  const header = document.querySelector("[data-header]");
  const updateHeader = () => {
    header?.classList.toggle("is-scrolled", window.scrollY > 16);
  };
  updateHeader();
  window.addEventListener("scroll", updateHeader, { passive: true });

  const menuButton = document.querySelector("[data-menu-button]");
  const navigation = document.querySelector("[data-nav]");

  function closeMenu() {
    menuButton?.setAttribute("aria-expanded", "false");
    navigation?.classList.remove("is-open");
    document.body.classList.remove("menu-open");
  }

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

  document.querySelectorAll("[data-current-year]").forEach((element) => {
    element.textContent = String(new Date().getFullYear());
  });
})();
