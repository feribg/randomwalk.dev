#!/usr/bin/env julia
#
# derive_aapl_spread.jl — turn an options chain snapshot into the aggregate bid-ask
# statistics the post uses as a scale reference.
#
#   julia --project tools/derive_aapl_spread.jl /path/to/chain.csv
#
# The chain path is a required argument. This script lives in a public repository and
# reads vendor data that is NOT redistributable, so the location of that data is never
# baked in. THE RAW CHAIN IS NEVER COMMITTED, and nothing per-contract is written: the
# only output is data/aapl_spread_summary.csv, which holds bucket medians.
#
# Expected columns: expiration, strike, c_bid, c_ask, p_bid, p_ask, S, T
#
# WHY TWO INVERSIONS
#
# The post reports every error in implied-vol basis points, so the market's own bid-ask
# width has to be expressed in the same unit to be a useful yardstick. That means
# inverting a bid and an ask to volatilities and subtracting.
#
# These are AMERICAN options, and the obvious inversion uses the European Black formula,
# which cannot produce an early-exercise premium — so each implied volatility comes out at
# the wrong LEVEL. The width should survive anyway, because it is the difference of two
# inversions of two prices a cent apart under the same model, and a bias that depends on
# the contract rather than on the side of the spread cancels in the subtraction.
#
# "Should" is not evidence. So every leg is inverted twice — once with Black, once with a
# Leisen-Reimer American lattice — and both medians are reported. If they agree, the
# yardstick is sound and the argument above is unnecessary.
#
# The lattice runs at n = 401 rather than the n = 4001 used for reference pricing
# elsewhere. This is a few thousand two-leg bisections, and the comparison is Black
# against the lattice at IDENTICAL settings, so tree resolution cannot change the
# conclusion. 401 is far more resolution than a spread yardstick needs.

using CSV, DataFrames, Statistics, Printf

const HERE = @__DIR__
include(joinpath(HERE, "..", "american.jl"))
using .American

# AAPL on 2024-01-02: short rate off the Treasury curve for that date, and the declared
# dividend carried as a small continuous yield. Both only shift the implied LEVEL, and the
# width is a difference, so neither materially affects what this script measures.
const R, Q = 0.054, 0.005
const LATTICE_N = 401

# Sample construction. Both of these are part of what the post claims about this data, so
# they belong in the script rather than in a preprocessing step that never got committed.
#
#   MONEYNESS_CAP  keeps the sample to contracts with a meaningful two-sided market. A raw
#                  chain runs far into the wings -- this one carries strikes from 50 to 320
#                  against a spot of 185 -- and those quotes are not a market width in any
#                  useful sense.
#   REL_SPREAD_CAP drops quotes whose width exceeds 15% of the mid. This is why the post
#                  makes no claim about illiquid contracts: they are removed here, by
#                  construction, and real wing spreads are wider than anything reported.
const MONEYNESS_CAP  = 0.06
const REL_SPREAD_CAP = 0.15
# The lattice cannot be bracketed down to 1e-3. At low volatility the Peizer-Pratt
# inversion degenerates at BOTH ends: for a deeply out-of-the-money contract the
# up-probability underflows to zero and the up-factor overflows, and for a deeply
# in-the-money one it saturates at one and the down-factor divides by zero. `lr_params`
# reports either as NaN. 1% is comfortably inside the usable range for everything within
# the moneyness cap above, and far below any volatility a real quote implies. The European
# bracket keeps its own wider floor.
const IV_LO, IV_HI = 0.01, 5.0
const IV_TOL = 1e-8
const MAX_ITER = 60

"""
Implied volatility from an AMERICAN price by bisection on the lattice.

`american.jl` deliberately ships only a European solver, so this lives here rather than in
the module: it exists to answer one question about one dataset, not as a general routine.
Bisection rather than Newton because the lattice has no cheap vega and robustness matters
more than speed at this size.

Returns `NaN` when no volatility in `[IV_LO, IV_HI]` reproduces the price, which for a
quote usually means it sits at or below intrinsic.
"""
function american_iv(cp::OptionType, target, S, K, r, q, T; n::Int=LATTICE_N)
    f(s) = lr_price(cp, S, K, r, q, s, T; n=n) - target
    lo, hi = IV_LO, IV_HI
    flo, fhi = f(lo), f(hi)
    (isfinite(flo) && isfinite(fhi)) || return NaN
    (flo > 0 || fhi < 0) && return NaN          # outside the attainable range
    for _ in 1:MAX_ITER
        mid = (lo + hi) / 2
        fm = f(mid)
        fm > 0 ? (hi = mid) : (lo = mid)
        (hi - lo) < IV_TOL && break
    end
    return (lo + hi) / 2
end

function main()
    if length(ARGS) != 1
        println(stderr, "usage: julia --project tools/derive_aapl_spread.jl <chain.csv>")
        println(stderr, "  chain columns: expiration, strike, c_bid, c_ask, p_bid, p_ask, S, T")
        exit(2)
    end
    src = ARGS[1]
    isfile(src) || (println(stderr, "no such chain file: $src"); exit(2))

    df = CSV.read(src, DataFrame)
    for c in ("strike","c_bid","c_ask","p_bid","p_ask","S","T")
        hasproperty(df, Symbol(c)) || (println(stderr, "chain is missing column: $c"); exit(2))
    end
    @printf("chain: %d rows, spot %.3f\n", nrow(df), df.S[1])
    @printf("filters: |log S/K| < %.0f%%, relative spread < %.0f%%\n",
            100*MONEYNESS_CAP, 100*REL_SPREAD_CAP)
    @printf("inverting each leg twice (Black, and a %d-step American lattice)\n\n", LATTICE_N)

    rows = NamedTuple[]
    legs = 0; drop_mn = 0; drop_rel = 0; drop_quote = 0; drop_inv = 0
    for row in eachrow(df)
        T = row.T
        T > 0 || continue
        S = row.S                       # per-row spot, not the first row's
        K = row.strike
        mn = abs(log(S / K))
        for (cp, bid, ask) in ((Call(), row.c_bid, row.c_ask), (Put(), row.p_bid, row.p_ask))
            legs += 1
            mn < MONEYNESS_CAP           || (drop_mn += 1; continue)
            (bid > 0.005 && ask > bid)   || (drop_quote += 1; continue)
            mid = (bid + ask) / 2
            rel = (ask - bid) / mid
            rel < REL_SPREAD_CAP         || (drop_rel += 1; continue)
            (ivb, _, okb) = bs_implied_vol(cp, bid, S, K, R, Q, T)
            (iva, _, oka) = bs_implied_vol(cp, ask, S, K, R, Q, T)
            avb = american_iv(cp, bid, S, K, R, Q, T)
            ava = american_iv(cp, ask, S, K, R, Q, T)
            (okb && oka && isfinite(ivb) && isfinite(iva) &&
             isfinite(avb) && isfinite(ava)) || (drop_inv += 1; continue)
            push!(rows, (T=T, days=round(Int, T*365), K=K, mn=mn,
                         euro_volbp=1e4*(iva - ivb),
                         amer_volbp=1e4*(ava - avb),
                         rel=rel))
        end
    end
    d = DataFrame(rows)
    @printf("legs %d -> dropped %d outside the moneyness cap, %d one-sided or sub-penny,\n",
            legs, drop_mn, drop_quote)
    @printf("            %d wider than the spread cap, %d not invertible\n", drop_rel, drop_inv)
    @printf("         -> %d legs in the sample\n\n", nrow(d))

    buckets = [("near-ATM (|log S/K| < 2%), front 3 expiries", x -> x.mn < 0.02 && x.days <= 26),
               ("near-ATM (|log S/K| < 2%), all expiries",     x -> x.mn < 0.02),
               ("|log S/K| 2-4%, all expiries",                x -> 0.02 <= x.mn < 0.04),
               ("|log S/K| 4-6%, all expiries",                x -> 0.04 <= x.mn < MONEYNESS_CAP),
               ("all invertible legs",                          x -> true)]
    out = DataFrame(bucket=String[], n=Int[],
                    median_spread_volbp=Float64[],
                    p25_spread_volbp=Float64[], p75_spread_volbp=Float64[],
                    median_spread_volbp_american=Float64[],
                    median_rel_spread_pct=Float64[])
    @printf("%-46s %6s %12s %12s %9s\n", "bucket", "n", "Black", "American", "diff")
    for (nm, f) in buckets
        s = filter(f, d)
        nrow(s) == 0 && continue
        me, ma = median(s.euro_volbp), median(s.amer_volbp)
        push!(out, (nm, nrow(s), me, quantile(s.euro_volbp,0.25), quantile(s.euro_volbp,0.75),
                    ma, 100*median(s.rel)))
        @printf("%-46s %6d %9.1f bp %9.1f bp %8.2f bp\n", nm, nrow(s), me, ma, ma - me)
    end
    dest = joinpath(HERE, "..", "data", "aapl_spread_summary.csv")
    CSV.write(dest, out)
    @printf("\nwrote data/aapl_spread_summary.csv (aggregates only, %d rows)\n", nrow(out))
    worst = maximum(abs.(out.median_spread_volbp_american .- out.median_spread_volbp))
    @printf("largest bucket disagreement between the two inversions: %.2f bp\n", worst)
end

main()
