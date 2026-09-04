# §9 — dividend input error against the pricer's own error.
# §3 — what a basis point of implied vol is actually worth.

"""
Perturb the dividend, hold the engine fixed, and compare against the same engine given
the right dividend. This is the only comparison in the post where the pricer is the
control rather than the subject.
"""
function input_vs_pricer_error()
    banner(9, "DIVIDEND INPUT ERROR vs PRICER ERROR — which one binds?")
    S0, SIG = 100.0, 0.28
    engine(cp,S,K,r,q,s,T,dv) = lr_cash_div(cp,S,K,r,q,s,T,dv; n=401)
    scen = ["pricer error, correct dividend"      => (d -> d),
            "ex-date off by 1 week"               => (d -> [CashDiv(x.t + 7/365, x.amount) for x in d]),
            "ex-date off by 1 month"              => (d -> [CashDiv(x.t + 30/365, x.amount) for x in d]),
            "amount off by +10%"                  => (d -> [CashDiv(x.t, 1.10x.amount) for x in d]),
            "amount off by -10%"                  => (d -> [CashDiv(x.t, 0.90x.amount) for x in d]),
            "amount off by +25%"                  => (d -> [CashDiv(x.t, 1.25x.amount) for x in d]),
            "amount off by -25%"                  => (d -> [CashDiv(x.t, 0.75x.amount) for x in d]),
            "dividend suspended entirely"         => (d -> CashDiv[])]
    rows = DataFrame(scenario=String[], p50=Float64[], p95=Float64[], maxbp=Float64[], n=Int[])
    println("  engine LR-401, pooled calls and puts, one dividend of 2% of spot at 0.4T")
    println("  scenario                          p50 bp     p95 bp     max bp")
    for (nm, f) in scen
        e = Float64[]
        for cp in (Call(),Put()), m in (0.85,1.0,1.15), d in (91,365), r in (0.0,0.04)
            T=d/365; K=S0/m; q=0.02
            divs = [CashDiv(0.4T, 0.02*S0)]
            ref = fd_cash_div(cp,S0,K,r,q,SIG,T,divs; nx=2400,nt=1200)
            vg  = bs_vega(S0-pv_dividends(divs,r),K,r,q,SIG,T)
            vg > VEGA_FLOOR || continue
            push!(e, volbp(engine(cp,S0,K,r,q,SIG,T,f(divs)) - ref, vg))
        end
        push!(rows,(nm,nmed(e),p95v(e),maximum(e),length(e)))
        @printf("  %-32s %9.1f %10.1f %10.1f\n", nm, nmed(e), p95v(e), maximum(e))
    end
    writeresult("input_vs_pricer_error", rows)
    base = rows[1,:]
    println("\n  crossover -- how accurate your dividend AMOUNTS must be before refining")
    println("  the pricer pays anything at all:")
    for (lbl, q) in (("median", :p50), ("p95", :p95))
        a10 = rows[findfirst(==("amount off by +10%"), rows.scenario), q]
        @printf("    at the %-7s the pricer sits at %6.1f bp and a 10%% amount error at %7.1f bp\n",
                lbl, base[q], a10)
        @printf("             -> dividend amounts must be better than %.1f%% to matter\n",
                10 * base[q] / a10)
    end
end

"""
The unit, made concrete. Same vol error, three ways: basis points, cents, and share of
the option premium. The conversion is `price_err = bp * 1e-4 * vega`.
"""
function volbp_scale()
    banner(10, "WHAT A BASIS POINT OF IMPLIED VOL IS WORTH")
    S0 = 100.0
    contracts = [("30d ATM",            Call(), 100.0, 30/365,  0.25, 0.04, 0.0),
                 ("1y ATM",             Call(), 100.0, 1.0,     0.25, 0.04, 0.0),
                 ("30d 25-delta put",   Put(),   92.0, 30/365,  0.28, 0.04, 0.0),
                 ("2y deep-ITM put",    Put(),  140.0, 2.0,     0.25, 0.04, 0.0)]
    rows = DataFrame(contract=String[], K=Float64[], T=Float64[], sigma=Float64[],
                     premium=Float64[], vega=Float64[], bp10_cents=Float64[],
                     bp100_cents=Float64[], bp100_pct_premium=Float64[])
    println("  contract              premium     vega    10bp     100bp   100bp as % of premium")
    for (nm, cp, K, T, s, r, q) in contracts
        prem = bs_price(cp,S0,K,r,q,s,T)
        vg   = bs_vega(S0,K,r,q,s,T)
        c10  = 100*volbp_to_price(10.0, vg)
        c100 = 100*volbp_to_price(100.0, vg)
        pct  = volbp_to_premium_pct(100.0, vg, prem)
        push!(rows,(nm,K,T,s,prem,vg,c10,c100,pct))
        @printf("  %-20s %8.4f %8.3f %7.2fc %8.2fc %14.2f%%\n", nm, prem, vg, c10, c100, pct)
    end
    writeresult("volbp_scale", rows)

    # the market yardstick, from committed aggregates only
    p = joinpath(@__DIR__, "..", "data", "aapl_spread_summary.csv")
    if isfile(p)
        df = CSV.read(p, DataFrame)
        println("\n  Market yardstick — AAPL, 2024-01-02 15:45 ET (aggregates only):")
        for r in eachrow(df)
            @printf("    %-34s n=%4d   median spread %6.1f vol bp\n",
                    r.bucket, r.n, r.median_spread_volbp)
        end
        println("\n  The chain was filtered to relative spread < 15%, so wide markets are")
        println("  excluded by construction and no claim is made about illiquid contracts.")
    else
        println("\n  (data/aapl_spread_summary.csv absent — market yardstick skipped)")
    end
end
