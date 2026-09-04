# Supports the claim that a constant yield gets the SHAPE of the exercise region wrong,
# across regimes rather than at the single contract of Healy §4.13.
#
# For each regime: build a cash dividend, derive the constant yield that matches its
# forward exactly, calibrate the spot-model volatility so the two agree on the EUROPEAN
# price, then compare the American prices. Any remaining gap is early-exercise behaviour
# and nothing else.

function constant_yield_regimes()
    banner(13, "CONSTANT YIELD vs CASH JUMP ACROSS REGIMES")
    S0, r, sig = 100.0, 0.05, 0.30
    N = 2001
    # bisection with an explicit bracket check: without it a root outside [lo, hi] is
    # returned silently as an endpoint, which looks like a converged answer.
    solve(f, lo, hi) = begin
        (f(lo) <= 0 <= f(hi)) || error("root not bracketed in [$lo, $hi]")
        a, b = lo, hi
        for _ in 1:100
            m = (a + b) / 2
            f(m) > 0 ? (b = m) : (a = m)
        end
        (a + b) / 2
    end

    rows = DataFrame(cp=String[], divpct=Float64[], moneyness=Float64[], days=Int[],
                     tfrac=Float64[], sigma_cash=Float64[], european=Float64[],
                     const_yield=Float64[], cash_jump=Float64[],
                     missed=Float64[], missed_pct=Float64[], premium_captured_pct=Float64[])
    for cp in (Call(), Put()), dp in (0.02, 0.04, 0.08), m in (0.9, 1.0, 1.2),
        d in (30, 91, 365), tf in (0.5,)

        T = d / 365
        K = S0 / m
        alpha = dp * S0 * exp(r * tf * T)          # forward-equivalent cash amount
        divs = [CashDiv(tf * T, alpha)]
        F = S0 * exp(r * T) - alpha * exp(r * (T - tf * T))
        q_eq = r - log(F / S0) / T

        eu = bs_price(cp, S0, K, r, q_eq, sig, T)
        # calibrate the spot-model vol so the two models agree on the European price
        sc = solve(s -> quad_european_cash_div(cp, S0, K, r, 0.0, s, T, divs[1]; nodes=400) - eu,
                   0.05, 1.20)
        cy = lr_price(cp, S0, K, r, q_eq, sig, T; n=N)
        cj = lr_cash_div(cp, S0, K, r, 0.0, sc, T, divs; n=N)

        prem_cj = cj - eu
        push!(rows, (iscall(cp) ? "call" : "put", dp, m, d, tf, sc, eu, cy, cj,
                     cj - cy, 100 * (cj - cy) / cj,
                     prem_cj > 1e-10 ? 100 * max(cy - eu, 0.0) / prem_cj : NaN))
    end
    writeresult("constant_yield_regimes", rows)

    println("  CALLS — % of the option's value the constant-yield model misses")
    println("  div    S/K      30d      91d     365d")
    for dp in (0.02, 0.04, 0.08), m in (0.9, 1.0, 1.2)
        v = [only(filter(x -> x.cp=="call" && x.divpct==dp && x.moneyness==m && x.days==d, rows)).missed_pct
             for d in (30, 91, 365)]
        @printf("  %3.0f%%  %5.2f  %7.2f%% %7.2f%% %7.2f%%\n", 100dp, m, v...)
    end
    println("\n  CALLS — % of the early-exercise premium the constant-yield model captures")
    println("  div    S/K      30d      91d     365d")
    for dp in (0.02, 0.04, 0.08), m in (0.9, 1.0, 1.2)
        v = [only(filter(x -> x.cp=="call" && x.divpct==dp && x.moneyness==m && x.days==d, rows)).premium_captured_pct
             for d in (30, 91, 365)]
        @printf("  %3.0f%%  %5.2f  %7.1f%% %7.1f%% %7.1f%%\n", 100dp, m, v...)
    end
    c = filter(x -> x.cp=="call", rows); p = filter(x -> x.cp=="put", rows)
    @printf("\n  calls: misses %.2f-%.2f%% of value, captures %.0f-%.0f%% of the premium\n",
            minimum(c.missed_pct), maximum(c.missed_pct),
            minimum(filter(isfinite, c.premium_captured_pct)), maximum(filter(isfinite, c.premium_captured_pct)))
    @printf("  puts:  misses %.2f-%.2f%% of value, captures %.0f-%.0f%% of the premium\n",
            minimum(p.missed_pct), maximum(p.missed_pct),
            minimum(filter(isfinite, p.premium_captured_pct)), maximum(filter(isfinite, p.premium_captured_pct)))
end
