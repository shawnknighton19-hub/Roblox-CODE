--!nonstrict
-- HAB_PLAY_POLISH_8. Immediate cosmetic swing; server alone accepts the hit and ability.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Input=game:GetService('UserInputService')
local CAS=game:GetService('ContextActionService')
local Run=game:GetService('RunService')
local Debris=game:GetService('Debris')
local SoundService=game:GetService('SoundService')
local me=Players.LocalPlayer
local X=RS:WaitForChild('HABExpansion')
local Config=require(X.Config)
local Rules=require(X.CombatRules)
local Pack=RS:WaitForChild('HABHalloween')
local Render=require(Pack.Renderer)
local BombSkins=require(RS.BombSkinBuilderV12)
local Skins=require(RS.HussCatalogV11)
local links,poses,missiles,shields={},{},{},{}
local live=true;local sequence=0;local predicted={};local nextLocal={};local queued=nil;local lastLeap=nil
local HUD,pose,send
local folder=Instance.new('Folder');folder.Name='HABActionCosmetics';folder.Parent=workspace
local function link(event,fn) local l=event:Connect(fn);links[#links+1]=l;return l end
local function low() return me:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true end
local function char(actor)
 if typeof(actor)~='Instance' then return nil end
 return actor:IsA('Player') and actor.Character or actor:IsA('Model') and actor or nil
end
local function sound(key,parent)
 if me:GetAttribute('HussSFXMuted')==true then return end
 local ids={Swing=Config.Audio.SwingId,Throw=Config.Audio.ThrowId,Ability=Config.Audio.AbilityId}
 local fallback={Swing='rbxasset://sounds/action_get_up.mp3',Throw='rbxasset://sounds/action_get_up.mp3',Ability='rbxasset://sounds/action_jump.mp3'}
 local id=ids[key]
 local s=Instance.new('Sound');s.SoundId=id and id>0 and ('rbxassetid://'..id) or fallback[key]
 s.Volume=.13*math.clamp(me:GetAttribute('HussSFXVolume') or .8,0,1);s.PlaybackSpeed=key=='Throw' and .85 or 1.22
 s.RollOffMaxDistance=65;s.RollOffMinDistance=8;s.Parent=parent or SoundService;s:Play();Debris:AddItem(s,3)
end
local function play(id,where,size,offset,follow)
 if not id or id=='' or low() then return end
 local ok,err=pcall(Render.Play,id,where,size*(Config.VFX.AbilityScale or 1.35),offset,follow,.09,true)
 if not ok then warn('[HAB Action FX] '..tostring(err)) end
end
local function inGame()
 local c=me.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local r=c and c:FindFirstChild('HumanoidRootPart')
 return me:GetAttribute('InRound')==true and h and r and h.Health>0 and not r.Anchored
end
local function openAbilityMenu()
 me:SetAttribute('HABExpansionTab','ABILITIES')
 me:SetAttribute('HABExpansionRequest',(me:GetAttribute('HABExpansionRequest') or 0)+1)
end
local function swingVisual(actor,at,seq)
 local c=char(actor);local r=c and c:FindFirstChild('HumanoidRootPart')
 if not r then return end
 pose(actor,at,'Swing',seq)
 sound('Swing',r)
 task.delay(Config.Swing.Windup,function()
  if live and c.Parent and r.Parent then play('combat_00001',r.CFrame*CFrame.new(0,.25,-2.7),3.1) end
 end)
end
send=function(kind,fromBuffer)
 if not live or Input:GetFocusedTextBox() then return end
 if kind=='Ability' and me:GetAttribute('InRound')~=true then openAbilityMenu();return end
 if not inGame() or me:GetAttribute('HABCollectionOpen')==true or me:GetAttribute('HABExpansionOpen')==true then return end
 local c=me.Character;local r=c:FindFirstChild('HumanoidRootPart')
 if kind~='Ability' and c:GetAttribute('HussBombCarrier')~=true then return end
 local now=workspace:GetServerTimeNow()
 local attr=kind=='Ability' and 'HABAbilityReadyAt' or kind=='Swing' and 'HABSwingReadyAt' or 'HABThrowReadyAt'
 local ready=math.max(tonumber(me:GetAttribute(attr)) or 0,nextLocal[kind] or 0)
 if kind=='Swing' then ready=math.max(ready,tonumber(me:GetAttribute('HABSwingUnlockAt')) or 0) end
 if now<ready then
  if kind=='Swing' and not fromBuffer and ready-now<=.14 then queued={At=ready,End=now+.2,Character=c} end
  return
 end
 if kind=='Ability' and (me:GetAttribute('HABAbility') or Config.DefaultAbility)=='Shield' and c:GetAttribute('HussBombCarrier') then
  HUD.Notice('Phase Guard cannot protect the bomb carrier.');return
 end
 sequence=sequence+1;local seq=sequence
 local cam=workspace.CurrentCamera
 local aim=kind=='Throw' and cam and cam.CFrame.LookVector or r.CFrame.LookVector
 nextLocal[kind]=now+(kind=='Swing' and Config.Swing.Cooldown or .35)
 HUD.Pending(kind,nextLocal[kind])
 if kind=='Swing' then
  predicted[seq]={Character=c,At=now};swingVisual(me,now,seq)
 end
 X.Action:FireServer(kind,{Seq=seq,Direction=aim,At=now})
end
HUD=require(X:WaitForChild('HABCombatHUD'))(send)
local function restore(p)
 for _,j in ipairs(p.Joints) do
  if j.Object.Parent and j.Applied and j.Object.Transform==j.Applied then j.Object.Transform=j.Before end
  j.Applied=nil
 end
end
pose=function(actor,stamp,kind,seq)
 local c=char(actor);if not c then return end
 local h=c:FindFirstChildOfClass('Humanoid');if not h or h.Health<=0 then return end
 if poses[c] then restore(poses[c]) end
 local left=kind=='Swing' and (seq or 1)%2==0
 local joints={}
 for _,o in ipairs(c:GetDescendants()) do
  local motor=o:IsA('Motor6D');local constraint=o:IsA('AnimationConstraint')
  if motor or constraint then
   local connected=motor and o.Part1 or (constraint and o.Attachment1 and o.Attachment1.Parent)
   local basis=motor and o.C0 or (constraint and o.Attachment0 and o.Attachment0.CFrame)
   if connected and basis then
    local name=o.Name:lower():gsub('%s','')
    local side=left and 'left' or 'right'
    local role=name:find(side..'shoulder',1,true) and 'Shoulder' or name:find(side..'elbow',1,true) and 'Elbow'
    if not role and constraint then
     local limb=left and 'Left' or 'Right'
     role=connected.Name==limb..'UpperArm' and 'Shoulder' or connected.Name==limb..'LowerArm' and 'Elbow'
    end
    if role then joints[#joints+1]={Object=o,Role=role,Axes=basis.Rotation} end
   end
  end
 end
 poses[c]={At=stamp,Kind=kind,Seq=seq,Joints=joints,Humanoid=h,Side=left and -1 or 1}
end
link(Run.PreAnimation,function() for _,p in pairs(poses) do restore(p) end end)
link(Run.PreSimulation,function()
 local now=workspace:GetServerTimeNow()
 for c,p in pairs(poses) do
  local age=now-p.At;local total=p.Kind=='Swing' and Config.Swing.Cooldown or .48
  if not c.Parent or p.Humanoid.Health<=0 or age>total then restore(p);poses[c]=nil
  else
   local wind=Config.Swing.Windup
   local strike=math.clamp((age-wind)/.13,0,1)
   local recovery=1-math.clamp((age-wind-.17)/math.max(.05,total-wind-.17),0,1)
   local entry=math.clamp(age/math.max(.02,wind),0,1)
   local weight=entry*recovery
   for _,j in ipairs(p.Joints) do
    local joint=j.Object
    if joint.Parent then
     local turn
     if j.Role=='Elbow' then turn=CFrame.Angles(-.75*(1-strike)*weight,0,0)
     elseif p.Kind=='Throw' then turn=CFrame.Angles(math.rad(-110+75*strike)*weight,.18*weight,-.2*weight)
     else turn=CFrame.Angles((-.38-.85*strike)*weight,(-.35+.95*strike)*p.Side*weight,(.5-1.1*strike)*p.Side*weight) end
     j.Before=joint.Transform
     local delta=j.Axes:Inverse()*turn*j.Axes
     j.Applied=j.Before:Lerp(CFrame.identity,.65*weight)*delta
     joint.Transform=j.Applied
    end
   end
  end
 end
end)
local function removeProjectile(id)
 local m=missiles[id];if not m then return end
 for _,entry in ipairs(m.Hidden or {}) do if entry.Object.Parent then entry.Object[entry.Property]=entry.Value end end
 m.Part:Destroy();missiles[id]=nil
end
local function newProjectile(e)
 local p=Instance.new('Part');p.Name='CosmeticThrownBomb';p.Size=Vector3.new(2.25,2.25,2.25);p.Shape=Enum.PartType.Ball
 p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.Color=Color3.fromRGB(28,30,39);p.CFrame=CFrame.new(e.Origin);p.Parent=folder
 local skin=Skins.ById[e.Skin] or Skins.ById[Skins.Defaults.Bombs]
 pcall(BombSkins.Apply,p,skin,{Preview=true})
 local locals={}
 for _,o in ipairs(p:GetDescendants()) do if o:IsA('BasePart') then locals[#locals+1]={o,p.CFrame:ToObjectSpace(o.CFrame)} end end
 local hidden={};local c=char(e.Actor);local carried=c and c:FindFirstChild('ActiveBomb')
 if carried then
  local function hide(o)
   local property=o:IsA('BasePart') and 'LocalTransparencyModifier' or o:IsA('BillboardGui') and 'Enabled' or nil
   if property then hidden[#hidden+1]={Object=o,Property=property,Value=o[property]};o[property]=property=='LocalTransparencyModifier' and 1 or false end
  end
  hide(carried);for _,o in ipairs(carried:GetDescendants()) do hide(o) end
 end
 missiles[e.Id]={Part=p,Locals=locals,Event=e,At=e.Time,FXAt=0,Hidden=hidden}
end
local function applyLocalAbility(e,c,r)
 if e.Actor~=me or e.Character~=c then return end
 local now=workspace:GetServerTimeNow()
 if (e.Mechanic or e.Ability)=='Speed' and type(e.Until)=='number' and now<e.Until then
  -- This is the existing movement controller's modifier, populated ONLY after server approval.
  c:SetAttribute('HABSpeedUntil',e.Until);c:SetAttribute('HABSpeedBonus',math.clamp(tonumber(e.Bonus) or 6,0,6))
 elseif (e.Mechanic or e.Ability)=='Leap' and e.LaunchOnClient and e.Id~=lastLeap and now-e.Time<.65 then
  local h=c:FindFirstChildOfClass('Humanoid')
  if not h or h.Health<=0 or r.Anchored or h.Sit then return end
  lastLeap=e.Id
  -- One owner-applied launch. Ordinary Jumping stays disabled; no server/client double impulse.
  h:ChangeState(Enum.HumanoidStateType.Freefall)
  local v=r.AssemblyLinearVelocity
  r.AssemblyLinearVelocity=Vector3.new(v.X,math.clamp(tonumber(e.Velocity) or 72,30,85),v.Z)
 end
end
link(X.FX.OnClientEvent,function(e)
 if type(e)~='table' or type(e.Kind)~='string' then return end
 if e.Kind=='ActionReply' then
  HUD.Reply(e)
  if type(e.ReadyAt)=='number' then nextLocal[e.Action]=e.ReadyAt elseif e.OK~=true then nextLocal[e.Action]=0 end
  if e.OK~=true and e.Action=='Swing' then
   local p=poses[me.Character]
   if p and p.Seq==e.Request then restore(p);poses[me.Character]=nil end
  end
  return
 end
 if e.Kind=='Notice' then HUD.Notice(tostring(e.Message or ''));return end
 if type(e.Time)~='number' or math.abs(workspace:GetServerTimeNow()-e.Time)>3 then return end
 if e.Kind=='ThrowEnd' then removeProjectile(e.Id);return end
 if e.Kind=='SwingEnd' then
  if e.Actor==me and e.Result~='HIT' and e.Result~='CANCELLED' then
   HUD.Notice(e.Result=='BLOCKED' and 'BLOCKED' or e.Result=='DODGED' and 'DODGED' or 'MISS',nil,.42)
  end
  return
 end
 if e.Kind=='TagHit' and e.Actor==me then HUD.Hit() end
 local c=char(e.Actor);local r=c and c:FindFirstChild('HumanoidRootPart')
 if not r then return end
 -- Gameplay acknowledgements must run even when VFX are reduced, unavailable, or out of view.
 if e.Kind=='Ability' then applyLocalAbility(e,c,r) end
 local cam=workspace.CurrentCamera
 if not cam or ((r.Position-cam.CFrame.Position).Magnitude>180 and e.Actor~=me) then return end
 if e.Kind=='Swing' then
  if not(e.Actor==me and e.Request and predicted[e.Request]) then swingVisual(e.Actor,e.Time,e.Request or e.Id) end
 elseif e.Kind=='Throw' then pose(e.Actor,e.Time,'Throw',e.Request);sound('Throw',r);newProjectile(e)
 elseif e.Kind=='TagHit' then play('combat_00107',e.Position,3.2)
 elseif e.Kind=='ShieldBlock' then play('combat_00094',e.Position,4.7)
 elseif e.Kind=='Ability' then
  sound('Ability',r);play(e.Effect,r,e.Ability=='Shield' and 5.8 or 4.5,Vector3.new(0,-.5,0),true)
  if e.Ability=='Shield' and not low() then
   local orb=Instance.new('Part');orb.Name='PhaseGuardCosmetic';orb.Shape=Enum.PartType.Ball;orb.Size=Vector3.new(6,6,6);orb.Material=Enum.Material.ForceField;orb.Transparency=.72
   orb.Color=Color3.fromRGB(94,226,255);orb.Anchored=true;orb.CanCollide=false;orb.CanTouch=false;orb.CanQuery=false;orb.Parent=folder
   shields[#shields+1]={Part=orb,Root=r,Character=c,Until=e.Until or e.Time+e.Duration}
  end
 end
end)
local function action(name,state)
 if state~=Enum.UserInputState.Begin or Input:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
 if name=='HABAbility' then
  if me:GetAttribute('InRound')~=true then openAbilityMenu() else send('Ability') end
 else send('Throw') end
 return Enum.ContextActionResult.Sink
end
CAS:BindActionAtPriority('HABAbility',action,false,2100,Enum.KeyCode.Q,Enum.KeyCode.ButtonY)
CAS:BindActionAtPriority('HABThrow',action,false,2100,Enum.KeyCode.R,Enum.KeyCode.ButtonR1)
link(Input.InputBegan,function(i,processed)
 if processed or Input:GetFocusedTextBox() then return end
 if i.UserInputType==Enum.UserInputType.MouseButton1 or i.KeyCode==Enum.KeyCode.ButtonR2 then send('Swing') end
end)
link(me.CharacterRemoving,function() queued=nil;lastLeap=nil;nextLocal={};predicted={} end)
link(me:GetAttributeChangedSignal('InRound'),function() queued=nil;nextLocal={} end)
link(Run.RenderStepped,function()
 local now=workspace:GetServerTimeNow()
 if queued then
  local q=queued
  if q.Character~=me.Character or now>q.End then queued=nil
  elseif now>=q.At then queued=nil;send('Swing',true) end
 end
 for id,p in pairs(predicted) do if now-p.At>2 then predicted[id]=nil end end
 for id,m in pairs(missiles) do
  local e=m.Event;local age=now-e.Time
  if age>e.Duration+.25 or not m.Part.Parent then removeProjectile(id)
  else
   local pos=Rules.Projectile(e.Origin,e.Velocity,e.Gravity,math.max(0,age))
   m.Part.CFrame=CFrame.new(pos)*CFrame.Angles(age*12,age*8,0)
   for _,o in ipairs(m.Locals) do if o[1].Parent then o[1].CFrame=m.Part.CFrame*o[2] end end
   if not low() and now>m.FXAt then m.FXAt=now+.16;play(e.Effect,pos,2.2) end
  end
 end
 for i=#shields,1,-1 do
  local s=shields[i]
  if not s.Root.Parent or now>s.Until or (s.Character:GetAttribute('HABShieldCharge') or 0)==0 or low() then s.Part:Destroy();table.remove(shields,i)
  else s.Part.CFrame=s.Root.CFrame;s.Part.Transparency=.72+math.sin(now*7)*.045 end
 end
end)
link(script.Destroying,function()
 live=false
 for _,l in ipairs(links) do l:Disconnect() end
 for _,p in pairs(poses) do restore(p) end
 CAS:UnbindAction('HABAbility');CAS:UnbindAction('HABThrow')
 for id in pairs(missiles) do removeProjectile(id) end
 HUD.Destroy();folder:Destroy()
end)
print('[HAB Polish] Responsive swing animation, ability picker and large action buttons ready.')


-- HAB_FUN_9
