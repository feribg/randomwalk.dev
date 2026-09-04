# §4 — the oracle problem. Three independent families must agree before any accuracy
# claim later in the post means anything.
#
#   1. Leisen-Reimer lattice with a Vellekoop-Nieuwenhuis cash jump
#   2. Crank-Nicolson/Rannacher finite differences with the ex-date pinned to a step
#   3. direct quadrature, which is exact and is only available at r = 0
#
# Nothing here is carried from anywhere. The two carried floors quoted in the post
# (QuantLib QdFp vs LR-1001 at 0.2418 bp p95; lattice vs FD at 0.134/0.501/2.07 bp over
# the 1,296-case study) are NOT reproduced by this script and are labelled as carried.

function oracle_agreement()
    banner(1, "ORACLE AGREEMENT — do independent families agree?")
    S0, SIG = 100.0, 0.28
    R = 0.04

    # -- (a) lattice vs FD over the 216-case dividend grid ---------------------------
    rows = DataFrame(cp=String[], days=Int[], divfrac=Float64[], tfrac=Float64[],
                     moneyness=Float64[], lattice=Float64[], fd=Float64[],
                     absdiff=Float64[], volbp=Float64[])
    for cp in (Call(), Put()), d in (30, 91, 182, 365), fr in (0.005, 0.01, 0.02),
        tf in (0.25, 0.6, 0.85), m in (0.90, 1.0, 1.10)

        T = d / 365
        K = S0 / m
        divs = [CashDiv(tf * T, fr * S0)]
        lat = lr_cash_div(cp, S0, K, R, 0.0, SIG, T, divs; n=4001)
        fdv = fd_cash_div(cp, S0, K, R, 0.0, SIG, T, divs; nx=2400, nt=1200)
        pv = pv_dividends(divs, R)
        vg = bs_vega(S0 - pv, K, R, 0.0, SIG, T)
        push!(rows, (iscall(cp) ? "call" : "put", d, fr, tf, m, lat, fdv,
                     abs(fdv - lat), vg > VEGA_FLOOR ? volbp(fdv - lat, vg) : NaN))
    end
    bps = filter(isfinite, rows.volbp)
    @printf("  (a) lattice(LR-4001) vs FD(2400x1200), %d cases, %d scored\n",
            nrow(rows), length(bps))
    @printf("      |FD - lattice|  median %.3f bp   p95 %.3f bp   max %.3f bp\n",
            nmed(bps), p95v(bps), maximum(bps))
    @printf("      in price terms   median %.2e   max %.2e\n",
            nmed(rows.absdiff), maximum(rows.absdiff))
    writeresult("oracle_lattice_vs_fd", rows)

    # -- (b) both against exact quadrature at r = 0 -----------------------------------
    # At r = 0 (with q >= 0) a put is never exercised early, so the American price
    # equals the European one, which quadrature gives exactly.
    q = DataFrame(days=Int[], divfrac=Float64[], tfrac=Float64[], moneyness=Float64[],
                  exact=Float64[], lattice_bp=Float64[], fd_bp=Float64[])
    for d in (30, 91, 182, 365), fr in (0.005, 0.01, 0.02), tf in (0.25, 0.6, 0.85),
        m in (0.90, 1.0, 1.10)
        T = d / 365
        K = S0 / m
        dv = CashDiv(tf * T, fr * S0)
        ex  = quad_european_cash_div(Put(), S0, K, 0.0, 0.0, SIG, T, dv; nodes=600)
        lat = lr_cash_div(Put(), S0, K, 0.0, 0.0, SIG, T, [dv]; n=4001)
        fdv = fd_cash_div(Put(), S0, K, 0.0, 0.0, SIG, T, [dv]; nx=2400, nt=1200)
        vg = bs_vega(S0 - fr * S0 * exp(0.0), K, 0.0, 0.0, SIG, T)
        vg > VEGA_FLOOR || continue
        push!(q, (d, fr, tf, m, ex, volbp(lat - ex, vg), volbp(fdv - ex, vg)))
    end
    @printf("\n  (b) vs EXACT quadrature at r = 0, %d scored cases\n", nrow(q))
    @printf("      lattice  median %.3f bp   p95 %.3f bp   max %.3f bp\n",
            nmed(q.lattice_bp), p95v(q.lattice_bp), maximum(q.lattice_bp))
    @printf("      FD       median %.3f bp   p95 %.3f bp   max %.3f bp\n",
            nmed(q.fd_bp), p95v(q.fd_bp), maximum(q.fd_bp))
    writeresult("oracle_vs_quadrature", q)

    # -- (c) the reference's own convergence, so its error budget is stated ------------
    conv = DataFrame(engine=String[], setting=String[], price=Float64[], vs_finest=Float64[])
    T, K = 0.5, 100.0
    dv = [CashDiv(0.25, 2.0)]
    fine_l = lr_cash_div(Put(), S0, K, R, 0.0, SIG, T, dv; n=25601)
    fine_f = fd_cash_div(Put(), S0, K, R, 0.0, SIG, T, dv; nx=4800, nt=2400)
    for n in (101, 401, 1601, 6401, 12801)
        v = lr_cash_div(Put(), S0, K, R, 0.0, SIG, T, dv; n=n)
        push!(conv, ("lattice", "n=$n", v, v - fine_l))
    end
    for (nx, nt) in ((200,100),(400,200),(800,400),(1600,800),(2400,1200))
        v = fd_cash_div(Put(), S0, K, R, 0.0, SIG, T, dv; nx=nx, nt=nt)
        push!(conv, ("fd", "$(nx)x$(nt)", v, v - fine_f))
    end
    println("\n  (c) each family's own convergence (91d-equivalent ATM put, D=2 at 0.5T)")
    for r in eachrow(conv)
        @printf("      %-8s %-12s %.10f   %+.2e\n", r.engine, r.setting, r.price, r.vs_finest)
    end
    writeresult("oracle_convergence", conv)

    # -- (d) Brennan-Schwartz vs PSOR: does the connected-exercise-region assumption hold?
    bsp = DataFrame(cp=String[], r=Float64[], q=Float64[], sigma=Float64[], absdiff=Float64[])
    for cp in (Call(), Put()), (rr, qq) in ((0.05,0.02),(0.02,0.08),(0.08,0.0)), s in (0.15,0.35,0.6)
        a = fd_american(cp,S0,100.0,rr,qq,s,1.0; nx=300,nt=150,solver=:brennan_schwartz)
        b = fd_american(cp,S0,100.0,rr,qq,s,1.0; nx=300,nt=150,solver=:psor)
        push!(bsp, (iscall(cp) ? "call" : "put", rr, qq, s, abs(a-b)))
    end
    @printf("\n  (d) Brennan-Schwartz vs PSOR over %d configs: max |diff| = %.2e\n",
            nrow(bsp), maximum(bsp.absdiff))
    writeresult("oracle_bs_vs_psor", bsp)
end
