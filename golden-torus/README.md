# Golden Torus

Implementation of the paper **"Living on a Random Torus"** by Saad Mneimneh.

## The experiment

Take an m x n grid and assign each cell to be land (1) with probability p, or water (0) with probability q = 1 - p. Wrap the grid into a torus using modular arithmetic (row m = row 0, column n = column 0) so there are no boundaries.

Count two things on this torus:

- **Islands**: maximal connected components of land cells using 4-connectivity (up, down, left, right).
- **Pools**: maximal connected components of water cells using 8-connectivity (4-neighbors + diagonals).

The asymmetry (4 vs 8 connectivity) is intentional. If you can only walk land orthogonally, then two diagonal land cells don't connect -- but the water between them does connect diagonally, forming a single pool that separates them.

## The result

Using the linearity of expectation and indicator random variables, the paper derives:

```
lim (E[#islands] - E[#pools]) / (m*n) = p * q * (q - p^2)
    m,n -> inf
```

This expression equals zero at the trivial cases p = 0 and p = 1, but also at:

```
q = p^2
1/p = p/q
(p + q) / p = p / q = phi = (1 + sqrt(5)) / 2
```

So p = 1/phi ~ 0.618. At this critical probability, the expected number of islands equals the expected number of pools. The golden ratio emerges naturally from the balance condition.

## What this code does

Generates 5 visualizations:

1. **Flat grid** - component-coloured torus at p = 1/phi, each island and pool in a distinct color
2. **3D torus** - the same random grid mapped onto a torus surface
3. **1D ring** - the special case m = 1, a circular array where E[#islands] = npq + p^n
4. **Simulation curves** - average islands and pools vs p, reproducing Figure 4 of the paper
5. **Theory overlay** - simulated difference vs the theoretical p*q*(q - p^2), showing the golden ratio crossing

## Usage

```
cd golden-torus
julia run.jl              # 100x100 torus, 100 trials
julia run.jl 200 200 50   # 200x200 torus, 50 trials
```

Output goes to `output/`.

## Reference

Saad Mneimneh, "Living on a Random Torus." The paper covers the probabilistic analysis connecting island/pool counts on a random torus to the golden ratio via linearity of expectation.
