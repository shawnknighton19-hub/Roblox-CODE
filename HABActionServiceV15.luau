--!nonstrict
-- HAB_POLISH_V15. Server-authorized contact, consistent animation clocks and one transfer per attack.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local X=RS:WaitForChild('HABExpansion')
local Config=require(X.Config)
local Rules=require(X.CombatRules)
local Passes=require(script.Parent.HABPassService)
local Economy=require(script.Parent.EconomyServiceV9)
local Perfect=require(script.Parent.PerfectWeaveServiceV11)
local Input=X:WaitForChild('Action')
local FX=X:WaitForChild('FX')
local S={};local started=false
local carrier,fuse,lock,protectedId,protectedUntil=nil,0,0,nil,0
local attack=nil;local serial=0;local records={};local samples={}
local function clock() return workspace:GetServerTimeNow() end
local function player(p) return typeof(p)=='Instance' and p:IsA('Player') end
local function root(p)
 local c=p and p.Character
 local h=c and c:FindFirstChildOfClass('Humanoid')
 local r=c and c:FindFirstChild('HumanoidRootPart')
 if not p or not p.Parent or not c or not c.Parent or not h or h.Health<=0 or not r or not r:IsA('BasePart') then return end
 if p:GetAttribute('InRound')~=true or p:GetAttribute('BombTagAFK')==true or h.Sit or h.PlatformStand or r.Anchored then return end
 if c:GetAttribute('Ragdolled')==true or c:GetAttribute('IsRagdoll')==true or p:GetAttribute('HussGamePaused')==true or workspace:GetAttribute('HussGamePaused')==true then return end
 if not Rules.Finite(r.Position) then return end
 return r,h,c
end
local function record(p)
 local s=records[p]
 if not s then s={SwingAt=0,ThrowAt=0,AbilityAt=0,Tokens=10,RateAt=clock(),Links={}};records[p]=s end
 return s
end
local function emit(kind,p,values)
 values=values or {};values.Actor=player(p) and p or (p and p.Character);values.Character=p and p.Character;values.Time=clock();values.Kind=kind
 if type(values.Target)=='table' then values.Target=values.Target.Character end
 if type(values.Attacker)=='table' then values.Attacker=values.Attacker.Character end
 FX:FireAllClients(values)
end
local function reply(p,kind,seq,ok,message,ready)
 if player(p) and p.Parent==Players then
  FX:FireClient(p,{Kind='ActionReply',Action=kind,Request=seq,OK=ok,Message=message,ReadyAt=ready,Time=clock()})
 end
end
local function endAttack(reason)
 local a=attack;attack=nil
 if not a then return end
 if a.Kind=='Throw' then emit('ThrowEnd',a.Owner,{Id=a.Id,Request=a.Request,Result=reason or 'MISS'})
 else emit('SwingEnd',a.Owner,{Id=a.Id,Request=a.Request,Result=reason or 'MISS'}) end
end
local function clearAbility(p,resetCooldown)
 local c=p and p.Character
 if c then c:SetAttribute('HABShieldUntil',0);c:SetAttribute('HABShieldCharge',0);c:SetAttribute('HABSpeedUntil',0);c:SetAttribute('HABSpeedBonus',0) end
 if resetCooldown and p then
  local s=record(p);s.AbilityAt=0;s.SwingAt=0;s.ThrowAt=0;s.Queue=nil
  p:SetAttribute('HABAbilityReadyAt',0);p:SetAttribute('HABSwingReadyAt',0);p:SetAttribute('HABThrowReadyAt',0)
 end
end
function S.SetCarrier(p,ends,lockedUntil,previous,untilTime)
 endAttack('CANCELLED');carrier=p;fuse=ends or 0;lock=lockedUntil or 0;protectedId=previous;protectedUntil=untilTime or 0
 local r,h,c=root(p)
 if c then c:SetAttribute('HABShieldUntil',0);c:SetAttribute('HABShieldCharge',0);c:SetAttribute('BombTagIFrameUntil',0) end
 if p then
  local stamp=c and c:GetAttribute('HussDodgeStartedAt')
  p:SetAttribute('HABSwingUnlockAt',math.max(lock,type(stamp)=='number' and stamp==stamp and stamp+.72 or 0))
 end
end
function S.Stop()
 endAttack('CANCELLED');carrier=nil;fuse=0;lock=0;samples={}
 for p,s in pairs(records) do
  s.Queue=nil
  if not player(p) then records[p]=nil end
 end
end
local function lineClear(a,b,params)
 return (b-a).Magnitude<.01 or workspace:Raycast(a,b-a,params)==nil
end
local function paramsFor(actors)
 local list={}
 for _,p in ipairs(actors or {}) do if p.Character then list[#list+1]=p.Character end end
 -- Players outside the current round must not be accepted as targets or act as query obstructions.
 for _,p in ipairs(Players:GetPlayers()) do if p.Character then list[#list+1]=p.Character end end
 local rp=RaycastParams.new();rp.FilterType=Enum.RaycastFilterType.Exclude;rp.FilterDescendantsInstances=list
 rp.IgnoreWater=true;rp.RespectCanCollide=true
 return rp
end
local function info(value)
 if type(value)=='table' then
  local seq=type(value.Seq)=='number' and value.Seq==value.Seq and value.Seq%1==0 and value.Seq>0 and value.Seq<1e10 and value.Seq or nil
  return seq,Rules.Finite(value.Direction) and value.Direction or nil
 end
 return nil,Rules.Finite(value) and value or nil
end
local function swing(p,value,queued)
 local seq,aim=info(value)
 local now=clock();local r,h,c=root(p);local s=record(p)
 if not r or carrier~=p or now>=fuse then reply(p,'Swing',seq,false,'You must be the active bomb carrier.');return false end
 local stamp=c:GetAttribute('HussDodgeStartedAt')
 -- The authored weave owns the body for .72s. Contact starts only after that
 -- recovery, so every accepted bomb strike can actually show its hit animation.
 local dodgeLock=type(stamp)=='number' and stamp==stamp and stamp+.72 or 0
 local ready=math.max(s.SwingAt,lock,dodgeLock)
 if attack or now<ready then
  if not queued and not attack and ready-now<=.14 then
   s.Queue={Value=value,At=ready,Until=now+.19,Character=c};return false
  end
  reply(p,'Swing',seq,false,now<lock and 'Bomb arming...' or 'Recovering...',ready);return false
 end
 s.Queue=nil;s.SwingAt=now+Config.Swing.Cooldown;p:SetAttribute('HABSwingReadyAt',s.SwingAt)
 local direction=Rules.Direction(r.CFrame.LookVector)
 if aim and aim.Magnitude>.5 and aim.Magnitude<2 then direction=Rules.Turn(direction,Rules.Direction(aim,direction),math.rad(80)) end
 serial=serial+1
 attack={Kind='Swing',Owner=p,Id=serial,Request=seq,Character=c,Created=now,Start=now+Config.Swing.Windup,
  End=now+Config.Swing.Windup+Config.Swing.Window,Initial=direction,Direction=direction,ServerFacing=Rules.Direction(r.CFrame.LookVector),Origin=r.Position,Hit={},LastTick=now}
 reply(p,'Swing',seq,true,nil,s.SwingAt)
 emit('Swing',p,{Id=serial,Request=seq,Direction=direction,Duration=Config.Swing.Cooldown,
  Windup=Config.Swing.Windup,Window=Config.Swing.Window,ContactAt=attack.Start})
 return true
end
local function throw(p,value)
 local seq,aim=info(value)
 local now=clock();local r,h,c=root(p);local s=record(p)
 local stamp=c and c:GetAttribute('HussDodgeStartedAt')
 local dodgeLock=type(stamp)=='number' and stamp==stamp and stamp+.72 or 0
 local ready=math.max(lock,s.ThrowAt,dodgeLock)
 if not r or carrier~=p or now<ready or now>=fuse or attack then reply(p,'Throw',seq,false,'Throw is not ready.',ready);return end
 if not Passes.Has(p,'Throw') then reply(p,'Throw',seq,false,'Bomb Pitcher requires your game pass.');return end
 if not aim or aim.Magnitude<.5 or aim.Magnitude>2 then reply(p,'Throw',seq,false,'Aim ahead before throwing.');return end
 local flat=Rules.Direction(aim)
 if flat:Dot(Rules.Direction(r.CFrame.LookVector))<-.1 then reply(p,'Throw',seq,false,'Face your throw direction.');return end
 local direction=(flat+Vector3.new(0,math.clamp(aim.Unit.Y,-.10,.45),0)).Unit
 local origin=r.Position+direction*1.5+Vector3.new(0,.5,0)
 local rp=paramsFor({p})
 if not lineClear(r.Position,origin,rp) then reply(p,'Throw',seq,false,'Move away from the wall.');return end
 s.Queue=nil;s.ThrowAt=now+Config.Throw.Cooldown;p:SetAttribute('HABThrowReadyAt',s.ThrowAt)
 serial=serial+1
 attack={Kind='Throw',Owner=p,Id=serial,Request=seq,Character=c,Start=now,End=now+Config.Throw.Lifetime,
  Origin=origin,Velocity=direction*Config.Throw.Speed,Last=origin,LastTick=now,Hit={}}
 reply(p,'Throw',seq,true,nil,s.ThrowAt)
 emit('Throw',p,{Id=serial,Request=seq,Origin=origin,Velocity=attack.Velocity,Gravity=Config.Throw.Gravity,Duration=Config.Throw.Lifetime,
  Skin=p:GetAttribute('HussBombId'),Effect=p:GetAttribute('HABPackBombFX')})
end
local function ground(p,r,h,c)
 local rp=paramsFor({p})
 local leg=c:FindFirstChild('Left Leg');local foot=c:FindFirstChild('LeftFoot') or leg or r
 rp.CollisionGroup=foot.CollisionGroup
 local height=math.clamp(h.HipHeight+r.Size.Y*.5+(leg and leg.Size.Y or 0),1.6,12)
 local best
 for _,offset in ipairs({Vector3.zero,Vector3.new(.7,0,0),Vector3.new(-.7,0,0)}) do
  local hit=workspace:Raycast(r.Position+Vector3.new(0,.4,0)+offset,Vector3.new(0,-height-1.2,0),rp)
  if hit and hit.Normal.Y>.45 then best=hit;break end
 end
 return best,rp
end
local function ability(p,value)
 local seq=info(value)
 local now=clock();local r,h,c=root(p);local s=record(p)
 if not r then reply(p,'Ability',seq,false,'Abilities work in an active round or solo practice.');return end
 if now<s.AbilityAt then reply(p,'Ability',seq,false,'Ability cooling down.',s.AbilityAt);return end
 if attack and attack.Owner==p then reply(p,'Ability',seq,false,'Finish your bomb action first.');return end
 local stamp=c:GetAttribute('HussDodgeStartedAt')
 if type(stamp)=='number' and stamp==stamp and now-stamp<.72 then reply(p,'Ability',seq,false,'Finish your dodge first.');return end
 local key=Economy.HABSelectedAbility(p);local def
 for _,d in ipairs(Config.Abilities) do if d.Key==key then def=d;break end end
 if not def then reply(p,'Ability',seq,false,'Choose an ability in the lobby.');return end
 if not Economy.HABCanUseAbility(p,key) then reply(p,'Ability',seq,false,'This ability is not unlocked.');return end
 local mechanic=def.Mechanic or key
 if key=='Shield' and p==carrier then reply(p,'Ability',seq,false,'The bomb carrier cannot use Phase Guard.');return end
 if mechanic=='Leap' then
  local floor,rp=ground(p,r,h,c)
  if not floor or math.abs(r.AssemblyLinearVelocity.Y)>12 then reply(p,'Ability',seq,false,'Skyvault: stand on solid ground.');return end
  -- Three head-clearance tests cover the torso, not only a thin center ray.
  for _,offset in ipairs({Vector3.zero,Vector3.new(.75,0,0),Vector3.new(-.75,0,0)}) do
   if workspace:Raycast(r.Position+offset,Vector3.new(0,5.5,0),rp) then reply(p,'Ability',seq,false,'Skyvault: move out from under the ceiling.');return end
  end
 end
 serial=serial+1
 s.AbilityAt=now+def.Cooldown;p:SetAttribute('HABAbilityReadyAt',s.AbilityAt)
 p:SetAttribute('HABAbility',key)
 local clientLaunch=false
 if key=='Shield' then
  c:SetAttribute('HABShieldUntil',now+def.Duration);c:SetAttribute('HABShieldCharge',1)
 elseif mechanic=='Speed' then
  c:SetAttribute('HABSpeedBonus',def.Bonus);c:SetAttribute('HABSpeedUntil',now+def.Duration)
 elseif mechanic=='Leap' then
  c:SetAttribute('HABLeapAt',now);c:SetAttribute('HABLeapToken',serial)
  local ok,owner=pcall(r.GetNetworkOwner,r)
  clientLaunch=player(p) and ok and owner==p
  if not clientLaunch then
   h:ChangeState(Enum.HumanoidStateType.Freefall)
   local v=r.AssemblyLinearVelocity;r.AssemblyLinearVelocity=Vector3.new(v.X,def.Velocity,v.Z)
  end
 end
 reply(p,'Ability',seq,true,nil,s.AbilityAt)
 emit('Ability',p,{Id=serial,Request=seq,Character=c,Ability=key,Mechanic=mechanic,Effect=def.Effect,Duration=def.Duration or .75,
  Velocity=def.Velocity,Bonus=def.Bonus,Until=now+(def.Duration or .75),Position=r.Position,LaunchOnClient=clientLaunch})
end
local function shieldOrDodge(candidate,now,a,b)
 local c=candidate.Character
 if candidate==carrier then return false end
 local iframe=c:GetAttribute('BombTagIFrameUntil')
 if type(iframe)=='number' and iframe==iframe and iframe>now then
  pcall(Perfect.Try,carrier,candidate,a,b,protectedId,protectedUntil)
  return 'Dodge'
 end
 local shield=c:GetAttribute('HABShieldUntil')
 if type(shield)=='number' and shield==shield and shield>now and c:GetAttribute('HABShieldCharge')==1 then
  c:SetAttribute('HABShieldUntil',0);c:SetAttribute('HABShieldCharge',0)
  emit('ShieldBlock',candidate,{Target=candidate,TargetCharacter=c,Attacker=carrier,AttackerCharacter=carrier and carrier.Character,
   AttackKind=attack and attack.Kind,Id=attack and attack.Id,Position=b});return 'Shield'
 end
 return false
end
function S.Tick(actors,now)
 local previous=samples;local current={}
 for _,p in ipairs(actors) do
  local rr,hh,cc=root(p)
  if rr then current[p]={Position=rr.Position,Direction=Rules.Direction(rr.CFrame.LookVector),Character=cc,At=now,Root=rr,Humanoid=hh} end
 end
 samples=current
 local owner=current[carrier]
 if not owner or now>=fuse then endAttack('CANCELLED');return end
 local r,c=owner.Root,owner.Character
 local rec=record(carrier)
 if rec.Queue then
  local q=rec.Queue
  if now>q.Until or q.Character~=c then rec.Queue=nil
  elseif now>=q.At and not attack then rec.Queue=nil;swing(carrier,q.Value,true) end
 end
 if not player(carrier) and not attack then
  -- Practice NPCs can swing; real players always need an input.
  for _,p in ipairs(actors) do local x=current[p]
   if x and p~=carrier and Rules.Swing(r.Position,x.Position,owner.Direction,Config.Swing) then swing(carrier);break end
  end
 end
 if not attack then return end
 local a=attack
 if a.Character~=c or now<lock or (r.Position-a.Origin).Magnitude>90 then endAttack('CANCELLED');return end
 if now<a.Start then return end
 local rp=paramsFor(actors);local contacts={}
 if a.Kind=='Swing' then
  -- Keep the final fraction of the active window when a server tick straddles
  -- its end. Do not rewind a stale tick or manufacture hits after recovery.
  if now>a.End+.085 then endAttack(a.BlockedBy or 'MISS');return end
  local sampleAt=math.min(now,a.End)
  local dt=math.clamp(now-(a.LastTick or now),0,.08)
  local desired=a.Direction
  if owner.Direction:Dot(a.ServerFacing)<.999 then desired=Rules.Turn(a.Initial,owner.Direction,math.rad(85)) end
  local direction=Rules.Turn(a.Direction,desired,math.rad(540)*dt)
  local prevOwner=previous[carrier]
  for _,p in ipairs(actors) do
   local candidate=current[p]
   if p~=carrier and candidate and not a.Hit[p] and not(p.UserId==protectedId and now<protectedUntil) then
    local torso=candidate.Character:FindFirstChild('UpperTorso') or candidate.Character:FindFirstChild('Torso') or candidate.Root
    local radius=math.clamp(torso.Size.X*.5+.1,.85,1.25)
    local height=math.clamp(torso.Size.Y*.65,1.2,2)
    local result
    local prev=previous[p]
    if prevOwner and prev and prevOwner.Character==c and prev.Character==candidate.Character
     and now-prev.At<=.085 and now-prevOwner.At<=.085
     and (candidate.Position-prev.Position).Magnitude<10 and (owner.Position-prevOwner.Position).Magnitude<10 then
     local span=math.max(.001,now-prev.At)
     local start=math.clamp((a.Start-prev.At)/span,0,1)
     local finish=math.clamp((sampleAt-prev.At)/span,0,1)
     if prev.At<=sampleAt then
      result=Rules.Swept(prevOwner.Position:Lerp(owner.Position,start),prevOwner.Position:Lerp(owner.Position,finish),
       prev.Position:Lerp(candidate.Position,start),prev.Position:Lerp(candidate.Position,finish),
       a.Direction,direction,Config.Swing,radius,height)
     end
    elseif now<=a.End then
     local score=Rules.Swing(owner.Position,candidate.Position,direction,Config.Swing,radius,height)
     if score then result={Score=score,A=owner.Position,B=candidate.Position} end
    end
    -- No wall tags: require both the sampled segment and CURRENT bodies to have clear sight.
    if result and (candidate.Position-owner.Position).Magnitude<Config.Swing.Range+radius+1.5
     and lineClear(owner.Position,candidate.Position,rp) and lineClear(result.A,result.B,rp) then
     contacts[#contacts+1]={p,result.Score,candidate.Position}
    end
   end
  end
  a.Direction=direction;a.LastTick=now
 else
  -- A long suspended server frame has no trustworthy moving-target history.
  if now-(a.LastTick or now)>.15 then endAttack('CANCELLED');return end
  local endAt=math.min(now,a.End)
  local t=math.min(endAt-a.Start,Config.Throw.Lifetime)
  local pos=Rules.Projectile(a.Origin,a.Velocity,Config.Throw.Gravity,t)
  local segmentLength=(pos-a.Last).Magnitude
  local wall=(pos-a.Last).Magnitude>.001 and workspace:Raycast(a.Last,pos-a.Last,rp) or nil
  if wall then
   local fraction=segmentLength>.001 and math.clamp((wall.Position-a.Last).Magnitude/segmentLength,0,1) or 0
   endAt=(a.LastTick or endAt)+(endAt-(a.LastTick or endAt))*fraction
   pos=wall.Position
  end
  for _,p in ipairs(actors) do
   local candidate=current[p]
   if p~=carrier and candidate and not(p.UserId==protectedId and now<protectedUntil) and not a.Hit[p] then
    local from,to=candidate.Position,candidate.Position
    local prev=previous[p]
    if prev and prev.Character==candidate.Character and now-prev.At<=.085
     and (candidate.Position-prev.Position).Magnitude<10 then
     local span=math.max(.001,now-prev.At)
     from=prev.Position:Lerp(candidate.Position,math.clamp(((a.LastTick or now)-prev.At)/span,0,1))
     to=prev.Position:Lerp(candidate.Position,math.clamp((endAt-prev.At)/span,0,1))
    end
    local alpha=Rules.MovingSphere(a.Last,pos,from,to,Config.Throw.Radius)
    if alpha then
     local impact=a.Last:Lerp(pos,alpha);local target=from:Lerp(to,alpha)
     if lineClear(impact,target,rp) and lineClear(pos,candidate.Position,rp) then
      contacts[#contacts+1]={p,alpha,target}
     end
    end
   end
  end
  a.Last=pos;a.LastTick=endAt;a.HitWall=wall~=nil
  if #contacts==0 and (wall or now>=a.End) then endAttack('MISS');return end
 end
 table.sort(contacts,function(x,y) if x[2]==y[2] then return x[1].UserId<y[1].UserId end;return x[2]<y[2] end)
 for _,entry in ipairs(contacts) do
  local p,position=entry[1],entry[3]
  local guard=shieldOrDodge(p,now,r.Position,position)
  if guard=='Shield' then endAttack('BLOCKED');return end
  if guard=='Dodge' then a.Hit[p]=true;a.BlockedBy='DODGED'
  else
   emit('TagHit',carrier,{Id=a.Id,Request=a.Request,Target=p,TargetCharacter=p.Character,
    AttackKind=a.Kind,Direction=Rules.Direction(position-r.Position),Position=position})
   endAttack('HIT');return p
  end
 end
 if a.Kind=='Swing' and now>=a.End then endAttack(a.BlockedBy or 'MISS') end
 if a.Kind=='Throw' and (a.HitWall or now>=a.End) then endAttack('MISS') end
end
function S.Init()
 if started then return end;started=true
 Passes.Init()
 local function setup(p)
  local s=record(p)
  local function character(c)
   clearAbility(p,true)
   local key=Economy.HABSelectedAbility(p)
   p:SetAttribute('HABAbility',key)
  end
  s.Links[#s.Links+1]=p.CharacterAdded:Connect(character)
  s.Links[#s.Links+1]=p:GetAttributeChangedSignal('InRound'):Connect(function()
   clearAbility(p,true)
  end)
  if p.Character then character(p.Character) end
 end
 Players.PlayerAdded:Connect(setup);for _,p in ipairs(Players:GetPlayers()) do setup(p) end
 Players.PlayerRemoving:Connect(function(p)
  local s=records[p];if s then for _,c in ipairs(s.Links) do c:Disconnect() end end
  records[p]=nil;samples[p]=nil;if p==carrier then S.Stop() end
 end)
 Input.OnServerEvent:Connect(function(p,kind,value)
  if type(kind)~='string' or #kind>16 or (kind~='Swing' and kind~='Throw' and kind~='Ability') then return end
  local s=record(p);local now=clock();s.Tokens=math.min(10,s.Tokens+math.max(0,now-s.RateAt)*8);s.RateAt=now
  if s.Tokens<1 then return end;s.Tokens=s.Tokens-1
  if kind=='Swing' then swing(p,value) elseif kind=='Throw' then throw(p,value) else ability(p,value) end
 end)
 print('[HAB V15] Swept bomb hits, animated contact events and server-approved abilities ready.')
end
return S


-- HAB_FUN_9
