(() => {
  "use strict";

  const languageKey = "kifxpro-site-language";
  const supportedLanguages = new Set(["zh", "en"]);

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
    document.querySelectorAll("[data-language-option]").forEach((button) => {
      button.setAttribute(
        "aria-pressed",
        String(button.dataset.languageOption === language),
      );
    });
    document.querySelectorAll("[data-lang]").forEach((block) => {
      block.hidden = block.dataset.lang !== language;
    });
    document.querySelectorAll("[data-policy-language]").forEach((block) => {
      block.hidden = block.dataset.policyLanguage !== language;
    });

    const title = document.body.dataset[`title${language === "zh" ? "Zh" : "En"}`];
    const descriptionValue = document.body.dataset[
      `description${language === "zh" ? "Zh" : "En"}`
    ];
    if (title) document.title = title;
    const description = document.querySelector('meta[name="description"]');
    if (description && descriptionValue) description.content = descriptionValue;

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

  document.querySelectorAll("[data-language-option]").forEach((button) => {
    button.addEventListener("click", () => setLanguage(button.dataset.languageOption));
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
