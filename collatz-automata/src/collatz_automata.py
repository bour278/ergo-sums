import numpy as np
from PIL import Image, ImageDraw
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from pathlib import Path

EMPTY = -1
BG = (8, 8, 16)
PAL_DEFAULT = ((232, 160, 32), (20, 34, 56))
PAL_MULTI = [
    ((240, 80, 45), (52, 20, 12)),
    ((55, 210, 95), (14, 45, 22)),
    ((80, 145, 245), (18, 34, 58)),
    ((230, 195, 55), (50, 42, 14)),
]


def collatz(n):
    return n // 2 if n % 2 == 0 else 3 * n + 1


def collatz_t3(n):
    if n <= 1:
        return 1
    if n % 2 == 1:
        n = 3 * n + 1
    while n % 2 == 0:
        n //= 2
    return n


def trajectory(n, accelerated=False):
    step = collatz_t3 if accelerated else collatz
    path = [n]
    if n <= 1:
        return path
    while path[-1] != 1:
        path.append(step(path[-1]))
        if len(path) > 50000:
            break
    return path


def binary_grid(traj):
    max_bits = max(v.bit_length() for v in traj if v > 0)
    grid = np.full((len(traj), max_bits), EMPTY, dtype=np.int8)
    for i, val in enumerate(traj):
        bits = []
        v = val
        while v > 0:
            bits.append(v & 1)
            v >>= 1
        bits.reverse()
        for j, b in enumerate(bits):
            grid[i, j] = b
    return grid


def _bright(color, amt):
    return tuple(min(255, c + amt) for c in color)


def _draw_row(draw, grid, row, col_off, cell, gap, c1, c0):
    for j in range(grid.shape[1]):
        v = grid[row, j]
        if v == EMPTY:
            continue
        color = c1 if v == 1 else c0
        px = (col_off + j) * cell
        py = row * cell
        draw.rectangle(
            [px + gap, py + gap, px + cell - gap - 1, py + cell - gap - 1],
            fill=color
        )


def spacetime_gif(n, outpath, accelerated=True, target_h=850, delay=60):
    traj = trajectory(n, accelerated=accelerated)
    grid = binary_grid(traj)
    nrows, ncols = grid.shape

    cell = max(4, min(20, target_h // nrows))
    gap = 1 if cell >= 8 else 0
    margin = 10

    w = ncols * cell + 2 * margin
    h = nrows * cell + 2 * margin

    c1, c0 = PAL_DEFAULT
    c1_hi, c0_hi = _bright(c1, 40), _bright(c0, 14)

    canvas = Image.new('RGB', (w, h), BG)
    draw = ImageDraw.Draw(canvas)
    frames = []

    def row_draw(r, one, zero):
        for j in range(ncols):
            v = grid[r, j]
            if v == EMPTY:
                continue
            color = one if v == 1 else zero
            px = margin + j * cell
            py = margin + r * cell
            draw.rectangle(
                [px + gap, py + gap, px + cell - gap - 1, py + cell - gap - 1],
                fill=color
            )

    for r in range(nrows):
        if r > 0:
            row_draw(r - 1, c1, c0)
        row_draw(r, c1_hi, c0_hi)
        frames.append(canvas.copy())

    row_draw(nrows - 1, c1, c0)
    final = canvas.copy()
    frames.extend([final] * 30)

    frames[0].save(
        str(outpath), save_all=True, append_images=frames[1:],
        duration=delay, loop=0, optimize=True
    )
    return nrows


def parallel_gif(numbers, outpath, accelerated=True, cell=12, gap_cols=2, delay=70):
    trajs = [trajectory(n, accelerated=accelerated) for n in numbers]
    grids = [binary_grid(t) for t in trajs]
    max_rows = max(g.shape[0] for g in grids)

    col_offsets = []
    off = 0
    for g in grids:
        col_offsets.append(off)
        off += g.shape[1] + gap_cols
    total_cols = off - gap_cols

    gap = 1 if cell >= 8 else 0
    margin = 10
    w = total_cols * cell + 2 * margin
    h = max_rows * cell + 2 * margin

    canvas = Image.new('RGB', (w, h), BG)
    draw = ImageDraw.Draw(canvas)
    frames = []

    def traj_row(idx, row, highlight):
        g = grids[idx]
        if row >= g.shape[0]:
            return
        pal = PAL_MULTI[idx % len(PAL_MULTI)]
        c1 = _bright(pal[0], 35) if highlight else pal[0]
        c0 = _bright(pal[1], 10) if highlight else pal[1]
        co = col_offsets[idx]
        for j in range(g.shape[1]):
            v = g[row, j]
            if v == EMPTY:
                continue
            color = c1 if v == 1 else c0
            px = margin + (co + j) * cell
            py = margin + row * cell
            draw.rectangle(
                [px + gap, py + gap, px + cell - gap - 1, py + cell - gap - 1],
                fill=color
            )

    for r in range(max_rows):
        for idx in range(len(grids)):
            if r > 0:
                traj_row(idx, r - 1, False)
            traj_row(idx, r, True)
        frames.append(canvas.copy())

    for idx in range(len(grids)):
        traj_row(idx, grids[idx].shape[0] - 1, False)
    final = canvas.copy()
    frames.extend([final] * 30)

    frames[0].save(
        str(outpath), save_all=True, append_images=frames[1:],
        duration=delay, loop=0, optimize=True
    )


def stopping_times_plot(max_n, outpath, accelerated=True):
    ns = list(range(2, max_n + 1))
    times = [len(trajectory(n, accelerated=accelerated)) - 1 for n in ns]

    fig, ax = plt.subplots(figsize=(16, 7))
    fig.patch.set_facecolor('#080810')
    ax.set_facecolor('#080810')

    ax.scatter(ns, times, s=0.3, c=times, cmap='inferno', alpha=0.85, edgecolors='none')

    label = 'accelerated T3' if accelerated else 'standard'
    ax.set_xlabel('n', color='#aaa', fontsize=13)
    ax.set_ylabel('stopping time', color='#aaa', fontsize=13)
    ax.set_title(f'Collatz stopping times ({label}), n = 2..{max_n}',
                 color='white', fontsize=16, pad=12)

    ax.tick_params(colors='#888')
    for spine in ax.spines.values():
        spine.set_color('#333')

    fig.savefig(str(outpath), dpi=200, bbox_inches='tight',
                facecolor=fig.get_facecolor())
    plt.close(fig)


def landscape_png(n, outpath, accelerated=False, cell=6):
    traj = trajectory(n, accelerated=accelerated)
    grid = binary_grid(traj)
    nrows, ncols = grid.shape
    c1, c0 = PAL_DEFAULT

    w = ncols * cell
    h = nrows * cell
    img = Image.new('RGB', (w, h), BG)
    draw = ImageDraw.Draw(img)

    for i in range(nrows):
        for j in range(ncols):
            v = grid[i, j]
            if v == EMPTY:
                continue
            color = c1 if v == 1 else c0
            px, py = j * cell, i * cell
            draw.rectangle([px, py, px + cell - 1, py + cell - 1], fill=color)

    img.save(str(outpath))


def generate_all(outdir="output"):
    p = Path(outdir)
    p.mkdir(exist_ok=True)

    print()
    print("Collatz Automata - Binary Spacetime Diagrams")
    print("Based on Chen, 'CA to More Efficiently Compute the Collatz Map'")
    print()

    print("[1/4] Spacetime GIF for n=27 (T3 accelerated)...")
    steps = spacetime_gif(27, p / "01_spacetime_27.gif", accelerated=True)
    print(f"  {steps} steps -> {p}/01_spacetime_27.gif")

    print("[2/4] Parallel trajectories GIF [7, 27, 97] (T3)...")
    parallel_gif([7, 27, 97], p / "02_parallel.gif", accelerated=True)
    print(f"  saved {p}/02_parallel.gif")

    print("[3/4] Stopping times scatter (n=2..10000, T3)...")
    stopping_times_plot(10000, p / "03_stopping_times.png", accelerated=True)
    print(f"  saved {p}/03_stopping_times.png")

    print("[4/4] Binary landscape for n=27 (standard Collatz)...")
    landscape_png(27, p / "04_landscape_27.png", accelerated=False)
    print(f"  saved {p}/04_landscape_27.png")

    print()
    print(f"All outputs saved to {outdir}/")
