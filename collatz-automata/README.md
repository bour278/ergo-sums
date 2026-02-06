# Collatz Automata

Binary spacetime diagrams of the Collatz process, inspired by
Chen, "Cellular Automata to More Efficiently Compute the Collatz Map" (2018).

## The idea

The Collatz map on odd numbers reduces to a local operation in binary:
- Multiply by 3: shift left and add to self (carry propagation)
- Add 1: flip the LSB
- Strip trailing zeros: shift right

Chen showed this can be expressed as a cellular automaton (CA3) operating
on a 2D grid of binary digits. Each row of the grid holds one iterate
of the trajectory, and the CA's local rules compute the next row from
the previous one using only nearest-neighbor lookups.

The accelerated map T3 skips all even steps:

    T3(n) = (3n + 1) / 2^k    where 2^k || (3n + 1)

Every output is odd, so the trajectory goes directly from one
nontrivial number to the next.

## Outputs

| File | Description |
|------|-------------|
| `01_spacetime_27.gif` | Animated binary spacetime diagram for n=27 under T3 |
| `02_parallel.gif` | Three trajectories (7, 27, 97) animated in parallel |
| `03_stopping_times.png` | T3 stopping times for n = 2..10000 |
| `04_landscape_27.png` | Full standard Collatz trajectory of 27 in binary (static) |

## Usage

```bash
cd collatz-automata
python3 run.py            # outputs to ./output/
python3 run.py my_dir     # outputs to ./my_dir/
```
