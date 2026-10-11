#!/usr/bin/env python3
"""Execute the actual V12 HUD, stand client, geometry, catalog and bomb previews in Luau mocks."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
SOURCES = {
    'CATALOG': 'HussCatalogV12.luau',
    'SKIN_BUILDER': 'BombSkinBuilderV12.luau',
    'WORLD': 'ShopStandsV12.luau',
    'HUD': 'HudControllerV12.luau',
    'CLIENT': 'StandShopV12.client.luau',
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--luau', default=shutil.which('luau') or '/workspace/.cloud-tools/bin/luau')
    parser.add_argument('--luau-compile', default=shutil.which('luau-compile'))
    parser.add_argument('--report', action='store_true', help='Write ShopV12.validation.json with tested source hashes')
    args = parser.parse_args()
    compiler = args.luau_compile or str(Path(args.luau).with_name('luau-compile'))
    source = (HERE / 'shop_fixture.luau.in').read_text()
    hashes = {}
    for key, filename in SOURCES.items():
        path = ROOT / filename
        subprocess.run([compiler, str(path)], check=True, stdout=subprocess.DEVNULL)
        source = source.replace('{{' + key + '}}', path.read_text())
        hashes[filename] = hashlib.sha256(path.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix='huss-shop-v12-') as directory:
        test = Path(directory) / 'shop_test.luau'
        test.write_text(source)
        result = subprocess.run([args.luau, str(test)], text=True, capture_output=True)
        print(result.stdout, end='')
        print(result.stderr, end='')
        if result.returncode:
            raise SystemExit(result.returncode)
    if args.report:
        count = re.search(r'STAND_SHOP_V12 (\d+) assertions passed', result.stdout)
        assert count, 'Missing test result'
        report = {
            'status': 'passed',
            'assertions': int(count.group(1)),
            'sourceSha256': hashes,
            'command': 'python tools/v12/tests/test_shop.py --report',
            'checks': [
                'Physical panels preserve lobby geometry, fit below signs, and repeat without duplicates',
                'Strict SurfaceGui ZIndex property guard exercises real GUI creation',
                'All 25 bombs accessible with actual shared sculpture previews',
                'Proximity hysteresis, round/practice/death/disabled stand closure',
                'Authoritative profile and separate request ID namespace',
                'Matching transaction responses, double-click protection, timeout and late responses',
                'Equipped emote play/stop on existing server remote',
                'Gamepad, cursor unlock, visibility restoration and subscription teardown',
                'Index equips owned items without a remote purchase entry point',
                'Original bomb, round and AFK HUD remote contracts retained',
            ],
            'limits': ['Standalone Luau mocks; native Studio rendering, pointer raycasting and multiplayer replication were unavailable.'],
        }
        (ROOT / 'ShopV12.validation.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
