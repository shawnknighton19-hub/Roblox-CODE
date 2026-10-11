#!/usr/bin/env python3
"""Run the V13 trail previews through the real HUD and walk-up shop in Luau mocks."""
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
    'CATALOG': 'HussCatalogV13.luau',
    'SKIN_BUILDER': 'BombSkinBuilderV12.luau',
    'TRAIL_BUILDER': 'TrailDesignsV13.luau',
    'WORLD': 'ShopStandsV12.luau',
    'HUD': 'HudControllerV13.luau',
    'CLIENT': 'StandShopV13.client.luau',
}


def replace_once(source, old, new):
    assert source.count(old) == 1, f'Fixture anchor changed: {old[:90]}'
    return source.replace(old, new, 1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--luau', default=shutil.which('luau') or '/workspace/.cloud-tools/bin/luau')
    parser.add_argument('--luau-compile', default=shutil.which('luau-compile'))
    parser.add_argument('--report', action='store_true')
    args = parser.parse_args()
    compiler = args.luau_compile or str(Path(args.luau).with_name('luau-compile'))
    source = (ROOT / 'tools/v12/tests/shop_fixture.luau.in').read_text()
    source = replace_once(source, 'local tagged={}', '''local TrailDesigns=(function()
{{TRAIL_BUILDER}}
end)()
local tagged={}''')
    source = replace_once(source, "local catalogModule=Instance.new('ModuleScript',ReplicatedStorage)", "local trailModule=Instance.new('ModuleScript',ReplicatedStorage);trailModule.Name='HussTrailDesignsV13'\nlocal catalogModule=Instance.new('ModuleScript',ReplicatedStorage)")
    source = replace_once(source, ' if module==builderModule then return SkinBuilder end', ' if module==trailModule then return TrailDesigns end\n if module==builderModule then return SkinBuilder end')
    source = replace_once(source, 'function instanceMethods:GetBoundingBox() return CFrame.new(),Vector3.new(180,40,160) end', (HERE / 'trail_shop_bounds.luau').read_text())
    source = replace_once(source, "for _,category in ipairs({'Trails','Titles','Emotes'}) do", (HERE / 'trail_shop_stand_regressions.luau').read_text() + "\nfor _,category in ipairs({'Trails','Titles','Emotes'}) do")
    source = replace_once(source, "check(node('Item_bomb_cobalt',hud):GetAttribute('HussDisabled'),'locked Index item is browse-only')", "check(node('Item_bomb_cobalt',hud):GetAttribute('HussDisabled'),'locked Index item is browse-only')\n" + (HERE / 'trail_shop_index_regressions.luau').read_text())
    source = source.replace("print('STAND_SHOP_V12 '", "print('TRAIL_SHOP_V13 '")
    hashes = {}
    for key, filename in SOURCES.items():
        path = ROOT / filename
        subprocess.run([compiler, str(path)], check=True, stdout=subprocess.DEVNULL)
        source = source.replace('{{' + key + '}}', path.read_text())
        hashes[filename] = hashlib.sha256(path.read_bytes()).hexdigest()
    assert not re.search(r'\{\{[A-Z_]+\}\}', source), 'Unreplaced fixture input'
    with tempfile.TemporaryDirectory(prefix='huss-trail-shop-v13-') as directory:
        test = Path(directory) / 'trail_shop_test.luau'
        test.write_text(source)
        result = subprocess.run([args.luau, str(test)], text=True, capture_output=True)
        print(result.stdout, end='')
        print(result.stderr, end='')
        if result.returncode:
            raise SystemExit(result.returncode)
    if args.report:
        count = re.search(r'TRAIL_SHOP_V13 (\d+) assertions passed', result.stdout)
        assert count, 'Missing test result'
        report = {
            'status': 'passed',
            'assertions': int(count.group(1)),
            'sourceSha256': hashes,
            'command': 'python tools/v13/tests/test_trail_shop.py --report',
            'checks': [
                'All V12 walk-up shop and inventory integration regressions retained',
                'All 25 trail sculptures previewed using the actual shared design module',
                'Every preview part bounding corner fits its viewport camera with a margin',
                'Only one stand preview and at most six inventory trail previews exist',
                'Previews have no emitters, beams, physics, or per-frame rendering callbacks',
                'Paging, category switching and closing destroy the old preview models',
                'Reduced-motion keeps preview geometry fixed',
                'Inventory remains equip-only; physical stands retain the purchase path',
            ],
            'limits': ['Standalone Luau mocks; native Studio GUI rendering, touch interaction and replication were unavailable.'],
        }
        (ROOT / 'TrailShopV13.validation.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
