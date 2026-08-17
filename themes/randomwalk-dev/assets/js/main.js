(function () {
  var root = document.documentElement;
  var toggle = document.querySelector("[data-theme-toggle]");
  var navToggle = document.querySelector("[data-nav-toggle]");
  var nav = document.querySelector("[data-site-nav]");

  function currentTheme() {
    return root.getAttribute("data-theme") === "dark" ? "dark" : "light";
  }

  // giscus renders in a cross-origin iframe, so it can't read our CSS/data-theme
  // attribute directly — it has to be told the theme explicitly via postMessage
  function sendGiscusTheme(theme) {
    var iframe = document.querySelector("iframe.giscus-frame");
    if (!iframe) return;
    iframe.contentWindow.postMessage(
      { giscus: { setConfig: { theme: theme === "dark" ? "dark" : "light" } } },
      "https://giscus.app"
    );
  }

  // Any message from giscus means its iframe is live and can be configured.
  // Deliberately not keyed to `.discussion`: giscus only sends that payload once
  // a discussion exists, so a post with no comments yet would never get its
  // theme pushed and would render in the OS theme regardless of the reader's
  // explicit toggle. The resize message emitted on first render is the reliable
  // signal.
  window.addEventListener("message", function (event) {
    if (event.origin !== "https://giscus.app") return;
    if (!(event.data && event.data.giscus)) return;
    sendGiscusTheme(currentTheme());
  });

  function setTheme(theme) {
    root.setAttribute("data-theme", theme);
    localStorage.setItem("theme", theme);
    if (toggle) {
      toggle.textContent = theme === "dark" ? "Light mode" : "Dark mode";
    }
    sendGiscusTheme(theme);
  }

  if (toggle) {
    toggle.textContent = currentTheme() === "dark" ? "Light mode" : "Dark mode";
    toggle.addEventListener("click", function () {
      setTheme(currentTheme() === "dark" ? "light" : "dark");
    });
  }

  if (navToggle && nav) {
    navToggle.addEventListener("click", function () {
      var isOpen = nav.classList.toggle("is-open");
      navToggle.textContent = isOpen ? "Close Menu" : "Open Menu";
      navToggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
    });
  }
})();
