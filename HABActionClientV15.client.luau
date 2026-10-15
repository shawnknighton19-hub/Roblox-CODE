--!nonstrict
-- HAB_ACTION_V15. Authored poses, server-authorized gameplay, restrained native geometry feedback.
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
local Animations=require(X:WaitForChild('HABActionAnimationsV15'))
local AbilityEffects=require(X:WaitForChild('HABAbilityEffectsV15'))
local BombSkins=require(RS.BombSkinBuilderV12)
local Skins=require(RS.HussCatalogV11)
local links,poses,missiles={},{},{}
local seenEvents,seenOrder={},{}
local dodgeState=setmetatable({},{__mode="k"})
local live=true;local sequence=0;local predicted={};local nextLocal={};local queued=nil;local lastLeap=nil
local HUD,pose,send
local folder=Instance.new('Folder');folder.Name='HABActionCosmeticsV15';folder.Parent=workspace
local Effects=AbilityEffects.new(folder,me,Input.TouchEnabled)
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
 task.delay(math.max(0,at+Config.Swing.Windup-workspace:GetServerTimeNow()),function()
  if live and c.Parent and r.Parent then Effects:Swing(r,workspace:GetServerTimeNow(),(seq or 1)%3==2) end
 end)
end
send=function(kind,fromBuffer)
 if not live or Input:GetFocusedTextBox() then return end
 if kind=='Ability' and me:GetAttribute('InRound')~=true then openAbilityMenu();return end
 if not inGame() or me:GetAttribute('HABCollectionOpen')==true or me:GetAttribute('HABExpansionOpen')==true or me:GetAttribute('HABModalOwnerV15')~=nil then return end
 local c=me.Character;local r=c:FindFirstChild('HumanoidRootPart')
 if kind~='Ability' and c:GetAttribute('HussBombCarrier')~=true then return end
 local now=workspace:GetServerTimeNow()
 local attr=kind=='Ability' and 'HABAbilityReadyAt' or kind=='Swing' and 'HABSwingReadyAt' or 'HABThrowReadyAt'
 local ready=math.max(tonumber(me:GetAttribute(attr)) or 0,nextLocal[kind] or 0)
 local dodgeStamp=c:GetAttribute('HussDodgeStartedAt')
 if type(dodgeStamp)=='number' then ready=math.max(ready,dodgeStamp+.72) end
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
 predicted[seq]={Character=c,At=now,Kind=kind}
 if kind=='Swing' then swingVisual(me,now,seq)
 elseif kind=='Throw' then pose(me,now,'Throw',seq,{Contact=.06})
 elseif kind=='Ability' then pose(me,now,me:GetAttribute('HABAbility') or Config.DefaultAbility,seq) end
 X.Action:FireServer(kind,{Seq=seq,Direction=aim,At=now})
end
HUD=require(X:WaitForChild('HABCombatHUD'))(send)
local function restore(p)
 for _,j in ipairs(p.Joints) do
  if j.Before and j.Object.Parent and j.Object.Transform==j.Applied then j.Object.Transform=j.Before end
  j.Before,j.Applied=nil,nil
 end
end
local function clearPose(c)
 local p=poses[c];if not p then return end
 restore(p)
 if p.Descendant then p.Descendant:Disconnect() end
 if c:GetAttribute('HABActionPoseUntil')==p.Until then c:SetAttribute('HABActionPoseUntil',nil);c:SetAttribute('HABActionPoseName',nil) end
 poses[c]=nil
end
local function dodging(c,now)
 local record=dodgeState[c]
 if not record then record={Id=nil,Until=0};dodgeState[c]=record end
 local id=c:GetAttribute('MovementActionId')
 if id~=record.Id then
  record.Id=id
  local action=c:GetAttribute('MovementAction')
  if action=='DiveEnd' then record.Until=0
  elseif type(action)=='string' and action:sub(1,4)=='Dive' then record.Until=now+.72 end
 end
 local approved=c:GetAttribute('HussDodgeStartedAt')
 return now<record.Until or (type(approved)=='number' and now>=approved-.1 and now<approved+.72)
end
local function blocked(c,h,r,now)
 if not c.Parent or not h.Parent or h.Health<=0 or not r.Parent or r.Anchored or h.Sit or h.PlatformStand
  or c:GetAttribute('Ragdolled')==true or c:GetAttribute('IsRagdoll')==true then return true end
 local state=h:GetState()
 if state==Enum.HumanoidStateType.Dead or state==Enum.HumanoidStateType.Physics or state==Enum.HumanoidStateType.Ragdoll then return true end
 local owner=Players:GetPlayerFromCharacter(c)
 return dodging(c,now) or c:GetAttribute('HussGamePaused')==true or workspace:GetAttribute('HussGamePaused')==true
  or (owner and (owner:GetAttribute('HussEmotePlaying')~=nil or owner:GetAttribute('HussGamePaused')==true))
end
pose=function(actor,stamp,kind,seq,options)
 local c=char(actor);if not c then return end
 local h=c:FindFirstChildOfClass('Humanoid');local r=c:FindFirstChild('HumanoidRootPart')
 local now=workspace:GetServerTimeNow()
 if not h or not r or blocked(c,h,r,now) then return end
 local name,mirror=Animations.Resolve(kind,seq);if not name then return end
 options=options or {};options.Mirror=mirror
 if kind=='Swing' then options.Duration=Config.Swing.Cooldown;options.Contact=Config.Swing.Windup end
 local duration=Animations.Duration(name,options)
 if now-stamp>=duration then return end
 local previous=poses[c]
 if previous and Animations.Clips[previous.Name].Priority>Animations.Clips[name].Priority and previous.Until>now then return end
 clearPose(c)
 local p={Name=name,Kind=kind,Seq=seq,At=stamp,Until=stamp+duration,Options=options,Joints={},Seen={},Humanoid=h,Root=r,R15=h.RigType==Enum.HumanoidRigType.R15}
 local function add(joint)
  if p.Seen[joint] then return end
  local info=Animations.JointInfo(joint)
  if info then p.Seen[joint]=true;p.Joints[#p.Joints+1]=info end
 end
 for _,joint in ipairs(c:GetDescendants()) do add(joint) end
 p.Descendant=c.DescendantAdded:Connect(add)
 poses[c]=p;c:SetAttribute('HABActionPoseUntil',p.Until);c:SetAttribute('HABActionPoseName',name)
end
link(Run.PreAnimation,function() for _,p in pairs(poses) do restore(p) end end)
link(Run.PreSimulation,function()
 local now=workspace:GetServerTimeNow()
 for c,p in pairs(poses) do
  local sample=Animations.Sample(p.Name,now-p.At,p.Options)
  if not sample or blocked(c,p.Humanoid,p.Root,now) then clearPose(c)
  else
   local v=p.Root.AssemblyLinearVelocity
   local moving=Vector3.new(v.X,0,v.Z).Magnitude>2
   for _,j in ipairs(p.Joints) do
    local joint=j.Object
    if joint.Parent and joint.Enabled then
     local weight=Animations.Weight(sample,j.Role,moving,low())*(p.Options.Strength or 1)
     local turn=Animations.Transform(sample,j.Role,p.R15,low())
     local target=j.Axes:Inverse()*turn*j.Axes
     j.Before=joint.Transform;j.Applied=j.Before:Lerp(target,weight);joint.Transform=j.Applied
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
 removeProjectile(e.Id)
 local p=Instance.new('Part');p.Name='CosmeticThrownBomb';p.Size=Vector3.new(2.25,2.25,2.25);p.Shape=Enum.PartType.Ball
 p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.Color=Color3.fromRGB(28,30,39);p.CFrame=CFrame.new(e.Origin);p.Parent=folder
 local a,b=Instance.new('Attachment'),Instance.new('Attachment');a.Position=Vector3.new(-.3,0,0);b.Position=Vector3.new(.3,0,0);a.Parent=p;b.Parent=p
 local trail=Instance.new('Trail');trail.Name='BombThrowWake';trail.Attachment0=a;trail.Attachment1=b;trail.Lifetime=.12;trail.LightEmission=.7;trail.FaceCamera=true;trail.MinLength=.15;trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.65),NumberSequenceKeypoint.new(1,1)});trail.Color=ColorSequence.new(Color3.fromRGB(255,225,135));trail.Enabled=not low();trail.Parent=p
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
  if e.OK~=true then
   local p=poses[me.Character]
   if p and p.Seq==e.Request then clearPose(me.Character) end
   predicted[e.Request]=nil
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
 if e.Id~=nil then
  local token=e.Kind..':'..tostring(e.Id)
  if seenEvents[token] then return end
  seenEvents[token]=true;seenOrder[#seenOrder+1]=token
  if #seenOrder>256 then seenEvents[table.remove(seenOrder,1)]=nil end
 end
 local c=char(e.Actor)
 if e.Character~=nil and e.Character~=c then return end
 local r=c and c:FindFirstChild('HumanoidRootPart')
 if not r then return end
 -- Gameplay acknowledgements must run even when VFX are reduced, unavailable, or out of view.
 if e.Kind=='Ability' then applyLocalAbility(e,c,r) end
 local cam=workspace.CurrentCamera
 if not cam or ((r.Position-cam.CFrame.Position).Magnitude>180 and e.Actor~=me) then return end
 local prediction=e.Actor==me and e.Request and predicted[e.Request]
 if prediction and prediction.Character~=c then prediction=nil end
 if e.Kind=='Swing' then
  if not(prediction and prediction.Kind=='Swing') then swingVisual(e.Actor,e.Time,e.Request or e.Id) end
 elseif e.Kind=='Throw' then
  if not(prediction and prediction.Kind=='Throw') then pose(e.Actor,e.Time-.06,'Throw',e.Request,{Contact=.06}) end
  sound('Throw',r);newProjectile(e)
 elseif e.Kind=='TagHit' then
  if e.Target and (e.TargetCharacter==nil or e.TargetCharacter==char(e.Target)) then pose(e.Target,e.Time,'Hit',e.Id) end
  Effects:Impact('Hit',r,e.Position or r.Position,e.Time)
 elseif e.Kind=='ShieldBlock' then
  if e.TargetCharacter==nil or e.TargetCharacter==char(e.Target or e.Actor) then pose(e.Target or e.Actor,e.Time,'Block',e.Id) end
  if e.Attacker and (e.AttackerCharacter==nil or e.AttackerCharacter==char(e.Attacker)) then pose(e.Attacker,e.Time,'Hit',e.Id,{Strength=.65}) end
  Effects:Impact('Block',r,e.Position or r.Position,e.Time)
 elseif e.Kind=='Ability' then
  if not(prediction and prediction.Kind=='Ability') then pose(e.Actor,e.Time,e.Ability,e.Request) end
  sound('Ability',r);Effects:Ability(e,r)
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
link(me.CharacterRemoving,function(c) clearPose(c);queued=nil;lastLeap=nil;nextLocal={};predicted={} end)
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
   local trail=m.Part:FindFirstChild('BombThrowWake');if trail then trail.Enabled=not low() end
  end
 end
 Effects:Step(now)
end)
link(script.Destroying,function()
 live=false
 for _,l in ipairs(links) do l:Disconnect() end
 for c in pairs(poses) do clearPose(c) end
 CAS:UnbindAction('HABAbility');CAS:UnbindAction('HABThrow')
 for id in pairs(missiles) do removeProjectile(id) end
 HUD.Destroy();Effects:Destroy();folder:Destroy()
end)
print('[HAB V15] Three strike poses, throw, hit/block reactions and nine ability clips ready.')

