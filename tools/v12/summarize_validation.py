"""Collect the five installer test reports into a compact, versioned release record."""
from pathlib import Path
import hashlib
import json
import os
import tempfile
from assemble import REPO, ROOT


def main():
    normal = Path(os.environ.get('V12_TEST_OUTPUT', str(Path(tempfile.gettempdir()) / 'huss-v12-installer-tests')))
    full = Path(os.environ.get('V12_FULL_TEST_OUTPUT', str(normal)))
    upgrade = Path(os.environ.get('V12_UPGRADE_TEST_OUTPUT', str(normal)))
    sources = [normal / 'installer.validation.json', normal / 'installer-sources.validation.json',
               normal / 'upgrade.validation.json', full / 'installer-full.validation.json',
               upgrade / 'upgrade-full.validation.json']
    suites = []
    for path in sources:
        report = json.loads(path.read_text())
        suites.append({'suite': path.name, 'cases': report['cases'], 'assertions': report['assertions'],
                       'scope': report['scope'], 'results': report.get('results', []),
                       'installed_source_compilations': report.get('installed_source_compilations', [])})
    assembly = json.loads((ROOT / 'assembly.json').read_text())
    for relative, expected in assembly['components'].items():
        assert hashlib.sha256((REPO / relative).read_bytes()).hexdigest() == expected['sha256'], relative + ' changed after assembly'
    target = REPO / 'Install-Bomb-Expansion-V12.validation.json'
    report = {'result': 'passed', 'cases': sum(x['cases'] for x in suites),
              'assertions': sum(x['assertions'] for x in suites),
              'installed_source_compiles': sum(sum(x['files'] for x in suite['installed_source_compilations']) for suite in suites),
              'installer': {'path': 'Install-Bomb-Expansion-V12.command.luau', 'bytes': assembly['bytes'], 'sha256': assembly['sha256']},
              'installer_sha256': assembly['sha256'], 'sha256': {filename: hashlib.sha256((REPO / filename).read_bytes()).hexdigest() for filename in ['Install-Bomb-Expansion-V12.command.luau', 'Huss-A-Bomb-V12.txt', 'Install-Bomb-Expansion-V12.txt']},
              'windows_text': assembly['windows_text'], 'suites': suites,
              'limits': 'Deterministic Instance execution and real Luau compilation; native Roblox Studio rendering, physics, networking, and DataStore execution were not available.'}
    target.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'suites'}))


if __name__ == '__main__':
    main()
