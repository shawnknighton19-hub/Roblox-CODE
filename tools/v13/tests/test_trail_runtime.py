#!/usr/bin/env python3
"""Execute the actual collection client against deterministic Roblox lifecycle fixtures.

No renderer, networking or native Humanoid physics are simulated here.
"""
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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--luau', default=shutil.which('luau') or '/workspace/.cloud-tools/bin/luau')
    parser.add_argument('--luau-compile', default=shutil.which('luau-compile'))
    args = parser.parse_args()
    compiler = args.luau_compile or str(Path(args.luau).with_name('luau-compile'))
    production = ROOT / 'CollectionEffectsV13.client.luau'
    filenames = ['CollectionEffectsV13.client.luau', 'TrailDesignsV13.luau', 'HussCatalogV13.luau']
    payloads = {name: (ROOT/name).read_text() for name in filenames}
    subprocess.run([compiler, str(production)], check=True, stdout=subprocess.DEVNULL)
    source = (ROOT/'tools/v12/tests/panic_fixture.luau.in').read_text().split('local panicExports')[0]
    source += '\nlocal catalog=(function()\n'+payloads['HussCatalogV13.luau']+'\nend)()\n'
    source += (HERE/'trail_runtime_fixture.luau.in').read_text()
    source = source.replace('{{RUNTIME}}', payloads['CollectionEffectsV13.client.luau'])
    source = source.replace('{{TRAIL_DESIGNS}}', payloads['TrailDesignsV13.luau'])
    source = source.replace('{{REGRESSIONS}}', (HERE/'trail_runtime_regressions.luau').read_text())
    with tempfile.TemporaryDirectory(prefix='huss-trails-runtime-v13-') as directory:
        test = Path(directory)/'trail_runtime_test.luau'
        test.write_text(source)
        result = subprocess.run([args.luau, str(test)], text=True, capture_output=True)
        print(result.stdout, end='')
        print(result.stderr, end='')
        if result.returncode == 0:
            match = re.search(r'V13 trail runtime: (\d+) assertions passed;', result.stdout)
            if not match:
                raise RuntimeError('Runtime validation did not report its assertion count')
            report = {
                'passed': True,
                'syntax_compile': 'passed',
                'runtime_assertions': int(match.group(1)),
                'run_command': 'python3 tools/v13/tests/test_trail_runtime.py',
                'all_catalog_trails_tested': 25,
                'max_visible_trails': 10,
                'max_remote_trails': 9,
                'culling_distance_studs': 90,
                'checks': [
                    'Actual runtime and geometry builder execute together.',
                    'Moving path displays geometry without per-frame Instance allocation.',
                    'All 25 equipment IDs, invalid IDs and wrong categories.',
                    'Local priority, nearest remote selection and reserved remote budget.',
                    'Complete stop fade before destruction and threshold-jitter pool reuse.',
                    'Reduced Motion, player/workspace pause, seating, anchoring, air and ragdolls.',
                    'High velocity, missing camera and distance culling.',
                    'Character, root, humanoid and head streaming without listener growth.',
                    'Respawns, player departures, death and repeated teardown.',
                    'Existing titles, emotes, perfect-weave cue and mute behavior.',
                ],
                'limitations': 'Deterministic Instance/math/lifecycle harness. Native Roblox rendering, Animator, physics, networking and published-client behavior require Studio or live playtesting.',
                'sha256': {name: hashlib.sha256(payloads[name].encode()).hexdigest() for name in filenames},
            }
            (ROOT/'CollectionEffectsV13.validation.json').write_text(json.dumps(report, indent=2)+'\n')
        raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
