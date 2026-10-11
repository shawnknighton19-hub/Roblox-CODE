-- HUSS A BOMB V7: SIMPLER LOBBY, REAL MUSIC, SHIFT-LOCK DODGE
-- Requires V6. Stop Play, paste this whole block, save, then Play.
-- Optional: put approved Roblox audio IDs between these quotes. Blank keeps your existing IDs.
local MUSIC={Lobby='',Chase='',Duel=''}
local run=game:GetService('RunService')
assert(run:IsStudio() and not run:IsRunning(),'Stop Play before installing.')
local scripts=game:GetService('StarterPlayer').StarterPlayerScripts
local controllers=scripts:FindFirstChild('Controllers')
local hud=controllers and controllers:FindFirstChild('HudController')
local movement=scripts:FindFirstChild('SnappyMovement')
local shiftlock=scripts:FindFirstChild('ForcedShiftLock')
local audio=scripts:FindFirstChild('GameAudioV6')
local oldLobby=workspace:FindFirstChild('Lobby')
local oldSpawn=oldLobby and oldLobby:FindFirstChild('LobbySpawn')
assert(hud and hud:IsA('ModuleScript') and movement and movement:IsA('LocalScript') and shiftlock and shiftlock:IsA('LocalScript') and audio and audio:IsA('LocalScript'),'Install the previous V6 update first. Nothing changed.')
assert(hud.Source:find('-- HussAudioV6',1,true) and movement.Source:find('-- HussActionV6',1,true) and audio.Source:find('-- HUSS A BOMB V6.',1,true),'V6 script signatures are missing. Nothing changed.')
assert(oldLobby and oldLobby:IsA('Model') and oldSpawn and oldSpawn:IsA('SpawnLocation'),'Workspace.Lobby.LobbySpawn must be a SpawnLocation. Nothing changed.')
local musicIds={}
for _,scene in ipairs({'Lobby','Chase','Duel'}) do
 local value=MUSIC[scene]
 if type(value)=='number' then
  assert(value==value and value>0 and value<=9007199254740991 and value%1==0,'Invalid '..scene..' music ID. Nothing changed.')
  value=string.format('%.0f',value)
 end
 assert(type(value)=='string','Music IDs must be numbers or text. Nothing changed.')
 value=value:match('^%s*(.-)%s*$')
 if value~='' then
  local digits=value:match('^rbxassetid://(%d+)$') or value:match('^(%d+)$')
  local n=digits and tonumber(digits)
  assert(n and n>0 and n<=9007199254740991 and n%1==0,'Invalid '..scene..' music ID. Nothing changed.')
  musicIds['Huss'..scene..'MusicId']='rbxassetid://'..digits
 end
end

local patchHUD=(function()
-- Keep the existing settings and adjust the description for full-track music.
return function(source)
 local old='Original lobby music, a faster chase arrangement, and responsive game sounds. Adjust each layer below.'
 local new='Control the soundtrack and game sounds separately. Adjust each layer below.'
 if source:find(new,1,true) then return source end
 local a,b=source:find(old,1,true)
 assert(a,'The V6 HUD audio settings are missing. Nothing changed.')
 return source:sub(1,a-1)..new..source:sub(b+1)
end

end)()

local patchShiftLock=(function()
-- V7: one facing owner. Shift lock aims; SnappyMovement supplies translation.
local Patch={}
local marker='-- HussShiftLockV7'
local function replace(source,old,new,label)
 local a,b=source:find(old,1,true)
 assert(a and not source:find(old,b+1,true),'Unexpected '..label..'. Nothing changed.')
 return source:sub(1,a-1)..new..source:sub(b+1)
end
function Patch.Movement(source)
 assert(source:find('-- HussActionV6',1,true) and source:find('DIVE_COOLDOWN = 1.5',1,true),'Install the V6 movement update first. Nothing changed.')
 if source:find(marker,1,true) then
  assert(source:find('local function cameraOwnsFacing()',1,true),'Incomplete V7 movement update. Nothing changed.')
  return source
 end
 source=replace(source,'local function horizontal(',[[-- HussShiftLockV7: inspect the actual facing constraint, not a delayed flag.
local function cameraOwnsFacing()
 local lock=root and root:FindFirstChild('ForcedShiftLockOrientation')
 return lock~=nil and lock:IsA('AlignOrientation') and lock.Enabled
end

local function horizontal(]],'movement helper')
 source=replace(source,'local function faceDirection(\n\tdirection,\n\tdt\n)\n',[[local function faceDirection(
	direction,
	dt
)
 if cameraOwnsFacing() then return end
]],'dodge facing')
 source=replace(source,'if humanoid.Health <= 0 then',[[if humanoid.Health <= 0 or humanoid.PlatformStand or humanoid.Sit
  or character:GetAttribute('Ragdolled')==true or character:GetAttribute('IsRagdoll')==true
  or player:GetAttribute('HussGamePaused')==true or workspace:GetAttribute('HussGamePaused')==true
  or humanoid:GetState()==Enum.HumanoidStateType.Physics
  or humanoid:GetState()==Enum.HumanoidStateType.Ragdoll
  or humanoid:GetState()==Enum.HumanoidStateType.Seated then]],'movement lock gate')
 local count
 source,count=source:gsub('humanoid%.AutoRotate =%s*true','humanoid.AutoRotate = not cameraOwnsFacing()')
 assert(count==2,'Unexpected AutoRotate assignments. Nothing changed.')
 return source
end
function Patch.ShiftLock(source)
 if source:find(marker,1,true) then
  assert(source:find('updateCharacterRotation=function()',1,true) and source:find('local owns=shouldUseShiftLock()',1,true),'Incomplete V7 shift lock update. Nothing changed.')
  return source
 end
 assert(source:find('if movementState == "Dive" then',1,true) and source:find('local function shouldUseShiftLock()',1,true),'ForcedShiftLock differs from the supplied game. Nothing changed.')
 local first=source:find('local function updateCharacterRotation()',1,true)
 local last=first and source:find('------------------------------------------------------------\n-- ROUND TRANSITION',first+1,true)
 assert(first and last,'Shift lock rotation section is missing. Nothing changed.')
 local rotation=[[updateCharacterRotation=function()
 -- HussShiftLockV7: stay camera-facing during every directional dodge.
 if not humanoid or not root or not alignOrientation then return end
 local camera=workspace.CurrentCamera
 local mode=humanoid:GetState()
 local blocked=humanoid.Health<=0 or root.Anchored or humanoid.PlatformStand or humanoid.Sit
  or character:GetAttribute('Ragdolled')==true or character:GetAttribute('IsRagdoll')==true
  or player:GetAttribute('HussGamePaused')==true or workspace:GetAttribute('HussGamePaused')==true
  or mode==Enum.HumanoidStateType.Dead or mode==Enum.HumanoidStateType.Ragdoll
  or mode==Enum.HumanoidStateType.Physics or mode==Enum.HumanoidStateType.Seated
 local owns=shouldUseShiftLock() and not blocked and camera~=nil
 if owns then
  local look=camera.CFrame.LookVector
  local flat=Vector3.new(look.X,0,look.Z)
  if flat.Magnitude>.001 then
   alignOrientation.CFrame=CFrame.lookAt(Vector3.zero,flat.Unit,Vector3.yAxis)
  elseif not alignOrientation.Enabled then
   local facing=root.CFrame.LookVector
   flat=Vector3.new(facing.X,0,facing.Z)
   if flat.Magnitude>.001 then alignOrientation.CFrame=CFrame.lookAt(Vector3.zero,flat.Unit,Vector3.yAxis)
   else owns=false end
  end
 end
 alignOrientation.Enabled=owns
 humanoid.AutoRotate=not owns and not blocked and character:GetAttribute('MovementState')~='Dive'
end
updateCharacterRotation()

]]
 source=source:sub(1,first-1)..rotation..source:sub(last)
 source=replace(source,'local function setupCharacter(','local updateCharacterRotation\nlocal function setupCharacter(','shift lock setup')
 source=replace(source,'\tcreateRotationSystem()\nend','\tcreateRotationSystem()\n if updateCharacterRotation then updateCharacterRotation() end\nend','shift lock respawn')
 source=source:gsub('SnappyMovement controls facing','Shift lock controls facing; SnappyMovement controls travel',1)
 return source
end
return Patch

end)()

local patchAudio=(function()
-- Replaces the V6 generated-note soundtrack with full audio tracks. SFX stay intact.
return function(source)
 local marker='-- HussMusicV7: full tracks only; final duel reuses Chase when unset.'
 assert(type(source)=='string' and source:find('-- HUSS A BOMB V6.',1,true),'GameAudioV6 source differs. Nothing changed.')
 if source:find(marker,1,true) then
  assert(source:find("if name=='Duel' then return readMusicId('Chase') end",1,true) and not source:find('local progression=',1,true),'Partial V7 audio update found. Nothing changed.')
  return source
 end
 local function replace(old,new)
  local first,last=source:find(old,1,true)
  assert(first and not source:find(old,last+1,true),'Audio source differs at '..old:sub(1,45)..'. Nothing changed.')
  source=source:sub(1,first-1)..new..source:sub(last+1)
 end
 local first=source:find('local function configured(name)',1,true)
 local last=first and source:find('local function updateScene()',first+1,true)
 assert(first and last,'Audio track configuration differs. Nothing changed.')
 local config=[=[local function readMusicId(name)
 local value=workspace:GetAttribute('Huss'..name..'MusicId')
 if type(value)=='number' then
  if not finite(value) or value<=0 or value%1~=0 or value>9007199254740991 then return '' end
  value=string.format('%.0f',value)
 end
 if type(value)~='string' then return '' end
 local digits=value:match('^rbxassetid://(%d+)$') or value:match('^(%d+)$')
 local id=digits and tonumber(digits)
 return id and finite(id) and id>0 and id<=9007199254740991 and 'rbxassetid://'..digits or ''
end
local function configured(name)
 local id=readMusicId(name)
 if id~='' then return id end
 if name=='Duel' then return readMusicId('Chase') end
 return ''
end
]=]
 source=source:sub(1,first-1)..marker..'\n'..config..source:sub(last)
 replace("scene=nextScene;customId=id;sceneAt=os.clock();lastStep=-1",[=[scene=nextScene;root:SetAttribute('Scene',scene)
 if customId==id then return end -- Keep the same song playing across phase changes.
 customId=id;sceneAt=os.clock();lastStep=-1]=])
 first=source:find('local progression=',1,true)
 last=first and source:find('local actions=',first+1,true)
 assert(first and last,'Generated soundtrack section differs. Nothing changed.')
 source=source:sub(1,first-1)..source:sub(last)
 replace("for i=1,12 do musicVoices[i]={sound=sound(music),group=music,untilAt=0} end",'-- Music uses OwnedMusic; no synthetic note pool.')
 replace('updateScene();score(now)','updateScene()')
 return source
end

end)()

local buildLobby=(function()
--!nonstrict
-- V7: calmer courtyard; no-jump routes.
local B={}
local V,C,R,M=Vector3.new,CFrame.new,Color3.fromRGB,Enum.Material
local ink,stone,cream,wood=R(27,39,38),R(151,170,151),R(230,227,205),R(105,73,52)
local sage,leaf,lime,gold=R(97,131,107),R(57,99,71),R(180,248,126),R(225,187,104)
local data
local function group(p,n) local g=Instance.new('Model');g.Name=n;g.Parent=p;return g end
local function part(p,n,x,y,z,w,h,d,c,m,solid,rot,class)
 local o=Instance.new(class or 'Part');o.Name=n;o.Size=V(w,h,d);o.CFrame=C(x,y,z)*(rot or CFrame.identity)
 o.Color=c;o.Material=m or M.Limestone;o.Anchored=true;o.CanCollide=solid==true;o.CanTouch=false;o.CanQuery=o.CanCollide
 o.TopSurface=Enum.SurfaceType.Smooth;o.BottomSurface=Enum.SurfaceType.Smooth;o.Parent=p;return o
end
local function beam(p,n,a,b,w,h,c,solid)
 local q=(a+b)/2;return part(p,n,q.X,q.Y,q.Z,w,h,(b-a).Magnitude,c,M.Metal,solid,CFrame.lookAt(a,b).Rotation)
end
local function round(p,n,x,y,z,w,h,d,c,ball)
 local o=part(p,n,x,y,z,ball and w or h,ball and h or w,d,c,ball and M.Grass or M.Limestone,false,ball and CFrame.identity or CFrame.Angles(0,0,math.pi/2))
 o.Shape=ball and Enum.PartType.Ball or Enum.PartType.Cylinder;return o
end
local function label(p,title,sub,x,y,z,w,h,rot)
 local board=part(p,title,x,y,z,w,h,.4,ink,M.Metal,false,rot)
 local ui=Instance.new('SurfaceGui');ui.Face=Enum.NormalId.Back;ui.CanvasSize=Vector2.new(1000,300);ui.LightInfluence=.1;ui.Parent=board
 for i,t in ipairs({title,sub}) do
  local l=Instance.new('TextLabel');l.BackgroundTransparency=1;l.Size=UDim2.new(1,-40,0,i==1 and 140 or 82);l.Position=UDim2.fromOffset(20,i==1 and 26 or 177)
  l.Font=Enum.Font.GothamBold;l.Text=t;l.TextSize=i==1 and 66 or 33;l.TextColor3=i==1 and lime or cream;l.TextWrapped=true;l.Parent=ui
 end
end
local function pave(p,x,z,w,d,y)
 part(p,'Paving',x,y+.035,z,w,.05,d,cream)
end
local function rail(p,a,b)
 beam(p,'Smooth guard',a+V(0,1.8,0),b+V(0,1.8,0),.6,3.6,ink,true).Transparency=1
 beam(p,'Handrail',a+V(0,3.7,0),b+V(0,3.7,0),.4,.4,gold)
 beam(p,'Lower rail',a+V(0,1,0),b+V(0,1,0),.2,.2,ink)
 local n=math.ceil((b-a).Magnitude/16)
 for i=0,n do local q=a:Lerp(b,i/n);part(p,'Post',q.X,q.Y+1.8,q.Z,.4,3.6,.4,ink,M.Metal) end
end
local function bench(p,x,y,z,turn)
 local g=group(p,'Bench');local cf=C(x,y,z)*CFrame.Angles(0,turn or 0,0)
 local function b(n,px,py,pz,w,h,d,c,solid)
  local o=part(g,n,px,py,pz,w,h,d,c,M.WoodPlanks,solid);o.CFrame=cf*o.CFrame;return o
 end
 b('Smooth collision',0,1.25,0,9,2.5,3.2,wood,true).Transparency=1
 b('Seat',0,2.4,0,9,.35,3.2,wood)
 b('Back',0,3.3,-1.5,9,1.6,.3,wood)
 for _,s in ipairs({-1,1}) do b('Leg',s*3.5,1.1,0,.7,2.2,2.7,ink) end
end
local function lamp(p,x,y,z)
 part(p,'Lamp post',x,y+4,z,.45,8,.45,ink,M.Metal)
 local o=part(p,'Lantern',x,y+8,z,1.2,1.5,1.2,R(255,226,159),M.Neon)
 part(p,'Lantern cap',x,y+8.9,z,1.8,.3,1.8,ink,M.Metal)
 local light=Instance.new('PointLight');light.Color=R(255,226,172);light.Brightness=.6;light.Range=16;light.Shadows=false;light.Parent=o
end
local function garden(p,x,z,w,d,height)
 local g=group(p,'Garden')
 part(g,'Planter',x,1.35,z,w,2.7,d,stone,nil,true)
 part(g,'Coping',x,2.73,z,w+.3,.22,d+.3,cream)
 part(g,'Soil',x,2.87,z,w-1,.18,d-1,R(57,57,42),M.Ground)
 for i=-1,1 do round(g,'Hedge',x+i*(w-4)/3,3.9,z+d*.2,(w-2)/3,2.4,4,leaf,true) end
 if height then
  part(g,'Trunk',x,3+height*.35,z-2,1.5,height*.7,1.5,wood,M.Wood)
  round(g,'Canopy',x,3+height*.8,z-2,12,10,12,leaf,true)
  round(g,'Crown',x+2,3+height,z-2,9,7,9,sage,true)
 end
end
local function ramp(p,name,x)
 local a,b=V(x,0,-24),V(x,5,-48)
 part(p,name,x,2.5,-36,24,5,24,cream,nil,true,CFrame.Angles(0,math.pi,0),'WedgePart'):SetAttribute('NoJumpRoute',true)
 rail(p,a+V(-11.7,0,0),b+V(-11.7,0,0));rail(p,a+V(11.7,0,0),b+V(11.7,0,0))
 table.insert(data.Ramps,{Name=name,X1=x,Z1=-24,X2=x,Z2=-48,BaseY=0,Rise=5,Run=24,Width=24,SlopeDegrees=math.deg(math.atan(5/24))})
end
function B.Build(parent,origin)
 data={Version=7,Name='The Conservatory',Width=204,Depth=188,Ramps={},Decks={},Routes={},Spawns={}}
 local model=group(parent,'Lobby');model:SetAttribute('HussLobbyVersion',7);model:SetAttribute('MapWidth',204);model:SetAttribute('MapDepth',188)
 local floor=part(model,'Floor',0,-3,0,204,6,188,sage,M.Grass,true);model.PrimaryPart=floor
 local paths=group(model,'Promenades')
 pave(paths,0,0,92,128,0);pave(paths,0,70,62,28,.001)
 for _,s in ipairs({-1,1}) do pave(paths,s*76,7,46,76,.002) end
 pave(paths,0,36,164,24,.003);pave(paths,0,-16,140,16,.004)
 for i=0,7 do local a=math.pi/8+i*math.pi/4;part(paths,'Plaza border',math.sin(a)*33,.085,math.cos(a)*33,27.4,.035,.5,gold,M.Metal,false,CFrame.Angles(0,a,0)) end
 local f=group(model,'Bomb fountain')
 round(f,'Plinth',0,.24,0,32,.48,32,stone)
 round(f,'Basin',0,1.6,0,27,3.2,27,cream).CanCollide=true
 round(f,'Water',0,3.23,0,24,.15,24,R(49,109,102)).Material=M.Glass
 round(f,'Pedestal',0,4.5,0,7,3.2,7,ink)
 local bomb=round(f,'Bomb sculpture',0,9.4,0,9.5,9.5,9.5,ink,true);bomb.Material=M.Metal
 round(f,'Fuse socket',0,14.3,0,2,1.1,2,gold)
 beam(f,'Fuse',V(0,14.8,0),V(1.4,16.8,.2),.55,.55,gold)
 round(f,'Ember',1.4,16.8,.2,1.4,1.4,1.4,lime,true).Material=M.Neon
 label(f,'PASS THE PRESSURE','RUN / SPRINT / DODGE',0,2.1,13.65,14,2.2)
 local t=group(model,'North terrace')
 part(t,'Terrace deck',0,2.5,-68,148,5,40,stone,nil,true);pave(t,0,-68,147.8,39.8,5)
 table.insert(data.Decks,{Name='North terrace',X=0,Y=5,Z=-68,Width=148,Depth=40,SolidBase=true})
 ramp(t,'West promenade ramp',-54);ramp(t,'East promenade ramp',54)
 for _,ends in ipairs({{-74,-66},{-42,42},{66,74}}) do rail(t,V(ends[1],5,-48),V(ends[2],5,-48)) end
 rail(t,V(-74,5,-88),V(74,5,-88));rail(t,V(-74,5,-48),V(-74,5,-88));rail(t,V(74,5,-48),V(74,5,-88))
 for _,x in ipairs({-30,30}) do for _,z in ipairs({-57,-80}) do
  part(t,'Pavilion column',x,12.5,z,2.2,15,2.2,stone,nil,true)
  part(t,'Capital',x,19.7,z,3.2,.6,3.2,cream)
 end end
 part(t,'Pavilion eave',0,20,-68.5,67,1.1,30,cream);part(t,'Pavilion roof',0,21,-68.5,69,1.1,32,sage,M.Metal)
 label(t,'HUSS A BOMB','THE CONSERVATORY',0,15.8,-55.1,48,5.2)
 label(t,'YOUR NEXT CHASE','CHOOSE YOUR ARENA IN THE MAP VOTE',0,10.2,-80.4,40,4.6)
 local g=group(model,'Gardens and seating')
 for _,s in ipairs({-1,1}) do
  bench(t,s*52,5,-79);lamp(t,s*52,5,-84)
  garden(g,s*56,57,20,22,12);garden(g,s*84,67,18,26,15)
  garden(g,s*84,-54,14,24,13);garden(g,s*22,-31,15,13)
  lamp(g,s*39,0,59);lamp(g,s*41,0,-8);bench(g,s*29,0,51)
 end
 local wings=group(model,'Shaded galleries')
 for _,s in ipairs({-1,1}) do
  local turn=CFrame.Angles(0,-s*math.pi/2,0)
  for _,z in ipairs({-30,44}) do for _,x in ipairs({s*70,s*97}) do
   part(wings,'Gallery column',x,7.8,z,2.1,15.6,2.1,stone,nil,true)
   part(wings,'Capital',x,15.4,z,3.2,.6,3.2,cream)
  end end
  part(wings,'Gallery eave',s*80,15.9,7,39,1,73,cream);part(wings,'Gallery roof',s*80,16.9,7,40,1.1,74,sage,M.Metal)
  label(wings,s<0 and 'THE ARENAS' or 'THE CHASE','TAKE A MOMENT BETWEEN ROUNDS',s*63,12,7,45,3.5,turn)
  for i,name in ipairs(s<0 and {'EXPLORE','CHOOSE','PLAY'} or {'RUN','PASS','SURVIVE'}) do
   local z=-17+(i-1)*24;part(wings,'Gallery panel',s*97,4.5,z,3,9,14,stone,nil,true)
   label(wings,name,'HUSS A BOMB',s*95.3,5.2,z,12,4,turn)
  end
  bench(wings,s*85.5,0,21,s*math.pi/2);bench(wings,s*85.5,0,-5,s*math.pi/2)
 end
 local gate=group(model,'Arrival')
 for _,s in ipairs({-1,1}) do part(gate,'Gate pier',s*25,8,79,2.8,16,3.6,stone,nil,true);part(gate,'Gate capital',s*25,16,79,4,.7,4.2,cream) end
 part(gate,'Gate beam',0,16.5,79,54,1.4,4,cream)
 label(gate,'HUSS A BOMB','RUN / SPRINT / DODGE',0,17.1,81.3,34,4.5)
 local edge=group(model,'Boundary')
 for _,s in ipairs({-1,1}) do
  part(edge,'Side wall',s*101,3,0,2,6,188,stone,nil,true);part(edge,'Coping',s*101,6.05,0,2.5,.45,188,cream)
  part(edge,'End wall',0,3,s*93,200,6,2,stone,nil,true);part(edge,'Coping',0,6.05,s*93,200,.45,2.5,cream)
 end
 local spawn=part(model,'LobbySpawn',0,.5,64,8,1,8,cream,nil,false,nil,'SpawnLocation');spawn.Transparency=1;spawn.Neutral=true;spawn.Duration=0;spawn.Enabled=true
 table.insert(data.Spawns,{Name='LobbySpawn',X=0,Y=.5,Z=64})
 local function p(x,y,z) return {X=x,Y=y,Z=z} end
 local function route(name,width,points) table.insert(data.Routes,{Name=name,Width=width,Points=points}) end
 for _,s in ipairs({-1,1}) do
  route((s<0 and 'West' or 'East')..' arrival circuit',12,{p(0,0,64),p(0,0,40),p(s*36,0,40),p(s*36,0,0),p(s*36,0,-16),p(s*54,0,-16),p(s*54,0,-24),p(s*54,5,-48),p(s*54,5,-65),p(0,5,-65)})
  route((s<0 and 'West' or 'East')..' gallery access',10,{p(s*36,0,36),p(s*77,0,36),p(s*77,0,7),p(s*54,0,7),p(s*36,0,7)})
 end
 route('Fountain south promenade',12,{p(-36,0,26),p(0,0,26),p(36,0,26)})
 route('Fountain north promenade',10,{p(-36,0,-19),p(0,0,-19),p(36,0,-19)})
 if origin then for _,o in ipairs(model:GetDescendants()) do if o:IsA('BasePart') then o.CFrame=origin*o.CFrame end end end
 return model
end
function B.GetGeometry() return data end
return B

end)()

local edits={{hud,patchHUD(hud.Source)},{movement,patchShiftLock.Movement(movement.Source)},{shiftlock,patchShiftLock.ShiftLock(shiftlock.Source)},{audio,patchAudio(audio.Source)}}
local storage=game:GetService('ServerStorage')
local backup=Instance.new('Folder');backup.Name='SimpleLobbyShiftLockBackup_'..os.time()
while storage:FindFirstChild(backup.Name) do backup.Name..='_' end
local staging=Instance.new('Folder');staging.Name='V7Staging'
local newLobby,originalSources,oldMusic=nil,{},{}
local oldLobbyParent=oldLobby.Parent
for name in pairs(musicIds) do oldMusic[name]=workspace:GetAttribute(name) end
local ok,err=pcall(function()
 for _,edit in ipairs(edits) do
  local object,source=edit[1],edit[2]
  assert(object.Archivable,object.Name..' must be Archivable. Nothing changed.')
  originalSources[object]=object.Source
  local copy=object:Clone();if copy:IsA('BaseScript') then copy.Disabled=true end;copy.Parent=backup
  local probe=Instance.new(object.ClassName)
  local written,message=pcall(function() probe.Source=source end);probe:Destroy();assert(written,message)
 end
 newLobby=buildLobby.Build(staging)
 assert(newLobby and newLobby:IsA('Model') and newLobby.Name=='Lobby' and newLobby.Parent==staging,'Lobby construction failed.')
 local spawn=newLobby:FindFirstChild('LobbySpawn')
 assert(spawn and spawn:IsA('SpawnLocation'),'New lobby is missing its SpawnLocation.')
 newLobby:PivotTo(newLobby:GetPivot()+(oldSpawn.Position-spawn.Position))
end)
if not ok then staging:Destroy();backup:Destroy();error('Preflight stopped; originals preserved: '..tostring(err)) end
ok,err=pcall(function()
 backup.Parent=storage
 for _,edit in ipairs(edits) do edit[1].Source=edit[2] end
 oldLobby.Parent=backup
 for name,id in pairs(musicIds) do workspace:SetAttribute(name,id) end
 newLobby.Parent=workspace
end)
if not ok then
 local failures={}
 local function restore(fn) local success,message=pcall(fn);if not success then table.insert(failures,tostring(message)) end end
 restore(function() newLobby:Destroy() end)
 for object,source in pairs(originalSources) do restore(function() object.Source=source end) end
 restore(function() oldLobby.Parent=oldLobbyParent end)
 for name in pairs(musicIds) do restore(function() workspace:SetAttribute(name,oldMusic[name]) end) end
 staging:Destroy()
 if #failures==0 then backup:Destroy();error('Installation rolled back: '..tostring(err)) end
 error('Installation stopped. Backups: ServerStorage/'..backup.Name..'. Restore errors: '..table.concat(failures,'; ')..'. Original error: '..tostring(err))
end
staging:Destroy()
print('V7 installed: simpler lobby, real-track music support and shift-lock dodge. Speed, distance and cooldown unchanged.')
print('Backups: ServerStorage/'..backup.Name..'. Save the place, then press Play.')
