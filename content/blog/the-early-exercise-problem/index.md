---
title: "The Early Exercise Problem"
date: 2026-08-23
description: "European options are solved to machine precision. American options — nearly everything listed on US single names and ETFs — are not, and the thing that breaks them is discrete dividends rather than the free boundary."
draft: false
math: true
references:
  - key: blackscholes1973
    author: "Black, F., and Scholes, M."
    year: 1973
    title: "The pricing of options and corporate liabilities"
    container: "Journal of Political Economy 81(3)"
    url: "https://www.jstor.org/stable/1831029"
  - key: merton1973
    author: "Merton, R. C."
    year: 1973
    title: "Theory of rational option pricing"
    container: "Bell Journal of Economics and Management Science 4(1)"
    url: "https://www.jstor.org/stable/3003143"
  - key: stefanica2017
    author: "Stefanica, D., and Radoicic, R."
    year: 2017
    title: "An explicit implied volatility formula"
    container: "International Journal of Theoretical and Applied Finance 20(7)"
  - key: cboe_etp
    author: "Cboe Global Markets"
    year: 2026
    title: "Options on ETPs — product specifications"
    container: "Exercise style: American; physically settled"
    url: "https://www.cboe.com/exchange_traded_stock/etp_options_spec/"
  - key: cboe_spx
    author: "Cboe Global Markets"
    year: 2026
    title: "S&P 500 Index Options — product specifications"
    container: "Exercise style: European; cash settled"
    url: "https://www.cboe.com/tradable_products/sp_500/spx_options/specifications/"
  - key: healy2025
    author: "Healy, J."
    year: 2025
    title: "Applied Quantitative Finance for Equity Derivatives"
    container: "Fifth edition, licensed CC BY-SA 4.0"
    url: "https://jherekhealy.github.io/"
  - key: mcdonald1998
    author: "McDonald, R. L., and Schroder, M. D."
    year: 1998
    title: "A parity result for American options"
    container: "Journal of Computational Finance 1(3)"
  - key: battauz2015
    author: "Battauz, A., De Donno, M., and Sbuelz, A."
    year: 2015
    title: "Real options and American derivatives: the double continuation region"
    container: "Management Science 61(5)"
  - key: leisen1996
    author: "Leisen, D. P. J., and Reimer, M."
    year: 1996
    title: "Binomial models for option valuation — examining and improving convergence"
    container: "Applied Mathematical Finance 3(4)"
  - key: peizer1968
    author: "Peizer, D. B., and Pratt, J. W."
    year: 1968
    title: "A normal approximation for binomial, F, beta, and other common, related tail probabilities"
    container: "Journal of the American Statistical Association 63(324)"
  - key: vellekoop2006
    author: "Vellekoop, M. H., and Nieuwenhuis, J. W."
    year: 2006
    title: "Efficient pricing of derivatives on assets with discrete dividends"
    container: "Applied Mathematical Finance 13(3)"
  - key: brennan1977
    author: "Brennan, M. J., and Schwartz, E. S."
    year: 1977
    title: "The valuation of American put options"
    container: "Journal of Finance 32(2)"
  - key: rannacher1984
    author: "Rannacher, R."
    year: 1984
    title: "Finite element solution of diffusion problems with irregular data"
    container: "Numerische Mathematik 43(2)"
  - key: quantlib
    author: "QuantLib"
    year: 2026
    title: "QuantLib 1.43 — QdFpAmericanEngine"
    container: "BSD-licensed quantitative finance library"
    url: "https://www.quantlib.org/"
  - key: thetadata
    author: "ThetaData"
    year: 2024
    title: "US equity options quote history"
    container: "Market data vendor; AAPL snapshot of 2024-01-02"
    url: "https://www.thetadata.net/"
---

{{% callout label="Part 1 of 6 — American option pricing" %}}
This post sets up the problem: what early exercise is worth, why puts and calls break for
different reasons, and what a discrete dividend costs when it gets smeared into a smooth
yield. Later parts cover the jump models, finite differences against trees, the fast
analytic approximations, greeks, and implied volatility on a real tape.
{{% /callout %}}

An option is the right to buy or sell at a fixed price. If that right can only be used on
a single date the contract is European, and the problem has been closed since 1973: Black
and Scholes wrote down the price, and the sensitivities and the volatility implied by a
quoted price all follow from the same formula{{< cite blackscholes1973 >}}{{< cite merton1973 >}}.
Inverting a market price to a volatility is a solved numerical
exercise{{< cite stefanica2017 >}} rather than a modelling question.

If the right can be used at any moment before expiry the contract is American, and the
formula is not harder — it is gone. Whether to exercise depends on the price, and the
price depends on when a rational holder would exercise, so the two have to be solved
together. What was an integral becomes a free boundary: a curve through time separating
the region where holding is worth more from the region where taking the intrinsic value
is. Nobody knows how to write that curve down, so every method from here is an
approximation, each with its own way of failing.

That would be a tolerable inconvenience if American options were a niche. They are not.
SPX and SPY track the same index and settle differently: the index option is European and
cash-settled{{< cite cboe_spx >}}, while the ETF option is American and delivers
shares{{< cite cboe_etp >}}. That split runs through the whole listed market. Cash-settled
broad-based index options are European; single-name equity options and ETF options — SPY,
QQQ, IWM — are American, and that is where most listed US volume sits. The closed-form
case is the exception.

Plenty of methods price an American option well enough, so the question worth asking is
narrower: which part of the calculation is actually costing money? Everything below says
it is not the pricer. It is the dividend fed into it.

## Measuring in the right unit

Errors here are quoted in **implied-volatility basis points**. One vol bp is $10^{-4}$ of
$\sigma$, so a 50 bp error means the price is off by as much as moving volatility from
25.00% to 25.50% would move it.

Throughout, $S$ is the spot price, $K$ the strike, $T$ the time to expiry, $\sigma$ the
volatility, $r$ the risk-free rate and $q$ a continuous dividend yield. A discrete dividend
is an amount $D$ paid on a given ex-date, and is kept separate from $q$ — the gap between
those two ways of carrying a dividend is most of what this post is about. Moneyness is
written as $S/K$, so a ratio above one is a call in the money and a put out of it.

Price error alone doesn't compare across contracts: a cent on a fifteen-cent wing option
and a cent on a twenty-eight-dollar LEAP are not the same mistake. Dividing by vega — the
price move per one-point change in volatility — fixes that, and has the practical advantage
of being the unit models are calibrated in{{< cite healy2025 >}}. The conversion is a price
change of $\text{bp} \times 10^{-4} \times \text{vega}$, which is worth seeing on real
contracts:

| contract | K | σ | premium | vega | 10 bp | 100 bp | 100 bp as % of premium |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 30d ATM | 100 | 25% | 3.0211 | 11.40 | 1.14¢ | 11.40¢ | 3.77% |
| 1y ATM | 100 | 25% | 11.8370 | 38.31 | 3.83¢ | 38.31¢ | 3.24% |
| 30d 25-delta put | 92 | 28% | 0.5487 | 6.11 | 0.61¢ | 6.11¢ | **11.13%** |
| 2y deep-ITM put | 140 | 25% | 34.6870 | 48.54 | 4.85¢ | 48.54¢ | 1.40% |

*▸ computed by `experiments.jl` → `results/volbp_scale.csv`. S = 100, r = 4%, q = 0.*

The same hundred basis points is 1.4% of a deep-in-the-money LEAP and 11% of a one-month
wing put, so every headline table below carries a percent-of-premium column as well.

The other half of the yardstick is what the market itself charges. Taking the AAPL tape
from 2 January 2024 — last two-sided quote per contract before 15:45 ET, with the bid and
the ask each inverted to a volatility:

| bucket | contracts | median width | IQR |
| --- | ---: | ---: | ---: |
| near-ATM, front 3 expiries | 20 | **24.4 vol bp** | 16.0–44.2 |
| near-ATM, all expiries | 50 | 25.2 vol bp | 18.3–38.5 |
| \|log S/K\| between 2% and 4% | 76 | 28.9 vol bp | 19.9–39.0 |

*▸ derived by `tools/derive_aapl_spread.jl` → `data/aapl_spread_summary.csv` (aggregates only). Buckets are by |log S/K|, which measures distance from the money in either direction: near-ATM is under 2%, roughly five dollars either side of a 185 spot.*

Those widths come from inverting a bid and an ask with the European Black formula, which
cannot produce an early-exercise premium at all. These are American options, so every
implied volatility above is at the wrong level.

A width, though, is the difference of two inversions of two prices a cent apart under the
same model, so a bias that depends on the contract rather than on the side of the spread
should cancel. Rather than argue that, every leg was inverted a second time with an
American lattice: the near-the-money medians move by three hundredths of a basis point,
and no bucket moves by more than eight tenths. The level is biased and the width is not.

A liquid AAPL option is about 25 vol bp wide. That gives the rest of the post a scale: the
50 bp tolerance a pricing library is typically held to is two of those widths. A pricing
error inside 50 bp is smaller than the spread the option would actually trade across. That
50 bp is a working convention and not a published standard — it has never been validated
end to end, and doing so needs the downstream signals it feeds, which are outside this
work.

<figure>
<svg viewBox="0 0 720 312" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="What a basis point of implied volatility is worth">
<rect x="395.5" y="46" width="89.7" height="198" fill="currentColor" fill-opacity=".07"/>
<line x1="432.6" y1="46" x2="432.6" y2="244" stroke="currentColor" stroke-opacity=".45" stroke-dasharray="3 3"/>
<text x="432.6" y="22.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".70" font-family="var(--font-sans),system-ui,sans-serif">AAPL near-ATM market width</text><text x="432.6" y="36.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".50" font-family="var(--font-sans),system-ui,sans-serif">median 24 bp (IQR 16-44)</text><line x1="150.0" y1="46" x2="150.0" y2="244" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="150.0" y="262.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">1</text><line x1="247.2" y1="46" x2="247.2" y2="244" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="247.2" y="262.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">3</text><line x1="353.7" y1="46" x2="353.7" y2="244" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="353.7" y="262.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">10</text><line x1="450.9" y1="46" x2="450.9" y2="244" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="450.9" y="262.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">30</text><line x1="557.4" y1="46" x2="557.4" y2="244" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="557.4" y="262.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">100</text><line x1="654.6" y1="46" x2="654.6" y2="244" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="654.6" y="262.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">300</text><text x="415.0" y="296.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">error in implied-vol basis points (log scale)</text><text x="138.0" y="74.8" text-anchor="end" font-size="12" font-weight="400" fill="currentColor" fill-opacity=".85" font-family="var(--font-sans),system-ui,sans-serif">30d ATM</text><circle cx="353.7" cy="70.8" r="4.5" fill="var(--color-accent)" fill-opacity=".85"/>
<circle cx="557.4" cy="70.8" r="4.5" fill="var(--color-accent)" fill-opacity=".35"/>
<line x1="353.7" y1="70.8" x2="557.4" y2="70.8" stroke="var(--color-accent)" stroke-opacity=".35" stroke-width="1.5"/>
<text x="676.0" y="64.8" text-anchor="end" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".60" font-family="var(--font-sans),system-ui,sans-serif">1.1c  |  11.4c = 3.8% of premium</text><text x="138.0" y="124.2" text-anchor="end" font-size="12" font-weight="400" fill="currentColor" fill-opacity=".85" font-family="var(--font-sans),system-ui,sans-serif">1y ATM</text><circle cx="353.7" cy="120.2" r="4.5" fill="var(--color-accent)" fill-opacity=".85"/>
<circle cx="557.4" cy="120.2" r="4.5" fill="var(--color-accent)" fill-opacity=".35"/>
<line x1="353.7" y1="120.2" x2="557.4" y2="120.2" stroke="var(--color-accent)" stroke-opacity=".35" stroke-width="1.5"/>
<text x="676.0" y="114.2" text-anchor="end" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".60" font-family="var(--font-sans),system-ui,sans-serif">3.8c  |  38.3c = 3.2% of premium</text><text x="138.0" y="173.8" text-anchor="end" font-size="12" font-weight="400" fill="currentColor" fill-opacity=".85" font-family="var(--font-sans),system-ui,sans-serif">30d 25-delta put</text><circle cx="353.7" cy="169.8" r="4.5" fill="var(--color-accent)" fill-opacity=".85"/>
<circle cx="557.4" cy="169.8" r="4.5" fill="var(--color-accent)" fill-opacity=".35"/>
<line x1="353.7" y1="169.8" x2="557.4" y2="169.8" stroke="var(--color-accent)" stroke-opacity=".35" stroke-width="1.5"/>
<text x="676.0" y="163.8" text-anchor="end" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".60" font-family="var(--font-sans),system-ui,sans-serif">0.6c  |  6.1c = 11.1% of premium</text><text x="138.0" y="223.2" text-anchor="end" font-size="12" font-weight="400" fill="currentColor" fill-opacity=".85" font-family="var(--font-sans),system-ui,sans-serif">2y deep-ITM put</text><circle cx="353.7" cy="219.2" r="4.5" fill="var(--color-accent)" fill-opacity=".85"/>
<circle cx="557.4" cy="219.2" r="4.5" fill="var(--color-accent)" fill-opacity=".35"/>
<line x1="353.7" y1="219.2" x2="557.4" y2="219.2" stroke="var(--color-accent)" stroke-opacity=".35" stroke-width="1.5"/>
<text x="676.0" y="213.2" text-anchor="end" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".60" font-family="var(--font-sans),system-ui,sans-serif">4.9c  |  48.5c = 1.4% of premium</text><line x1="150" y1="244" x2="680" y2="244" stroke="currentColor" stroke-opacity=".28" stroke-width="1"/>
<text x="353.7" y="280.0" text-anchor="middle" font-size="10.5" font-weight="400" fill="currentColor" fill-opacity=".80" font-family="var(--font-sans),system-ui,sans-serif">10 bp</text><text x="557.4" y="280.0" text-anchor="middle" font-size="10.5" font-weight="400" fill="currentColor" fill-opacity=".45" font-family="var(--font-sans),system-ui,sans-serif">100 bp</text>
</svg>
<figcaption>The same error, three ways. Each row is one contract; the large dot marks 10 bp of implied volatility and the small dot 100 bp, with the cash value and share of premium at the right. The shaded band is the AAPL near-ATM bid-ask width, for scale.</figcaption>
</figure>

{{% callout label="Careful" variant="warning" %}}
Every error quoted **in vol basis points** below filters to `vega > 0.1`, because dividing
by a vanishing vega turns a small price error into an enormous volatility one. In practice
that guard almost never fires: across every grid in this post it removes four
contract-settings out of 1,944, all in one corner where a thirty-day option fifteen
percent out of the money is priced at twenty percent volatility. The shortest-dated
dividend cases, where the worry would be reasonable, survive intact — a seven-day option
struck at 111 on a spot of 100 still has vega of 0.15.

The real limitation is not the filter but the grids themselves, which stay within about
fifteen percent of the money and never visit the deep wings. Push that same seven-day
option out to a strike of 140 and its vega is effectively zero, so nothing in this post
speaks to those contracts — and they carry real listed volume. Tables quoted as a
percentage of value are not filtered at all, since they never divide by vega.
{{% /callout %}}

## The reference problem

Since there is no closed form, every accuracy claim depends on the reference being right,
and a reference that shares a failure mode with the method it scores will confirm that
method's error instead of exposing it. The only defence is to require agreement between
methods that have structurally nothing in common.

Three families are used throughout, chosen for how little they share:

- a **Leisen–Reimer lattice**{{< cite leisen1996 >}}{{< cite peizer1968 >}} with a Vellekoop–Nieuwenhuis dividend jump{{< cite vellekoop2006 >}} — discrete in time and state, backward induction over a tree;
- **Crank–Nicolson finite differences** with a Rannacher startup{{< cite rannacher1984 >}} and a Brennan–Schwartz free-boundary solve{{< cite brennan1977 >}} — a PDE on a grid;
- **direct quadrature**, which is exact, and is available in exactly one place.

That last one is the anchor. At $r = 0$ with $q \ge 0$ a put is never exercised early, so
the American price equals the European price — and the European price under a jumping
stock can be integrated directly, because conditional on the ex-date spot the terminal
price is lognormal and the inner expectation is closed-form Black–Scholes. One dimension
of quadrature remains, and it converges.

Set against each other over 216 dividend cases, the tree and the grid agree to a median of
**0.032 vol bp**, and their worst disagreement anywhere is under four tenths of a basis point.

*▸ computed by `experiments.jl` → `results/oracle_lattice_vs_fd.csv`. IQR 0.010–0.049, max 0.366. Grid: calls and puts, tenors 30/91/182/365d, dividends of 0.5/1/2% of spot at 0.25/0.6/0.85 of the option's life, S/K ∈ {0.90, 1.0, 1.10}, r = 4%, q = 0, σ = 28%; lattice n = 4001 against finite differences at 2400×1200.*

Scored against the exact quadrature, both land in the same neighbourhood: a median of six
thousandths of a basis point for the lattice and fourteen thousandths for the grid, with
neither above six hundredths anywhere in the grid of cases. The figure below shows the
whole distribution rather than a point estimate, because two medians that close say very
little on their own. Three constructions sharing no machinery agree with a closed-form
answer, and with each other, far inside anything the rest of the post needs to resolve.

<figure>
<svg viewBox="0 0 720 236" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Lattice and finite-difference error against the exact quadrature answer">
<line x1="132.0" y1="44" x2="132.0" y2="180" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="132.0" y="198.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">0.0001</text><line x1="297.3" y1="44" x2="297.3" y2="180" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="297.3" y="198.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">0.001</text><line x1="462.7" y1="44" x2="462.7" y2="180" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="462.7" y="198.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">0.01</text><line x1="628.0" y1="44" x2="628.0" y2="180" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="628.0" y="198.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">0.1</text><text x="120.0" y="82.0" text-anchor="end" font-size="12" font-weight="400" fill="currentColor" fill-opacity=".85" font-family="var(--font-sans),system-ui,sans-serif">lattice</text><circle cx="185.3" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="190.1" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="215.1" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="224.9" cy="79.6" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="229.1" cy="81.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="265.3" cy="82.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="288.0" cy="73.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="288.4" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="292.7" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="307.5" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="308.7" cy="79.6" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="309.4" cy="81.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="312.4" cy="82.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="321.4" cy="73.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="340.8" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="341.7" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="343.2" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="343.3" cy="79.6" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="343.9" cy="81.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="353.3" cy="82.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="361.3" cy="73.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="361.5" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="362.0" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="366.5" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="367.9" cy="79.6" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="371.0" cy="81.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="371.6" cy="82.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="373.1" cy="73.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="373.9" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="377.2" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="382.0" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="388.1" cy="79.6" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="391.2" cy="81.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="395.5" cy="82.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="395.7" cy="73.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="396.1" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="396.2" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="397.4" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="398.1" cy="79.6" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="399.7" cy="81.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="400.9" cy="82.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="404.8" cy="73.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="405.4" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="412.7" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="413.4" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="413.6" cy="79.6" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="416.3" cy="81.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="417.5" cy="82.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="418.9" cy="73.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="422.5" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="422.8" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="424.6" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="424.6" cy="79.6" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="424.9" cy="81.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="426.1" cy="82.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="426.3" cy="73.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="428.1" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="432.0" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="432.7" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="441.3" cy="79.6" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="442.3" cy="81.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="446.3" cy="82.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="446.5" cy="73.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="446.7" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="447.2" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="447.2" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="448.2" cy="79.6" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="450.0" cy="81.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="451.2" cy="82.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="454.1" cy="73.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="455.9" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="457.6" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="460.3" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="464.0" cy="79.6" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="464.7" cy="81.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="471.5" cy="82.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="473.3" cy="73.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="474.7" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="474.9" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="476.0" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="476.1" cy="79.6" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="477.3" cy="81.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="478.0" cy="82.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="478.1" cy="73.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="486.5" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="491.2" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="492.1" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="493.0" cy="79.6" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="494.4" cy="81.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="497.0" cy="82.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="498.4" cy="73.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="500.1" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="504.2" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="505.7" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="507.3" cy="79.6" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="510.4" cy="81.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="514.1" cy="82.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="516.4" cy="73.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="522.2" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="525.3" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="529.7" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="529.7" cy="79.6" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="538.1" cy="81.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="540.8" cy="82.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="544.3" cy="73.2" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="569.9" cy="74.8" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="582.9" cy="76.4" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<circle cx="591.2" cy="78.0" r="1.6" fill="var(--color-accent)" fill-opacity=".16"/>
<line x1="185.3" y1="78.0" x2="591.2" y2="78.0" stroke="var(--color-accent)" stroke-opacity=".30" stroke-width="1.2"/>
<rect x="372.7" y="69.0" width="103.7" height="18" fill="var(--color-accent)" fill-opacity=".16" stroke="var(--color-accent)" stroke-opacity=".35"/>
<line x1="425.5" y1="67.0" x2="425.5" y2="89.0" stroke="var(--color-accent)" stroke-opacity=".95" stroke-width="2.4"/>
<text x="636.0" y="82.0" text-anchor="start" font-size="10.5" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">median 0.006</text><text x="120.0" y="150.0" text-anchor="end" font-size="12" font-weight="400" fill="currentColor" fill-opacity=".85" font-family="var(--font-sans),system-ui,sans-serif">finite differences</text><circle cx="349.6" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="353.6" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="356.2" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="396.0" cy="147.6" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="397.1" cy="149.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="397.8" cy="150.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="410.3" cy="141.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="410.7" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="411.0" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="446.4" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="446.6" cy="147.6" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="446.7" cy="149.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="452.4" cy="150.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="452.8" cy="141.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="453.0" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="462.3" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="462.7" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="463.0" cy="147.6" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="465.7" cy="149.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="466.1" cy="150.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="466.4" cy="141.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="469.7" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="469.9" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="470.0" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="471.6" cy="147.6" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="471.6" cy="149.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="471.7" cy="150.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="477.9" cy="141.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="477.9" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="477.9" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="479.2" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="479.2" cy="147.6" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="479.2" cy="149.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="479.3" cy="150.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="479.4" cy="141.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="479.5" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="481.0" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="481.0" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="481.1" cy="147.6" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="481.5" cy="149.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="481.5" cy="150.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="481.5" cy="141.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="481.8" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="481.8" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="481.8" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="484.7" cy="147.6" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="484.7" cy="149.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="484.8" cy="150.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="485.2" cy="141.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="485.3" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="485.3" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="486.1" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="486.2" cy="147.6" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="486.3" cy="149.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="486.3" cy="150.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="486.3" cy="141.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="486.3" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="486.4" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="486.4" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="486.5" cy="147.6" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="487.1" cy="149.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="487.1" cy="150.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="487.1" cy="141.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="487.5" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="487.5" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="487.5" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="487.6" cy="147.6" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="487.7" cy="149.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="487.8" cy="150.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="488.0" cy="141.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="488.1" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="488.1" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="488.1" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="488.3" cy="147.6" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="488.5" cy="149.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="488.7" cy="150.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="488.8" cy="141.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="488.9" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.0" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.0" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.0" cy="147.6" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.0" cy="149.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.1" cy="150.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.1" cy="141.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.2" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.3" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.4" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.4" cy="147.6" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.5" cy="149.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.5" cy="150.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.6" cy="141.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.7" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.8" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.8" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.8" cy="147.6" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.9" cy="149.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="489.9" cy="150.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="490.0" cy="141.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="490.0" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="491.0" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="491.2" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="491.3" cy="147.6" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="491.3" cy="149.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="491.4" cy="150.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="491.5" cy="141.2" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="491.5" cy="142.8" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="491.5" cy="144.4" r="1.6" fill="currentColor" fill-opacity=".16"/>
<circle cx="491.6" cy="146.0" r="1.6" fill="currentColor" fill-opacity=".16"/>
<line x1="349.6" y1="146.0" x2="491.6" y2="146.0" stroke="currentColor" stroke-opacity=".30" stroke-width="1.2"/>
<rect x="476.4" y="137.0" width="12.6" height="18" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-opacity=".35"/>
<line x1="486.3" y1="135.0" x2="486.3" y2="157.0" stroke="currentColor" stroke-opacity=".62" stroke-width="2.4"/>
<text x="636.0" y="150.0" text-anchor="start" font-size="10.5" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">median 0.014</text><line x1="132" y1="180" x2="628" y2="180" stroke="currentColor" stroke-opacity=".28" stroke-width="1"/>
<text x="380.0" y="218.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">error against the exact answer, implied-vol basis points (log scale)</text><text x="132.0" y="28.0" text-anchor="start" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".50" font-family="var(--font-sans),system-ui,sans-serif">each dot is one of 108 contracts; box is the interquartile range</text>
</svg>
<figcaption>Error against the exact quadrature answer, one dot per contract, on 108 cases where an exact answer exists. Box is the interquartile range, vertical rule the median. Reference resolutions: lattice <em>n</em> = 4001 against finite differences at 2400×1200. Grid: puts, tenors 30d/91d/182d/365d, dividends of 0.5/1/2% of spot at 0.25/0.6/0.85 of the option's life, S/K ∈ {0.90, 1.0, 1.10}, r = 0, q = 0, σ = 28%.</figcaption>
</figure>

Two further figures come from the larger study behind this series; the code here does not
reproduce them. QuantLib's converged `QdFpAmericanEngine` against an independent lattice
over several thousand options puts agreement at roughly
**a quarter of a basis point** at the p95{{< cite quantlib >}}, and a lattice-versus-grid
comparison over a larger dividend book lands around half a basis point.

Those are larger than the hundredths above because they measure something else: agreement
at production settings across a real book, where tenors are short, dividends stack, and
resolution is bounded by what a risk run can afford. That is the number a working system
has to live inside.

One caveat on the QuantLib figure: that engine shares an analytic family with some of the
methods it scores, so a method from that family landing under it is indistinguishable from
the reference, not better than it.

Three methods picked by one person from one literature can still share a blind spot. The
last check is external: pricing the setup from Healy §4.13 — a
three-month option on a stock paying a 7% dividend at forty days — under four different
dividend models and comparing against the published values.

| model | call | put |
| --- | ---: | ---: |
| European (Black) | 3.376221 | 8.891463 |
| constant yield | 3.999857 | 8.891463 |
| proportional jump | 4.744395 | 9.139853 |
| cash jump, calibrated | 4.563931 | 9.153993 |

*▸ computed by `experiments.jl` → `results/dividend_models.csv`. All four rows reproduce the values published for this setup{{< cite healy2025 >}}. Two adjustments make the comparison mean anything. The cash dividend is 7.05, not 7.00, so that it takes the same amount out of the forward as a 7% proportional drop at day forty does; and the cash model's volatility is calibrated to 29.03% so that the two models agree on the European price. Without both, most of what gets measured is the gap between two calibrations.*

The finite-difference settings that make the grid a credible reference — the domain width,
the Rannacher damping, the treatment below the lower boundary, the choice of free-boundary
solver — are the subject of part 3, and are taken on trust here.

## What early exercise is worth

Use Black–Scholes on an American option and the result is the European price, short by
whatever the right to exercise early is worth. Measured against the reference just
described, across a grid spanning interest rates, dividend yields, moneyness, tenors and
volatilities, that premium behaves very differently depending on which corner of the grid
the contract sits in. Two of those corners are set by the interest rate $r$ and the
continuous dividend yield $q$:

| class | median | p95 | max | n |
| --- | ---: | ---: | ---: | ---: |
| call, $q = 0$ | 0.0000% | 0.000% | 0.00% | 96 |
| call, $q > 0$ | 0.746% | 13.41% | 53.19% | 288 |
| put, $r = 0$ | 0.0000% | 0.000% | 0.00% | 96 |
| put, $r > 0$ | 0.781% | 13.94% | 56.52% | 288 |

*▸ computed by `experiments.jl` → `results/premium_map.csv`. Premium as a percentage of the European price. Grid: r, q ∈ {0, 2, 4, 8}%, S/K ∈ {0.85, 1.0, 1.15}, tenors 30d–2y, σ ∈ {20%, 40%}.*

In volatility terms the two live classes run to medians in the low twenties of basis
points, with p95s of roughly seven hundred on the call side and a thousand on the put —
many times the width of the market, and concentrated in a way the medians hide. The more
useful observation is in the other two rows, where the premium is not small but
*exactly zero*.

## Puts are a rate story, calls are a dividend story

That is not a numerical artifact. Two identities produce it, and between them they
organise the rest of the series.

A call is never worth exercising early when $q \le 0$ and $q \le r$ — the classical result
for a non-dividend-paying stock{{< cite merton1973 >}}. A put is never worth exercising
early when $r \le 0$ and $r \le q$, which follows from the first by the McDonald–Schroder
symmetry $V_{\text{call}}(S,K,r,q) = V_{\text{put}}(K,S,q,r)${{< cite mcdonald1998 >}}.
The second condition in each pair only binds at negative rates: at $r \ge 0$ a call with
$q \le 0$ satisfies $q \le r$ automatically, which is why the textbook version drops it.

Checked rather than assumed, over 240 contracts per identity spanning moneyness, tenors
from a month to two years and volatilities from fifteen to sixty percent, the largest
premium found anywhere came to less than a thousandth of a basis point. That residual is
the lattice's own discretisation noise: it shrinks with step count and does not scale with
$r$ or $q$.

*▸ computed by `experiments.jl` → `results/exactness.csv`. Both identities, 240 contracts each: S/K ∈ {0.7, 0.85, 1.0, 1.15, 1.4}, tenors 30/91/365/730d, σ ∈ {15, 30, 60}%, and the free parameter over {0, 2, 5, 8}%. Lattice n = 2001.*

So on a non-dividend-paying stock the American call *is* the European call, exactly, and
Black–Scholes is not an approximation but the answer. At zero rates the American put *is*
the European put, and the put's entire premium is interest on the strike that exercising
early would let you collect. The same book therefore behaves completely differently at 5%
rates than it did at 0%, and a call's premium exists only because of dividends. Two
different problems wearing one name — and the call's problem is where the model choice,
rather than the numerical method, decides the answer.

This series assumes non-negative rates throughout. Below zero an American put can have two
exercise boundaries rather than one, with exercise optimal between
them{{< cite battauz2015 >}}{{< cite healy2025 >}}, and nothing here applies.

## Then a dividend shows up

There are two ways to carry a dividend through a model, and they are not two
approximations of the same thing{{< cite healy2025 >}}. The **forward, or escrowed, model**
splits the share price in two: the present value of the dividends still to come, treated as
a known cash amount set aside, and the rest, which is assumed lognormal. The name is the
idea — the dividend is held in escrow and only the remainder is allowed to move. Because
that remainder is lognormal, the Black formula applies to it directly, which is the whole
appeal.

The **spot model** keeps the share price itself lognormal between ex-dates and makes it
drop by the dividend at each one, which is what actually happens.

The two agree only when every dividend is a fixed percentage of the share price rather than
a fixed cash amount. A percentage drop rescales the whole distribution and leaves its shape
alone; a fixed cash drop shifts it, and a two-dollar dividend is a far bigger event for a
twenty-dollar stock than for a two-hundred-dollar one. Real dividends are declared in cash,
so the two models disagree by construction, and the rest of this section is about how much
that costs.

Escrowing has a consequence that follows directly from the identity above — no dividends,
no early call exercise. It prices at
$S - \mathrm{PV}(D)$ with $q = 0$, and a call with $q = 0$ is never exercised early, so
the engine short-circuits to the European value. The approximation removes the
early-exercise feature it was meant to approximate:

| dividend (% of spot) | S/K | reference | escrowed | missed | as % |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 2% | 1.00 | 13.153346 | 13.037956 | 0.115390 | 0.88% |
| 4% | 1.00 | 12.230694 | 11.894653 | 0.336041 | 2.75% |
| 8% | 1.00 | 11.104628 | 9.764927 | 1.339700 | **12.06%** |
| 8% | 1.20 | 20.975415 | 17.943802 | 3.031613 | **14.45%** |

*▸ computed by `experiments.jl` → `results/escrowed_europeanises.csv`. American call, single cash dividend at mid-life, r = 5%, σ = 30%, T = 1.*

The escrowed price matches the European price at the escrowed spot to
$3.6\times10^{-8}$ — it *is* the European price. Which is also why two different escrowed
engines will agree with each other perfectly, and why that agreement is worth nothing as
evidence. Both are failing the same way.

### A constant yield gets the shape wrong

The more common approximation converts the dividend into a continuous yield chosen to
match the forward. To see what that costs without confounding it with a calibration gap,
the comparison has to be set up carefully: derive the yield that matches the cash
dividend's forward exactly, then calibrate the spot-model volatility so the two agree on
the *European* price. Whatever remains is early-exercise behaviour and nothing else.

| side | dividend | 30d | 91d | 365d |
| --- | ---: | ---: | ---: | ---: |
| call | 2% | 4.75% | 1.18% | −0.00% |
| call | 4% | 16.13% | 5.67% | 0.54% |
| call | 8% | **39.33%** | 19.37% | 4.30% |
| put | 2% | 0.94% | 1.89% | 1.66% |
| put | 4% | 1.03% | 2.02% | 3.45% |
| put | 8% | 1.18% | 2.23% | **5.37%** |

*▸ computed by `experiments.jl` → `results/constant_yield_regimes.csv`. Percentage of the option's value the constant-yield model misses, at S/K = 1.00, r = 5%, dividend at mid-life, nominal σ = 30% with the cash model calibrated to 28.7–29.7% per regime. Across all 27 regimes the call range is −1.2% to 39.5% and the put range 0.4% to 5.6%; a negative figure means the yield model overshoots the cash reference instead of falling short.*

The two sides move in opposite directions. A call's error is driven by dividend size and
collapses as the tenor lengthens — 39% of the option's value at 30 days on an 8% dividend,
down to 4% at a year. A put's error is small throughout and *grows* with tenor. Anyone
generalising from a single contract would get the sign of that tenor relationship wrong,
so a rule of thumb quoted without its grid says almost nothing.

The mechanism is structural, not numerical. Under a cash or proportional dividend,
exercising an American call early is optimal *only* at the ex-date, because capturing the
dividend is the only reason to do it. Under a constant yield the stock leaks value
continuously and exercise is optimal across a whole region of time. Different exercise
regions produce different prices, and no amount of grid resolution reconciles them.

<figure>
<svg viewBox="0 0 720 300" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Early-exercise boundary for an American call under three dividend models">
<line x1="56.0" y1="248" x2="243.3" y2="248" stroke="currentColor" stroke-opacity=".28" stroke-width="1"/>
<line x1="56.0" y1="34" x2="56.0" y2="248" stroke="currentColor" stroke-opacity=".28" stroke-width="1"/>
<line x1="138.4" y1="202.0" x2="138.4" y2="248" stroke="var(--color-accent)" stroke-opacity=".95" stroke-width="2.5"/>
<text x="149.7" y="20.0" text-anchor="middle" font-size="12" font-weight="600" fill="currentColor" fill-opacity=".85" font-family="var(--font-sans),system-ui,sans-serif">cash jump</text><text x="149.7" y="266.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">1 of 801 levels</text><text x="149.7" y="281.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".45" font-family="var(--font-sans),system-ui,sans-serif">(0.1% of the option's life)</text><line x1="269.3" y1="248" x2="456.7" y2="248" stroke="currentColor" stroke-opacity=".28" stroke-width="1"/>
<line x1="269.3" y1="34" x2="269.3" y2="248" stroke="currentColor" stroke-opacity=".28" stroke-width="1"/>
<line x1="351.8" y1="202.0" x2="351.8" y2="248" stroke="var(--color-accent)" stroke-opacity=".95" stroke-width="2.5"/>
<text x="363.0" y="20.0" text-anchor="middle" font-size="12" font-weight="600" fill="currentColor" fill-opacity=".85" font-family="var(--font-sans),system-ui,sans-serif">proportional jump</text><text x="363.0" y="266.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">1 of 801 levels</text><text x="363.0" y="281.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".45" font-family="var(--font-sans),system-ui,sans-serif">(0.1% of the option's life)</text><line x1="482.7" y1="248" x2="670.0" y2="248" stroke="currentColor" stroke-opacity=".28" stroke-width="1"/>
<line x1="482.7" y1="34" x2="482.7" y2="248" stroke="currentColor" stroke-opacity=".28" stroke-width="1"/>
<polyline points="488.3,54.8 488.5,46.2 488.8,54.8 489.0,46.2 489.2,54.8 489.5,46.2 489.7,54.8 489.9,46.2 490.2,54.8 490.4,46.2 490.6,54.8 490.9,46.2 491.1,54.8 491.3,46.2 491.6,54.8 491.8,46.2 492.0,54.8 492.3,46.2 492.5,54.8 492.7,46.2 493.0,54.8 493.2,46.2 493.4,54.8 493.7,46.2 493.9,54.8 494.1,46.2 494.4,54.8 494.6,46.2 494.8,54.8 495.1,46.2 495.3,54.8 495.5,46.2 495.8,54.8 496.0,46.2 496.2,54.8 496.5,46.2 496.7,54.8 497.0,46.2 497.2,54.8 497.4,46.2 497.7,54.8 497.9,46.2 498.1,54.8 498.4,46.2 498.6,54.8 498.8,46.2 499.1,54.8 499.3,46.2 499.5,54.8 499.8,46.2 500.0,54.8 500.2,46.2 500.5,54.8 500.7,46.2 500.9,54.8 501.2,46.2 501.4,54.8 501.6,46.2 501.9,54.8 502.1,46.2 502.3,54.8 502.6,46.2 502.8,54.8 503.0,46.2 503.3,54.8 503.5,46.2 503.7,54.8 504.0,46.2 504.2,54.8 504.4,46.2 504.7,54.8 504.9,46.2 505.1,54.8 505.4,46.2 505.6,54.8 505.8,46.2 506.1,54.8 506.3,46.2 506.6,54.8 506.8,46.2 507.0,54.8 507.3,46.2 507.5,54.8 507.7,63.4 508.0,54.8 508.2,63.4 508.4,54.8 508.7,63.4 508.9,54.8 509.1,63.4 509.4,54.8 509.6,63.4 509.8,54.8 510.1,63.4 510.3,54.8 510.5,63.4 510.8,54.8 511.0,63.4 511.2,54.8 511.5,63.4 511.7,54.8 511.9,63.4 512.2,54.8 512.4,63.4 512.6,54.8 512.9,63.4 513.1,54.8 513.3,63.4 513.6,54.8 513.8,63.4 514.0,54.8 514.3,63.4 514.5,54.8 514.7,63.4 515.0,54.8 515.2,63.4 515.5,54.8 515.7,63.4 515.9,54.8 516.2,63.4 516.4,54.8 516.6,63.4 516.9,54.8 517.1,63.4 517.3,54.8 517.6,63.4 517.8,54.8 518.0,63.4 518.3,54.8 518.5,63.4 518.7,54.8 519.0,63.4 519.2,54.8 519.4,63.4 519.7,54.8 519.9,63.4 520.1,54.8 520.4,63.4 520.6,54.8 520.8,63.4 521.1,54.8 521.3,63.4 521.5,54.8 521.8,63.4 522.0,54.8 522.2,63.4 522.5,54.8 522.7,63.4 522.9,54.8 523.2,63.4 523.4,54.8 523.6,63.4 523.9,54.8 524.1,63.4 524.3,54.8 524.6,63.4 524.8,54.8 525.1,63.4 525.3,54.8 525.5,63.4 525.8,54.8 526.0,63.4 526.2,54.8 526.5,63.4 526.7,54.8 526.9,63.4 527.2,54.8 527.4,63.4 527.6,54.8 527.9,63.4 528.1,54.8 528.3,63.4 528.6,54.8 528.8,63.4 529.0,54.8 529.3,63.4 529.5,54.8 529.7,63.4 530.0,54.8 530.2,63.4 530.4,54.8 530.7,63.4 530.9,54.8 531.1,63.4 531.4,54.8 531.6,63.4 531.8,54.8 532.1,63.4 532.3,54.8 532.5,63.4 532.8,54.8 533.0,63.4 533.2,54.8 533.5,63.4 533.7,54.8 533.9,63.4 534.2,54.8 534.4,63.4 534.7,54.8 534.9,63.4 535.1,54.8 535.4,63.4 535.6,54.8 535.8,63.4 536.1,54.8 536.3,63.4 536.5,71.9 536.8,63.4 537.0,71.9 537.2,63.4 537.5,71.9 537.7,63.4 537.9,71.9 538.2,63.4 538.4,71.9 538.6,63.4 538.9,71.9 539.1,63.4 539.3,71.9 539.6,63.4 539.8,71.9 540.0,63.4 540.3,71.9 540.5,63.4 540.7,71.9 541.0,63.4 541.2,71.9 541.4,63.4 541.7,71.9 541.9,63.4 542.1,71.9 542.4,63.4 542.6,71.9 542.8,63.4 543.1,71.9 543.3,63.4 543.6,71.9 543.8,63.4 544.0,71.9 544.3,63.4 544.5,71.9 544.7,63.4 545.0,71.9 545.2,63.4 545.4,71.9 545.7,63.4 545.9,71.9 546.1,63.4 546.4,71.9 546.6,63.4 546.8,71.9 547.1,63.4 547.3,71.9 547.5,63.4 547.8,71.9 548.0,63.4 548.2,71.9 548.5,63.4 548.7,71.9 548.9,63.4 549.2,71.9 549.4,63.4 549.6,71.9 549.9,63.4 550.1,71.9 550.3,63.4 550.6,71.9 550.8,63.4 551.0,71.9 551.3,63.4 551.5,71.9 551.7,63.4 552.0,71.9 552.2,63.4 552.4,71.9 552.7,63.4 552.9,71.9 553.2,63.4 553.4,71.9 553.6,63.4 553.9,71.9 554.1,63.4 554.3,71.9 554.6,63.4 554.8,71.9 555.0,63.4 555.3,71.9 555.5,63.4 555.7,71.9 556.0,63.4 556.2,71.9 556.4,63.4 556.7,71.9 556.9,63.4 557.1,71.9 557.4,63.4 557.6,71.9 557.8,63.4 558.1,71.9 558.3,63.4 558.5,71.9 558.8,63.4 559.0,71.9 559.2,63.4 559.5,71.9 559.7,80.4 559.9,71.9 560.2,80.4 560.4,71.9 560.6,80.4 560.9,71.9 561.1,80.4 561.3,71.9 561.6,80.4 561.8,71.9 562.0,80.4 562.3,71.9 562.5,80.4 562.8,71.9 563.0,80.4 563.2,71.9 563.5,80.4 563.7,71.9 563.9,80.4 564.2,71.9 564.4,80.4 564.6,71.9 564.9,80.4 565.1,71.9 565.3,80.4 565.6,71.9 565.8,80.4 566.0,71.9 566.3,80.4 566.5,71.9 566.7,80.4 567.0,71.9 567.2,80.4 567.4,71.9 567.7,80.4 567.9,71.9 568.1,80.4 568.4,71.9 568.6,80.4 568.8,71.9 569.1,80.4 569.3,71.9 569.5,80.4 569.8,71.9 570.0,80.4 570.2,71.9 570.5,80.4 570.7,71.9 570.9,80.4 571.2,71.9 571.4,80.4 571.7,71.9 571.9,80.4 572.1,71.9 572.4,80.4 572.6,71.9 572.8,80.4 573.1,71.9 573.3,80.4 573.5,71.9 573.8,80.4 574.0,71.9 574.2,80.4 574.5,71.9 574.7,80.4 574.9,71.9 575.2,80.4 575.4,71.9 575.6,80.4 575.9,71.9 576.1,80.4 576.3,71.9 576.6,80.4 576.8,71.9 577.0,80.4 577.3,71.9 577.5,80.4 577.7,71.9 578.0,80.4 578.2,71.9 578.4,80.4 578.7,71.9 578.9,80.4 579.1,88.8 579.4,80.4 579.6,88.8 579.8,80.4 580.1,88.8 580.3,80.4 580.5,88.8 580.8,80.4 581.0,88.8 581.3,80.4 581.5,88.8 581.7,80.4 582.0,88.8 582.2,80.4 582.4,88.8 582.7,80.4 582.9,88.8 583.1,80.4 583.4,88.8 583.6,80.4 583.8,88.8 584.1,80.4 584.3,88.8 584.5,80.4 584.8,88.8 585.0,80.4 585.2,88.8 585.5,80.4 585.7,88.8 585.9,80.4 586.2,88.8 586.4,80.4 586.6,88.8 586.9,80.4 587.1,88.8 587.3,80.4 587.6,88.8 587.8,80.4 588.0,88.8 588.3,80.4 588.5,88.8 588.7,80.4 589.0,88.8 589.2,80.4 589.4,88.8 589.7,80.4 589.9,88.8 590.1,80.4 590.4,88.8 590.6,80.4 590.9,88.8 591.1,80.4 591.3,88.8 591.6,80.4 591.8,88.8 592.0,80.4 592.3,88.8 592.5,80.4 592.7,88.8 593.0,80.4 593.2,88.8 593.4,80.4 593.7,88.8 593.9,80.4 594.1,88.8 594.4,80.4 594.6,88.8 594.8,80.4 595.1,88.8 595.3,97.1 595.5,88.8 595.8,97.1 596.0,88.8 596.2,97.1 596.5,88.8 596.7,97.1 596.9,88.8 597.2,97.1 597.4,88.8 597.6,97.1 597.9,88.8 598.1,97.1 598.3,88.8 598.6,97.1 598.8,88.8 599.0,97.1 599.3,88.8 599.5,97.1 599.8,88.8 600.0,97.1 600.2,88.8 600.5,97.1 600.7,88.8 600.9,97.1 601.2,88.8 601.4,97.1 601.6,88.8 601.9,97.1 602.1,88.8 602.3,97.1 602.6,88.8 602.8,97.1 603.0,88.8 603.3,97.1 603.5,88.8 603.7,97.1 604.0,88.8 604.2,97.1 604.4,88.8 604.7,97.1 604.9,88.8 605.1,97.1 605.4,88.8 605.6,97.1 605.8,88.8 606.1,97.1 606.3,88.8 606.5,97.1 606.8,88.8 607.0,97.1 607.2,88.8 607.5,97.2 607.7,88.8 607.9,97.2 608.2,88.8 608.4,97.2 608.6,105.5 608.9,97.2 609.1,105.5 609.4,97.2 609.6,105.5 609.8,97.2 610.1,105.5 610.3,97.2 610.5,105.5 610.8,97.2 611.0,105.5 611.2,97.2 611.5,105.5 611.7,97.2 611.9,105.5 612.2,97.2 612.4,105.5 612.6,97.2 612.9,105.5 613.1,97.2 613.3,105.5 613.6,97.2 613.8,105.5 614.0,97.2 614.3,105.5 614.5,97.2 614.7,105.5 615.0,97.2 615.2,105.5 615.4,97.2 615.7,105.5 615.9,97.2 616.1,105.5 616.4,97.2 616.6,105.5 616.8,97.2 617.1,105.5 617.3,97.2 617.5,105.5 617.8,97.2 618.0,105.5 618.2,97.2 618.5,105.5 618.7,97.2 619.0,105.5 619.2,97.2 619.4,105.5 619.7,113.8 619.9,105.5 620.1,113.8 620.4,105.5 620.6,113.8 620.8,105.5 621.1,113.8 621.3,105.5 621.5,113.8 621.8,105.5 622.0,113.8 622.2,105.5 622.5,113.8 622.7,105.5 622.9,113.8 623.2,105.5 623.4,113.8 623.6,105.5 623.9,113.8 624.1,105.5 624.3,113.8 624.6,105.5 624.8,113.8 625.0,105.5 625.3,113.8 625.5,105.5 625.7,113.8 626.0,105.5 626.2,113.8 626.4,105.5 626.7,113.8 626.9,105.5 627.1,113.8 627.4,105.5 627.6,113.8 627.9,105.5 628.1,113.8 628.3,105.5 628.6,113.8 628.8,105.5 629.0,113.8 629.3,122.0 629.5,113.8 629.7,122.0 630.0,113.8 630.2,122.0 630.4,113.8 630.7,122.0 630.9,113.8 631.1,122.0 631.4,113.8 631.6,122.0 631.8,113.8 632.1,122.0 632.3,113.8 632.5,122.0 632.8,113.8 633.0,122.0 633.2,113.8 633.5,122.0 633.7,113.8 633.9,122.0 634.2,113.8 634.4,122.0 634.6,113.8 634.9,122.0 635.1,113.8 635.3,122.0 635.6,113.8 635.8,122.0 636.0,113.8 636.3,122.0 636.5,113.8 636.7,122.0 637.0,130.2 637.2,122.0 637.5,130.2 637.7,122.0 637.9,130.2 638.2,122.0 638.4,130.2 638.6,122.0 638.9,130.2 639.1,122.0 639.3,130.2 639.6,122.0 639.8,130.2 640.0,122.0 640.3,130.2 640.5,122.0 640.7,130.2 641.0,122.0 641.2,130.2 641.4,122.0 641.7,130.2 641.9,122.0 642.1,130.2 642.4,122.0 642.6,130.2 642.8,122.0 643.1,130.2 643.3,138.3 643.5,130.2 643.8,138.3 644.0,130.2 644.2,138.3 644.5,130.2 644.7,138.3 644.9,130.2 645.2,138.3 645.4,130.2 645.6,138.3 645.9,130.2 646.1,138.3 646.3,130.2 646.6,138.4 646.8,130.2 647.1,138.4 647.3,130.2 647.5,138.4 647.8,130.2 648.0,138.4 648.2,130.2 648.5,138.4 648.7,130.2 648.9,138.4 649.2,146.5 649.4,138.4 649.6,146.5 649.9,138.4 650.1,146.5 650.3,138.4 650.6,146.5 650.8,138.4 651.0,146.5 651.3,138.4 651.5,146.5 651.7,138.4 652.0,146.5 652.2,138.4 652.4,146.5 652.7,138.4 652.9,146.5 653.1,138.4 653.4,146.5 653.6,154.5 653.8,146.5 654.1,154.5 654.3,146.5 654.5,154.5 654.8,146.5 655.0,154.5 655.2,146.5 655.5,154.5 655.7,146.5 656.0,154.5 656.2,146.5 656.4,154.5 656.7,146.5 656.9,154.5 657.1,162.5 657.4,154.5 657.6,162.5 657.8,154.5 658.1,162.5 658.3,154.5 658.5,162.5 658.8,154.5 659.0,162.5 659.2,154.5 659.5,162.5 659.7,154.5 659.9,162.5 660.2,170.5 660.4,162.5 660.6,170.5 660.9,162.5 661.1,170.5 661.3,162.5 661.6,170.5 661.8,162.5 662.0,170.5 662.3,162.5 662.5,170.5 662.7,178.5 663.0,170.5 663.2,178.5 663.4,170.5 663.7,178.5 663.9,170.5 664.1,178.5 664.4,170.5 664.6,178.5 664.8,186.4 665.1,178.5 665.3,186.4 665.6,178.5 665.8,186.4 666.0,178.5 666.3,186.4 666.5,194.2 666.7,186.4 667.0,194.2 667.2,186.4 667.4,194.2 667.7,202.0 667.9,194.2 668.1,202.0 668.4,194.2 668.6,202.0 668.8,209.8 669.1,202.0 669.3,209.8 669.5,217.5 669.8,225.2 670.0,232.9" fill="none" stroke="currentColor" stroke-opacity=".45" stroke-width="2" stroke-linejoin="round"/>
<text x="576.3" y="20.0" text-anchor="middle" font-size="12" font-weight="600" fill="currentColor" fill-opacity=".85" font-family="var(--font-sans),system-ui,sans-serif">constant yield</text><text x="576.3" y="266.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">777 of 801 levels</text><text x="576.3" y="281.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".45" font-family="var(--font-sans),system-ui,sans-serif">(97% of the option's life)</text><text x="48.0" y="40.0" text-anchor="end" font-size="10" font-weight="400" fill="currentColor" fill-opacity=".45" font-family="var(--font-sans),system-ui,sans-serif">115</text><text x="48.0" y="248.0" text-anchor="end" font-size="10" font-weight="400" fill="currentColor" fill-opacity=".45" font-family="var(--font-sans),system-ui,sans-serif">100</text><text x="20.0" y="141.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">S</text>
</svg>
<figcaption>Where early exercise of an American call is optimal, under three dividend models sharing a forward and a total dividend present value. Cash and proportional dividends make exercise optimal at a single instant; a constant yield makes it optimal across almost the whole life. Grid: 801-step tree, S = K = 100, r = 6%, σ = 30%, 7% dividend at 40/365.</figcaption>
</figure>

Counted directly on an 801-step tree, the cash and proportional models put the exercise
region at a single time level out of 801. The constant-yield model puts it at 777 of them.

### Switching models manufactures a smile

European put-call parity holds under both the cash and the proportional model with the
same forward, so a volatility reproducing the European call reproduces the European put
automatically — measured gap, $6\times10^{-15}$. On European prices the calibration is
unambiguous.

Parity does not hold for American options, and that is where the ambiguity lives. Taking
cash-dividend American prices as truth and asking what volatility the proportional model
needs to reproduce them:

| strike | call vol | put vol | gap |
| ---: | ---: | ---: | ---: |
| 50 | 28.168% | 31.380% | **3.212 pts** |
| 75 | 28.868% | 31.270% | 2.402 pts |
| 100 | 29.886% | 31.240% | 1.354 pts |
| 125 | 30.615% | 31.232% | 0.616 pts |
| 150 | 30.884% | 31.222% | 0.338 pts |

*▸ computed by `experiments.jl` → `results/model_implied_vol.csv`. S = 100, r = 6%, a cash dividend of 7 — seven percent of spot — at t = 0.5, T = 1, nominal σ = 30%.*

The put volatility is nearly flat, moving 0.158 points across the whole strike range. The
call volatility slopes by 2.72 points, and the two disagree by up to 3.2 points at the
same strike. Moving between two dividend models that agree on the forward produces a
smile out of nothing at all.

## What smearing a dividend actually costs

The model matters, then. The next question is how much, and the answer depends on how
badly the dividend has been flattened.

Both sides appear from here, which the identity above — a call's premium comes from
dividends, a put's from the rate — might seem to forbid. It does not. That identity governs
what *creates* an early-exercise premium — dividends for a call, the
interest rate for a put — not what moves a price. A dividend moves both sides regardless
of exercise, and mis-specifying it does two separable things. It changes the terminal
distribution even when the forward is matched exactly, because a stock that drops once by
a fixed amount is not shaped like one bled down continuously; on European contracts, where
exercise cannot be involved, that alone costs 24 to 32 basis points at every tenor and
falls almost evenly on calls and puts. Separately, it changes the *size* of the put's
premium — the rate creates that premium, but the dividend path controls how large it gets.
The two premiums also run in opposite directions with tenor, the call's decaying as the
put's grows, crossing near six months; by one year the put's is three times the call's,
and smearing the dividend away destroys nearly two thirds of it.

*▸ computed by `experiments.jl` → `results/premium_under_smearing.csv`. European prices isolate the distribution effect, the premium columns isolate exercise. S = K = 100, r = 4%, q = 2%, σ = 28%, one dividend of 2% of spot at mid-life.*

The crudest version stores one dividend-yield number per name and applies it regardless of
tenor. Against the real schedule, for a stock paying 4% a year in quarterly instalments:

| tenor | scalar yield p95 | tenor-matched p95 | ratio |
| ---: | ---: | ---: | ---: |
| 7d | **2,942.5 bp** | 0.1 bp | 21,069× |
| 30d | 607.7 | 174.9 | 3.5× |
| 91d | 162.9 | 161.2 | 1.0× |
| 365d | 113.9 | 112.3 | 1.0× |

*▸ computed by `experiments.jl` → `results/scalar_vs_matched.csv`. Grid: calls and puts, S/K ∈ {0.9, 1.0, 1.1}, first ex-date at 0.02/0.10/0.20y, annual yield 2% and 4%, r = 4%, σ = 28%.*

Splitting by whether an ex-date actually falls inside the option's life makes the
mechanism obvious. At seven days with no ex-date in the window, the scalar yield is 2,942
bp wrong and the tenor-matched yield is 0.1 bp wrong: the flat annual number is charging
the option for dividends it will never see. By 91 days the distinction stops mattering,
since the window contains its dividend either way.

Matching the present value over the actual tenor removes that gross error and leaves a
subtler one. Holding the total PV fixed and comparing the schedule against the smeared
version, pooled across calls and puts:

| tenor | ex-date | schedule | yield, on a tree | yield, on a grid |
| ---: | ---: | ---: | ---: | ---: |
| 30d | 0.15T | 1.8 / 20.4 | 18.7 / 2137.2 | 19.0 / 2137.2 |
| 30d | 0.85T | 3.6 / 18.5 | 140.0 / 962.3 | 141.7 / 962.3 |
| 91d | 0.50T | 1.0 / 7.1 | 57.5 / 481.5 | 58.0 / 479.9 |
| 730d | 0.50T | 0.7 / 4.3 | 23.1 / 60.8 | 23.4 / 61.1 |

*▸ computed by `experiments.jl` → `results/smearing_shape.csv`. Median / p95 vol bp. Grid: calls and puts, S/K ∈ {0.85, 1.0, 1.15}, r ∈ {0, 4, 8}%, q = 2%, one dividend of 2% of spot.*

The last two columns are the point. A tree and a grid share no machinery, and on a smeared
dividend they land within two basis points of each other — against a model error running
to 142. **Using a better pricer on a smeared dividend recovers nothing** — the loss is in
the model, and the numerical method has no access to it. This is why the order of the series
matters: fixing the dividend representation dominates every scheme decision that comes
after it.

Which side pays depends on the tenor, and on whether you are budgeting the median or the
tail:

| tenor | side | schedule | smeared | median penalty |
| ---: | --- | ---: | ---: | ---: |
| 30d | call | 0.9 / 3.4 | **122.7 / 700.6** | 140× |
| 30d | put | 0.2 / 3.2 | 48.0 / **1,395.6** | 295× |
| 91d | call | 0.6 / 2.3 | 91.9 / 446.4 | 153× |
| 91d | put | 0.1 / 0.6 | 54.4 / 301.2 | 646× |
| 365d | call | 0.2 / 1.6 | 25.2 / 155.2 | 126× |
| 365d | put | 0.1 / 1.0 | **52.3** / 122.3 | 550× |
| 730d | call | 0.2 / 0.9 | 20.6 / 91.0 | 108× |
| 730d | put | 0.2 / 1.3 | 41.8 / 69.3 | 273× |

*▸ computed by `experiments.jl` → `results/smearing_by_side.csv`. Median / p95 vol bp, engine held at a 401-step lattice. Grid: S/K ∈ {0.85, 0.95, 1.0, 1.05, 1.15}, r ∈ {0, 4, 8}%, q = 2%, one dividend of 2% of spot at 0.3/0.5/0.8 of the option's life.*

Read the smeared column, not the ratio. At the median a 30-day call loses 123 basis
points and a 30-day put 48, the call's loss decays with tenor while the put's grows, and
the two sides cross somewhere between three months and a year. The penalty column divides
that loss by the engine's own error, which is now a fraction of a basis point at every
tenor — so it measures how little the numerical method contributes, not which side is
worse, and the side comparison belongs to the column beside it.

At the p95 the ordering is different again: the single worst number in the table is a
30-day *put* at 1,396 bp, while calls are worse than puts at every tenor from 91 days out.
Pooled over tenors the calls lose more — 65 bp against 49 at the median — but no single
statistic makes this a call problem or a put problem, and picking one to quote decides the
answer before the reader sees it.

The mechanism is the same one the exercise-region plot showed. A short-dated call's entire
value sits inside the window the dividend distorts, while a long-dated put accumulates a
mis-specified carry across its whole life.

<figure>
<svg viewBox="0 0 720 300" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Median error from smearing a discrete dividend into a yield, by tenor and side">
<line x1="62" y1="248.0" x2="590" y2="248.0" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="52.0" y="252.0" text-anchor="end" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">0.01</text><line x1="62" y1="206.4" x2="590" y2="206.4" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="52.0" y="210.4" text-anchor="end" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">0.1</text><line x1="62" y1="164.8" x2="590" y2="164.8" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="52.0" y="168.8" text-anchor="end" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">1</text><line x1="62" y1="123.2" x2="590" y2="123.2" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="52.0" y="127.2" text-anchor="end" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">10</text><line x1="62" y1="81.6" x2="590" y2="81.6" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="52.0" y="85.6" text-anchor="end" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">100</text><text x="128.0" y="268.0" text-anchor="middle" font-size="11.5" font-weight="400" fill="currentColor" fill-opacity=".70" font-family="var(--font-sans),system-ui,sans-serif">30d</text><line x1="115.0" y1="167.2" x2="115.0" y2="77.9" stroke="var(--color-accent)" stroke-opacity=".25" stroke-width="6" stroke-linecap="round"/>
<circle cx="115.0" cy="167.2" r="3.5" fill="none" stroke="var(--color-accent)" stroke-opacity=".95" stroke-width="1.6"/>
<circle cx="115.0" cy="77.9" r="4.5" fill="var(--color-accent)" fill-opacity=".95"/>
<line x1="141.0" y1="197.6" x2="141.0" y2="94.9" stroke="currentColor" stroke-opacity=".25" stroke-width="6" stroke-linecap="round"/>
<circle cx="141.0" cy="197.6" r="3.5" fill="none" stroke="currentColor" stroke-opacity=".55" stroke-width="1.6"/>
<circle cx="141.0" cy="94.9" r="4.5" fill="currentColor" fill-opacity=".55"/>
<text x="260.0" y="268.0" text-anchor="middle" font-size="11.5" font-weight="400" fill="currentColor" fill-opacity=".70" font-family="var(--font-sans),system-ui,sans-serif">91d</text><line x1="247.0" y1="174.0" x2="247.0" y2="83.1" stroke="var(--color-accent)" stroke-opacity=".25" stroke-width="6" stroke-linecap="round"/>
<circle cx="247.0" cy="174.0" r="3.5" fill="none" stroke="var(--color-accent)" stroke-opacity=".95" stroke-width="1.6"/>
<circle cx="247.0" cy="83.1" r="4.5" fill="var(--color-accent)" fill-opacity=".95"/>
<line x1="273.0" y1="209.5" x2="273.0" y2="92.6" stroke="currentColor" stroke-opacity=".25" stroke-width="6" stroke-linecap="round"/>
<circle cx="273.0" cy="209.5" r="3.5" fill="none" stroke="currentColor" stroke-opacity=".55" stroke-width="1.6"/>
<circle cx="273.0" cy="92.6" r="4.5" fill="currentColor" fill-opacity=".55"/>
<text x="392.0" y="268.0" text-anchor="middle" font-size="11.5" font-weight="400" fill="currentColor" fill-opacity=".70" font-family="var(--font-sans),system-ui,sans-serif">365d</text><line x1="379.0" y1="193.9" x2="379.0" y2="106.5" stroke="var(--color-accent)" stroke-opacity=".25" stroke-width="6" stroke-linecap="round"/>
<circle cx="379.0" cy="193.9" r="3.5" fill="none" stroke="var(--color-accent)" stroke-opacity=".95" stroke-width="1.6"/>
<circle cx="379.0" cy="106.5" r="4.5" fill="var(--color-accent)" fill-opacity=".95"/>
<line x1="405.0" y1="207.3" x2="405.0" y2="93.3" stroke="currentColor" stroke-opacity=".25" stroke-width="6" stroke-linecap="round"/>
<circle cx="405.0" cy="207.3" r="3.5" fill="none" stroke="currentColor" stroke-opacity=".55" stroke-width="1.6"/>
<circle cx="405.0" cy="93.3" r="4.5" fill="currentColor" fill-opacity=".55"/>
<text x="524.0" y="268.0" text-anchor="middle" font-size="11.5" font-weight="400" fill="currentColor" fill-opacity=".70" font-family="var(--font-sans),system-ui,sans-serif">730d</text><line x1="511.0" y1="194.6" x2="511.0" y2="110.1" stroke="var(--color-accent)" stroke-opacity=".25" stroke-width="6" stroke-linecap="round"/>
<circle cx="511.0" cy="194.6" r="3.5" fill="none" stroke="var(--color-accent)" stroke-opacity=".95" stroke-width="1.6"/>
<circle cx="511.0" cy="110.1" r="4.5" fill="var(--color-accent)" fill-opacity=".95"/>
<line x1="537.0" y1="198.7" x2="537.0" y2="97.4" stroke="currentColor" stroke-opacity=".25" stroke-width="6" stroke-linecap="round"/>
<circle cx="537.0" cy="198.7" r="3.5" fill="none" stroke="currentColor" stroke-opacity=".55" stroke-width="1.6"/>
<circle cx="537.0" cy="97.4" r="4.5" fill="currentColor" fill-opacity=".55"/>
<line x1="62" y1="248" x2="590" y2="248" stroke="currentColor" stroke-opacity=".28" stroke-width="1"/>
<line x1="62" y1="40" x2="62" y2="248" stroke="currentColor" stroke-opacity=".28" stroke-width="1"/>
<circle cx="612" cy="56" r="4.5" fill="var(--color-accent)" fill-opacity=".95"/>
<text x="624.0" y="60.0" text-anchor="start" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".70" font-family="var(--font-sans),system-ui,sans-serif">call, smeared</text><circle cx="612" cy="76" r="4.5" fill="currentColor" fill-opacity=".55"/>
<text x="624.0" y="80.0" text-anchor="start" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".70" font-family="var(--font-sans),system-ui,sans-serif">put, smeared</text><circle cx="612" cy="96" r="3.5" fill="none" stroke="currentColor" stroke-opacity=".7" stroke-width="1.6"/>
<text x="624.0" y="100.0" text-anchor="start" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".70" font-family="var(--font-sans),system-ui,sans-serif">same, on the</text><text x="624.0" y="114.0" text-anchor="start" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".70" font-family="var(--font-sans),system-ui,sans-serif">real schedule</text><text x="52.0" y="28.0" text-anchor="end" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">vol bp</text>
</svg>
<figcaption>Median error from smearing, by tenor and side. Hollow markers are the same engine given the real dividend schedule; filled markers are the same engine given a present-value-matched yield.</figcaption>
</figure>

That leaves the question of whether a dividend can ever be small enough to drop:

| PV/S | ignore entirely | matched yield |
| ---: | ---: | ---: |
| 0.00% | 0.0 / 0.4 | 0.0 / 0.4 |
| 0.25% | 48.1 / 946.3 | 5.0 / 597.3 |
| 1.00% | 209.7 / 2,130.3 | 32.2 / 1,019.0 |
| 3.00% | 600.8 / 3,353.9 | 106.5 / 703.7 |

*▸ computed by `experiments.jl` → `results/pv_threshold.csv`. Median / p95 vol bp. Grid: calls and puts, S/K ∈ {0.85, 1.0, 1.15}, tenors 30d/91d/365d, σ ∈ {20%, 40%}, r = 4%, dividend at mid-life.*

It cannot. A quarter of one percent of spot — a rounding error of a dividend — already
costs 48 bp at the median and 946 in the tail, which is two ATM bid-ask widths and forty
of them respectively. Only exactly zero is safe, which makes the highest-value field in
the entire pipeline a boolean: whether an ex-date falls before expiry.

## The dividend forecast is worse than the pricer

Everything so far compared models against each other. The last comparison is between the
model and the data feeding it. Hold the engine completely fixed, give it a wrong dividend,
and score it against the same engine given the right one:

| input error | median | p95 |
| --- | ---: | ---: |
| **pricer error, correct dividend** | **0.2 bp** | **0.6 bp** |
| ex-date off by 1 week | 4.6 | 42.9 |
| ex-date off by 1 month | 20.0 | 186.0 |
| amount off by −10% | 27.0 | 171.4 |
| amount off by +10% | 27.1 | 171.0 |
| amount off by −25% | 67.3 | 426.8 |
| amount off by +25% | 67.0 | 429.1 |
| dividend suspended entirely | 277.3 | 1,662.0 |

*▸ computed by `experiments.jl` → `results/input_vs_pricer_error.csv`. Engine held at a 401-step lattice, pooled calls and puts. Grid: S/K ∈ {0.85, 1.0, 1.15}, tenors 91d and 365d, r ∈ {0, 4%}, q = 2%, σ = 28%, one dividend of 2% of spot at 0.4T. Over- and under-estimates are near-symmetric.*

<figure>
<svg viewBox="0 0 720 340" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Dividend input error against the pricer's own error">
<line x1="210.0" y1="30" x2="210.0" y2="290" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="210.0" y="308.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">0.1</text><line x1="312.3" y1="30" x2="312.3" y2="290" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="312.3" y="308.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">1</text><line x1="414.6" y1="30" x2="414.6" y2="290" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="414.6" y="308.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">10</text><line x1="517.0" y1="30" x2="517.0" y2="290" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="517.0" y="308.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">100</text><line x1="619.3" y1="30" x2="619.3" y2="290" stroke="currentColor" stroke-opacity=".10" stroke-width="1"/>
<text x="619.3" y="308.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">1000</text><line x1="234.2" y1="30" x2="234.2" y2="290" stroke="var(--color-accent)" stroke-opacity=".55" stroke-dasharray="4 3"/>
<text x="198.0" y="50.2" text-anchor="end" font-size="11.5" font-weight="600" fill="currentColor" fill-opacity=".95" font-family="var(--font-sans),system-ui,sans-serif">pricer error, correct dividend</text><line x1="234.2" y1="46.2" x2="289.3" y2="46.2" stroke="var(--color-accent)" stroke-opacity=".30" stroke-width="5" stroke-linecap="round"/>
<circle cx="234.2" cy="46.2" r="4.5" fill="var(--color-accent)" fill-opacity=".95"/>
<circle cx="289.3" cy="46.2" r="3" fill="var(--color-accent)" fill-opacity=".45"/>
<text x="666.0" y="50.2" text-anchor="start" font-size="10.5" font-weight="400" fill="currentColor" fill-opacity=".45" font-family="var(--font-sans),system-ui,sans-serif">1</text><text x="198.0" y="82.8" text-anchor="end" font-size="11.5" font-weight="400" fill="currentColor" fill-opacity=".78" font-family="var(--font-sans),system-ui,sans-serif">ex-date off by 1 week</text><line x1="379.8" y1="78.8" x2="479.4" y2="78.8" stroke="currentColor" stroke-opacity=".30" stroke-width="5" stroke-linecap="round"/>
<circle cx="379.8" cy="78.8" r="4.5" fill="currentColor" fill-opacity=".95"/>
<circle cx="479.4" cy="78.8" r="3" fill="currentColor" fill-opacity=".45"/>
<text x="666.0" y="82.8" text-anchor="start" font-size="10.5" font-weight="400" fill="currentColor" fill-opacity=".45" font-family="var(--font-sans),system-ui,sans-serif">43</text><text x="198.0" y="115.2" text-anchor="end" font-size="11.5" font-weight="400" fill="currentColor" fill-opacity=".78" font-family="var(--font-sans),system-ui,sans-serif">ex-date off by 1 month</text><line x1="445.5" y1="111.2" x2="544.5" y2="111.2" stroke="currentColor" stroke-opacity=".30" stroke-width="5" stroke-linecap="round"/>
<circle cx="445.5" cy="111.2" r="4.5" fill="currentColor" fill-opacity=".95"/>
<circle cx="544.5" cy="111.2" r="3" fill="currentColor" fill-opacity=".45"/>
<text x="666.0" y="115.2" text-anchor="start" font-size="10.5" font-weight="400" fill="currentColor" fill-opacity=".45" font-family="var(--font-sans),system-ui,sans-serif">186</text><text x="198.0" y="147.8" text-anchor="end" font-size="11.5" font-weight="400" fill="currentColor" fill-opacity=".78" font-family="var(--font-sans),system-ui,sans-serif">amount off by +10%</text><line x1="459.0" y1="143.8" x2="540.8" y2="143.8" stroke="currentColor" stroke-opacity=".30" stroke-width="5" stroke-linecap="round"/>
<circle cx="459.0" cy="143.8" r="4.5" fill="currentColor" fill-opacity=".95"/>
<circle cx="540.8" cy="143.8" r="3" fill="currentColor" fill-opacity=".45"/>
<text x="666.0" y="147.8" text-anchor="start" font-size="10.5" font-weight="400" fill="currentColor" fill-opacity=".45" font-family="var(--font-sans),system-ui,sans-serif">171</text><text x="198.0" y="180.2" text-anchor="end" font-size="11.5" font-weight="400" fill="currentColor" fill-opacity=".78" font-family="var(--font-sans),system-ui,sans-serif">amount off by -10%</text><line x1="458.8" y1="176.2" x2="540.9" y2="176.2" stroke="currentColor" stroke-opacity=".30" stroke-width="5" stroke-linecap="round"/>
<circle cx="458.8" cy="176.2" r="4.5" fill="currentColor" fill-opacity=".95"/>
<circle cx="540.9" cy="176.2" r="3" fill="currentColor" fill-opacity=".45"/>
<text x="666.0" y="180.2" text-anchor="start" font-size="10.5" font-weight="400" fill="currentColor" fill-opacity=".45" font-family="var(--font-sans),system-ui,sans-serif">171</text><text x="198.0" y="212.8" text-anchor="end" font-size="11.5" font-weight="400" fill="currentColor" fill-opacity=".78" font-family="var(--font-sans),system-ui,sans-serif">amount off by +25%</text><line x1="499.2" y1="208.8" x2="581.7" y2="208.8" stroke="currentColor" stroke-opacity=".30" stroke-width="5" stroke-linecap="round"/>
<circle cx="499.2" cy="208.8" r="4.5" fill="currentColor" fill-opacity=".95"/>
<circle cx="581.7" cy="208.8" r="3" fill="currentColor" fill-opacity=".45"/>
<text x="666.0" y="212.8" text-anchor="start" font-size="10.5" font-weight="400" fill="currentColor" fill-opacity=".45" font-family="var(--font-sans),system-ui,sans-serif">429</text><text x="198.0" y="245.2" text-anchor="end" font-size="11.5" font-weight="400" fill="currentColor" fill-opacity=".78" font-family="var(--font-sans),system-ui,sans-serif">amount off by -25%</text><line x1="499.3" y1="241.2" x2="581.4" y2="241.2" stroke="currentColor" stroke-opacity=".30" stroke-width="5" stroke-linecap="round"/>
<circle cx="499.3" cy="241.2" r="4.5" fill="currentColor" fill-opacity=".95"/>
<circle cx="581.4" cy="241.2" r="3" fill="currentColor" fill-opacity=".45"/>
<text x="666.0" y="245.2" text-anchor="start" font-size="10.5" font-weight="400" fill="currentColor" fill-opacity=".45" font-family="var(--font-sans),system-ui,sans-serif">427</text><text x="198.0" y="277.8" text-anchor="end" font-size="11.5" font-weight="400" fill="currentColor" fill-opacity=".78" font-family="var(--font-sans),system-ui,sans-serif">dividend suspended entirely</text><line x1="562.3" y1="273.8" x2="641.9" y2="273.8" stroke="currentColor" stroke-opacity=".30" stroke-width="5" stroke-linecap="round"/>
<circle cx="562.3" cy="273.8" r="4.5" fill="currentColor" fill-opacity=".95"/>
<circle cx="641.9" cy="273.8" r="3" fill="currentColor" fill-opacity=".45"/>
<text x="666.0" y="277.8" text-anchor="start" font-size="10.5" font-weight="400" fill="currentColor" fill-opacity=".45" font-family="var(--font-sans),system-ui,sans-serif">1662</text><line x1="210" y1="290" x2="660" y2="290" stroke="currentColor" stroke-opacity=".28" stroke-width="1"/>
<text x="435.0" y="328.0" text-anchor="middle" font-size="11" font-weight="400" fill="currentColor" fill-opacity=".55" font-family="var(--font-sans),system-ui,sans-serif">implied-vol basis points  —  dot = median, small dot = p95 (log scale)</text>
</svg>
<figcaption>Dividend input error against the pricer's own error, with the same engine throughout. The dashed line is the pricer's median error given a correct dividend; large dots are medians and small dots p95.</figcaption>
</figure>

Amounts matter more than dates, by roughly a factor of six at the median and four in the
tail. Being a month early on the ex-date is about as damaging as being ten percent wrong
on the size, which is a useful calibration for anyone deciding where to spend effort on a
dividend feed.

Line the three numbers up and the shape of the whole problem appears. The pricer's own
error is a fifth of a basis point. A ten percent error in the dividend is more than two
orders of magnitude worse than that. And the market itself is about twenty-five basis
points wide, so the pricer sits a factor of a hundred and forty inside the spread it would
trade against, while the dividend error is comfortably outside it. These are not
comparable quantities being weighed against each other; one of them is simply not the
binding constraint.

Turned around, that gives the useful form: refining the pricer only starts paying once
dividend amounts are better than about **six hundredths of a percent** accurate, and
judging by the p95 rather than the median tightens that to **three hundredths**. Nobody
forecasts dividends to a twentieth of a percent: companies cut, raise, shift dates for
calendar reasons, and pay specials. The suspension row — 277 bp at the median, 1,662 in
the tail — is what a dividend cut does to a book before anything has been re-marked.

## Where this leaves us

Pricing an American equity option properly needs a jump condition at each ex-date, a free
boundary solved backwards, and enough resolution that the pricer's own error sits under
the noise floor of the dividend forecast. That last clause does more work than it looks
like it does.

The two sides of the book are genuinely different problems. A put's premium is interest on
the strike and vanishes exactly at zero rates; a call's exists only because of dividends
and vanishes exactly on a non-payer. Anything that flattens the dividend — escrowing it,
converting it to a yield, storing one annual number per name — damages the call side far
more than the put side at short tenors, and the damage is in the shape of the exercise
region rather than in the arithmetic, which is why a finer grid never recovers it. Two
unrelated numerical methods will agree with each other to a basis point or two on a smeared
dividend and both be wrong by the same hundreds.

Below roughly 5 bp, more numerical accuracy buys nothing that survives contact with the
input data, because the dividend noise floor sits well above it. That does not make the
scheme comparisons in the rest of this series pointless — it is still
worth knowing which methods land inside 5 bp and what they cost, and some widely
recommended ones do not. But it does mean the honest question is about speed and
reliability rather than accuracy, and that a great deal of effort usually spent on the
last basis point of the pricer would be better spent on the dividend calendar feeding it.

## Reproducing this

The [code](https://github.com/feribg/randomwalk.dev/tree/main/code/the-early-exercise-problem)
is one self-contained Julia module plus a script per experiment, with no dependency on
anything private. It runs in about eighty seconds on one core, writes every table
above into `results/`, and regenerates every figure from those CSVs, so no number in a plot
is typed by hand.

Everything assumes Black–Scholes dynamics with flat scalar rate, carry and volatility, and
non-negative rates, on vanilla American calls and puts. No term structure, no local or
stochastic volatility. Timings are single-threaded on one machine, so ratios travel and
absolute microseconds do not.

The market data is a ThetaData snapshot{{< cite thetadata >}} of AAPL on 2 January 2024 at
15:45 ET — spot 184.855, 760 strikes across 19 expiries, last two-sided quote per contract
in the preceding minute. That is a raw chain running from strike 50 to strike 320; the
derivation script cuts it to within 6% of the money and to relative spreads under 15%,
which leaves 208 of 1,520 legs, and prints what each cut removes. No raw quotes are in the
repository; only the derived aggregate spread statistics are committed, along with the
script that produced them. That spread cut is also why no claim is made anywhere above
about illiquid contracts: wide markets are excluded from the sample by construction, and
real wing spreads are wider than anything shown.

Healy's *Applied Quantitative Finance for Equity Derivatives*{{< cite healy2025 >}} is the
reference text for most of this material and is licensed CC BY-SA 4.0. Where its numbers
appear here they serve as an independent check rather than a reproduction of its tables.
