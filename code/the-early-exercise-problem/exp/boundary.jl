# Chart 5 — the early-exercise boundary under three dividend models.
#
# The shape is the whole argument of §7: under a cash or proportional jump, exercising an
# American call is optimal only in a thin sliver just before the ex-date. Under a constant
# yield it is optimal over a whole region of time. Same forward, same total dividend PV,
# completely different exercise behaviour -- so the constant-yield price is not a coarse
# approximation of the cash price, it is a different model.

"""
Roll a Leisen-Reimer tree back and record, at every level, the exercise boundary: the
spot at which continuing stops being worth more than exercising.

`jumpfn(level_index) -> (cash, keep)` describes the dividend at that level; the post-jump
spot is `S*keep - cash`, so cash dividends set `keep = 1` and proportional ones `cash = 0`.

The rollback deliberately reuses `American.lr_params` and `American.jump_shift!` rather
than re-deriving them. An earlier version inlined its own copy of the Peizer-Pratt
inversion and its own interpolation, which meant the boundary this chart draws could drift
away from the prices every other table reports without anything failing.
"""
function boundary_curve(cp::OptionType, S, K, r, q, sigma, T, n::Int, jumpfn)
    nn = American.force_odd(n)
    dt = T / nn
    u, d, p = American.lr_params(S, K, r, q, sigma, T, nn)
    isnan(p) && error("lattice parameters degenerate at S=$S K=$K sigma=$sigma T=$T n=$nn")
    disc = exp(-r * dt)
    pu, pd = disc * p, disc * (1 - p)
    w = omega(cp)
    lu, ld = log(u), log(d)

    v = [max(w * (S * exp(j*lu + (nn-j)*ld) - K), 0.0) for j in 0:nn]
    spots = zeros(nn + 1)
    shifted = zeros(nn + 1)
    ts = Float64[]; bs = Float64[]
    for i in (nn-1):-1:0
        for j in 0:i; v[j+1] = pu*v[j+2] + pd*v[j+1]; end
        for j in 0:i; spots[j+1] = S*exp(j*lu + (i-j)*ld); end
        cash, keep = jumpfn(i + 1)
        if cash != 0.0 || keep != 1.0
            American.jump_shift!(shifted, v, spots, i + 1, cp, K, S_ -> S_*keep - cash)
        end
        # the boundary is read off the CONTINUATION value, before the exercise projection
        b = NaN
        for j in 0:i
            ex = w * (spots[j+1] - K)
            if ex > 0 && v[j+1] <= ex + 1e-12
                b = spots[j+1]
                iscall(cp) && break          # calls: lowest exercised spot
            end
        end
        for j in 0:i; v[j+1] = max(v[j+1], w*(spots[j+1] - K)); end
        push!(ts, i*dt); push!(bs, b)
    end
    return reverse(ts), reverse(bs)
end

function exercise_boundary()
    banner(11, "EXERCISE BOUNDARY — the shape the constant-yield model gets wrong")
    S0, K, r, sig = 100.0, 100.0, 0.06, 0.30
    T, tb, beta = 91/365, 40/365, 0.07
    alpha = beta*S0*exp(r*tb)
    q_eq = r - log(S0*exp(r*T)*(1-beta)/S0)/T
    n = 801; dt = T/n
    kcash = clamp(ceil(Int, tb/dt), 1, n)

    models = ("cash jump"        => (0.0, (i) -> i == kcash ? (alpha, 1.0) : (0.0, 1.0)),
              "proportional jump"=> (0.0, (i) -> i == kcash ? (0.0, 1-beta) : (0.0, 1.0)),
              "constant yield"   => (q_eq, (i) -> (0.0, 1.0)))
    rows = DataFrame(model=String[], t=Float64[], boundary=Float64[])
    for (nm, (qq, jf)) in models
        ts, bs = boundary_curve(Call(), S0, K, r, qq, sig, T, n, jf)
        for (t, b) in zip(ts, bs)
            push!(rows, (nm, t, b))
        end
        live = count(isfinite, bs)
        @printf("  %-19s exercise optimal somewhere at %3d of %3d time levels (%.0f%% of the life)\n",
                nm, live, length(bs), 100live/length(bs))
    end
    writeresult("exercise_boundary", rows)
    println("\n  A cash or proportional dividend makes call exercise optimal only around the")
    println("  ex-date. A constant yield spreads it across the whole life. Same forward,")
    println("  different exercise region -- which is why no volatility reconciles them.")
end
