# american.jl — self-contained American option pricers for
# "The Early Exercise Problem" (randomwalk.dev).
#
# Everything the post claims is computed here. No dependency on any private tree.
#
# Engines:
#   Black-Scholes             closed form, greeks, implied vol
#   Leisen-Reimer             binomial lattice, Peizer-Pratt inversion
#   CRR                       for contrast only; diverges when sigma < |r-q|*sqrt(dt)
#   LR + cash jump            Vellekoop-Nieuwenhuis discrete cash dividends
#   LR + proportional jump    the same rollback with a multiplicative jump
#   FD (CN + Rannacher)       uniform log grid, Brennan-Schwartz or PSOR
#   Quadrature (Gauss-Legendre) exact European under the spot model, the third oracle
#
# Conventions used throughout:
#   * `cp` is `Call()` or `Put()`; `w = omega(cp)` is +1 / -1.
#   * `q` is a CONTINUOUS carry (borrow / lending fee). Discrete dividends are passed
#     separately as `CashDiv`/`PropDiv` and must NOT also be folded into `q`.
#   * `theta` is -dV/dT. Error is reported in implied-vol basis points: 1 bp = 1e-4 of sigma.

module American

using SpecialFunctions: erfc, erfcx
using FastGaussQuadrature: gausslegendre

export Call, Put, OptionType, omega, iscall, isput, intrinsic, forward
export CashDiv, PropDiv
export bs_price, bs_vega, bs_greeks, bs_implied_vol, bs_d1d2
export lr_price, crr_price, lr_cash_div, lr_prop_div
export fd_american, fd_cash_div
export quad_european_cash_div
export escrowed_price, matched_q_price, scalar_q_price, matched_q, pv_dividends
export volbp, volbp_to_price, volbp_to_premium_pct
export zero_vol_american

# ---------------------------------------------------------------------------
# types and small helpers
# ---------------------------------------------------------------------------

abstract type OptionType end
struct Call <: OptionType end
struct Put  <: OptionType end

iscall(::Call) = true
iscall(::Put)  = false
isput(cp::OptionType) = !iscall(cp)
omega(::Call) =  1.0
omega(::Put)  = -1.0

intrinsic(cp::OptionType, S, K) = max(omega(cp) * (S - K), 0.0)
forward(S, r, q, T) = S * exp((r - q) * T)

"""A cash dividend of `amount` with ex-date at time `t` (year fraction from valuation)."""
struct CashDiv
    t::Float64
    amount::Float64
end

"""A proportional dividend: the stock drops by a `frac` of its own price at time `t`."""
struct PropDiv
    t::Float64
    frac::Float64
end

const INV_SQRT_2 = 0.7071067811865476
const INV_SQRT_2PI = 0.3989422804014327

# erfc form rather than 0.5*(1+erf(x/sqrt(2))): it keeps full relative accuracy in the
# far left tail, where the naive form cancels to zero.
norm_cdf(x) = erfc(-x * INV_SQRT_2) / 2
norm_pdf(x) = INV_SQRT_2PI * exp(-x * x / 2)

# ---------------------------------------------------------------------------
# Black-Scholes
# ---------------------------------------------------------------------------

@inline function bs_d1d2(S, K, r, q, sigma, T)
    v = sigma * sqrt(T)
    d1 = (log(S / K) + (r - q) * T) / v + v / 2
    return d1, d1 - v
end

"""
    bs_price(cp, S, K, r, q, sigma, T)

European Black-Scholes-Merton value. Degenerate inputs (`T<=0`, `sigma<=0`, `S<=0`)
collapse to the discounted intrinsic value of the forward, which is the correct
zero-variance limit and keeps the function total instead of returning NaN.
"""
function bs_price(cp::OptionType, S, K, r, q, sigma, T)
    if !(T > 0) || !(sigma > 0) || !(S > 0)
        return exp(-r * T) * intrinsic(cp, forward(S, r, q, T), K)
    end
    d1, d2 = bs_d1d2(S, K, r, q, sigma, T)
    df_S = S * exp(-q * T)
    df_K = K * exp(-r * T)
    return iscall(cp) ? df_S * norm_cdf(d1) - df_K * norm_cdf(d2) :
                        df_K * norm_cdf(-d2) - df_S * norm_cdf(-d1)
end

"""`dV/dsigma`, per unit of volatility (not per volatility point). Same for calls and puts."""
function bs_vega(S, K, r, q, sigma, T)
    (T > 0 && sigma > 0 && S > 0) || return 0.0
    d1, _ = bs_d1d2(S, K, r, q, sigma, T)
    return S * exp(-q * T) * norm_pdf(d1) * sqrt(T)
end

"""Analytic first- and second-order greeks in one pass. `theta` is -dV/dT."""
function bs_greeks(cp::OptionType, S, K, r, q, sigma, T)
    if !(T > 0) || !(sigma > 0) || !(S > 0)
        v = bs_price(cp, S, K, r, q, sigma, T)
        return (value=v, delta=0.0, gamma=0.0, vega=0.0, theta=0.0,
                rho=0.0, vanna=0.0, vomma=0.0)
    end
    d1, d2 = bs_d1d2(S, K, r, q, sigma, T)
    sq = sqrt(T)
    dq, dr = exp(-q * T), exp(-r * T)
    phi = norm_pdf(d1)
    vega  = S * dq * phi * sq
    gamma = dq * phi / (S * sigma * sq)
    vanna = -dq * phi * d2 / sigma
    vomma = vega * d1 * d2 / sigma
    common = -S * dq * phi * sigma / (2 * sq)
    value = bs_price(cp, S, K, r, q, sigma, T)
    if iscall(cp)
        delta = dq * norm_cdf(d1)
        theta = common - r * K * dr * norm_cdf(d2) + q * S * dq * norm_cdf(d1)
        rho   = K * T * dr * norm_cdf(d2)
    else
        delta = -dq * norm_cdf(-d1)
        theta = common + r * K * dr * norm_cdf(-d2) - q * S * dq * norm_cdf(-d1)
        rho   = -K * T * dr * norm_cdf(-d2)
    end
    return (value=value, delta=delta, gamma=gamma, vega=vega, theta=theta,
            rho=rho, vanna=vanna, vomma=vomma)
end

const IV_LO = 1e-4
const IV_HI = 5.0

"""
    bs_implied_vol(cp, target, S, K, r, q, T) -> (sigma, iters, converged)

Safeguarded Newton off a Brenner-Subrahmanyam seed, bracketed to `[1e-4, 5]`.

This is deliberately the simple solver, not the state of the art. Healy §2.4 pairs a
Stefanica-Radoicic seed with a third-order Householder iteration and reaches 1e-14 in a
few hundred nanoseconds; that is the right choice in production and the wrong choice for
a post whose point is elsewhere. Newton is safeguarded to bisection at every step so it
cannot walk out of the bracket.

`converged == false` means no volatility reproduces `target` — usually a price at or
below intrinsic, which is a property of the quote, not a solver failure.
"""
function bs_implied_vol(cp::OptionType, target, S, K, r, q, T; tol=1e-10, maxiter=100)
    f(s) = bs_price(cp, S, K, r, q, s, T) - target
    lo, hi = IV_LO, IV_HI
    flo, fhi = f(lo), f(hi)
    (isfinite(flo) && isfinite(fhi)) || return (NaN, 0, false)
    flo > 0 && return (NaN, 0, false)      # target below the zero-vol floor
    fhi < 0 && return (NaN, 0, false)      # target above the sigma -> inf limit
    # Brenner-Subrahmanyam: sigma ~ sqrt(2pi/T) * price / S. Crude but always inside.
    s = clamp(sqrt(2pi / T) * target / S, 0.05, 3.0)
    for it in 1:maxiter
        fs = f(s)
        abs(fs) < tol && return (s, it, true)
        fs > 0 ? (hi = s) : (lo = s)
        v = bs_vega(S, K, r, q, s, T)
        snew = v > 1e-12 ? s - fs / v : (lo + hi) / 2
        # safeguard: any Newton step leaving the bracket falls back to bisection
        (snew <= lo || snew >= hi || !isfinite(snew)) && (snew = (lo + hi) / 2)
        abs(snew - s) < 1e-14 && return (snew, it, true)
        s = snew
    end
    return (s, maxiter, false)
end

# ---------------------------------------------------------------------------
# error measurement
# ---------------------------------------------------------------------------

"""
    volbp(price_err, vega) -> Float64

Convert an absolute price error to implied-vol basis points. `1e4 * err / vega` because
vega is per unit of vol and a basis point is 1e-4 of that.

Only meaningful when vega is not small — every table in the post applies a `vega > 0.1`
filter for exactly this reason.
"""
volbp(price_err, vega) = 1e4 * abs(price_err) / vega

"""Inverse of `volbp`: what a given vol-bp error is worth in price terms."""
volbp_to_price(bp, vega) = bp * 1e-4 * vega

"""What a given vol-bp error is worth as a percentage of the option premium."""
volbp_to_premium_pct(bp, vega, premium) = 100 * volbp_to_price(bp, vega) / premium

"""
    zero_vol_american(cp, S, K, r, q, T)

Value at zero volatility. The stock follows a known path, so the only question is when to
exercise: `max` over `t` in `[0,T]` of `exp(-r*t) * intrinsic(S*exp((r-q)*t), K)`.

Wherever the payoff is positive that is `S*exp(-q*t) - K*exp(-r*t)` for a call and its
mirror for a put, both smooth, so the maximum sits at an endpoint, at the moneyness
crossing, or at the stationary point where `q*S*exp(-q*t) = r*K*exp(-r*t)`. Discounting
the terminal intrinsic instead would understate a deep in-the-money put, which is worth
exercising now rather than at expiry.
"""
# Deterministic spot net of a schedule, for the zero-volatility limit only.
ex_div_spot(S, divs::Vector{CashDiv}, r) = S - sum(d.amount * exp(-r * d.t) for d in divs; init=0.0)
ex_div_spot(S, divs::Vector{PropDiv}, r) = S * prod(1 - d.frac for d in divs; init=1.0)

function zero_vol_american(cp::OptionType, S, K, r, q, T)
    val(t) = exp(-r * t) * intrinsic(cp, S * exp((r - q) * t), K)
    best = max(val(0.0), val(T))
    for t in (log(K / S) / (r - q), log(q * S / (r * K)) / (q - r))
        isfinite(t) && 0 < t < T && (best = max(best, val(t)))
    end
    return best
end

# ---------------------------------------------------------------------------
# lattices
# ---------------------------------------------------------------------------

"""
Peizer-Pratt inversion, their formula 2: the up-probability whose `n`-step binomial has
standard normal quantile `z` at its centre. This is what makes Leisen-Reimer
strike-centred by construction, and why `n` must be odd.
"""
@inline function peizer_pratt(z, n)
    c = z / (n + 1/3 + 0.1 / (n + 1))
    return 0.5 + copysign(0.5 * sqrt(-expm1(-c * c * (n + 1/6))), z)
end

"""
Leisen-Reimer up/down factors and probability. Note `u*d != 1` away from the money.

Returns NaN where the inversion degenerates, which happens at both ends and for different
reasons. As `p` goes to zero — a deeply out-of-the-money contract at low volatility, where
`d2` underflows the inversion — `u = e^{(r-q)dt} p_t / p` overflows and the `p*u` term in
`d` becomes `0 * Inf`. As `p` goes to one, `d` divides by `1 - p`. Neither is a small
error to be tolerated: the tree parameters simply do not exist there. Reporting NaN makes
that visible instead of letting it propagate silently through a rollback, the same choice
`crr_params` makes for its own breakdown.

In practice this is a wing-and-low-volatility phenomenon. Nothing in the post's grids
comes near it; an implied-vol search over a full option chain does.
"""
@inline function lr_params(S, K, r, q, sigma, T, n)
    dt = T / n
    d1, d2 = bs_d1d2(S, K, r, q, sigma, T)
    p  = peizer_pratt(d2, n)
    pt = peizer_pratt(d1, n)
    (0 < p < 1) || return (NaN, NaN, NaN)
    u = exp((r - q) * dt) * pt / p
    d = (exp((r - q) * dt) - p * u) / (1 - p)
    (isfinite(u) && isfinite(d)) || return (NaN, NaN, NaN)
    return u, d, p
end

"""
Cox-Ross-Rubinstein parameters.

`u` and `d` depend only on `sigma*sqrt(dt)` while the drift enters through `p`, so when
the carry outweighs the diffusion — `sigma < |r-q|*sqrt(dt)` — the implied probability
leaves `[0,1]` and the recursion stops being an expectation. It then diverges violently
rather than losing accuracy gracefully. Returning NaN reports the breakdown instead of
propagating a meaningless number.
"""
@inline function crr_params(S, K, r, q, sigma, T, n)
    dt = T / n
    u = exp(sigma * sqrt(dt))
    d = 1 / u
    p = (exp((r - q) * dt) - d) / (u - d)
    (0 <= p <= 1) || return (NaN, NaN, NaN)
    return u, d, p
end

force_odd(n::Integer) = isodd(n) ? Int(n) : Int(n) + 1

"""Backward induction with American exercise at every node."""
function lattice_rollback(cp::OptionType, S, K, r, T, n, u, d, p)
    dt = T / n
    disc = exp(-r * dt)
    pu, pd = disc * p, disc * (1 - p)
    ud = u / d
    w = omega(cp)
    logu, logd = log(u), log(d)

    v = Vector{Float64}(undef, n + 1)
    # One exp per terminal node rather than a running product, so the deepest nodes do
    # not accumulate the relative error of n successive multiplications.
    @inbounds for j in 0:n
        Sj = S * exp(j * logu + (n - j) * logd)
        v[j+1] = max(w * (Sj - K), 0.0)
    end
    @inbounds for i in (n-1):-1:0
        Sj = S * exp(i * logd)
        for j in 0:i
            cont = pu * v[j+2] + pd * v[j+1]
            v[j+1] = max(cont, w * (Sj - K))
            Sj *= ud
        end
    end
    return v[1]
end

"""American price on a Leisen-Reimer tree. `n` is forced odd. NaN where `lr_params` degenerates."""
function lr_price(cp::OptionType, S, K, r, q, sigma, T; n::Integer=101)
    T > 0 || return intrinsic(cp, S, K)
    sigma > 0 || return zero_vol_american(cp, S, K, r, q, T)
    nn = force_odd(n)
    u, d, p = lr_params(S, K, r, q, sigma, T, nn)
    isnan(p) && return NaN
    return lattice_rollback(cp, S, K, r, T, nn, u, d, p)
end

"""American price on a CRR tree. Returns NaN where the CRR probability leaves [0,1]."""
function crr_price(cp::OptionType, S, K, r, q, sigma, T; n::Integer=101)
    T > 0 || return intrinsic(cp, S, K)
    u, d, p = crr_params(S, K, r, q, sigma, T, n)
    isnan(p) && return NaN
    return lattice_rollback(cp, S, K, r, T, n, u, d, p)
end

"""
Linear interpolation of lattice values `v` on ascending spots `s`, evaluated at `x`.

Kept only as the fallback for the last few levels of the tree, where there are too few
nodes for the four-point rule `jump_shift!` normally uses.
"""
@inline function interp_lin(s, v, x, m)
    x <= s[1] && return v[1]
    x >= s[m] && return v[m]
    lo, hi = 1, m
    while hi - lo > 1
        mid = (lo + hi) >>> 1
        s[mid] <= x ? (lo = mid) : (hi = mid)
    end
    w = (x - s[lo]) / (s[hi] - s[lo])
    return v[lo] * (1 - w) + v[hi] * w
end

"""
    jump_shift!(shifted, v, spots, m, cp, K, post)

Apply a dividend jump to the value function in place: `V(S, t-) = V(post(S), t+)`, where
`post` maps a cum-dividend spot to its ex-dividend value. `shifted` is scratch.

The interpolation is FOURTH-ORDER, in log-spot, and that choice is worth a word because
linear is the obvious thing and costs an order of magnitude. A lattice's value function is
convex, so a chord between two nodes lies above it; linear interpolation therefore biases
every jump the same way and the errors accumulate instead of cancelling. Measured against
the exact quadrature over the 108-case grid of `oracle_agreement`, linear lands at 0.213
vol bp median and four-point at 0.006 — a factor of thirty-six, from one line.

Lattice spots are geometric, so their logarithms are uniformly spaced and `interp4` — the
same rule the finite-difference solver uses for its own jump — applies directly with
`x0 = log(spots[1])` and `h = log(u) - log(d)`.

Below the grid the value continues along the slope of the two lowest nodes. That reduces
to the intrinsic wherever the intrinsic is right — deep in the exercise region the slope
IS -1 for a put and 0 for a call — without assuming it where it is not.
"""
function jump_shift!(shifted, v, spots, m::Int, cp::OptionType, K, post)
    x0 = log(spots[1])
    h = m > 1 ? (log(spots[m]) - x0) / (m - 1) : 0.0
    slope = m > 1 ? (v[2] - v[1]) / (spots[2] - spots[1]) : 0.0
    @inbounds for j in 1:m
        y = post(spots[j])
        shifted[j] = if y <= 0.0
            intrinsic(cp, 0.0, K)               # stock wiped out; exercise value is exact
        elseif y <= spots[1]
            # Continue along the boundary slope. Substituting the intrinsic here assumes
            # the lowest node is already in the exercise region, which is false near the
            # root: there the tree is narrower than the dividend, EVERY node lands in this
            # branch, and the continuation value is destroyed rather than approximated.
            max(v[1] + slope * (y - spots[1]), 0.0)
        elseif y >= spots[m]
            v[m]
        elseif m < 4
            interp_lin(spots, v, y, m)
        else
            # Four-point Lagrange, limited to the pair it interpolates between. Unlimited
            # it can overshoot the payoff kink and return small negative values.
            k = clamp(floor(Int, (log(y) - x0) / h) + 1, 1, m - 1)
            lo, hi = minmax(v[k], v[k+1])
            clamp(interp4(x0, h, view(v, 1:m), log(y)), lo, hi)
        end
    end
    @inbounds for j in 1:m
        v[j] = shifted[j]
    end
    return v
end

"""
    lr_cash_div(cp, S, K, r, q, sigma, T, divs; n=101)

American price with discrete CASH dividends, via the Vellekoop-Nieuwenhuis jump applied
to the value function.

The tree is built on the DIVIDEND-FREE process — dividends enter only through the jump
`V(S, t-) = V(S - D, t+)`, never through the tree parameters. Exercise is re-applied on
the cum-dividend spot after the jump, which is what makes call exercise optimal at the
ex-date and nowhere else.

This is the reference the dividend sections of the post are measured against, at large `n`.

Dividends outside `(0, T)` are ignored, matching `fd_cash_div`. A dividend falling exactly
at expiry is ambiguous — whether the holder sees it depends on settlement rather than on
anything the model knows — and the two engines previously disagreed about it by more than
ten percent, which is the kind of divergence a cross-engine check exists to prevent.
"""
function lr_cash_div(cp::OptionType, S, K, r, q, sigma, T, divs::Vector{CashDiv};
                     n::Integer=101)
    T > 0 || return intrinsic(cp, S, K)
    # with a schedule the zero-vol path jumps, so the exact answer is only available
    # once the dividends are gone; `lr_price`/`fd_american` then take it from there.
    sigma > 0 || return zero_vol_american(cp, ex_div_spot(S, divs, r), K, r, q, T)
    isempty(divs) && return lr_price(cp, S, K, r, q, sigma, T; n=n)

    nn = force_odd(n)
    dt = T / nn
    u, d, p = lr_params(S, K, r, q, sigma, T, nn)
    isnan(p) && return NaN
    disc = exp(-r * dt)
    pu, pd = disc * p, disc * (1 - p)
    w = omega(cp)
    logu, logd = log(u), log(d)

    jump = zeros(Float64, nn + 1)
    for dv in divs
        (0 < dv.t < T) || continue
        k = clamp(ceil(Int, dv.t / dt), 1, nn)
        jump[k+1] += dv.amount
    end

    v = Vector{Float64}(undef, nn + 1)
    spots = Vector{Float64}(undef, nn + 1)
    shifted = Vector{Float64}(undef, nn + 1)

    @inbounds for j in 0:nn
        Sj = S * exp(j * logu + (nn - j) * logd)
        v[j+1] = max(w * (Sj - K), 0.0)
    end
    @inbounds for i in (nn-1):-1:0
        for j in 0:i
            v[j+1] = pu * v[j+2] + pd * v[j+1]
        end
        for j in 0:i
            spots[j+1] = S * exp(j * logu + (i - j) * logd)
        end
        Dk = jump[i+2]
        Dk > 0 && jump_shift!(shifted, v, spots, i + 1, cp, K, S_ -> S_ - Dk)
        for j in 0:i
            v[j+1] = max(v[j+1], w * (spots[j+1] - K))
        end
    end
    return v[1]
end

"""
    lr_prop_div(cp, S, K, r, q, sigma, T, divs; n=101)

The same rollback with a multiplicative jump `V(S, t-) = V((1-beta)S, t+)`.

Kept separate from `lr_cash_div` so the two dividend MODELS can be compared on an
identical engine — the point of the post's §7 is that they disagree by more than either
one's discretisation error. Both engines share `jump_shift!`, so a change to the
interpolation cannot bias one model relative to the other.

Dividends outside `(0, T)` are ignored, as in `lr_cash_div`.
"""
function lr_prop_div(cp::OptionType, S, K, r, q, sigma, T, divs::Vector{PropDiv};
                     n::Integer=101)
    T > 0 || return intrinsic(cp, S, K)
    # with a schedule the zero-vol path jumps, so the exact answer is only available
    # once the dividends are gone; `lr_price`/`fd_american` then take it from there.
    sigma > 0 || return zero_vol_american(cp, ex_div_spot(S, divs, r), K, r, q, T)
    isempty(divs) && return lr_price(cp, S, K, r, q, sigma, T; n=n)

    nn = force_odd(n)
    dt = T / nn
    u, d, p = lr_params(S, K, r, q, sigma, T, nn)
    isnan(p) && return NaN
    disc = exp(-r * dt)
    pu, pd = disc * p, disc * (1 - p)
    w = omega(cp)
    logu, logd = log(u), log(d)

    keep = ones(Float64, nn + 1)
    for dv in divs
        (0 < dv.t < T) || continue
        k = clamp(ceil(Int, dv.t / dt), 1, nn)
        keep[k+1] *= (1 - dv.frac)
    end

    v = Vector{Float64}(undef, nn + 1)
    spots = Vector{Float64}(undef, nn + 1)
    shifted = Vector{Float64}(undef, nn + 1)

    @inbounds for j in 0:nn
        Sj = S * exp(j * logu + (nn - j) * logd)
        v[j+1] = max(w * (Sj - K), 0.0)
    end
    @inbounds for i in (nn-1):-1:0
        for j in 0:i
            v[j+1] = pu * v[j+2] + pd * v[j+1]
        end
        for j in 0:i
            spots[j+1] = S * exp(j * logu + (i - j) * logd)
        end
        kk = keep[i+2]
        kk != 1.0 && jump_shift!(shifted, v, spots, i + 1, cp, K, S_ -> S_ * kk)
        for j in 0:i
            v[j+1] = max(v[j+1], w * (spots[j+1] - K))
        end
    end
    return v[1]
end

# ---------------------------------------------------------------------------
# finite differences
# ---------------------------------------------------------------------------

"""
    brennan_schwartz!(v, a, b, c, d, g, from_low)

Solve the linear complementarity problem in one elimination pass plus one projected
substitution pass — the same cost as a Thomas solve.

It assumes the exercise region is a single connected interval anchored at one end of the
grid, which is true for a vanilla American option under positive rates and false for,
say, an American butterfly. `from_low = true` is the put case (exercise region at the low
end); `false` mirrors it for calls. `b` and `d` are overwritten.
"""
function brennan_schwartz!(v, a, b, c, d, g, from_low::Bool)
    M = length(v)
    if from_low
        @inbounds for i in (M-1):-1:1
            f = c[i] / b[i+1]
            b[i] -= f * a[i+1]
            d[i] -= f * d[i+1]
        end
        @inbounds v[1] = max(d[1] / b[1], g[1])
        @inbounds for i in 2:M
            v[i] = max((d[i] - a[i] * v[i-1]) / b[i], g[i])
        end
    else
        @inbounds for i in 2:M
            f = a[i] / b[i-1]
            b[i] -= f * c[i-1]
            d[i] -= f * d[i-1]
        end
        @inbounds v[M] = max(d[M] / b[M], g[M])
        @inbounds for i in (M-1):-1:1
            v[i] = max((d[i] - c[i] * v[i+1]) / b[i], g[i])
        end
    end
    return v
end

"""
Projected SOR for the same problem. Makes no assumption about the shape of the exercise
region, so it is the cross-check that Brennan-Schwartz's assumption actually holds.
"""
function psor!(v, a, b, c, d, g, omega_relax, tol, maxiter)
    M = length(v)
    for _ in 1:maxiter
        err = 0.0
        @inbounds for i in 1:M
            lo = i > 1 ? a[i] * v[i-1] : 0.0
            hi = i < M ? c[i] * v[i+1] : 0.0
            gs = (d[i] - lo - hi) / b[i]
            vi = max(g[i], v[i] + omega_relax * (gs - v[i]))
            err = max(err, abs(vi - v[i]))
            v[i] = vi
        end
        err < tol && break
    end
    return v
end

"""4-point Lagrange interpolation on a uniform grid in `x`, evaluated at `xq`."""
function interp4(x0, h, full, xq)
    n = length(full) - 1
    k = clamp(floor(Int, (xq - x0) / h) - 1, 0, n - 3)
    xs = ntuple(i -> x0 + (k + i - 1) * h, 4)
    ys = ntuple(i -> full[k+i], 4)
    acc = 0.0
    for i in 1:4
        num = 1.0
        den = 1.0
        for j in 1:4
            i == j && continue
            num *= (xq - xs[j])
            den *= (xs[i] - xs[j])
        end
        acc += ys[i] * num / den
    end
    return acc
end

"""
    fd_american(cp, S, K, r, q, sigma, T; nx, nt, halfwidth, rannacher, solver, anchor)

Crank-Nicolson with a Rannacher startup, on a uniform grid in `x = log S`.

Settings, and why:

  * **uniform in log S.** Plain and sufficient. Stretching and grid deformation buy
    little for American payoffs (Healy §4.9.4 "Key facts"), and the hyperbolic-sinh grid
    we built never earned its complexity.
  * **half-width `7.5*sigma*sqrt(T) + |mu|*T`.** Far wider than the three-standard-deviation
    rule of §4.9.1, because a reference must not be boundary-limited. Holding the mesh `h`
    fixed and widening from 5 to 20 standard deviations moves the price by 8e-6, so the
    truncation itself is not a limit here. Note that widening at FIXED `nx` coarsens `h`
    and makes the price move far more than that — 3.5e-3 at 400x200 — but that is the
    spatial error growing, not the boundary.
  * **Rannacher startup.** `rannacher` fully-implicit steps before switching to
    theta = 1/2. Crank-Nicolson alone is A-stable but not L-stable, so it rings on the
    payoff kink; two backward-Euler steps damp it.
  * **anchoring.** `:spot` puts S exactly on the centre node (needs even `nx`) and reads
    the value off directly. `:strike` fixes the grid independently of S and interpolates,
    which is what the dividend solver uses.
  * **Dirichlet ends at the American intrinsic**, not zero. For the put this is exact: deep
    in the money immediate exercise is optimal and the option IS worth `K - S`. For a call
    with `q = 0` it is not — the true value there is `S - K*exp(-r*tau)`, and the boundary
    understates it by `K*(1 - exp(-r*tau))`. At seven and a half standard deviations the
    probability of the centre node ever seeing that error is far below anything measurable
    here, which is what makes the approximation safe rather than correct.
"""
function fd_american(cp::OptionType, S, K, r, q, sigma, T;
                     nx::Int=400, nt::Int=200, halfwidth::Float64=7.5,
                     rannacher::Int=2, solver::Symbol=:brennan_schwartz,
                     anchor::Symbol=:spot, psor_omega::Float64=1.5,
                     psor_tol::Float64=1e-12, psor_maxiter::Int=10_000)
    T > 0 || return intrinsic(cp, S, K)
    sigma > 0 || return zero_vol_american(cp, S, K, r, q, T)
    iseven(nx) || (nx += 1)

    w = omega(cp)
    mu = r - q - sigma * sigma / 2
    L = halfwidth * sigma * sqrt(T) + abs(mu) * T
    centre_x = anchor === :spot ? log(S) : log(K)
    if anchor === :strike
        L = max(L, abs(log(S / K)) + 2 * sigma * sqrt(T) + 0.1)
    end
    h = 2L / nx
    x0 = centre_x - L
    spots = [exp(x0 + i * h) for i in 0:nx]
    payoff = [max(w * (s - K), 0.0) for s in spots]

    M = nx - 1
    alpha = sigma * sigma / (2h * h) - mu / (2h)
    beta  = -sigma * sigma / (h * h) - r
    gamma = sigma * sigma / (2h * h) + mu / (2h)

    v = payoff[2:nx]
    g = payoff[2:nx]
    a = Vector{Float64}(undef, M)
    b = Vector{Float64}(undef, M)
    c = Vector{Float64}(undef, M)
    d = Vector{Float64}(undef, M)

    dt = T / nt
    lo_v = iscall(cp) ? 0.0 : K - spots[1]
    hi_v = iscall(cp) ? spots[end] - K : 0.0

    for step in 1:nt
        theta = step <= rannacher ? 1.0 : 0.5
        @inbounds for i in 1:M
            a[i] = -theta * dt * alpha
            b[i] = 1 - theta * dt * beta
            c[i] = -theta * dt * gamma
            vm = i > 1 ? v[i-1] : lo_v
            vp = i < M ? v[i+1] : hi_v
            d[i] = v[i] + (1 - theta) * dt * (alpha * vm + beta * v[i] + gamma * vp)
        end
        d[1] += theta * dt * alpha * lo_v
        d[M] += theta * dt * gamma * hi_v
        if solver === :psor
            psor!(v, a, b, c, d, g, psor_omega, psor_tol, psor_maxiter)
        else
            brennan_schwartz!(v, a, b, c, d, g, isput(cp))
        end
    end

    if anchor === :spot
        return v[nx ÷ 2]
    else
        full = Vector{Float64}(undef, nx + 1)
        full[1] = lo_v
        full[end] = hi_v
        @inbounds for i in 1:M
            full[i+1] = v[i]
        end
        return interp4(x0, h, full, log(S))
    end
end

"""
    fd_cash_div(cp, S, K, r, q, sigma, T, divs; nx, nt, ...)

The same scheme with discrete cash dividends. Every ex-date is pinned exactly onto a
time-step boundary, which is why the FD error does not grow with the number of dividends
the way a lattice's does.

Below the grid the value is set to the EXACT intrinsic rather than linearly extrapolated.
Healy §4.13.2 measures the naive version at 0.0187 of error against 0.000009 for this one.
"""
function fd_cash_div(cp::OptionType, S, K, r, q, sigma, T, divs::Vector{CashDiv};
                     nx::Int=800, nt::Int=400, halfwidth::Float64=7.5,
                     rannacher::Int=2, solver::Symbol=:brennan_schwartz)
    T > 0 || return intrinsic(cp, S, K)
    # with a schedule the zero-vol path jumps, so the exact answer is only available
    # once the dividends are gone; `lr_price`/`fd_american` then take it from there.
    sigma > 0 || return zero_vol_american(cp, ex_div_spot(S, divs, r), K, r, q, T)
    inside = sort([dv for dv in divs if 0 < dv.t < T], by = x -> x.t)
    isempty(inside) && return fd_american(cp, S, K, r, q, sigma, T;
                                          nx=nx, nt=nt, halfwidth=halfwidth,
                                          rannacher=rannacher, solver=solver,
                                          anchor=:strike)
    iseven(nx) || (nx += 1)
    w = omega(cp)
    mu = r - q - sigma * sigma / 2
    L = halfwidth * sigma * sqrt(T) + abs(mu) * T
    L = max(L, abs(log(S / K)) + 2 * sigma * sqrt(T) + 0.1)
    h = 2L / nx
    x0 = log(K) - L
    spots = [exp(x0 + i * h) for i in 0:nx]
    payoff = [max(w * (s - K), 0.0) for s in spots]

    M = nx - 1
    alpha = sigma * sigma / (2h * h) - mu / (2h)
    beta  = -sigma * sigma / (h * h) - r
    gamma = sigma * sigma / (2h * h) + mu / (2h)
    lo_v = iscall(cp) ? 0.0 : K - spots[1]
    hi_v = iscall(cp) ? spots[end] - K : 0.0

    # Backward time grid in tau = T - t, with a break exactly at every ex-date.
    breaks = sort(unique(vcat(0.0, [T - dv.t for dv in inside], T)))
    taus = Float64[0.0]
    isjump = Bool[false]
    for k in 2:length(breaks)
        seg = breaks[k] - breaks[k-1]
        nsteps = max(1, round(Int, (seg / T) * nt))
        for j in 1:nsteps
            push!(taus, breaks[k-1] + seg * j / nsteps)
            push!(isjump, j == nsteps && k < length(breaks))
        end
    end

    v = payoff[2:nx]
    g = payoff[2:nx]
    a = Vector{Float64}(undef, M)
    b = Vector{Float64}(undef, M)
    c = Vector{Float64}(undef, M)
    d = Vector{Float64}(undef, M)
    full = Vector{Float64}(undef, nx + 1)

    for step in 2:length(taus)
        dt = taus[step] - taus[step-1]
        theta = step <= rannacher + 1 ? 1.0 : 0.5
        @inbounds for i in 1:M
            a[i] = -theta * dt * alpha
            b[i] = 1 - theta * dt * beta
            c[i] = -theta * dt * gamma
            vm = i > 1 ? v[i-1] : lo_v
            vp = i < M ? v[i+1] : hi_v
            d[i] = v[i] + (1 - theta) * dt * (alpha * vm + beta * v[i] + gamma * vp)
        end
        d[1] += theta * dt * alpha * lo_v
        d[M] += theta * dt * gamma * hi_v
        brennan_schwartz!(v, a, b, c, d, g, isput(cp))

        if isjump[step]
            tau = taus[step]
            D = 0.0
            for dv in inside
                isapprox(T - dv.t, tau; atol=1e-12) && (D += dv.amount)
            end
            if D > 0
                full[1] = lo_v
                full[end] = hi_v
                @inbounds for i in 1:M
                    full[i+1] = v[i]
                end
                @inbounds for i in 1:M
                    y = spots[i+1] - D
                    v[i] = if y <= spots[1]
                        # exact asymptotic value below the grid, not an extrapolation
                        intrinsic(cp, max(y, 0.0), K)
                    elseif y >= spots[end]
                        intrinsic(cp, y, K)
                    else
                        interp4(x0, h, full, log(y))
                    end
                    v[i] = max(v[i], g[i])
                end
            end
        end
    end

    full[1] = lo_v
    full[end] = hi_v
    @inbounds for i in 1:M
        full[i+1] = v[i]
    end
    return interp4(x0, h, full, log(S))
end

# ---------------------------------------------------------------------------
# quadrature: the third oracle family
# ---------------------------------------------------------------------------

"""
    quad_european_cash_div(cp, S, K, r, q, sigma, T, div; nodes=400)

European price under the SPOT model with one cash dividend, by direct quadrature.
Exact up to quadrature error — no discretisation of time or space.

Why this is a useful oracle: at `r = 0` (with `q >= 0`) early exercise of a put is never
optimal, so the American put EQUALS this European price. That gives one point in the
dividend problem where a genuinely independent, non-lattice, non-PDE answer exists, and
both the tree and the grid can be scored against it.

Two things make it accurate, and both matter:

  * **The inner expectation is done in closed form.** Conditional on the ex-date spot,
    `S_T` is lognormal, so the continuation value is exactly Black-Scholes. Only the
    outer expectation over the ex-date needs quadrature, and its integrand is smooth.
  * **The integration is split at the kink.** Below `S(td-) = D` the liquidator jump
    takes the stock to zero, and that whole region contributes `Phi(z_a)*K*exp(-rT)` for
    a put and nothing for a call — analytically, with no quadrature at all.

Do NOT reach for Gauss-Hermite here, which is the obvious first instinct. The payoff
kink wrecks it: at `D = 0` a 96-node Gauss-Hermite rule misses plain Black-Scholes by
1.8e-2 and oscillates rather than converging as the order rises. Healy §2.7.5 makes the
same point and recommends a simple truncated rule instead.
"""
function quad_european_cash_div(cp::OptionType, S, K, r, q, sigma, T, div::CashDiv;
                                nodes::Int=400)
    td, D = div.t, div.amount
    (0 < td < T) && (D > 0) || return bs_price(cp, S, K, r, q, sigma, T)
    s1 = sigma * sqrt(td)
    m1 = (r - q - sigma^2 / 2) * td
    tau = T - td

    # z below which the dividend wipes the stock out
    za = (log(D / S) - m1) / s1
    lo, hi = max(za, -8.0), 8.0

    # the wiped-out region, in closed form
    acc = isput(cp) ? norm_cdf(min(za, 8.0)) * K * exp(-r * tau) : 0.0

    if hi > lo
        x, w = gausslegendre(nodes)
        half, mid = (hi - lo) / 2, (hi + lo) / 2
        @inbounds for i in 1:nodes
            z = mid + half * x[i]
            Sp = S * exp(m1 + s1 * z) - D
            Sp <= 0 && continue
            acc += w[i] * half * norm_pdf(z) * bs_price(cp, Sp, K, r, q, sigma, tau)
        end
    end
    return exp(-r * td) * acc
end

# ---------------------------------------------------------------------------
# continuous-yield approximations to a discrete dividend
# ---------------------------------------------------------------------------

pv_dividends(divs::Vector{CashDiv}, r) = sum(dv.amount * exp(-r * dv.t) for dv in divs; init=0.0)

"""
The PV-matched continuous yield over `[0, T]`: the `q` whose discounting removes the same
present value from the forward as the schedule does.
"""
function matched_q(S, divs::Vector{CashDiv}, r, T)
    pv = pv_dividends(divs, r)
    pv <= 0 && return 0.0
    pv >= S && return Inf
    return -log(1 - pv / S) / T
end

"""
Escrowed (forward-model) approximation: price at `S - PV(D)` with `q = 0`.

Note what this does to an American CALL. Setting `q = 0` means early exercise is never
optimal (at `r >= 0`), so any American engine short-circuits to the European value — the
approximation silently deletes the early-exercise feature it was supposed to price.
"""
function escrowed_price(engine, cp::OptionType, S, K, r, sigma, T, divs::Vector{CashDiv})
    return engine(cp, S - pv_dividends(divs, r), K, r, 0.0, sigma, T)
end

"""PV-matched-yield approximation: price at `S` with the tenor-matched continuous `q`."""
function matched_q_price(engine, cp::OptionType, S, K, r, sigma, T, divs::Vector{CashDiv})
    return engine(cp, S, K, r, matched_q(S, divs, r, T), sigma, T)
end

"""
Scalar annualised-yield approximation: the trailing annual dividend divided by spot,
applied as a flat `q` regardless of whether an ex-date falls inside `[0, T]`.

This is the naive thing a data pipeline does when it stores one dividend-yield number per
name, and §8 measures what it costs.
"""
function scalar_q_price(engine, cp::OptionType, S, K, r, sigma, T, annual_yield)
    return engine(cp, S, K, r, annual_yield, sigma, T)
end

end # module
