# randomwalk.dev

Source for [randomwalk.dev](https://randomwalk.dev) — musings on code, models
and markets: quant finance, machine learning, and the engineering that makes
them work.

Built with [Hugo](https://gohugo.io/) on a custom theme
(`themes/randomwalk-dev/`): editorial serif typography, native Chroma syntax
highlighting, self-hosted KaTeX math, self-hosted fonts, and light/dark theming.
No Node, no npm, no build pipeline beyond the Hugo binary itself — JS bundling,
CSS concatenation, image processing, and social-card generation all run natively
inside it.

## Local development

Requires [**Hugo extended**](https://gohugo.io/installation/) 0.163.0 or newer
(`brew install hugo` on macOS). The extended build is required for WebP/AVIF
image processing and for the social-card generation.

```sh
hugo server -D
```

Serves at `http://localhost:1313/` with live reload. `-D` includes drafts, which
is how you see `content/blog/design-reference/` — a kitchen-sink page rendering
every element the theme supports. It's the fastest way to check a styling change
against everything at once.

Production build:

```sh
hugo --minify --gc
```

## Writing a post

```sh
hugo new content/blog/my-new-post/index.md
```

Front matter comes from `archetypes/blog.md`:

```yaml
title: "My New Post"
date: 2026-01-01
description: ""
draft: true
math: false
```

- `draft: false` publishes it.
- `math: true` opts the page into KaTeX. It's per-page because the KaTeX assets
  are ~300KB and most posts don't need them.
- `description` is used for the meta description, the RSS summary, and the card
  blurb on list pages. Worth writing properly.

Author posts as **leaf bundles** — a folder named after the slug containing
`index.md` — so images live next to the post that uses them. Reference an image
with plain Markdown and a render hook turns it into a responsive `<picture>`
with WebP and AVIF sources:

```markdown
![Alt text](chart.png "Optional caption")
```

Posts live under `content/blog/` but the `blog/` prefix is stripped from the
URL, so `content/blog/my-post/index.md` publishes at `/my-post/`.

### Code blocks

Fenced, with an optional filename shown in the header bar:

````markdown
```python {filename="walk.py"}
import numpy as np
```
````

`diff` fences get per-line red/green tinting automatically. Every block gets a
copy button.

### Callouts

```markdown
{{%/* callout label="Careful" variant="warning" */%}}
Body text here, parsed as Markdown.
{{%/* /callout */%}}
```

Omit `variant` for a neutral note.

### Citations and footnotes

Two different things, deliberately. A **footnote** is an aside — standard
Markdown `[^1]` syntax. A **citation** points at a source, and is declared in
front matter then referenced by key:

```yaml
references:
  - key: polya1921
    author: "Pólya, G."
    year: 1921
    title: "Über eine Aufgabe der Wahrscheinlichkeitsrechnung"
    container: "Mathematische Annalen 84(1–2)"
    url: "https://example.com"
```

```markdown
This result is due to Pólya{{</* cite polya1921 */>}}.
```

That renders a `[1]` marker linked to the entry, and the entry links back to the
marker. Numbering follows the order of the `references:` list, not order of
appearance, so moving a paragraph never renumbers anything. Citing a key that
isn't declared **fails the build** rather than shipping a dead link.

### Runnable code for a post

Full, runnable versions of a post's experiments go in `code/<post-slug>/`, kept
outside `content/` so Hugo never processes them and so the trimmed snippet in
the post and the real thing don't silently drift. See `code/README.md`.

## Social cards

Every post gets a generated 1200×630 card — the post title set in Source Serif
over the site's paper background — composed at build time by
`themes/randomwalk-dev/layouts/partials/opengraph-image.html` using Hugo's
`images.Text`. There's nothing to configure per post.

## RSS

`/blog/index.xml` is the feed, auto-discoverable from every page via
`<link rel="alternate">`. The home page's own feed is disabled, since Hugo's
default would mix in undated pages like Contact.

## Corrections

Found an error in a post, a broken snippet, or a reference that doesn't resolve?
[Open an issue](https://github.com/feribg/randomwalk.dev/issues) — that's the
most useful thing you can send, and the fix ends up visible to whoever hits it
next. Or email **hello123@randomwalk.dev**.

## License

**Source-available, not open source.** The code and the writing here are
publicly viewable for reference, but no license is granted to copy, redistribute,
modify, or reuse either. See [LICENSE](LICENSE).

Vendored fonts (Source Serif 4, IBM Plex Sans, JetBrains Mono — all OFL) and
KaTeX (MIT) are **not** covered by that and keep their own licenses. See
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
