#!/usr/bin/env python3
"""Run owner/proximity regressions plus retained economy persistence tests using Luau CLI."""
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
    args = parser.parse_args()
    source = (HERE / 'owner_economy_fixture.luau.in').read_text()
    catalog = ROOT / 'HussCatalogV12.luau'
    if not catalog.exists():
        catalog = ROOT / 'HussCatalogV11.luau'
    replacements = {
        'CATALOG': catalog.read_text(),
        'OWNER': (ROOT / 'OwnerCommandsV12.luau').read_text(),
        'ECONOMY': (ROOT / 'EconomyServiceV12.luau').read_text(),
        'REGRESSIONS': (HERE / 'owner_economy_regressions.luau').read_text(),
    }
    for key, value in replacements.items():
        source = source.replace('{{' + key + '}}', value)
    with tempfile.TemporaryDirectory(prefix='huss-owner-v12-') as directory:
        test = Path(directory) / 'owner_economy_test.luau'
        test.write_text(source)
        result = subprocess.run([args.luau, str(test)], text=True, capture_output=True)
        print(result.stdout, end='')
        print(result.stderr, end='')
        raise SystemExit(result.returncode)

if __name__ == '__main__':
    main()
