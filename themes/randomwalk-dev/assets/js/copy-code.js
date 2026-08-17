(function () {
  document.querySelectorAll(".code-block").forEach(function (block) {
    var btn = block.querySelector(".copy-btn");
    var code = block.querySelector(".chroma");
    if (!btn || !code) return;

    var originalLabel = btn.textContent;

    btn.addEventListener("click", function () {
      var text = code.textContent;
      var done = function () {
        btn.textContent = "Copied";
        btn.classList.add("is-copied");
        setTimeout(function () {
          btn.textContent = originalLabel;
          btn.classList.remove("is-copied");
        }, 1500);
      };

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done);
      } else {
        var textarea = document.createElement("textarea");
        textarea.value = text;
        textarea.style.position = "fixed";
        textarea.style.opacity = "0";
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand("copy");
        document.body.removeChild(textarea);
        done();
      }
    });
  });
})();
