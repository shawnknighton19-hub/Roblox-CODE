#!/usr/bin/env python3
"""Execute V15 production combat sources in a deterministic Roblox API adapter.

This checks server decisions and clocks, not native physics or network replication.
"""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
LUAU = shutil.which('luau') or '/workspace/.cloud-tools/bin/luau'
SOURCES = [
    'CombatRulesV15.luau', 'HABActionServiceV15.luau', 'BombServiceV15.luau',
    'SnappyMovementV15.client.luau', 'PracticeServiceV15.luau', 'DodgeIFrameServerV15.server.luau',
]

def quote(value):
    eq = '=' * 8
    while ']' + eq + ']' in value:
        eq += '='
    return '[' + eq + '[' + value + ']' + eq + ']'

def run():
    for name in SOURCES:
        result = subprocess.run([LUAU + '-compile', str(ROOT / name)], text=True, capture_output=True)
        if result.returncode:
            raise SystemExit(result.stderr)
    config = (HERE / 'Config-HABWAS.luau').read_text()
    names = ['rulesSource', 'actionSource', 'bombSource', 'movementSource', 'practiceSource', 'dodgeSource']
    chunks = ['local ' + name + '=' + quote((ROOT / file).read_text()) for name, file in zip(names, SOURCES)]
    chunks.append('local configSource=' + quote(config))
    chunks.append((HERE / 'math_adapter.luau').read_text())
    chunks.append((HERE / 'combat_fixture.luau').read_text())
    chunks.append((HERE / 'combat_regressions.luau').read_text())
    with tempfile.TemporaryDirectory() as folder:
        test = Path(folder) / 'test.luau'
        test.write_text('\n'.join(chunks))
        result = subprocess.run([LUAU, str(test)], capture_output=True, text=True)
        if result.returncode:
            raise SystemExit(result.stdout + result.stderr)
    print(result.stdout, end='')
    checks = int(re.search(r'COMBAT_ASSERTIONS=(\d+)', result.stdout).group(1))
    report = {
        'checks': checks,
        'actual_source_executed': True,
        'syntax_checked': True,
        'native_studio_tested': False,
        'coverage': [
            'swept melee and clipped final active interval', 'single transfer per attack',
            'deterministic nearest target', 'moving projectile/target crossings',
            'wall obstruction and dodge before wall termination', 'antitagback',
            'carrier, AFK, pause, cooldown and pass rejects', 'all nine ability acknowledgements',
            'shield charge, ground, ceiling, ownership and server/client leap route',
            'validated dodge recovery timestamp', 'carrier gain, loss and respawn speed cleanup',
            'walking and sprint advantage; existing dodge cap and cooldown unchanged',
        ],
        'limitations': ['Mocked raycast and humanoid APIs; native multiplayer playtesting remains required.'],
        'source_sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in SOURCES},
    }
    (ROOT / 'CombatV15.validation.json').write_text(json.dumps(report, indent=2) + '\n')

if __name__ == '__main__':
    run()
