#!/usr/bin/env python3
"""Actual-source V16 effect/category regressions with deterministic Roblox service doubles."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
BASE=ROOT/'tools/v15/fixtures'
LUAU=shutil.which('luau') or '/workspace/.cloud-tools/bin/luau'
manifest=json.loads((ROOT/'tools/v16/effect_patch_manifest.json').read_text())
def read(name):return (ROOT/name).read_text()
def old(name):return (BASE/name).read_text()
def module(source):return '(function()\n'+source+'\nend)()'
for row in manifest['edits']:
 assert hashlib.sha256((BASE/row['original']).read_bytes()).hexdigest()==row['original_sha256']
 path=ROOT/row['source']
 result=subprocess.run([LUAU+'-compile',str(path)],capture_output=True,text=True)
 if result.returncode:raise SystemExit(result.stderr)
 row['source_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
# The original renderer implementation and the sprite animation/atlas remain exact.
assert old('27147_Renderer.luau').split('local ExpandedCatalog=')[0]==read('HABRendererV16.luau').split('local ExpandedCatalog=')[0]
assert old('27160_FXCanvas.luau').split(' local sourceId=item.SourceId or id',1)[1]==read('FXCanvasV16.luau').split(' local sourceId=item.SourceId or id',1)[1]
original=old('8445_HABHalloweenEffects.luau')
preserved=original[original.index('   if ids.Aura'):original.index("   local bomb=s.c:FindFirstChild('ActiveBomb')")]
assert preserved in read('HABHalloweenEffectsV16.client.luau')
assert 'PanicTear' not in read('CarrierPanicV16.client.luau') and 'Instance.new' not in read('CarrierPanicV16.client.luau')
assert 'ParticleEmitter' not in read('HABCombatFXV16.client.luau') and "Instance.new('Explosion')" not in read('HABCombatFXV16.client.luau')
source=read('tools/v12/tests/panic_fixture.luau.in').split('local panicExports')[0]
source+=(HERE/'effect_fixture.luau').read_text()
source+='\nconfig='+module(old('27167_Config.luau'))+'\n'
source+='effects='+module(old('27145_Effects.luau'))+'\n'
source+='settings='+module(old('27151_Settings.luau'))+'\n'
source+='names='+module(old('27162_HABEffectNames.luau'))+'\n'
source+='sounds='+module(old('27164_HABKillSounds.luau'))+'\n'
template_ids=re.findall(r'\["((?:ability|combat)_\d+)"\]=',old('27146_Catalog.luau'))
source+='for _,id in ipairs({'+','.join(json.dumps(i) for i in template_ids)+'}) do extra.Templates[id]={Name=id,Color={.4,.7,1},Pack="Original art",Duration=.7} end\n'
source+='local originalCatalog='+module(old('27146_Catalog.luau'))+'\n'
source+='catalog='+module(read('HABCatalogV16.luau'))+'\n'
source+='local model='+module(read('CollectionViewModelV16.luau'))+'\n'
source+='local renderer='+module(read('HABRendererV16.luau'))+'\n'
source+='local canvas='+module(read('FXCanvasV16.luau'))+'\n'
source+='local function serviceGuard(action,payload)\nlocal p=owner;local Catalog=catalog;local Economy={HABCrateProfile=function() return savedState end};local snapshot=function() return savedState end\n'
service=read('HABCrateServiceV16.luau')
source+=service[service.index('            local removed='):service.index("            if action=='BuyCrate' or action=='OpenStored'")]
source+='\nend\n'
panic=read('CarrierPanicV16.client.luau')
source+='local function panicGuard(state,now,serverNow)\nlocal me=owner;local VIEW_DISTANCE=110;local DODGE_DURATION=.72\nlocal function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end\nlocal function reduced() return false end\n'
source+=panic[panic.index('local function blocked('):panic.index('local function pose(')]
source+='return blocked(state,now,serverNow)\nend\n'
source+='local function startAbilities()\n'+read('HABFunAbilityFXV16.client.luau')+'\nend\n'
stand=read('StandShopV16.client.luau')
source+='local function standRouteTest()\n'
source+=(HERE/'stand_route_fixture.luau').read_text()
source+=stand[stand.index('updateApproach=function()'):stand.index('connect(RS.ChildAdded,attach)')]
source+='''
+updateApproach()
+check(owner:GetAttribute('HABCollectionTab')=='INVENTORY' and owner:GetAttribute('HABCollectionRequest')==1,'former emote booth opens existing inventory')
+check(renderCalls==0,'retired emote shop not rendered')
+updateApproach();check(owner:GetAttribute('HABCollectionRequest')==1,'locker does not reopen every heartbeat')
+root.CFrame=CFrame.new(40,3,0);updateApproach()
+root.CFrame=CFrame.new(0,3,0);updateApproach()
+check(owner:GetAttribute('HABCollectionRequest')==2,'locker reopens after leaving and returning')
+locker:SetAttribute('HussShopCategory','Bombs');dismissed=nil;updateApproach()
+check(renderCalls==1 and active==locker,'original bomb shop path unchanged')
+end
+standRouteTest()
+'''.replace('\n+','\n')
source+=(HERE/'effect_cases.luau').read_text()
with tempfile.TemporaryDirectory(prefix='hab-v16-effects-') as directory:
 path=Path(directory)/'regressions.luau';path.write_text(source)
 result=subprocess.run([LUAU,str(path)],capture_output=True,text=True)
 if result.returncode:raise SystemExit(result.stdout+result.stderr)
 print(result.stdout,end='');checks=int(result.stdout.split('V16_EFFECT_ASSERTIONS=')[1].splitlines()[0])
(ROOT/'tools/v16/effect_patch_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
report={'assertions':checks,'actual_source_executed':True,'syntax_checked':True,'native_studio_tested':False,
 'preservation':['original Trail/Aura renderer core','original sprite atlas/update','original Trail/Aura live timing and positions','all saved catalog IDs','kill sounds','original 25 boost Trail script unchanged'],
 'coverage':['removed category rendering denied','ability artwork requires approved context','same original preview textures','removed crate refund-only','direct request category guards','all nine original ability effects','shield cleanup','event deduplication','panic yields to action/weave'],
 'source_sha256':{row['source']:row['source_sha256'] for row in manifest['edits']}}
(ROOT/'EffectsV16.validation.json').write_text(json.dumps(report,indent=2)+'\n')
