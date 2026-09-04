# §8 — what smearing a discrete dividend into a continuous yield costs.
# Engine is held fixed in every table here; only the MODEL changes.

const REF_NX, REF_NT = 2400, 1200
refprice(cp,S,K,r,q,s,T,divs) = fd_cash_div(cp,S,K,r,q,s,T,divs; nx=REF_NX, nt=REF_NT)

"""Quarterly cash dividends of `annual/4` of spot, first ex-date at `t0`, within (0,T]."""
function quarterly(S0, annual, t0, T)
    ds = CashDiv[]
    t = t0
    while t <= T + 1e-12
        t > 0 && push!(ds, CashDiv(t, annual/4 * S0))
        t += 0.25
    end
    ds
end

"""
A scalar annualised yield -- one dividend-yield number per name -- against a
tenor-matched yield and against the actual schedule.

The split that matters is whether an ex-date actually falls inside `[0,T]`. A flat annual
yield charges the option for dividends it will never see.
"""
function scalar_vs_matched()
    banner(6, "SCALAR ANNUAL YIELD vs TENOR-MATCHED YIELD vs THE SCHEDULE")
    S0, SIG, R = 100.0, 0.28, 0.04
    rows = DataFrame(days=Int[], cp=String[], moneyness=Float64[], t0=Float64[],
                     annual=Float64[], ndiv=Int[], exdate_inside=Bool[],
                     reference=Float64[], scalar_bp=Float64[], matched_bp=Float64[],
                     schedule_bp=Float64[])
    lat(cp,S,K,r,q,s,T) = lr_price(cp,S,K,r,q,s,T; n=401)
    for d in (7,14,30,60,91,182,365,730), cp in (Call(),Put()), m in (0.9,1.0,1.1),
        t0 in (0.02,0.10,0.20), annual in (0.02,0.04)
        T = d/365; K = S0/m
        divs = quarterly(S0, annual, t0, T)
        ref  = refprice(cp,S0,K,R,0.0,SIG,T,divs)
        vg   = bs_vega(S0 - pv_dividends(divs,R), K, R, 0.0, SIG, T)
        vg > VEGA_FLOOR || continue
        sc   = lat(cp,S0,K,R,annual,SIG,T)
        mq   = matched_q_price(lat, cp,S0,K,R,SIG,T,divs)
        sch  = lr_cash_div(cp,S0,K,R,0.0,SIG,T,divs; n=401)
        push!(rows,(d, iscall(cp) ? "call" : "put", m, t0, annual, length(divs),
                    !isempty(divs), ref, volbp(sc-ref,vg), volbp(mq-ref,vg), volbp(sch-ref,vg)))
    end
    writeresult("scalar_vs_matched", rows)
    println("\n  days   scalar q p50/p95      matched q p50/p95     schedule p50/p95     ratio p95")
    for d in (7,14,30,60,91,182,365,730)
        s = filter(x -> x.days == d, rows)
        isempty(s) && continue
        @printf("  %4d  %8.1f /%8.1f    %8.1f /%8.1f   %7.2f /%7.2f   %9.1fx\n", d,
                nmed(s.scalar_bp), p95v(s.scalar_bp), nmed(s.matched_bp), p95v(s.matched_bp),
                nmed(s.schedule_bp), p95v(s.schedule_bp),
                p95v(s.scalar_bp)/max(p95v(s.matched_bp),1e-9))
    end
    println("\n  split by whether an ex-date actually falls inside the option's life:")
    for d in (7,14,30)
        for inside in (false,true)
            s = filter(x -> x.days==d && x.exdate_inside==inside, rows)
            isempty(s) && continue
            @printf("   %4dd  ex-date inside = %-5s  scalar p95 %8.1f bp   matched p95 %8.1f bp\n",
                    d, inside, p95v(s.scalar_bp), p95v(s.matched_bp))
        end
    end
end

"""
Same total present value, two representations: the actual schedule, versus a PV-matched
continuous yield. Priced on a lattice and again on a second engine, to show the loss is
the MODEL and not the numerical method.
"""
function smearing_penalty()
    banner(7, "PV-MATCHED YIELD vs THE FULL SCHEDULE")
    S0, SIG, R = 100.0, 0.28, 0.04
    lat101(cp,S,K,r,q,s,T) = lr_price(cp,S,K,r,q,s,T; n=101)
    fd_yield(cp,S,K,r,q,s,T) = fd_american(cp,S,K,r,q,s,T; nx=400,nt=200,anchor=:strike)

    shape = DataFrame(days=Int[], tfrac=Float64[], schedule_p50=Float64[], schedule_p95=Float64[],
                      yieldLR_p50=Float64[], yieldLR_p95=Float64[],
                      yieldFD_p50=Float64[], yieldFD_p95=Float64[])
    println("  (a) pooled over calls and puts -- schedule vs the same PV as a flat yield")
    println("  tenor  ex-date      schedule         yield+LR            yield+FD")
    for d in (30,91,365,730), tf in (0.15,0.5,0.85)
        T = d/365
        a=Float64[]; b=Float64[]; c=Float64[]
        for cp in (Call(),Put()), m in (0.85,1.0,1.15), r in (0.0,0.04,0.08)
            K = S0/m; q = 0.02
            divs = [CashDiv(tf*T, 0.02*S0)]
            ref = refprice(cp,S0,K,r,q,SIG,T,divs)
            vg  = bs_vega(S0-pv_dividends(divs,r),K,r,q,SIG,T)
            vg > VEGA_FLOOR || continue
            push!(a, volbp(lr_cash_div(cp,S0,K,r,q,SIG,T,divs;n=101)-ref, vg))
            push!(b, volbp(matched_q_price((C,S,KK,rr,qq,ss,TT)->lat101(C,S,KK,rr,qq+q,ss,TT),
                                           cp,S0,K,r,SIG,T,divs)-ref, vg))
            push!(c, volbp(matched_q_price((C,S,KK,rr,qq,ss,TT)->fd_yield(C,S,KK,rr,qq+q,ss,TT),
                                           cp,S0,K,r,SIG,T,divs)-ref, vg))
        end
        push!(shape,(d,tf,nmed(a),p95v(a),nmed(b),p95v(b),nmed(c),p95v(c)))
        @printf("  %4dd  %.2f   %6.1f/%-8.1f %8.1f/%-9.1f %8.1f/%-9.1f\n",
                d, tf, nmed(a),p95v(a), nmed(b),p95v(b), nmed(c),p95v(c))
    end
    writeresult("smearing_shape", shape)

    side = DataFrame(days=Int[], cp=String[], schedule_p50=Float64[], schedule_p95=Float64[],
                     yield_p50=Float64[], yield_p95=Float64[], penalty_p50=Float64[])
    println("\n  (b) which side pays -- engine fixed at LR-401, only the model changes")
    println("  tenor  side    schedule p50/p95      yield p50/p95       p50 penalty")
    lat401(cp,S,K,r,q,s,T) = lr_price(cp,S,K,r,q,s,T; n=401)
    for d in (30,91,365,730), cp in (Call(),Put())
        T = d/365
        a=Float64[]; b=Float64[]
        for m in (0.85,0.95,1.0,1.05,1.15), r in (0.0,0.04,0.08), tf in (0.3,0.5,0.8)
            K = S0/m; q = 0.02
            divs = [CashDiv(tf*T, 0.02*S0)]
            ref = refprice(cp,S0,K,r,q,SIG,T,divs)
            vg  = bs_vega(S0-pv_dividends(divs,r),K,r,q,SIG,T)
            vg > VEGA_FLOOR || continue
            push!(a, volbp(lr_cash_div(cp,S0,K,r,q,SIG,T,divs;n=401)-ref, vg))
            push!(b, volbp(matched_q_price((C,S,KK,rr,qq,ss,TT)->lat401(C,S,KK,rr,qq+q,ss,TT),
                                           cp,S0,K,r,SIG,T,divs)-ref, vg))
        end
        push!(side,(d, iscall(cp) ? "call" : "put", nmed(a),p95v(a),nmed(b),p95v(b),
                    nmed(b)/max(nmed(a),1e-9)))
        @printf("  %4dd  %-5s %7.1f/%-8.1f %10.1f/%-9.1f %10.1fx\n",
                d, iscall(cp) ? "call" : "put", nmed(a),p95v(a),nmed(b),p95v(b),
                nmed(b)/max(nmed(a),1e-9))
    end
    writeresult("smearing_by_side", side)
end

"""Is there a dividend small enough to ignore? Sweep PV/S and find out."""
function pv_threshold()
    banner(8, "IS THERE A SAFE THRESHOLD FOR IGNORING A DIVIDEND?")
    S0, SIG, R = 100.0, 0.28, 0.04
    rows = DataFrame(pvfrac=Float64[], cp=String[], ignore_p50=Float64[], ignore_p95=Float64[],
                     matched_p50=Float64[], matched_p95=Float64[])
    lat(cp,S,K,r,q,s,T) = lr_price(cp,S,K,r,q,s,T; n=401)
    println("  PV/S     IGNORE p50/p95         MATCHED-q p50/p95      worse for")
    for pv in (0.0,0.0025,0.005,0.0075,0.01,0.015,0.02,0.03)
        agg = Dict("call"=>(Float64[],Float64[]), "put"=>(Float64[],Float64[]))
        for cp in (Call(),Put()), m in (0.85,1.0,1.15), d in (30,91,365), s in (0.2,0.4)
            T=d/365; K=S0/m
            divs = pv > 0 ? [CashDiv(0.5T, pv*S0*exp(R*0.5T))] : CashDiv[]
            # The reference is the FD grid at EVERY pv, including zero. Using a lattice for
            # the pv = 0 row would compare a lattice against a lattice and put the baseline
            # below the cross-family floor the other rows all carry, making the zero row
            # look better than it is by construction rather than by measurement.
            ref = refprice(cp,S0,K,R,0.0,s,T,divs)
            vg = bs_vega(S0-pv_dividends(divs,R),K,R,0.0,s,T)
            vg > VEGA_FLOOR || continue
            key = iscall(cp) ? "call" : "put"
            push!(agg[key][1], volbp(lat(cp,S0,K,R,0.0,s,T)-ref, vg))
            push!(agg[key][2], volbp(matched_q_price(lat,cp,S0,K,R,s,T,divs)-ref, vg))
        end
        for k in ("call","put")
            ig, mq = agg[k]
            push!(rows,(pv,k,nmed(ig),p95v(ig),nmed(mq),p95v(mq)))
        end
        ig = vcat(agg["call"][1],agg["put"][1]); mq = vcat(agg["call"][2],agg["put"][2])
        # the pooled row as well: it is what the post quotes, and a median over both sides
        # is not recoverable from the two per-side medians.
        push!(rows,(pv,"pooled",nmed(ig),p95v(ig),nmed(mq),p95v(mq)))
        worse = p95v(agg["put"][1]) > p95v(agg["call"][1]) ? "puts (ignore)" : "calls (ignore)"
        @printf("  %5.2f%%  %8.1f /%9.1f    %8.1f /%9.1f    %s\n",
                100pv, nmed(ig),p95v(ig), nmed(mq),p95v(mq), worse)
    end
    writeresult("pv_threshold", rows)
end

"""
Why the put side appears in a section about dividends at all.

The identity in the previous section governs what CREATES an early-exercise premium: a
call's comes from dividends, a put's from the interest rate. It says nothing about what
affects the PRICE. A dividend moves both sides regardless of exercise, and getting its
shape wrong does two separable things:

  1. it changes the terminal distribution even when the forward matches exactly, which
     costs both sides roughly the same and has nothing to do with early exercise; and
  2. it changes the SIZE of the put's premium, which the interest rate created but the
     dividend path modulates.

Splitting the two is the point of this experiment: European prices isolate the first
effect, and the premium columns isolate the second.
"""
function premium_under_smearing()
    banner(14, "WHY PUTS APPEAR IN A DIVIDEND SECTION")
    S0, SIG, r, q = 100.0, 0.28, 0.04, 0.02
    rows = DataFrame(days=Int[], cp=String[], eu_cash=Float64[], eu_yield=Float64[],
                     eu_diff_bp=Float64[], prem_cash=Float64[], prem_smeared=Float64[],
                     retained_pct=Float64[])
    println("  European prices isolate the distribution effect; premiums isolate exercise.")
    println("  tenor side   EU cash   EU yield  EU diff |  premium cash  smeared  retained")
    for d in (30, 91, 365, 730), cp in (Call(), Put())
        T = d/365; K = S0
        dv = [CashDiv(0.5T, 0.02*S0)]
        qm = matched_q(S0, dv, r, T) + q
        euc = quad_european_cash_div(cp, S0, K, r, q, SIG, T, dv[1]; nodes=600)
        euy = bs_price(cp, S0, K, r, qm, SIG, T)
        amc = lr_cash_div(cp, S0, K, r, q, SIG, T, dv; n=2001)
        amy = lr_price(cp, S0, K, r, qm, SIG, T; n=2001)
        vg  = bs_vega(S0 - pv_dividends(dv, r), K, r, q, SIG, T)
        pc, ps = amc - euc, amy - euy
        ret = pc > 1e-9 ? 100*ps/pc : NaN
        push!(rows, (d, iscall(cp) ? "call" : "put", euc, euy, volbp(euy-euc, vg), pc, ps, ret))
        @printf("  %4dd %-5s %9.6f %9.6f %6.1f bp | %12.6f %8.6f %7.0f%%\n",
                d, iscall(cp) ? "call" : "put", euc, euy, volbp(euy-euc,vg), pc, ps, ret)
    end
    writeresult("premium_under_smearing", rows)
    eu = filter(isfinite, rows.eu_diff_bp)
    @printf("\n  distribution effect alone (European, forward matched): %.0f-%.0f bp, both sides\n",
            minimum(eu), maximum(eu))
    p365 = only(filter(x -> x.days==365 && x.cp=="put",  rows))
    c365 = only(filter(x -> x.days==365 && x.cp=="call", rows))
    @printf("  at one year the put's premium is %.1fx the call's (%.3f vs %.3f)\n",
            p365.prem_cash/c365.prem_cash, p365.prem_cash, c365.prem_cash)
    @printf("  and smearing the dividend retains only %.0f%% of it\n", p365.retained_pct)
end
