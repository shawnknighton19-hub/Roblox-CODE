"""Bind delivered V16 artifacts to their executed validation and original input."""
from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[2]
def digest(path):return hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
def read(path):return json.loads((ROOT/path).read_text())
def source_hashes(report,key):
    for path,expected in report[key].items():
        assert digest(path)==expected,('Stale validation',path)

def run():
    base='c354d8c3c7ac43b9364749aa292716aa592eee6f496f532c98c0bafb88279309'
    assert digest('HABWAS.rbxl')==base
    manifest=read('tools/v16/place_patch.json')
    assert manifest['input_sha256']==base
    for e in manifest['edits']:assert digest(e['source'])==e['source_sha256']
    reports={}
    for name in ['ActionsV16','WeaveV16','ActionWeaveIntegrationV16']:
        path=name+'.validation.json';r=read(path);assert r['passed'];source_hashes(r,'sha256');reports[path]=digest(path)
    path='EffectsV16.validation.json';r=read(path)
    assert r['actual_source_executed'] and r['syntax_checked'] and r['assertions']>0
    source_hashes(r,'source_sha256');reports[path]=digest(path)
    path='BootV16.validation.json';r=read(path)
    assert r['input_sha256']==base and r['new_maps_executed']
    assert r['map_builder_sha256']==digest('MapBuilderV16.luau')
    assert r['economy_patch_sha256']==digest('EconomyServiceV16.luau')
    for e in manifest['edits']:assert r['source_overlays'][e['path']]==digest(e['source'])
    assert len(r['scenarios'])>=10;reports[path]=digest(path)
    assembly=read('tools/v16/assembly.json');assert assembly['status']=='passed'
    source_hashes(assembly,'source_sha256')
    installer='Install-HABWAS-Polish-V16.command.luau'
    assert assembly['installer_sha256']==digest(installer)
    assert (ROOT/'HABWAS-Polish-V16.txt').read_bytes().replace(b'\r\n',b'\n')==(ROOT/installer).read_bytes()
    path='InstallerV16.validation.json';r=read(path)
    assert r.get('passed') is True or r.get('status')=='passed'
    assert r['installer_sha256']==digest(installer)
    source_hashes(r,'source_sha256')
    reports[path]=digest(path)
    path='V16-APIReview.validation.json';r=read(path)
    assert r['verified'];source_hashes(r,'sourceSha256');reports[path]=digest(path)
    path='HABWAS-Polished-V16.validation.json';r=read(path)
    assert r['status']=='passed' and r['input_sha256']==base
    assert r['output_sha256']==digest('HABWAS-Polished-V16.rbxl')
    assert r['all_original_property_entries_verified'] and r['independent_decoder_no_new_warnings']
    assert set(r['updated_sources'])=={e['path'] for e in manifest['edits']+manifest['additions']}
    reports[path]=digest(path)
    for wpath in manifest['world_manifests']:
        w=read(wpath)
        assert digest(w['builder'])==w['sourceSHA256']
        assert digest(w['geometry'])==w['geometry_sha256']
        reports[wpath]=digest(wpath)
    path='MapsV16.validation.json';maps=read(path)
    assert maps['builderSHA256']==digest('MapBuilderV16.luau')
    assert maps['geometrySHA256']==digest('tools/v16/maps/generated.rbxl')
    assert maps['routes']['mapCount']==15 and maps['routes']['allRampsIndependentlyReachable']==30
    assert maps['mutations']['rejectedBrokenFixtures']==5
    reports[path]=digest(path)
    for path in ['LobbyV16.validation.json','LobbyInstallerV16.validation.json']:
        r=read(path);assert r['passed']
        assert r['builderSHA256']==digest('LobbyBuilderV16.luau')
        if 'mapBuilderSHA256' in r:
            assert r['mapBuilderSHA256']==digest('MapBuilderV16.luau')
            assert r['mapExportSHA256']==maps['routes']['geometryRawSHA256']
        reports[path]=digest(path)
    path='PackagedRerunV16.validation.json';r=read(path)
    assert r['passed'] and r['place_sha256']==digest('HABWAS-Polished-V16.rbxl')
    assert r['installer_sha256']==digest(installer);reports[path]=digest(path)
    preview_provenance=read('tools/v16/lobby/preview-provenance.json')
    assert preview_provenance['builderSHA256']==digest('LobbyBuilderV16.luau')
    assert preview_provenance['mapBuilderSHA256']==digest('MapBuilderV16.luau')
    source_hashes(preview_provenance,'previews')
    files=[installer,'HABWAS-Polish-V16.txt','HABWAS-Polished-V16.rbxl','HABWAS.rbxl',
           'tools/v16/place_patch.json','tools/v16/assembly.json']
    release={'status':'passed','baseline':'Untouched HABWAS.rbxl; no V15 runtime installed',
        'artifacts':{p:{'bytes':(ROOT/p).stat().st_size,'sha256':digest(p)} for p in files},
        'validation_reports':reports,'runtime_sources':assembly['source_sha256'],
        'offline_previews':{p:digest(p) for p in [*preview_provenance['previews'],'MapsV16-Preview.png',
            'ActionAnimationsV16-Poses.png','ActionAnimationsV16-Preview.gif','WeaveV16-Poses.png','WeaveV16-Preview.gif']},
        'native_studio_tested':False,
        'limits':'Offline actual-source tests, analytic geometry and independent RBXL decoding passed. Native Studio opening, rendering, physics, animation blending, streaming, networking and live Roblox purchases require playtesting.'}
    (ROOT/'V16-Release.validation.json').write_text(json.dumps(release,indent=2)+'\n')
    print('V16 release artifacts and executed source validations match.')

if __name__=='__main__':run()
