# harness.jl — shared helpers for the experiment scripts.
module Harness

using Statistics: median, quantile
using Printf
using CSV, DataFrames

export nmed, p95v, writeresult, banner, VEGA_FLOOR

"""
Every table in the post filters to `vega > 0.1`.

Error is reported in implied-vol basis points, which means dividing a price error by
vega. Where vega is small that division amplifies noise without bound, so the rows are
dropped rather than reported as enormous. The cost is that deep-in-the-money and very
short-dated contracts — which carry a lot of listed volume — are outside every number
here. That is a scope boundary, not a footnote.
"""
const VEGA_FLOOR = 0.1

nmed(v) = isempty(v) ? NaN : median(v)
p95v(v) = isempty(v) ? NaN : quantile(v, 0.95)

const RESULTS = joinpath(@__DIR__, "results")

function writeresult(name::AbstractString, df::DataFrame)
    isdir(RESULTS) || mkpath(RESULTS)
    path = joinpath(RESULTS, name * ".csv")
    CSV.write(path, df)
    @printf("  -> results/%s.csv  (%d rows)\n", name, nrow(df))
    return path
end

function banner(n, title)
    println()
    println("="^78)
    @printf("%d. %s\n", n, title)
    println("="^78)
end

end # module
