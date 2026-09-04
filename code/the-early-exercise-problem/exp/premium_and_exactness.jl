# §5 and §6 — what early exercise costs, and the put/call asymmetry.

"""
The early-exercise premium across the rate/yield plane, both sides.

Reported two ways on purpose, because the private-tree table this replaces reports it as
a PERCENTAGE OF THE EUROPEAN PRICE and the rest of the post works in vol basis points.
Mixing those two silently is an easy way to be wrong by two orders of magnitude.
"""
function premium_map()
    banner(2, "EARLY-EXERCISE PREMIUM — the rate/yield asymmetry")
    S0 = 100.0
    rows = DataFrame(cp=String[], r=Float64[], q=Float64[], moneyness=Float64[],
                     days=Int[], sigma=Float64[], european=Float64[], american=Float64[],
                     premium=Float64[], premium_pct=Float64[], premium_bp=Float64[],
                     vega=Float64[])
    for cp in (Call(), Put()), r in (0.0, 0.02, 0.04, 0.08), q in (0.0, 0.02, 0.04, 0.08),
        m in (0.85, 1.0, 1.15), d in (30, 91, 365, 730), s in (0.2, 0.4)

        T = d / 365
        K = S0 / m
        eu = bs_price(cp, S0, K, r, q, s, T)
        am = lr_price(cp, S0, K, r, q, s, T; n=2001)
        vg = bs_vega(S0, K, r, q, s, T)
        prem = am - eu
        push!(rows, (iscall(cp) ? "call" : "put", r, q, m, d, s, eu, am, prem,
                     eu > 1e-8 ? 100 * prem / eu : NaN,
                     vg > VEGA_FLOOR ? volbp(prem, vg) : NaN, vg))
    end
    writeresult("premium_map", rows)

    println("\n  Premium as % of the European price, by class:")
    println("  class                       median      p95       max        n")
    for (nm, sub) in (("call, q = 0",  filter(x -> x.cp=="call" && x.q==0.0, rows)),
                      ("call, q > 0",  filter(x -> x.cp=="call" && x.q>0.0,  rows)),
                      ("put,  r = 0",  filter(x -> x.cp=="put"  && x.r==0.0, rows)),
                      ("put,  r > 0",  filter(x -> x.cp=="put"  && x.r>0.0,  rows)))
        v = filter(isfinite, sub.premium_pct)
        @printf("  %-24s %8.4f %8.3f %9.2f %8d\n", nm, nmed(v), p95v(v), maximum(v), length(v))
    end

    println("\n  Same thing in implied-vol basis points (vega > 0.1 only):")
    println("  class                       median      p95       max        n")
    for (nm, sub) in (("call, q = 0",  filter(x -> x.cp=="call" && x.q==0.0, rows)),
                      ("call, q > 0",  filter(x -> x.cp=="call" && x.q>0.0,  rows)),
                      ("put,  r = 0",  filter(x -> x.cp=="put"  && x.r==0.0, rows)),
                      ("put,  r > 0",  filter(x -> x.cp=="put"  && x.r>0.0,  rows)))
        v = filter(isfinite, sub.premium_bp)
        @printf("  %-24s %8.4f %8.2f %9.1f %8d\n", nm, nmed(v), p95v(v), maximum(v), length(v))
    end
end

"""
The two exactness identities, checked rather than asserted.

A call is never exercised early when `q <= 0` AND `q <= r`; a put when `r <= 0` and
`r <= q`. The second condition in each pair only bites at negative rates, which is why
the textbook version drops it — but dropping it is only safe at `r >= 0`, and every grid
here is at `r >= 0`.
"""
function exactness()
    banner(3, "EXACTNESS — q=0 calls and r=0 puts carry no premium")
    S0 = 100.0
    rows = DataFrame(case=String[], cp=String[], S=Float64[], K=Float64[], r=Float64[],
                     q=Float64[], sigma=Float64[], T=Float64[], american=Float64[],
                     european=Float64[], diff=Float64[], diff_bp=Float64[])
    for m in (0.7, 0.85, 1.0, 1.15, 1.4), d in (30, 91, 365, 730), s in (0.15, 0.3, 0.6),
        r in (0.0, 0.02, 0.05, 0.08)
        T = d/365; K = S0/m
        am = lr_price(Call(), S0, K, r, 0.0, s, T; n=2001)
        eu = bs_price(Call(), S0, K, r, 0.0, s, T)
        vg = bs_vega(S0, K, r, 0.0, s, T)
        push!(rows, ("q=0 call", "call", S0, K, r, 0.0, s, T, am, eu, am-eu,
                     vg > VEGA_FLOOR ? volbp(am-eu, vg) : NaN))
    end
    for m in (0.7, 0.85, 1.0, 1.15, 1.4), d in (30, 91, 365, 730), s in (0.15, 0.3, 0.6),
        q in (0.0, 0.02, 0.05, 0.08)
        T = d/365; K = S0/m
        am = lr_price(Put(), S0, K, 0.0, q, s, T; n=2001)
        eu = bs_price(Put(), S0, K, 0.0, q, s, T)
        vg = bs_vega(S0, K, 0.0, q, s, T)
        push!(rows, ("r=0 put", "put", S0, K, 0.0, q, s, T, am, eu, am-eu,
                     vg > VEGA_FLOOR ? volbp(am-eu, vg) : NaN))
    end
    writeresult("exactness", rows)
    for c in ("q=0 call", "r=0 put")
        sub = filter(x -> x.case == c, rows)
        v = filter(isfinite, abs.(sub.diff_bp))
        @printf("  %-10s  n=%3d   max |premium| = %.2e price, %.4f bp\n",
                c, nrow(sub), maximum(abs.(sub.diff)), maximum(v))
    end
    println("\n  Both are exact identities. The residual is the lattice's own discretisation")
    println("  error, not a premium -- it shrinks with n and does not scale with r or q.")
end
