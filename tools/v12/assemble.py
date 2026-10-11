"""Build the standalone, source-verified V12 Studio Command Bar installer."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]
OUTPUT = REPO / 'Install-Bomb-Expansion-V12.command.luau'


def literal(text):
    for count in range(2, 20):
        end = ']' + '=' * count + ']'
        if end not in text:
            return '[' + '=' * count + '[' + text + end
    raise ValueError('Luau long-string delimiter collision')


FUNCTIONS = [
    ('gameplayAdapter', ROOT / 'patch_gameplay.luau'),
    ('uiAdapter', ROOT / 'patch_ui.luau'),
    ('movementAdapter', ROOT / 'patch_movement.luau'),
    ('dependencyValidator', ROOT / 'dependencies.luau'),
    ('worldBuilder', REPO / 'WorldBuilderV11.luau'),
    ('placementBuilder', ROOT / 'placement.luau'),
    ('shopBuilder', REPO / 'ShopStandsV12.luau'),
]
SOURCES = [
    ('legacyBombSource', ROOT / 'legacy/BombServiceV11.luau'),
    ('legacyHUDSource', REPO / 'HudControllerV11.luau'),
    ('legacyEconomySource', REPO / 'EconomyServiceV11.luau'),
    ('legacyCatalogSource', REPO / 'HussCatalogV11.luau'),
    ('legacyCosmeticsSource', REPO / 'CosmeticsServiceV11.luau'),
    ('bombSource', REPO / 'BombServiceV12.luau'),
    ('hudSource', REPO / 'HudControllerV12.luau'),
    ('economySource', REPO / 'EconomyServiceV12.luau'),
    ('catalogSource', REPO / 'HussCatalogV12.luau'),
    ('cosmeticsSource', REPO / 'CosmeticsServiceV12.luau'),
    ('skinSource', REPO / 'BombSkinBuilderV12.luau'),
    ('ownerSource', REPO / 'OwnerCommandsV12.luau'),
    ('feedbackSource', REPO / 'OwnerFeedbackV12.client.luau'),
    ('panicSource', REPO / 'CarrierPanicV12.client.luau'),
    ('shopSource', REPO / 'StandShopV12.client.luau'),
    ('practiceSource', REPO / 'PracticeServiceV11.luau'),
    ('weaveSource', REPO / 'PerfectWeaveServiceV11.luau'),
    ('collectionSource', REPO / 'CollectionEffectsV11.client.luau'),
    ('boardsSource', REPO / 'LobbyBoardsV11.client.luau'),
]


def payload(stub_world=None, stub_shop=None):
    content = (ROOT / 'installer_head.luau').read_text()
    for name, path in FUNCTIONS:
        source = (stub_world if name == 'worldBuilder' and stub_world is not None
                  else stub_shop if name == 'shopBuilder' and stub_shop is not None
                  else path.read_text())
        content += '\nlocal ' + name + '=(function()\n' + source + '\nend)()\n'
    for name, path in SOURCES:
        content += '\nlocal ' + name + '=' + literal(path.read_text()) + '\n'
    return content + '\n' + (ROOT / 'installer_tail.luau').read_text()


def compiler():
    configured = os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile')
    fallback = Path('/workspace/.cloud-tools/bin/luau-compile')
    if not configured and fallback.is_file():
        configured = str(fallback)
    if not configured:
        raise RuntimeError('Install luau-compile or set LUAU_COMPILE before building.')
    return configured


def assemble():
    text = payload()
    OUTPUT.write_text(text, newline='\n')
    subprocess.run([compiler(), '--binary', str(OUTPUT)], stdout=subprocess.DEVNULL, check=True)
    for name in ['Install-Bomb-Expansion-V12.txt', 'Huss-A-Bomb-V12.txt']:
        (REPO / name).write_bytes(text.replace('\n', '\r\n').encode())
    report = {
        'bytes': len(text.encode()),
        'sha256': hashlib.sha256(text.encode()).hexdigest(),
        'luau_compile': 'passed',
        'windows_text': {name: {'bytes': (REPO / name).stat().st_size, 'sha256': hashlib.sha256((REPO / name).read_bytes()).hexdigest(), 'normalized_matches_command': (REPO / name).read_text() == text} for name in ['Install-Bomb-Expansion-V12.txt', 'Huss-A-Bomb-V12.txt']},
        'components': {
            str(path.relative_to(REPO)): {
                'bytes': path.stat().st_size,
                'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            }
            for _, path in FUNCTIONS + SOURCES + [('head', ROOT / 'installer_head.luau'), ('tail', ROOT / 'installer_tail.luau')]
        },
    }
    (ROOT / 'assembly.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({key: value for key, value in report.items() if key != 'components'}))
    return text


if __name__ == '__main__':
    assemble()
