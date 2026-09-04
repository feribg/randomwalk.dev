# The Early Exercise Problem — code

Everything behind [the post](https://randomwalk.dev/the-early-exercise-problem/). Self
contained: pure Julia, a handful of registered packages, no dependency on anything private.

```sh
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project experiments.jl                      # writes results/*.csv
julia --project charts.jl                           # regenerates charts/*.svg
python3 sync_charts.py <path-to-post/index.md>      # splices figures into that post
```

`results/` is committed, so you can check the numbers without running anything.

## Layout

| file | what |
| --- | --- |
| `american.jl` | every pricer, in one module |
| `harness.jl` | shared statistics helpers and the vega filter |
| `experiments.jl` | driver — runs every experiment in `exp/` |
| `exp/*.jl` | one file per group of experiments |
| `exp/dividend_models.jl` | external validation — reprices the Healy §4.13 setup under four dividend models against the published values; the only check here against a source outside this repository |
| `charts.jl` | emits the post's figures; every coordinate comes from a CSV |
| `sync_charts.py` | splices `charts/*.svg` into a post; takes the post path as an argument |
| `tools/derive_aapl_spread.jl` | turns a chain snapshot into the committed aggregate spread statistics |
| `data/` | committed derived inputs (see **Data** below) |
| `results/` | committed outputs |

## What's implemented

- **Black–Scholes** — price, analytic greeks, and implied volatility by safeguarded
  Newton off a Brenner–Subrahmanyam seed. Deliberately the simple solver; Healy §2.4
  pairs a Stefanica–Radoicic seed with a Householder iteration and is much better, and
  is also not what this post is about.
- **Leisen–Reimer** lattice, Peizer–Pratt inversion formula 2. `n` is forced odd — the
  inversion needs an odd step count to keep the strike centred, so `n = 100` and
  `n = 101` are the same tree. Returns `NaN` where the inversion degenerates, which at low
  volatility happens at both ends: the up-probability underflows to zero deep out of the
  money and saturates at one deep in it. No grid in this repository comes near either.
- **CRR**, for contrast only. It returns `NaN` where `σ < |r−q|√Δt` puts the risk-neutral
  probability outside `[0,1]`. That regime diverges rather than degrading, so the guard
  reports the breakdown instead of propagating a meaningless number — an unguarded
  recursion there returns values of order `1e20`, not a slightly wrong price.
- **Cash-dividend lattice**, Vellekoop–Nieuwenhuis. The tree is built on the
  *dividend-free* process and dividends enter only through the value-function jump. That
  jump is interpolated with a four-point rule in log-spot, not linearly: a lattice value
  function is convex, so a chord between nodes sits above it and linear interpolation
  biases every jump the same way. Over the 108-case grid this is the difference between
  0.213 and 0.006 vol bp against the exact answer.
- **Proportional-dividend lattice**, the same rollback with a multiplicative jump, so the
  two dividend models can be compared on an identical engine.
- **Finite differences** — Crank–Nicolson with a Rannacher startup on a uniform log grid,
  Brennan–Schwartz for the free boundary, PSOR as the cross-check, and every ex-date
  pinned onto a time-step boundary.
- **Quadrature** — the exact European price under the spot model with one cash dividend.
  The inner expectation is closed-form Black–Scholes and the integration is split at the
  kink, so it converges by fifty nodes.

Not here, because they belong to later posts in the series: Andersen–Lake and QD+,
Roll–Geske–Whaley, and the automatic-differentiation greek paths.

**Two notes worth having if you extend this.** Gauss–Hermite is the obvious quadrature to
reach for and it fails badly — the payoff kink means a 96-node rule misses plain
Black–Scholes by 1.8e-2 and oscillates rather than converging as the order rises. Healy
§2.7.5 makes the same point. And the cash-dividend model needs its volatility calibrated
against the European Black price before it can be compared to a proportional or
constant-yield model at the same nominal number; without that, most of the difference you
measure is the calibration gap.

## Data

The post uses one piece of market data: a **ThetaData** snapshot of **AAPL on
2024-01-02, 15:45 ET** — spot 184.855, 760 strikes across 19 expiries, taken as the last
two-sided quote per contract in the preceding minute. The snapshot is a raw chain: strikes
run from 50 to 320, so most of it is far out of the money. `derive_aapl_spread.jl` applies
the sample construction itself, as `MONEYNESS_CAP = 0.06` and `REL_SPREAD_CAP = 0.15`, and
prints how many legs each one removes. Of 1520 legs, 208 survive.

**No raw quotes are in this repository**, and none will be — redistributing them would
violate the vendor licence. What is committed is `data/aapl_spread_summary.csv`: five
rows of aggregate bid-ask statistics, derived by inverting each bid and ask to a
volatility and taking bucket medians. That is the only thing the post needs.

That 15% spread cap is also why the post makes no claim about illiquid contracts. Wide
markets are removed from the sample by construction, so the wings are not represented and
real wing spreads are wider than anything shown.

To regenerate the summary you need a ThetaData subscription and a chain snapshot with
columns `expiration, strike, c_bid, c_ask, p_bid, p_ask, S, T`:

```sh
julia --project tools/derive_aapl_spread.jl /path/to/chain.csv
```

The chain path is a required argument — this repository is public and the tape is not, so
no private location is baked in. Without a subscription the committed CSV is enough to run
every experiment; nothing else reads the tape.

That script inverts every bid and ask **twice**, once with the European Black formula and
once with a 401-step American lattice, and reports both medians. The reason is that these
are American options being inverted with a European formula, so each implied volatility is
at the wrong level; a spread is a difference of two inversions under the same model, so the
bias should cancel. It does — the near-the-money medians differ by three hundredths of a
basis point — and `median_spread_volbp_american` is in the committed CSV so the check is
visible rather than asserted.

One thing surfaces when you run it: the lattice cannot be bracketed below about 1% vol,
because the Peizer-Pratt inversion degenerates there. On a raw chain that silently removes
a quarter of the far-wing legs — not because their quotes violate any no-arbitrage bound,
but because the tree parameters do not exist at the bracket floor — and it moves those
buckets' medians. Inside the moneyness cap the problem disappears: of 1520 legs, exactly
four fail to invert, and none of them are near the money.

## Caveats

- Flat scalar `r`, `q` and `σ`. No term structure, no local or stochastic volatility.
- **Positive rates only.** Under `r < 0` an American put can have two free boundaries with
  exercise optimal between them; nothing here is tested there.
- Every table filters to `vega > 0.1`. Deep-ITM and very short-dated contracts are outside
  every number in the post.
- Timings are single-threaded on one machine. Ratios travel; absolute microseconds don't.
