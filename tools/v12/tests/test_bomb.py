#!/usr/bin/env python3
"""Compile and execute the actual V12 BombService against contact/cleanup regressions."""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--luau', default=shutil.which('luau') or '/workspace/.cloud-tools/bin/luau')
    parser.add_argument('--luau-compile', default=shutil.which('luau-compile'))
    args = parser.parse_args()
    compiler = args.luau_compile or str(Path(args.luau).with_name('luau-compile'))
    production = ROOT / 'BombServiceV12.luau'
    subprocess.run([compiler, str(production)], check=True, stdout=subprocess.DEVNULL)
    source = (HERE / 'bomb_fixture.luau.in').read_text()
    source = source.replace('{{BOMB}}', production.read_text())
    source = source.replace('{{WEAVE}}', (ROOT / 'PerfectWeaveServiceV11.luau').read_text())
    source = source.replace('{{REGRESSIONS}}', (HERE / 'bomb_regressions.luau').read_text())
    with tempfile.TemporaryDirectory(prefix='huss-bomb-v12-') as directory:
        test = Path(directory) / 'bomb_test.luau'
        test.write_text(source)
        result = subprocess.run([args.luau, str(test)], text=True, capture_output=True)
        print(result.stdout, end='')
        print(result.stderr, end='')
        raise SystemExit(result.returncode)

if __name__ == '__main__':
    main()
