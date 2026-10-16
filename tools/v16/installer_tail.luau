local priorVersion=workspace:GetAttribute('HABPolishVersion')
if priorVersion~=nil and priorVersion~=16 then problem('Workspace.HABPolishVersion='..tostring(priorVersion)..'. V16 starts from the uploaded HABWAS place; open that original or restore its complete backup.') end
for _,name in ipairs({'HABMonetizationConfigV15','HABModalV15','HABUILayoutV15','HABActionAnimationsV15','HABAbilityEffectsV15','HABCleanCosmeticsV15'}) do
 for _,o in ipairs(Replicated:GetDescendants()) do if o.Name==name then problem('Rejected V15 runtime '..full(o)..'; this installer uses the original HABWAS gameplay and UI.') end end
end
local objects,edits,additions,compileObjects={},{},{},{}
for _,entry in ipairs(entries) do
 local object=find(entry.path,entry.add)
 if entry.add then
  local name=entry.path:match('[^/]+$')
  for _,other in ipairs(Replicated:GetDescendants()) do
   if other.Name==name and other~=object then problem(entry.path..': another copy exists at '..full(other)) end
  end
 end
 if object then
  objects[entry.path]=object
  if object.ClassName~=entry.class then problem(entry.path..': expected '..entry.class..', found '..object.ClassName)
  else
   local source=try(entry.path..' source read',function() return object.Source end)
   if type(source)=='string' then
    local actual=canonical(source)
    local oldMatches=entry.old and actual==canonical(entry.old)
    local targetMatches=entry.target and actual==canonical(entry.target)
    if not oldMatches and not targetMatches then
     problem(entry.path..': source differs from both the actual uploaded HABWAS script and this V16 update. Custom edits were preserved; review them before installing.')
    else
     if entry.target and not targetMatches then table.insert(edits,{object=object,target=entry.target,path=entry.path}) end
     table.insert(compileObjects,{path=entry.path,text=entry.target or source})
    end
   end
   if object:IsA('BaseScript') and object.Disabled~=entry.disabled then problem(entry.path..': unexpected Disabled state; controller ownership requires review.') end
  end
 elseif entry.add then
  local parent=find(entry.path:match('^(.*)/[^/]+$'))
  if parent then
   table.insert(additions,{parent=parent,name=entry.path:match('[^/]+$'),class=entry.class,target=entry.target,path=entry.path})
   table.insert(compileObjects,{path=entry.path,text=entry.target})
  end
 end
end
-- The supplied place's only bootstrap is INSIDE Services. Do not create another.
local mainCount=0
for _,o in ipairs(Server:GetDescendants()) do
 if o.Name=='ServerMain' and o:IsA('LuaSourceContainer') then
  mainCount+=1
  if o~=objects['ServerScriptService/Services/ServerMain'] then problem('Competing ServerMain at '..full(o)) end
 end
end
if mainCount~=1 then problem('Expected exactly one ServerMain at ServerScriptService/Services/ServerMain; found '..mainCount) end
local worldPlan=try('World compatibility',function() return World.Plan(priorVersion) end)
stop()
local staging=Instance.new('Folder');staging.Name='HABPolishV16Preflight'
while Storage:FindFirstChild(staging.Name) do staging.Name..='_' end
staging.Parent=Storage
for _,entry in ipairs(compileObjects) do
 local probe=Instance.new('ModuleScript');probe.Name='SyntaxProbe';probe.Parent=staging
 local ok,err=pcall(function()
  local wrapper='return function()\n'..entry.text..'\nend\n'
  probe.Source=wrapper;assert(probe.Source==wrapper,'Source readback mismatch')
  -- Parsing occurs, but the returned function is never called. No live module,
  -- purchase handler, profile writer, animation or gameplay service runs here.
  assert(type(require(probe))=='function','Unexpected syntax-probe result')
 end)
 probe:Destroy()
 if not ok then problem(entry.path..': Luau syntax probe failed: '..tostring(err)) end
end
if #issues>0 then staging:Destroy();stop() end
if #edits==0 and #additions==0 and not worldPlan.Changed and priorVersion==16 then
 local ok,err=pcall(function() World.Verify({Plan=worldPlan}) end)
 staging:Destroy()
 if not ok then error('V16 validation stopped; existing game preserved: '..tostring(err),0) end
 print('V16 already installed. Sources, dependencies, map structure and Luau syntax verified. No duplicate systems, geometry or backups created.')
 return
end
local backup=Instance.new('Folder');backup.Name='HABPolishV16Backup_'..os.time()
while Storage:FindFirstChild(backup.Name) do backup.Name..='_' end
local originals,created={},{}
local worldState
local ok,err=pcall(function()
 local scripts=Instance.new('Folder');scripts.Name='Scripts';scripts.Parent=backup
 local world=Instance.new('Folder');world.Name='World';world.Parent=backup
 for _,entry in ipairs(edits) do
  local o=entry.object;assert(o.Archivable,entry.path..' must be Archivable for a source backup')
  local old={source=o.Source,disabled=nil};if o:IsA('BaseScript') then old.disabled=o.Disabled end
  originals[o]=old
  local copy=assert(o:Clone(),'Cannot clone '..entry.path);copy.Name=tostring(#scripts:GetChildren()+1)..'_'..o.Name
  copy:SetAttribute('OriginalPath',entry.path)
  if copy:IsA('BaseScript') then copy:SetAttribute('OriginalDisabled',o.Disabled);copy.Disabled=true end
  copy.Parent=scripts
 end
 for _,entry in ipairs(additions) do
  local o=Instance.new(entry.class);o.Name=entry.name;o.Source=entry.target;o.Parent=staging
  assert(o.Source==entry.target,'New module source readback failed: '..entry.path)
  table.insert(created,{object=o,parent=entry.parent,path=entry.path})
 end
 worldState=World.Stage(worldPlan,staging)
 World.Backup(worldState,world)
 backup:SetAttribute('OriginalPolishVersion',priorVersion)
 backup:SetAttribute('Installer','HAB V16 for original HABWAS')
 backup:SetAttribute('OriginalUploadSHA256','c354d8c3c7ac43b9364749aa292716aa592eee6f496f532c98c0bafb88279309')
 local lines={'V16 stopped-Studio installation backup. Do not run archived scripts.','',
  'Restore each Scripts copy Source to its OriginalPath and OriginalDisabled state.',
  'World/OriginalMapRoots: move MapLibrary to ServerStorage; Maps to Workspace; BombTagV6Previews and BombTagPreviewGalleryV5 to ReplicatedStorage. Remove the corresponding new roots first.',
  'World/IndependentLobbyRecovery/OriginalLobby is a complete original lobby clone. It can replace Workspace/Lobby for manual disaster recovery.',
  'World/LobbyArchitecture retains archived originals, original booth clones and the builder transform journal. The independent lobby clone preserves full original properties.',
  'Restore Workspace/ActiveArenaAnchor.CFrame from World/IndependentLobbyRecovery/OriginalActiveArenaAnchor.',
  'Restore Workspace.HABPolishVersion from OriginalPolishVersion on this backup; no attribute means remove it.',
  'Original round, bomb and movement rules are unchanged. Reviewed changes protect economy startup and block retired effect purchases; saved profile data is not rewritten.',
  '', 'ADDED MODULES (remove during full manual restore):'}
 for _,row in ipairs(created) do table.insert(lines,row.path) end
 local record=Instance.new('StringValue');record.Name='RestoreManifest';record.Value=table.concat(lines,'\n');record.Parent=backup
end)
if not ok then
 staging:Destroy();backup:Destroy()
 error('V16 staging failed; original scripts and world were not modified: '..tostring(err),0)
end
ok,err=pcall(function()
 backup.Parent=Storage;assert(backup.Parent==Storage,'Backup parent commit failed')
 for _,row in ipairs(created) do row.object.Parent=row.parent;assert(row.object.Parent==row.parent,'Module parent commit failed: '..row.path) end
 for _,entry in ipairs(edits) do entry.object.Source=entry.target;assert(entry.object.Source==entry.target,'Source write/readback failed: '..entry.path) end
 World.Apply(worldState)
 World.Verify(worldState)
 workspace:SetAttribute('HABPolishVersion',16)
 assert(workspace:GetAttribute('HABPolishVersion')==16,'Version marker readback failed')
end)
if not ok then
 local failures={}
 local function restore(label,fn)
  local success,message=pcall(fn);if not success then table.insert(failures,label..': '..tostring(message)) end
 end
 local restored,worldFailures=pcall(function() return World.Rollback(worldState) end)
 if restored then for _,message in ipairs(worldFailures) do table.insert(failures,message) end
 else table.insert(failures,'World recovery journal: '..tostring(worldFailures)) end
 for _,row in ipairs(created) do restore(row.path,function() row.object:Destroy();assert(row.object.Parent==nil,'Removal readback failed') end) end
 for o,old in pairs(originals) do restore(full(o),function()
  o.Source=old.source;assert(o.Source==old.source,'Source restoration readback failed')
  if old.disabled~=nil then o.Disabled=old.disabled;assert(o.Disabled==old.disabled,'Disabled restoration readback failed') end
 end) end
 restore('Version marker',function() workspace:SetAttribute('HABPolishVersion',priorVersion);assert(workspace:GetAttribute('HABPolishVersion')==priorVersion,'Version restoration readback failed') end)
 restore('Preflight cleanup',function() staging:Destroy() end)
 if #failures==0 then
  backup:Destroy()
  error('V16 installation rolled back; original scripts, world objects and properties restored. Initial error: '..tostring(err),0)
 end
 -- Never delete originals when even one recovery operation cannot be verified.
 local saved,saveError=pcall(function() backup.Parent=Storage end)
 error('V16 installation stopped. Backup retained at ServerStorage/'..backup.Name..(saved and '' or ' (backup parent failure: '..tostring(saveError)..')')..'. Restore errors: '..table.concat(failures,'; ')..'. Initial error: '..tostring(err),0)
end
staging:Destroy()
print('V16 installed. Original/target source compatibility, dependencies, Luau syntax, world validation and commit readbacks passed.')
print('Backup: ServerStorage/'..backup.Name..'. Original GUI and gameplay are preserved. Fifteen replacement maps, spectator lobby, ability poses and new weave are installed.')
print('Save a separate copy, then test solo practice and two-player rounds in Studio before publishing. Native animation playback and physics still require that playtest.')
