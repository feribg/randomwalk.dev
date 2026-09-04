# §7 — the dividend model choice, and what escrowing quietly does.

"""
Escrowing sets `q = 0`. At `r >= 0` a call with `q = 0` is never exercised early, so any
American engine short-circuits to the European value: the approximation deletes the very
feature it was meant to price. Two different "American" engines then agree exactly,
which looks like corroboration and is actually both of them failing the same way.
"""
function escrowed_europeanises()
    banner(4, "ESCROWED DIVIDENDS SILENTLY EUROPEANISE AMERICAN CALLS")
    S0, K, r, sig, T = 100.0, 100.0, 0.05, 0.30, 1.0
    rows = DataFrame(divpct=Float64[], tfrac=Float64[], moneyness=Float64[],
                     reference=Float64[], escrowed=Float64[], european_at_escrow=Float64[],
                     matched_q=Float64[], escrow_miss=Float64[], escrow_miss_pct=Float64[])
    println("  American CALL, single mid-life cash dividend, r = 5%, sigma = 30%, T = 1")
    println("  div%  S/K    reference   escrowed   euro(escrow)   miss      miss %")
    for dp in (0.02, 0.04, 0.08), m in (0.9, 1.0, 1.2)
        Kx = S0 / m
        divs = [CashDiv(0.5 * T, dp * S0)]
        ref = lr_cash_div(Call(), S0, Kx, r, 0.0, sig, T, divs; n=4001)
        esc = escrowed_price((cp,S,K2,rr,qq,ss,TT) -> lr_price(cp,S,K2,rr,qq,ss,TT; n=4001),
                             Call(), S0, Kx, r, sig, T, divs)
        eue = bs_price(Call(), S0 - pv_dividends(divs, r), Kx, r, 0.0, sig, T)
        mq  = matched_q_price((cp,S,K2,rr,qq,ss,TT) -> lr_price(cp,S,K2,rr,qq,ss,TT; n=4001),
                              Call(), S0, Kx, r, sig, T, divs)
        push!(rows, (dp, 0.5, m, ref, esc, eue, mq, ref - esc, 100*(ref-esc)/ref))
        @printf("  %4.0f%% %5.2f %10.6f %10.6f %13.6f %9.6f %8.2f%%\n",
                100dp, m, ref, esc, eue, ref-esc, 100*(ref-esc)/ref)
    end
    writeresult("escrowed_europeanises", rows)
    d = maximum(abs.(rows.escrowed .- rows.european_at_escrow))
    @printf("\n  max |escrowed American - European at the escrowed spot| = %.2e\n", d)
    println("  i.e. the escrowed 'American' call IS the European call, to the last bit.")
end

"""
Healy §4.13's setup, priced under four dividend models on one engine.

The volatility for the cash model has to be CALIBRATED so its European price matches the
European Black price -- otherwise the comparison is between two different models at the
same nominal number, and the difference is mostly the calibration gap rather than the
early-exercise behaviour. Calibrating to the call and to the put give different answers,
which is itself the point.
"""
function dividend_models()
    banner(5, "DIVIDEND MODELS ON ONE ENGINE — Healy §4.13 replicated")
    S0, K, r, sig = 100.0, 100.0, 0.06, 0.30
    T, tb, beta = 91/365, 40/365, 0.07
    alpha = beta * S0 * exp(r * tb)          # forward-equivalent cash amount (§4.16)
    F_prop = S0 * exp(r * T) * (1 - beta)
    q_eq = r - log(F_prop / S0) / T
    @printf("  forward %.6f (cash and proportional match by construction)\n", F_prop)
    @printf("  equivalent constant yield %.6f%%\n", 100q_eq)

    # bracket check first -- see the note in constant_yield_regimes.jl
    calib(f, lo, hi) = begin
        (f(lo) <= 0 <= f(hi)) || error("root not bracketed in [$lo, $hi]")
        a, b = lo, hi
        for _ in 1:100
            m = (a + b) / 2
            f(m) > 0 ? (b = m) : (a = m)
        end
        (a + b) / 2
    end
    sig_c = calib(s -> quad_european_cash_div(Call(),S0,K,r,0.0,s,T,CashDiv(tb,alpha); nodes=600)
                       - bs_price(Call(),S0,K,r,q_eq,sig,T), 0.20, 0.35)
    sig_p = calib(s -> quad_european_cash_div(Put(),S0,K,r,0.0,s,T,CashDiv(tb,alpha); nodes=600)
                       - bs_price(Put(),S0,K,r,q_eq,sig,T), 0.20, 0.35)
    @printf("  spot-model vol calibrated to the European CALL %.6f%%, to the PUT %.6f%%\n",
            100sig_c, 100sig_p)
    @printf("  -> %.4f volatility points of ambiguity from one model choice\n\n",
            100*abs(sig_c - sig_p))

    N = 8001
    book = Dict("European (Black)"=>(3.376221,8.891463), "constant yield"=>(3.999140,8.890554),
                "proportional jump"=>(4.744712,9.139456), "cash jump (calibrated)"=>(4.564396,9.153665))
    vals = ("European (Black)" => (bs_price(Call(),S0,K,r,q_eq,sig,T), bs_price(Put(),S0,K,r,q_eq,sig,T)),
            "constant yield"   => (lr_price(Call(),S0,K,r,q_eq,sig,T;n=N), lr_price(Put(),S0,K,r,q_eq,sig,T;n=N)),
            "proportional jump"=> (lr_prop_div(Call(),S0,K,r,0.0,sig,T,[PropDiv(tb,beta)];n=N),
                                   lr_prop_div(Put(), S0,K,r,0.0,sig,T,[PropDiv(tb,beta)];n=N)),
            "cash jump (calibrated)" => (lr_cash_div(Call(),S0,K,r,0.0,sig_c,T,[CashDiv(tb,alpha)];n=N),
                                         lr_cash_div(Put(), S0,K,r,0.0,sig_p,T,[CashDiv(tb,alpha)];n=N)),
            "cash jump (uncalibrated)" => (lr_cash_div(Call(),S0,K,r,0.0,sig,T,[CashDiv(tb,alpha)];n=N),
                                           lr_cash_div(Put(), S0,K,r,0.0,sig,T,[CashDiv(tb,alpha)];n=N)))
    rows = DataFrame(model=String[], call=Float64[], put=Float64[],
                     book_call=Float64[], book_put=Float64[],
                     call_diff=Float64[], put_diff=Float64[])
    println("  model                        call        put   |  book call   book put  |   diffs")
    for (nm, (c, p)) in vals
        bc, bp = get(book, nm, (NaN, NaN))
        push!(rows, (nm, c, p, bc, bp, c-bc, p-bp))
        @printf("  %-24s %9.6f %10.6f | %9.6f %10.6f | %+8.1e %+8.1e\n", nm, c, p, bc, bp, c-bc, p-bp)
    end
    writeresult("dividend_models", rows)

    eu_c = bs_price(Call(),S0,K,r,q_eq,sig,T); eu_p = bs_price(Put(),S0,K,r,q_eq,sig,T)
    cy_c, cy_p = vals[2][2]; cj_c, cj_p = vals[4][2]
    @printf("\n  constant yield misses %.6f of the call (%.1f%% of its value)\n",
            cj_c - cy_c, 100*(cj_c - cy_c)/cj_c)
    capc = 100*(cy_c-eu_c)/(cj_c-eu_c)
    capp = 100*max(cy_p-eu_p, 0.0)/max(cj_p-eu_p, 1e-12)
    @printf("  it captures %.0f%% of the call's early-exercise premium and %.0f%% of the put's\n", capc, capp)
end

"""
Where the calibration ambiguity actually lives.

The obvious claim -- that no single spot-model volatility matches both the European call
and the European put -- is FALSE, and this experiment is what shows it. European put-call
parity holds under both the cash and the proportional model with the same forward, so a
volatility that reproduces the European call reproduces the European put automatically.
Calibrating on European prices is unambiguous.

The ambiguity is in the AMERICAN prices, where parity does not hold. Take cash-dividend
American prices as truth and ask what volatility the proportional model needs to
reproduce them: the answer depends on the strike AND on whether you asked a call or a
put. Healy §4.16 shows the same effect.
"""
function model_implied_vol()
    banner(12, "MOVING BETWEEN DIVIDEND MODELS CREATES A SMILE")
    S0, r, sig, T = 100.0, 0.06, 0.30, 1.0
    N = 2001
    println("  Cash model: alpha = 7 at t = 0.5, sigma = 30%. What volatility does the")
    println("  proportional model need to reproduce its price?\n")

    # First: European calibration is unambiguous (parity), demonstrated not asserted.
    ta, alpha = 0.5, 7.0
    beta = alpha * exp(-r * ta) / S0
    solve(f, lo, hi) = begin
        (f(lo) <= 0 <= f(hi)) || error("root not bracketed in [$lo, $hi]")
        a, b = lo, hi
        for _ in 1:100
            m = (a + b) / 2
            f(m) > 0 ? (b = m) : (a = m)
        end
        (a + b) / 2
    end
    K0 = 100.0
    ec = quad_european_cash_div(Call(),S0,K0,r,0.0,sig,T,CashDiv(ta,alpha); nodes=600)
    ep = quad_european_cash_div(Put(), S0,K0,r,0.0,sig,T,CashDiv(ta,alpha); nodes=600)
    Fc = S0*exp(r*T) - alpha*exp(r*(T-ta))
    vc = solve(s -> bs_price(Call(),S0*exp(-0.0),K0,r, r-log(Fc/S0)/T, s,T) - ec, 0.05, 1.0)
    vp = solve(s -> bs_price(Put(), S0*exp(-0.0),K0,r, r-log(Fc/S0)/T, s,T) - ep, 0.05, 1.0)
    @printf("  EUROPEAN, ATM: vol from the call %.6f%%, from the put %.6f%%  (gap %.2e)\n",
            100vc, 100vp, abs(vc-vp))
    println("  -> identical, because European put-call parity holds in both models.\n")

    rows = DataFrame(K=Float64[], cp=String[], cash_price=Float64[], prop_vol=Float64[])
    println("  AMERICAN, proportional-model volatility implied from the cash-model price:")
    println("     K      call vol      put vol       gap")
    for K in (50.0, 75.0, 90.0, 100.0, 110.0, 125.0, 150.0)
        out = Float64[]
        for cp in (Call(), Put())
            tgt = lr_cash_div(cp,S0,K,r,0.0,sig,T,[CashDiv(ta,alpha)]; n=N)
            v = solve(s -> lr_prop_div(cp,S0,K,r,0.0,s,T,[PropDiv(ta,beta)]; n=N) - tgt, 0.05, 1.20)
            push!(rows, (K, iscall(cp) ? "call" : "put", tgt, v))
            push!(out, v)
        end
        @printf("  %6.1f  %10.4f%%  %10.4f%%  %8.4f pts\n", K, 100out[1], 100out[2],
                100*abs(out[1]-out[2]))
    end
    writeresult("model_implied_vol", rows)
    c = filter(x -> x.cp=="call", rows).prop_vol
    p = filter(x -> x.cp=="put",  rows).prop_vol
    @printf("\n  call vol ranges over %.3f volatility points across strikes, put vol %.3f\n",
            100*(maximum(c)-minimum(c)), 100*(maximum(p)-minimum(p)))
    @printf("  largest call-vs-put gap at a single strike: %.3f points\n",
            100*maximum(abs.(c .- p)))
end
