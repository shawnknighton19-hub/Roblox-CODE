--!nonstrict
-- HUSS ANIMATION RECOVERY V13
-- Replaces only the reviewed Animate controller. Movement and procedural dodge/panic
-- keep their existing owners. Each clip loads independently and has a bounded fallback.
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid", 10)
local root = character:WaitForChild("HumanoidRootPart", 10)
if not humanoid or not root then warn("[Huss V13 animations] Character is missing Humanoid or HumanoidRootPart."); return end
local animator, animatorDeadline = nil, os.clock() + 10
repeat
	for _, object in ipairs(humanoid:GetChildren()) do
		if object:IsA("Animator") and object:GetAttribute("HussServerAnimatorV13") == true then animator = object; break end
	end
	if not animator then task.wait(.05) end
until animator or os.clock() >= animatorDeadline or humanoid.Health <= 0
if not animator then
	warn("[Huss V13 animations] Server Animator is missing. Check AnimationRuntimeV13 in ServerScriptService/Services.")
	return
end
local workspaceDeadline = os.clock() + 10
while not character:IsDescendantOf(workspace) and os.clock() < workspaceDeadline do task.wait(.1) end
if not character:IsDescendantOf(workspace) then
	warn("[Huss V13 animations] Character did not enter Workspace; animation loading was cancelled.")
	return
end

-- Retained from your existing R6 Animate; the installer preserves reviewed ID edits.
local IDLE_ID = "rbxassetid://86722180453998"
local WALK_ID = "rbxassetid://128318370222834"
local RUN_ID = "rbxassetid://124106396906271"
local FALL_ID = "rbxassetid://103035488330716"
local R6_DEFAULT = {Idle="180435571", Walk="180426354", Run="180426354", Fall="180436148"}
local R15_DEFAULT = {Idle="507766666", Walk="507777826", Run="507767714", Fall="507767968"}
local CUSTOM = {Idle=IDLE_ID, Walk=WALK_ID, Run=RUN_ID, Fall=FALL_ID}
local TIMEOUT, FADE = 8, .13
local r6 = humanoid.RigType == Enum.HumanoidRigType.R6
local defaults = r6 and R6_DEFAULT or R15_DEFAULT
local player = Players:GetPlayerFromCharacter(character)
local stopped, links, resources, slots = false, {}, {}, {}
local currentTrack, currentName, currentSpeed, lastWarning = nil, nil, nil, {}
if not r6 then
	warn("[Huss V13 animations] This character is R15. Using R15 fallback clips. For your custom R6 animations: Studio File > Avatar Settings > ... > R6; save settings, publish, and join a fresh server.")
end
local function alive()
	return not stopped and character.Parent ~= nil and humanoid.Parent == character and humanoid.Health > 0
end
local function warnOnce(key, message)
	if lastWarning[key] then return end
	lastWarning[key] = true
	warn("[Huss V13 animations] " .. message)
end
local function stopTrack(track)
	if track then pcall(function() if track.IsPlaying then track:Stop(FADE) end end) end
end
local function clearCurrent()
	stopTrack(currentTrack)
	currentTrack, currentName, currentSpeed = nil, nil, nil
end
local function cleanup()
	if stopped then return end
	stopped = true
	clearCurrent()
	for _, connection in ipairs(links) do connection:Disconnect() end
	table.clear(links)
	for _, resource in ipairs(resources) do
		if resource.track then pcall(function() resource.track:Stop(0); resource.track:Destroy() end) end
		resource.animation:Destroy()
	end
	table.clear(resources)
end
local function load(name, id, custom)
	if not alive() then return end
	local animation = Instance.new("Animation")
	animation.Name = "HussV13" .. name .. (custom and "Custom" or "Fallback")
	animation.AnimationId = id
	local resource = {animation=animation}
	table.insert(resources, resource)
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	if not ok or not track then
		warnOnce(name .. tostring(custom), name .. " " .. id .. " could not load. " .. (custom and "Its Roblox fallback loads separately; check the animation's experience permission/creator." or "This is the Roblox fallback; check the client animation errors if the state has no playable clip."))
		return
	end
	resource.track = track
	track.Priority = name == "Idle" and Enum.AnimationPriority.Idle or Enum.AnimationPriority.Movement
	track.Looped = true
	local deadline = os.clock() + TIMEOUT
	-- LoadAnimation can succeed while a denied/private asset remains Length == 0.
	while alive() and track.Length <= 0 and os.clock() < deadline do task.wait(.1) end
	if not alive() then pcall(function() track:Destroy() end); return end
	if track.Length <= 0 then
		warnOnce(name .. tostring(custom), name .. " " .. id .. " has no playable clip after 8 seconds. " .. (custom and "Its Roblox fallback loads separately; verify this experience can use the animation." or "This is the Roblox fallback; check the client Output/F9 errors if the state has no playable clip."))
		track:Destroy()
		resource.track = nil
		return
	end
	if custom then slots[name].custom = track else slots[name].fallback = track end
end
local function blocked()
	if humanoid.Sit or humanoid.PlatformStand or character:GetAttribute("Ragdolled") == true or character:GetAttribute("IsRagdoll") == true then return true end
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Dead or state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.Seated then return true end
	return player and type(player:GetAttribute("HussEmotePlaying")) == "string"
end
local function selected()
	local mode = character:GetAttribute("MovementState") or "Idle"
	if root.Anchored or mode == "Locked" then return "Idle", 1 end
	if humanoid.FloorMaterial == Enum.Material.Air then return "Fall", 1 end
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local moving = humanoid.MoveDirection.Magnitude > .05 and speed > .5
	if not moving then return "Idle", 1 end
	if mode == "Sprint" or mode == "Dive" then return "Run", math.clamp(speed / 32, .65, 1.65) end
	return "Walk", math.clamp(speed / 24, .65, 1.5)
end
local function update()
	if not alive() then cleanup(); return end
	if blocked() then clearCurrent(); return end
	local name, speed = selected()
	local slot = slots[name]
	local track = slot and (slot.custom or slot.fallback)
	-- Keep a valid moving/idle clip until the requested clip is ready. A single
	-- failed fall/run asset cannot stop all of the other states from animating.
	if not track then return end
	if currentTrack ~= track or currentName ~= name or not track.IsPlaying then
		clearCurrent()
		local ok = pcall(function() track:Play(FADE, 1, speed) end)
		if not ok then
			if slot.custom == track then slot.custom = nil else slot.fallback = nil end
			warnOnce(name .. "play", name .. " could not play; trying its available fallback.")
			return
		end
		currentTrack, currentName, currentSpeed = track, name, speed
	elseif math.abs(speed - currentSpeed) > .025 then
		track:AdjustSpeed(speed)
		currentSpeed = speed
	end
end
for _, name in ipairs({"Idle", "Walk", "Run", "Fall"}) do slots[name] = {} end
table.insert(links, humanoid.Died:Connect(cleanup))
table.insert(links, character.AncestryChanged:Connect(function() if not character:IsDescendantOf(workspace) then cleanup() end end))
table.insert(links, script.Destroying:Connect(cleanup))
-- Animator evaluates after PreAnimation. Existing dodge/panic overlay transforms
-- are restored before evaluation and applied in PreSimulation by their own scripts.
table.insert(links, Run.PreAnimation:Connect(update))
for _, name in ipairs({"Idle", "Walk", "Run", "Fall"}) do
	task.spawn(load, name, "rbxassetid://" .. defaults[name], false)
	if r6 then task.spawn(load, name, CUSTOM[name], true) end
end
