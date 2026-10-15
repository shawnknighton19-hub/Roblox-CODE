"""Exercise actual lobby Plan/Apply code, including rollback and repeated installation."""
from pathlib import Path
import subprocess,json,hashlib,argparse
from common import REPO as ROOT, output_dir, luau_binary
parser=argparse.ArgumentParser();parser.add_argument('--out-dir');parser.add_argument('--luau');parser.add_argument('--report')
args=parser.parse_args();OUT=output_dir(args.out_dir)
mock=(ROOT/'tools/v12/mock_prefix.luau').read_text()
source=(ROOT/'LobbyBuilderV15.luau').read_text()
regressions=r'''
function methods:IsDescendantOf(ancestor)
 local p=self.Parent;while p do if p==ancestor then return true end;p=p.Parent end;return false
end
local checks=0
local function check(value,message) checks+=1;assert(value,message) end
local function create(class,parent,name)
 local o=Instance.new(class);o.Name=name;o.Parent=parent;return o
end
local function fixture()
 local lobby=create('Model',workspace,'Lobby')
 local floor=create('Part',lobby,'Floor');floor.Size=Vector3.new(204,6,188);floor.CFrame=CFrame.new(0,-1.5,86.66000366210938);lobby.PrimaryPart=floor
 local origin=floor.CFrame*CFrame.new(0,3,0)
 local spawn=create('SpawnLocation',lobby,'LobbySpawn');spawn.CFrame=origin*CFrame.new(0,.5,64)
 for _,name in ipairs(B.ArchiveNames) do create('Model',lobby,name) end
 local exchange=create('Model',lobby,'V11 Bomb Exchange')
 for name,pos in pairs({Bombs=Vector3.new(-79.5,5.5,-17),Trails=Vector3.new(-79.5,5.5,20),Titles=Vector3.new(79.5,5.5,-17),Emotes=Vector3.new(79.5,5.5,20)}) do
  local kiosk=create('Model',exchange,name..' kiosk');local anchor=create('Part',kiosk,'Browse '..name);anchor.CFrame=origin*CFrame.new(pos)
  anchor:SetAttribute('HussShopCategory',name);anchor:SetAttribute('HussShopRadius',12);anchor:SetAttribute('HussShopStandEnabled',true)
  local prompt=create('ProximityPrompt',anchor,'BrowseShop');prompt:SetAttribute('HussShopCategory',name);prompt.Enabled=false
 end
 local emotes=exchange:FindFirstChild('Emotes kiosk')
 for _,row in ipairs({{'EMOTES/HussSignV11/Body/Heading','EMOTES'},{'EMOTES/HussSignV11/Body/Subtitle','SHOW YOUR STYLE'},{'ShopPanelV12/ShopIdleV12/Body/Title','EMOTES EXCHANGE'},{'ShopPanelV12/ShopIdleV12/Body/Hint','WALK UP TO BROWSE'},{'ShopPanelV12/ShopIdleV12/Body/Details','CELEBRATE EVERY CLOSE CALL'}}) do
  local parent=emotes;local names=string.split(row[1],'/')
  for i,name in ipairs(names) do local child=parent:FindFirstChild(name) or create(i==#names and 'TextLabel' or 'Frame',parent,name);parent=child end
  parent.Text=row[2]
 end
 create('Model',exchange,'Lobby leaderboards')
 local expansion=create('Model',lobby,'HABExpansionLobby')
 for name,pos in pairs({Bundle_Cyber=Vector3.new(-28,3.6,68.3),Bundle_Glacier=Vector3.new(28,3.6,68.3),Bundle_Solar=Vector3.new(52,3.6,-7.7),Bundle_Phantom=Vector3.new(-52,3.6,-7.7),CrateStand=Vector3.new(68,3.8,35.5)}) do
  local stand=create('Model',expansion,name);local anchor=create('Part',stand,'BrowseStand');anchor.CFrame=origin*CFrame.new(pos)
  local prompt=create('ProximityPrompt',anchor,'ProximityPrompt');prompt:SetAttribute('HABOpenPanel',name=='CrateStand' and 'CRATES' or 'BUNDLES');prompt:SetAttribute('HABOffer',name);prompt.Enabled=true
 end
 create('Model',expansion,'SpectatorOverlook');create('Model',expansion,'InvisibleLobbyBarrier')
 local backup=create('Folder',services.ServerStorage,'BeforeLobbyPolish')
 return lobby,backup,spawn,floor,exchange,expansion
end
local function snapshot(o) return json(exportNode(o)) end
local function withoutText(o)
 local n=exportNode(o)
 local function visit(v) if v.class=='TextLabel' then v.props.Text=nil end;for _,c in ipairs(v.children) do visit(c) end end
 visit(n);return json(n)
end
local function countNamed(root,name) local n=0;for _,v in ipairs(root:GetDescendants()) do if v.Name==name then n+=1 end end;return n end
local lobby,backup,spawn,floor,exchange,expansion=fixture()
local spawnBefore,exchangeBefore,expansionBefore=snapshot(spawn),withoutText(exchange),snapshot(expansion)
local originalExchange=snapshot(exchange)
local plan=B.Plan(lobby);check(#plan.Move==6,'six old groups');check(plan.Previous==nil,'fresh install')
local first,result=B.Apply(lobby,backup)
check(result.Archived==6,'first archives six');check(first.Parent==lobby,'commit new geometry')
check(lobby.PrimaryPart==floor,'primary floor preserved');check(lobby:FindFirstChild('LobbySpawn')==spawn,'original spawn retained')
check(snapshot(spawn)==spawnBefore,'spawn properties untouched');check(withoutText(exchange)==exchangeBefore,'every exchange property except planned labels intact');check(result.SignChanges==4,'four visible locker labels updated');check(backup:FindFirstChild('LobbySignTextV15')~=nil,'original labels backed up');check(snapshot(expansion)==expansionBefore,'every bundle property intact')
check(countNamed(lobby,'BrowsePolishedStand')==2,'two extra prompts');check(countNamed(lobby,'HABPolishedLobbyV15')==1,'one addition root')
local second,r2=B.Apply(lobby,backup)
check(r2.Archived==1,'rerun archives only prior V15 root');check(first.Parent==backup,'previous new geometry retained');check(second.Parent==lobby,'replacement committed')
check(countNamed(lobby,'HABPolishedLobbyV15')==1,'rerun one root');check(countNamed(lobby,'BrowsePolishedStand')==2,'rerun no duplicate booths')
check(withoutText(exchange)==exchangeBefore and snapshot(expansion)==expansionBefore,'rerun preserves functional booths');check(r2.SignChanges==0,'repeat does not back up already-updated signs again')
r2.Undo();check(first.Parent==lobby,'parent transaction undo restores previous version');check(second.Parent==nil,'undo destroys staged version');r2.Undo();check(first.Parent==lobby,'undo is idempotent')
result.Undo();check(lobby:FindFirstChild('HABPolishedLobbyV15')==nil,'undo first restores original architecture');check(#backup:GetChildren()==0,'undo leaves no half-archived geometry');check(snapshot(exchange)==originalExchange,'undo restores exact original text')
lobby:Destroy()
for _,failure in ipairs({'spawn','floor','duplicate','stand','unknownVersion','missingBundle','backup'}) do
 local l,b,s,f,e,x=fixture()
 if failure=='spawn' then s.CFrame=s.CFrame+CFrame.new(0,0,4).Position
 elseif failure=='floor' then f.Size=Vector3.new(208,6,188)
 elseif failure=='duplicate' then create('Part',l,'Floor')
 elseif failure=='stand' then local a=e:FindFirstChild('Bombs kiosk'):FindFirstChild('Browse Bombs');a.CFrame=a.CFrame+CFrame.new(4,0,0).Position
 elseif failure=='unknownVersion' then create('Model',l,'HABPolishedLobbyV15')
 elseif failure=='missingBundle' then x:FindFirstChild('Bundle_Cyber'):Destroy()
 elseif failure=='backup' then b.Parent=workspace end
 local before=snapshot(l)
 local ok=pcall(B.Apply,l,b);check(not ok,'reject '..failure);check(snapshot(l)==before,'rejection no live mutation '..failure)
 l:Destroy();b:Destroy()
end
for _,failName in ipairs({'North terrace','HABPolishedLobbyV15'}) do
 local l,b=fixture();local before=snapshot(l)
 local original=mt.__newindex;local fired=false
 mt.__newindex=function(o,key,value)
  if not fired and key=='Parent' and o.Name==failName and value==(failName=='North terrace' and b or l) then fired=true;error('Injected parent assignment failure') end
  return original(o,key,value)
 end
 local ok,err=pcall(B.Apply,l,b);mt.__newindex=original
 check(not ok and fired,'injected rollback path '..failName)
 -- Sibling order can change while parents restore; identity/properties and all seven roots must remain.
 for _,name in ipairs(B.ArchiveNames) do check(l:FindFirstChild(name)~=nil,'rollback restores '..name) end
 check(l:FindFirstChild('HABPolishedLobbyV15')==nil,'failed install leaves no new root')
 check(#b:GetChildren()==0,'failed install leaves backup empty')
 l:Destroy();b:Destroy()
end
print(json({checks=checks,passed=true,scenarios={'fresh','rerun','moved spawn','changed floor','duplicate floor','moved booth','unknown replacement','missing bundle','invalid backup','mid-archive rollback','commit rollback'}}))
'''
(OUT/'test_installer.luau').write_text(mock+'\nlocal B=(function()\n'+source+'\nend)()\n'+regressions)
result=json.loads(subprocess.check_output([luau_binary(args.luau),str(OUT/'test_installer.luau')],text=True))
result['sourceSHA256']={'LobbyBuilderV15.luau':hashlib.sha256(source.encode()).hexdigest()}
result['limits']='Actual Luau code exercised in deterministic Instance adapter; not Roblox Studio integration.'
(Path(args.report) if args.report else OUT/'LobbyInstallerV15.validation.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
