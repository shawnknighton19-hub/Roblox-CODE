-- Geometry transaction only. All gameplay controllers keep their original paths.
local W={Version=16}
local roots={
 {Path='ServerStorage/MapLibrary',Name='MapLibrary',Kind='library'},
 {Path='ReplicatedStorage/BombTagV6Previews',Name='BombTagV6Previews',Kind='previews'},
 {Path='ReplicatedStorage/BombTagPreviewGalleryV5',Name='BombTagPreviewGalleryV5',Kind='legacy'},
 {Path='Workspace/Maps',Name='Maps',Kind='active'},
}
local legacyNames={'Sky Garden','Sunset Docks','Neon District','Crystal Cavern'}
local function one(parent,name)
 local found
 for _,o in ipairs(parent:GetChildren()) do if o.Name==name then assert(not found,'Duplicate '..parent:GetFullName()..'/'..name);found=o end end
 assert(found,'Missing '..parent:GetFullName()..'/'..name);return found
end
local function path(name)
 local parts=string.split(name,'/');local o=game:GetService(parts[1])
 for i=2,#parts do o=one(o,parts[i]) end
 return o
end
local function close(a,b)
 local aa,bb={a:GetComponents()},{b:GetComponents()}
 for i=1,12 do if math.abs(aa[i]-bb[i])>.002 then return false end end
 return true
end
local function geometryOnly(root)
 for _,o in ipairs(root:GetDescendants()) do
  assert(not o:IsA('LuaSourceContainer'),'Unexpected script inside archived geometry: '..o:GetFullName())
 end
end
local function catalogNames()
 local names={}
 for _,entry in ipairs(Maps.Catalog) do assert(not names[entry.Name],'Duplicate map catalog entry');names[entry.Name]=true end
 return names
end
local function validateMap(model,installed,playable)
 assert(model:IsA('Model'),'Expected arena Model: '..model:GetFullName())
 if installed then
  assert(model:GetAttribute('HABMapVersion')==16 and model:GetAttribute('HABWorldVersion')==16,'Unknown map version at '..model:GetFullName())
  assert(model:GetAttribute('NoJumpRequired')==true,'Missing no-jump route contract at '..model:GetFullName())
 end
 if playable or installed then
  local floor=one(model,'Floor');local spawns=one(model,'Spawns')
  assert(floor:IsA('BasePart') and floor.Anchored,'Invalid arena Floor: '..model:GetFullName())
  if installed then
   -- Floor is the invisible voting/pivot reference; polygon tiles provide the
   -- playable collision so each arena can have a different outline.
   local ground=0
   for _,o in ipairs(model:GetDescendants()) do if o:IsA('BasePart') and o:GetAttribute('HABGroundV16')==true and o.Anchored and o.CanCollide then ground+=1 end end
   assert(ground>0,'V16 arena has no solid foundation: '..model:GetFullName())
  end
  assert(model.PrimaryPart==floor,'Arena PrimaryPart must remain Floor: '..model:GetFullName())
  assert(spawns:IsA('Folder'),'Arena Spawns must be a Folder: '..model:GetFullName())
  local children=spawns:GetChildren();assert(#children>=2,'Arena has too few spawns: '..model:GetFullName())
  if installed then assert(#children==16,'V16 arena must have sixteen spawn markers: '..model:GetFullName()) end
  local names={}
  for _,o in ipairs(children) do
   assert(o:IsA('BasePart') and o.Anchored and not names[o.Name],'Invalid or duplicate spawn in '..model:GetFullName());names[o.Name]=true
   if installed then assert(o:GetAttribute('HABSpawnV16')==true,'Missing V16 spawn marker at '..o:GetFullName()) end
  end
 end
end
local function validateRoot(folder,kind,installed,activeName)
 assert(folder:IsA('Folder'),'Expected map Folder: '..folder:GetFullName());geometryOnly(folder)
 assert((folder:GetAttribute('HABWorldVersion')==16)==installed,'Mixed original/V16 world at '..folder:GetFullName()..'; restore a complete backup first')
 local wanted=kind=='legacy' and {} or catalogNames()
 if kind=='legacy' then for _,name in ipairs(legacyNames) do wanted[name]=true end end
 if kind=='active' then wanted={[activeName]=true} end
 for _,model in ipairs(folder:GetChildren()) do
  assert(wanted[model.Name],'Unexpected or duplicate map '..model:GetFullName());wanted[model.Name]=nil
  validateMap(model,installed,kind=='library' or kind=='active')
  if not installed and (kind=='library' or kind=='previews' or kind=='active') then
   assert(model:GetAttribute('BombTagGenerated')=='HussWorld11','Unrecognized original arena at '..model:GetFullName())
  end
 end
 for name in pairs(wanted) do error('Missing map '..folder:GetFullName()..'/'..name) end
end
function W.Plan(version)
 assert(version==nil or version==16,'V16 requires the original HABWAS place or this V16 update')
 local lobby=path('Workspace/Lobby');local anchor=path('Workspace/ActiveArenaAnchor')
 local lobbyPlan=Lobby.Plan(lobby,anchor)
 local installed=version==16
 assert((lobbyPlan.Previous~=nil)==installed,'Lobby/version marker disagree; restore a complete original or V16 backup first')
 local active=path('Workspace/Maps');local children=active:GetChildren()
 assert(#children==1 and children[1]:IsA('Model'),'Workspace/Maps must contain one active arena')
 local activeModel=children[1]
 local voted=activeModel:GetAttribute('VotedMap') or activeModel:GetAttribute('DisplayName')
 assert(catalogNames()[voted],'Active arena has an unknown VotedMap')
 assert(workspace:GetAttribute('CurrentVotedMap')==voted,'CurrentVotedMap disagrees with active arena')
 local out={Installed=installed,Lobby=lobby,LobbyPlan=lobbyPlan,Anchor=anchor,Roots={},ActiveName=activeModel.Name,VotedMap=voted}
 for _,entry in ipairs(roots) do
  local o=path(entry.Path);validateRoot(o,entry.Kind,installed,out.ActiveName)
  table.insert(out.Roots,{Object=o,Parent=o.Parent,Path=entry.Path,Name=entry.Name,Kind=entry.Kind})
 end
 local floor=one(activeModel,'Floor')
 local top=floor.Position+Vector3.new(0,floor.Size.Y/2,0)
 assert((top-anchor.Position).Magnitude<.01,'Active arena Floor does not match ActiveArenaAnchor')
 geometryOnly(lobby)
 for _,move in ipairs(lobbyPlan.Moves) do
  assert(move.Model.Archivable,'Booth must be Archivable: '..move.Path)
  for _,o in ipairs(move.Model:GetDescendants()) do assert(o.Archivable,'Booth descendant must be Archivable: '..o:GetFullName()) end
 end
 assert(lobby.Archivable,'Lobby must be Archivable for an independent backup')
 for _,o in ipairs(lobby:GetDescendants()) do assert(o.Archivable,'Lobby descendant must be Archivable: '..o:GetFullName()) end
 out.Changed=not installed or #lobbyPlan.Moves>0 or #lobbyPlan.Archives>0 or #lobbyPlan.Texts>0
 return out
end
function W.Stage(plan,staging)
 local state={Plan=plan,Staging=staging,NewRoots={},NewLobby=nil,Undo=nil}
 if not plan.Changed then return state end
 if not plan.Installed then
  local archive=Maps.BuildArchive({MapName=plan.ActiveName,VotedMap=plan.VotedMap,Anchor=Vector3.new(0,-27,-190)})
  archive.Parent=staging;state.Archive=archive
  assert(#archive:GetChildren()==#roots,'Map builder returned an incomplete archive')
  for _,entry in ipairs(plan.Roots) do
   local o=one(archive,entry.Name);validateRoot(o,entry.Kind,true,plan.ActiveName)
   table.insert(state.NewRoots,{Object=o,Parent=entry.Parent,Original=entry.Object,Path=entry.Path})
  end
 end
 -- Exercise geometry construction while no originals have been touched.
 local preview=Lobby.Build(nil);preview.Parent=staging
 assert(preview.Name=='HABLobbyLayoutV16' and preview:GetAttribute('HABLobbyLayoutVersion')==16,'Lobby builder returned an unknown root')
 geometryOnly(preview);preview:Destroy()
 return state
end
function W.Backup(state,folder)
 if not state.Plan.Changed then return end
 state.Backup=folder
 local plan=state.Plan;local lp=plan.LobbyPlan
 local maps=Instance.new('Folder');maps.Name='OriginalMapRoots';maps.Parent=folder;state.MapBackup=maps
 local architecture=Instance.new('Folder');architecture.Name='LobbyArchitecture';architecture.Parent=folder;state.LobbyBackup=architecture
 local recovery=Instance.new('Folder');recovery.Name='IndependentLobbyRecovery';recovery.Parent=folder
 local copy=assert(plan.Lobby:Clone(),'Cannot clone original lobby');copy.Name='OriginalLobby';copy.Parent=recovery
 copy:SetAttribute('OriginalPath','Workspace/Lobby')
 local saved=Instance.new('CFrameValue');saved.Name='OriginalActiveArenaAnchor';saved.Value=plan.Anchor.CFrame;saved.Parent=recovery
 -- This separate journal is captured before Lobby.Apply. Its recovery does not
 -- depend on that builder reaching its return or finishing its own Undo.
 local journal={Parents={},Parts={},Pivots={},Attributes={},Texts={},Anchor=plan.Anchor.CFrame,Previous=lp.Previous}
 state.Journal=journal
 for _,o in ipairs(lp.Archives) do table.insert(journal.Parents,{o,o.Parent}) end
 if lp.Previous then table.insert(journal.Parents,{lp.Previous,lp.Previous.Parent}) end
 for _,row in ipairs(lp.Texts) do table.insert(journal.Texts,{row.Label,row.Label.Text}) end
 for _,move in ipairs(lp.Moves) do
  local all={move.Model};for _,o in ipairs(move.Model:GetDescendants()) do table.insert(all,o) end
  for _,o in ipairs(all) do
   if o:IsA('BasePart') then table.insert(journal.Parts,{o,o.CFrame})
   elseif o:IsA('Model') then table.insert(journal.Pivots,{o,o.WorldPivot}) end
   for name,value in pairs(o:GetAttributes()) do if typeof(value)=='CFrame' then table.insert(journal.Attributes,{o,name,value}) end end
  end
 end
end
function W.Apply(state)
 if not state.Plan.Changed then return end
 assert(state.Journal and state.Backup:IsDescendantOf(game:GetService('ServerStorage')),'World backup must be complete before commit')
 for _,row in ipairs(state.NewRoots) do
  row.Original.Parent=state.MapBackup;assert(row.Original.Parent==state.MapBackup,'Cannot archive '..row.Path)
  row.Object.Parent=row.Parent;assert(row.Object.Parent==row.Parent,'Cannot install '..row.Path)
 end
 local newLobby,result=Lobby.Apply(state.Plan.Lobby,state.LobbyBackup,state.Plan.Anchor)
 state.NewLobby=newLobby;state.Undo=result and result.Undo
 assert(newLobby.Parent==state.Plan.Lobby,'Lobby parent readback failed')
end
function W.Verify(state)
 local plan=state.Plan
 local lp=Lobby.Plan(plan.Lobby,plan.Anchor)
 assert(lp.Previous and #lp.Moves==0 and #lp.Archives==0 and #lp.Texts==0,'Lobby commit did not reach its target layout')
 for _,entry in ipairs(plan.Roots) do validateRoot(path(entry.Path),entry.Kind,true,plan.ActiveName) end
 local floor=one(one(path('Workspace/Maps'),plan.ActiveName),'Floor')
 assert((floor.Position+Vector3.new(0,floor.Size.Y/2,0)-plan.Anchor.Position).Magnitude<.01,'Installed arena does not align with viewing anchor')
 assert(workspace:GetAttribute('CurrentVotedMap')==plan.VotedMap,'Map selection was unexpectedly changed')
end
function W.Rollback(state)
 local failures={}
 local function restore(label,fn)
  local ok,message=pcall(fn);if not ok then table.insert(failures,label..': '..tostring(message)) end
 end
 if state.Undo then pcall(state.Undo) end -- independent restoration below is authoritative
 local journal=state.Journal
 if journal then
  for _,row in ipairs(journal.Parts) do restore(row[1].Name..' CFrame',function() row[1].CFrame=row[2];assert(close(row[1].CFrame,row[2]),'readback failed') end) end
  for _,row in ipairs(journal.Pivots) do restore(row[1].Name..' pivot',function() row[1].WorldPivot=row[2];assert(close(row[1].WorldPivot,row[2]),'readback failed') end) end
  for _,row in ipairs(journal.Attributes) do restore(row[1].Name..' attribute '..row[2],function() row[1]:SetAttribute(row[2],row[3]);assert(close(row[1]:GetAttribute(row[2]),row[3]),'readback failed') end) end
  for _,row in ipairs(journal.Texts) do restore(row[1].Name..' text',function() row[1].Text=row[2];assert(row[1].Text==row[2],'readback failed') end) end
  restore('ActiveArenaAnchor',function() state.Plan.Anchor.CFrame=journal.Anchor;assert(close(state.Plan.Anchor.CFrame,journal.Anchor),'readback failed') end)
  for _,row in ipairs(journal.Parents) do restore(row[1].Name..' parent',function() row[1].Parent=row[2];assert(row[1].Parent==row[2],'readback failed') end) end
  for _,o in ipairs(state.Plan.Lobby:GetChildren()) do
   if o.Name=='HABLobbyLayoutV16' and o~=journal.Previous then restore('New lobby root',function() o:Destroy();assert(o.Parent==nil,'delete readback failed') end) end
  end
 end
 for _,row in ipairs(state.NewRoots) do
  restore(row.Path..' original',function() row.Original.Parent=row.Parent;assert(row.Original.Parent==row.Parent,'readback failed') end)
  restore(row.Path..' new geometry',function() row.Object:Destroy();assert(row.Object.Parent==nil,'delete readback failed') end)
 end
 return failures
end
return W
