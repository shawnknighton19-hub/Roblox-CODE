--!nonstrict
-- HAB_MOTION_REPAIR_1 | Existing catalog, ownership, currency and bomb skins preserved.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local C = require(RS:WaitForChild("HussCatalogV11"))
local BombSkinBuilder = require(RS:WaitForChild("BombSkinBuilderV12"))
local S, states, started = {}, {}, false
local function item(p, attribute, category)
    local entry = p and C.ById[p:GetAttribute(attribute)]
    return entry and entry.category == category and entry or C.ById[C.Defaults[category]]
end
function S.ApplyBomb(player, bomb)
    return BombSkinBuilder.Apply(bomb, item(player,"HussBombId","Bombs"))
end
local function notice(p, message)
    p:SetAttribute("HABEmoteStatus", message)
    p:SetAttribute("HABEmoteNotice", (p:GetAttribute("HABEmoteNotice") or 0) + 1)
end
local function stop(p)
    local s = states[p]
    if s then s.active = nil end
    p:SetAttribute("HussEmotePlaying", nil)
    p:SetAttribute("HussEmoteStarted", nil)
end
local function serverAnimator(p,c)
    local h = c:WaitForChild("Humanoid", 15)
    if not h or p.Character ~= c or not p.Parent then return end
    if not h:FindFirstChildOfClass("Animator") then
        local a = Instance.new("Animator"); a.Parent = h
    end
    c:SetAttribute("HABServerAnimator", true)
    c:SetAttribute("HABServerRig", h.RigType.Name)
end
local function stationary(p)
    local c = p.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if not h or not r or h.Health <= 0 then return nil, "Wait for your character to spawn." end
    if p:GetAttribute("InRound") == true then return nil, "Emotes are available in the lobby." end
    if h.Sit or h.PlatformStand or r.Anchored then return nil, "Stand up before using an emote." end
    if p:GetAttribute("HussGamePaused") == true or workspace:GetAttribute("HussGamePaused") == true
        or c:GetAttribute("Ragdolled") == true or c:GetAttribute("IsRagdoll") == true then
        return nil, "Emotes are unavailable while paused or ragdolled."
    end
    local stamp = c:GetAttribute("HussDodgeStartedAt")
    if type(stamp) == "number" and workspace:GetServerTimeNow() - stamp < 0.85 then
        return nil, "Finish your dodge first."
    end
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances = {c}
    ray.IgnoreWater = true
    ray.RespectCanCollide = true
    ray.CollisionGroup = r.CollisionGroup
    local leg = c:FindFirstChild("Left Leg")
    local feet = h.HipHeight + r.Size.Y * 0.5 + (leg and leg.Size.Y or 0)
    local hit = workspace:Raycast(r.Position + Vector3.new(0,0.25,0), Vector3.new(0,-math.clamp(feet+1.1,2.5,12),0), ray)
    if not hit or hit.Normal.Y < 0.45 then return nil, "Stand on the floor to use an emote." end
    local velocity = r.AssemblyLinearVelocity
    if hit.Instance:IsA("BasePart") then velocity = velocity - hit.Instance:GetVelocityAtPosition(hit.Position) end
    if Vector3.new(velocity.X,0,velocity.Z).Magnitude > 2.5 or math.abs(velocity.Y) > 4 then
        return nil, "Stop moving to use an emote."
    end
    return c,h,r
end
function S.Init()
    if started then return end
    started = true
    local remote = RS:FindFirstChild("HussCosmeticsV11")
    if not remote then remote = Instance.new("RemoteEvent"); remote.Name = "HussCosmeticsV11"; remote.Parent = RS end
    assert(remote:IsA("RemoteEvent"), "HussCosmeticsV11 must be a RemoteEvent")
    local function add(p)
        if states[p] then return end
        local s = {nextAt=0, active=nil}
        states[p] = s
        stop(p)
        s.charLink = p.CharacterAdded:Connect(function(c) stop(p); task.spawn(serverAnimator,p,c) end)
        s.removeLink = p.CharacterRemoving:Connect(function() stop(p) end)
        if p.Character then task.spawn(serverAnimator,p,p.Character) end
    end
    Players.PlayerAdded:Connect(add)
    Players.PlayerRemoving:Connect(function(p)
        local s = states[p]
        if s then s.charLink:Disconnect(); s.removeLink:Disconnect() end
        states[p] = nil
    end)
    for _, p in ipairs(Players:GetPlayers()) do add(p) end
    remote.OnServerEvent:Connect(function(p,action)
        local s=states[p]
        if not s or type(action)~='string' then return end
        stop(p)
        if action=='Emote' and os.clock()>=s.nextAt then
            s.nextAt=os.clock()+1
            notice(p,'Emotes have been retired. Your previous ownership is archived.')
        end
    end)
    local elapsed = 0
    Run.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        if elapsed < 0.1 then return end
        elapsed = 0
        for p,s in pairs(states) do
            if s.active then
                local c,h,r = stationary(p)
                local a = s.active
                if not c or c ~= a.character or h.Health < a.health
                    or (r.Position-a.position).Magnitude > 0.8 or os.clock() >= a.untilAt then
                    stop(p)
                end
            end
        end
    end)
    print("[HAB Motion] Server Animator and emote validation ready.")
end
return S

-- HAB_FUN_9