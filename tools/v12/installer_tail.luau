-- Discover the actual place. Names are not treated as proof of compatibility.
local starter=unique(starterRoot,'StarterPlayerScripts','StarterPlayerScripts',false)
local services=unique(server,'Services','Folder',false)
local hud=unique(starter,'HudController','ModuleScript',true)
local main=unique(server,'ServerMain','Script',true)
local round=unique(services,'RoundService','ModuleScript',false)
local bomb=unique(services,'BombService','ModuleScript',false)
local economy=unique(services,'EconomyServiceV9','ModuleScript',false,true)
local movement=unique(starter,'SnappyMovement','LocalScript',true)
local effects=unique(starter,'MovementEffectsV8','LocalScript',true)
local originalLibrary=unique(storage,'MapLibrary','Folder',false)
local originalLobby=unique(workspace,'Lobby','Model',false)
local originalPreviews=unique(replicated,'BombTagV6Previews','Folder',false,true)
local maps=unique(workspace,'Maps','Folder',false)
local anchor=unique(workspace,'ActiveArenaAnchor','BasePart',false)
local originalArena
if maps then for _,object in ipairs(maps:GetChildren()) do if object:IsA('Model') then
 if originalArena then problem('Workspace.Maps has multiple active arenas; the installer cannot safely choose one.') end
 originalArena=object
end end end
if not originalArena then problem('Workspace.Maps needs one active arena Model.') end
local function validateSpawns(model)
 if not model then return end
 unique(model,'Floor','BasePart',false)
 local spawns=unique(model,'Spawns','Folder',false)
 if spawns then
  local count=0;for _,object in ipairs(spawns:GetChildren()) do if object:IsA('BasePart') then count+=1 end end
  if count<16 then problem(path(spawns)..' needs at least sixteen BasePart spawns; found '..count..'.') end
 end
end
if originalLobby then unique(originalLobby,'Floor','BasePart',false);unique(originalLobby,'LobbySpawn','SpawnLocation',false) end
validateSpawns(originalArena)
for _,object in ipairs({main,movement,effects}) do if object and object.Disabled then problem(path(object)..' is disabled. The installer preserves this setting; enable the intended owner before installing.') end end
local edits,additions,dependencySources={},{},{}
local function edit(object,adapter)
 if not object then return end
 local source=attempt(path(object),function() return adapter(object.Source) end)
 if type(source)=='string' then table.insert(edits,{object,source}) end
end
local function upgraded(source,oldAdapter,expected,target)
 if canonical(source)==canonical(target) then return target end
 local compatible=oldAdapter(source)
 assert(canonical(compatible)==canonical(expected),'Verified legacy adapter produced an unexpected source. Originals preserved.')
 return target
end
edit(main,gameplayAdapter.Main);edit(round,gameplayAdapter.Round)
edit(bomb,function(source) return upgraded(source,gameplayAdapter.Bomb,legacyBombSource,bombSource) end)
edit(hud,function(source) return upgraded(source,uiAdapter.HUD,legacyHUDSource,hudSource) end)
edit(movement,movementAdapter.Movement);edit(effects,uiAdapter.Effects)
if economy then
 local length,sum=fingerprint(economy.Source)
 if (length==14880 and sum==1268984491) or canonical(economy.Source)==canonical(legacyEconomySource) or canonical(economy.Source)==canonical(economySource) then table.insert(edits,{economy,economySource})
 else problem(path(economy)..' has unsupported source ('..length..' bytes; checksum '..sum..'). Its existing saves and source will not be overwritten.') end
elseif services then table.insert(additions,{services,'ModuleScript','EconomyServiceV9',economySource}) end
if replicated and services and starter then
 for _,entry in ipairs({
  {replicated,'ModuleScript','HussCatalogV11',catalogSource,nil,legacyCatalogSource},
  {replicated,'ModuleScript','BombSkinBuilderV12',skinSource},
  {services,'ModuleScript','CosmeticsServiceV11',cosmeticsSource,nil,legacyCosmeticsSource},
  {services,'ModuleScript','OwnerCommandsV12',ownerSource},
  {services,'ModuleScript','PracticeServiceV11',practiceSource},
  {services,'ModuleScript','PerfectWeaveServiceV11',weaveSource},
  {starter,'LocalScript','CollectionEffectsV11',collectionSource},
  {starter,'LocalScript','LobbyBoardsV11',boardsSource},
  {starter,'LocalScript','OwnerFeedbackV12',feedbackSource},
  {starter,'LocalScript','CarrierPanicV12',panicSource},
  {starter,'LocalScript','StandShopV12',shopSource},
 }) do table.insert(additions,entry) end
end
for _,entry in ipairs(additions) do
 local old=unique(entry[1],entry[3],entry[2],true,true);entry[5]=old
 if old then
  if old.Parent~=entry[1] then problem(path(old)..' is in an unexpected container; expected '..path(entry[1])..'. No duplicate will be installed.') end
  if canonical(old.Source)~=canonical(entry[4]) then
   if entry[6] and canonical(old.Source)==canonical(entry[6]) then table.insert(edits,{old,entry[4]})
   else problem(path(old)..' already contains different source. No unrelated script will be replaced.') end
  end
  if old:IsA('BaseScript') and old.Disabled then problem(path(old)..' is disabled; enable the intended system before reinstalling.') end
 end
end
for _,pair in ipairs({{'HussEconomyV9',economy},{'HussCosmeticsV11',services and services:FindFirstChild('CosmeticsServiceV11')}}) do
 local remote=unique(replicated,pair[1],'RemoteEvent',false,true)
 if remote and not pair[2] then problem(path(remote)..' has no verified owning service. Its ownership must be resolved before installation.') end
end
-- Runtime chat commands are owned by OwnerCommandsV12; do not shadow another command.
local chatService=game:GetService('TextChatService')
for _,object in ipairs(chatService:GetDescendants()) do
 local primary=object:IsA('TextChatCommand') and string.lower(object.PrimaryAlias) or ''
 local secondary=object:IsA('TextChatCommand') and string.lower(object.SecondaryAlias) or ''
 if object.Name=='HussOwnerGrantV12' or primary=='/grant' or primary=='/hussgrant' or secondary=='/grant' or secondary=='/hussgrant' then
  problem(path(object)..' conflicts with the runtime owner command /grant or /hussgrant. Commands with these aliases must not persist in Edit mode; the existing command was not replaced.')
 end
end
local context={server=server,replicated=replicated,storage=storage,starter=starter,services=services,main=main,round=round,bomb=bomb,hud=hud,movement=movement,effects=effects,library=originalLibrary,lobby=originalLobby,maps=maps,anchor=anchor,economy=economy}
local validation=attempt('Installation dependencies',function() return dependencyValidator.Validate(context) end)
if type(validation)=='table' then
 for _,message in ipairs(validation.issues or {}) do problem(message) end
 dependencySources=validation.sources or {}
 for _,message in ipairs(validation.notes or {}) do note(message) end
end
local originalNames={'Sky Garden','Sunset Docks','Frostfall Village','Sunstone Bazaar','Neon District','Clockwork Foundry','Orbital Station','Stardust Carnival','Crystal Cavern','Emerald Ruins','Pirate Cove','Ember Keep'}
local worldComplete=originalLobby and originalLobby:GetAttribute('HussLobbyVersion')==11
local worldCount,knownCount=0,0
if originalLibrary then
 local seen={}
 for _,model in ipairs(originalLibrary:GetChildren()) do
  if seen[model.Name] then problem('Duplicate map name in MapLibrary: '..model.Name) end;seen[model.Name]=true
  if model:IsA('Model') then
   worldCount+=1
   local version=model:GetAttribute('BombTagGenerated')
   if version=='HussWorld4' or version=='HussWorld11' then
    knownCount+=1
    validateSpawns(model)
    local floor=model:FindFirstChild('Floor')
    if floor and version=='HussWorld4' and (type(model:GetAttribute('MapWidth'))~='number' or type(model:GetAttribute('MapDepth'))~='number') then problem(path(model)..' is missing its authored map dimensions.') end
    if version~='HussWorld11' then worldComplete=false end
   end
  end
 end
 for _,name in ipairs(originalNames) do
  local model=originalLibrary:FindFirstChild(name)
  if not model or not model:IsA('Model') or (model:GetAttribute('BombTagGenerated')~='HussWorld4' and model:GetAttribute('BombTagGenerated')~='HussWorld11') then problem('Missing verified authored map: '..name) end
 end
 if knownCount<12 then problem('MapLibrary does not contain the twelve verified Huss movement maps. Existing map voting will be preserved.') end
 for _,name in ipairs({'Fuseworks','Detonator Plaza','Payload Port'}) do
  local model=originalLibrary:FindFirstChild(name)
  if not model then worldComplete=false
  elseif not model:IsA('Model') or model:GetAttribute('BombTagGenerated')~='HussWorld11' then problem(path(model)..' conflicts with a V11 featured map name; it will not be replaced.');worldComplete=false end
 end
end
if originalLobby and originalLobby:GetAttribute('HussLobbyVersion')~=7 and originalLobby:GetAttribute('HussLobbyVersion')~=11 then problem(path(originalLobby)..' is not a verified V7/V11 lobby; its geometry will be preserved.') end
local shopsComplete=false
if originalLobby and originalLobby:GetAttribute('HussShopVersion')==12 then
 shopsComplete=attempt('V12 lobby shops',function() return shopBuilder.Validate(originalLobby) end)==true
end
if not worldComplete or not shopsComplete then
 local toClone=not worldComplete and {originalLibrary,originalLobby,originalArena} or {originalLobby}
 for _,model in ipairs(toClone) do if model then
  for _,object in ipairs(model:GetDescendants()) do if object:IsA('BaseScript') and not object.Disabled then problem(path(object)..' is an enabled script inside geometry scheduled for cloning. Its behavior needs verification before the world can be upgraded.') end end
 end end
end
stopPreflight()
note('ServerMain: '..path(main))
note('Gameplay: '..path(round)..'; '..path(bomb))
note(economy and ('Economy: verified existing '..path(economy)) or ('Economy: add '..path(services)..'.EconomyServiceV9'))
local staging=Instance.new('Folder');staging.Name='ExpansionV12Preflight_'..os.time()
while storage:FindFirstChild(staging.Name) do staging.Name..='_' end
staging.Parent=storage
local function compileSource(label,source)
 -- require executes this outer return only. The original script body remains inert.
 -- Each fresh ModuleScript avoids require's cache and compiles LocalScripts/Scripts too.
 local probe=Instance.new('ModuleScript');probe.Name='SyntaxProbe';probe.Parent=staging
 local ok,message=pcall(function()
  probe.Source='return function()\n'..source..'\nend\n'
  assert(probe.Source=='return function()\n'..source..'\nend\n','Source write/read verification failed')
  assert(type(require(probe))=='function','Syntax probe returned unexpected content')
 end)
 probe:Destroy()
 if not ok then problem(label..': Luau syntax check failed: '..tostring(message)) end
end
for _,entry in ipairs(edits) do compileSource(path(entry[1]),entry[2]) end
for _,entry in ipairs(additions) do compileSource(path(entry[1])..'.'..entry[3],entry[4]) end
for _,object in ipairs(dependencySources) do compileSource(path(object),object.Source) end
if #issues>0 then staging:Destroy();stopPreflight() end
local changes={}
for _,entry in ipairs(edits) do if entry[1].Source~=entry[2] then table.insert(changes,entry) end end
local missing=false
for _,entry in ipairs(additions) do if not entry[5] then missing=true end end
local previewsComplete=originalPreviews and #originalPreviews:GetChildren()==worldCount
if previewsComplete then for _,model in ipairs(originalLibrary:GetChildren()) do if model:IsA('Model') then
 local preview=originalPreviews:FindFirstChild(model.Name)
 if not preview or not preview:IsA('Model') then previewsComplete=false;break end
end end end
if worldComplete and shopsComplete and previewsComplete and #changes==0 and not missing and workspace:GetAttribute('HussExpansionVersion')==12 then
 staging:Destroy()
 for _,message in ipairs(notes) do print('[V12] '..message) end
 print('V12 already installed: source compatibility, dependencies and Luau syntax verified. No systems duplicated; maps left unchanged.')
 return
end
local backup=Instance.new('Folder');backup.Name='ExpansionV12Backup_'..os.time()
while storage:FindFirstChild(backup.Name) do backup.Name..='_' end
local sourceBackups=Instance.new('Folder');sourceBackups.Name='Scripts';sourceBackups.Parent=backup
local worldBackups=Instance.new('Folder');worldBackups.Name='World';worldBackups.Parent=backup
local originals,newObjects,moved={},{},{}
local built,newPreviews,newArena,chosen,newLobby
local oldChosen=workspace:GetAttribute('CurrentVotedMap')
local oldVersion=workspace:GetAttribute('HussExpansionVersion')
local ok,err=pcall(function()
 for _,entry in ipairs(changes) do
  local object=entry[1];assert(object.Archivable,path(object)..' must be Archivable so it can be backed up.')
  originals[object]=object.Source
  local copy=object:Clone();assert(copy,'Unable to back up '..path(object));copy.Parent=sourceBackups
  copy:SetAttribute('OriginalPath',path(object))
  if copy:IsA('BaseScript') then copy:SetAttribute('OriginalDisabled',copy.Disabled);copy.Disabled=true end
 end
 for _,entry in ipairs(additions) do if not entry[5] then
  local object=Instance.new(entry[2]);object.Name=entry[3];object.Parent=staging;object.Source=entry[4]
  if object:IsA('BaseScript') then object.Disabled=false end
  assert(object.Source==entry[4],'Source write/read verification failed for '..entry[3]);table.insert(newObjects,{object,entry[1]})
 end end
 if not worldComplete then
  built=worldBuilder.Build(originalLibrary,originalLobby)
  assert(built and built.Library and built.Lobby,'World generator returned no staged world.')
  built.Library.Parent=staging;built.Lobby.Parent=staging
  -- Keep already upgraded new arenas intact in partially installed places.
  for _,name in ipairs({'Fuseworks','Detonator Plaza','Payload Port'}) do
   local existing=originalLibrary:FindFirstChild(name)
   if existing and existing:GetAttribute('BombTagGenerated')=='HussWorld11' then
    local generated=built.Library:FindFirstChild(name);if generated then generated:Destroy() end
    local copy=existing:Clone();assert(copy,'Unable to preserve '..name);copy.Parent=built.Library
   end
  end
 end
 if built then newLobby=built.Lobby
 elseif not shopsComplete then newLobby=originalLobby:Clone();assert(newLobby,'Cannot clone the lobby for its shop upgrade.');newLobby.Parent=staging end
 if newLobby then shopBuilder.Apply(newLobby);assert(shopBuilder.Validate(newLobby),'Shop stand validation failed after staging.') end
 local library=built and built.Library or originalLibrary
 if built or not previewsComplete then
  newPreviews=Instance.new('Folder');newPreviews.Name='BombTagV6Previews';newPreviews.Parent=staging
  local mapCount=0
  for _,map in ipairs(library:GetChildren()) do if map:IsA('Model') then
   mapCount+=1
   assert(map:FindFirstChild('Floor') and map:FindFirstChild('Spawns') and #map.Spawns:GetChildren()>=16,'Incomplete map: '..map.Name)
   local preview=map:Clone();assert(preview,'Map preview cannot be cloned.');preview.Parent=newPreviews
   for _,object in ipairs(preview:GetDescendants()) do
    if object.Name=='Spawns' or object:IsA('LuaSourceContainer') or object:IsA('SurfaceGui') or object:IsA('Light') or (object:IsA('BasePart') and object.Transparency>=1) then object:Destroy() end
   end
  end end
  assert(mapCount>=15,'Expected fifteen completed maps.')
 end
 if built then
  local template=library:FindFirstChild(oldChosen or '') or library:FindFirstChild(originalArena:GetAttribute('VotedMap') or '') or library:FindFirstChild('Sky Garden')
  assert(template,'Unable to select the existing active map.');chosen=template.Name;newArena=template:Clone();assert(newArena,'Cannot clone active arena');newArena.Parent=staging;newArena.Name=originalArena.Name
  local floor=newArena.Floor;newArena:PivotTo(newArena:GetPivot()+anchor.Position-(floor.Position+Vector3.new(0,floor.Size.Y/2,0)))
  newArena:SetAttribute('DisplayName',chosen);newArena:SetAttribute('VotedMap',chosen)
  local empty=Instance.new('Folder');empty.Parent=staging
  local placement=placementBuilder.Plan(built.Lobby,library,empty,anchor);placementBuilder.Apply(placement);empty:Destroy()
 end
 local manifest={'V12 compatibility backup','ServerMain: '..path(main),'','RESTORE SOURCES (copies under Scripts; each has OriginalPath):'}
 for _,entry in ipairs(changes) do table.insert(manifest,path(entry[1])) end
 table.insert(manifest,'');table.insert(manifest,'ADDED SYSTEMS (remove only these objects when undoing this install):')
 for _,entry in ipairs(newObjects) do table.insert(manifest,path(entry[2])..'.'..entry[1].Name) end
 table.insert(manifest,'');table.insert(manifest,'ARCHIVED WORLD OBJECTS (move originals under World back to these locations):')
 if built then for _,object in ipairs({originalLibrary,originalArena}) do table.insert(manifest,path(object)) end end
 if newLobby then table.insert(manifest,path(originalLobby)) end
 if newPreviews and originalPreviews then table.insert(manifest,path(originalPreviews)) end
 if newPreviews and not originalPreviews then table.insert(manifest,'Added preview folder: '..path(replicated)..'.BombTagV6Previews') end
 table.insert(manifest,'');table.insert(manifest,'Restore Workspace attributes from OriginalCurrentVotedMap and OriginalExpansionVersion on this backup folder. A missing attribute means remove it.')
 local record=Instance.new('StringValue');record.Name='RestoreManifest';record.Value=table.concat(manifest,'\n');record.Parent=backup
 backup:SetAttribute('OriginalCurrentVotedMap',oldChosen);backup:SetAttribute('OriginalExpansionVersion',oldVersion)
 backup:SetAttribute('Installer','V12 compatibility installer');backup:SetAttribute('ServerMainPath',path(main))
end)
if not ok then
 if built and built.Library then built.Library:Destroy() end
 if newLobby then newLobby:Destroy() elseif built and built.Lobby then built.Lobby:Destroy() end
 staging:Destroy();backup:Destroy();error('V12 staging stopped; originals preserved: '..tostring(err),0)
end
local function archive(object)
 if object then table.insert(moved,{object,object.Parent});object.Parent=worldBackups end
end
ok,err=pcall(function()
 backup.Parent=storage
 for _,entry in ipairs(newObjects) do entry[1].Parent=entry[2] end
 for _,entry in ipairs(changes) do entry[1].Source=entry[2];assert(entry[1].Source==entry[2],'Source write failed: '..path(entry[1])) end
 if built then
  archive(originalLibrary);archive(originalArena)
  built.Library.Parent=storage;newArena.Parent=maps
  workspace:SetAttribute('CurrentVotedMap',chosen)
 end
 if newLobby then archive(originalLobby);newLobby.Parent=workspace end
 if newPreviews then archive(originalPreviews);newPreviews.Parent=replicated end
 workspace:SetAttribute('HussExpansionVersion',12)
end)
if not ok then
 local failures={}
 local function restore(fn) local success,message=pcall(fn);if not success then table.insert(failures,tostring(message)) end end
 for _,entry in ipairs(newObjects) do restore(function() entry[1]:Destroy() end) end
 if built then restore(function() built.Library:Destroy() end) end
 if newLobby then restore(function() newLobby:Destroy() end) end
 if newPreviews then restore(function() newPreviews:Destroy() end) end
 if newArena then restore(function() newArena:Destroy() end) end
 for i=#moved,1,-1 do local pair=moved[i];restore(function() pair[1].Parent=pair[2] end) end
 for object,source in pairs(originals) do restore(function() object.Source=source end) end
 restore(function() workspace:SetAttribute('CurrentVotedMap',oldChosen);workspace:SetAttribute('HussExpansionVersion',oldVersion) end)
 staging:Destroy()
 if #failures==0 then backup:Destroy();error('V12 installation rolled back: '..tostring(err)..'. Originals restored.',0) end
 error('V12 stopped. Restore from ServerStorage/'..backup.Name..'. Restore errors: '..table.concat(failures,'; ')..'. Original error: '..tostring(err),0)
end
staging:Destroy()
for _,message in ipairs(notes) do print('[V12] '..message) end
print('V12 installed: compatible source, dependency and Luau syntax checks passed. Gameplay, voting, AFK, movement and HUD callbacks retained.')
print('Owner grants, walk-up lobby shops, smooth bomb transfers, panic carrier effects, and 25 rebuilt bomb skins installed. Solo practice awards no Coins or persistent progress; Studio progression is temporary.')
print('Backup: ServerStorage/'..backup.Name..'. Save a new place copy, then playtest with one and two players.')
