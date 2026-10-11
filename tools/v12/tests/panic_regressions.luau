
local checks=0
local function check(value,message) checks+=1;assert(value,message) end
local function tick(dt)
 clock+=dt or .04
 services.RunService.PreAnimation:Fire()
 services.RunService.PreSimulation:Fire(dt or .04)
end
local function state(p) return panicExports.states[p.Character] end
local function carrier(p,value) p.Character:SetAttribute('HussBombCarrier',value) end
local function moving(p,speed) p.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.new(speed or 32,0,0) end
local function visibleDrops()
 local total=0
 for _,o in ipairs(panicExports.folder:GetChildren()) do if o.Transparency<1 then total+=1 end end
 return total
end
local function originals(p)
 local all={}
 for _,object in ipairs(p.Character:GetDescendants()) do if object:IsA('Motor6D') then all[object]={c0=object.C0,transform=object.Transform} end end
 return all
end
local function unchanged(base)
 for motor,record in pairs(base) do check(nearCF(motor.C0,record.c0),'C0 untouched');check(nearCF(motor.Transform,record.transform),'Transform restored') end
end
check(state(owner)~=nil and state(r15)~=nil,'R6 and R15 characters tracked on startup')
check(#state(owner).joints==4,'R6 only torso/neck/arms')
check(#state(r15).joints==6,'R15 only waist/neck/arms/elbows')
local baseline=originals(owner)
moving(owner);tick()
check(panicExports.allocated()==0,'noncarrier allocates no particles')
unchanged(baseline)
carrier(owner,true);tick(.08)
check(panicExports.allocated()==12,'carrier bounded twelve-drop pool')
check(visibleDrops()==2,'paired tears emitted from eyes')
local first=state(owner).joints[1]
check(first.base and not nearCF(first.motor.Transform,first.base),'carrier upper body pose applied')
for motor,record in pairs(baseline) do
 check(nearCF(motor.C0,record.c0),'panic never changes C0')
 if motor.Name:find('Hip',1,true) then check(nearCF(motor.Transform,record.transform),'legs stay owned by run animation') end
end
local root=owner.Character.HumanoidRootPart
local rootCF=root.CFrame
local originalSpeed=owner.Character.Humanoid.WalkSpeed
for n=1,240 do tick(1/60);check(visibleDrops()<=12,'pool emission bounded during sustained run') end
check(root.CFrame==rootCF and owner.Character.Humanoid.WalkSpeed==originalSpeed,'panic never changes root or speed')
services.RunService.PreAnimation:Fire()
unchanged(baseline)
services.RunService.PreSimulation:Fire(.04)
carrier(owner,false)
unchanged(baseline)
check(panicExports.allocated()==0 and #panicExports.folder:GetChildren()==0,'losing bomb immediately clears tear pool')
carrier(owner,true);tick()
local localState=state(owner)
owner.Character:SetAttribute('MovementAction','DiveLeft')
owner.Character:SetAttribute('MovementActionId',1)
check(not localState.drops and localState.weight==0,'local dodge immediately cancels pose and tears')
local otherPose=CFrame.Angles(.3,.4,.2)
first.motor.Transform=otherPose
carrier(owner,false)
check(first.motor.Transform==otherPose,'losing bomb during dodge does not overwrite dodge Transform')
first.motor.Transform=baseline[first.motor].transform
carrier(owner,true)
tick(.1)
check(not localState.drops,'panic yields during dodge')
owner.Character:SetAttribute('MovementAction','DiveEnd')
owner.Character:SetAttribute('MovementActionId',2)
tick(.1);check(not localState.drops,'early DiveEnd does not steal recovery')
tick(.55);check(localState.drops~=nil,'panic resumes after local dodge duration')
owner.Character:SetAttribute('BombTagIFrameUntil',clock+.45)
check(not localState.drops,'authoritative immunity immediately excludes panic')
tick(.46)
owner.Character:SetAttribute('BombTagIFrameUntil',0)
check(not localState.drops,'cleared immunity does not lose full dodge animation exclusion')
tick(.25);check(not localState.drops,'panic excludes .71-second recovery')
tick(.02);check(localState.drops~=nil,'panic resumes after .72-second recovery')
-- Remote viewer follows broadcast age, rejecting malformed timestamps.
carrier(observer,true);moving(observer);tick()
local remoteState=state(observer)
event.OnClientEvent:Fire(observer,'DiveRight',clock-.2)
check(not remoteState.drops,'remote dodge broadcast cancels spectator pose')
tick(.50);check(not remoteState.drops,'spectator keeps remaining .52-second dodge interval')
tick(.03);check(remoteState.drops~=nil,'spectator pose resumes at transmitted dodge end')
local before=remoteState.dodgeUntil
event.OnClientEvent:Fire(observer,'DiveRight',clock+5)
event.OnClientEvent:Fire(observer,'DiveRight',0/0)
event.OnClientEvent:Fire(observer,'DiveRight',clock-3)
event.OnClientEvent:Fire(observer,'FakeDive',clock)
check(remoteState.dodgeUntil==before,'invalid action/timestamps do not change pose state')
-- R15, animation resets and lifecycle exclusions.
carrier(owner,false);carrier(observer,false);carrier(r15,true);moving(r15);tick()
check(state(r15).drops~=nil,'R15 carrier renders tears')
local r15Baseline={}
for _,j in ipairs(state(r15).joints) do r15Baseline[j.motor]=j.base end
for _,attribute in ipairs({'Ragdolled','IsRagdoll','HussGamePaused'}) do
 r15.Character:SetAttribute(attribute,true);tick();check(not state(r15).drops,attribute..' blocks panic')
 r15.Character:SetAttribute(attribute,false);tick();check(state(r15).drops~=nil,attribute..' restoration resumes')
end
for _,mode in ipairs({Enum.HumanoidStateType.Dead,Enum.HumanoidStateType.Ragdoll,Enum.HumanoidStateType.Physics,Enum.HumanoidStateType.Seated}) do
 r15.Character.Humanoid.State=mode;tick();check(not state(r15).drops,'humanoid exclusion')
end
r15.Character.Humanoid.State=Enum.HumanoidStateType.Running;tick()
for _,property in ipairs({'Sit','PlatformStand'}) do
 r15.Character.Humanoid[property]=true;tick();check(not state(r15).drops,property..' exclusion')
 r15.Character.Humanoid[property]=false;tick()
end
r15.Character.HumanoidRootPart.Anchored=true;tick();check(not state(r15).drops,'anchored root excluded')
r15.Character.HumanoidRootPart.Anchored=false
r15:SetAttribute('HussEmotePlaying','emote_wave');tick();check(not state(r15).drops,'emote C0 owner has priority')
r15:SetAttribute('HussEmotePlaying',nil);tick();check(state(r15).drops~=nil,'emote end resumes panic')
owner:SetAttribute('HussReducedMotion',true);tick();check(panicExports.allocated()==0,'local reduced motion clears every carrier')
owner:SetAttribute('HussReducedMotion',false);workspace:SetAttribute('HussReducedMotion',true);tick();check(panicExports.allocated()==0,'world reduced motion blocks every carrier')
workspace:SetAttribute('HussReducedMotion',false);tick()
workspace.CurrentCamera.CFrame=CFrame.new(500,0,0);tick();check(panicExports.allocated()==0,'offscreen range culls effects')
workspace.CurrentCamera.CFrame=CFrame.new(0,8,8);tick();check(state(r15).drops~=nil,'return to range reuses live state')
r15.Character.Humanoid.Health=0;r15.Character.Humanoid.Died:Fire();check(panicExports.allocated()==0,'death immediately cleans pooled geometry')
r15.Character.Humanoid.Health=100;carrier(r15,false)
-- Practice bot folder creation/removal and server C0 locomotion are supported.
local bots=Instance.new('Folder',workspace);bots.Name='HussPracticeBots';workspace.ChildAdded:Fire(bots)
local npc=newCharacter('PracticeBot',false)
local bot=npc.Character;bot:SetAttribute('HussPracticeBot',true);bot:SetAttribute('HussBombCarrier',true);bot.Parent=bots
bots.ChildAdded:Fire(bot)
check(panicExports.states[bot]~=nil,'practice bot discovered without whole-workspace scan')
tick();check(panicExports.states[bot].drops~=nil,'practice bot gets carrier pose and tears')
local botState=panicExports.states[bot]
local botJoint=botState.joints[1]
local newC0=CFrame.Angles(.2,.3,.1)
botJoint.motor.C0=newC0;tick()
check(botJoint.motor.C0==newC0,'server bot locomotion C0 not overwritten')
bot:SetAttribute('HussDodgeStartedAt',clock);tick();check(not botState.drops,'bot dodge timestamp exclusion')
tick(.73);check(botState.drops~=nil,'stale bot MovementAction does not lock panic forever')
-- New avatar parts are picked up; removed joints/heads are restored and stop emission.
local head=bot.Head
bot.DescendantRemoving:Fire(head);head.Parent=nil
check(not botState.drops and botState.head==nil,'streamed-out head clears effect')
head.Parent=bot;bot.DescendantAdded:Fire(head);tick()
check(botState.head==head and botState.drops~=nil,'head streaming back restores supported rig')
local motor=botState.joints[1].motor
local base=botState.joints[1].base
bot.DescendantRemoving:Fire(motor)
check(not base or nearCF(motor.Transform,base),'removed joint restored before untracking')
check(#botState.joints==3,'removed joint not retained')
-- Simulate transient duplicated carrier attributes: total pool still capped.
carrier(owner,true);carrier(observer,true);carrier(r15,true);tick()
check(panicExports.allocated()<=36,'global pool cap bounds malformed/transient multiple carriers')
for _,part in ipairs(panicExports.folder:GetChildren()) do
 check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,'all tears have zero collision/query effect')
end
workspace.ChildRemoved:Fire(bots);bots.Parent=nil
check(not panicExports.states[bot] and not panicExports.botFolders[bots],'practice session removal fully unbinds state')
-- Respawn/player removal/new characters get fresh state.
local old=observer.Character
observer.CharacterRemoving:Fire(old)
check(not panicExports.states[old],'CharacterRemoving cleans old state')
local replacement=newCharacter('ObserverRespawn',true).Character
observer.Character=replacement;observer.CharacterAdded:Fire(replacement)
check(panicExports.states[replacement]~=nil,'respawn binds fresh state')
replacement:SetAttribute('HussBombCarrier',true);tick()
replacement.Parent=nil;replacement.AncestryChanged:Fire()
check(not panicExports.states[replacement],'detached character disposed')
playerService.PlayerRemoving:Fire(owner)
check(not panicExports.players[owner] and not state(owner),'PlayerRemoving clears bindings and pose')
local count=0
for _,s in ipairs(allSignals) do for _,c in ipairs(s.list) do if c.Connected then count+=1 end end end
check(count>0,'lifecycle listeners exist before shutdown')
script.Destroying:Fire()
check(next(panicExports.states)==nil and next(panicExports.players)==nil and next(panicExports.botFolders)==nil,'shutdown clears all tracking')
check(panicExports.allocated()==0 and panicExports.folder.Parent==nil,'shutdown destroys all geometry')
local live=0
for _,s in ipairs(allSignals) do for _,c in ipairs(s.list) do if c.Connected then live+=1 end end end
check(live==0,'all client connections disconnected on destroy')
print('CarrierPanicV12 runtime checks: '..checks..' passed (mock lifecycle/math; not Roblox rendering or Animator).')
