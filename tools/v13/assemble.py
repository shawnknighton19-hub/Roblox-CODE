"""Build the complete local V12 -> V13 Command Bar update; no network requests."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]
OUTPUT = REPO / 'Install-R6-Trails-V13.command.luau'
TEXT_NAMES = ['Install-R6-Trails-V13.txt', 'Huss-A-Bomb-V13.txt']


def literal(text):
    for count in range(2, 30):
        closing = ']' + '=' * count + ']'
        if closing not in text:
            return '[' + '=' * count + '[' + text + closing
    raise ValueError('Unable to safely quote source')


SOURCES = {
    'oldCatalog': REPO / 'HussCatalogV12.luau',
    'oldHUD': REPO / 'HudControllerV12.luau',
    'oldShop': REPO / 'StandShopV12.client.luau',
    'oldCollection': REPO / 'CollectionEffectsV11.client.luau',
    'catalog': REPO / 'HussCatalogV13.luau',
    'hud': REPO / 'HudControllerV13.luau',
    'shop': REPO / 'StandShopV13.client.luau',
    'collection': REPO / 'CollectionEffectsV13.client.luau',
    'trails': REPO / 'TrailDesignsV13.luau',
    'animate': REPO / 'AnimateV13.client.luau',
    'animationRuntime': REPO / 'AnimationRuntimeV13.server.luau',
}
# These are compared with the actual instance sources, never required/executed.
PRESERVED = {
    'ServerMain': ROOT / 'fixtures/ServerMainV12.luau',
    'RoundService': ROOT / 'fixtures/RoundServiceV12.luau',
    'SnappyMovement': ROOT / 'fixtures/SnappyMovementV12.luau',
    'MovementEffectsV8': ROOT / 'fixtures/MovementEffectsV12.luau',
    'BombService': REPO / 'BombServiceV12.luau',
    'EconomyServiceV9': REPO / 'EconomyServiceV12.luau',
    'CosmeticsServiceV11': REPO / 'CosmeticsServiceV12.luau',
    'OwnerCommandsV12': REPO / 'OwnerCommandsV12.luau',
    'OwnerFeedbackV12': REPO / 'OwnerFeedbackV12.client.luau',
    'CarrierPanicV12': REPO / 'CarrierPanicV12.client.luau',
    'BombSkinBuilderV12': REPO / 'BombSkinBuilderV12.luau',
    'PracticeServiceV11': REPO / 'PracticeServiceV11.luau',
    'PerfectWeaveServiceV11': REPO / 'PerfectWeaveServiceV11.luau',
    'LobbyBoardsV11': REPO / 'LobbyBoardsV11.client.luau',
    'DodgeActionV6': REPO / 'DodgeActionV6.client.luau',
}
FUNCTIONS = {
    'dependencyValidator': ROOT.parent / 'v12/dependencies.luau',
    'shopValidator': REPO / 'ShopStandsV12.luau',
    'animationAdapter': ROOT / 'animation_adapter.luau',
}


def compiler():
    configured = os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile')
    fallback = Path('/workspace/.cloud-tools/bin/luau-compile')
    if not configured and fallback.is_file():
        configured = str(fallback)
    if not configured:
        raise RuntimeError('Install luau-compile or set LUAU_COMPILE.')
    return configured


def payload(shop_stub=None):
    out = (ROOT / 'installer_head.luau').read_text()
    for name, source in FUNCTIONS.items():
        body = shop_stub if name == 'shopValidator' and shop_stub is not None else source.read_text()
        out += '\nlocal ' + name + '=(function()\n' + body + '\nend)()\n'
    out += '\nlocal source={\n' + ''.join('[ ' + literal(k) + ' ]=' + literal(p.read_text()) + ',\n' for k,p in SOURCES.items()) + '}\n'
    out += '\nlocal preservedSource={\n' + ''.join('[ ' + literal(k) + ' ]=' + literal(p.read_text()) + ',\n' for k,p in PRESERVED.items()) + '}\n'
    return out + '\n' + (ROOT / 'installer_tail.luau').read_text()


def assemble():
    text = payload()
    OUTPUT.write_text(text, newline='\n')
    subprocess.run([compiler(), '--binary', str(OUTPUT)], stdout=subprocess.DEVNULL, check=True)
    for name in TEXT_NAMES:
        (REPO / name).write_bytes(text.replace('\n','\r\n').encode())
    components = list(SOURCES.values()) + list(PRESERVED.values()) + list(FUNCTIONS.values()) + [ROOT/'installer_head.luau',ROOT/'installer_tail.luau']
    report = {
        'bytes': len(text.encode()), 'sha256': hashlib.sha256(text.encode()).hexdigest(),
        'luau_compile': 'passed', 'scope': 'Verified V12 -> V13 update. Existing maps and lobby geometry are not rewritten.',
        'required_publish_step': 'Set Avatar Settings to R6, save, publish, join a new server. Installer cannot set experience rig settings.',
        'windows_text': {name: {'bytes':(REPO/name).stat().st_size,'sha256':hashlib.sha256((REPO/name).read_bytes()).hexdigest(),'normalized_matches_command':(REPO/name).read_text()==text} for name in TEXT_NAMES},
        'components': {str(p.relative_to(REPO)): {'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in components},
    }
    (ROOT/'assembly.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='components'}))
    return text


if __name__=='__main__':
    assemble()
