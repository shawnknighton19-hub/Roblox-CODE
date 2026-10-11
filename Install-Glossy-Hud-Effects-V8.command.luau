-- HUSS A BOMB V8: COLOUR, MOVEMENT EFFECTS AND LOBBY CLEARANCE
-- Requires V7. Stop Play and paste this whole block into Studio's Command Bar.
local run=game:GetService('RunService')
assert(run:IsStudio() and not run:IsRunning(),'Stop Play before installing.')
local storage=game:GetService('ServerStorage')
local lighting=game:GetService('Lighting')
local scripts=game:GetService('StarterPlayer').StarterPlayerScripts
local controllers=scripts:FindFirstChild('Controllers')
local hud=controllers and controllers:FindFirstChild('HudController')
local audio=scripts:FindFirstChild('GameAudioV6')
local movement=scripts:FindFirstChild('SnappyMovement')
local lock=scripts:FindFirstChild('ForcedShiftLock')
local lobby=workspace:FindFirstChild('Lobby')
assert(hud and hud:IsA('ModuleScript') and audio and audio:IsA('LocalScript') and movement and movement:IsA('LocalScript') and lock and lock:IsA('LocalScript'),'Install the previous V7 update first. Nothing changed.')
assert(hud.Source:find('Control the soundtrack and game sounds separately.',1,true) and audio.Source:find('-- HussMusicV7',1,true) and movement.Source:find('-- HussShiftLockV7',1,true) and lock.Source:find('-- HussShiftLockV7',1,true),'V7 signatures are missing. Nothing changed.')
assert(lobby and lobby:IsA('Model') and lobby:GetAttribute('HussLobbyVersion')==7,'The V7 lobby is required. Nothing changed.')
local footsteps=scripts:FindFirstChild('Footsteps')
assert(not footsteps or footsteps:IsA('LocalScript'),'Unexpected Footsteps object. Nothing changed.')
local previousEffects=scripts:FindFirstChild('MovementEffectsV8')
assert(not previousEffects or (previousEffects:IsA('LocalScript') and previousEffects.Source:find('-- HussMovementEffectsV8',1,true)),'An unrelated MovementEffectsV8 already exists. Nothing changed.')

local patchHUD=(function()
-- Glossy, colorful surfaces on the existing responsive HUD and its real controls.
return function(source)
 local marker='-- HussGlossV8'
 assert(type(source)=='string' and source:find('-- HussAudioV6',1,true),'The V6/V7 HUD is missing. Nothing changed.')
 if source:find(marker,1,true) then
  assert(source:find('local function gloss(',1,true) and source:find('HussDisabled',1,true),'Incomplete V8 HUD. Nothing changed.')
  return source
 end
 local function replace(old,new)
  local a,b=source:find(old,1,true)
  assert(a and not source:find(old,b+1,true),'Unexpected HUD section: '..old:sub(1,35)..'. Nothing changed.')
  source=source:sub(1,a-1)..new..source:sub(b+1)
 end
 local function section(first,last,value)
  local a=source:find(first,1,true);local b=a and source:find(last,a+1,true)
  assert(a and b,'Missing HUD style section. Nothing changed.')
  source=source:sub(1,a-1)..value..source:sub(b)
 end
 section('local C = {','local U, links',[[-- HussGlossV8
local rgb=Color3.fromRGB
local C={ink=rgb(13,17,43),panel=rgb(35,40,83),line=rgb(114,144,209),white=rgb(255,255,255),muted=rgb(204,217,246),green=rgb(165,255,113),red=rgb(255,108,131),gold=rgb(255,216,106),cyan=rgb(97,232,255),violet=rgb(192,150,255)}
local tones={STATS=rgb(157,96,23),CONTROLS=rgb(17,123,157),["HOW TO PLAY"]=rgb(105,63,178),MAPS=rgb(28,121,82),SETTINGS=rgb(158,58,123),Close=rgb(195,45,72),AFK=rgb(54,78,138),VoteReopen=rgb(143,88,23),Continue=rgb(28,121,82),Music=rgb(79,59,145),SoundEffects=rgb(20,108,134),Motion=rgb(105,63,178)}
local panelTones={MatchStatus=rgb(19,79,122),Identity=rgb(69,43,126),MatchInfo=rgb(47,66,131),Bomb=rgb(108,60,30),Dodge=rgb(21,82,91),LobbyFooter=rgb(59,47,111),Notification=rgb(39,64,112)}
]])
 replace('Thickness=1,Transparency=.25','Thickness=2,Transparency=.12')
 replace('TextStrokeTransparency=.45','TextStrokeTransparency=.18')
 section('local function panel(','local function bar(',[[local function gloss(o)
 o.ClipsDescendants=true
 make("UIGradient",o,{Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(141,156,207)),Rotation=90})
 local shine=frame(o,"Gloss",3,3,1,10,C.white,o.ZIndex+1)
 shine.Size=UDim2.new(1,-6,0,10);shine.BackgroundTransparency=.87;shine.Active=false;shine.Selectable=false;rounded(shine,7)
 local bevel=frame(o,"Bevel",3,0,1,4,C.ink,o.ZIndex+1)
 bevel.Position=UDim2.new(0,3,1,-7);bevel.Size=UDim2.new(1,-6,0,4);bevel.BackgroundTransparency=.42;bevel.Active=false;bevel.Selectable=false;rounded(bevel,2)
end
local function panel(parent,name,w,h,z,accent)
 local o=frame(parent,name,0,0,w,h,panelTones[name] or C.panel,z)
 o.BackgroundTransparency=.035;rounded(o,12);local rim=stroke(o,accent or C.cyan);gloss(o)
 return o,rim
end
local function button(parent,name,caption,callback,danger,bucket)
 local tone=danger and tones.Close or tones[name] or rgb(54,76,139)
 local b=make("TextButton",parent,{Name=name,Text=caption,TextTruncate=Enum.TextTruncate.AtEnd,Size=UDim2.fromOffset(120,44),BackgroundColor3=tone,TextColor3=C.white,TextStrokeColor3=C.ink,TextStrokeTransparency=.12,Font=Enum.Font.GothamBlack,TextSize=13,AutoButtonColor=false,BorderSizePixel=0,ZIndex=(parent.ZIndex or 1)+3})
 rounded(b,10);local rim=stroke(b,danger and C.red or tone:Lerp(C.white,.56));gloss(b)
 local focused=false
 local function paint()
  local selected=b:GetAttribute("HussSelected")==true;local disabled=b:GetAttribute("HussDisabled")==true
  local color=selected and rgb(39,115,65) or (disabled and C.panel or tone)
  b.Interactable=not disabled;b.Selectable=not disabled
  motion(rim,{Color=selected and C.green or (focused and not disabled and C.white or (disabled and C.line or tone:Lerp(C.white,.56)))})
  motion(b,{BackgroundColor3=focused and not disabled and color:Lerp(C.white,.13) or color})
 end
 local function focus(on) focused=on;paint() end
 connect(b.MouseEnter,function() focus(true) end,bucket);connect(b.MouseLeave,function() focus(false) end,bucket)
 connect(b.SelectionGained,function() focus(true) end,bucket);connect(b.SelectionLost,function() focus(false) end,bucket)
 connect(b:GetAttributeChangedSignal("HussSelected"),paint,bucket);connect(b:GetAttributeChangedSignal("HussDisabled"),paint,bucket)
 connect(b.Activated,function() if b:GetAttribute("HussDisabled")~=true then callback() end end,bucket);return b
end
]])
 replace('"L O B B Y  /  M E N U",3,0,180,16,10,C.muted','"L O B B Y  /  M E N U",3,0,180,16,10,C.gold')
 replace('string.format("%02d   %s   ›",i,name)','name.."   ›"')
 replace('"YOUR NEXT ROUND STARTS HERE"','"READY FOR YOUR NEXT ROUND"')
 replace('frame(b,"Accent",0,12,2,24,C.green,b.ZIndex+1)','frame(b,"Accent",0,13,3,22,C.white,b.ZIndex+1)')
 replace('U.BombRim.Color=(mine or danger) and C.red or C.line','U.BombRim.Color=(mine or danger) and C.red or C.gold; U.Bomb.BackgroundColor3=(mine or danger) and rgb(117,35,64) or panelTones.Bomb')
 replace('e.rim.Color=(selected or (not voteOpen and voteChosen==name)) and C.green or C.line',[[e.button:SetAttribute("HussSelected",selected or (not voteOpen and voteChosen==name))
    e.button:SetAttribute("HussDisabled",not voteOpen or server>=voteEnd)
    e.status.TextColor3=(selected or voteChosen==name) and C.green or C.muted
    if voteOpen and server>=voteEnd then e.status.Text="VOTING CLOSED" end]])
 replace('HUD transitions and dodge trails are disabled.','HUD transitions and movement trails are disabled.')
 replace('Crisp transitions and short dodge trails give feedback during the action.','Glossy transitions and movement effects give feedback during the action.')
 return source
end

end)()

local patchAudio=(function()
-- V8 uses clipped impact/scuff samples, never the default Roblox running loop.
return function(source)
 local marker='-- HussFootstepsV8'
 assert(source:find('-- HussMusicV7',1,true),'Install V7 audio first. Nothing changed.')
 if source:find(marker,1,true) then
  assert(source:find('local function nativeRunning(o)',1,true) and not source:find('action_footsteps_plastic',1,true),'Incomplete V8 audio. Nothing changed.')
  return source
 end
 local function replace(old,new)
  local a,b=source:find(old,1,true)
  assert(a and not source:find(old,b+1,true),'Unexpected audio source: '..old:sub(1,40))
  source=source:sub(1,a-1)..new..source:sub(b+1)
 end
 replace(",step='action_footsteps_plastic.mp3'",'')
 replace('local function play(pool,key,level,speed,lifetime,parent)','local function play(pool,key,level,speed,lifetime,parent,offset)')
 replace('v.TimePosition=0','v.TimePosition=offset or 0')
 replace('local voices,musicVoices,legacyAudio={},{},{}','local voices,musicVoices,legacyAudio,stepVoices={},{},{},{}')
 replace('-- Music uses OwnedMusic; no synthetic note pool.',[[-- HussFootstepsV8
for i=1,12 do stepVoices[i]={sound=sound(sfx),group=sfx,untilAt=0} end
-- Music uses OwnedMusic; no synthetic note pool.]])
 replace('local function audioLevel(o,saved)\n saved.applied=saved.level*sfx.Volume;o.Volume=saved.applied\nend',[[local function nativeRunning(o)
 if o.Name~='Running' then return false end
 local p=o.Parent
 while p and p~=workspace do
  if p:IsA('Model') and Players:GetPlayerFromCharacter(p) then return true end
  p=p.Parent
 end
 return false
end
local function audioLevel(o,saved)
 saved.applied=nativeRunning(o) and 0 or saved.level*(saved.player and sfx.Volume or 1)
 if o.Volume~=saved.applied then o.Volume=saved.applied end
end]])
 replace([[ if o:IsA('AudioPlayer') and not legacyAudio[o] then
  local saved={level=o.Volume};legacyAudio[o]=saved]],[[ if o:IsA('Sound') and (o.SoundGroup==sfx or o.SoundGroup==music) then return end
 if (o:IsA('AudioPlayer') or o:IsA('Sound')) and not legacyAudio[o] then
  local saved={level=o.Volume,player=o:IsA('AudioPlayer')};legacyAudio[o]=saved
  saved.name=o:GetPropertyChangedSignal('Name'):Connect(function() audioLevel(o,saved) end)]])
 replace('  audioLevel(o,saved);return','  audioLevel(o,saved)')
 local count
 source,count=source:gsub('saved.link:Disconnect%(%)','saved.link:Disconnect();saved.name:Disconnect()')
 assert(count==2,'Unexpected audio cleanup. Nothing changed.')
 replace(" if player==P and people[player] then people[player].readyAt=os.clock()+1.5 end",[[ if people[player] then
  people[player].dodgeUntil=os.clock()+.72
  if player==P then people[player].readyAt=os.clock()+1.5 end
 end]])
 replace('record.character=nil;record.humanoid=nil;record.root=nil;record.readyAt=nil','record.character=nil;record.humanoid=nil;record.root=nil;record.readyAt=nil;record.nextStep=nil;record.dodgeUntil=nil')
 replace(' for _,o in ipairs(c:GetChildren()) do discover(o) end',[[ for _,o in ipairs(c:GetChildren()) do discover(o) end
 for _,o in ipairs(c:GetDescendants()) do local saved=legacyAudio[o];if saved then audioLevel(o,saved) else adopt(o) end end]])
 local a=source:find('local function nativeFootsteps()',1,true)
 local b=a and source:find("link(Remotes.Get('RoundState')",a+1,true)
 assert(a and b,'Footstep section differs. Nothing changed.')
 local feet=[[local soft={Grass=true,Ground=true,Sand=true,Snow=true,Fabric=true,LeafyGrass=true,Mud=true}
local metal={Metal=true,DiamondPlate=true,CorrodedMetal=true}
local function feet()
 local now=os.clock();local camera=workspace.CurrentCamera;local candidates={}
 for _,record in pairs(people) do
  local c,h,r=record.character,record.humanoid,record.root
  local distance=camera and r and (camera.CFrame.Position-r.Position).Magnitude or math.huge
  local mode=h and h:GetState()
  local velocity=r and r.AssemblyLinearVelocity
  local valid=c and c.Parent and h and h.Parent==c and r and r.Parent and h.Health>0 and not r.Anchored
   and Vector3.new(velocity.X,0,velocity.Z).Magnitude>5
   and not h.Sit and not h.PlatformStand and distance<48 and sfx.Volume>0
   and (mode==Enum.HumanoidStateType.Running or mode==Enum.HumanoidStateType.RunningNoPhysics or mode==Enum.HumanoidStateType.Landed)
   and c:GetAttribute('MovementState')~='Dive' and c:GetAttribute('MovementState')~='Locked'
   and c:GetAttribute('Ragdolled')~=true and c:GetAttribute('IsRagdoll')~=true
   and record.player:GetAttribute('HussGamePaused')~=true and workspace:GetAttribute('HussGamePaused')~=true
   and now>=(record.dodgeUntil or 0) and (record.player~=P or h.MoveDirection.Magnitude>.05)
  if valid then table.insert(candidates,{record=record,distance=record.player==P and -1 or distance})
  else record.nextStep=nil end
 end
 table.sort(candidates,function(x,y) return x.distance<y.distance end)
 for i,entry in ipairs(candidates) do
  local record=entry.record;local r,h,c=record.root,record.humanoid,record.character
  if i>4 then record.nextStep=nil;continue end
  if not record.ray then
   record.ray=RaycastParams.new();record.ray.FilterType=Enum.RaycastFilterType.Exclude;record.ray.RespectCanCollide=true;record.ray.IgnoreWater=true
  end
  record.ray.FilterDescendantsInstances={c}
  local hit=workspace:Raycast(r.Position,Vector3.new(0,-math.max(3.4,h.HipHeight+r.Size.Y/2+.8),0),record.ray)
  local velocity=r.AssemblyLinearVelocity
  if hit and hit.Instance:IsA('BasePart') then velocity-=hit.Instance:GetVelocityAtPosition(hit.Position) end
  local speed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
  if not hit or speed<5 or math.abs(velocity.Y)>12 or (record.player==P and h.FloorMaterial==Enum.Material.Air) then record.nextStep=nil;continue end
  if now<(record.nextStep or 0) then continue end
  record.nextStep=now+math.clamp(7.8/speed,.2,.48)
  record.stride=(record.stride or 0)+1
  local variation=1+((record.stride*7%11)-5)*.009
  local name=hit.Material.Name;local gentle=soft[name];local hard=metal[name]
  local level=(record.player==P and 1 or .7)*math.clamp(speed/28,.7,1.2)
  play(stepVoices,'hit',level*(gentle and .032 or .045),variation*(hard and 1.3 or gentle and .98 or 1.1),.19,r,.033)
  play(stepVoices,'swish',level*(gentle and .01 or hard and .006 or .007),variation*1.1,.14,r,.12)
 end
end
]]
 source=source:sub(1,a-1)..feet..source:sub(b)
 source,count=source:gsub('{voices,musicVoices}','{voices,musicVoices,stepVoices}')
 assert(count==2,'Unexpected audio voice lifecycle. Nothing changed.')
 replace('footAt>=.1','footAt>=.05')
 return source
end

end)()

local world=(function()
-- V8: measure every arena at its actual runtime position; move only the lobby.
local World={}
local V=Vector3.new
local function bounds(model,delta,out)
 out=out or {MinX=math.huge,MaxX=-math.huge,MinZ=math.huge,MaxZ=-math.huge}
 for _,p in ipairs(model:GetDescendants()) do if p:IsA('BasePart') then
  local c,h=p.CFrame,p.Size*.5
  local r,u,l=c.RightVector,c.UpVector,c.LookVector
  local x=math.abs(r.X)*h.X+math.abs(u.X)*h.Y+math.abs(l.X)*h.Z
  local z=math.abs(r.Z)*h.X+math.abs(u.Z)*h.Y+math.abs(l.Z)*h.Z
  local q=p.Position+delta
  out.MinX=math.min(out.MinX,q.X-x);out.MaxX=math.max(out.MaxX,q.X+x)
  out.MinZ=math.min(out.MinZ,q.Z-z);out.MaxZ=math.max(out.MaxZ,q.Z+z)
 end end
 assert(out.MinX<math.huge,'Missing world geometry. Nothing changed.')
 return out
end
local function clear(a,b,gap)
 return a.MaxX<=b.MinX-gap or a.MinX>=b.MaxX+gap or a.MaxZ<=b.MinZ-gap or a.MinZ>=b.MaxZ+gap
end
function World.Plan(lobby,library,maps,anchor)
 assert(lobby and lobby:IsA('Model') and library and maps and anchor and anchor:IsA('BasePart'),'Lobby or map containers missing. Nothing changed.')
 local spawn=lobby:FindFirstChild('LobbySpawn')
 assert(spawn and spawn:IsA('SpawnLocation'),'LobbySpawn is missing. Nothing changed.')
 local arena,count=nil,0
 for _,model in ipairs(library:GetChildren()) do if model:IsA('Model') then
  local floor=model:FindFirstChild('Floor',true) or model.PrimaryPart
  assert(floor and floor:IsA('BasePart'),'Map floor missing: '..model.Name)
  -- Match MapService and map voting: floor-top translation, no anchor rotation.
  local top=floor.Position+V(0,floor.Size.Y/2,0)
  arena=bounds(model,anchor.Position-top,arena);count+=1
 end end
 assert(count>0,'MapLibrary is empty. Nothing changed.')
 if #maps:GetDescendants()>0 then arena=bounds(maps,Vector3.zero,arena) end
 local box=bounds(lobby,Vector3.zero)
 local delta,gap=Vector3.zero,96
 if not clear(box,arena,gap-.01) then
  local options={V(arena.MinX-gap-.05-box.MaxX,0,0),V(arena.MaxX+gap+.05-box.MinX,0,0),V(0,0,arena.MinZ-gap-.05-box.MaxZ),V(0,0,arena.MaxZ+gap+.05-box.MinZ)}
  delta=options[1]
  for _,offset in ipairs(options) do if offset.Magnitude<delta.Magnitude then delta=offset end end
 end
 return {Lobby=lobby,Spawn=spawn,OldParent=lobby.Parent,OldSpawnPosition=spawn.Position,OldPivot=lobby:GetPivot(),NewPivot=lobby:GetPivot()+delta,Delta=delta,ArenaBounds=arena,Gap=gap,TemplateCount=count}
end
function World.Apply(plan)
 assert(plan.Lobby.Parent==plan.OldParent and plan.Lobby:FindFirstChild('LobbySpawn')==plan.Spawn,'Lobby changed during installation.')
 if plan.Delta.Magnitude>0 then plan.Lobby:PivotTo(plan.NewPivot) end
 assert((plan.Spawn.Position-plan.OldSpawnPosition-plan.Delta).Magnitude<.02,'Lobby spawn alignment failed.')
 assert(clear(bounds(plan.Lobby,Vector3.zero),plan.ArenaBounds,plan.Gap-.01),'Lobby clearance failed.')
end
function World.Graphics(lighting)
 local old={}
 for _,effect in ipairs(lighting:GetChildren()) do
  if effect.Name=='HussColorV8' then assert(effect:IsA('ColorCorrectionEffect'),'HussColorV8 has an unexpected class. Nothing changed.') end
  if effect.Name=='HussBloomV8' then assert(effect:IsA('BloomEffect'),'HussBloomV8 has an unexpected class. Nothing changed.') end
  if effect.Name=='HussColorV8' or effect.Name=='HussBloomV8' or (effect.Name=='Bloom' and effect:IsA('BloomEffect')) then table.insert(old,effect) end
 end
 return {Old=old,New={
  {Class='ColorCorrectionEffect',Name='HussColorV8',Properties={Enabled=true,Brightness=.01,Contrast=.05,Saturation=.10,TintColor=Color3.new(1,1,1)}},
  {Class='BloomEffect',Name='HussBloomV8',Properties={Enabled=true,Intensity=.10,Size=18,Threshold=1.3}},
 }}
end
return World

end)()

local effectsSource=[==[--!nonstrict
-- HussMovementEffectsV8: narrow action wakes and small ground puffs; cosmetic only.
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local RS=game:GetService('ReplicatedStorage')
local me=Players.LocalPlayer
local V=Vector3.new
local states,records,links={},{},{}
local stopped,allocated,rayTokens=false,0,12
local actions={DiveForward=true,DiveBack=true,DiveLeft=true,DiveRight=true,DiveForwardLeft=true,DiveForwardRight=true,DiveBackLeft=true,DiveBackRight=true}
local cyan=ColorSequence.new(Color3.fromRGB(125,244,255),Color3.fromRGB(44,163,255))
local gold=ColorSequence.new(Color3.fromRGB(255,250,193),Color3.fromRGB(255,193,75))
local function link(signal,fn,list) table.insert(list or links,signal:Connect(fn)) end
local function make(class,parent,properties)
 local o=Instance.new(class);for k,v in pairs(properties) do o[k]=v end;o.Parent=parent;return o
end
local function reduced() return me:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true end
local function blocked(s)
 local h,c,r=s.h,s.c,s.r
 local mode=h:GetState()
 return not c.Parent or not h.Parent or not r.Parent or h.Health<=0 or r.Anchored or h.Sit or h.PlatformStand
  or s.p:GetAttribute('HussGamePaused')==true or workspace:GetAttribute('HussGamePaused')==true
  or c:GetAttribute('Ragdolled')==true or c:GetAttribute('IsRagdoll')==true
  or mode==Enum.HumanoidStateType.Dead or mode==Enum.HumanoidStateType.Ragdoll
  or mode==Enum.HumanoidStateType.Physics or mode==Enum.HumanoidStateType.Seated
end
local function clear(s,destroy)
 s.untilAt=nil;s.pending=false
 for _,t in ipairs(s.trails) do t.Enabled=false;t:Clear() end
 if s.dust then s.dust:Clear() end
 if destroy and #s.objects>0 then
  for _,o in ipairs(s.objects) do o:Destroy() end
  table.clear(s.objects);table.clear(s.trails);s.dust=nil;s.mode=nil;allocated-=1
 end
end
local function effects(s)
 if #s.objects>0 then return true end
 -- Reserve one slot for the local player. At most 12 sets / 24 trails.
 if allocated>=(s.p==me and 12 or 11) then return false end
 allocated+=1
 local function obj(class,parent,props) local o=make(class,parent,props);table.insert(s.objects,o);return o end
 for _,side in ipairs({-1,1}) do
  local a=obj('Attachment',s.r,{Name='HussWakeTop',Position=V(side*.7,-.45,.3)})
  local b=obj('Attachment',s.r,{Name='HussWakeBottom',Position=V(side*.7,-.62,.3)})
  local t=obj('Trail',s.r,{Name='HussMovementWake',Attachment0=a,Attachment1=b,Lifetime=.09,MinLength=.1,MaxLength=8,LightEmission=.75,FaceCamera=true,Enabled=false,Color=cyan,
   Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.36),NumberSequenceKeypoint.new(1,1)}),
   WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})})
  table.insert(s.trails,t)
 end
 s.at=obj('Attachment',s.r,{Name='HussGroundPuff'})
 s.dust=obj('ParticleEmitter',s.at,{Name='HussGroundDust',Texture='rbxasset://textures/particles/smoke_main.dds',Rate=0,Enabled=false,
  Lifetime=NumberRange.new(.16,.3),Speed=NumberRange.new(1.2,3.2),SpreadAngle=Vector2.new(60,60),EmissionDirection=Enum.NormalId.Top,
  Acceleration=V(0,1.5,0),VelocityInheritance=.04,Drag=3,Rotation=NumberRange.new(0,360),RotSpeed=NumberRange.new(-35,35),LightInfluence=.7,
  Color=ColorSequence.new(Color3.fromRGB(212,217,220)),
  Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(.65,.7),NumberSequenceKeypoint.new(1,.9)}),
  Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.55),NumberSequenceKeypoint.new(.5,.75),NumberSequenceKeypoint.new(1,1)})})
 return true
end
local function ground(s,now)
 if s.p==me and s.h.FloorMaterial==Enum.Material.Air then return nil end
 if now>=s.groundAt then
  if s.p~=me then if rayTokens<1 then return nil end;rayTokens-=1 end
  s.groundAt=now+.14
  local leg=s.c:FindFirstChild('Left Leg')
  local height=math.clamp(s.h.HipHeight+s.r.Size.Y*.5+(leg and leg.Size.Y or 0),1.5,8)
  local hit=workspace:Raycast(s.r.Position,V(0,-height-.7,0),s.ray)
  s.hit=hit and hit.Normal.Y>.45 and hit or nil
 end
 return s.hit
end
local function start(s,action,age)
 if not actions[action] or age<0 or age>=.72 or blocked(s) or reduced() or workspace:GetAttribute('HussDodgeV5')~=true then return end
 s.untilAt=os.clock()+.32-age;s.dodgeUntil=os.clock()+.72-age;s.pending=age<.14;s.groundAt=0
end
local function dispose(p)
 local s=states[p];if not s then return end
 clear(s,true);for _,c in ipairs(s.links) do c:Disconnect() end;states[p]=nil
end
local function character(p,c)
 local record=records[p];record.generation+=1;local generation=record.generation;dispose(p)
 task.spawn(function()
  local h=c:WaitForChild('Humanoid',10);local r=c:WaitForChild('HumanoidRootPart',10)
  if stopped or records[p]~=record or record.generation~=generation or p.Character~=c or not h or not r then return end
  local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude;ray.FilterDescendantsInstances={c};ray.IgnoreWater=true;ray.RespectCanCollide=true
  local s={p=p,c=c,h=h,r=r,ray=ray,trails={},objects={},links={},groundAt=0,nextDust=0};states[p]=s
  link(h.Died,function() clear(s,true) end,s.links)
  if p==me then link(c:GetAttributeChangedSignal('MovementActionId'),function()
   local action=c:GetAttribute('MovementAction')
   if action=='DiveEnd' then clear(s,false) else start(s,action,0) end
  end,s.links) end
 end)
end
local function remove(p)
 local record=records[p];if not record then return end
 record.generation+=1;for _,c in ipairs(record.links) do c:Disconnect() end;dispose(p);records[p]=nil
end
local function add(p)
 if records[p] then return end
 local record={generation=0,links={}};records[p]=record
 link(p.CharacterAdded,function(c) character(p,c) end,record.links)
 link(p.CharacterRemoving,function() record.generation+=1;dispose(p) end,record.links)
 if p.Character then character(p,p.Character) end
end
link(Players.PlayerAdded,add);link(Players.PlayerRemoving,remove)
for _,p in ipairs(Players:GetPlayers()) do add(p) end
link(Run.Heartbeat,function(dt)
 rayTokens=math.min(12,rayTokens+math.min(dt,.25)*80)
 local now=os.clock();local camera=workspace.CurrentCamera
 local origin=camera and camera.CFrame.Position
 local low=reduced()
 for _,s in pairs(states) do
  local near=origin and (s.r.Position-origin).Magnitude<100
  if low or not near or blocked(s) then clear(s,true)
  else
   local v=s.r.AssemblyLinearVelocity;local speed=V(v.X,0,v.Z).Magnitude
   local dodge=s.untilAt and now<s.untilAt
   local sprint=speed>4 and now>=(s.dodgeUntil or 0) and (s.p~=me or s.c:GetAttribute('MovementState')=='Sprint')
   local slot=#s.objects>0 or allocated<(s.p==me and 12 or 11)
   local hit=slot and (dodge or sprint) and ground(s,now)
   if hit and not dodge then
    local floor=hit.Instance
    if floor:IsA('BasePart') then v-=floor:GetVelocityAtPosition(s.r.Position) end
    speed=V(v.X,0,v.Z).Magnitude
    if speed<=27 or speed>=44 then hit=nil end
   end
   if hit and effects(s) then
    s.usedAt=now
    local mode=dodge and 'dodge' or 'sprint'
    for _,t in ipairs(s.trails) do
     if s.mode~=mode then t.Color=dodge and gold or cyan;t.Lifetime=dodge and .145 or .09 end
     t.Enabled=speed>4
    end
    s.mode=mode
    if s.pending or (sprint and now>=s.nextDust) then
     s.at.Position=s.r.CFrame:PointToObjectSpace(hit.Position+V(0,.12,0))
     s.dust:Emit(s.pending and 6 or 1);s.pending=false;s.nextDust=now+.24
    end
   else
    for _,t in ipairs(s.trails) do t.Enabled=false end
    s.pending=false
    if now-(s.usedAt or 0)>1 then clear(s,true) end
   end
  end
 end
end)
task.spawn(function()
 local remote=RS:WaitForChild('Shared'):WaitForChild('Net'):WaitForChild('DodgeIFrameRequest')
 if stopped then return end
 link(remote.OnClientEvent,function(p,action,stamp)
  if p==me or not actions[action] or type(stamp)~='number' or stamp~=stamp then return end
  local age=workspace:GetServerTimeNow()-stamp
  local s=states[p]
  if s and age>=0 and age<.72 and (not s.lastStamp or stamp>s.lastStamp) then s.lastStamp=stamp;start(s,action,age) end
 end)
end)
link(script.Destroying,function()
 stopped=true;for _,c in ipairs(links) do c:Disconnect() end
 local list={};for p in pairs(records) do table.insert(list,p) end;for _,p in ipairs(list) do remove(p) end
end)
]==]

local edits={{hud,patchHUD(hud.Source)},{audio,patchAudio(audio.Source)}}
local plan=world.Plan(lobby,storage:FindFirstChild('MapLibrary'),workspace:FindFirstChild('Maps'),workspace:FindFirstChild('ActiveArenaAnchor'))
local graphics=world.Graphics(lighting)
local backup=Instance.new('Folder');backup.Name='GlossyEffectsBackup_'..os.time()
while storage:FindFirstChild(backup.Name) do backup.Name..='_' end
local staging=Instance.new('Folder');staging.Name='V8Staging'
local lightingBackup=Instance.new('Folder');lightingBackup.Name='Lighting';lightingBackup.Parent=backup
local originalSources,oldParents,newGraphics={},{},{}
local newEffects
local oldFootsteps=footsteps and footsteps.Disabled
local oldEffectsParent=previousEffects and previousEffects.Parent
local oldEffectsDisabled=previousEffects and previousEffects.Disabled
local ok,err=pcall(function()
 local pivot=Instance.new('CFrameValue');pivot.Name='PreviousLobbyPivot';pivot.Value=plan.OldPivot;pivot.Parent=backup
 local ref=Instance.new('ObjectValue');ref.Name='LobbyReference';ref.Value=lobby;ref.Parent=backup
 for _,edit in ipairs(edits) do
  local object,source=edit[1],edit[2]
  assert(object.Archivable,object.Name..' must be Archivable. Nothing changed.')
  originalSources[object]=object.Source
  local copy=object:Clone();assert(copy,'Unable to back up '..object.Name)
  if copy:IsA('BaseScript') then copy:SetAttribute('OriginalDisabled',copy.Disabled);copy.Disabled=true end
  copy.Parent=backup
  local probe=Instance.new(object.ClassName)
  local written,message=pcall(function() probe.Source=source end);probe:Destroy();assert(written,message)
 end
 if footsteps then
  local state=Instance.new('BoolValue');state.Name='PreviousFootstepsDisabled';state.Value=oldFootsteps;state.Parent=backup
 end
 if previousEffects then backup:SetAttribute('PreviousEffectsDisabled',oldEffectsDisabled) end
 for _,effect in ipairs(graphics.Old) do oldParents[effect]=effect.Parent end
 for _,spec in ipairs(graphics.New) do
  local effect=Instance.new(spec.Class);effect.Parent=staging;table.insert(newGraphics,effect);effect.Name=spec.Name
  for property,value in pairs(spec.Properties) do effect[property]=value end
 end
 newEffects=Instance.new('LocalScript');newEffects.Disabled=true;newEffects.Parent=staging;newEffects.Name='MovementEffectsV8';newEffects.Source=effectsSource
end)
if not ok then staging:Destroy();backup:Destroy();error('Preflight stopped; originals preserved: '..tostring(err)) end
ok,err=pcall(function()
 backup.Parent=storage
 for _,edit in ipairs(edits) do edit[1].Source=edit[2] end
 world.Apply(plan)
 for _,effect in ipairs(graphics.Old) do effect.Parent=lightingBackup end
 for _,effect in ipairs(newGraphics) do effect.Parent=lighting end
 if footsteps then footsteps.Disabled=true end
 if previousEffects then previousEffects.Disabled=true;previousEffects.Parent=backup end
 newEffects.Parent=scripts;newEffects.Disabled=false
end)
if not ok then
 local failures={}
 local function restore(fn) local success,message=pcall(fn);if not success then table.insert(failures,tostring(message)) end end
 restore(function() newEffects:Destroy() end)
 for _,effect in ipairs(newGraphics) do restore(function() effect:Destroy() end) end
 if previousEffects then restore(function() previousEffects.Parent=oldEffectsParent;previousEffects.Disabled=oldEffectsDisabled end) end
 if footsteps then restore(function() footsteps.Disabled=oldFootsteps end) end
 for effect,parent in pairs(oldParents) do restore(function() effect.Parent=parent end) end
 restore(function() lobby:PivotTo(plan.OldPivot) end)
 for object,source in pairs(originalSources) do restore(function() object.Source=source end) end
 staging:Destroy()
 if #failures==0 then backup:Destroy();error('Installation rolled back: '..tostring(err)) end
 error('Installation stopped. Backups: ServerStorage/'..backup.Name..'. Restore errors: '..table.concat(failures,'; ')..'. Original error: '..tostring(err))
end
staging:Destroy()
print('V8 installed: glossy colourful HUD, custom footsteps, movement effects and clear lobby placement.')
print('Checked '..plan.TemplateCount..' map templates; lobby moved '..math.floor(plan.Delta.Magnitude+.5)..' studs with a '..plan.Gap..'-stud clearance. Movement tuning is unchanged.')
print('Backups: ServerStorage/'..backup.Name..'. Save the place, then press Play.')
