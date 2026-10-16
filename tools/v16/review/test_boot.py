#!/usr/bin/env python3
"""Execute original HABWAS server boot/round code with deterministic service doubles.
Every required project module is the full extracted body, never an import stub.
Native rendering, physics/network replication and platform availability are not simulated.
"""
from pathlib import Path
import sys,json,hashlib,subprocess,base64,zstandard,re,tempfile,argparse
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools/v15'))
from place_binary import Place
from original_fixture import load as original_rows
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--manifest',type=Path,default=ROOT/'tools/v16/place_patch.json')
parser.add_argument('--new-maps',action='store_true',help='Build the exact new MapBuilderV16 templates inside each patched test environment')
args=parser.parse_args()
manifest=json.loads(args.manifest.read_text()) if args.manifest.exists() else None
INPUT=ROOT/'HABWAS.rbxl'
place=Place(INPUT)
assert hashlib.sha256(place.data).hexdigest()=='c354d8c3c7ac43b9364749aa292716aa592eee6f496f532c98c0bafb88279309'
paths={place.path_of(r):r for r in place.instances}
overrides={paths[e['path']]:ROOT/e['source'] for e in manifest['edits']} if manifest else {27181:ROOT/'EconomyServiceV16.luau'}
for ref,path in overrides.items():assert path.exists(),path
original_by_ref={r['ref']:r for r in original_rows()}

def quoted(s):return json.dumps(s,ensure_ascii=False)
def lua(v):
    if v is None:return 'nil'
    if isinstance(v,bool):return str(v).lower()
    if isinstance(v,(int,float)):return repr(v)
    if isinstance(v,str):return quoted(v)
    if isinstance(v,list):return '{'+','.join(map(lua,v))+'}'
    return '{'+','.join('['+quoted(k)+']='+lua(w) for k,w in v.items())+'}'
packed=''.join(re.search(r'return \[=\[(.*?)\]=\]',(ROOT/'tools/v15/fixtures'/name).read_text(),re.S).group(1) for name in ['27153_ExtraFXPart01.luau','27154_ExtraFXPart02.luau','27155_ExtraFXPart03.luau','27156_ExtraFXPart04.luau'])
archive=zstandard.ZstdDecompressor().decompress(base64.b64decode(packed)).decode()
assert len(archive.encode())==2611230
archive_prefix='local originalArchiveBase64='+quoted(packed)+'\nlocal originalArchiveJSON='+quoted(archive)+'\nlocal originalArchiveData='+lua(json.loads(archive))+'\n'

def world():
    chosen=set()
    for ref,obj in place.instances.items():
        path=place.path_of(ref)
        if ref in place.source_chunks or (path.startswith('ReplicatedStorage/') and obj['class'] in ('Folder','Model','RemoteEvent','RemoteFunction')):
            chosen.add(path)
        if path.startswith('Workspace/Lobby/V11 Bomb Exchange/') and obj['name'].startswith('Browse '):chosen.add(path)
        if path in ('Workspace/Lobby','Workspace/Lobby/LobbySpawn','Workspace/ActiveArenaAnchor','Workspace/Maps','ServerStorage/MapLibrary'):
            chosen.add(path)
        if path.startswith(('ServerStorage/MapLibrary/','Workspace/Maps/')):
            parts=path.split('/')
            if len(parts)==3 or (len(parts)==4 and parts[-1] in ('Floor','Spawns')) or (len(parts)==5 and parts[-2]=='Spawns'):
                chosen.add(path)
    for path in list(chosen):
        pieces=path.split('/')
        for n in range(1,len(pieces)):chosen.add('/'.join(pieces[:n]))
    lines=['local world={}']
    for path in sorted(chosen,key=lambda p:(p.count('/'),p)):
        o=place.instances[paths[path]]
        if '/' not in path:
            lines.append(f'world[{quoted(path)}]=services[{quoted(path)}] or Instance.new({quoted(o["class"])})')
        else:
            parent,name=path.rsplit('/',1)
            lines.append(f'do local o=Instance.new({quoted(o["class"])});o.Name={quoted(name)};o.Parent=world[{quoted(parent)}];world[{quoted(path)}]=o end')
        if path.startswith('Workspace/Lobby/V11 Bomb Exchange/') and o['name'].startswith('Browse '):
            row=original_by_ref[paths[path]]
            frame=row['props']['CFrame']['value']
            lines.append(f'world[{quoted(path)}].CFrame=CFrame.new('+','.join(map(str,frame))+')')
            for key,value in row['attrs'].items():lines.append(f'world[{quoted(path)}]:SetAttribute({quoted(key)},{lua(value)})')
            tags=row['props'].get('Tags','').split('\x00')
            lines.append(f'world[{quoted(path)}]._fixtureTags='+lua(tags))
        if o['class'] in ('Part','WedgePart','SpawnLocation'):
            # Scenario physics is intentionally a flat plane. World shape contracts checked separately.
            name=o['name']
            if name=='Floor':lines.append(f'world[{quoted(path)}].Size=Vector3.new(300,2,300)')
            if path.endswith('/Spawns/'+name):
                index=1+len([x for x in chosen if x.rsplit('/',1)[0]==path.rsplit('/',1)[0] and x<path])
                lines.append(f'world[{quoted(path)}].Position=Vector3.new({index*15},2,0)')
    return '\n'.join(lines)

def sourceblock(patched):
    blocks=[]
    for ref,(ci,idx,values) in place.source_chunks.items():
        if place.instances[ref]['class']!='ModuleScript' and ref not in (27177,27217,27219,27221):continue
        src=values[idx].decode()
        if ref in overrides and patched:src=overrides[ref].read_text()
        path=place.path_of(ref).replace('/','.')
        blocks.append('sources['+quoted(path)+']=function(script)\n'+src+'\nend')
    return '\n'.join(blocks)
math=(HERE/'math_instances.luau').read_text().split('local workspace=Instance.new')[0]+'\nlocal InstanceBase=Instance\n'
runtime=(HERE/'runtime.luau').read_text()
cases=(HERE/'cases.luau').read_text()
temporary=tempfile.TemporaryDirectory(prefix='hab-boot-');out=Path(temporary.name)/'generated_boot.luau'
# Two environments, each bound to exact full source: baseline and proposed patch.
patched_world=world()
patched_world+='\nlocal lobbyLayout=(function()\n'+(ROOT/'LobbyBuilderV16.luau').read_text()+'\nend)().GetLayout()\nfor _,entry in ipairs(lobbyLayout) do local anchor=world["Workspace/Lobby/"..entry.Path.."/"..entry.Anchor];if anchor then anchor.CFrame=entry.New end end\n'
if args.new_maps:
    patched_world+='\nlocal mapBuilder=(function()\n'+(ROOT/'MapBuilderV16.luau').read_text()+'\nend)()\nservices.ServerStorage.MapLibrary:Destroy()\nmapBuilder.BuildAll(services.ServerStorage)\n'
source=archive_prefix+math+'\n'+runtime.replace('newEnvironment','baselineEnvironment',1).replace('-- SOURCES_INSERT',sourceblock(False)).replace('-- WORLD_INSERT',world())+'\n'+runtime.replace('newEnvironment','patchedEnvironment',1).replace('-- SOURCES_INSERT',sourceblock(True)).replace('-- WORLD_INSERT',patched_world)+'\n'+cases
serializer=(HERE/'math_instances.luau').read_text().split('local function json(value)')[1].split('local function exportNode')[0]
source=source.replace(cases, 'local function json(value)'+serializer+'\n'+cases)
out.write_text(source)
result=subprocess.run(['/workspace/.cloud-tools/bin/luau',str(out)],capture_output=True,text=True,timeout=60)
print(result.stderr,end='',file=sys.stderr)
if result.returncode:print(result.stdout,end='')
if result.returncode:raise SystemExit(result.returncode)
report=json.loads(result.stdout.split('BOOT_REPORT=')[1].splitlines()[0]);print('Boot integration scenarios passed: '+', '.join(report['scenarios']))
report['input_sha256']=hashlib.sha256(place.data).hexdigest()
report['economy_patch_sha256']=hashlib.sha256((ROOT/'EconomyServiceV16.luau').read_bytes()).hexdigest()
report['source_overlays']={place.path_of(ref):hashlib.sha256(path.read_bytes()).hexdigest() for ref,path in overrides.items()}
report['new_maps_executed']=args.new_maps
report['lobby_layout_sha256']=hashlib.sha256((ROOT/'LobbyBuilderV16.luau').read_bytes()).hexdigest()
if args.new_maps:report['map_builder_sha256']=hashlib.sha256((ROOT/'MapBuilderV16.luau').read_bytes()).hexdigest()
report['native_studio_tested']=False
report['scope']='Actual original bootstrap and full transitive project modules executed with deterministic platform service doubles; scenario world is flat test geometry, not Roblox physics.'
(ROOT/'BootV16.validation.json').write_text(json.dumps(report,indent=2)+'\n')
