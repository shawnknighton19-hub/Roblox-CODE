--!nonstrict
-- V16: original panic-run pose, with extra tear cosmetics removed.
-- Normal locomotion, shift lock, speed, collision, dodge and immunity remain with their controllers.
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local me = Players.LocalPlayer
local V, CF = Vector3.new, CFrame.new
local DODGE_DURATION, IFRAME_DURATION, VIEW_DISTANCE = .72, .45, 110
local states, players, botFolders, links = {}, {}, {}, {}
local stopped = false
local diveActions = {
	DiveForward=true, DiveBack=true, DiveLeft=true, DiveRight=true,
	DiveForwardLeft=true, DiveForwardRight=true, DiveBackLeft=true, DiveBackRight=true,
}
local jointRoles = {
	Torso="body", UpperTorso="body", Head="neck",
	["Left Arm"]="leftArm", ["Right Arm"]="rightArm",
	LeftUpperArm="leftArm", RightUpperArm="rightArm",
	LeftLowerArm="leftElbow", RightLowerArm="rightElbow",
}
local function connect(signal, callback, bucket)
	table.insert(bucket or links, signal:Connect(callback))
end
local function disconnect(bucket)
	for _, connection in ipairs(bucket) do connection:Disconnect() end
	table.clear(bucket)
end
local function finite(value)
	return type(value)=="number" and value==value and math.abs(value)<math.huge
end
local function reduced()
	return me:GetAttribute("HussReducedMotion")==true or workspace:GetAttribute("HussReducedMotion")==true
end
local function restoreJoint(joint)
	-- Another controller may already own the joint. Never restore over its new pose.
	if joint.base then
		if joint.motor.Parent and joint.motor.Transform==joint.applied then
			joint.motor.Transform=joint.base
		end
		joint.base, joint.applied=nil, nil
	end
end
local function restore(state)
	for _, joint in ipairs(state.joints) do restoreJoint(joint) end
end
local function cancel(state)
	restore(state)
	state.weight=0
end
local function dispose(character)
	local state=states[character]
	if not state then return end
	cancel(state)
	disconnect(state.links)
	states[character]=nil
end
local function addJoint(state, motor)
	if not motor:IsA("Motor6D") or not motor.Part0 or not motor.Part1 then return end
	local role=jointRoles[motor.Part1.Name]
	if not role then return end
	for _, joint in ipairs(state.joints) do if joint.motor==motor then return end end
	table.insert(state.joints, {motor=motor, role=role})
end
local function beginDodge(state, age)
	if not finite(age) or age<0 or age>=DODGE_DURATION then return end
	state.dodgeUntil=math.max(state.dodgeUntil, os.clock()+DODGE_DURATION-age)
	cancel(state)
end
local function actionChanged(state)
	local action=state.character:GetAttribute("MovementAction")
	if diveActions[action] then beginDodge(state, 0) end
	-- Keep the short exclusion through recovery, even if DiveEnd arrived early.
end
local function characterAdded(character, player, sourceFolder)
	if stopped or states[character] or not character:IsA("Model") then return end
	local state={character=character, player=player, sourceFolder=sourceFolder,
		joints={}, links={}, weight=0, dodgeUntil=0, nextDrop=0, phase=0}
	states[character]=state
	local function refresh()
		state.h=character:FindFirstChildOfClass("Humanoid")
		state.root=character:FindFirstChild("HumanoidRootPart")
		state.head=character:FindFirstChild("Head")
		if state.h and state.boundHumanoid~=state.h then
			state.boundHumanoid=state.h
			connect(state.h.Died, function() cancel(state) end, state.links)
		end
	end
	refresh()
	for _, object in ipairs(character:GetDescendants()) do addJoint(state, object) end
	connect(character.DescendantAdded, function(object)
		addJoint(state, object)
		if object.Parent==character then refresh() end
	end, state.links)
	connect(character.DescendantRemoving, function(object)
		for index=#state.joints,1,-1 do
			local joint=state.joints[index]
			if joint.motor==object then restoreJoint(joint); table.remove(state.joints,index) end
		end
		if object==state.root or object==state.h or object==state.head then
			cancel(state)
			if object==state.root then state.root=nil end
			if object==state.h then state.h=nil end
			if object==state.head then state.head=nil end
		end
	end, state.links)
	connect(character:GetAttributeChangedSignal("HussBombCarrier"), function()
		if character:GetAttribute("HussBombCarrier")~=true then cancel(state) end
	end, state.links)
	connect(character:GetAttributeChangedSignal("MovementActionId"), function() actionChanged(state) end, state.links)
	local function immunityChanged()
		local untilTime=character:GetAttribute("BombTagIFrameUntil")
		local serverNow=workspace:GetServerTimeNow()
		if finite(untilTime) and untilTime>serverNow then
			-- The reviewed server publishes a .45-second immunity window, including to
			-- clients that do not receive the optional dodge animation broadcast.
			beginDodge(state,math.max(0,IFRAME_DURATION-(untilTime-serverNow)))
		end
	end
	connect(character:GetAttributeChangedSignal("BombTagIFrameUntil"),immunityChanged,state.links)
	immunityChanged()
	connect(character.AncestryChanged, function()
		if not character:IsDescendantOf(workspace) then dispose(character) end
	end, state.links)
end
local function addPlayer(player)
	if players[player] then return end
	local bucket={}
	players[player]=bucket
	connect(player.CharacterAdded, function(character) characterAdded(character, player) end, bucket)
	connect(player.CharacterRemoving, dispose, bucket)
	if player.Character then characterAdded(player.Character, player) end
end
local function removePlayer(player)
	local bucket=players[player]
	if bucket then disconnect(bucket); players[player]=nil end
	local characters={}
	for character,state in pairs(states) do if state.player==player then table.insert(characters,character) end end
	for _, character in ipairs(characters) do dispose(character) end
end
local function bindBots(object)
	if stopped or object.Name~="HussPracticeBots" or not object:IsA("Folder") or botFolders[object] then return end
	local bucket={}
	botFolders[object]=bucket
	local function add(character)
		if character:IsA("Model") and character:GetAttribute("HussPracticeBot")==true then characterAdded(character,nil,object) end
	end
	connect(object.ChildAdded, add, bucket)
	connect(object.ChildRemoved, dispose, bucket)
	for _, character in ipairs(object:GetChildren()) do add(character) end
end
local function removeBots(object)
	local bucket=botFolders[object]
	if not bucket then return end
	disconnect(bucket)
	botFolders[object]=nil
	local characters={}
	for character,state in pairs(states) do if state.sourceFolder==object then table.insert(characters,character) end end
	for _, character in ipairs(characters) do dispose(character) end
end
local function blocked(state, now, serverNow)
	local c,h,r,head=state.character,state.h,state.root,state.head
	if c:GetAttribute("HussBombCarrier")~=true or not c.Parent or not h or not r or not head
		or not h.Parent or not r.Parent or not head.Parent or h.Health<=0 or r.Anchored or h.Sit or h.PlatformStand then return true end
	if reduced() or workspace:GetAttribute("HussGamePaused")==true or c:GetAttribute("HussGamePaused")==true
		or state.player and state.player:GetAttribute("HussGamePaused")==true then return true end
	if c:GetAttribute("Ragdolled")==true or c:GetAttribute("IsRagdoll")==true then return true end
	local mode=h:GetState()
	if mode==Enum.HumanoidStateType.Dead or mode==Enum.HumanoidStateType.Ragdoll
		or mode==Enum.HumanoidStateType.Physics or mode==Enum.HumanoidStateType.Seated then return true end
	-- Emotes use C0 in CollectionEffects; panic uses Transform and gives emotes priority.
	if state.player and type(state.player:GetAttribute("HussEmotePlaying"))=="string" then return true end
	if now<state.dodgeUntil then return true end
	local actionUntil=c:GetAttribute("HABActionPoseUntil")
	local weaveUntil=c:GetAttribute("HABWeavePoseUntil")
	if finite(actionUntil) and actionUntil>serverNow or finite(weaveUntil) and weaveUntil>serverNow then return true end
	local started=c:GetAttribute("HussDodgeStartedAt")
	if finite(started) and serverNow>=started-.1 and serverNow<started+DODGE_DURATION then return true end
	local immuneUntil=c:GetAttribute("BombTagIFrameUntil")
	if finite(immuneUntil) and immuneUntil>serverNow then return true end
	local camera=workspace.CurrentCamera
	return not camera or (camera.CFrame.Position-r.Position).Magnitude>VIEW_DISTANCE
end
local function pose(role, phase, running, r15)
	local swing=math.sin(phase)
	local flutter=math.sin(phase*1.9)
	local pitch,yaw,roll=0,0,0
	if role=="body" then
		pitch=-4-7*running
		yaw=swing*(2+3*running)
		roll=swing*(1.5+2.5*running)
	elseif role=="neck" then
		pitch=8+flutter*3
		yaw=math.sin(phase*.48)*17
		roll=-swing*4
	elseif role=="leftArm" then
		pitch=136+swing*(14+10*running)
		yaw=-12
		roll=-38-flutter*8
	elseif role=="rightArm" then
		pitch=136-swing*(14+10*running)
		yaw=12
		roll=38+flutter*8
	elseif role=="leftElbow" then pitch=48-swing*12
	elseif role=="rightElbow" then pitch=48+swing*12 end
	if role=="body" and not r15 then pitch*=.65; roll*=.7 end
	if not r15 and (role=="leftArm" or role=="rightArm") then pitch+=14 end
	return CFrame.Angles(math.rad(pitch),math.rad(yaw),math.rad(roll))
end
connect(Players.PlayerAdded, addPlayer)
connect(Players.PlayerRemoving, removePlayer)
for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end
connect(workspace.ChildAdded, bindBots)
connect(workspace.ChildRemoved, removeBots)
for _, child in ipairs(workspace:GetChildren()) do bindBots(child) end
-- Existing remote broadcasts validated dodge actions to spectators; no new request protocol.
local dodgeRemote=RS:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("DodgeIFrameRequest")
connect(dodgeRemote.OnClientEvent, function(player, action, stamp)
	if player==me or not diveActions[action] or not finite(stamp) then return end
	local state=player and states[player.Character]
	local age=workspace:GetServerTimeNow()-stamp
	if state and age>=-.1 and age<DODGE_DURATION then beginDodge(state,math.max(0,age)) end
end)
-- Restore before Animator evaluation, then layer over its fresh upper-body result.
-- Legs and physical root position remain untouched.
connect(Run.PreAnimation, function()
	for _, state in pairs(states) do restore(state) end
end)
connect(Run.PreSimulation, function(dt)
	local now,serverNow=os.clock(),workspace:GetServerTimeNow()
	for _, state in pairs(states) do
		if blocked(state,now,serverNow) then cancel(state)
		else
			state.weight=math.min(1,state.weight+math.clamp(dt,0,.1)*7)
			local velocity=state.root.AssemblyLinearVelocity
			local running=math.clamp(V(velocity.X,0,velocity.Z).Magnitude/32,0,1)
			state.phase=(state.phase+math.clamp(dt,0,.1)*(8+running*7))%(math.pi*2)
			local phase=state.phase
			for _, joint in ipairs(state.joints) do
				local motor=joint.motor
				if motor.Parent and motor.Enabled then
					local axes=motor.C0.Rotation
					local offset=axes:Inverse()*pose(joint.role,phase,running,state.h.RigType==Enum.HumanoidRigType.R15)*axes
					joint.base=motor.Transform
					local upperArm=joint.role=="leftArm" or joint.role=="rightArm" or joint.role=="leftElbow" or joint.role=="rightElbow"
					joint.applied=upperArm and joint.base:Lerp(offset,state.weight*.86)
						or joint.base:Lerp(joint.base*offset,state.weight)
					motor.Transform=joint.applied
				end
			end
		end
	end
end)
connect(script.Destroying, function()
	stopped=true
	disconnect(links)
	local characters={}
	for character in pairs(states) do table.insert(characters,character) end
	for _, character in ipairs(characters) do dispose(character) end
	for _, bucket in pairs(players) do disconnect(bucket) end
	for _, bucket in pairs(botFolders) do disconnect(bucket) end
	table.clear(players)
	table.clear(botFolders)
end)
