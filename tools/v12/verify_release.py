"""Check the shipped Command Bar artifact matches every current build input."""
from pathlib import Path
import hashlib
import json
import subprocess

from assemble import REPO, SOURCES, compiler, payload


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    command = REPO / 'Install-Bomb-Expansion-V12.command.luau'
    expected = payload()
    assert command.read_text() == expected, 'Installer is stale: run tools/v12/assemble.py'
    checked = []
    for _, path in SOURCES:
        if 'V12' in path.name and path not in checked:
            subprocess.run([compiler(), '--binary', str(path)], check=True, stdout=subprocess.DEVNULL)
            checked.append(path)
    subprocess.run([compiler(), '--binary', str(command)], check=True, stdout=subprocess.DEVNULL)
    checked.append(command)
    for name in ('Huss-A-Bomb-V12.txt', 'Install-Bomb-Expansion-V12.txt'):
        path = REPO / name
        raw = path.read_bytes()
        assert raw == expected.replace('\n', '\r\n').encode(), f'{name} differs or lacks Windows line endings'
        checked.append(path)
    report_names = ['OwnerCommandsV12.validation.json', 'BombServiceV12.validation.json',
                    'BombSkinsV12.validation.json', 'CarrierPanicV12.validation.json',
                    'ShopV12.validation.json', 'Install-Bomb-Expansion-V12.validation.json']
    component_reports = {}
    for name in report_names:
        path = REPO / name
        data = json.loads(path.read_text())
        recorded = data.get('sha256')
        if isinstance(recorded, dict):
            for filename, expected_hash in recorded.items():
                assert sha(REPO / filename) == expected_hash, f'Stale validation for {filename}'
        elif isinstance(recorded, str) and data.get('source'):
            assert sha(REPO / data['source']) == recorded, f'Stale validation: {name}'
        if data.get('production_source_sha256'):
            assert sha(REPO / 'BombServiceV12.luau') == data['production_source_sha256'], 'Stale bomb validation'
        component_reports[name] = {'sha256': sha(path)}
    report = {
        'status': 'passed',
        'checks': ['Installer equals current assembly inputs', 'All V12 runtime payloads compile',
                   'Complete Command Bar installer compiles', 'Both Windows TXT files equal the complete installer',
                   'Recorded component source hashes match the release'],
        'files': {str(path.relative_to(REPO)): {'bytes': path.stat().st_size, 'sha256': sha(path)} for path in checked},
        'component_reports': component_reports,
        'limits': ['Artifact and syntax verification only; component behavioral checks have separate reports.',
                   'Native Roblox Studio rendering, input, physics, replication and live persistence were not available.'],
    }
    (REPO / 'V12-Release.validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print('V12 release artifacts verified:', len(checked), 'files')


if __name__ == '__main__':
    main()
