(() => {
  "use strict";

  const languageKey = "tripcost-site-language";
  const supportedLanguages = new Set(["zh", "en"]);
  const page = document.body.dataset.page || "home";
  let activeLanguage = "zh";

  const pageMetadata = {
    home: {
      zh: {
        title: "RoamSum — 旅行真实消费成本助手",
        description:
          "RoamSum 是免费的旅行真实消费成本助手：扫描价格、比较支付成本、识别 DCC 加价，并持续掌握旅行预算。",
      },
      en: {
        title: "RoamSum — A True Travel Cost Assistant",
        description:
          "Scan local prices, compare payment costs, spot DCC markups, and keep your travel budget on track.",
      },
    },
    privacy: {
      zh: {
        title: "RoamSum 隐私政策",
        description:
          "了解 RoamSum 如何在设备本地处理旅行、消费、票据和汇率数据，以及可选的 iCloud 同步。",
      },
      en: {
        title: "RoamSum Privacy Policy",
        description:
          "Learn how RoamSum handles trips, expenses, receipts, and rate data on device, plus optional iCloud sync.",
      },
    },
  };

  function savedLanguage() {
    const queryLanguage = new URLSearchParams(window.location.search).get("lang");
    if (supportedLanguages.has(queryLanguage)) return queryLanguage;

    try {
      const saved = window.localStorage.getItem(languageKey);
      if (supportedLanguages.has(saved)) return saved;
    } catch (_) {
      // The site still works if local storage is unavailable.
    }

    return navigator.language.toLowerCase().startsWith("zh") ? "zh" : "en";
  }

  function updateInternalLinks(language) {
    document.querySelectorAll("[data-language-link]").forEach((link) => {
      const href = link.getAttribute("href");
      if (!href || href.startsWith("#") || href.startsWith("mailto:")) return;

      try {
        const url = new URL(href, window.location.href);
        if (url.protocol !== "http:" && url.protocol !== "https:" && url.protocol !== "file:") return;
        if (url.origin !== window.location.origin && url.protocol !== "file:") return;
        url.searchParams.set("lang", language);
        link.href = url.href;
      } catch (_) {
        // Leave a malformed or unsupported link unchanged.
      }
    });
  }

  function setLanguage(language, persist = true) {
    if (!supportedLanguages.has(language)) return;

    activeLanguage = language;
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
        // The language remains active for the current page.
      }
    }
  }

  const initialLanguage = savedLanguage();
  setLanguage(initialLanguage, false);

  document.querySelectorAll("[data-language-option]").forEach((button) => {
    button.addEventListener("click", () => {
      setLanguage(button.dataset.languageOption);
    });
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

  const contactModal = document.querySelector("[data-contact-modal]");
  const contactPanel = contactModal?.querySelector("[data-contact-panel]");
  const contactEmail = contactModal?.querySelector("[data-contact-email]")?.textContent?.trim() || "";
  const copyButton = contactModal?.querySelector("[data-copy-email]");
  const copyLabel = contactModal?.querySelector("[data-copy-label]");
  const copyStatus = contactModal?.querySelector("[data-copy-status]");
  let lastContactTrigger = null;
  let copyResetTimer = 0;

  const openContactModal = (trigger) => {
    if (!contactModal) return;
    lastContactTrigger = trigger;
    contactModal.hidden = false;
    document.body.classList.add("modal-open");
    if (copyStatus) copyStatus.textContent = "";
    contactModal.querySelector("[data-contact-close]")?.focus();
  };

  const closeContactModal = () => {
    if (!contactModal || contactModal.hidden) return;
    contactModal.hidden = true;
    document.body.classList.remove("modal-open");
    if (copyStatus) copyStatus.textContent = "";
    lastContactTrigger?.focus();
    lastContactTrigger = null;
  };

  document.querySelectorAll("[data-contact-trigger]").forEach((trigger) => {
    trigger.addEventListener("click", (event) => {
      event.preventDefault();
      closeMenu();
      openContactModal(trigger);
    });
  });

  contactModal?.querySelectorAll("[data-contact-close]").forEach((button) => {
    button.addEventListener("click", closeContactModal);
  });

  const fallbackCopy = (text) => {
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    document.body.appendChild(textarea);
    textarea.select();
    const copied = document.execCommand("copy");
    textarea.remove();
    if (!copied) throw new Error("Copy command was unavailable.");
  };

  copyButton?.addEventListener("click", async () => {
    if (!contactEmail) return;
    try {
      if (navigator.clipboard?.writeText) {
        try {
          await navigator.clipboard.writeText(contactEmail);
        } catch (_) {
          fallbackCopy(contactEmail);
        }
      } else {
        fallbackCopy(contactEmail);
      }
      if (copyLabel) copyLabel.textContent = activeLanguage === "zh" ? "已复制" : "Copied";
      if (copyStatus) {
        copyStatus.textContent = activeLanguage === "zh"
          ? "邮箱已复制到剪贴板。"
          : "Email address copied to the clipboard.";
      }
      window.clearTimeout(copyResetTimer);
      copyResetTimer = window.setTimeout(() => {
        if (copyLabel) copyLabel.textContent = activeLanguage === "zh" ? "复制邮箱" : "Copy email";
      }, 1800);
    } catch (_) {
      if (copyStatus) {
        copyStatus.textContent = activeLanguage === "zh"
          ? "复制失败，请长按或选中上方邮箱复制。"
          : "Copy failed. Select the email address above to copy it.";
      }
    }
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closeMenu();
      closeContactModal();
      return;
    }

    if (event.key !== "Tab" || !contactModal || contactModal.hidden || !contactPanel) return;
    const focusable = Array.from(
      contactPanel.querySelectorAll('button:not([disabled]), a[href], [tabindex]:not([tabindex="-1"])'),
    );
    if (focusable.length === 0) return;
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  });

  document.querySelectorAll("[data-current-year]").forEach((element) => {
    element.textContent = String(new Date().getFullYear());
  });
})();
