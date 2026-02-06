module GoldenTorus

using CairoMakie
using Random
using Statistics

export generate_all

# Constants
const PHI    = (1 + sqrt(5)) / 2   # golden ratio
const P_GOLD = 1 / PHI             # critical land probability
const Q_GOLD = 1 - P_GOLD

# -- Core simulation --------------------------------------------------------

function random_torus(m::Int, n::Int, p::Float64; rng=Random.default_rng())
    rand(rng, m, n) .< p
end

function label_components(torus::BitMatrix, is_land::Bool)
    m, n = size(torus)
    labels = zeros(Int, m, n)
    ncomp = 0

    offsets = is_land ?
        ((0,-1), (0,1), (-1,0), (1,0)) :
        ((-1,-1), (-1,0), (-1,1), (0,-1), (0,1), (1,-1), (1,0), (1,1))

    queue = Tuple{Int,Int}[]
    sizehint!(queue, m * n / 4)

    for si in 1:m, sj in 1:n
        torus[si, sj] != is_land && continue
        labels[si, sj] != 0      && continue

        ncomp += 1
        empty!(queue)
        push!(queue, (si, sj))
        labels[si, sj] = ncomp
        head = 1

        while head <= length(queue)
            ci, cj = queue[head]; head += 1
            for (di, dj) in offsets
                ni = mod1(ci + di, m)
                nj = mod1(cj + dj, n)
                if torus[ni, nj] == is_land && labels[ni, nj] == 0
                    labels[ni, nj] = ncomp
                    push!(queue, (ni, nj))
                end
            end
        end
    end

    labels, ncomp
end

count_islands(t::BitMatrix) = label_components(t, true)[2]
count_pools(t::BitMatrix)   = label_components(t, false)[2]

function run_simulation(; m::Int=100, n::Int=100, runs::Int=100,
                          ps=range(0.01, 0.99, length=50))
    ps_vec = collect(ps)
    np = length(ps_vec)
    mn = m * n
    avg_islands = zeros(np)
    avg_pools   = zeros(np)

    for (idx, p) in enumerate(ps_vec)
        si = 0; sp = 0
        for _ in 1:runs
            t = random_torus(m, n, p)
            si += count_islands(t)
            sp += count_pools(t)
        end
        avg_islands[idx] = si / (runs * mn)
        avg_pools[idx]   = sp / (runs * mn)

        if idx % 5 == 0 || idx == np
            print("\r  progress: $idx / $np p-values")
        end
    end
    println()

    ps_vec, avg_islands, avg_pools
end

# Theoretical limit of (E[#islands] - E[#pools]) / (m*n) as m, n -> inf.
theory(p) = p * (1 - p) * ((1 - p) - p^2)

# -- Color utilities ---------------------------------------------------------

function hsv_to_rgbf(h::Float64, s::Float64, v::Float64)
    h = mod(h, 360.0)
    c = v * s
    x = c * (1.0 - abs(mod(h / 60.0, 2.0) - 1.0))
    m = v - c
    r, g, b = if     h <  60; (c, x, 0.)
              elseif h < 120; (x, c, 0.)
              elseif h < 180; (0., c, x)
              elseif h < 240; (0., x, c)
              elseif h < 300; (x, 0., c)
              else;           (c, 0., x) end
    RGBf(r + m, g + m, b + m)
end

function island_palette(n::Int)
    n == 0 && return RGBf[]
    [hsv_to_rgbf(
        0.0 + 120.0 * (i - 1) / max(n - 1, 1),
        0.85,
        clamp(0.55 + 0.40 * mod(i * 0.618, 1.0), 0.50, 0.95))
     for i in 1:n]
end

function pool_palette(n::Int)
    n == 0 && return RGBf[]
    [hsv_to_rgbf(
        180.0 + 160.0 * (i - 1) / max(n - 1, 1),
        0.75,
        clamp(0.35 + 0.35 * mod(i * 0.618, 1.0), 0.30, 0.70))
     for i in 1:n]
end

# -- Vis 1: component-coloured flat grid -------------------------------------

function plot_grid(; m=40, n=40, p=P_GOLD, seed=42)
    torus = random_torus(m, n, p; rng=MersenneTwister(seed))
    ilab, ni = label_components(torus, true)
    plab, np = label_components(torus, false)

    ic = island_palette(ni); shuffle!(MersenneTwister(7),  ic)
    pc = pool_palette(np);   shuffle!(MersenneTwister(13), pc)

    img = fill(RGBf(0, 0, 0), m, n)
    for i in 1:m, j in 1:n
        img[i, j] = torus[i, j] ? ic[ilab[i, j]] : pc[plab[i, j]]
    end

    fig = Figure(size=(820, 820), backgroundcolor=:white, figure_padding=20)

    ax = Axis(fig[1, 1];
        title = "Random Torus Grid  -  p = 1/phi",
        titlesize = 22, titlefont = :bold,
        subtitle = "$ni islands (warm)  |  $np pools (cool)  |  $(m)x$(n)",
        subtitlesize = 13, subtitlecolor = :gray40,
        xlabel = "Column j", ylabel = "Row i",
        xlabelsize = 14, ylabelsize = 14,
        aspect = DataAspect(),
        yreversed = true)

    image!(ax, 0.5 .. (n + 0.5), 0.5 .. (m + 0.5), permutedims(img); interpolate=false)

    elem_island = [PolyElement(color=RGBf(0.85, 0.45, 0.12))]
    elem_pool   = [PolyElement(color=RGBf(0.18, 0.42, 0.78))]
    Legend(fig[1, 1],
        [elem_island, elem_pool], ["Land (4-connected)", "Water (8-connected)"];
        tellheight=false, tellwidth=false,
        halign=:right, valign=:top, margin=(10, 10, 10, 10),
        framevisible=true, padding=(8, 8, 6, 6), labelsize=12)

    fig
end

# -- Vis 2: 3D torus surface -------------------------------------------------

function plot_torus_3d(; m=80, n=80, p=P_GOLD, seed=42, R=3.0, r=1.2)
    torus = random_torus(m, n, p; rng=MersenneTwister(seed))

    thetas = range(0, 2pi; length=m + 1)
    psis   = range(0, 2pi; length=n + 1)

    X = [(R + r * cos(th)) * cos(ps) for th in thetas, ps in psis]
    Y = [(R + r * cos(th)) * sin(ps) for th in thetas, ps in psis]
    Z = [r * sin(th)                  for th in thetas, ps in psis]

    land_c  = RGBf(0.30, 0.65, 0.15)
    water_c = RGBf(0.08, 0.25, 0.60)

    C = fill(water_c, m + 1, n + 1)
    for i in 1:m+1, j in 1:n+1
        C[i, j] = torus[mod1(i, m), mod1(j, n)] ? land_c : water_c
    end

    fig = Figure(size=(1000, 850), backgroundcolor=RGBf(0.96, 0.96, 0.95))

    ax = Axis3(fig[1, 1];
        title = "Toroidal World  -  p = 1/phi",
        titlesize = 24, titlefont = :bold,
        aspect    = :data,
        elevation = pi / 5,
        azimuth   = 5 * pi / 8)
    hidedecorations!(ax)
    hidespines!(ax)

    surface!(ax, X, Y, Z; color=C, shading=true)

    elem_l = [PolyElement(color=land_c)]
    elem_w = [PolyElement(color=water_c)]
    Legend(fig[1, 1], [elem_l, elem_w], ["Land", "Water"];
        tellheight=false, tellwidth=false,
        halign=:left, valign=:bottom, margin=(20, 0, 0, 20),
        framevisible=true, padding=(8, 8, 6, 6), labelsize=13)

    fig
end

# -- Vis 3: 1D ring (special case m=1) ---------------------------------------

function plot_ring(; n_ring=30, p=P_GOLD, seed=42)
    torus = random_torus(1, n_ring, p; rng=MersenneTwister(seed))
    row = vec(torus)

    edges = sum(row[k] && !row[mod1(k + 1, n_ring)] for k in 1:n_ring)
    all_land = all(row)
    n_islands = all_land ? 1 : edges

    angs = [2pi * (k - 1) / n_ring for k in 1:n_ring]
    R = 3.5
    xs = R .* cos.(angs)
    ys = R .* sin.(angs)

    fig = Figure(size=(680, 680), backgroundcolor=:white, figure_padding=15)

    ax = Axis(fig[1, 1];
        title = "Special Case: 1x$n_ring Ring",
        titlesize = 22, titlefont = :bold,
        subtitle = "p = 1/phi  |  $n_islands island(s)  |  E[#] = npq + p^n",
        subtitlesize = 13, subtitlecolor = :gray40,
        aspect = DataAspect())
    hidedecorations!(ax)
    hidespines!(ax)

    for k in 1:n_ring
        k2 = mod1(k + 1, n_ring)
        lines!(ax, [xs[k], xs[k2]], [ys[k], ys[k2]];
               color=:gray80, linewidth=1.5)
    end

    cell_colors = [row[k] ? RGBf(0.85, 0.35, 0.15) : RGBf(0.20, 0.45, 0.80)
                   for k in 1:n_ring]
    scatter!(ax, xs, ys; color=cell_colors, markersize=22,
             strokecolor=:gray30, strokewidth=1.5)

    for k in 1:n_ring
        lx = (R + 0.55) * cos(angs[k])
        ly = (R + 0.55) * sin(angs[k])
        text!(ax, lx, ly; text=row[k] ? "1" : "0",
              fontsize=10, align=(:center, :center), color=:gray50)
    end

    fig
end

# -- Vis 4: simulation curves (paper Figure 4) -------------------------------

function plot_curves(ps, avg_islands, avg_pools; m=100, n=100, runs=100)
    fig = Figure(size=(950, 620), backgroundcolor=:white, figure_padding=25)

    ax = Axis(fig[1, 1];
        title = "Islands and Pools on a Random Torus",
        titlesize = 24, titlefont = :bold,
        subtitle = "Averaged over $runs trials on a $(m)x$(n) torus",
        subtitlesize = 13, subtitlecolor = :gray50,
        xlabel = "p  (land probability)",
        ylabel = "Average count / (m * n)",
        xlabelsize = 16, ylabelsize = 16,
        xticks = 0:0.1:1)

    lines!(ax, ps, avg_islands;
        color=:firebrick, linewidth=3, label="Islands (4-connected)")
    lines!(ax, ps, avg_pools;
        color=:steelblue, linewidth=3, linestyle=:dash, label="Pools (8-connected)")

    vlines!(ax, [P_GOLD]; color=(:goldenrod, 0.5), linewidth=1.5, linestyle=:dot)
    text!(ax, P_GOLD + 0.015, maximum(avg_islands) * 0.92;
          text="p = 1/phi", fontsize=14, color=:goldenrod)

    axislegend(ax; position=:rt, framevisible=true,
               padding=(10, 10, 6, 6), labelsize=14)

    fig
end

# -- Vis 5: theory overlay + golden ratio (paper Figure 6) -------------------

function plot_theory(ps, avg_islands, avg_pools)
    fig = Figure(size=(1000, 800), backgroundcolor=:white, figure_padding=25)

    # top panel: islands & pools curves
    ax1 = Axis(fig[1, 1];
        title = "The Golden Ratio on a Random Torus",
        titlesize = 24, titlefont = :bold,
        subtitle = "E[#islands] = E[#pools] when p/q = phi = (1+sqrt(5))/2",
        subtitlesize = 14, subtitlecolor = :gray50,
        ylabel = "Count / (m * n)",
        ylabelsize = 15,
        xticks = 0:0.1:1,
        xticklabelsvisible = false)

    lines!(ax1, ps, avg_islands;
        color=:firebrick, linewidth=2.5, label="Islands (sim.)")
    lines!(ax1, ps, avg_pools;
        color=:steelblue, linewidth=2.5, linestyle=:dash, label="Pools (sim.)")

    vlines!(ax1, [P_GOLD]; color=(:goldenrod, 0.6), linewidth=2, linestyle=:dashdot)
    text!(ax1, P_GOLD + 0.015, maximum(avg_islands) * 0.88;
          text="p = 1/phi ~ 0.618", fontsize=13, color=:goldenrod)
    axislegend(ax1; position=:rt, framevisible=true,
               padding=(10, 10, 6, 6), labelsize=13)

    # bottom panel: difference vs theory
    ax2 = Axis(fig[2, 1];
        xlabel = "p  (land probability)",
        ylabel = "delta = (Islands - Pools) / (m * n)",
        xlabelsize = 15, ylabelsize = 15,
        xticks = 0:0.1:1)

    diff_sim = avg_islands .- avg_pools
    scatter!(ax2, ps, diff_sim;
        color=(:purple, 0.45), markersize=7, label="Simulated delta")

    pt = collect(range(0.001, 0.999; length=300))
    lines!(ax2, pt, theory.(pt);
        color=:gray20, linewidth=2.5, linestyle=:solid, label="p*q*(q - p^2)")

    vlines!(ax2, [P_GOLD]; color=(:goldenrod, 0.7), linewidth=2, linestyle=:dashdot)
    scatter!(ax2, [P_GOLD], [0.0];
        color=:gold, markersize=14, strokecolor=:black, strokewidth=2)

    text!(ax2, P_GOLD + 0.02, 0.005;
          text="p/q = phi\nq = p^2 => balance",
          fontsize=12, color=:gray20, align=(:left, :bottom))
    text!(ax2, 0.15, -0.005;
          text="<- Islands dominate", fontsize=11, color=(:firebrick, 0.7),
          align=(:center, :top))
    text!(ax2, 0.88, -0.005;
          text="Pools dominate ->", fontsize=11, color=(:steelblue, 0.7),
          align=(:center, :top))

    axislegend(ax2; position=:rb, framevisible=true,
               padding=(10, 10, 6, 6), labelsize=13)

    linkxaxes!(ax1, ax2)
    rowgap!(fig.layout, 10)
    rowsize!(fig.layout, 1, Relative(0.55))

    fig
end

# -- Main entry point --------------------------------------------------------

function generate_all(; m=100, n=100, runs=100, outdir="output")
    mkpath(outdir)

    println()
    println("Living on a Random Torus - The Golden Ratio")
    println("Based on the paper by Saad Mneimneh")
    println()
    println("  phi   = $(round(PHI; digits=8))")
    println("  p     = 1/phi = $(round(P_GOLD; digits=8))")
    println("  q     = 1-p   = $(round(Q_GOLD; digits=8))")
    println("  p/q   = $(round(P_GOLD / Q_GOLD; digits=8))  (= phi)")
    println()

    println("[1/5] Component-coloured torus grid...")
    fig1 = plot_grid()
    save(joinpath(outdir, "01_torus_grid.png"), fig1; px_per_unit=2)
    println("  saved $(outdir)/01_torus_grid.png")

    println("[2/5] 3D toroidal world...")
    fig2 = plot_torus_3d()
    save(joinpath(outdir, "02_torus_3d.png"), fig2; px_per_unit=2)
    println("  saved $(outdir)/02_torus_3d.png")

    println("[3/5] 1D ring (special case m=1)...")
    fig3 = plot_ring()
    save(joinpath(outdir, "03_ring_1d.png"), fig3; px_per_unit=2)
    println("  saved $(outdir)/03_ring_1d.png")

    println("[4/5] Monte Carlo simulation (m=$m, n=$n, $runs trials)...")
    ps, avg_i, avg_p = run_simulation(; m, n, runs)
    fig4 = plot_curves(ps, avg_i, avg_p; m, n, runs)
    save(joinpath(outdir, "04_simulation_curves.png"), fig4; px_per_unit=2)
    println("  saved $(outdir)/04_simulation_curves.png")

    println("[5/5] Theory overlay with golden ratio...")
    fig5 = plot_theory(ps, avg_i, avg_p)
    save(joinpath(outdir, "05_golden_theory.png"), fig5; px_per_unit=2)
    println("  saved $(outdir)/05_golden_theory.png")

    println()
    println("All 5 figures saved to $(outdir)/")

    (fig1, fig2, fig3, fig4, fig5)
end

end # module
