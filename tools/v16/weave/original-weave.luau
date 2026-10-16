--!nonstrict
-- V6 ACTION DODGE: shoulder drive, lateral power-step, braced backstep.
-- Cosmetic R6/R15 joints only. SnappyMovement owns speed, collisions and cooldown.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local me = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("DodgeIFrameRequest")
local DURATION = .72
local CF, V = CFrame.new, Vector3.new
local active, players, connections = {}, {}, {}
local stopped = false

local directions = {
	DiveForward={0,1}, DiveBack={0,-1}, DiveLeft={-1,0}, DiveRight={1,0},
	DiveForwardLeft={-.7071,.7071}, DiveForwardRight={.7071,.7071},
	DiveBackLeft={-.7071,-.7071}, DiveBackRight={.7071,-.7071},
}
-- time, blend, compression, lean, guard, stride: snap-load, burst, reach, plant, recover.
local keys = {
	{0,0,0,0,0,0}, {.045,.88,.58,-.18,.85,-.5},
	{.135,1,1,1,1,1}, {.28,1,.84,.92,.94,.68},
	{.46,.84,.48,.48,.58,-.32}, {.60,.30,.1,.09,.15,.12},
	{DURATION,0,0,0,0,0},
}
local roles = {
	Torso="root", LowerTorso="root", UpperTorso="waist", Head="neck",
	["Left Arm"]="leftArm", ["Right Arm"]="rightArm",
	["Left Leg"]="leftHip", ["Right Leg"]="rightHip",
	LeftUpperArm="leftArm", RightUpperArm="rightArm",
	LeftLowerArm="leftElbow", RightLowerArm="rightElbow",
	LeftUpperLeg="leftHip", RightUpperLeg="rightHip",
	LeftLowerLeg="leftKnee", RightLowerLeg="rightKnee",
	LeftFoot="leftAnkle", RightFoot="rightAnkle",
}
local function sample(t)
	for i=2,#keys do
		local b,a = keys[i],keys[i-1]
		if t<=b[1] then
			local u=math.clamp((t-a[1])/(b[1]-a[1]),0,1)
			u=u*u*(3-2*u)
			local result={}
			for j=2,6 do result[j-1]=a[j]+(b[j]-a[j])*u end
			return result
		end
	end
	return {0,0,0,0,0}
end
local function pose(role,r15,d,s)
	local _,dip,lean,guard,stride=table.unpack(s)
	local side,front=d[1],d[2]
	local forward,back=math.max(front,0),math.max(-front,0)
	local bank=side~=0 and side or (front>0 and -.26 or .18)
	local pitch=(-34*forward+19*back-12*math.abs(side))*lean
	local roll=-bank*27*lean
	local yaw=(side*16+(side==0 and front*12 or 0))*lean
	local hip=(r15 and 32*dip or 0)-(r15 and pitch*.34 or pitch*.92)
	local lead=(side<0 and -1 or 1)*(25*stride+12*back*lean)
	local armDrive=(front*42+side*32)*lean
	local x,y,z,rx,ry,rz=0,0,0,0,0,0
	if role=="root" then
		x,y,z=side*.32*lean,(r15 and -.18 or .12+.26*math.abs(side))*dip,-forward*.22*lean
		rx,ry,rz=pitch*(r15 and .34 or 1),yaw,roll*(r15 and .52 or 1)
	elseif role=="waist" then rx,ry,rz=pitch*.66,side*14*lean,roll*.48
	elseif role=="neck" then rx,ry,rz=-pitch*.70,-yaw*.65,-roll*.5
	elseif role=="leftArm" then
		rx,ry,rz=16+47*guard+armDrive,-18*guard,-14-16*guard+side*9*lean
	elseif role=="rightArm" then
		rx,ry,rz=16+47*guard-armDrive,18*guard,14+16*guard+side*9*lean
	elseif role=="leftElbow" then rx=30+45*guard+math.max(armDrive,0)*.3
	elseif role=="rightElbow" then rx=30+45*guard+math.max(-armDrive,0)*.3
	elseif role=="leftHip" then rx,ry,rz=hip+lead,-side*8*lean,-9*dip-roll*.42
	elseif role=="rightHip" then rx,ry,rz=hip-lead,-side*8*lean,9*dip-roll*.42
	elseif role=="leftKnee" then rx=-56*dip-math.max(lead,0)*.45
	elseif role=="rightKnee" then rx=-56*dip-math.max(-lead,0)*.45
	elseif role=="leftAnkle" or role=="rightAnkle" then rx=26*dip
	end
	return CF(x,y,z)*CFrame.Angles(math.rad(rx),math.rad(ry),math.rad(rz))
end
local function restore(state)
	for _,j in ipairs(state.joints) do
		if j.base then
			if j.motor.Parent and j.motor.Transform==j.applied then
				j.motor.Transform=j.base
			end
			j.base,j.applied=nil,nil
		end
	end
end
local function cancel(state)
	restore(state)
	state.started=nil
	for _,trail in ipairs(state.trails) do trail.Enabled=false end
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
local function trailFor(state,part)
	if not part then return end
	local a,b=Instance.new("Attachment"),Instance.new("Attachment")
	a.Name,b.Name="HussDodgeTrailTop","HussDodgeTrailBottom"
	a.Position,b.Position=V(0,-part.Size.Y*.2,0),V(0,-part.Size.Y*.45,0)
	a.Parent,b.Parent=part,part
	local t=Instance.new("Trail")
	t.Name="HussActionBurst"
	t.Attachment0,t.Attachment1=a,b
	t.Lifetime=.115
	t.MinLength=.12
	t.LightEmission=.7
	t.Color=ColorSequence.new(Color3.fromRGB(225,255,238),Color3.fromRGB(137,244,177))
	t.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.52),NumberSequenceKeypoint.new(1,1)})
	t.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})
	t.FaceCamera=true
	t.Enabled=false
	t.Parent=part
	table.insert(state.trails,t)
	for _,object in ipairs({a,b,t}) do table.insert(state.effects,object) end
end
local function start(state,action,age)
	if not directions[action] or blocked(state) or workspace:GetAttribute("HussDodgeV5")~=true then return end
	age=age or 0
	if age>=DURATION then return end
	cancel(state)
	state.direction=directions[action]
	state.started=os.clock()-math.max(age,0)
	-- HAB_MOTION_REPAIR_1: boost bursts replace the two old arm ribbon trails.
end
local function dispose(state)
	if not state then return end
	cancel(state)
	for _,connection in ipairs(state.connections) do connection:Disconnect() end
	for _,effect in ipairs(state.effects) do effect:Destroy() end
	active[state.player]=nil
end
local function characterAdded(player,character)
	local record=players[player]
	if not record then return end
	record.generation+=1
	local generation=record.generation
	dispose(active[player])
	task.spawn(function()
		local h=character:WaitForChild("Humanoid",10)
		local root=character:WaitForChild("HumanoidRootPart",10)
		if stopped or players[player]~=record or record.generation~=generation
			or player.Character~=character or not h or not root then return end
		local state={player=player,character=character,humanoid=h,root=root,
			r15=h.RigType==Enum.HumanoidRigType.R15,joints={},connections={},effects={},trails={}}
		local function add(j)
			if not (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) or not j.Part1 or not j.Part0 then return end -- HAB_MOTION_REPAIR_1
			local role=roles[j.Part1.Name]
			if role then table.insert(state.joints,{motor=j,role=role}) end
		end
		for _,j in ipairs(character:GetDescendants()) do add(j) end
		table.insert(state.connections,character.DescendantAdded:Connect(add))
		table.insert(state.connections,h.Died:Connect(function() cancel(state) end))
		active[player]=state
		if player==me then
			table.insert(state.connections,character:GetAttributeChangedSignal("MovementActionId"):Connect(function()
				local action=character:GetAttribute("MovementAction")
				if action=="DiveEnd" then cancel(state) else start(state,action,0) end
			end))
		end
	end)
end
local function addPlayer(player)
	if players[player] then return end
	local record={generation=0}
	players[player]=record
	record.added=player.CharacterAdded:Connect(function(c) characterAdded(player,c) end)
	record.removing=player.CharacterRemoving:Connect(function()
		record.generation+=1
		dispose(active[player])
	end)
	if player.Character then characterAdded(player,player.Character) end
end
local function removePlayer(player)
	local record=players[player]
	if not record then return end
	record.generation+=1
	record.added:Disconnect()
	record.removing:Disconnect()
	dispose(active[player])
	players[player]=nil
end
table.insert(connections,Players.PlayerAdded:Connect(addPlayer))
table.insert(connections,Players.PlayerRemoving:Connect(removePlayer))
for _,player in ipairs(Players:GetPlayers()) do addPlayer(player) end
table.insert(connections,remote.OnClientEvent:Connect(function(player,action,stamp)
	if player==me or type(stamp)~="number" or stamp~=stamp or math.abs(stamp)==math.huge
		or stamp>workspace:GetServerTimeNow()+1 or not directions[action] then return end
	local state=active[player]
	if state and (not state.lastStamp or stamp>state.lastStamp) then
		state.lastStamp=stamp
		start(state,action,workspace:GetServerTimeNow()-stamp)
	end
end))
-- Restore before Animator evaluation; sample its fresh result after evaluation.
table.insert(connections,RunService.PreAnimation:Connect(function()
	for _,state in pairs(active) do restore(state) end
end))
table.insert(connections,RunService.PreSimulation:Connect(function()
	for _,state in pairs(active) do
		if state.started then
			local elapsed=os.clock()-state.started
			if elapsed>=DURATION or blocked(state) or workspace:GetAttribute("HussDodgeV5")~=true then
				cancel(state)
			else
				local s=sample(elapsed)
				for _,j in ipairs(state.joints) do
					local motor=j.motor
					if motor.Parent and motor.Enabled then
						local axes=motor.C0.Rotation
						local target=axes:Inverse()*pose(j.role,state.r15,state.direction,s)*axes
						j.base=motor.Transform
						j.applied=j.base:Lerp(target,s[1])
						motor.Transform=j.applied
					end
				end
				local trails=elapsed>.035 and elapsed<.30 and me:GetAttribute("HussReducedMotion")~=true
					and workspace:GetAttribute("HussReducedMotion")~=true
				for _,trail in ipairs(state.trails) do trail.Enabled=trails end
			end
		end
	end
end))
table.insert(connections,script.Destroying:Connect(function()
	stopped=true
	for _,connection in ipairs(connections) do connection:Disconnect() end
	local list={}
	for player in pairs(players) do table.insert(list,player) end
	for _,player in ipairs(list) do removePlayer(player) end
end))
