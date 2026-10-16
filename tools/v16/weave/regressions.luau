check(A.Duration==.72,'Exact original movement duration')
check(#exports.States[owner].joints==6,'Complete R6 rig found')
check(#exports.States[r15].joints==13,'Connected R15 joint roles found')
check(#exports.States[owner].feet==2 and #exports.States[r15].feet==2,'Grounding uses terminal feet only')
local restRoot=owner.Character.HumanoidRootPart.CFrame
local restVelocity=owner.Character.HumanoidRootPart.AssemblyLinearVelocity
local signatures={}
local grounded={}
for _,player in ipairs({owner,r15}) do
	local state=exports.States[player]
	local transforms={}
	for _,j in ipairs(state.joints) do transforms[j.motor]=j.motor.Transform end
	local floorY=A.FootHeight(state.joints,state.root,nil,state.feet)
	for action in pairs(A.Directions) do
		reset(player)
		if player==owner then localAction(action) else event.OnClientEvent:Fire(player,action,clock) end
		check(state.started~=nil,'Original action protocol starts '..action)
		check(state.character:GetAttribute('HABWeavePoseStartedAt')==clock,'Server clock marker')
		local minimum,maximum=math.huge,-math.huge
		for i=1,43 do
			tick(1/60)
			local applied={}
			for _,j in ipairs(state.joints) do
				applied[j.motor]=j.motor.Transform
				local finite=true
				for _,n in ipairs({j.motor.Transform:GetComponents()}) do finite=finite and n==n and math.abs(n)<100 end
				assert(finite,'Nonfinite or unbounded pose for '..action..' / '..j.role)
			end
			local y=A.FootHeight(state.joints,state.root,applied,state.feet)
			minimum,maximum=math.min(minimum,y-floorY),math.max(maximum,y-floorY)
			if i==12 and player==owner then
				local root=state.rootJoint.Transform
				local sig=string.format('%.2f/%.2f/%.2f',root.LookVector.X,root.LookVector.Y,root.UpVector.X)
				check(not signatures[sig],'Eight direction silhouettes are distinct');signatures[sig]=true
			end
		end
		check(math.abs(minimum)<.025 and math.abs(maximum)<.025,'Feet stay on bind floor: '..action..' '..minimum..' '..maximum)
		grounded[#grounded+1]={Rig=player==owner and 'R6' or 'R15',Action=action,Minimum=minimum,Maximum=maximum}
		tick(.02)
		check(state.started==nil and state.character:GetAttribute('HABWeavePoseUntil')==nil,'Natural recovery clears ownership')
		for _,j in ipairs(state.joints) do check(nearCF(j.motor.Transform,transforms[j.motor]),'No transform accumulation') end
	end
end
check(nearCF(owner.Character.HumanoidRootPart.CFrame,restRoot),'Physics root CFrame untouched')
check(owner.Character.HumanoidRootPart.AssemblyLinearVelocity==restVelocity,'Movement velocity untouched')
for _,time in ipairs({-1,0,.72,1,math.huge,0/0}) do check(A.Sample('DiveForward',time,false).Weight==0,'Inactive endpoints') end
check(A.Sample('Unknown',.2,false).Weight==0,'Unknown action rejected')
-- The actor starts immediately locally and remote observers catch up to the original server stamp.
reset(owner);localAction('DiveRight');tick(.1)
local state=exports.States[owner]
local predicted=state.started
event.OnClientEvent:Fire(owner,'DiveRight',clock)
check(state.started==predicted,'Local echo never restarts predicted weave')
localAction('DiveEnd');check(state.started==nil,'Original DiveEnd cancellation')
reset(observer);event.OnClientEvent:Fire(observer,'DiveLeft',clock-.21)
check(math.abs(clock-exports.States[observer].started-.21)<1e-8,'Remote latency catches up without slowing physics')
local remoteStart=exports.States[observer].started
event.OnClientEvent:Fire(observer,'DiveBack',clock-.3)
check(exports.States[observer].started==remoteStart,'Older remote packet ignored')
for _,stamp in ipairs({clock-1,clock+1.1,math.huge,0/0}) do event.OnClientEvent:Fire(observer,'DiveForward',stamp) end
check(exports.States[observer].started==remoteStart,'Invalid/stale/future remote packets ignored')
-- Preserve another pose writer and a fresh Animator base; restore only transforms we still own.
reset(owner);localAction('DiveForward');tick(.12)
local joint=state.joints[2].motor
local external=CFrame.Angles(.2,.1,.15);joint.Transform=external
exports.Cancel(state);check(joint.Transform==external,'Never overwrite another pose system')
joint.Transform=CFrame.new()
localAction('DiveForward');tick(.1)
services.RunService.PreAnimation:Fire()
local animatorPose=CFrame.Angles(.15,0,0);joint.Transform=animatorPose
services.RunService.PreSimulation:Fire()
exports.Cancel(state);check(joint.Transform==animatorPose,'Restores fresh Animator result')
joint.Transform=CFrame.new()
-- Newer server-approved actions win visually; delayed older actions cannot stomp a new weave.
reset(owner);localAction('DiveLeft');tick(.1)
local startStamp=state.stamp
owner.Character:SetAttribute('HABActionPoseStartedAt',startStamp-.1);owner.Character:SetAttribute('HABActionPoseUntil',clock+1)
tick(.01);check(state.started~=nil,'Older action yields to newer weave')
owner.Character:SetAttribute('HABActionPoseStartedAt',clock);tick(.01)
check(state.started==nil,'New accepted attack can be seen even during physical dodge')
-- Ragdoll, round pause, anchor, death and script shutdown all surrender joints.
for _,reason in ipairs({'Ragdolled','IsRagdoll','PlatformStand','Sit','Anchored','Paused','FeatureOff','Dead'}) do
	reset(owner);localAction('DiveBack');tick(.1)
	if reason=='Ragdolled' or reason=='IsRagdoll' then owner.Character:SetAttribute(reason,true)
	elseif reason=='PlatformStand' or reason=='Sit' then owner.Character.Humanoid[reason]=true
	elseif reason=='Anchored' then owner.Character.HumanoidRootPart.Anchored=true
	elseif reason=='Paused' then workspace:SetAttribute('HussGamePaused',true)
	elseif reason=='FeatureOff' then workspace:SetAttribute('HussDodgeV5',false)
	else owner.Character.Humanoid.Health=0;owner.Character.Humanoid.Died:Fire() end
	tick(.01);check(state.started==nil,'Safe interruption: '..reason)
end
reset(owner)
-- Modern constraint rigs use the same joint transforms; duplicate events must not double-apply.
local j=state.joints[1].motor;j.ClassName='AnimationConstraint'
local before=#state.joints;owner.Character.DescendantAdded:Fire(j)
check(#state.joints==before,'No duplicated joints after streaming event')
localAction('DiveRight');tick(.12);check(not nearCF(j.Transform,CFrame.new()),'AnimationConstraint posed')
localAction('DiveEnd');j.ClassName='Motor6D'
-- Delayed character construction and stale old-life packets.
reset(observer);local old=observer.Character;observer.CharacterRemoving:Fire(old)
check(exports.States[observer]==nil,'Respawn disposes old state')
local replacement=newCharacter('Replacement',false).Character
delayTasks=true;observer.Character=replacement;observer.CharacterAdded:Fire(replacement)
local birth=clock
event.OnClientEvent:Fire(observer,'DiveForward',birth-.01)
check(exports.Players[observer].pending==nil,'Old-life packet rejected after respawn')
event.OnClientEvent:Fire(observer,'DiveForward',birth+.01)
check(exports.Players[observer].pending~=nil,'Valid event buffered while rig assembles')
clock+=.1;delayTasks=false;flushTasks()
check(exports.States[observer].character==replacement and exports.States[observer].started~=nil,'Buffered event applied to correct life')
-- A delayed setup for a removed character must never reconnect to its former player.
local ghost=newCharacter('Ghost',false);delayTasks=true
playerService.PlayerAdded:Fire(ghost);playerService.PlayerRemoving:Fire(ghost)
delayTasks=false;flushTasks();check(exports.States[ghost]==nil,'Removed pending rig cannot resurrect')
script.Destroying:Fire()
check(next(exports.States)==nil and next(exports.Players)==nil,'Destroy disposes all states and owners')
for _,s in ipairs({services.RunService.PreAnimation,services.RunService.PreSimulation,event.OnClientEvent}) do
	for _,connection in ipairs(s.list) do check(not connection.Connected,'Disconnect global signal on destroy') end
end
print('V16 weave: '..assertions..' assertions passed')
print('GROUNDING_JSON:'..json(grounded))
