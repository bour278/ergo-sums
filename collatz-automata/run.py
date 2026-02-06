#!/usr/bin/env python3
import subprocess
import sys
import importlib.util
from pathlib import Path

deps = {'numpy': 'numpy', 'PIL': 'Pillow', 'matplotlib': 'matplotlib'}
missing = [pkg for mod, pkg in deps.items() if importlib.util.find_spec(mod) is None]
if missing:
    print(f"Installing: {', '.join(missing)}")
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', '-q'] + missing)

sys.path.insert(0, str(Path(__file__).parent / 'src'))
from collatz_automata import generate_all

if __name__ == '__main__':
    outdir = sys.argv[1] if len(sys.argv) > 1 else 'output'
    generate_all(outdir)
