local starter=unique(starterRoot,'StarterPlayerScripts','StarterPlayerScripts',false)
local characters=unique(starterRoot,'StarterCharacterScripts','StarterCharacterScripts',false)
local services=unique(server,'Services','Folder',false)
local main=unique(server,'ServerMain','Script',true)
local hud=unique(starter,'HudController','ModuleScript',true)
local round=unique(services,'RoundService','ModuleScript',false)
local bomb=unique(services,'BombService','ModuleScript',false)
local economy=unique(services,'EconomyServiceV9','ModuleScript',false)
local movement=unique(starter,'SnappyMovement','LocalScript',true)
local effects=unique(starter,'MovementEffectsV8','LocalScript',true)
local library=unique(storage,'MapLibrary','Folder',false)
local lobby=unique(workspace,'Lobby','Model',false)
local maps=unique(workspace,'Maps','Folder',false)
local anchor=unique(workspace,'ActiveArenaAnchor','BasePart',false)
local arena
if maps then for _,o in ipairs(maps:GetChildren()) do if o:IsA('Model') then
 if arena then problem('Workspace.Maps has multiple active arenas; the V12 world must have one active arena.') end
 arena=o
end end end
if not arena then problem('Workspace.Maps has no active arena Model.') end
if workspace:GetAttribute('HussExpansionVersion')~=12 then problem('This update requires the completed V12 installation (Workspace.HussExpansionVersion = 12). Run the V12 installer first; existing scripts were preserved.') end
local priorVersion=workspace:GetAttribute('HussTrailAnimationVersion')
if priorVersion~=nil and priorVersion~=13 then problem('Unknown HussTrailAnimationVersion '..tostring(priorVersion)..'; a newer or custom update will not be overwritten.') end
local priorDodge=workspace:GetAttribute('HussDodgeV5')
if priorDodge~=nil and type(priorDodge)~='boolean' then problem('Workspace.HussDodgeV5 must be a boolean or absent; its custom value was preserved.') end
local compileObjects,edits,additions={},{},{}
local seenCompile={}
local function compileLater(object)
 if object and not seenCompile[object] then seenCompile[object]=true;table.insert(compileObjects,object) end
end
local function enabled(object)
 if object and object:IsA('BaseScript') and object.Disabled then problem(path(object)..' is disabled. Its existing disabled setting will not be overwritten.') end
end
local function verify(object,expected)
 if not object then return end
 local readable,actual=pcall(function() return object.Source end)
 if not readable then problem(path(object)..': Source is not readable.')
 elseif canonical(actual)~=canonical(expected) then problem(path(object)..' differs from the reviewed V12 source; compatibility must be checked before replacing dependencies.') end
 enabled(object);compileLater(object)
end
for _,pair in ipairs({{main,'ServerMain'},{round,'RoundService'},{bomb,'BombService'},{economy,'EconomyServiceV9'},{movement,'SnappyMovement'},{effects,'MovementEffectsV8'}}) do verify(pair[1],preservedSource[pair[2]]) end
for _,entry in ipairs({
 {replicated,'BombSkinBuilderV12','ModuleScript'},
 {services,'CosmeticsServiceV11','ModuleScript'},
 {services,'OwnerCommandsV12','ModuleScript'},
 {services,'PracticeServiceV11','ModuleScript'},
 {services,'PerfectWeaveServiceV11','ModuleScript'},
 {starter,'OwnerFeedbackV12','LocalScript'},
 {starter,'CarrierPanicV12','LocalScript'},
 {starter,'LobbyBoardsV11','LocalScript'},
 {starter,'DodgeActionV6','LocalScript'},
}) do
 local object=unique(entry[1],entry[2],entry[3],true)
 -- These reviewed V12 services/controllers live directly in their designated folder.
 if object and object.Parent~=entry[1] then problem(path(object)..' is in an unexpected container; expected '..path(entry[1])..'.') end
 verify(object,preservedSource[entry[2]])
end
local function upgrade(parent,name,class,old,target,recursive,mayAdd)
 local object=unique(parent,name,class,true,mayAdd)
 if object then
  local actual=attempt(path(object)..' Source',function() return canonical(object.Source) end)
  if actual and actual~=canonical(target) and (not old or actual~=canonical(old)) then
   problem(path(object)..' has unsupported or customized source. It will not be replaced.')
  else table.insert(edits,{object,target}) end
  if object.Parent~=parent and not recursive then problem(path(object)..' is in an unexpected container.') end
  enabled(object)
 elseif mayAdd and parent then table.insert(additions,{parent,class,name,target}) end
 return object
end
if hud then
 local actual=attempt(path(hud)..' Source',function() return canonical(hud.Source) end)
 if actual~=canonical(source.oldHUD) and actual~=canonical(source.hud) then problem(path(hud)..' is not the verified V12/V13 HUD. Existing customizations were preserved.')
 else table.insert(edits,{hud,source.hud}) end
end
upgrade(replicated,'HussCatalogV11','ModuleScript',source.oldCatalog,source.catalog,false,false)
upgrade(starter,'CollectionEffectsV11','LocalScript',source.oldCollection,source.collection,false,false)
upgrade(starter,'StandShopV12','LocalScript',source.oldShop,source.shop,false,false)
-- Search recursively before adding a system so a misplaced copy never gets duplicated.
for _,entry in ipairs({
 {replicated,'HussTrailDesignsV13','ModuleScript',source.trails},
 {services,'AnimationRuntimeV13','Script',source.animationRuntime,server},
}) do
 local object=unique(entry[5] or entry[1],entry[2],entry[3],true,true)
 if object then
  if object.Parent~=entry[1] then problem(path(object)..' is in an unexpected container; no second copy will be installed.') end
  verify(object,entry[4])
 else if entry[1] then table.insert(additions,{entry[1],entry[3],entry[2],entry[4]}) end end
end
local animate=unique(characters,'Animate','LocalScript',true,true)
if animate then
 if animate.Parent~=characters then problem(path(animate)..' must be directly under StarterCharacterScripts; its current location was preserved.') end
 enabled(animate)
 local adapted=attempt(path(animate)..' compatibility',function() return animationAdapter.Adapt(animate.Source,source.animate) end)
 if type(adapted)=='string' then table.insert(edits,{animate,adapted}) end
 if animationAdapter.ValidateChildren then attempt(path(animate)..' animation configuration',function() return animationAdapter.ValidateChildren(animate) end) end
elseif characters then table.insert(additions,{characters,'LocalScript','Animate',source.animate}) end
if characters then for _,object in ipairs(characters:GetDescendants()) do
 if object~=animate and object:IsA('LocalScript') and not object.Disabled then
  local text=attempt(path(object)..' Source',function() return object.Source end)
  if type(text)=='string' and (text:find('LoadAnimation',1,true) or text:find('Motor6D',1,true) or text:find('Animator',1,true)) then
   problem(path(object)..' is another enabled character animation controller. Resolve its ownership before installing this Animate repair; it was not disabled or overwritten.')
  end
 end
end end
-- Reject an alternative character template: it can override the experience's R6 setting.
local starterCharacter=unique(starterRoot,'StarterCharacter','Model',false,true)
if starterCharacter then problem(path(starterCharacter)..' is a custom character template. Its rig and animation setup require review before this standard-avatar repair can be installed.') end
local validation=attempt('Existing gameplay dependencies',function()
 return dependencyValidator.Validate({server=server,replicated=replicated,storage=storage,starter=starter,services=services,main=main,round=round,bomb=bomb,hud=hud,movement=movement,effects=effects,library=library,lobby=lobby,maps=maps,anchor=anchor,economy=economy})
end)
if type(validation)=='table' then
 for _,message in ipairs(validation.issues or {}) do problem(message) end
 for _,object in ipairs(validation.sources or {}) do compileLater(object) end
end
local function validateArena(model)
 if not model then return end
 unique(model,'Floor','BasePart',false)
 local spawns=unique(model,'Spawns','Folder',false)
 if spawns then local count=0;for _,object in ipairs(spawns:GetChildren()) do if object:IsA('BasePart') then count+=1 end end
  if count<16 then problem(path(spawns)..' requires sixteen or more existing spawn parts; found '..count..'.') end
 end
end
validateArena(arena)
if library then
 local count,names=0,{}
 for _,model in ipairs(library:GetChildren()) do
  if names[model.Name] then problem('Duplicate existing map name: '..model.Name) end;names[model.Name]=true
  if model:IsA('Model') then count+=1;validateArena(model) end
 end
 if count<15 then problem('V12 MapLibrary requires the existing fifteen maps; found '..count..'. This update never rebuilds missing geometry.') end
end
if lobby then
 unique(lobby,'Floor','BasePart',false);unique(lobby,'LobbySpawn','SpawnLocation',false)
 if lobby:GetAttribute('HussLobbyVersion')~=11 then problem(path(lobby)..' must be the existing V11 lobby with V12 shops.') end
 attempt('Existing lobby walk-up shops',function() assert(shopValidator.Validate(lobby),'V12 shop validation failed.') end)
end
stopPreflight()
note('ServerMain preserved at '..path(main)..'. Economy, practice gates, voting, AFK, movement and bomb gameplay verified.')
note('All existing maps, lobby stands, lighting and world geometry remain in place.')
local staging=Instance.new('Folder');staging.Name='TrailAnimationV13Preflight_'..os.time()
while storage:FindFirstChild(staging.Name) do staging.Name..='_' end
staging.Parent=storage
local function compileSource(label,text)
 -- This outer return only compiles the body; it never runs gameplay modules.
 local probe=Instance.new('ModuleScript');probe.Name='SyntaxProbe';probe.Parent=staging
 local ok,message=pcall(function()
  probe.Source='return function()\n'..text..'\nend\n'
  assert(probe.Source=='return function()\n'..text..'\nend\n','Source write/read verification failed')
  assert(type(require(probe))=='function','Syntax probe returned unexpected content')
 end)
 probe:Destroy()
 if not ok then problem(label..': Luau syntax check failed: '..tostring(message)) end
end
for _,entry in ipairs(edits) do compileSource(path(entry[1]),entry[2]) end
for _,entry in ipairs(additions) do compileSource(path(entry[1])..'.'..entry[3],entry[4]) end
for _,object in ipairs(compileObjects) do compileSource(path(object),object.Source) end
if #issues>0 then staging:Destroy();stopPreflight() end
local changes={}
for _,entry in ipairs(edits) do if entry[1].Source~=entry[2] then table.insert(changes,entry) end end
if #changes==0 and #additions==0 and priorVersion==13 and priorDodge==true then
 staging:Destroy()
 for _,message in ipairs(notes) do print('[V13] '..message) end
 print('V13 already installed: source compatibility, dependencies and Luau syntax verified. No duplicate systems or backups created.')
 r6Reminder();return
end
local backup=Instance.new('Folder');backup.Name='TrailAnimationV13Backup_'..os.time()
while storage:FindFirstChild(backup.Name) do backup.Name..='_' end
local sourceBackups=Instance.new('Folder');sourceBackups.Name='Scripts';sourceBackups.Parent=backup
local originals,newObjects={},{}
local ok,err=pcall(function()
 for _,entry in ipairs(changes) do
  local object=entry[1];assert(object.Archivable,path(object)..' must be Archivable so it can be backed up.')
  originals[object]=object.Source
  local copy=object:Clone();assert(copy,'Unable to back up '..path(object));copy.Parent=sourceBackups
  copy:SetAttribute('OriginalPath',path(object))
  if copy:IsA('BaseScript') then copy:SetAttribute('OriginalDisabled',copy.Disabled);copy.Disabled=true end
 end
 for _,entry in ipairs(additions) do
  local object=Instance.new(entry[2]);object.Name=entry[3];object.Parent=staging;object.Source=entry[4]
  if object:IsA('BaseScript') then object.Disabled=false end
  assert(object.Source==entry[4],'Source write/read verification failed for '..entry[3]);table.insert(newObjects,{object,entry[1]})
 end
 local manifest={'V13 movement animation and trail update backup','ServerMain: '..path(main),'','RESTORE SOURCES: copies under Scripts have OriginalPath and OriginalDisabled. Copy Source back to the same existing instance; do not run backup copies.'}
 for _,entry in ipairs(changes) do table.insert(manifest,path(entry[1])) end
 table.insert(manifest,'');table.insert(manifest,'ADDED SYSTEMS: remove only these objects to undo this update:')
 for _,entry in ipairs(newObjects) do table.insert(manifest,path(entry[2])..'.'..entry[1].Name) end
 table.insert(manifest,'');table.insert(manifest,'Restore Workspace.HussTrailAnimationVersion from OriginalTrailAnimationVersion on this backup folder. Missing means remove the Workspace attribute. HussExpansionVersion stays 12.')
 table.insert(manifest,'Restore Workspace.HussDodgeV5 from OriginalDodgeV5Enabled on this backup folder. Missing means remove the attribute. V13 enables the exact source-verified procedural dodge animation controller; speed and cooldown are unchanged.')
 table.insert(manifest,'No maps, lobby geometry, player saves, economy rules or rig/avatar settings were changed by this installer.')
 local record=Instance.new('StringValue');record.Name='RestoreManifest';record.Value=table.concat(manifest,'\n');record.Parent=backup
 backup:SetAttribute('OriginalTrailAnimationVersion',priorVersion);backup:SetAttribute('OriginalDodgeV5Enabled',priorDodge);backup:SetAttribute('Installer','V13 movement animation and trail installer');backup:SetAttribute('ServerMainPath',path(main))
end)
if not ok then staging:Destroy();backup:Destroy();error('V13 staging stopped; originals preserved: '..tostring(err),0) end
ok,err=pcall(function()
 backup.Parent=storage
 for _,entry in ipairs(newObjects) do entry[1].Parent=entry[2] end
 for _,entry in ipairs(changes) do entry[1].Source=entry[2];assert(entry[1].Source==entry[2],'Source write failed: '..path(entry[1])) end
 workspace:SetAttribute('HussDodgeV5',true)
 workspace:SetAttribute('HussTrailAnimationVersion',13)
end)
if not ok then
 local failures={}
 local function restore(fn) local success,message=pcall(fn);if not success then table.insert(failures,tostring(message)) end end
 for _,entry in ipairs(newObjects) do restore(function() entry[1]:Destroy() end) end
 for object,text in pairs(originals) do restore(function() object.Source=text;assert(object.Source==text,'Source restoration readback failed: '..path(object)) end) end
 restore(function() workspace:SetAttribute('HussTrailAnimationVersion',priorVersion) end)
 restore(function() workspace:SetAttribute('HussDodgeV5',priorDodge) end)
 staging:Destroy()
 if #failures==0 then backup:Destroy();error('V13 installation rolled back: '..tostring(err)..'. Originals restored.',0) end
 error('V13 stopped. Restore from ServerStorage/'..backup.Name..'. Restore errors: '..table.concat(failures,'; ')..'. Original error: '..tostring(err),0)
end
staging:Destroy()
for _,message in ipairs(notes) do print('[V13] '..message) end
print('V13 scripts installed: source compatibility, dependencies and Luau syntax checks passed. Twenty-five trail designs, collection previews and animation repair installed.')
print('Backup: ServerStorage/'..backup.Name..'. Practice still awards no Coins, persistent stats or quest progress. Publish after the REQUIRED avatar step below.')
r6Reminder()
