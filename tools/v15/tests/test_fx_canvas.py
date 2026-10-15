#!/usr/bin/env python3
"""Execute native preview routing/cleanup and literal-only monetization preservation."""
from pathlib import Path
import hashlib, json, shutil, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[3]
LUAU=shutil.which('luau') or '/workspace/.cloud-tools/bin/luau'
files=['FXCanvasV15.luau','tools/v15/monetization_adapter.luau','HABMonetizationConfigV15.luau']
old=(ROOT/'tools/v15/fixtures/27160_FXCanvas.luau').read_text()
current=(ROOT/files[0]).read_text()
assert old in current, 'Trail source must remain exact inside lazy wrapper'
source=(ROOT/'tools/v12/tests/skins_math_instance_fixture.luau').read_text()
source+='''
local checks=0
local function check(ok,message) checks+=1;assert(ok,message or tostring(checks)) end
local callbacks={}
local run={RenderStepped={Connect=function(_,fn) callbacks[#callbacks+1]=fn;return {Disconnect=function() end} end}}
local player={GetAttribute=function() return false end}
services.RunService=run;services.Players={LocalPlayer=player}
Enum.ParticleFlipbookLayout={GetEnumItems=function() return {{Value=0,Name='None'},{Value=1,Name='Grid4x4'}} end}
local reads=0
local catalog={ById={},Effects={trail={colour=456,lifetime=1}}}
catalog.Get=function(id) return catalog.ById[id] end
for _,category in ipairs({'Aura','BombFX','DodgeFX','Other','Trail'}) do
 local id=category=='Trail' and 'trail' or category
 catalog.ById[id]={Category=category,Color=Color3.fromRGB(255,200,80)}
end
local data={Templates={},Properties={}}
local soundById={ById={sound=true}}
local soundMounts=0
local sounds={Mount=function(parent,id)
 soundMounts+=1
 local frame=Instance.new('TextLabel');frame.Text='♪';frame.Parent=parent
 return {Stop=function() frame:Destroy() end}
end}
local pack={Catalog=catalog,ExtraFXData=data,HABKillSounds=soundById,HABKillSoundPlayer=sounds}
function pack:FindFirstChild(name) return self[name] end
local script={Parent=pack}
local function require(module) if module==data then reads+=1 end;return module end
local function loadCanvas()
'''+current+'''
end
local canvas=loadCanvas()
local screen=Instance.new('ScreenGui');screen.Enabled=true;screen.Parent=services.ReplicatedStorage
local function box()
 local frame=Instance.new('Frame');frame.ZIndex=2;frame.Parent=screen;return frame
end
check(reads==0 and #callbacks==0,'non-trail initialization does not load texture data or animate')
for _,id in ipairs({'Aura','BombFX','DodgeFX','Other'}) do
 local parent=box();local h=canvas.Mount(parent,id,12)
 check(h and h.Status=='READY' and type(h.Destroy)=='function','native handle compatibility')
 check(h.Label.Text=='3D ACCENT','honest native accent label')
 local partCount=0
 for _,object in ipairs(parent:GetDescendants()) do
  check(object.ClassName~='ImageLabel' and object.ClassName~='ImageButton' and object.ClassName~='ParticleEmitter','no imported PNG geometry preview')
  if object:IsA('BasePart') then
   partCount+=1
   check(object.Anchored and not object.CanCollide and not object.CanTouch and not object.CanQuery,'preview geometry inert')
  end
 end
 check(partCount>=5 and partCount<=6,'bounded native geometry')
 check(reads==0 and #callbacks==0,'static native preview needs no frame loop')
 h:Retry();check(parent:GetAttribute('HABFXPreviewStatus')=='READY','native Retry compatible')
 h:Stop();h:Destroy();check(#parent:GetChildren()==0,'idempotent native preview cleanup')
end
local soundBox=box();local sound=canvas.Mount(soundBox,'sound',8)
check(soundMounts==1 and reads==0,'sound delegates vector play preview only')
sound:Destroy();check(#soundBox:GetChildren()==0,'sound destroy alias')
check(canvas.Mount(box(),'unknown',8)==nil,'unknown ID stays absent')
local parent=box();local trail=canvas.Mount(parent,'trail',8)
check(reads==1 and #callbacks==1,'trail starts original shared animator lazily')
check(#trail.Sprites==1 and trail.Sprites[1].Image.Image=='rbxassetid://456','original trail art retained')
trail.Sprites[1].Image.IsLoaded=true
for _,callback in ipairs(callbacks) do callback(.04) end
check(trail.Status=='READY','original animated preview loads')
trail:Destroy()
check(#parent:GetChildren()==0,'trail Destroy aliases original Stop')
for _,callback in ipairs(callbacks) do callback(.04) end
local second=canvas.Mount(box(),'trail',8)
check(reads==1 and #callbacks==1,'one shared trail update loop')
second:Stop()
local function loadAdapter()
'''+(ROOT/files[1]).read_text()+'''
end
local adapter=loadAdapter()
local baseline='''+'[========['+(ROOT/files[2]).read_text()+']========]'+'''
check(adapter.Compatible(baseline,baseline),'default config compatible')
local edited=baseline:gsub('VIP = 0','VIP = 222'):gsub('Solar = 0','Solar = 333'):gsub('pouch = 0','pouch = 444'):gsub('pouch = true','pouch = false')
local ok,values=adapter.Compatible(baseline,edited)
check(ok and values.Passes.VIP==222 and values.Products.pouch==444 and not values.Sales.pouch,'allowed IDs/sale switches preserved')
check(not adapter.Compatible(baseline,edited:gsub('Solar = 333','Solar = 222')),'duplicate pass IDs rejected')
check(not adapter.Compatible(baseline,edited:gsub('VIP = 222','VIP = -1')),'negative ID rejected')
check(not adapter.Compatible(baseline,edited:gsub('VIP = 222','VIP = 2.5')),'fractional ID rejected')
check(not adapter.Compatible(baseline,edited:gsub('VIP = 222','VIP = 1e3')),'executable/exponent syntax outside literals rejected')
check(not adapter.Compatible(baseline,edited:gsub('VIP = 222','VIP = 9007199254740992')),'unsafe integer rejected')
check(not adapter.Compatible(baseline,edited:gsub('pouch = false','pouch = nil')),'invalid switch rejected')
check(not adapter.Compatible(baseline,edited:gsub('VIP = 222','VIP=222')),'unreviewed formatting changes stop safely')
check(not adapter.Compatible(baseline,edited..'\\nprint(123)'),'added executable content rejected')
check(not adapter.Compatible(baseline,edited:gsub('Version = 15','Version = 99')),'only approved fields can change')
print('FX_CANVAS_ASSERTIONS='..checks)
'''
for file in files:
 result=subprocess.run([LUAU+'-compile',str(ROOT/file)],capture_output=True,text=True)
 if result.returncode: raise SystemExit(result.stderr)
with tempfile.TemporaryDirectory() as directory:
 path=Path(directory)/'preview.luau';path.write_text(source)
 result=subprocess.run([LUAU,str(path)],capture_output=True,text=True)
 if result.returncode: raise SystemExit(result.stdout+result.stderr)
 print(result.stdout,end='')
 count=int(result.stdout.split('FX_CANVAS_ASSERTIONS=')[1].splitlines()[0])
report={'assertions':count,'actual_source_executed':True,'trail_source_preserved_exactly':True,'native_studio_tested':False,
        'coverage':['non-trail PNG-free geometry','bounded static preview/cleanup','sound icon delegation',
                    'original trail texture animation','shared lazy trail loop','literal-only monetization preservation'],
        'source_sha256':{f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in files}}
(ROOT/'FXCanvasV15.validation.json').write_text(json.dumps(report,indent=2)+'\n')
