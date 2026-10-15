--!nonstrict
-- HAB_MOTION_REPAIR_1 | Animation only: never changes velocity, speed, or input.
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid", 15)
local root = character:WaitForChild("HumanoidRootPart", 15)
if not humanoid or not root then warn("[HAB Motion] Character rig is incomplete"); return end
local animator = humanoid:WaitForChild("Animator", 15)
if not animator or not animator:IsA("Animator") then
    warn("[HAB Motion] No server Animator. Check CosmeticsServiceV11 startup."); return
end
local player = Players.LocalPlayer
local r6 = humanoid.RigType == Enum.HumanoidRigType.R6
local HS = Enum.HumanoidStateType
local running, links, records = true, {}, {}
local current, currentName, currentRate, dodgeUntil = nil, nil, nil, 0
local function link(signal, fn) links[#links + 1] = signal:Connect(fn) end
-- Keep your original R6 clips. R15 must use R15 clips, not R6 IDs.
local custom = {
    Idle = "86722180453998", Walk = "128318370222834",
    Run = "124106396906271", Fall = "103035488330716",
}
local defaults = r6 and {
    Idle = "180435571", Walk = "180426354", Run = "180426354",
    Fall = "180436148", Climb = "180436334", Sit = "178130996",
} or {
    Idle = "507766666", Walk = "507777826", Run = "507767714",
    Fall = "507767968", Climb = "507765644", Sit = "2506281703",
}
character:SetAttribute("HABAnimationRig", r6 and "R6" or "R15")
if not r6 then
    warn("[HAB Motion] R15 avatar: using R15 locomotion. For your original clips choose R6 in Avatar Settings, then publish.")
end
local function releaseTrack(track)
    if track then pcall(function() track:Stop(0.1); track:Destroy() end) end
end
local function loadTrack(name, id, primary)
    local asset = Instance.new("Animation")
    asset.Name = "HAB_" .. name
    asset.AnimationId = "rbxassetid://" .. id
    local ok, track = pcall(function() return animator:LoadAnimation(asset) end)
    asset:Destroy()
    if not ok then
        warn("[HAB Motion] " .. name .. " " .. id .. ": " .. tostring(track))
        return
    end
    if not running then releaseTrack(track); return end
    track.Looped = true
    track.Priority = (name == "Idle" or name == "Sit") and Enum.AnimationPriority.Idle or Enum.AnimationPriority.Movement
    records[name][primary and "primary" or "fallback"] = track
    local deadline = os.clock() + 10
    while running and character.Parent and track.Length <= 0 and os.clock() < deadline do
        task.wait(0.15)
    end
    if running and track.Length <= 0 then
        warn("[HAB Motion] " .. name .. " asset " .. id .. " did not load. Check experience permissions and the asset ID. Using a loaded fallback where available.")
        character:SetAttribute("HABAnimationLoadWarning", name .. ": " .. id)
    end
end
-- Parallel, bounded loads: one failing custom clip cannot abort every animation.
for name, id in pairs(defaults) do
    records[name] = {}
    task.spawn(loadTrack, name, id, false)
    if r6 and custom[name] then task.spawn(loadTrack, name, custom[name], true) end
end
local function choose(name)
    local row = records[name]
    if not row then return nil end
    if row.primary and row.primary.Length > 0 then return row.primary end
    if row.fallback and row.fallback.Length > 0 then return row.fallback end
    return nil
end
local function stop()
    if current then current:Stop(0.13) end
    current, currentName, currentRate = nil, nil, nil
end
local function play(name, rate)
    local track = choose(name) or choose("Idle")
    if not track then return end
    if current ~= track or not track.IsPlaying then
        stop(); current, currentName = track, name
        track:Play(0.16, 1, rate); currentRate = rate
        character:SetAttribute("HABAnimationState", name)
    elseif not currentRate or math.abs(rate - currentRate) > 0.025 then
        track:AdjustSpeed(rate); currentRate = rate
    end
end
local function dodge()
    local action = character:GetAttribute("MovementAction")
    if action == "DiveEnd" then dodgeUntil = 0
    elseif type(action) == "string" and action:sub(1,4) == "Dive" then
        dodgeUntil = os.clock() + 0.72
    end
end
link(character:GetAttributeChangedSignal("MovementActionId"), dodge)
local function update()
    if not running or not character.Parent or humanoid.Health <= 0 then stop(); return end
    local state = humanoid:GetState()
    if humanoid.PlatformStand or character:GetAttribute("Ragdolled") == true
        or character:GetAttribute("IsRagdoll") == true or state == HS.Physics
        or state == HS.Ragdoll or state == HS.Dead then stop(); return end
    -- Emotes and DodgeWeaveV5 own their own visual pose; do not fight them.
    if player:GetAttribute("HussEmotePlaying") ~= nil
        or (workspace:GetAttribute("HussDodgeV5") == true and os.clock() < dodgeUntil) then
        stop(); return
    end
    if root.Anchored then play("Idle",1); return end
    if state == HS.Climbing then
        play("Climb", math.clamp(math.abs(root.AssemblyLinearVelocity.Y) / 10, 0, 1.8)); return
    end
    if humanoid.Sit or state == HS.Seated then play("Sit",1); return end
    if state == HS.Freefall or state == HS.FallingDown or state == HS.Jumping then
        play("Fall",1); return
    end
    local velocity = root.AssemblyLinearVelocity
    local speed = Vector3.new(velocity.X,0,velocity.Z).Magnitude
    local moving = humanoid.MoveDirection.Magnitude > 0.035 and speed > 0.7
    if not moving then play("Idle",1)
    elseif character:GetAttribute("MovementState") == "Sprint" or speed > 27 then
        play("Run", math.clamp(speed / (r6 and 32 or 28), 0.65, 1.8))
    else play("Walk", math.clamp(speed / (r6 and 24 or 16), 0.65, 1.65)) end
end
link(Run.PreAnimation, update)
link(humanoid.Died, stop)
link(script.Destroying, function()
    running = false
    for _, c in ipairs(links) do c:Disconnect() end
    stop()
    for _, record in pairs(records) do
        releaseTrack(record.primary); releaseTrack(record.fallback)
    end
end)
