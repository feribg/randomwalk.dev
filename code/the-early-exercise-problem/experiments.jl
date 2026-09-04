#!/usr/bin/env julia
# experiments.jl — every number in "The Early Exercise Problem".
#
#   julia --project experiments.jl
#
# Writes one CSV per experiment into results/. The finite-difference reference grids
# dominate the runtime.

include("american.jl"); using .American
include("harness.jl");  using .Harness

using Printf, Statistics, CSV, DataFrames

include("exp/oracle_agreement.jl")
include("exp/premium_and_exactness.jl")
include("exp/dividend_models.jl")
include("exp/smearing.jl")
include("exp/inputs_and_scale.jl")
include("exp/boundary.jl")
include("exp/constant_yield_regimes.jl")

function main()
    t0 = time()
    println("The Early Exercise Problem — reproducing every number in the post.")
    println("Julia $(VERSION) on $(Sys.CPU_NAME)")
    oracle_agreement()
    premium_map()
    exactness()
    escrowed_europeanises()
    dividend_models()
    model_implied_vol()
    scalar_vs_matched()
    smearing_penalty()
    pv_threshold()
    input_vs_pricer_error()
    volbp_scale()
    exercise_boundary()
    constant_yield_regimes()
    premium_under_smearing()
    @printf("\nAll experiments complete in %.1f s. Results in results/.\n", time()-t0)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
