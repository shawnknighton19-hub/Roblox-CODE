--!nonstrict
-- V16: authored grounded shoulder slips, lateral steps and braced back dodges.
-- Replaces DodgeWeaveV5 only. Original SnappyMovement remains the sole physics owner.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local me=Players.LocalPlayer
local Animation=require(ReplicatedStorage:WaitForChild("HABWeaveAnimationsV16"))
local remote=ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("DodgeIFrameRequest")
local active,players,connections={},{},{}
local stopped=false
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function restore(state)
	for _,j in ipairs(state.joints) do
		if j.base then
			if j.motor.Parent and j.motor.Transform==j.applied then j.motor.Transform=j.base end
			j.base,j.applied=nil,nil
		end
	end
end
local function cancel(state)
	restore(state)
	if state.character:GetAttribute("HABWeavePoseStartedAt")==state.stamp then
		state.character:SetAttribute("HABWeavePoseUntil",nil)
		state.character:SetAttribute("HABWeavePoseStartedAt",nil)
		state.character:SetAttribute("HABWeavePoseDirection",nil)
	end
	state.started,state.stamp=nil,nil
end
local function blocked(state)
	local h,c,r=state.humanoid,state.character,state.root
	if not c.Parent or not h.Parent or h.Health<=0 or not r.Parent or r.Anchored then return true end
	if state.player:GetAttribute("HussGamePaused")==true or workspace:GetAttribute("HussGamePaused")==true then return true end
	if c:GetAttribute("Ragdolled")==true or c:GetAttribute("IsRagdoll")==true or h.PlatformStand or h.Sit then return true end
	local mode=h:GetState()
	return mode==Enum.HumanoidStateType.Dead or mode==Enum.HumanoidStateType.Ragdoll
		or mode==Enum.HumanoidStateType.Physics or mode==Enum.HumanoidStateType.Seated
end
local function start(state,action,stamp)
	if not Animation.Directions[action] or blocked(state) or workspace:GetAttribute("HussDodgeV5")~=true then return end
	local now=workspace:GetServerTimeNow()
	local age=math.max(now-stamp,0)
	if age>=Animation.Duration then return end
	cancel(state)
	state.action,state.stamp,state.started=action,stamp,os.clock()-age
	state.character:SetAttribute("HABWeavePoseStartedAt",stamp)
	state.character:SetAttribute("HABWeavePoseUntil",now+Animation.Duration-age)
	state.character:SetAttribute("HABWeavePoseDirection",action)
end
local function dispose(state)
	if not state then return end
	cancel(state)
	for _,c in ipairs(state.connections) do c:Disconnect() end
	active[state.player]=nil
end
local function characterAdded(player,character,initial)
	local record=players[player]
	if not record then return end
	record.generation+=1
	record.pending=nil
	record.bornAt=not initial and workspace:GetServerTimeNow() or nil
	local generation=record.generation
	dispose(active[player])
	task.spawn(function()
		local h=character:WaitForChild("Humanoid",10)
		local root=character:WaitForChild("HumanoidRootPart",10)
		if stopped or players[player]~=record or record.generation~=generation
			or player.Character~=character or not h or not root then return end
		local state={player=player,character=character,humanoid=h,root=root,
			r15=h.RigType==Enum.HumanoidRigType.R15,joints={},feet={},seen={},connections={}}
		local function add(j)
			if state.seen[j] or not (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then return end
			state.seen[j]=true
			local attached=false
			local function attach()
				if attached or not j.Parent or not j.Part0 or not j.Part1 then return end
				local role=Animation.Roles[j.Part1.Name]
				if not role or j.Part0.Parent~=character or j.Part1.Parent~=character then return end
				attached=true
				table.insert(state.joints,{motor=j,role=role})
				if role=="root" and j.Part0==root then state.rootJoint=j end
				if role=="leftAnkle" or role=="rightAnkle" or not state.r15 and (role=="leftHip" or role=="rightHip") then
					table.insert(state.feet,j.Part1)
				end
				state.restFoot=nil
			end
			attach()
			if not attached then
				table.insert(state.connections,j:GetPropertyChangedSignal("Part0"):Connect(attach))
				table.insert(state.connections,j:GetPropertyChangedSignal("Part1"):Connect(attach))
			end
		end
		for _,j in ipairs(character:GetDescendants()) do add(j) end
		table.insert(state.connections,character.DescendantAdded:Connect(add))
		table.insert(state.connections,h.Died:Connect(function() cancel(state) end))
		active[player]=state
		if player==me then
			table.insert(state.connections,character:GetAttributeChangedSignal("MovementActionId"):Connect(function()
				local action=character:GetAttribute("MovementAction")
				if action=="DiveEnd" then cancel(state) else start(state,action,workspace:GetServerTimeNow()) end
			end))
		elseif record.pending and record.pending.character==character then
			start(state,record.pending.action,record.pending.stamp)
			record.pending=nil
		end
	end)
end
local function addPlayer(player)
	if players[player] then return end
	local record={generation=0}
	players[player]=record
	record.added=player.CharacterAdded:Connect(function(c) characterAdded(player,c) end)
	record.removing=player.CharacterRemoving:Connect(function()
		record.generation+=1;record.pending=nil;dispose(active[player])
	end)
	if player.Character then characterAdded(player,player.Character,true) end
end
local function removePlayer(player)
	local record=players[player]
	if not record then return end
	record.generation+=1
	record.added:Disconnect();record.removing:Disconnect()
	dispose(active[player]);players[player]=nil
end
table.insert(connections,Players.PlayerAdded:Connect(addPlayer))
table.insert(connections,Players.PlayerRemoving:Connect(removePlayer))
for _,player in ipairs(Players:GetPlayers()) do addPlayer(player) end
table.insert(connections,remote.OnClientEvent:Connect(function(player,action,stamp)
	local now=workspace:GetServerTimeNow()
	if player==me or not finite(stamp) or stamp>now+1 or now-stamp>=Animation.Duration
		or not Animation.Directions[action] then return end
	local record=players[player]
	if not record or not player.Character or record.bornAt and stamp<record.bornAt
		or record.lastStamp and stamp<=record.lastStamp then return end
	record.lastStamp=stamp
	local state=active[player]
	if state and state.character==player.Character then start(state,action,stamp)
	else record.pending={action=action,stamp=stamp,character=player.Character} end
end))
-- Restore our last pose before Animator evaluation, then blend its fresh pose each frame.
table.insert(connections,RunService.PreAnimation:Connect(function()
	for _,state in pairs(active) do restore(state) end
end))
table.insert(connections,RunService.PreSimulation:Connect(function()
	for _,state in pairs(active) do
		if state.started then
			local elapsed=os.clock()-state.started
			local actionStamp=state.character:GetAttribute("HABActionPoseStartedAt")
			local actionUntil=state.character:GetAttribute("HABActionPoseUntil")
			local newerAction=finite(actionStamp) and actionStamp>=state.stamp and finite(actionUntil)
				and actionUntil>workspace:GetServerTimeNow()
			if elapsed>=Animation.Duration or blocked(state) or newerAction or workspace:GetAttribute("HussDodgeV5")~=true then
				cancel(state)
			else
				local reduced=me:GetAttribute("HussReducedMotion")==true or workspace:GetAttribute("HussReducedMotion")==true
				local pose=Animation.Sample(state.action,elapsed,state.r15,reduced)
				local bases,targets={},{}
				for _,j in ipairs(state.joints) do
					local motor=j.motor
					if motor.Parent and motor.Enabled and pose.Poses[j.role] then
						bases[motor]=motor.Transform
						targets[motor]=motor.Transform:Lerp(Animation.JointTransform(motor,pose.Poses[j.role]),pose.Weight)
					end
				end
				local rootJoint=state.rootJoint
				if rootJoint and targets[rootJoint] then
					state.restFoot=state.restFoot or Animation.FootHeight(state.joints,state.root,nil,state.feet)
					local baseFoot=Animation.FootHeight(state.joints,state.root,bases,state.feet)
					local targetFoot=Animation.FootHeight(state.joints,state.root,targets,state.feet)
					if state.restFoot and baseFoot and targetFoot then
						local plane=baseFoot+(state.restFoot-baseFoot)*pose.Weight
						local lift=math.clamp(plane-targetFoot,-1.6,1.6)
						local localUp=rootJoint.C0.Rotation:Inverse():VectorToWorldSpace(Vector3.new(0,lift,0))
						targets[rootJoint]=CFrame.new(localUp)*targets[rootJoint]
					end
				end
				for _,j in ipairs(state.joints) do
					if targets[j.motor] then
						j.base,j.applied=bases[j.motor],targets[j.motor]
						j.motor.Transform=j.applied
					end
				end
			end
		end
	end
end))
table.insert(connections,script.Destroying:Connect(function()
	stopped=true
	for _,c in ipairs(connections) do c:Disconnect() end
	local list={};for player in pairs(players) do table.insert(list,player) end
	for _,player in ipairs(list) do removePlayer(player) end
end))
