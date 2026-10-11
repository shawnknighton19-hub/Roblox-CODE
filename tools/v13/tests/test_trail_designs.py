#!/usr/bin/env python3
"""Execute actual trail geometry and path sampling without claiming Studio rendering."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, tempfile

repo = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', default=shutil.which('luau') or '/workspace/.cloud-tools/bin/luau')
parser.add_argument('--report', type=Path)
parser.add_argument('--preview-data', type=Path)
args = parser.parse_args()
compiler = shutil.which('luau-compile') or str(Path(args.luau).with_name('luau-compile'))
source = (repo/'tools/v12/tests/skins_math_instance_fixture.luau').read_text()
for name, path in [('catalog','HussCatalogV13.luau'),('oldCatalog','HussCatalogV12.luau'),('builder','TrailDesignsV13.luau')]:
    source += '\nlocal '+name+'=(function()\n'+(repo/path).read_text()+'\nend)()\n'
source += r'''
local checks=0
local function check(ok,message) checks+=1;assert(ok,message) end
local output={}
local maximum=0
local function hidden(h)
 for _,p in ipairs(h.Model:GetChildren()) do if p.Transparency<1 then return false end end
 return true
end
local function center(group)
 local v=Vector3.zero;for _,r in ipairs(group) do v+=r.object.Position end;return v/#group
end
check(#catalog.Items==#oldCatalog.Items,'Catalog length unchanged')
check(json(catalog.Categories)==json(oldCatalog.Categories),'Categories unchanged')
check(json(catalog.Defaults)==json(oldCatalog.Defaults),'Defaults unchanged')
for i,item in ipairs(catalog.Items) do
 local old=oldCatalog.Items[i]
 for key,value in pairs(old) do
  if item.category=='Trails' and key=='description' then check(item.description~=old.description,'Trail description updated')
  else check(json(item[key])==json(value),'Preserved catalog field '..item.id..' '..key) end
 end
end
local parent=Instance.new('Folder')
check(builder.Create(parent,'unknown')==nil,'Unknown id rejected')
check(builder.Create(nil,'default')==nil,'Missing parent rejected')
check(builder.Create(parent,catalog.ById.bomb_classic)==nil,'Wrong category rejected')
check(builder.Preview(parent,'unknown')==nil,'Unknown preview rejected')
check(#parent:GetChildren()==0,'Invalid calls create no objects')
check(#builder.Ids==25 and builder.MaxParts==18,'Published design and part budgets')
for _,item in ipairs(catalog.Items) do if item.category=='Trails' then
 local h=builder.Create(parent,item)
 check(h~=nil and h.Model.Parent==parent,'Creates isolated model')
 check(h.Model:GetAttribute('HussTrailId')==item.id,'Authoritative visual identity')
 check(h.PartCount>3 and h.PartCount<=18,'Bounded readable motif pool')
 maximum=math.max(maximum,h.PartCount)
 check(#h.Model:GetChildren()==h.PartCount,'Exactly declared pool')
 check(hidden(h),'Created disabled and invisible')
 for _,p in ipairs(h.Model:GetChildren()) do
  check(p:IsA('BasePart'),'No effects, constraints or executable descendants')
  check(p.Anchored and p.Massless and not p.CanCollide and not p.CanTouch and not p.CanQuery and not p.CastShadow,'Local geometry cannot affect gameplay')
  check(p.Size.X>0 and p.Size.Y>0 and p.Size.Z>0,'Positive dimensions')
 end
 local allocated=nextID
 h:SetEnabled(true)
 -- Strafe along X while the avatar faces -Z, then turn left: wake must follow actual path.
 for frame=1,20 do h:Step(CFrame.new(frame*.5,3,0),Vector3.new(30,0,0),frame/60,1/60) end
 check(not hidden(h),'Running populates visible historical motifs')
 h:Step(CFrame.new(10,3,-.5),Vector3.new(0,0,-30),21/60,1/60)
 local tail=center(h.groups[#h.groups])
 check(tail.X<8.8 and math.abs(tail.Z)<1.6,'Tail follows previous strafe through corner, not avatar facing')
 for frame=22,80 do h:Step(CFrame.new(10,3,-(frame-20)*.5),Vector3.new(0,0,-30),frame/60,1/60) end
 check(#h.history<=64,'History remains bounded')
 check(nextID==allocated,'Motion creates no Instances')
 for _,p in ipairs(h.Model:GetChildren()) do
  for _,n in ipairs({p.CFrame:GetComponents()}) do check(n==n and math.abs(n)<math.huge,'Finite transforms after turns') end
  check(p.Transparency>=0 and p.Transparency<=1,'Valid alpha')
 end
 -- Stopping fades every existing part before the runtime reclaims its pool.
 h:SetEnabled(false)
 local samples=#h.history
 h:Step(CFrame.new(10,3,-30),Vector3.zero,80/60+builder.StopFade/2,1/60)
 check(not hidden(h),'Stop fade remains visible halfway through')
 h:Step(CFrame.new(10,3,-30),Vector3.zero,80/60+builder.StopFade+.01,1/60)
 check(hidden(h),'Stopped geometry fades fully before reclaim')
 check(#h.history==samples,'Disabled trails do not add motion samples')
 h:SetEnabled(true)
 check(#h.history==0 and hidden(h),'Reactivation discards stale history')
 for frame=1,20 do h:Step(CFrame.new(frame*.5,3,0),Vector3.new(30,0,0),2+frame/60,1/60) end
 h:Step(CFrame.new(120,3,300),Vector3.new(30,0,0),2+21/60,1/60)
 check(#h.history==1 and hidden(h),'Teleport clears trail instead of drawing across map')
 h:Step(CFrame.new(120.5,3,300),Vector3.new(30,0,0),4,1/60)
 check(#h.history==1 and hidden(h),'Large frame gap clears trail')
 h:Step(CFrame.new(121,3,300),Vector3.new(30,0,0),3,1/60)
 check(#h.history==1 and hidden(h),'Clock reversal clears trail')
 h:Step(CFrame.new(121,3,300),Vector3.new(0/0,0,0),3.1,1/60)
 check(not h.enabled and hidden(h) and #h.history==0,'Invalid input fails closed without corrupt transforms')
 check(nextID==allocated,'All lifecycle steps reuse only pooled Instances')
 h:Destroy();h:Destroy();h:SetEnabled(true);h:Step(CFrame.identity,Vector3.zero,5,1/60)
 check(h.Model.Parent==nil and #h.Model:GetChildren()==0 and h.destroyed,'Destroy idempotent and releases all geometry')
 -- Frozen preview is the actual sculpture, with no extra render-step callback.
 local preview=builder.Preview(parent,item)
 check(preview and preview:GetAttribute('Preview')==true,'Preview model returned')
 check(#preview:GetChildren()==h.PartCount,'Preview and live use identical part pool')
 for _,p in ipairs(preview:GetChildren()) do
  check(p.Anchored and p.Transparency<1,'Every preview motif visible and anchored')
  check(p.Position.Magnitude<5,'Preview bounds remain compact')
 end
 table.insert(output,{item=item,object=exportNode(preview),parts=h.PartCount})
 preview:Destroy()
end end
check(#output==25,'All 25 trails exercised')
check(#parent:GetChildren()==0,'No orphaned models after all lifecycle tests')
print(json({checks=checks,maximum_parts=maximum,trails=output}))
'''
for name in ['TrailDesignsV13.luau','HussCatalogV13.luau']:
    subprocess.run([compiler,str(repo/name)],check=True,stdout=subprocess.DEVNULL)
with tempfile.TemporaryDirectory(prefix='huss-trails-v13-') as directory:
    test=Path(directory)/'trails.luau';test.write_text(source)
    result=subprocess.run([args.luau,str(test)],capture_output=True,text=True)
    if result.returncode:
        print(result.stdout,end='');print(result.stderr,end='');raise SystemExit(result.returncode)
data=json.loads(result.stdout)
signatures={}
for entry in data['trails']:
    signature=[]
    for node in entry['object']['children']:
        p=node['props'];cf=p['CFrame']
        signature.append([node['class'],p.get('Shape',{}).get('Name'),[p['Size'][axis] for axis in 'XYZ'],
                          [round(cf['p'][axis],6) for axis in 'XYZ'],[round(v,6) for v in cf['m']]])
    digest=hashlib.sha256(json.dumps(sorted(signature,key=str)).encode()).hexdigest()
    assert digest not in signatures,('Duplicate geometry excluding color/name',entry['item']['id'],signatures.get(digest))
    signatures[digest]=entry['item']['id']
report={'passed':True,'runtime_assertions':data['checks'],'distinct_geometry_signatures_excluding_color_and_names':len(signatures),
        'maximum_parts_per_trail':data['maximum_parts'],'emitters_per_trail':0,'instances_created_during_motion':0,
        'catalog_ids_prices_defaults_preserved':True,'path_corner_teleport_stop_cleanup_tested':True,
        'part_counts':{t['item']['id']:t['parts'] for t in data['trails']},
        'limitations':'Deterministic Instance/math harness and offline geometry export; native Roblox rendering requires Studio playtest.',
        'sha256':{name:hashlib.sha256((repo/name).read_bytes()).hexdigest() for name in ['TrailDesignsV13.luau','HussCatalogV13.luau']}}
if args.report:
    args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(report,indent=2)+'\n')
if args.preview_data:
    args.preview_data.parent.mkdir(parents=True,exist_ok=True);args.preview_data.write_text(json.dumps(data['trails']))
print(json.dumps({key:report[key] for key in ['passed','runtime_assertions','distinct_geometry_signatures_excluding_color_and_names','maximum_parts_per_trail']}))
