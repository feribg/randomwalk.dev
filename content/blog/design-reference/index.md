---
title: "Design Reference: Every Element This Blog Supports"
description: "A working sample of every typographic element the blog supports — headings, code, math, tables, callouts, citations, and more."
date: 2026-07-05
math: true
draft: true
references:
  - key: polya1921
    author: "Pólya, G."
    year: 1921
    title: "Über eine Aufgabe der Wahrscheinlichkeitsrechnung betreffend die Irrfahrt im Straßennetz"
    container: "Mathematische Annalen 84(1–2)"
    url: "https://link.springer.com/article/10.1007/BF01458701"
  - key: donsker1951
    author: "Donsker, M. D."
    year: 1951
    title: "An invariance principle for certain probability limit theorems"
    container: "Memoirs of the American Mathematical Society 6"
  - key: blackscholes1973
    author: "Black, F., and Scholes, M."
    year: 1973
    title: "The pricing of options and corporate liabilities"
    container: "Journal of Political Economy 81(3)"
    url: "https://www.jstor.org/stable/1831029"
---

This page exists purely as a kitchen sink. If it's on the page, the blog needs to render it well: headings, inline formatting, lists, blockquotes, callouts, code in four languages, inline and display math, tables, figures, citations, and footnotes. Scroll through the whole thing before judging any single element in isolation — type systems live or die on how their pieces sit next to each other.

## Headings and hierarchy

The section above is an `h2`. It marks a new major section of a post and is the only heading level guaranteed to appear in every article.

### A subsection is an h3

Used to break a long section into a few labeled parts, like this one.

#### A detail within that subsection is an h4

Reserved for one more level of nesting — a specific case or caveat that belongs under the `h3` above it.

##### A minor label is an h5

Styled as small caps in the sans font rather than a scaled-down serif, since a fifth level of size contrast stops being readable as hierarchy and starts just being a smaller sentence. This is about as deep as a post should ever nest.

## Text formatting

A paragraph can carry **bold text** for emphasis, *italics* for a softer emphasis or term introduction, `inline code` for identifiers and short expressions, ~~strikethrough~~ for a retracted claim, and <mark>a highlighted phrase</mark> for something you want to draw the eye to without a full callout. It can also link out — for instance to [the Wikipedia article on random walks](https://en.wikipedia.org/wiki/Random_walk) — with a plain underline in the body text color rather than the default browser blue.

## Lists

An unordered list, for unordered facts:

- Simple random walks are recurrent in one and two dimensions
- They are transient in three dimensions and above
- This result is due to Pólya{{< cite polya1921 >}}, and it still surprises people the first time they hear it

An ordered list, for a sequence that matters, with a nested list inside one item:

1. Simulate $N$ independent paths
2. Estimate the empirical variance at each time step
   - Confirm it grows roughly linearly in $t$
   - Compare against the theoretical value $\operatorname{Var}(X_t) = t$
3. Fit a diffusion coefficient if the walk isn't a pure ±1 step

And a definition list, for terms that need a precise, short gloss:

<dl>
  <dt>Martingale</dt>
  <dd>A process whose expected next value, conditional on the past, equals its current value.</dd>
  <dt>Markov property</dt>
  <dd>The future depends on the past only through the present state.</dd>
</dl>

## Blockquotes

A simple blockquote, for quoting a source directly:

> A drunk man will eventually find his way home, but a drunk bird may get lost forever.
>
> <cite>Shizuo Kakutani, on recurrence of random walks in 2D vs. 3D</cite>

Blockquotes can nest, for a quote within a quote:

> The original proof is short enough to sketch here.
>
> > Consider the walk's return probability as a function of dimension…
>
> —which is the kind of aside a nested quote is for.

## Callouts

For a note that's useful but would break the flow of a paragraph:

{{% callout label="Note" %}}
Everything in this post uses the same font, color, and spacing tokens as the rest of the site — nothing here is a one-off style.
{{% /callout %}}

And for something that actually needs to change the reader's behavior:

{{% callout label="Careful" variant="warning" %}}
A ±1 random walk is not a model of an asset price on its own — it has no drift and no volatility scaling. Don't wire this directly into a backtest.
{{% /callout %}}

## Code

Python, with the file name in the header bar:

```python {filename="walk_np.py"}
import numpy as np

def random_walk(n_steps: int, n_paths: int = 1, seed: int | None = None) -> np.ndarray:
    rng = np.random.default_rng(seed)
    steps = rng.choice([-1.0, 1.0], size=(n_paths, n_steps))
    return steps.cumsum(axis=1)
```

A YAML config, to show a third language and a different token mix:

```yaml {filename="config.yaml"}
simulation:
  n_steps: 10_000
  n_paths: 1_000
  seed: 42
model:
  drift: 0.0
  volatility: 1.0
  process: geometric_brownian_motion
```

C++, for the cases where the interpreter overhead is the thing being measured:

```cpp {filename="walk.cpp"}
#include <random>
#include <vector>

std::vector<double> random_walk(int n_steps, unsigned seed = 42) {
    std::mt19937 rng(seed);
    std::uniform_int_distribution<int> step(0, 1);

    std::vector<double> path;
    path.reserve(n_steps + 1);

    double position = 0.0;
    path.push_back(position);
    for (int i = 0; i < n_steps; ++i) {
        position += step(rng) == 0 ? -1.0 : 1.0;
        path.push_back(position);
    }
    return path;
}
```

And a diff, for showing a change to existing code — note the per-line red/green tinting:

```diff {filename="walk.py.diff"}
--- a/walk.py
+++ b/walk.py
@@ -1,7 +1,7 @@
-import random
+import numpy as np

-def random_walk(n_steps):
-    position = 0.0
-    path = [position]
-    for _ in range(n_steps):
-        step = random.choice([-1.0, 1.0])
-        position += step
-        path.append(position)
-    return path
+def random_walk(n_steps, n_paths=1, seed=None):
+    rng = np.random.default_rng(seed)
+    steps = rng.choice([-1.0, 1.0], size=(n_paths, n_steps))
+    return steps.cumsum(axis=1)
```

## Math

Inline math sits at text size, like the step distribution $\varepsilon_t \sim \text{Uniform}\{-1, +1\}$ or a variance claim $\operatorname{Var}(X_n) = n$. Display math gets its own centered line and can scroll horizontally on narrow screens without breaking the layout:

$$ X_{t+1} = X_t + \varepsilon_t $$

A system of equations renders as a single aligned block — this one being the process underlying Black–Scholes{{< cite blackscholes1973 >}}, which the walk above converges to in the continuous-time limit by Donsker's invariance principle{{< cite donsker1951 >}}:

$$ \begin{aligned} dS_t &= \mu S_t\, dt + \sigma S_t\, dW_t \\ d\langle S \rangle_t &= \sigma^2 S_t^2\, dt \end{aligned} $$

And a matrix, since covariance structures come up constantly in this kind of writing:

$$ \Sigma = \begin{bmatrix} \sigma_1^2 & \rho\,\sigma_1\sigma_2 \\ \rho\,\sigma_1\sigma_2 & \sigma_2^2 \end{bmatrix} $$

## Tables

A results table with a right-aligned, tabular-figure numeric column:

| Estimator          |  Bias |  RMSE |
| ------------------- | ----: | ----: |
| Sample mean          |  0.00 | 0.014 |
| MLE (Gaussian)       |  0.00 | 0.012 |
| Method of moments    | -0.03 | 0.019 |

## Figures

<figure>
  <svg viewBox="0 0 640 220" xmlns="http://www.w3.org/2000/svg" role="img" aria-labelledby="fig-walk-caption">
    <line x1="10" y1="31.1" x2="630" y2="31.1" stroke="currentColor" stroke-opacity="0.25" stroke-dasharray="4 4" />
    <polyline points="10.0,31.1 15.2,20.5 20.4,31.1 25.6,20.5 30.8,31.1 36.1,41.6 41.3,52.1 46.5,41.6 51.7,52.1 56.9,62.6 62.1,73.2 67.3,83.7 72.5,73.2 77.7,62.6 82.9,73.2 88.2,83.7 93.4,94.2 98.6,83.7 103.8,94.2 109.0,104.7 114.2,115.3 119.4,125.8 124.6,115.3 129.8,125.8 135.0,136.3 140.3,146.8 145.5,157.4 150.7,146.8 155.9,136.3 161.1,146.8 166.3,157.4 171.5,146.8 176.7,157.4 181.9,167.9 187.1,178.4 192.4,167.9 197.6,178.4 202.8,188.9 208.0,199.5 213.2,210.0 218.4,199.5 223.6,188.9 228.8,178.4 234.0,167.9 239.2,157.4 244.5,146.8 249.7,136.3 254.9,146.8 260.1,157.4 265.3,167.9 270.5,178.4 275.7,167.9 280.9,157.4 286.1,146.8 291.3,136.3 296.6,125.8 301.8,136.3 307.0,146.8 312.2,136.3 317.4,146.8 322.6,136.3 327.8,146.8 333.0,136.3 338.2,125.8 343.4,136.3 348.7,146.8 353.9,136.3 359.1,125.8 364.3,115.3 369.5,104.7 374.7,94.2 379.9,104.7 385.1,115.3 390.3,104.7 395.5,94.2 400.8,104.7 406.0,115.3 411.2,104.7 416.4,94.2 421.6,83.7 426.8,73.2 432.0,62.6 437.2,73.2 442.4,62.6 447.6,52.1 452.9,62.6 458.1,73.2 463.3,62.6 468.5,73.2 473.7,83.7 478.9,73.2 484.1,83.7 489.3,94.2 494.5,83.7 499.7,73.2 505.0,62.6 510.2,73.2 515.4,83.7 520.6,73.2 525.8,62.6 531.0,52.1 536.2,62.6 541.4,52.1 546.6,41.6 551.8,31.1 557.1,20.5 562.3,10.0 567.5,20.5 572.7,31.1 577.9,41.6 583.1,52.1 588.3,62.6 593.5,73.2 598.7,83.7 603.9,94.2 609.2,83.7 614.4,94.2 619.6,83.7 624.8,73.2 630.0,83.7" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linejoin="round" stroke-linecap="round" />
  </svg>
  <figcaption id="fig-walk-caption">A single simulated path of 120 steps, seeded for reproducibility. The dashed line marks the starting position.</figcaption>
</figure>

A hand-authored inline `<svg>` like the one above passes through untouched. A plain Markdown image goes through the render hook instead, which resizes it and emits a `<picture>` with WebP and AVIF sources:

![Benchmark of three random-walk implementations](benchmark.png "Wall time for the pure-Python loop, the NumPy vectorization, and the C++ version, plotted against step count.")

## Notes and citations

The blog distinguishes two things that often get conflated. A **citation** points at a source and is written as a shortcode against the page's `references:` front matter, like the Pólya reference{{< cite polya1921 >}} earlier — click any marker to jump to the entry, then the arrow to come back to where you were. A **footnote** is an aside that would break the flow of a sentence but isn't a source at all[^1], and can carry math or code the way any other prose can[^2].

Both render as headingless blocks below, separated from the body by a rule and a drop in type size. Citations are numbered by their order in the front matter, so moving a paragraph never renumbers anything.

[^1]: A martingale has $\mathbb{E}[X_{t+1} \mid \mathcal{F}_t] = X_t$ — the conditional expectation of the next step is just where you are now. That's a statement about drift, not variance, which is why a martingale can still be arbitrarily volatile.
[^2]: The three-dimensional transience result generalizes to all dimensions $d \geq 3$, with return probability decaying as the walk explores more of the lattice than it can revisit.
