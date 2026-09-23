(() => {
  "use strict";

  const languageKey = "kifxpro-site-language";
  const supportedLanguages = new Set(["zh", "en"]);
  const page = document.body.dataset.page || "home";

  const pageMetadata = {
    home: {
      zh: {
        title: "KIFXPRO — 搬家纸箱登记与定位",
        description:
          "KIFXPRO 帮你快速登记纸箱、离线查找物品、生成标签并追踪搬运状态。无需账号，核心数据默认保存在设备本地。",
      },
      en: {
        title: "KIFXPRO — Moving Box Organizer",
        description:
          "Register boxes quickly, find packed items offline, create labels, and track every moving stage. No account required.",
      },
    },
    privacy: {
      zh: {
        title: "KIFXPRO 隐私政策",
        description:
          "了解 KIFXPRO 如何处理搬家项目、纸箱记录、照片、语音、二维码、导出文件和网站访问数据。",
      },
      en: {
        title: "KIFXPRO Privacy Policy",
        description:
          "Learn how KIFXPRO handles moving projects, box records, photos, voice input, QR codes, exports, and website data.",
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
      // The current page still supports switching if storage is unavailable.
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
        // Keep the original link when it cannot be resolved.
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
        // Keep the selection for this page even if persistence is unavailable.
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
