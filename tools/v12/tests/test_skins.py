#!/usr/bin/env python3
"""Geometry, particle budgets, reapplication, preview parity and persistent ID regressions."""
from pathlib import Path
import subprocess,json,hashlib,math,argparse,shutil,tempfile
repo=Path(__file__).resolve().parents[3]
here=Path(__file__).resolve().parent
parser=argparse.ArgumentParser(description='Compile and validate the actual 25 bomb sculptures in an Instance/math harness.')
parser.add_argument('--luau',default=shutil.which('luau') or '/workspace/.cloud-tools/bin/luau')
parser.add_argument('--luau-compile',default=shutil.which('luau-compile'))
parser.add_argument('--preview-data',type=Path)
parser.add_argument('--report',type=Path)
args=parser.parse_args()
compiler=args.luau_compile or str(Path(args.luau).with_name('luau-compile'))
prefix=(here/'skins_math_instance_fixture.luau').read_text()
extension='''
local NumberRange={new=function(a,b) return {Min=a,Max=b or a} end}
local ColorSequence={new=function(...) return {...} end}
local NumberSequence={new=function(...) return {...} end}
local NumberSequenceKeypoint={new=function(...) return {...} end}
function Color3.fromHSV(h,s,v)
 local x=h*6;local k=math.floor(x);local f=x-k;local p=v*(1-s);local q=v*(1-s*f);local t=v*(1-s*(1-f))
 local rows={{v,t,p},{q,v,p},{p,v,t},{p,q,v},{t,p,v},{v,p,q}};return Color3.new(table.unpack(rows[k%6+1]))
end
local checks=0
local function check(v,message) checks+=1;assert(v,message) end
'''
source=prefix+extension
for variable,path in [('catalog',repo/'HussCatalogV12.luau'),('oldCatalog',repo/'HussCatalogV11.luau'),('builder',repo/'BombSkinBuilderV12.luau')]:
 source+='\nlocal '+variable+'=(function()\n'+path.read_text()+'\nend)()\n'
source+='''
local output,signatures={},{}
local maximum=0
check(#catalog.Items==#oldCatalog.Items,'Catalog count unchanged')
for i,new in ipairs(catalog.Items) do
 local old=oldCatalog.Items[i]
 for key,value in pairs(old) do if key~='description' then check(json(new[key])==json(value),'Preserved catalog field '..key..' '..old.id) end end
end
for _,item in ipairs(catalog.Items) do if item.category=='Bombs' then
 local bomb=Instance.new('Part');bomb.Size=Vector3.new(2.25,2.25,2.25);bomb.CFrame=CFrame.new(12,8,-15)*CFrame.Angles(.3,.7,-.2)
 bomb.Anchored=false
 local container=builder.Apply(bomb,item)
 check(container~=nil and container.Parent==bomb,'Live folder returned')
 check(bomb.Shape==Enum.PartType.Ball,'Every skin retains round bomb silhouette')
 check(bomb.Size==Vector3.new(2.25,2.25,2.25),'Bomb collision size unchanged')
 check(bomb.Anchored==false,'Live body remains unanchored')
 check(bomb:GetAttribute('HussBombId')==item.id,'Skin identity')
 local parts,welds,emitters,rate,lights=0,0,0,0,0
 local transforms={}
 for _,p in ipairs(container:GetDescendants()) do
  check(not p:IsA('LuaSourceContainer') and p.ClassName~='Script' and p.ClassName~='LocalScript','No executable cosmetic descendants')
  if p:IsA('BasePart') then
   parts+=1
   check(not p.CanCollide and not p.CanTouch and not p.CanQuery and p.Massless,'Cosmetic cannot affect collision or queries')
   check(not p.Anchored,'Live detail not anchored')
   check(p.Parent==container,'Geometry contained in replaceable folder')
   local w=p:FindFirstChild('CosmeticWeld');check(w and w.Part0==bomb and w.Part1==p,'Each part welded to actual bomb')
   local cf=bomb.CFrame:ToObjectSpace(p.CFrame)
   table.insert(transforms,{name=p.Name,cf=cf})
   for _,n in ipairs({cf:GetComponents()}) do check(n==n and math.abs(n)<math.huge,'Finite transform') end
   check(p.Size.X>0 and p.Size.Y>0 and p.Size.Z>0,'Positive dimensions')
  elseif p:IsA('WeldConstraint') then welds+=1
  elseif p:IsA('ParticleEmitter') then
   emitters+=1;rate+=p.Rate
   check(p.Rate<=5 and p.Lifetime.Max<=.6 and p.Speed.Max<=1.25,'Bounded particle parameters')
   check(p.Parent:IsA('Attachment') and p.Parent.Parent:IsA('BasePart'),'Emitter physically parented')
  elseif p:IsA('PointLight') then
   lights+=1;check(p.Range<=4 and p.Brightness<=.35 and not p.Shadows,'Local bounded light')
  end
 end
 check(parts==welds and parts==container:GetAttribute('DetailPartCount'),'Every detail exactly one weld')
 check(parts<=45,'Part budget');maximum=math.max(maximum,parts)
 check(emitters<=2 and rate<=8 and lights<=1,'Effect budget')
 check(container:FindFirstChild('FuseCollar') and container:FindFirstChild('FuseCurl') and container:FindFirstChild('FuseSpark'),'Common visible fuse')
 local second=builder.Apply(bomb,item)
 check(container.Parent==nil and #container:GetChildren()==0,'Reapply destroys old entire sculpture')
 check(#bomb:GetChildren()==1 and second.Parent==bomb,'Reapply cannot duplicate systems')
 local preview=builder.Apply(bomb,item,{Preview=true})
 check(second.Parent==nil and #second:GetChildren()==0,'Preview transition destroys live particles')
 check(bomb.Anchored and preview:GetAttribute('Preview'),'Preview anchored')
 local index=0
 for _,p in ipairs(preview:GetDescendants()) do
  check(not p:IsA('WeldConstraint') and not p:IsA('ParticleEmitter') and not p:IsA('PointLight'),'Preview static only')
  if p:IsA('BasePart') then
   index+=1;check(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery,'Preview parts safe')
   local cf=bomb.CFrame:ToObjectSpace(p.CFrame);local prior=transforms[index]
   check(p.Name==prior.name and (cf.Position-prior.cf.Position).Magnitude<1e-7,'Preview/live identical sculpted positions')
   for n,v in ipairs(cf.m) do check(math.abs(v-prior.cf.m[n])<1e-7,'Preview/live identical rotations') end
  end
 end
 check(index==parts,'Preview/live identical geometry counts')
 -- Export canonical local geometry for an actual-code sculpture gallery.
 local canonical=Instance.new('Part');canonical.Size=Vector3.new(2.25,2.25,2.25);canonical.CFrame=CFrame.identity
 builder.Apply(canonical,item,{Preview=true})
 table.insert(output,{item=item,object=exportNode(canonical),parts=parts})
end end
check(#output==25,'All 25 bombs generated')
check(builder.Apply(nil,catalog.Items[1])==nil,'Nil target safely ignored')
check(builder.Apply(Instance.new('Folder'),catalog.Items[1])==nil,'Nonpart safely ignored')
local blank=Instance.new('Part');check(builder.Apply(blank,oldCatalog.ById.default)==nil and #blank:GetChildren()==0,'Nonbomb item safely rejected')
print(json({checks=checks,maximum_detail_parts=maximum,bombs=output}))
'''
for name in ['BombSkinBuilderV12.luau','CosmeticsServiceV12.luau','HussCatalogV12.luau']:
 subprocess.run([compiler,str(repo/name)],check=True,stdout=subprocess.DEVNULL)
with tempfile.TemporaryDirectory(prefix='huss-skins-v12-') as directory:
 test=Path(directory)/'skins-test.luau';test.write_text(source)
 p=subprocess.run([args.luau,str(test)],capture_output=True,text=True)
 if p.returncode:
  print(p.stdout,end='');print(p.stderr,end='');raise SystemExit(p.returncode)
data=json.loads(p.stdout)
if args.preview_data:
 args.preview_data.parent.mkdir(parents=True,exist_ok=True);args.preview_data.write_text(json.dumps(data['bombs']))
def walk(n):
 yield n
 for c in n.get('children',[]):yield from walk(c)
signatures={};counts={};bounds={}
for entry in data['bombs']:
 signature=[];lo=[float('inf')]*3;hi=[float('-inf')]*3
 for n in walk(entry['object']):
  if n['class'] not in ('Part','WedgePart'):continue
  props=n['props'];cf=props['CFrame'];size=[props['Size'][k] for k in 'XYZ'];pos=[cf['p'][k] for k in 'XYZ'];m=cf['m']
  signature.append([n['class'],props.get('Shape',{}).get('Name'),size,[round(v,7) for v in pos+m]])
  for axis in range(3):
   radius=sum(abs(m[axis*3+i])*size[i]/2 for i in range(3))
   lo[axis]=min(lo[axis],pos[axis]-radius);hi[axis]=max(hi[axis],pos[axis]+radius)
 digest=hashlib.sha256(json.dumps(sorted(signature,key=str)).encode()).hexdigest()
 assert digest not in signatures,'Geometry duplicates '+entry['item']['id']+' '+signatures.get(digest,'')
 signatures[digest]=entry['item']['id'];counts[entry['item']['id']]=entry['parts'];bounds[entry['item']['id']]={'min':lo,'max':hi}
 assert max(max(abs(v) for v in lo),max(abs(v) for v in hi))<2.01,(entry['item']['id'],lo,hi)
# V12 deliberately keeps server emote state, checks, rates and cleanup byte-for-byte.
s12=(repo/'CosmeticsServiceV12.luau').read_text();s11=(repo/'CosmeticsServiceV11.luau').read_text()
assert s12[s12.index('local function stop(p)'):]==s11[s11.index('local function stop(p)'):]
report={'passed':True,'runtime_assertions':data['checks'],'distinct_geometry_signatures_excluding_color_and_names':len(signatures),'maximum_detail_parts':data['maximum_detail_parts'],'part_counts':counts,'bounds_local_studs':bounds,'catalog_ids_prices_defaults_preserved':True,'emote_security_and_lifecycle_unchanged':True,'compile':'All three Luau sources compiled','limitations':'Deterministic Instance/math harness and offline geometry export. Native Roblox rendering, replicated welds and particle visuals require Studio playtest.','sha256':{name:hashlib.sha256((repo/name).read_bytes()).hexdigest() for name in ['BombSkinBuilderV12.luau','CosmeticsServiceV12.luau','HussCatalogV12.luau']}}
if args.report:
 args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['passed','runtime_assertions','distinct_geometry_signatures_excluding_color_and_names','maximum_detail_parts']}))
