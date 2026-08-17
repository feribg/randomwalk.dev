# Third-party notices

This repository redistributes the components below. Each is governed by its own
license, **not** by the repository's `LICENSE`. Nothing in that file restricts
the rights these licenses grant you.

Both the SIL Open Font License and the MIT License require their notice to
travel with the redistributed files, which is why the license texts are checked
in next to the assets themselves rather than only summarized here.

---

## Fonts

### Source Serif 4
- **Copyright** © 2014–2023 Adobe (https://www.adobe.com/), with Reserved Font Name "Source"
- **License** SIL Open Font License 1.1
- **Upstream** https://github.com/adobe-fonts/source-serif
- **Files**
  - `themes/randomwalk-dev/static/fonts/source-serif-4/*.woff2` — web faces
  - `themes/randomwalk-dev/assets/og/SourceSerif4Display-Semibold.ttf` — used at
    build time by `images.Text` to compose social cards; `images.Text` requires a
    TrueType/OpenType face and cannot read `woff2`
- **License text** `themes/randomwalk-dev/static/fonts/source-serif-4/OFL.md`
  and `themes/randomwalk-dev/assets/og/SourceSerif4-OFL.md`

> "Source" is a Reserved Font Name under the OFL. A modified version of these
> files may not be distributed under that name.

### IBM Plex Sans
- **Copyright** © 2017 IBM Corp.
- **License** SIL Open Font License 1.1
- **Upstream** https://github.com/IBM/plex
- **Files** `themes/randomwalk-dev/static/fonts/ibm-plex-sans/*.woff2`
- **License text** `themes/randomwalk-dev/static/fonts/ibm-plex-sans/LICENSE.txt`

### JetBrains Mono
- **Copyright** © 2020 The JetBrains Mono Project Authors
- **License** SIL Open Font License 1.1
- **Upstream** https://github.com/JetBrains/JetBrainsMono
- **Files** `themes/randomwalk-dev/static/fonts/jetbrains-mono/*.woff2`
- **License text** `themes/randomwalk-dev/static/fonts/jetbrains-mono/OFL.txt`

---

## Libraries

### KaTeX 0.16.11
- **Copyright** © 2013–2020 Khan Academy and other contributors
- **License** MIT
- **Upstream** https://github.com/KaTeX/KaTeX
- **Files** `themes/randomwalk-dev/static/vendor/katex/` — `katex.min.js`,
  `auto-render.min.js`, `katex.min.css`, and the `fonts/` directory
- **License text** `themes/randomwalk-dev/static/vendor/katex/LICENSE.txt`

KaTeX's bundled fonts are derived from the American Mathematical Society's
Computer Modern fonts and are covered by the same MIT license text above.

---

## Build-time only

**Hugo** (Apache 2.0) builds this site but is not redistributed here — it is a
prerequisite you install yourself. Chroma, the syntax highlighter whose class
names `assets/css/chroma.css` targets, ships inside the Hugo binary (MIT).
