"""Execute real V16 installer transactions, reruns, drift rejection and rollback."""
from pathlib import Path
import argparse,json,subprocess,sys,hashlib
HERE=Path(__file__).resolve().parent;REPO=HERE.parents[2];sys.path.insert(0,str(REPO/'tools/v15/lobby'))
from common import output_dir,luau_binary
p=argparse.ArgumentParser();p.add_argument('--out-dir');p.add_argument('--luau');p.add_argument('--report');a=p.parse_args();out=output_dir(a.out_dir)
mock=(REPO/'tools/v12/mock_prefix.luau').read_text();source=(REPO/'LobbyBuilderV16.luau').read_text()
test=r'''
function methods:IsDescendantOf(ancestor) local p=self.Parent;while p do if p==ancestor then return true end;p=p.Parent end;return false end
local checks=0
local function check(v,message) checks+=1;assert(v,message) end
local function create(class,parent,name) local o=Instance.new(class);o.Name=name;o.Parent=parent;return o end
local function path(root,where,finalClass)
 local list=string.split(where,'/');local p=root
 for i,name in ipairs(list) do p=p:FindFirstChild(name) or create(i==#list and (finalClass or 'Model') or 'Model',p,name) end
 return p
end
local function cfclose(a,b)
 local aa,bb={a:GetComponents()},{b:GetComponents()};for i=1,12 do if math.abs(aa[i]-bb[i])>.0001 then return false end end;return true
end
local function fixture()
 local l=create('Model',workspace,'Lobby');local floor=create('Part',l,'Floor');floor.Size=Vector3.new(204,6,188);floor.CFrame=CFrame.new(0,-1.5,86.66000366210938);l.PrimaryPart=floor
 local spawn=create('SpawnLocation',l,'LobbySpawn');spawn.CFrame=CFrame.new(0,2,150.66000366210938)
 local arena=create('Part',workspace,'ActiveArenaAnchor');arena.CFrame=CFrame.new(0,-27,-245)
 for _,entry in ipairs(B.GetLayout()) do
  local m=path(l,entry.Path);m.WorldPivot=entry.Old
  local anchor=create('Part',m,entry.Anchor);anchor.CFrame=entry.Old;anchor:SetAttribute('Category','KeepThis');anchor.CanCollide=false
  local nested=create('Model',m,'RotatingBombDisplay');nested.WorldPivot=entry.Old*CFrame.new(2,1,0);nested:SetAttribute('HABDisplayOrigin',nested.WorldPivot);nested:SetAttribute('KeepString','unchanged');nested:SetAttribute('KeepNumber',12)
  local p=create('Part',nested,'Display');p.CFrame=nested.WorldPivot;local prompt=create('ProximityPrompt',anchor,'Browse');prompt:SetAttribute('HABOpenPanel','BUNDLES')
 end
 for _,name in ipairs(B.ArchivePaths) do path(l,name) end
 for _,r in ipairs({{'EMOTES/HussSignV11/Body/Heading','EMOTES'},{'EMOTES/HussSignV11/Body/Subtitle','SHOW YOUR STYLE'},{'ShopPanelV12/ShopIdleV12/Body/Title','EMOTES EXCHANGE'},{'ShopPanelV12/ShopIdleV12/Body/Details','CELEBRATE EVERY CLOSE CALL'}}) do path(l,'V11 Bomb Exchange/Emotes kiosk/'..r[1],'TextLabel').Text=r[2] end
 local backup=create('Folder',services.ServerStorage,'BeforeLobby')
 return l,backup,arena,floor,spawn
end
local function snapshot(root)
 local rows={};for _,o in ipairs(root:GetDescendants()) do
  if o:IsA('BasePart') then table.insert(rows,{o,o.CFrame}) end
  for k,v in pairs(o:GetAttributes()) do table.insert(rows,{o,k,v}) end
  if o:IsA('TextLabel') then table.insert(rows,{o,'Text',o.Text}) end
 end;return rows
end
local function unchanged(rows)
 for _,r in ipairs(rows) do
  if #r==2 then check(cfclose(r[1].CFrame,r[2]),'restored part '..r[1].Name)
  elseif r[2]=='Text' then check(r[1].Text==r[3],'restored text')
  elseif typeof(r[3])=='CFrame' then check(cfclose(r[1]:GetAttribute(r[2]),r[3]),'restored CFrame attribute')
  else check(r[1]:GetAttribute(r[2])==r[3],'preserved attribute') end
 end
end
local l,b,a,f,s=fixture();local before=snapshot(l);local identities={}
for _,r in ipairs(B.GetLayout()) do identities[r.Path]=path(l,r.Path) end
local plan=B.Plan(l,a);check(#plan.Moves==10,'ten precise moves');check(#plan.Archives==5,'five old geometry groups')
local root,result=B.Apply(l,b,a);check(result.Moves==10,'ten moved groups');check(result.Archived==5,'five archived models');check(l.PrimaryPart==f,'floor identity');check(l:FindFirstChild('LobbySpawn')==s,'spawn identity');check(cfclose(a.CFrame,CFrame.new(0,-27,-190)),'arena moved closer')
for _,r in ipairs(B.GetLayout()) do
 local m=path(l,r.Path);check(m==identities[r.Path],'booth identity preserved');check(cfclose(path(m,r.Anchor,'Part').CFrame,r.New),'anchor correct '..r.Path)
 local display=m:FindFirstChild('RotatingBombDisplay');check(cfclose(display:GetAttribute('HABDisplayOrigin'),r.Delta*r.Old*CFrame.new(2,1,0)),'display origin moves');check(display:GetAttribute('KeepString')=='unchanged','non-CFrame attrs preserved')
end
local after=snapshot(l);local second,r2=B.Apply(l,b,a);check(r2.Moves==0,'rerun never moves booths twice');check(r2.Archived==1,'rerun archives only previous added geometry');check(root.Parent==b,'previous root backed up')
r2.Undo();check(root.Parent==l and second.Parent==nil,'rerun undo restores previous root');r2.Undo();unchanged(after)
result.Undo();unchanged(before);check(#b:GetChildren()==0,'rollback clears transaction backups');check(cfclose(a.CFrame,CFrame.new(0,-27,-245)),'rollback arena')
l:Destroy();a:Destroy();b:Destroy()
for _,kind in ipairs({'floor','spawn','anchor','arena','version','missing','text','backup'}) do
 local ll,bb,aa,ff,ss=fixture()
 if kind=='floor' then ff.Size=Vector3.new(208,6,188)
 elseif kind=='spawn' then ss.CFrame=CFrame.new(0,2,160)
 elseif kind=='anchor' then path(ll,'V11 Bomb Exchange/Bombs kiosk/Browse Bombs').CFrame=CFrame.new()
 elseif kind=='arena' then aa.CFrame=CFrame.new()
 elseif kind=='version' then create('Model',ll,'HABPolishedLobbyV15')
 elseif kind=='missing' then path(ll,'HABExpansionLobby/Bundle_Cyber'):Destroy()
 elseif kind=='text' then path(ll,'V11 Bomb Exchange/Emotes kiosk/EMOTES/HussSignV11/Body/Heading').Text='CUSTOM'
 elseif kind=='backup' then bb.Parent=workspace end
 local rows=snapshot(ll);local ok=pcall(B.Apply,ll,bb,aa);check(not ok,'reject drift '..kind);unchanged(rows);check(#bb:GetChildren()==0,'no partial backup on reject');ll:Destroy();aa:Destroy();bb:Destroy()
end
for _,failName in ipairs({'North terrace','HABLobbyLayoutV16'}) do
 local ll,bb,aa=fixture();local rows=snapshot(ll);local original=mt.__newindex;local fired=false
 mt.__newindex=function(o,key,value)
  if not fired and key=='Parent' and o.Name==failName and value==(failName=='North terrace' and bb or ll) then fired=true;error('Injected failure') end
  return original(o,key,value)
 end
 local ok=pcall(B.Apply,ll,bb,aa);mt.__newindex=original;check(not ok and fired,'injected failure rolled back');unchanged(rows);check(#bb:GetChildren()==0,'rollback no backup leftovers');check(ll:FindFirstChild('HABLobbyLayoutV16')==nil,'rollback no live root');check(cfclose(aa.CFrame,CFrame.new(0,-27,-245)),'failure restores arena')
 for _,name in ipairs(B.ArchivePaths) do check(path(ll,name).Parent~=bb,'archive restored') end
 ll:Destroy();aa:Destroy();bb:Destroy()
end
print(json({checks=checks,passed=true,scenarios={'fresh','rerun','identity preservation','CFrame attribute transformation','full undo','drift rejection','mid-archive rollback','commit rollback'}}))
'''
f=out/'lobby-tests.luau';f.write_text(mock+'\nlocal B=(function()\n'+source+'\nend)()\n'+test)
r=json.loads(subprocess.check_output([luau_binary(a.luau),str(f)],text=True));r['builderSHA256']=hashlib.sha256(source.encode()).hexdigest();r['limits']='Actual Luau transactions in deterministic Instance adapter; Studio engine not available.'
Path(a.report or out/'LobbyInstallerV16.validation.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
