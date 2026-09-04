#!/usr/bin/env julia
# charts.jl — emits the post's figures as inline SVG, with every coordinate derived from
# results/*.csv. Styling is hand-authored; data is not. Run experiments.jl first.
#
#   julia --project charts.jl        -> writes charts/*.svg
#
# Colours are theme tokens only (currentColor, --color-accent, --color-text-secondary,
# --color-border) so the figures follow light and dark mode.

using CSV, DataFrames, Printf
using Statistics: median, quantile

const OUT = joinpath(@__DIR__, "charts")
const RES = joinpath(@__DIR__, "results")
res(n) = CSV.read(joinpath(RES, n * ".csv"), DataFrame)
esc(s) = replace(string(s), "&"=>"&amp;", "<"=>"&lt;", ">"=>"&gt;")

const AX = "stroke=\"currentColor\" stroke-opacity=\".28\" stroke-width=\"1\""
const GRID = "stroke=\"currentColor\" stroke-opacity=\".10\" stroke-width=\"1\""
txt(x,y,s;anchor="middle",cls="",size=12,op=".62",weight="400") =
    "<text x=\"$(round(x,digits=1))\" y=\"$(round(y,digits=1))\" text-anchor=\"$anchor\" " *
    "font-size=\"$size\" font-weight=\"$weight\" fill=\"currentColor\" fill-opacity=\"$op\" " *
    "font-family=\"var(--font-sans),system-ui,sans-serif\"$cls>$(esc(s))</text>"

function svg(w, h, body; title="")
    io = IOBuffer()
    print(io, "<svg viewBox=\"0 0 $w $h\" xmlns=\"http://www.w3.org/2000/svg\" role=\"img\"")
    isempty(title) || print(io, " aria-label=\"$(esc(title))\"")
    print(io, ">\n", body, "\n</svg>\n")
    String(take!(io))
end

function write_svg(name, s)
    isdir(OUT) || mkpath(OUT)
    open(joinpath(OUT, name * ".svg"), "w") do f; write(f, s); end
    println("  -> charts/$name.svg")
end

# log10 scale helper. Clamped at BOTH ends: clamping only from below lets a value above
# `hi` map outside the plot area and draw beyond the viewBox, silently.
lg(v, lo, hi, a, b) = a + (b - a) * (log10(clamp(v, lo, hi)) - log10(lo)) / (log10(hi) - log10(lo))

# ---------------------------------------------------------------- chart 1: vol bp scale
function chart_volbp()
    d = res("volbp_scale")
    sp = CSV.read(joinpath(@__DIR__, "data", "aapl_spread_summary.csv"), DataFrame)
    atm = sp[findfirst(x -> occursin("front 3", x), sp.bucket), :]
    W, H = 720, 312
    L, R, T, B = 150, 40, 46, 68
    lo, hi = 1.0, 400.0
    io = IOBuffer()
    # AAPL spread band
    x1, x2 = lg(atm.p25_spread_volbp, lo, hi, L, W-R), lg(atm.p75_spread_volbp, lo, hi, L, W-R)
    print(io, "<rect x=\"$(round(x1,digits=1))\" y=\"$T\" width=\"$(round(x2-x1,digits=1))\" ",
              "height=\"$(H-T-B)\" fill=\"currentColor\" fill-opacity=\".07\"/>\n")
    xm = lg(atm.median_spread_volbp, lo, hi, L, W-R)
    print(io, "<line x1=\"$(round(xm,digits=1))\" y1=\"$T\" x2=\"$(round(xm,digits=1))\" y2=\"$(H-B)\" ",
              "stroke=\"currentColor\" stroke-opacity=\".45\" stroke-dasharray=\"3 3\"/>\n")
    print(io, txt(xm, T-24, "AAPL near-ATM market width", size=11, op=".70"))
    print(io, txt(xm, T-10, @sprintf("median %.0f bp (IQR %.0f-%.0f)", atm.median_spread_volbp,
                                     atm.p25_spread_volbp, atm.p75_spread_volbp), size=11, op=".50"))
    # ticks
    for v in (1,3,10,30,100,300)
        x = lg(v, lo, hi, L, W-R)
        print(io, "<line x1=\"$(round(x,digits=1))\" y1=\"$T\" x2=\"$(round(x,digits=1))\" y2=\"$(H-B)\" $GRID/>\n")
        print(io, txt(x, H-B+18, string(v), size=11, op=".55"))
    end
    print(io, txt((L+W-R)/2, H-B+52, "error in implied-vol basis points (log scale)", size=11, op=".55"))
    rowh = (H-T-B) / nrow(d)
    for (i, r) in enumerate(eachrow(d))
        y = T + rowh*(i-0.5)
        print(io, txt(L-12, y+4, r.contract, anchor="end", size=12, op=".85"))
        # 10bp and 100bp markers
        for (v, op, rad) in ((10.0, ".85", 4.5), (100.0, ".35", 4.5))
            x = lg(v, lo, hi, L, W-R)
            print(io, "<circle cx=\"$(round(x,digits=1))\" cy=\"$(round(y,digits=1))\" r=\"$rad\" ",
                      "fill=\"var(--color-accent)\" fill-opacity=\"$op\"/>\n")
        end
        c10 = lg(10.0, lo, hi, L, W-R); c100 = lg(100.0, lo, hi, L, W-R)
        print(io, "<line x1=\"$(round(c10,digits=1))\" y1=\"$(round(y,digits=1))\" x2=\"$(round(c100,digits=1))\" ",
                  "y2=\"$(round(y,digits=1))\" stroke=\"var(--color-accent)\" stroke-opacity=\".35\" stroke-width=\"1.5\"/>\n")
        print(io, txt(W-R-4, y-6, @sprintf("%.1fc  |  %.1fc = %.1f%% of premium", r.bp10_cents,
                                           r.bp100_cents, r.bp100_pct_premium), anchor="end", size=11, op=".60"))
    end
    print(io, "<line x1=\"$L\" y1=\"$(H-B)\" x2=\"$(W-R)\" y2=\"$(H-B)\" $AX/>\n")
    lx0 = lg(10.0, lo, hi, L, W-R); lx1 = lg(100.0, lo, hi, L, W-R)
    print(io, txt(lx0, H-B+36, "10 bp", size=10.5, op=".80"))
    print(io, txt(lx1, H-B+36, "100 bp", size=10.5, op=".45"))
    write_svg("volbp-scale", svg(W, H, String(take!(io)); title="What a basis point of implied volatility is worth"))
end

# ------------------------------------------------------- chart 2: exercise region shape
function chart_boundary()
    d = res("exercise_boundary")
    W, H = 720, 300
    L, R, T, B = 56, 24, 34, 52
    models = ["cash jump", "proportional jump", "constant yield"]
    panelw = (W - L - R) / 3
    # Range comes from the data. A hardcoded window squeezed every curve into the bottom
    # quarter of the panel, in the one figure whose whole subject is boundary shape.
    fin = filter(isfinite, d.boundary)
    pad = 0.06 * (maximum(fin) - minimum(fin))
    ymin, ymax = floor(minimum(fin) - pad), ceil(maximum(fin) + pad)
    io = IOBuffer()
    for (pi, m) in enumerate(models)
        s = filter(x -> x.model == m, d)
        x0 = L + (pi-1)*panelw
        pw = panelw - 26
        Tmax = maximum(s.t)
        print(io, "<line x1=\"$(round(x0,digits=1))\" y1=\"$(H-B)\" x2=\"$(round(x0+pw,digits=1))\" y2=\"$(H-B)\" $AX/>\n")
        print(io, "<line x1=\"$(round(x0,digits=1))\" y1=\"$T\" x2=\"$(round(x0,digits=1))\" y2=\"$(H-B)\" $AX/>\n")
        acc = pi == 3 ? "currentColor" : "var(--color-accent)"
        op  = pi == 3 ? ".45" : ".95"
        pts = String[]
        for r in eachrow(s)
            isfinite(r.boundary) || continue
            x = x0 + pw * (r.t / Tmax)
            y = (H-B) - (H-B-T) * (clamp(r.boundary, ymin, ymax) - ymin)/(ymax - ymin)
            push!(pts, @sprintf("%.1f,%.1f", x, y))
        end
        if length(pts) > 2
            print(io, "<polyline points=\"", join(pts, " "), "\" fill=\"none\" stroke=\"$acc\" ",
                      "stroke-opacity=\"$op\" stroke-width=\"2\" stroke-linejoin=\"round\"/>\n")
        else
            for p in pts
                xy = split(p, ",")
                print(io, "<line x1=\"$(xy[1])\" y1=\"$(xy[2])\" x2=\"$(xy[1])\" y2=\"$(H-B)\" ",
                          "stroke=\"$acc\" stroke-opacity=\"$op\" stroke-width=\"2.5\"/>\n")
            end
        end
        n = count(isfinite, s.boundary)
        print(io, txt(x0 + pw/2, T-14, m, size=12, op=".85", weight="600"))
        print(io, txt(x0 + pw/2, H-B+18, @sprintf("%d of %d levels", n, nrow(s)), size=11, op=".55"))
        pct = 100n/nrow(s)
        lbl = pct < 1 ? @sprintf("(%.1f%% of the option's life)", pct) : @sprintf("(%.0f%% of the option's life)", pct)
        print(io, txt(x0 + pw/2, H-B+33, lbl, size=11, op=".45"))
    end
    print(io, txt(L-8, T+6, string(Int(ymax)), anchor="end", size=10, op=".45"))
    print(io, txt(L-8, H-B, string(Int(ymin)), anchor="end", size=10, op=".45"))
    print(io, txt(20, (T+H-B)/2, "S", anchor="middle", size=11, op=".55"))
    write_svg("exercise-boundary", svg(W, H, String(take!(io));
        title="Early-exercise boundary for an American call under three dividend models"))
end

# ------------------------------------------- chart 3: dividend input error vs pricer error
function chart_inputs()
    d = res("input_vs_pricer_error")
    W, H = 720, 340
    L, R, T, B = 210, 60, 30, 50
    lo, hi = 0.1, 2500.0
    io = IOBuffer()
    for (v, lab) in ((0.1,"0.1"),(1,"1"),(10,"10"),(100,"100"),(1000,"1000"))
        x = lg(v, lo, hi, L, W-R)
        print(io, "<line x1=\"$(round(x,digits=1))\" y1=\"$T\" x2=\"$(round(x,digits=1))\" y2=\"$(H-B)\" $GRID/>\n")
        print(io, txt(x, H-B+18, lab, size=11, op=".55"))
    end
    base = d[1, :]
    xb = lg(base.p50, lo, hi, L, W-R)
    print(io, "<line x1=\"$(round(xb,digits=1))\" y1=\"$T\" x2=\"$(round(xb,digits=1))\" y2=\"$(H-B)\" ",
              "stroke=\"var(--color-accent)\" stroke-opacity=\".55\" stroke-dasharray=\"4 3\"/>\n")
    rowh = (H-T-B)/nrow(d)
    for (i, r) in enumerate(eachrow(d))
        y = T + rowh*(i-0.5)
        isbase = i == 1
        print(io, txt(L-12, y+4, r.scenario, anchor="end", size=11.5,
                      op=isbase ? ".95" : ".78", weight=isbase ? "600" : "400"))
        x50 = lg(r.p50, lo, hi, L, W-R); x95 = lg(r.p95, lo, hi, L, W-R)
        col = isbase ? "var(--color-accent)" : "currentColor"
        print(io, "<line x1=\"$(round(x50,digits=1))\" y1=\"$(round(y,digits=1))\" x2=\"$(round(x95,digits=1))\" ",
                  "y2=\"$(round(y,digits=1))\" stroke=\"$col\" stroke-opacity=\".30\" stroke-width=\"5\" stroke-linecap=\"round\"/>\n")
        print(io, "<circle cx=\"$(round(x50,digits=1))\" cy=\"$(round(y,digits=1))\" r=\"4.5\" fill=\"$col\" fill-opacity=\".95\"/>\n")
        print(io, "<circle cx=\"$(round(x95,digits=1))\" cy=\"$(round(y,digits=1))\" r=\"3\" fill=\"$col\" fill-opacity=\".45\"/>\n")
        print(io, txt(W-R+6, y+4, @sprintf("%.0f", r.p95), anchor="start", size=10.5, op=".45"))
    end
    print(io, "<line x1=\"$L\" y1=\"$(H-B)\" x2=\"$(W-R)\" y2=\"$(H-B)\" $AX/>\n")
    print(io, txt((L+W-R)/2, H-B+38, "implied-vol basis points  —  dot = median, small dot = p95 (log scale)", size=11, op=".55"))
    write_svg("input-vs-pricer", svg(W, H, String(take!(io));
        title="Dividend input error against the pricer's own error"))
end

# -------------------------------------------------- chart 4: smearing penalty by side
function chart_smearing()
    d = res("smearing_by_side")
    W, H = 720, 300
    L, R, T, B = 62, 130, 40, 52
    tenors = unique(d.days)
    lo, hi = 0.01, 1000.0
    io = IOBuffer()
    for (v, lab) in ((0.01,"0.01"),(0.1,"0.1"),(1,"1"),(10,"10"),(100,"100"))
        y = (H-B) - (H-B-T)*(log10(v)-log10(lo))/(log10(hi)-log10(lo))
        print(io, "<line x1=\"$L\" y1=\"$(round(y,digits=1))\" x2=\"$(W-R)\" y2=\"$(round(y,digits=1))\" $GRID/>\n")
        print(io, txt(L-10, y+4, lab, anchor="end", size=11, op=".55"))
    end
    yv(v) = (H-B) - (H-B-T)*(log10(clamp(v,lo,hi))-log10(lo))/(log10(hi)-log10(lo))
    stepx = (W-R-L)/length(tenors)
    for (i, dd) in enumerate(tenors)
        xc = L + stepx*(i-0.5)
        print(io, txt(xc, H-B+20, "$(dd)d", size=11.5, op=".70"))
        for (j, side) in enumerate(("call","put"))
            s = first(filter(x -> x.days==dd && x.cp==side, d))
            x = xc + (j==1 ? -13 : 13)
            col = j==1 ? "var(--color-accent)" : "currentColor"
            op  = j==1 ? ".95" : ".55"
            print(io, "<line x1=\"$(round(x,digits=1))\" y1=\"$(round(yv(s.schedule_p50),digits=1))\" ",
                      "x2=\"$(round(x,digits=1))\" y2=\"$(round(yv(s.yield_p50),digits=1))\" ",
                      "stroke=\"$col\" stroke-opacity=\".25\" stroke-width=\"6\" stroke-linecap=\"round\"/>\n")
            print(io, "<circle cx=\"$(round(x,digits=1))\" cy=\"$(round(yv(s.schedule_p50),digits=1))\" r=\"3.5\" ",
                      "fill=\"none\" stroke=\"$col\" stroke-opacity=\"$op\" stroke-width=\"1.6\"/>\n")
            print(io, "<circle cx=\"$(round(x,digits=1))\" cy=\"$(round(yv(s.yield_p50),digits=1))\" r=\"4.5\" ",
                      "fill=\"$col\" fill-opacity=\"$op\"/>\n")
        end
    end
    print(io, "<line x1=\"$L\" y1=\"$(H-B)\" x2=\"$(W-R)\" y2=\"$(H-B)\" $AX/>\n")
    print(io, "<line x1=\"$L\" y1=\"$T\" x2=\"$L\" y2=\"$(H-B)\" $AX/>\n")
    lx = W-R+16
    print(io, "<circle cx=\"$(lx+6)\" cy=\"$(T+16)\" r=\"4.5\" fill=\"var(--color-accent)\" fill-opacity=\".95\"/>\n")
    print(io, txt(lx+18, T+20, "call, smeared", anchor="start", size=11, op=".70"))
    print(io, "<circle cx=\"$(lx+6)\" cy=\"$(T+36)\" r=\"4.5\" fill=\"currentColor\" fill-opacity=\".55\"/>\n")
    print(io, txt(lx+18, T+40, "put, smeared", anchor="start", size=11, op=".70"))
    print(io, "<circle cx=\"$(lx+6)\" cy=\"$(T+56)\" r=\"3.5\" fill=\"none\" stroke=\"currentColor\" stroke-opacity=\".7\" stroke-width=\"1.6\"/>\n")
    print(io, txt(lx+18, T+60, "same, on the", anchor="start", size=11, op=".70"))
    print(io, txt(lx+18, T+74, "real schedule", anchor="start", size=11, op=".70"))
    print(io, txt(L-10, T-12, "vol bp", anchor="end", size=11, op=".55"))
    write_svg("smearing-by-side", svg(W, H, String(take!(io));
        title="Median error from smearing a discrete dividend into a yield, by tenor and side"))
end

# --------------------------------------------------------- chart 5: oracle convergence
function chart_oracle()
    d = res("oracle_convergence")
    q = res("oracle_vs_quadrature")
    W, H = 720, 290
    L, R, T, B = 66, 190, 34, 52
    io = IOBuffer()
    lo, hi = 1e-5, 1e-1
    yv(v) = (H-B) - (H-B-T)*(log10(clamp(abs(v),lo,hi))-log10(lo))/(log10(hi)-log10(lo))
    for e in (-5,-4,-3,-2,-1)
        y = yv(10.0^e)
        print(io, "<line x1=\"$L\" y1=\"$(round(y,digits=1))\" x2=\"$(W-R)\" y2=\"$(round(y,digits=1))\" $GRID/>\n")
        print(io, txt(L-10, y+4, "1e$e", anchor="end", size=10.5, op=".55"))
    end
    for (fam, col, op) in (("lattice","var(--color-accent)",".95"), ("fd","currentColor",".65"))
        s = filter(x -> x.engine == fam, d)
        n = nrow(s)
        pts = [@sprintf("%.1f,%.1f", L + (W-R-L)*(i-1)/(n-1), yv(r.vs_finest)) for (i,r) in enumerate(eachrow(s))]
        print(io, "<polyline points=\"", join(pts," "), "\" fill=\"none\" stroke=\"$col\" ",
                  "stroke-opacity=\"$op\" stroke-width=\"2\"/>\n")
        for (i,r) in enumerate(eachrow(s))
            x = L + (W-R-L)*(i-1)/(n-1)
            print(io, "<circle cx=\"$(round(x,digits=1))\" cy=\"$(round(yv(r.vs_finest),digits=1))\" r=\"3.5\" fill=\"$col\" fill-opacity=\"$op\"/>\n")
            fam == "fd" && print(io, txt(x, H-B+18, r.setting, size=9.5, op=".45"))
            fam == "lattice" && print(io, txt(x, T-8, replace(r.setting,"n="=>""), size=9.5, op=".45"))
        end
    end
    print(io, "<line x1=\"$L\" y1=\"$(H-B)\" x2=\"$(W-R)\" y2=\"$(H-B)\" $AX/>\n")
    print(io, "<line x1=\"$L\" y1=\"$T\" x2=\"$L\" y2=\"$(H-B)\" $AX/>\n")
    lx = W-R+14
    print(io, "<circle cx=\"$(lx+5)\" cy=\"$(T+14)\" r=\"4\" fill=\"var(--color-accent)\" fill-opacity=\".95\"/>\n")
    print(io, txt(lx+16, T+18, "lattice steps (top axis)", anchor="start", size=11, op=".70"))
    print(io, "<circle cx=\"$(lx+5)\" cy=\"$(T+30)\" r=\"4\" fill=\"currentColor\" fill-opacity=\".65\"/>\n")
    print(io, txt(lx+16, T+34, "FD grid (bottom axis)", anchor="start", size=11, op=".70"))
    print(io, txt(lx, T+62, "against exact quadrature", anchor="start", size=11, op=".80", weight="600"))
    print(io, txt(lx, T+78, @sprintf("lattice  %.3f bp median", median(q.lattice_bp)), anchor="start", size=11, op=".60"))
    print(io, txt(lx, T+94, @sprintf("FD       %.3f bp median", median(q.fd_bp)), anchor="start", size=11, op=".60"))
    print(io, txt(L, T-22, "price error vs each family's own finest grid", anchor="start", size=11, op=".55"))
    print(io, txt((L+W-R)/2, H-B+38, "refinement -->", size=11, op=".45"))
    write_svg("oracle-convergence", svg(W, H, String(take!(io));
        title="Convergence of the lattice and finite-difference references"))
end


# ------------------------------------------- chart 6: agreement against the exact answer
# §4's question is "do structurally unrelated methods agree with truth", not "how fast
# does each converge" -- that second question belongs to part 3. This plots the whole
# distribution rather than a point estimate.
function chart_agreement()
    q = res("oracle_vs_quadrature")
    W, H = 720, 236
    L, R, T, B = 132, 92, 44, 56
    lo, hi = 1e-4, 1e-1
    io = IOBuffer()
    for e in (-4, -3, -2, -1)
        x = lg(10.0^e, lo, hi, L, W-R)
        print(io, "<line x1=\"$(round(x,digits=1))\" y1=\"$T\" x2=\"$(round(x,digits=1))\" y2=\"$(H-B)\" $GRID/>\n")
        lab = e == -1 ? "0.1" : (e == -2 ? "0.01" : (e == -3 ? "0.001" : "0.0001"))
        print(io, txt(x, H-B+18, lab, size=11, op=".55"))
    end
    series = (("lattice", q.lattice_bp, "var(--color-accent)", ".95"),
              ("finite differences", q.fd_bp, "currentColor", ".62"))
    rowh = (H-T-B) / length(series)
    for (i, (nm, v, col, op)) in enumerate(series)
        y = T + rowh*(i-0.5)
        sv = sort(collect(v))
        # Statistics.quantile, matching harness.jl -- a nearest-rank estimator here would
        # print a "median" that disagrees with the one quoted in the prose.
        qt(p) = quantile(sv, p)
        x25, x50, x75 = lg(qt(0.25),lo,hi,L,W-R), lg(qt(0.50),lo,hi,L,W-R), lg(qt(0.75),lo,hi,L,W-R)
        xmin, xmax = lg(sv[1],lo,hi,L,W-R), lg(sv[end],lo,hi,L,W-R)
        print(io, txt(L-12, y+4, nm, anchor="end", size=12, op=".85"))
        # every case, faintly, so the reader sees the spread rather than a summary
        for (k, val) in enumerate(sv)
            xx = lg(val, lo, hi, L, W-R)
            jitter = ((k % 7) - 3) * 1.6
            print(io, "<circle cx=\"$(round(xx,digits=1))\" cy=\"$(round(y+jitter,digits=1))\" r=\"1.6\" fill=\"$col\" fill-opacity=\".16\"/>\n")
        end
        print(io, "<line x1=\"$(round(xmin,digits=1))\" y1=\"$(round(y,digits=1))\" x2=\"$(round(xmax,digits=1))\" y2=\"$(round(y,digits=1))\" stroke=\"$col\" stroke-opacity=\".30\" stroke-width=\"1.2\"/>\n")
        print(io, "<rect x=\"$(round(x25,digits=1))\" y=\"$(round(y-9,digits=1))\" width=\"$(round(max(x75-x25,1.5),digits=1))\" height=\"18\" fill=\"$col\" fill-opacity=\".16\" stroke=\"$col\" stroke-opacity=\".35\"/>\n")
        print(io, "<line x1=\"$(round(x50,digits=1))\" y1=\"$(round(y-11,digits=1))\" x2=\"$(round(x50,digits=1))\" y2=\"$(round(y+11,digits=1))\" stroke=\"$col\" stroke-opacity=\"$op\" stroke-width=\"2.4\"/>\n")
        print(io, txt(W-R+8, y+4, @sprintf("median %.3f", qt(0.50)), anchor="start", size=10.5, op=".55"))
    end
    print(io, "<line x1=\"$L\" y1=\"$(H-B)\" x2=\"$(W-R)\" y2=\"$(H-B)\" $AX/>\n")
    print(io, txt((L+W-R)/2, H-B+38, "error against the exact answer, implied-vol basis points (log scale)", size=11, op=".55"))
    print(io, txt(L, T-16, "each dot is one of 108 contracts; box is the interquartile range", anchor="start", size=11, op=".50"))
    write_svg("oracle-agreement", svg(W, H, String(take!(io));
        title="Lattice and finite-difference error against the exact quadrature answer"))
end

function main()
    println("Generating figures from results/ ...")
    chart_volbp(); chart_boundary(); chart_inputs(); chart_smearing()
    chart_oracle(); chart_agreement()
    println("Done.")
end
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
