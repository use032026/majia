(() => {
  "use strict";

  const languageKey = "jufu-site-language";
  const supportedLanguages = new Set(["zh", "en"]);

  function resolveInitialLanguage() {
    const queryLanguage = new URLSearchParams(window.location.search).get("lang");
    if (supportedLanguages.has(queryLanguage)) return queryLanguage;
    try {
      const savedLanguage = window.localStorage.getItem(languageKey);
      if (supportedLanguages.has(savedLanguage)) return savedLanguage;
    } catch (_) {
      // Language selection still works for this page when storage is unavailable.
    }
    return navigator.language.toLowerCase().startsWith("zh") ? "zh" : "en";
  }

  function updateInternalLinks(language) {
    document.querySelectorAll("[data-local-page], [data-language-link]").forEach((link) => {
      const href = link.getAttribute("href");
      if (!href || href.startsWith("#") || href.startsWith("mailto:")) return;
      try {
        const url = new URL(href, window.location.href);
        if (url.protocol !== "file:" && url.origin !== window.location.origin) return;
        url.searchParams.set("lang", language);
        link.href = url.href;
      } catch (_) {
        // Keep the original link if the browser cannot resolve it.
      }
    });
  }

  function applyLanguage(language, persist = true) {
    if (!supportedLanguages.has(language)) return;
    document.documentElement.lang = language === "zh" ? "zh-Hans" : "en";
    document.querySelectorAll("[data-lang]").forEach((element) => {
      element.hidden = element.dataset.lang !== language;
    });
    document.querySelectorAll("[data-zh][data-en]").forEach((element) => {
      element.textContent = element.dataset[language];
    });
    document.querySelectorAll("[data-policy-language]").forEach((element) => {
      element.hidden = element.dataset.policyLanguage !== language;
    });
    document.querySelectorAll("[data-language-option], [data-lang-choice]").forEach((button) => {
      const value = button.dataset.languageOption || button.dataset.langChoice;
      button.setAttribute("aria-pressed", String(value === language));
    });

    const title = language === "zh" ? document.body.dataset.titleZh : document.body.dataset.titleEn;
    const description = language === "zh" ? document.body.dataset.descriptionZh : document.body.dataset.descriptionEn;
    if (title) document.title = title;
    const meta = document.querySelector('meta[name="description"]');
    if (meta && description) meta.setAttribute("content", description);
    updateInternalLinks(language);

    if (persist) {
      try {
        window.localStorage.setItem(languageKey, language);
      } catch (_) {
        // The page remains usable when local storage is unavailable.
      }
    }
  }

  document.querySelectorAll("[data-language-option], [data-lang-choice]").forEach((button) => {
    button.addEventListener("click", () => {
      applyLanguage(button.dataset.languageOption || button.dataset.langChoice);
    });
  });
  applyLanguage(resolveInitialLanguage(), false);

  const header = document.querySelector("[data-header]");
  const updateHeader = () => header?.classList.toggle("is-scrolled", window.scrollY > 18);
  updateHeader();
  window.addEventListener("scroll", updateHeader, { passive: true });

  document.querySelectorAll("[data-current-year]").forEach((element) => {
    element.textContent = String(new Date().getFullYear());
  });
})();
