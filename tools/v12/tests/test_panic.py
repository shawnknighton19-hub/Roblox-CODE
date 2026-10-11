#!/usr/bin/env python3
"""Compile real carrier cosmetics and check rig, controller ownership and cleanup.

The deterministic engine adapter does not replace Roblox Studio Animator/render tests.
Optional --preview-data writes the actual authored poses for the offline renderer.
"""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--luau', default=shutil.which('luau') or '/workspace/.cloud-tools/bin/luau')
    parser.add_argument('--luau-compile', default=shutil.which('luau-compile'))
    parser.add_argument('--preview-data', type=Path)
    args = parser.parse_args()
    compiler = args.luau_compile or str(Path(args.luau).with_name('luau-compile'))
    production = ROOT / 'CarrierPanicV12.client.luau'
    subprocess.run([compiler, str(production)], check=True, stdout=subprocess.DEVNULL)
    source = (HERE / 'panic_fixture.luau.in').read_text()
    source = source.replace('{{CARRIER}}', production.read_text())
    source = source.replace('{{REGRESSIONS}}', (HERE / 'panic_regressions.luau').read_text())
    if args.preview_data:
        source += (HERE / 'panic_preview_export.luau').read_text()
    with tempfile.TemporaryDirectory(prefix='huss-panic-v12-') as directory:
        test = Path(directory) / 'panic_test.luau'
        test.write_text(source)
        result = subprocess.run([args.luau, str(test)], text=True, capture_output=True)
        output = result.stdout
        if args.preview_data and result.returncode == 0:
            output, encoded = output.split('PANIC_PREVIEW_JSON:', 1)
            args.preview_data.parent.mkdir(parents=True, exist_ok=True)
            args.preview_data.write_text(json.dumps(json.loads(encoded), indent=2)+'\n')
            output += f'Wrote eight R6/R15 pose frames to {args.preview_data}\n'
        print(output, end='')
        print(result.stderr, end='')
        raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
