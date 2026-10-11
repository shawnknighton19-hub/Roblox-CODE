from pathlib import Path
import json,subprocess,sys
sys.path.insert(0,str(Path(__file__).parent))
from assemble import ROOT as BUILD_ROOT,REPO,literal,payload,compiler
import os,shutil,tempfile
ROOT=Path(os.environ.get('V12_TEST_OUTPUT',str(Path(tempfile.gettempdir())/'huss-v12-installer-tests')))
ROOT.mkdir(parents=True,exist_ok=True)
FIXTURES=BUILD_ROOT/'fixtures'
PREFIX=(BUILD_ROOT/'mock_prefix.luau').read_text()
SELECT=['HudController','ServerMain','RoundService','BombService','Remotes','GameConfig','BombTagMapVoteServiceV6','DodgeIFrameServer','BombTagAFKServer','ClientMain','BombTagMapVoteServer']
MANIFEST=json.loads((FIXTURES/'manifest.json').read_text())
FIXTURE='local fixture={\n'+''.join('{path='+literal(x['path'])+',class='+literal(x['class'])+',source='+literal((FIXTURES/x['file']).read_text())+',disabled='+('true' if x['disabled'] else 'false')+'},\n' for x in MANIFEST)+'}\n'
SOURCES={'HUD':FIXTURES/'HudControllerV10-on-V8.luau','HUD_V9':REPO/'HudControllerV10.luau','MAIN_V9':FIXTURES/'MainV9.luau','ROUND_V9':FIXTURES/'RoundV9.luau','BOMB_V9':FIXTURES/'BombV9.luau','MOVEMENT':FIXTURES/'MovementV7.luau','EFFECTS':REPO/'MovementEffectsV8.client.luau','EFFECTS_V9':FIXTURES/'EffectsV9.luau','ECONOMY_V9':REPO/'EconomyServiceV9.luau'}
STUB=r'''
local B={}
function B.Build(library,lobby)
 if TEST_MODE=='worldBuildFailure' then error('injected world failure') end
 local result={Library=library:Clone(),Lobby=lobby:Clone()}
 for _,name in ipairs({'Fuseworks','Detonator Plaza','Payload Port'}) do if not result.Library:FindFirstChild(name) then local m=library:GetChildren()[1]:Clone();m.Name=name;m.Parent=result.Library end end
 for _,m in ipairs(result.Library:GetChildren()) do if m:IsA('Model') then m:SetAttribute('BombTagGenerated','HussWorld11') end end
 result.Lobby:SetAttribute('HussLobbyVersion',11)
 return result
end
return B
'''
SHOP_STUB=r'''
local S={}
function S.Validate(lobby) assert(lobby:GetAttribute('HussShopVersion')==12,'Shop fixture missing');return true end
function S.Apply(lobby) lobby:SetAttribute('HussShopVersion',12);return lobby end
return S
'''
SETUP=r'''
local baseIsA=methods.IsA
function methods:IsA(class)
 if class=='BaseScript' then return self.ClassName=='Script' or self.ClassName=='LocalScript' end
 if class=='LuaSourceContainer' then return self.ClassName=='ModuleScript' or self:IsA('BaseScript') end
 return baseIsA(self,class)
end
local assertions=0
local function check(ok,message) assert(ok,message);assertions+=1 end
local modes={'commandNameConflict','commandAliasConflict','commandWrongClass','normal','repeat','v9','rootMain','v9MissingEconomy','missingPreviews','repairMissingModule','playMode','notStudio','missingHUD','missingLobby','missingLibrary','missingAnchor','missingArena','extraArena','badHUD','badMain','badBomb','badRound','badMovement','badEffects','badEconomy','duplicateMain','duplicateHud','duplicateServices','duplicateMap','nestedEffects','disabledMain','disabledMovement','disabledEffects','unarchivable','worldScript','worldBuildFailure','syntaxFailure','newSourceFailure','backupParentFailure','archiveLibrary','archiveLobby','archivePreviews','archiveArena','worldLibrary','worldLobby','worldPreviews','worldArena','setMap','setVersion','unownedEconomyRemote','unownedCosmeticRemote','wrongRemote','sourceReadback','missingVoteModule','badVoteModule','missingVoteRemote','wrongAFKRemote','missingClientMain','badRemotes','badConfig','configValues','wrongDodgeRemote','wrongRoundRemote','duplicateRoundModule','missingShared','missingLobbySpawn','wrongLobbySpawn','badArenaSpawns','badTemplateSpawns','repeatMissingLobbySpawn','repeatBadArenaSpawns','repeatBadTemplateSpawns','aggregateErrors','featuredMapConflict','repeatBadFeaturedMap'}
local newNames={'EconomyServiceV9','HussCatalogV11','CosmeticsServiceV11','PracticeServiceV11','PerfectWeaveServiceV11','CollectionEffectsV11','LobbyBoardsV11','BombSkinBuilderV12','OwnerCommandsV12','OwnerFeedbackV12','CarrierPanicV12','StandShopV12'}
local function destination(name,rs,sp,sf) if name=='HussCatalogV11' or name=='BombSkinBuilderV12' then return rs elseif name=='CollectionEffectsV11' or name=='LobbyBoardsV11' or name=='OwnerFeedbackV12' or name=='CarrierPanicV12' or name=='StandShopV12' then return sp else return sf end end
for _,name in ipairs(newNames) do table.insert(modes,'conflict_'..name);table.insert(modes,'parent_'..name) end
for _,name in ipairs({'HUD','MAIN','BOMB','ROUND','MOVEMENT','EFFECTS'}) do table.insert(modes,'write_'..name) end
local summaries={}
local function runCase(mode)
 workspace=Instance.new('Workspace');services.Workspace=workspace
 for _,name in ipairs({'StarterPlayer','ServerStorage','ReplicatedStorage','ServerScriptService','Lighting','TextChatService'}) do services[name]=Instance.new(name) end
 services.CollectionService={AddTag=function(_,o,t) o:SetAttribute('_TestTag_'..t,true) end,HasTag=function(_,o,t) return o:GetAttribute('_TestTag_'..t)==true end}
 services.RunService={IsStudio=function() return mode~='notStudio' end,IsRunning=function() return mode=='playMode' end}
 local function make(class,parent,name,source)
  local o=Instance.new(class,parent);o.Name=name;o.Archivable=true;o.Disabled=false;if source then o.Source=source end;return o
 end
 local sp=make('StarterPlayerScripts',services.StarterPlayer,'StarterPlayerScripts')
 local ss,rs,sss=services.ServerStorage,services.ReplicatedStorage,services.ServerScriptService
 local byName={}
 for _,entry in ipairs(fixture) do
  local segments=string.split(entry.path,'/');local parent=services[segments[1]]
  for i=2,#segments-1 do parent=parent:FindFirstChild(segments[i]) or make('Folder',parent,segments[i]) end
  local o=make(entry.class,parent,segments[#segments],entry.source);o.Disabled=entry.disabled;byName[o.Name]=o
 end
 local sf=sss.Services
 if mode=='commandNameConflict' or mode=='commandAliasConflict' or mode=='commandWrongClass' then
  local cmd=make(mode=='commandWrongClass' and 'Folder' or 'TextChatCommand',services.TextChatService,mode=='commandAliasConflict' and 'CustomAdmin' or 'HussOwnerGrantV12')
  if cmd:IsA('TextChatCommand') then cmd.PrimaryAlias=mode=='commandAliasConflict' and '/GRANT' or '/something';cmd.SecondaryAlias='' end
 end
 local objects={HUD=byName.HudController,MAIN=byName.ServerMain,BOMB=byName.BombService,ROUND=byName.RoundService,
  MOVEMENT=make('LocalScript',sp,'SnappyMovement',MOVEMENT_SOURCE),EFFECTS=make('LocalScript',sp,'MovementEffectsV8',EFFECTS_SOURCE)}
 objects.HUD.Source=HUD_SOURCE
 make('RemoteEvent',rs,'BombTagVoteV6');make('RemoteEvent',rs,'BombTagAFKRequest')
 if mode=='v9' or mode=='v9MissingEconomy' or mode=='badEconomy' then
  objects.HUD.Source=HUD_V9_SOURCE;objects.MAIN.Source=MAIN_V9_SOURCE;objects.ROUND.Source=ROUND_V9_SOURCE;objects.BOMB.Source=BOMB_V9_SOURCE;objects.EFFECTS.Source=EFFECTS_V9_SOURCE
  if mode~='v9MissingEconomy' then objects.ECONOMY=make('ModuleScript',sf,'EconomyServiceV9',ECONOMY_V9_SOURCE) end
 end
 if mode=='rootMain' or mode=='v9' then objects.MAIN.Parent=sss end
 local untouched={make('LocalScript',sp,'GameAudioV6','original audio'),make('LocalScript',sp,'ForcedShiftLock','original shift'),byName.BombTagAFKServer,byName.DodgeIFrameServer,byName.BombTagMapVoteServiceV6,byName.ClientMain}
 local sky=make('Sky',services.Lighting,'Sky');sky.SkyboxBk='preserved';services.Lighting.TimeOfDay='08:45:00'
 local names={'Sky Garden','Sunset Docks','Frostfall Village','Sunstone Bazaar','Neon District','Clockwork Foundry','Orbital Station','Stardust Carnival','Crystal Cavern','Emerald Ruins','Pirate Cove','Ember Keep'}
 local library=make('Folder',ss,'MapLibrary')
 for i,name in ipairs(names) do
  local map=make('Model',library,name);map:SetAttribute('BombTagGenerated','HussWorld4');map:SetAttribute('MapWidth',180);map:SetAttribute('MapDepth',160)
  local floor=make('Part',map,'Floor');floor.Size=Vector3.new(160+i*3,4,150+i*2);floor.Position=Vector3.new(i*400,-2,0);map.PrimaryPart=floor
  local spawns=make('Folder',map,'Spawns')
  for j=1,16 do local p=make('Part',spawns,'Spawn'..j);p.Position=floor.Position+Vector3.new(j*2,3,25);p.Transparency=1 end
  make('SurfaceGui',floor,'MapSign')
 end
 local lobby=make('Model',workspace,'Lobby');lobby:SetAttribute('HussLobbyVersion',7)
 local lf=make('Part',lobby,'Floor');lf.Size=Vector3.new(204,4,188);lf.Position=Vector3.new(0,-2,240);lobby.PrimaryPart=lf
 local spawn=make('SpawnLocation',lobby,'LobbySpawn');spawn.Position=Vector3.new(0,.5,260)
 local anchor=make('Part',workspace,'ActiveArenaAnchor');anchor.Position=Vector3.new(0,0,0)
 local maps=make('Folder',workspace,'Maps');local arena=library:GetChildren()[1]:Clone();arena.Name='Arena01';arena.Parent=maps
 local previews=make('Folder',rs,'BombTagV6Previews');make('Model',previews,'OldPreview')
 local remote
 if mode=='unownedEconomyRemote' or mode=='unownedCosmeticRemote' or mode=='wrongRemote' then remote=make(mode=='wrongRemote' and 'Folder' or 'RemoteEvent',rs,mode=='unownedEconomyRemote' and 'HussEconomyV9' or 'HussCosmeticsV11') end
 local conflict=mode:match('^conflict_(.+)$')
 if conflict then make('ModuleScript',destination(conflict,rs,sp,sf),conflict,'user source') end
 local missing={missingHUD=objects.HUD,missingLobby=lobby,missingLibrary=library,missingPreviews=previews,missingAnchor=anchor,missingArena=arena,missingVoteModule=byName.BombTagMapVoteServiceV6,missingVoteRemote=rs.BombTagVoteV6,missingClientMain=byName.ClientMain,missingShared=rs.Shared}
 if missing[mode] then missing[mode].Parent=nil end
 if mode=='missingLobbySpawn' then spawn.Parent=nil end
 if mode=='wrongLobbySpawn' then spawn.Parent=nil;make('Part',lobby,'LobbySpawn') end
 if mode=='badArenaSpawns' then arena.Spawns:ClearAllChildren();for i=1,16 do make('Folder',arena.Spawns,'Fake'..i) end end
 if mode=='badTemplateSpawns' then library:GetChildren()[2].Spawns:ClearAllChildren() end
 if mode=='aggregateErrors' then objects.HUD.Parent=nil;objects.ROUND.Source='return {}';objects.EFFECTS.Source='return {}' end
 if mode=='extraArena' then local extra=arena:Clone();extra.Parent=maps end
 if mode=='duplicateMain' then local o=objects.MAIN:Clone();o.Parent=sss end
 if mode=='duplicateHud' then local o=objects.HUD:Clone();o.Parent=sp end
 if mode=='duplicateRoundModule' then local o=objects.ROUND:Clone();o.Parent=sf end
 if mode=='duplicateServices' then make('Folder',sss,'Services') end
 if mode=='featuredMapConflict' then make('Folder',library,'Fuseworks') end
 if mode=='duplicateMap' then local o=library:GetChildren()[1]:Clone();o.Parent=library end
 if mode=='nestedEffects' then make('LocalScript',sp.Controllers,'CollectionEffectsV11','custom effects') end
 if mode=='worldScript' then make('Script',lobby,'CustomWorld','print("unexpected")') end
 if mode=='wrongAFKRemote' then rs.BombTagAFKRequest:Destroy();make('Folder',rs,'BombTagAFKRequest') end
 if mode=='wrongDodgeRemote' then make('Folder',rs.Shared.Net,'DodgeIFrameRequest') end
 if mode=='wrongRoundRemote' then local f=make('Folder',rs,'BombTagRemotes');make('Folder',f,'RoundState') end
 local bad={badEconomy=objects.ECONOMY,badHUD=objects.HUD,badMain=objects.MAIN,badBomb=objects.BOMB,badRound=objects.ROUND,badMovement=objects.MOVEMENT,badEffects=objects.EFFECTS,badVoteModule=byName.BombTagMapVoteServiceV6,badRemotes=byName.Remotes}
 if bad[mode] then bad[mode].Source='return {}' end
 if mode=='badConfig' then byName.GameConfig.Source=byName.GameConfig.Source:gsub('GameConfig.TagCheckInterval = 0.03','GameConfig.TagCheckInterval = 0') end
 if mode=='configValues' then byName.GameConfig.Source=byName.GameConfig.Source:gsub('GameConfig.NormalBombFuseSeconds = 14','GameConfig.NormalBombFuseSeconds = 16') end
 if mode=='unarchivable' then objects.BOMB.Archivable=false end
 if mode=='disabledMain' then objects.MAIN.Disabled=true end
 if mode=='disabledMovement' then objects.MOVEMENT.Disabled=true end
 if mode=='disabledEffects' then objects.EFFECTS.Disabled=true end
 workspace:SetAttribute('CurrentVotedMap','Sky Garden');workspace:SetAttribute('HussLobbyMusicId','rbxassetid://321');workspace:SetAttribute('HussDodgeDuration',.72)
 local before,parent,disabled={},{},{}
 for _,o in pairs(objects) do before[o]=o.Source;parent[o]=o.Parent;disabled[o]=o.Disabled end
 for _,o in ipairs(untouched) do before[o]=o.Source end
 local originalObjects={library,lobby,previews,arena};local parentWorld={}
 for _,o in ipairs(originalObjects) do parentWorld[o]=o.Parent end
 local originalSpawnCF=spawn.CFrame
 local normalIndex,normalAttribute=mt.__newindex,methods.SetAttribute
 local armed=true
 methods.SetAttribute=function(o,key,value)
  if armed and o==workspace and ((mode=='setMap' and key=='CurrentVotedMap') or (mode=='setVersion' and key=='HussExpansionVersion')) then armed=false;error('injected '..mode) end
  normalAttribute(o,key,value)
 end
 mt.__newindex=function(o,key,value)
  local fail=false
  if armed then
   if mode=='newSourceFailure' then fail=key=='Source' and o.Name=='PracticeServiceV11'
   elseif mode=='backupParentFailure' then fail=key=='Parent' and value==ss and o.Name:find('ExpansionV12Backup_',1,true)==1
   elseif mode=='archiveLibrary' then fail=o==library and key=='Parent' and value~=ss
   elseif mode=='archiveLobby' then fail=o==lobby and key=='Parent' and value~=workspace
   elseif mode=='archivePreviews' then fail=o==previews and key=='Parent' and value~=rs
   elseif mode=='archiveArena' then fail=o==arena and key=='Parent' and value~=maps
   elseif mode=='worldLibrary' then fail=o~=library and o.Name=='MapLibrary' and key=='Parent' and value==ss
   elseif mode=='worldLobby' then fail=o~=lobby and o.Name=='Lobby' and key=='Parent' and value==workspace
   elseif mode=='worldPreviews' then fail=o~=previews and o.Name=='BombTagV6Previews' and key=='Parent' and value==rs
   elseif mode=='worldArena' then fail=o~=arena and o.Name=='Arena01' and key=='Parent' and value==maps
   elseif mode:find('write_',1,true)==1 then fail=o==objects[mode:sub(7)] and key=='Source' and value~=before[o]
   elseif mode:find('parent_',1,true)==1 then fail=o.Name==mode:sub(8) and key=='Parent' and (value==rs or value==sf or value==sp)
   elseif mode=='sourceReadback' and o==objects.MAIN and key=='Source' and value~=before[o] then armed=false;return
   end
  end
  if fail then armed=false;error('injected '..mode) end
  normalIndex(o,key,value)
 end
 local TEST_MODE=mode
 local requires=0
 local function require(module)
  check(module.Name=='SyntaxProbe' and module.Parent.Parent==ss,'Only inert syntax probe modules are required')
  check(module.Source:sub(1,18)=='return function()\n','Probe wraps original source')
  requires+=1
  if TEST_MODE=='syntaxFailure' and requires==1 then module.Source='return function()\nlocal =\nend' end
  local fn,message=loadstring(module.Source);assert(fn,message);return fn()
 end
 local function install()
'''
POST=r'''
 end
 local success,failure=pcall(install)
 mt.__newindex=normalIndex;methods.SetAttribute=normalAttribute
 local expected=mode=='normal' or mode=='repeat' or mode=='v9' or mode=='rootMain' or mode=='v9MissingEconomy' or mode=='missingPreviews' or mode=='repairMissingModule' or mode=='configValues' or mode:find('^repeat')~=nil
 check(success==expected,mode..' result: '..tostring(failure))
 if mode:find('^repeat') or mode=='repairMissingModule' then
  local firstEconomy=sf.EconomyServiceV9;local firstCatalog=rs.HussCatalogV11;local firstWorld=workspace.Lobby;local firstLibrary=ss.MapLibrary;local firstArena=maps.Arena01;local backupCount=#ss:GetChildren()
  if mode=='repairMissingModule' then sf.PracticeServiceV11:Destroy() end
  if mode=='repeatMissingLobbySpawn' then workspace.Lobby.LobbySpawn:Destroy() end
  if mode=='repeatBadArenaSpawns' then maps.Arena01.Spawns:ClearAllChildren() end
  if mode=='repeatBadFeaturedMap' then ss.MapLibrary.Fuseworks:Destroy();make('Folder',ss.MapLibrary,'Fuseworks') end
  if mode=='repeatBadTemplateSpawns' then ss.MapLibrary:GetChildren()[2].Spawns:ClearAllChildren() end
  local again,message=pcall(install);local broken=mode=='repeatMissingLobbySpawn' or mode=='repeatBadArenaSpawns' or mode=='repeatBadTemplateSpawns' or mode=='repeatBadFeaturedMap';check(again~=broken,'Rerun result: '..tostring(message));check(firstEconomy==sf.EconomyServiceV9 and firstCatalog==rs.HussCatalogV11,'Rerun preserves source identity')
  check(workspace.Lobby==firstWorld and ss.MapLibrary==firstLibrary and maps.Arena01==firstArena,'Rerun preserves geometry object identity')
  check(mode~='repeat' or #ss:GetChildren()==backupCount,'Complete rerun creates no backup or stage')
  check(sf:FindFirstChild('PracticeServiceV11')~=nil,'Missing owned dependency restored safely')
 end
 check(services.Lighting.TimeOfDay=='08:45:00' and sky.Parent==services.Lighting and sky.SkyboxBk=='preserved','Lighting untouched '..mode)
 check(workspace:GetAttribute('HussLobbyMusicId')=='rbxassetid://321' and workspace:GetAttribute('HussDodgeDuration')==.72,'Audio/cooldown settings untouched '..mode)
 check(spawn.CFrame==originalSpawnCF,'Original lobby geometry retained '..mode)
 for _,o in ipairs(untouched) do check(o.Source==before[o],'Untouched gameplay dependency '..mode) end
 check(rs:FindFirstChild('HussCosmeticsV11')==((mode=='unownedCosmeticRemote' or mode=='wrongRemote') and remote or nil),'Installer does not create runtime remotes '..mode)
 for _,o in pairs(objects) do check(o.Parent==parent[o] and o.Disabled==disabled[o],'Script identity/disabled retained '..o.Name..' '..mode) end
 for _,o in ipairs(ss:GetChildren()) do check(not o.Name:find('Preflight',1,true),'No temporary syntax modules or staging survive '..mode) end
 if expected then
  check(sf.EconomyServiceV9.Source:find('-- HussEconomyV12',1,true)~=nil,'Economy safely present '..mode)
  check(objects.HUD.Source:find('V11',1,true)~=nil,'HUD upgraded '..mode)
  for _,name in ipairs(newNames) do local p=destination(name,rs,sp,sf);check(p:FindFirstChild(name)~=nil,'New source '..name..' '..mode) end
  check(#ss.MapLibrary:GetChildren()==15 and #rs.BombTagV6Previews:GetChildren()==15,'All maps/previews installed '..mode)
  check(workspace.Lobby~=lobby and maps.Arena01~=arena,'New world installed '..mode)
  check(workspace:GetAttribute('HussExpansionVersion')==12,'Install version '..mode)
  if mode~='repeatMissingLobbySpawn' then check(workspace.Lobby.LobbySpawn.Position.Z>spawn.Position.Z,'Safe lobby gap applied '..mode) end
  for _,o in ipairs(originalObjects) do if parentWorld[o] then check(o.Parent and o.Parent.Name=='World' and o.Parent.Parent.Parent==ss,'Original world archived '..mode) end end
  local latestBackup
  for _,object in ipairs(ss:GetChildren()) do if object.Name:find('ExpansionV12Backup_',1,true)==1 then latestBackup=object end end
  check(latestBackup and latestBackup:FindFirstChild('RestoreManifest') and latestBackup.RestoreManifest.Value:find('ADDED SYSTEMS',1,true),'Backups include a readable restore manifest '..mode)
  check(requires>=19,'All resulting sources and unchanged dependencies compiled before commit '..mode)
 else
  if mode=='aggregateErrors' then check(tostring(failure):find('HudController') and tostring(failure):find('RoundService') and tostring(failure):find('MovementEffectsV8'),'Preflight aggregates all compatibility errors') end
  for _,o in pairs(objects) do check(o.Source==before[o],'Original source restored '..o.Name..' '..mode) end
  for _,o in ipairs(originalObjects) do check(o.Parent==parentWorld[o],'World restored '..o.Name..' '..mode) end
  check(workspace:GetAttribute('HussExpansionVersion')==nil and workspace:GetAttribute('CurrentVotedMap')=='Sky Garden','World attributes restored '..mode)
  for _,name in ipairs(newNames) do if name~=conflict and not (name=='EconomyServiceV9' and objects.ECONOMY) then local p=destination(name,rs,sp,sf);check(p:FindFirstChild(name)==nil,'Staged source cleaned '..name..' '..mode) end end
 end
 table.insert(summaries,{mode=mode,result=success and 'installed' or 'originals preserved',requires=requires,error=success and '' or tostring(failure)})
end
for _,mode in ipairs(modes) do runCase(mode) end
print('COMPAT_INSTALL_REPORT '..json({assertions=assertions,cases=#modes,results=summaries}))
'''
def main():
 full='--full-world' in sys.argv
 installed='--compile-installed' in sys.argv
 prefix=PREFIX;setup=SETUP;post=POST
 if full:
  prefix+='\nlocal ColorSequence={new=function(a,b) return {_kind="ColorSequence",A=a,B=b or a} end}\n'
  for name,file in [('OldMaps','MovementMapBuilder.luau'),('OldLobby','LobbyBuilderV7.luau')]:prefix+='\nlocal '+name+'=(function()\n'+(REPO/file).read_text()+'\nend)()\n'
  start=setup.index(" local library=make('Folder',ss,'MapLibrary')");end=setup.index(" local anchor=make('Part',workspace,'ActiveArenaAnchor')",start)
  setup=setup[:start]+" local library=make('Folder',ss,'MapLibrary');OldMaps.BuildInto(library)\n local lobby=OldLobby.Build(workspace,CFrame.new(0,0,240));local spawn=lobby.LobbySpawn\n"+setup[end:]
  setup=setup.replace('local summaries={}',"modes={'normal','repeat','v9'}\nlocal summaries={}")
 if installed:
  setup=setup.replace('local summaries={}',"modes={'normal','v9'}\nlocal summaries={}")
  post=post.replace(' table.insert(summaries,',r'''
 local values={}
 for _,o in pairs(objects) do values[o.Name]=o.Source end
 for _,name in ipairs(newNames) do local p=destination(name,rs,sp,sf);values[name]=p[name].Source end
 print('INSTALLED_SOURCES '..json(values))
 table.insert(summaries,''')
 body=prefix+'\n'+FIXTURE+''.join('local '+k+'_SOURCE='+literal(p.read_text())+'\n' for k,p in SOURCES.items())+setup+payload(None if full else STUB, None if full else SHOP_STUB)+post
 name='test-install-full' if full else 'test-install-sources' if installed else 'test-install'
 path=ROOT/(name+'.luau');path.write_text(body)
 result=subprocess.run([os.environ.get('LUAU') or shutil.which('luau') or '/workspace/.cloud-tools/bin/luau',str(path)],text=True,capture_output=True)
 (ROOT/(name+'.output')).write_text(result.stdout+result.stderr)
 if result.returncode:print(result.stdout[-1500:]+result.stderr);sys.exit(result.returncode)
 report=json.loads(next(x for x in result.stdout.splitlines() if x.startswith('COMPAT_INSTALL_REPORT ')).split(' ',1)[1])
 if installed:
  folders=[]
  for i,line in enumerate(x for x in result.stdout.splitlines() if x.startswith('INSTALLED_SOURCES ')):
   values=json.loads(line.split(' ',1)[1]);folder=ROOT/('installed-'+str(i));folder.mkdir(exist_ok=True)
   for n,source in values.items():
    p=folder/(n+'.luau');p.write_text(source);subprocess.run([compiler(),'--binary',str(p)],stdout=subprocess.DEVNULL,check=True)
   folders.append({'path':str(folder),'files':len(values)})
  report['installed_source_compilations']=folders
 report['scope']='Actual authored V4 maps/V7 lobby' if full else 'Real adapters, real staged source and syntax compilation; deterministic geometry fixture; no native Roblox Studio.'
 target=ROOT/('installer-full.validation.json' if full else 'installer-sources.validation.json' if installed else 'installer.validation.json')
 target.write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k!='results'}))
if __name__=='__main__':main()
