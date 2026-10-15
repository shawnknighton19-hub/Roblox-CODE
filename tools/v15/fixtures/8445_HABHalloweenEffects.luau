--!nonstrict
-- HAB_FUN_9: fitted full-body auras, real bomb-skin attachment and brighter equipped pack effects.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local Pack=RS:WaitForChild('HABHalloween')
local Catalog=require(Pack.Catalog)
local Render=require(Pack.Renderer)
local Config=require(RS.HABExpansion.Config)
local Skins=require(RS.HussCatalogV11)
local me=Players.LocalPlayer
local states,links={},{}
local clock=0
local function connect(event,fn) local c=event:Connect(fn);links[#links+1]=c;return c end
local function off() return me:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true end
local function reset(s)
 for _,h in ipairs(s.handles) do h:Stop() end
 s.handles={};s.auraAt=0;s.trailAt=0;s.bombAt=0;s.seen={};s.previous=nil;s.bomb=nil
end
local function add(p) states[p]={p=p,handles={},auraAt=0,trailAt=0,bombAt=0,seen={}} end
local function drop(p) local s=states[p];if s then reset(s);states[p]=nil end end
connect(Players.PlayerAdded,add);connect(Players.PlayerRemoving,drop)
for _,p in ipairs(Players:GetPlayers()) do add(p) end
local function selection(p,slot)
 local id=p:GetAttribute('HABPack'..slot);local item=id and Catalog.ById[id]
 return item and item.Category==slot and not item.RetiredFinisher and id or nil
end
local function play(s,...)
 local ok,h=pcall(Render.Play,...)
 if ok and h then s.handles[#s.handles+1]=h
 elseif not ok and os.clock()>(s.warnAt or 0) then s.warnAt=os.clock()+12;warn('[HAB VFX] '..tostring(h)) end
end
local function bodyHeight(c,r)
 local lo,hi=0,0
 for _,p in ipairs(c:GetChildren()) do if p:IsA('BasePart') and p.Name~='HumanoidRootPart' and p.Name~='ActiveBomb' then
  local pos=r.CFrame:PointToObjectSpace(p.Position)
  lo=math.min(lo,pos.Y-p.Size.Y/2);hi=math.max(hi,pos.Y+p.Size.Y/2)
 end end
 return math.clamp(hi-lo,4.8,8.5),(lo+hi)/2
end
local function bombFit(object)
 local anchor=object:IsA('BasePart') and object or object:IsA('Model') and (object.PrimaryPart or object:FindFirstChildWhichIsA('BasePart',true))
 if not anchor then return end
 local min=Vector3.new(math.huge,math.huge,math.huge);local max=-min
 local n=0
 local parts={anchor};for _,p in ipairs(object:GetDescendants()) do if p:IsA('BasePart') then parts[#parts+1]=p end end
 for _,p in ipairs(parts) do if p.Transparency<.95 and p.Size.Magnitude<15 then
  for _,sx in ipairs({-1,1}) do for _,sy in ipairs({-1,1}) do for _,sz in ipairs({-1,1}) do
   local v=anchor.CFrame:PointToObjectSpace(p.CFrame:PointToWorldSpace(p.Size*Vector3.new(sx,sy,sz)*.5))
   min=Vector3.new(math.min(min.X,v.X),math.min(min.Y,v.Y),math.min(min.Z,v.Z))
   max=Vector3.new(math.max(max.X,v.X),math.max(max.Y,v.Y),math.max(max.Z,v.Z))
  end end end;n+=1
 end end
 if n==0 then return anchor,Vector3.zero,anchor.Size end
 return anchor,(min+max)*.5,Vector3.new(math.clamp(max.X-min.X,1,7),math.clamp(max.Y-min.Y,1,7),math.clamp(max.Z-min.Z,1,7))
end
connect(Run.Heartbeat,function(dt)
 clock+=dt;if clock<.09 then return end;clock=0
 local cam=workspace.CurrentCamera;if not cam then return end
 local now=os.clock();local candidates={}
 for _,s in pairs(states) do
  local c=s.p.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local r=c and c:FindFirstChild('HumanoidRootPart')
  local blocked=not r or not h or h.Health<=0 or h.Sit or h.PlatformStand or r.Anchored or off()
   or s.p:GetAttribute('HussGamePaused')==true or workspace:GetAttribute('HussGamePaused')==true
   or c:GetAttribute('Ragdolled')==true or c:GetAttribute('IsRagdoll')==true
  if blocked then reset(s) else
   if s.c~=c then reset(s);s.c=c;s.height,s.center=bodyHeight(c,r) end
   s.r=r;s.h=h;s.distance=(r.Position-cam.CFrame.Position).Magnitude
   if s.p==me or s.distance<110 then candidates[#candidates+1]=s else reset(s) end
  end
 end
 table.sort(candidates,function(a,b) if a.p==me then return b.p~=me end;if b.p==me then return false end;return a.distance<b.distance end)
 for index,s in ipairs(candidates) do
  if index>(Input.TouchEnabled and 3 or 5) then reset(s) else
   for i=#s.handles,1,-1 do local h=s.handles[i];if h.Stopped or h.End<now then table.remove(s.handles,i) end end
   local ids={Aura=selection(s.p,'Aura'),Trail=selection(s.p,'Trail'),BombFX=selection(s.p,'BombFX')}
   local changed=false
   for k,v in pairs(ids) do if s.seen[k]~=v then changed=true end end
   for k,v in pairs(s.seen) do if ids[k]~=v then changed=true end end
   if changed or (s.previous and (s.r.Position-s.previous).Magnitude>50) then reset(s) end
   s.seen=ids;s.previous=s.r.Position
   local carrier=s.c:GetAttribute('HussBombCarrier')==true
   local width=math.clamp(s.height*1.18,5.9,Config.VFX.MaxAuraWidth)
   local alpha=carrier and .20 or .10
   if ids.Aura and now>=s.auraAt then
    local life=math.clamp(Catalog.Lifetime(ids.Aura),.65,5)
    s.auraAt=now+math.clamp(life*.86,.55,3.2)
    play(s,ids.Aura,s.r,width,Vector3.new(0,s.center,0),true,alpha,false)
    -- A secondary layer above the feet stops tall auras disappearing behind the torso.
    if s.p==me then
     local torso=s.c:FindFirstChild('UpperTorso') or s.c:FindFirstChild('Torso') or s.r
     play(s,ids.Aura,torso,width*.48,Vector3.new(0,.15,-torso.Size.Z*.55),true,.36,false)
    end
   end
   local velocity=s.r.AssemblyLinearVelocity
   local flat=Vector3.new(velocity.X,0,velocity.Z)
   local moving=flat.Magnitude>2 or (s.h:GetState()==Enum.HumanoidStateType.Climbing and velocity.Magnitude>1)
   if ids.Trail and moving and now>=s.trailAt then
    s.trailAt=now+(Catalog.ById[ids.Trail].Native and (s.p==me and .50 or .95) or (s.p==me and .27 or .45))
    local back=flat.Magnitude>.1 and -flat.Unit or -s.r.CFrame.LookVector
    play(s,ids.Trail,s.r.Position+back*1.5-Vector3.new(0,1,0),3.5,nil,false,.06)
    for _,side in ipairs({'Left','Right'}) do
     local hand=s.c:FindFirstChild(side..'Hand') or s.c:FindFirstChild(side..' Arm') or s.c:FindFirstChild(side..'LowerArm')
     if hand then play(s,ids.Trail,hand,2.0,Vector3.new(0,-hand.Size.Y*.3,0),true,.15) end
    end
   end
   local bomb=s.c:FindFirstChild('ActiveBomb')
   if ids.BombFX and carrier and bomb and now>=s.bombAt then
    s.bombAt=now+math.clamp(Catalog.Lifetime(ids.BombFX)*.85,.5,2.6)
    if s.bomb~=bomb then s.bomb=bomb;s.anchor,s.bombCenter,s.bombSize=bombFit(bomb) end
    if s.anchor and s.anchor.Parent then
     local a=s.bombSize;local diameter=math.clamp(math.max(a.X,a.Z,a.Y*.8)*Config.VFX.BombCover,2.5,6.2)
     local skin=Skins.ById[s.p:GetAttribute('HussBombId')]
     local tint=skin and Color3.fromRGB(table.unpack(skin.color)) or s.anchor.Color
     -- Bound to the real skin anchor, sized from the sculpture, with a surface-facing accent.
     play(s,ids.BombFX,s.anchor,diameter,s.bombCenter,true,.14,false,{Tint=tint})
     if s.p==me then play(s,ids.BombFX,s.anchor,diameter*.48,s.bombCenter+Vector3.new(0,a.Y*.20,-a.Z*.48),true,.30,false,{Tint=tint}) end
    end
   end
  end
 end
end)
local dodgeAt={}
local function dodge(p,action,stamp)
 if typeof(p)~='Instance' or not p:IsA('Player') or type(action)~='string' or action:sub(1,4)~='Dive' or action=='DiveEnd' or off() then return end
 if stamp and (type(stamp)~='number' or math.abs(workspace:GetServerTimeNow()-stamp)>.9) then return end
 local now=os.clock();if now-(dodgeAt[p] or -100)<.3 then return end
 local id=selection(p,'DodgeFX');local c=p.Character;local r=c and c:FindFirstChild('HumanoidRootPart');local h=c and c:FindFirstChildOfClass('Humanoid')
 if not id or not r or not h or h.Health<=0 then return end
 local cam=workspace.CurrentCamera;if p~=me and (not cam or (cam.CFrame.Position-r.Position).Magnitude>110) then return end
 dodgeAt[p]=now
 local v=Vector3.new(r.AssemblyLinearVelocity.X,0,r.AssemblyLinearVelocity.Z)
 if v.Magnitude<.5 then v=r.CFrame.LookVector end
 local pos=r.Position-Vector3.new(0,.55,0);local cf=CFrame.lookAt(pos,pos+v.Unit)
 pcall(Render.Play,id,cf,8.5,nil,false,.08,true)
 if p==me and not Input.TouchEnabled then
  task.delay(.15,function() if r.Parent and c==p.Character and h.Health>0 and not off() then pcall(Render.Play,id,r.CFrame*CFrame.new(0,-.8,1.2),4,nil,false,.38,false) end end)
 end
end
local function bind(c)
 local link=c:GetAttributeChangedSignal('MovementActionId'):Connect(function() dodge(me,c:GetAttribute('MovementAction')) end)
 c.Destroying:Once(function() link:Disconnect() end)
end
connect(me.CharacterAdded,bind);if me.Character then bind(me.Character) end
connect(Players.PlayerRemoving,function(p) dodgeAt[p]=nil end)
task.spawn(function()
 local shared=RS:WaitForChild('Shared',20);local net=shared and shared:WaitForChild('Net',20);local remote=net and net:WaitForChild('DodgeIFrameRequest',20)
 if remote and remote:IsA('RemoteEvent') then connect(remote.OnClientEvent,function(p,a,t) if p~=me then dodge(p,a,t) end end) end
end)
connect(script.Destroying,function() for _,s in pairs(states) do reset(s) end;for _,l in ipairs(links) do l:Disconnect() end end)
print('[HAB VFX 9] Body-sized auras, skin-mounted bomb VFX, arm trails and directional dodges ready.')
