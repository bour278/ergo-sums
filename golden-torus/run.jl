#!/usr/bin/env julia
#
# Living on a Random Torus - The Golden Ratio in Islands and Pools
# Based on the paper by Saad Mneimneh
#
# Usage:
#   cd golden-torus
#   julia run.jl              # defaults: 100x100 torus, 100 trials
#   julia run.jl 200 200 50   # custom:   200x200 torus, 50  trials

import Pkg

println("Setting up environment...")
Pkg.activate(@__DIR__)

manifest = joinpath(@__DIR__, "Manifest.toml")
if !isfile(manifest)
    println("First run: installing CairoMakie (this may take several minutes)...")
    Pkg.add("CairoMakie")
end

Pkg.instantiate()

println("Loading packages...")
t0 = time()

include(joinpath(@__DIR__, "src", "GoldenTorus.jl"))
using .GoldenTorus

dt = round(time() - t0; digits=1)
println("Loaded in $(dt)s")

m    = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 100
n    = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 100
runs = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 100

GoldenTorus.generate_all(; m, n, runs)
