local assertions=0
local function check(value,message) assertions+=1;assert(value,message) end
local function state(p) return runtimeExports.states[p or owner] end
local function allocated(n,message) check(runtimeExports.allocated()==n,message);check(liveTrails==n,'adapter and runtime allocation agree') end
beat();allocated(3,'initial three sprinting players')
check(state().trail.id=='default','Classic Wake renders its sculpted default design')
check(state().title~=nil,'titles preserved')
local ownerTrail=state().trail.handle
local baselineInstances=nextID
for n=1,12 do owner.Character.HumanoidRootPart.CFrame=CFrame.new(n*.5,3,0);beat(1/60) end
local visibleParts=0
for _,part in ipairs(ownerTrail.Model:GetDescendants()) do if part:IsA('BasePart') and part.Transparency<1 then visibleParts+=1 end end
check(visibleParts>0,'real travelled path displays actual sculpted motifs')
for n=1,180 do beat(1/60) end
check(state().trail.handle==ownerTrail,'continuous sprint reuses pool')
check(trailCreates==3,'no geometry allocation per frame')
check(nextID==baselineInstances,'actual sculpted trail Step creates no Instances')
check(ownerTrail.StepCount>=180,'pool animated each heartbeat')
local remotes={observer,r15}
for n=1,12 do table.insert(remotes,added('Remote'..n,5+n)) end
beat();allocated(10,'ten visible characters maximum')
check(state().trail~=nil,'local character always has its reserved slot')
local rendered=0
for _,p in ipairs(remotes) do if state(p).trail then rendered+=1 end end
check(rendered==9,'nine remote characters maximum')
local furthest=remotes[#remotes]
check(state(furthest).trail==nil,'distant candidate culled first')
furthest.Character.HumanoidRootPart.CFrame=CFrame.new(.25,3,0);beat()
check(state(furthest).trail~=nil,'closest candidate replaces far trail')
for n=1,8 do owner.Character.HumanoidRootPart.CFrame+=Vector3.new(.5,0,0);beat(1/60) end
owner.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.new(24,0,0);beat()
check(state().trail and not state().trail.handle.Enabled,'walk stops new motifs while existing wake fades')
beat(.38)
check(state().trail~=nil,'stop fade completes before pool cleanup')
local visibleAfterFade=0
for _,part in ipairs(state().trail.handle.Model:GetDescendants()) do if part:IsA('BasePart') and part.Transparency<1 then visibleAfterFade+=1 end end
check(visibleAfterFade==0,'all motifs finish fading before runtime destroys pool')
beat(.1);allocated(9,'local idle reserves no extra remote slot')
check(state().trail==nil,'walk fade grace releases geometry')
owner.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.new(32,0,0);beat();allocated(10,'local sprint retakes reserved slot')
local previous=state().trail.handle
for n=1,100 do
 owner.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.new(n%2==0 and 28 or 26,0,0);beat(.02)
end
check(state().trail.handle==previous,'threshold jitter reuses allocated pool')
owner.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.new(32,0,0)
local trailIds={}
for _,item in ipairs(catalog.Items) do if item.category=='Trails' then table.insert(trailIds,item.id) end end
check(#trailIds==25,'all 25 catalog trails covered')
for _,id in ipairs(trailIds) do
 local before=state().trail and state().trail.handle
 owner:SetAttribute('HussTrailId',id);beat()
 check(state().trail and state().trail.id==id,'equipped trail '..id)
 if before and before.id~=id then check(before.Destroyed,'old skin torn down immediately '..id) end
end
owner:SetAttribute('HussTrailId','nonexistent');beat()
check(state().trail.id=='default','invalid trail falls back to classic')
owner:SetAttribute('HussTrailId','bomb_classic');beat()
check(state().trail.id=='default','bomb ID cannot select trail design')
local function ownerBlocked(apply,undo,label)
 apply();beat();check(state().trail==nil,label..' removes trail immediately')
 undo();beat();check(state().trail~=nil,label..' can resume')
end
ownerBlocked(function() owner:SetAttribute('HussReducedMotion',true) end,function() owner:SetAttribute('HussReducedMotion',false) end,'local ReducedMotion')
ownerBlocked(function() workspace:SetAttribute('HussReducedMotion',true) end,function() workspace:SetAttribute('HussReducedMotion',false) end,'workspace ReducedMotion')
ownerBlocked(function() owner:SetAttribute('HussGamePaused',true) end,function() owner:SetAttribute('HussGamePaused',false) end,'player pause')
ownerBlocked(function() workspace:SetAttribute('HussGamePaused',true) end,function() workspace:SetAttribute('HussGamePaused',false) end,'game pause')
local h=owner.Character.Humanoid;local root=owner.Character.HumanoidRootPart;local c=owner.Character
ownerBlocked(function() h.Sit=true end,function() h.Sit=false end,'seated')
ownerBlocked(function() h.PlatformStand=true end,function() h.PlatformStand=false end,'platform stand')
ownerBlocked(function() root.Anchored=true end,function() root.Anchored=false end,'anchored')
ownerBlocked(function() h.FloorMaterial=Enum.Material.Air end,function() h.FloorMaterial=Enum.Material.Grass end,'airborne')
ownerBlocked(function() c:SetAttribute('Ragdolled',true) end,function() c:SetAttribute('Ragdolled',false) end,'ragdoll')
ownerBlocked(function() c:SetAttribute('IsRagdoll',true) end,function() c:SetAttribute('IsRagdoll',false) end,'alternate ragdoll')
ownerBlocked(function() root.AssemblyLinearVelocity=Vector3.new(101,0,0) end,function() root.AssemblyLinearVelocity=Vector3.new(32,0,0) end,'teleport speed')
ownerBlocked(function() workspace.CurrentCamera.CFrame=CFrame.new(500,0,0) end,function() workspace.CurrentCamera.CFrame=CFrame.new(0,8,8) end,'distance culling')
local cam=workspace.CurrentCamera
ownerBlocked(function() workspace.CurrentCamera=nil end,function() workspace.CurrentCamera=cam end,'missing camera')
ownerBlocked(function() c.Parent=nil end,function() c.Parent=workspace end,'streamed character')
ownerBlocked(function() root.Parent=nil end,function() root.Parent=c;c.DescendantAdded:Fire(root) end,'streamed root')
ownerBlocked(function() h.Parent=nil end,function() h.Parent=c;c.DescendantAdded:Fire(h) end,'streamed humanoid')
local originalHead=c.Head;local originalTitle=state().title
originalHead.Parent=nil;beat();check(state().title==nil,'streamed head clears old title')
check(originalTitle.Parent==nil,'old title instance destroyed')
local wrongHead=Instance.new('Folder',c);wrongHead.Name='Head';beat();check(state().title==nil,'nonpart head cannot become Adornee')
wrongHead:Destroy();originalHead.Parent=c;beat();check(state().title and state().title.Adornee==originalHead,'restored head receives title')
local function connectedCount()
 local count=0
 for _,signal in ipairs(allSignals) do for _,connection in ipairs(signal.list) do if connection.Connected then count+=1 end end end
 return count
end
local connections=connectedCount()
for n=1,20 do h.Parent=nil;beat();h.Parent=c;c.DescendantAdded:Fire(h);beat() end
check(connectedCount()==connections,'repeated humanoid streaming does not accumulate listeners')
local oldRoot=root
root.Parent=nil;beat();check(state().trail==nil,'old root is released before replacement')
root=Instance.new('Part',c);root.Name='HumanoidRootPart';root.Anchored=false;root.CFrame=oldRoot.CFrame;root.AssemblyLinearVelocity=Vector3.new(32,0,0)
c.DescendantAdded:Fire(root);beat()
check(state().root==root and state().trail~=nil,'streamed replacement root bound without CharacterAdded')
local oldCharacter=c;local oldTrail=state().trail.handle
owner.CharacterRemoving:Fire();check(oldTrail.Destroyed and state().character==nil,'removal clears old pool')
local replacement=readyPlayer(newCharacter('Replacement',false),0)
owner.Character=replacement.Character;c=owner.Character;h=c.Humanoid;root=c.HumanoidRootPart
owner.CharacterAdded:Fire(c);beat()
check(state().character==c and state().trail~=nil,'respawn binds replacement character')
check(state().trail.handle~=oldTrail,'respawn gets fresh trail state')
oldCharacter:SetAttribute('HussPerfectWeaveAt',clock)
check(state().burst==nil,'removed character signals disconnected')
root.AssemblyLinearVelocity=Vector3.zero;h.MoveDirection=Vector3.zero;beat(.5)
owner:SetAttribute('HussEmotePlaying','emote_wave');owner:SetAttribute('HussEmoteStarted',clock);beat(.2)
check(state().pose~=nil,'existing stationary emote still poses')
owner:SetAttribute('HussEmotePlaying',nil);beat()
check(state().pose==nil,'emote pose still restores')
c:SetAttribute('HussPerfectWeaveAt',clock)
check(state().burst~=nil,'perfect-weave highlight preserved')
local sounds=services.SoundService:GetChildren();local plays=0
for _,s in ipairs(sounds) do plays+=(s.Played or 0) end
check(plays==2,'perfect-weave sound cue preserved')
beat(.4);check(state().burst==nil,'perfect-weave highlight expires')
owner:SetAttribute('HussSFXMuted',true);c:SetAttribute('HussPerfectWeaveAt',clock)
local mutedPlays=0;for _,s in ipairs(sounds) do mutedPlays+=(s.Played or 0) end
check(mutedPlays==plays,'mute preference preserved')
owner:SetAttribute('HussSFXMuted',false)
root.AssemblyLinearVelocity=Vector3.new(32,0,0);h.MoveDirection=Vector3.new(1,0,0);beat()
check(state().trail~=nil,'sprint resumes after emote')
h.Health=0;h.Died:Fire();check(state().trail==nil and state().character==nil,'death clears trail and character state')
local departing=remotes[1];local departureHandle=state(departing).trail and state(departing).trail.handle
playerService.PlayerRemoving:Fire(departing)
check(runtimeExports.states[departing]==nil,'player departure removes state')
if departureHandle then check(departureHandle.Destroyed,'departure releases geometry') end
script.Destroying:Fire();allocated(0,'script teardown releases every geometry pool')
check(#runtimeExports.folder:GetChildren()==0 and runtimeExports.folder.Parent==nil,'private effects folder destroyed')
check(#services.SoundService:GetChildren()==0,'sounds destroyed')
check(next(runtimeExports.states)==nil,'all player state removed')
local before=trailCreates;beat();script.Destroying:Fire();check(trailCreates==before,'repeated teardown and later heartbeat cannot allocate')
local liveConnections=0
for _,signal in ipairs(allSignals) do for _,link in ipairs(signal.list) do if link.Connected then liveConnections+=1 end end end
check(liveConnections==0,'all owned connections disconnected')
check(trailCreates==trailDestroys,'every allocated trail destroyed exactly once')
print('V13 trail runtime: '..assertions..' assertions passed; lifecycle, 25 skins, streaming, priority, cleanup, preserved emotes and cues.')
