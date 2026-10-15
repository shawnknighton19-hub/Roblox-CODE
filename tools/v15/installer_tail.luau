local priorVersion=workspace:GetAttribute('HABPolishVersion')
if priorVersion~=nil and priorVersion~=15 then problem('Workspace.HABPolishVersion is an unknown version: '..tostring(priorVersion)) end
local objects,edits,additions,disables,compileObjects={},{},{},{},{}
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
   local text=try(entry.path..' source read',function() return object.Source end)
   if type(text)=='string' then
    local actual=canonical(text)
    local valid=actual==canonical(entry.target or entry.old) or (entry.old and actual==canonical(entry.old))
    if entry.config then
     local why;valid,why=ConfigAdapter.Compatible(canonical(entry.target),actual)
     if not valid then problem(entry.path..': '..tostring(why)) end
    elseif not valid then problem(entry.path..': source differs from both the uploaded HABWAS version and this V15 update. Preserve custom edits and review compatibility.') end
    if valid then
     if entry.target and not entry.config and actual~=canonical(entry.target) then edits[#edits+1]={object=object,target=entry.target} end
     compileObjects[#compileObjects+1]={path=entry.path,text=entry.target and not entry.config and entry.target or text}
    end
   end
   if object:IsA('BaseScript') then
    if entry.disable then
     if object.Disabled~=true then disables[#disables+1]=object end
    elseif object.Disabled~=entry.disabled then problem(entry.path..': unexpected Disabled setting; its controller ownership must be reviewed.') end
   end
  end
 elseif entry.add then
  local parentPath=entry.path:match('^(.*)/[^/]+$');local parent=find(parentPath)
  if parent then
   local name=entry.path:match('[^/]+$')
   additions[#additions+1]={parent=parent,name=name,class=entry.class,target=entry.target}
   compileObjects[#compileObjects+1]={path=entry.path,text=entry.target}
  end
 end
end
-- ServerMain in this uploaded place lives INSIDE Services; reject competing boot scripts.
local mainCount=0
for _,o in ipairs(Server:GetDescendants()) do if o.Name=='ServerMain' and o:IsA('LuaSourceContainer') then
 mainCount+=1
 if o~=objects['ServerScriptService/Services/ServerMain'] then problem('Unexpected ServerMain at '..full(o)) end
end end
if mainCount~=1 then problem('Expected exactly one ServerMain inside ServerScriptService/Services, found '..mainCount) end
-- ProcessReceipt is a single authoritative callback. Unknown owners require integration.
local knownReceipt=objects['ServerScriptService/Services/HABGemPurchases']
for _,root in ipairs({Server,Replicated,workspace}) do
 for _,o in ipairs(root:GetDescendants()) do
  if o:IsA('LuaSourceContainer') and o~=knownReceipt and (not o:IsA('BaseScript') or not o.Disabled) then
   local text=try(full(o)..' receipt ownership read',function() return o.Source end)
   if text and (text:find('%.%s*ProcessReceipt%s*=') or text:find('%[%s*[\'\"]ProcessReceipt[\'\"]%s*%]%s*=')) then
    problem('Another possible ProcessReceipt owner exists at '..full(o)..'. Integrate this callback before installing; it will not be overwritten.')
   end
  end
 end
end
local lobby=find('Workspace/Lobby')
local lobbyPlan=lobby and try('Lobby compatibility',function() return LobbyBuilder.Plan(lobby) end)
local library=find('ServerStorage/MapLibrary');local maps=find('Workspace/Maps')
if library then
 local names,count={},0
 for _,o in ipairs(library:GetChildren()) do if o:IsA('Model') then
  if names[o.Name] then problem('Duplicate vote map '..o.Name) end;names[o.Name]=true;count+=1
  if not o:FindFirstChild('Spawns') or not o:FindFirstChild('Floor') then problem('Vote map '..o.Name..' is missing Floor or Spawns') end
 end end
 if count==0 then problem('MapLibrary contains no maps; no replacement maps will be guessed.') end
end
if maps and #maps:GetChildren()==0 then problem('Workspace/Maps is empty; retain the uploaded active arena.') end
stop()
local staging=Instance.new('Folder');staging.Name='HABPolishV15Preflight'
while Storage:FindFirstChild(staging.Name) do staging.Name..='_' end
staging.Parent=Storage
for _,entry in ipairs(compileObjects) do
 local probe=Instance.new('ModuleScript');probe.Name='SyntaxProbe';probe.Parent=staging
 local ok,err=pcall(function()
  local wrapper='return function()\n'..entry.text..'\nend\n'
  probe.Source=wrapper;assert(probe.Source==wrapper,'Source readback mismatch')
  -- Require returns an uncalled function. Gameplay, saving and purchases never execute.
  assert(type(require(probe))=='function','Unexpected syntax-probe return value')
 end)
 probe:Destroy()
 if not ok then problem(entry.path..': Luau compile failed: '..tostring(err)) end
end
if #issues>0 then staging:Destroy();stop() end
local rebuildLobby=lobbyPlan and (#lobbyPlan.Move>0 or not lobbyPlan.Previous or #lobbyPlan.LabelChanges>0)
if #edits==0 and #additions==0 and #disables==0 and not rebuildLobby and priorVersion==15 then
 staging:Destroy()
 print('V15 already installed. Source compatibility, dependencies and Luau syntax verified. No duplicate systems or backups created; configured purchase IDs preserved.')
 return
end
local backup=Instance.new('Folder');backup.Name='HABPolishV15Backup_'..os.time()
while Storage:FindFirstChild(backup.Name) do backup.Name..='_' end
local scriptBackups=Instance.new('Folder');scriptBackups.Name='Scripts';scriptBackups.Parent=backup
local worldBackups=Instance.new('Folder');worldBackups.Name='LobbyArchitecture';worldBackups.Parent=backup
local originals,created={},{}
local function remember(o)
 if originals[o] then return end
 assert(o.Archivable,full(o)..' must be Archivable before creating a backup')
 local old={source=o.Source,disabled=o:IsA('BaseScript') and o.Disabled or nil}
 if o:IsA('BaseScript') then old.disabled=o.Disabled end
 originals[o]=old
 local copy=assert(o:Clone(),'Cannot clone '..full(o));copy.Name=tostring(#scriptBackups:GetChildren()+1)..'_'..o.Name
 copy:SetAttribute('OriginalPath',full(o))
 if copy:IsA('BaseScript') then copy:SetAttribute('OriginalDisabled',o.Disabled);copy.Disabled=true end
 copy.Parent=scriptBackups
end
local ok,err=pcall(function()
 for _,entry in ipairs(edits) do remember(entry.object) end
 for _,o in ipairs(disables) do remember(o) end
 for _,entry in ipairs(additions) do
  local o=Instance.new(entry.class);o.Name=entry.name;o.Source=entry.target;o.Parent=staging
  assert(o.Source==entry.target,'New module source readback failed for '..entry.name)
  created[#created+1]={object=o,parent=entry.parent}
 end
 backup:SetAttribute('OriginalPolishVersion',priorVersion)
 backup:SetAttribute('Installer','HAB V15 polish for uploaded HABWAS')
 local lines={'V15 installation backup. Do not run scripts in this backup.','',
 'Restore each Scripts copy Source to OriginalPath; restore OriginalDisabled on Scripts/LocalScripts.',
 'Remove the added modules listed below. Delete Workspace/Lobby/HABPolishedLobbyV15 and reparent archived models from LobbyArchitecture back to Workspace/Lobby.',
 'Restore sign text using LobbyArchitecture/LobbySignTextV15: each StringValue holds the original text and its OriginalPath.',
 'Restore Workspace.HABPolishVersion to OriginalPolishVersion on this folder; absence means remove the attribute.',
 'No save data, map templates, avatar configuration or lighting was rewritten.','', 'ADDED MODULES:'}
 for _,e in ipairs(created) do lines[#lines+1]=full(e.parent)..'.'..e.object.Name end
 local record=Instance.new('StringValue');record.Name='RestoreManifest';record.Value=table.concat(lines,'\n');record.Parent=backup
end)
if not ok then staging:Destroy();backup:Destroy();error('V15 staging failed; existing game preserved: '..tostring(err),0) end
local lobbyResult
ok,err=pcall(function()
 backup.Parent=Storage
 for _,entry in ipairs(created) do entry.object.Parent=entry.parent;assert(entry.object.Parent==entry.parent,'Module parent commit failed') end
 for _,entry in ipairs(edits) do entry.object.Source=entry.target;assert(entry.object.Source==entry.target,'Source write/readback failed: '..full(entry.object)) end
 for _,o in ipairs(disables) do o.Disabled=true;assert(o.Disabled,'Legacy script disable failed: '..full(o)) end
 if rebuildLobby then local model;model,lobbyResult=LobbyBuilder.Apply(lobby,worldBackups);assert(model.Parent==lobby,'Lobby commit failed') end
 workspace:SetAttribute('HABPolishVersion',15)
 assert(workspace:GetAttribute('HABPolishVersion')==15,'Version marker readback failed')
end)
if not ok then
 local failures={}
 local function restore(label,fn) local success,message=pcall(fn);if not success then failures[#failures+1]=label..': '..tostring(message) end end
 if lobbyResult then restore('Lobby',lobbyResult.Undo) end
 -- Check the complete world journal even when the builder itself threw during rollback.
 -- A failed inner rollback must never lead to deleting the only surviving originals.
 if rebuildLobby then
  for _,o in ipairs(lobbyPlan.Move) do restore('Lobby model '..o.Name,function() o.Parent=lobby;assert(o.Parent==lobby,'Parent restoration failed') end) end
  for _,entry in ipairs(lobbyPlan.LabelChanges) do restore('Lobby sign '..entry.Path,function() entry.Label.Text=entry.Old;assert(entry.Label.Text==entry.Old,'Text restoration failed') end) end
  if lobbyPlan.Previous then restore('Previous lobby polish',function() lobbyPlan.Previous.Parent=lobby;assert(lobbyPlan.Previous.Parent==lobby,'Previous lobby restoration failed') end) end
  for _,o in ipairs(lobby:GetChildren()) do
   if o.Name=='HABPolishedLobbyV15' and o~=lobbyPlan.Previous then restore('Staged lobby geometry',function() o:Destroy() end) end
  end
 end
 for _,entry in ipairs(created) do restore(entry.object.Name,function() entry.object:Destroy() end) end
 for o,old in pairs(originals) do restore(full(o),function()
  o.Source=old.source;assert(o.Source==old.source,'Source restoration readback failed')
  if old.disabled~=nil then o.Disabled=old.disabled;assert(o.Disabled==old.disabled,'Disabled restoration failed') end
 end) end
 restore('Version marker',function() workspace:SetAttribute('HABPolishVersion',priorVersion) end)
 staging:Destroy()
 if #failures==0 then backup:Destroy();error('V15 installation rolled back; originals restored. '..tostring(err),0) end
 error('V15 installation stopped. Backup retained at ServerStorage/'..backup.Name..'. Restore errors: '..table.concat(failures,'; ')..'. Initial error: '..tostring(err),0)
end
staging:Destroy()
print('V15 installed. Source compatibility, dependencies, Luau syntax and commit readbacks passed.')
print('Backup: ServerStorage/'..backup.Name..'. Save the place, then test solo practice and a two-player round before publishing.')
print('Official offers: enter your Roblox IDs in ReplicatedStorage/HABMonetizationConfigV15. Zero-ID offers remain unavailable. Existing saves and practice reward exclusion are preserved.')
