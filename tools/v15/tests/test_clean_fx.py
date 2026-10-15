"""Exercise actual compact FX lifecycle and imported-art routing with API doubles."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[3]
FILES=['HABCleanCosmeticsV15.luau','HABRendererV15.luau','HABHalloweenEffectsV15.client.luau']
base=(ROOT/'tools/v12/tests/panic_fixture.luau.in').read_text().split('local panicExports')[0]
base+=r'''
services.RunService.IsClient=function() return true end
services.UserInputService={TouchEnabled=false}
services.ContentProvider={PreloadAsync=function(_,assets,fn) for _,asset in ipairs(assets) do fn(asset,Enum.AssetFetchStatus.Success) end end}
Vector2.zero=Vector2.new(0,0)
function Color3:ToHSV() return .3,.5,1 end
function Color3.fromHSV() return Color3.new(.5,1,.6) end
local pack=Instance.new('Folder',services.ReplicatedStorage);pack.Name='HABHalloween'
local catalogue=Instance.new('ModuleScript',pack);catalogue.Name='Catalog'
local cleanModule=Instance.new('ModuleScript',pack);cleanModule.Name='HABCleanCosmeticsV15'
local effectsModule=Instance.new('ModuleScript',pack);effectsModule.Name='Effects'
local nativeModule=Instance.new('ModuleScript',pack);nativeModule.Name='NativeFX'
script.Parent=pack
local catalog={ById={}}
for _,kind in ipairs({'Aura','BombFX','DodgeFX','Trail','KillFX'}) do
 catalog.ById[kind]={Category=kind,Color=Color3.fromRGB(80,180,255),SourceId=kind..'Art'}
end
catalog.ById.NativeTrail={Category='Trail',SourceId='NativeTrailArt'}
catalog.ById.KillFX.RetiredFinisher=true
local effect={colour='123',mono='',fit=1,lifetime=.5,glow=Color3.fromRGB(80,180,255)}
local importedPreloads,importedPlays=0,0
local native={Has=function(id) return id=='NativeTrailArt' end,
 Preload=function() importedPreloads+=1 end,Status=function() return 'ready' end,
 Play=function() importedPlays+=1;return {End=clock+.5,Stop=function() end} end}
local require=function(object) assert(object==catalogue);return catalog end
local clean=(function()
{{CLEAN}}
end)()
require=function(object)
 if object==catalogue then return catalog elseif object==cleanModule then return clean
 elseif object==effectsModule then return {TrailArt=effect,AuraArt=effect,BombFXArt=effect,DodgeFXArt=effect}
 elseif object==nativeModule then return native end
 error('Unexpected require '..object.Name)
end
local renderer=(function()
{{RENDERER}}
end)()
local checks=0
local function check(value,message) checks+=1;assert(value,message) end
local function tick(dt) clock+=dt;services.RunService.Heartbeat:Fire(dt) end
local root=owner.Character.HumanoidRootPart
local function particles()
 local n=0;for _,v in ipairs(workspace:GetDescendants()) do if v:IsA('ParticleEmitter') then n+=1 end end;return n
end
for _,kind in ipairs({'Aura','BombFX','DodgeFX','rawAbility'}) do
 local h=renderer.Play(kind,root,6,nil,true,.2,true)
 check(h~=nil and #h.Objects<=6,'Compact native geometry for '..kind)
 tick(.05)
 check(particles()==0,'No PNG emitter for '..kind)
 for _,p in ipairs(h.Objects) do
  check(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery and not p.CastShadow,'Pure cosmetic geometry')
  check(p.Transparency<1 and p.Size.Magnitude<1,'Small visible effect')
 end
 local old=h.Objects[1].CFrame.Position
 root.CFrame=root.CFrame+CFrame.new().Position+Vector3.new(1,0,0)
 tick(.01)
 check((h.Objects[1].Position-old).Magnitude>.5,'Effect follows equipped host')
 h:Stop();h:Stop();check(h.Stopped and #h.Objects==0,'Idempotent cleanup')
end
check(renderer.Play('KillFX',root)==nil,'Retired kill effect stays retired')
renderer.Preload('Aura');check(importedPreloads==0,'No non-trail texture preload')
renderer.Preload('NativeTrail');check(importedPreloads==1,'Native imported trail preloads')
renderer.Play('NativeTrail',root,3);check(importedPlays==1,'Native imported trail renderer retained')
local png=renderer.Play('Trail',root,3)
check(png and particles()>0,'PNG trail renderer retained')
png:Stop();tick(.7);check(particles()==0,'Trail particles reclaimed')
local handles={}
for n=1,40 do handles[n]=clean.Play('Aura',root,3) end
local count=0;for _,h in pairs(handles) do if h then count+=1 end end
check(count<=22,'Desktop effect handle budget')
owner:SetAttribute('HussReducedMotion',true);tick(.01)
check(#workspace:FindFirstChild('HABCleanCosmeticsV15'):GetChildren()==0,'Reduced Motion clears existing effects')
check(clean.Play('Aura',root)==nil,'Reduced Motion blocks new effects')
owner:SetAttribute('HussReducedMotion',nil)
local h=clean.Play('Aura',root,3,nil,true);root.Parent=nil;tick(.02)
check(h.Stopped,'Removed character host cleans effect')
root.Parent=owner.Character
local far=clean.Play('Aura',CFrame.new(1000,0,0));check(far==nil,'Distance culling')
local expires=clean.Play('BombFX',root);tick(2);check(expires.Stopped,'Expired effects cleaned')
clean.Destroy();clean.Destroy();check(clean.Play('Aura',root)==nil,'Destroyed renderer cannot recreate effects')
print('CLEAN_FX_V15 '..checks..' checks passed')
'''
for name in FILES:
    subprocess.run(['/workspace/.cloud-tools/bin/luau-compile','--binary',str(ROOT/name)],stdout=subprocess.DEVNULL,check=True)
base=base.replace('{{CLEAN}}',(ROOT/FILES[0]).read_text()).replace('{{RENDERER}}',(ROOT/FILES[1]).read_text())
with tempfile.TemporaryDirectory(prefix='hab-v15-fx-') as temporary:
    path=Path(temporary)/'test.luau';path.write_text(base)
    result=subprocess.run(['/workspace/.cloud-tools/bin/luau',str(path)],capture_output=True,text=True)
    print(result.stdout,end='');print(result.stderr,end='')
    if result.returncode:raise SystemExit(result.returncode)
(ROOT/'CleanFXV15.validation.json').write_text(json.dumps({'status':'passed','output':result.stdout.strip(),
 'source_sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in FILES},
 'limits':'Actual-source deterministic API/lifecycle doubles, not native Studio rendering.'},indent=2)+'\n')
