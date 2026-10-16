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
   local ids={Aura=selection(s.p,'Aura'),Trail=selection(s.p,'Trail')}
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

  end
 end
end)
connect(script.Destroying,function() for _,s in pairs(states) do reset(s) end;for _,l in ipairs(links) do l:Disconnect() end end)
print('[HAB VFX 16] Original auras and trails ready; extra bomb and dodge visuals removed.')
