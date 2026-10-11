"""Verify the complete copyable installer and its recorded component checks."""
import hashlib
import json
import subprocess

from assemble import OUTPUT, REPO, SOURCES, TEXT_NAMES, compiler, payload


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    expected = payload()
    assert OUTPUT.read_text() == expected, 'Stale installer: run tools/v13/assemble.py'
    files = [OUTPUT]
    for path in SOURCES.values():
        if 'V13' in path.name and path not in files:
            files.append(path)
    for path in files:
        subprocess.run([compiler(), '--binary', str(path)], check=True, stdout=subprocess.DEVNULL)
    for name in TEXT_NAMES:
        path = REPO / name
        assert path.read_bytes() == expected.replace('\n', '\r\n').encode(), f'{name} is not the complete Windows installer'
        files.append(path)
    reports = {}
    for name in ['AnimationV13.validation.json', 'TrailDesignsV13.validation.json',
                 'CollectionEffectsV13.validation.json', 'TrailShopV13.validation.json',
                 'TrailApiV13.validation.json', 'Install-R6-Trails-V13.validation.json']:
        path = REPO / name
        result = json.loads(path.read_text())
        for key in ('sha256', 'sourceSha256', 'source_sha256'):
            hashes = result.get(key, {})
            if isinstance(hashes, dict):
                for filename, recorded in hashes.items():
                    assert isinstance(recorded, str) and len(recorded) == 64, f'Invalid source hash: {name}: {filename}'
                    assert (REPO / filename).is_file(), f'Missing tested source: {name}: {filename}'
                    assert digest(REPO / filename) == recorded, f'Stale validation: {filename} in {name}'
        if 'installer_sha256' in result:
            assert digest(OUTPUT) == result['installer_sha256'], f'Stale installer tests: {name}'
        reports[name] = digest(path)
    assembly_path = REPO / 'tools/v13/assembly.json'
    assembly = json.loads(assembly_path.read_text())
    assert digest(OUTPUT) == assembly['sha256'], 'Stale assembly report'
    for filename, metadata in assembly['components'].items():
        assert digest(REPO / filename) == metadata['sha256'], f'Stale assembly input: {filename}'
    reports['tools/v13/assembly.json'] = digest(assembly_path)
    result = {
        'status': 'passed',
        'checks': ['Current source equals assembled payload', 'All V13 payloads and installer compile',
                   'Windows TXT copies contain the full installer', 'Recorded source hashes match the tested files'],
        'files': {str(path.relative_to(REPO)): {'bytes': path.stat().st_size, 'sha256': digest(path)} for path in files},
        'component_reports_sha256': reports,
        'required_user_step': 'File > Avatar Settings > top ... menu > R6; save, publish, join a new server.',
        'limits': ['Native Studio rendering, live animation permissions and published multiplayer were not available.',
                   'The installer cannot change Roblox experience avatar settings.'],
    }
    (REPO / 'V13-Release.validation.json').write_text(json.dumps(result, indent=2) + '\n')
    print('V13 release verified:', len(files), 'artifacts and', len(reports), 'component reports')


if __name__ == '__main__':
    main()
