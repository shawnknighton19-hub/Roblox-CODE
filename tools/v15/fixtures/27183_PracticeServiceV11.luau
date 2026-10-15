--!nonstrict
-- HussPracticeV11: server-owned NPC practice, never economy participants.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Paths=game:GetService('PathfindingService')
local Bomb=require(script.Parent:WaitForChild('BombService'))
local Config=require(game:GetService('ReplicatedStorage').Shared.Config.GameConfig)
local P={}
local active
local V=Vector3.new
local names={'Fuse','Sparky','Boomer'}
local colors={Color3.fromRGB(49,205,255),Color3.fromRGB(255,188,44),Color3.fromRGB(183,107,250)}
local function flat(v) return V(v.X,0,v.Z) end
local function unit(v) return v.Magnitude>.01 and v.Unit or V(1,0,0) end
local function root(actor) return actor and actor.Character and actor.Character:FindFirstChild('HumanoidRootPart') end
local function living(actor)
 local h=actor and actor.Character and actor.Character:FindFirstChildOfClass('Humanoid')
 return actor and actor.Parent and actor:GetAttribute('InRound')==true and h and h.Health>0 and root(actor)~=nil
end
local function solo(player)
 local count=0
 for _,p in ipairs(Players:GetPlayers()) do if p:GetAttribute('BombTagAFK')~=true then count+=1;if p~=player then return false end end end
 return count==1 and player.Parent==Players and player:GetAttribute('BombTagAFK')~=true
end
local function valid(session)
 return active==session and not session.cancelled and solo(session.player) and living(session.player) and session.context.Running() and workspace:GetServerTimeNow()<session.deadline
end
local function actors(session)
 if not valid(session) then return {} end
 local list={session.player}
 for _,bot in ipairs(session.bots) do if living(bot.actor) then table.insert(list,bot.actor) end end
 return list
end
function P.Stop()
 local session=active;if not session then return end
 session.cancelled=true;active=nil
 for _,connection in ipairs(session.connections) do connection:Disconnect() end
 for _,bot in ipairs(session.bots) do
  bot.token+=1;bot.actor.Parent=nil
  if bot.path then bot.path:Destroy();bot.path=nil end
 end
 if session.folder then session.folder:Destroy() end
 Bomb.Stop()
end
local function createBot(session,index,spawnPart)
 local model=Instance.new('Model');model.Name=names[index];model:SetAttribute('HussPracticeBot',true)
 local collisionGroup=root(session.player).CollisionGroup
 local function part(name,size,position,color,collide)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=CFrame.new(position);p.Color=color;p.Material=Enum.Material.SmoothPlastic
  p.CanCollide=collide==true;p.CanTouch=false;p.CollisionGroup=collisionGroup;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=model;return p
 end
 local ink=Color3.fromRGB(29,35,51);local color=colors[index]
 local r=part('HumanoidRootPart',V(2,2,1),V(0,3,0),ink,false);r.Transparency=1
 local torso=part('Torso',V(2,2,1),V(0,3,0),color,true)
 local head=part('Head',V(2,1,1),V(0,4.5,0),Color3.fromRGB(255,222,141),true)
 local leftArm=part('Left Arm',V(1,2,1),V(-1.5,3,0),color,false)
 local rightArm=part('Right Arm',V(1,2,1),V(1.5,3,0),color,false)
 local leftLeg=part('Left Leg',V(1,2,1),V(-.5,1,0),ink,false)
 local rightLeg=part('Right Leg',V(1,2,1),V(.5,1,0),ink,false)
 local joints={}
 local function joint(name,a,b,offset)
  local j=Instance.new('Motor6D');j.Name=name;j.Part0=a;j.Part1=b;j.C0=CFrame.new(offset);j.C1=CFrame.new();j.Parent=a;joints[name]={motor=j,base=j.C0};return j
 end
 joint('RootJoint',r,torso,V(0,0,0));joint('Neck',torso,head,V(0,1.5,0))
 joint('Left Shoulder',torso,leftArm,V(-1.5,0,0));joint('Right Shoulder',torso,rightArm,V(1.5,0,0))
 joint('Left Hip',torso,leftLeg,V(-.5,-2,0));joint('Right Hip',torso,rightLeg,V(.5,-2,0))
 local face=Instance.new('SurfaceGui');face.Name='Face';face.Face=Enum.NormalId.Front;face.CanvasSize=Vector2.new(256,128);face.Parent=head
 local expression=Instance.new('TextLabel');expression.Size=UDim2.fromScale(1,1);expression.BackgroundTransparency=1;expression.Text='• ᴗ •';expression.Font=Enum.Font.GothamBlack;expression.TextSize=80;expression.TextColor3=ink;expression.Parent=face
 local badge=Instance.new('BillboardGui');badge.Name='PracticeBadge';badge.Size=UDim2.fromOffset(190,35);badge.StudsOffset=V(0,2,0);badge.AlwaysOnTop=false;badge.MaxDistance=120;badge.Adornee=head;badge.Parent=head
 local label=Instance.new('TextLabel');label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1;label.Font=Enum.Font.FredokaOne;label.TextSize=20;label.TextStrokeTransparency=0;label.TextColor3=color;label.Text=names[index]..' • PRACTICE';label.Parent=badge
 local humanoid=Instance.new('Humanoid');humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;humanoid.WalkSpeed=24;humanoid.UseJumpPower=true;humanoid.JumpPower=0;humanoid.JumpHeight=0;humanoid.AutoJumpEnabled=false;humanoid.MaxSlopeAngle=38;humanoid.Parent=model;humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
 model.PrimaryPart=r;model.Parent=session.folder
 session.context.Ground(model,spawnPart)
 for _,o in ipairs(model:GetChildren()) do if o:IsA('BasePart') then o.Anchored=false;o:SetNetworkOwner(nil) end end
 local actor={UserId=-index,Name=names[index],DisplayName=names[index],Character=model,Parent=session.folder}
 function actor:GetAttribute(name) return model:GetAttribute(name) end
 function actor:SetAttribute(name,value) model:SetAttribute(name,value) end
 actor:SetAttribute('InRound',true)
 local bot={actor=actor,root=r,h=humanoid,joints=joints,side=index%2==0 and 1 or -1,nextThink=0,nextPath=0,token=0,lastDodge=-math.huge,position=r.Position,stuckAt=workspace:GetServerTimeNow(),waypoints={},waypoint=1}
 table.insert(session.bots,bot)
 table.insert(session.connections,humanoid.Died:Connect(function() actor:SetAttribute('InRound',false);bot.token+=1 end))
 return bot
end
local function params(session)
 local rp=RaycastParams.new();rp.FilterType=Enum.RaycastFilterType.Exclude;rp.FilterDescendantsInstances={session.folder,session.player.Character};rp.IgnoreWater=true;rp.RespectCanCollide=true;return rp
end
local function floorAt(session,position)
 local hit=workspace:Raycast(position+V(0,4,0),V(0,-16,0),session.ray)
 return hit and hit.Normal.Y>.65 and hit.Position or nil
end
local function free(session,from,direction,distance)
 if workspace:Raycast(from,direction*distance,session.ray) then return false end
 return floorAt(session,from+direction*distance)~=nil
end
local function steer(session,bot,desired)
 local dir=unit(flat(desired));local from=bot.root.Position
 if free(session,from,dir,6) then return dir end
 for _,angle in ipairs({.65,-.65,1.3,-1.3,2,-2,math.pi}) do
  local rotated=CFrame.Angles(0,angle*bot.side,0):VectorToWorldSpace(dir)
  if free(session,from,rotated,6) then return rotated end
 end
 return Vector3.zero
end
local function route(session,bot,goal,now)
 if bot.pending or now<bot.nextPath then return end
 bot.nextPath=now+1.1;bot.pending=true;bot.token+=1;local token=bot.token;local start=bot.root.Position
 task.spawn(function()
  local path=Paths:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=false,AgentCanClimb=false,WaypointSpacing=5,Costs={Water=math.huge}})
  local ok=pcall(function() path:ComputeAsync(start,goal) end)
  -- ComputeAsync cannot be interrupted, so allow just one worker per bot and
  -- discard stale results. A late result can never recreate a stopped session.
  if active~=session or session.cancelled or bot.token~=token or not living(bot.actor) then path:Destroy();return end
  bot.pending=false
  if ok and path.Status==Enum.PathStatus.Success and workspace:GetServerTimeNow()-now<3 then
   if bot.path then bot.path:Destroy() end;bot.path=path;bot.waypoints=path:GetWaypoints();bot.waypoint=math.min(2,#bot.waypoints)
  else path:Destroy();bot.waypoints={};bot.waypoint=1 end
 end)
end
local function dodge(session,bot,direction,now)
 if direction.Magnitude<.1 or now-bot.lastDodge<1.5 or bot.h.FloorMaterial==Enum.Material.Air or not free(session,bot.root.Position,direction,10) then return end
 bot.lastDodge=now;bot.dodgeAt=now;bot.velocity=direction*math.clamp(bot.h.WalkSpeed+44,74,84);bot.h.AutoRotate=false
 local character=bot.actor.Character
 character:SetAttribute('BombTagIFrameUntil',character:GetAttribute('HussBombCarrier')==true and 0 or now+.45);character:SetAttribute('HussDodgeStartedAt',now)
 character:SetAttribute('MovementAction','DiveForward');character:SetAttribute('MovementActionId',(character:GetAttribute('MovementActionId') or 0)+1)
end
local function think(session,bot,now)
 if now<bot.nextThink then return end;bot.nextThink=now+.16+math.random()*.16
 local carrier=Bomb.GetCarrier();local current=bot.root.Position;local goal
 local danger=carrier and carrier~=bot.actor and root(carrier)
 if carrier==bot.actor then
  local distance=math.huge
  for _,actor in ipairs(actors(session)) do if actor~=bot.actor then
   local other=root(actor);local d=(other.Position-current).Magnitude
   if d<distance then distance=d;goal=other.Position+flat(other.AssemblyLinearVelocity)*.12 end
  end end
 elseif danger and (danger.Position-current).Magnitude<65 then
  local away=unit(flat(current-danger.Position));local side=V(-away.Z,0,away.X)*bot.side
  local candidate=current+unit(away+side*.42)*32
  goal=floorAt(session,candidate) and candidate or nil
  local distance=(danger.Position-current).Magnitude
  if distance<14 and distance>3 and math.random()<.7 then dodge(session,bot,steer(session,bot,away+side),now) end
 end
 if not goal then
  if not bot.roam or (bot.roam-current).Magnitude<8 or now>(bot.roamAt or 0) then
   local spawn=session.context.Spawns[math.random(1,#session.context.Spawns)];bot.roam=spawn.Position+V(0,3,0);bot.roamAt=now+5
  end
  goal=bot.roam
 end
 if (current-bot.position).Magnitude>2 then bot.position=current;bot.stuckAt=now
 elseif now-bot.stuckAt>1.4 then bot.side=-bot.side;bot.roam=nil;bot.nextPath=0;bot.waypoints={};bot.stuckAt=now;goal=current+V(17*bot.side,0,11) end
 bot.goal=goal
 local distance=(goal-current).Magnitude
 bot.speed=(carrier==bot.actor or danger and (danger.Position-current).Magnitude<45 or distance>30) and 32 or 24
 if distance>7 then route(session,bot,goal,now) end
end
local function animate(bot,now,speed,diving)
 local swing=math.sin(now*(speed>25 and 15 or 11))*math.min(speed/32,.85)
 for name,record in pairs(bot.joints) do
  local pose=CFrame.new()
  if name=='RootJoint' then pose=CFrame.Angles(diving and -.65 or -.08,0,diving and bot.side*.18 or 0)
  elseif name:find('Shoulder',1,true) then pose=CFrame.Angles(diving and -1.2 or (name=='Left Shoulder' and swing or -swing),0,0)
  elseif name:find('Hip',1,true) then pose=CFrame.Angles(diving and .45 or (name=='Left Hip' and -swing or swing),0,0) end
  record.motor.C0=record.base*pose
 end
end
local function move(session,bot,dt,now)
 if not living(bot.actor) then return end
 think(session,bot,now)
 local target=bot.goal or bot.root.Position
 local waypoint=bot.waypoints[bot.waypoint]
 if waypoint then
  if (waypoint.Position-bot.root.Position).Magnitude<6 then bot.waypoint+=1;waypoint=bot.waypoints[bot.waypoint] end
  if waypoint and waypoint.Action~=Enum.PathWaypointAction.Jump then target=waypoint.Position end
 end
 local direction=steer(session,bot,target-bot.root.Position)
 local boost=(bot.actor.Character:GetAttribute('HussPerfectBoostUntil') or 0)>now and 6 or 0
 local carrierBonus=bot.actor.Character:GetAttribute('HussBombCarrier')==true and (bot.actor.Character:GetAttribute('HABCarrierSprintBonus') or 0) or 0
 local speed=(bot.speed or 24)+boost+((bot.speed or 24)>=32 and carrierBonus or 0)
 local elapsed=bot.dodgeAt and now-bot.dodgeAt or 1
 local diving=elapsed<.72
 if diving then
  local t=math.clamp(elapsed/.72,0,1);local smooth=t*t*(3-2*t)
  if t>.34 then local control=math.clamp((t-.34)/(.86-.34),0,1);control=control*control*(3-2*control);bot.velocity=bot.velocity:Lerp(direction*bot.velocity.Magnitude,1-math.exp(-5.5*control*dt)) end
  bot.velocity*=math.exp(-(1+1.7*smooth)*dt)
  local handoff=math.clamp((t-.55)/.45,0,1);handoff=handoff*handoff*(3-2*handoff)
  bot.velocity=bot.velocity:Lerp(direction*speed,1-math.exp(-8.5*handoff*dt))
  if not free(session,bot.root.Position,unit(bot.velocity),math.max(4,bot.velocity.Magnitude*dt+2)) then bot.velocity=Vector3.zero end
  bot.h.WalkSpeed=speed*handoff
  local v=bot.root.AssemblyLinearVelocity;bot.root.AssemblyLinearVelocity=V(bot.velocity.X,v.Y,bot.velocity.Z)
  if bot.velocity.Magnitude>.1 then bot.root.CFrame=CFrame.lookAt(bot.root.Position,bot.root.Position+unit(bot.velocity)) end
 else bot.h.AutoRotate=true;bot.h.WalkSpeed=speed end
 bot.h:Move(direction,false);animate(bot,now,flat(bot.root.AssemblyLinearVelocity).Magnitude,diving)
end
function P.Run(player,context)
 P.Stop()
 if not solo(player) or not living(player) or #context.Spawns<2 then return end
 local session={player=player,character=player.Character,context=context,bots={},connections={},deadline=workspace:GetServerTimeNow()+math.clamp(context.Duration or 30,15,180)}
 active=session
 local ok,message=xpcall(function()
  local folder=Instance.new('Folder');folder.Name='HussPracticeBots';folder.Parent=workspace;session.folder=folder
  local spawns=table.clone(context.Spawns);local playerRoot=root(player)
  table.sort(spawns,function(a,b) return (a.Position-playerRoot.Position).Magnitude>(b.Position-playerRoot.Position).Magnitude end)
  for index=1,math.min(3,#spawns-1) do createBot(session,index,spawns[index]) end
  session.ray=params(session)
  local function check() if not valid(session) then P.Stop() end end
  local function watch(p) table.insert(session.connections,p:GetAttributeChangedSignal('BombTagAFK'):Connect(check));check() end
  table.insert(session.connections,Players.PlayerAdded:Connect(watch));table.insert(session.connections,Players.PlayerRemoving:Connect(function(p) if p==player then P.Stop() end end))
  for _,p in ipairs(Players:GetPlayers()) do watch(p);if active~=session then return end end
  table.insert(session.connections,player.CharacterAdded:Connect(function() P.Stop() end))
  table.insert(session.connections,session.character:FindFirstChildOfClass('Humanoid').Died:Connect(function() P.Stop() end))
  local nextUpdate=0
  table.insert(session.connections,RunService.Heartbeat:Connect(function(dt)
   local moved,err=pcall(function()
    if not valid(session) then P.Stop();return end
    local now=workspace:GetServerTimeNow()
    for _,bot in ipairs(session.bots) do move(session,bot,math.min(dt,.1),now) end
    if now>=nextUpdate then nextUpdate=now+.25;context.Send('PRACTICE',math.ceil(session.deadline-now),#actors(session)) end
   end)
   if not moved then session.error=err;P.Stop() end
  end))
  while valid(session) and #actors(session)>1 do
   Bomb.RunBombCycle(function() return actors(session) end,#actors(session)==2 and Config.FinalDuelBombFuseSeconds or Config.NormalBombFuseSeconds)
   local untilTime=workspace:GetServerTimeNow()+Config.BetweenBombsSeconds
   while valid(session) and workspace:GetServerTimeNow()<untilTime do task.wait(.05) end
  end
 end,debug.traceback)
 if active==session then P.Stop() end
 if not ok or session.error then error(message or session.error) end
end
return P

-- HAB_HALLOWEEN_CRATES_1
