--!nonstrict
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
