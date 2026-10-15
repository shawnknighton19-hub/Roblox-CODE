--!nonstrict
-- BOMB TAG V6 / SERVER MAP VOTING SERVICE
-- Called directly by RoundService BEFORE lobby countdown.

local Players = game:GetService("Players")
local Storage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local config = require(
    ReplicatedStorage.Shared.Config.GameConfig
)

local remote = ReplicatedStorage:WaitForChild("BombTagVoteV6")
local library = Storage:WaitForChild("MapLibrary")
local maps = Workspace:WaitForChild("Maps")

local service = {}
local rng = Random.new()

local opened = false
local options = {}
local ballots = {}
local counts = {}
local deadline = 0

local chosen = Workspace:GetAttribute("CurrentVotedMap") or "Sky Garden"

local function eligible(p)
    return p.Parent == Players
        and p:GetAttribute("BombTagAFK") ~= true
        and p:GetAttribute("InRound") ~= true
end

local function snapshot()
    return {
        Open = opened,
        Options = table.clone(options),
        Counts = table.clone(counts),
        EndsAt = deadline,
        Chosen = chosen,
    }
end

local function announce(kind, player)
    if player then
        remote:FireClient(player, kind, snapshot())
    else
        remote:FireAllClients(kind, snapshot())
    end
end

local function chooseThree()
    local all = {}

    for _, map in ipairs(library:GetChildren()) do
        if map:IsA("Model") then
            table.insert(all, map.Name)
        end
    end

    for i = #all, 2, -1 do
        local j = rng:NextInteger(1, i)
        all[i], all[j] = all[j], all[i]
    end

    local result = {}

    for i = 1, math.min(3, #all) do
        result[i] = all[i]
    end

    return result
end

local function swapMap(name)
    local template = library:FindFirstChild(name)
    if not template then
        warn("[V6 Voting] Missing map:", name)
        return false
    end

    local target = Workspace:FindFirstChild("ActiveArenaAnchor")

    if not target then
        warn("[V6 Voting] ActiveArenaAnchor missing")
        return false
    end

    local clone = template:Clone()
    clone.Name = config.MapName

    local floor = clone:FindFirstChild("Floor")

    if not floor then
        clone:Destroy()
        return false
    end

    local top =
        floor.Position
        + Vector3.new(0, floor.Size.Y / 2, 0)

    clone:PivotTo(
        clone:GetPivot() + (target.Position - top)
    )

    clone:SetAttribute("DisplayName", name)
    clone:SetAttribute("VotedMap", name)

    -- RoundService is still in the lobby at this point.
    -- Swap happens BEFORE it retrieves the map's spawn folder.

    for _, old in ipairs(maps:GetChildren()) do
        if old:IsA("Model") then
            old:Destroy()
        end
    end

    clone.Parent = maps

    chosen = name
    Workspace:SetAttribute("CurrentVotedMap", name)

    print("[V6 Voting] Loaded", name)
    return true
end

local function calculateCounts()
    counts = {}

    for _, name in ipairs(options) do
        counts[name] = 0
    end

    for userId, votedName in pairs(ballots) do
        local p = Players:GetPlayerByUserId(userId)

        if p and eligible(p) and counts[votedName] ~= nil then
            counts[votedName] += 1
        end
    end
end

remote.OnServerEvent:Connect(function(player, action, mapName)
    if action == "Sync" then
        announce("Sync", player)
        return
    end

    if action ~= "Vote"
        or not opened
        or not eligible(player)
        or typeof(mapName) ~= "string"
        or not table.find(options, mapName) then
        return
    end

    ballots[player.UserId] = mapName

    calculateCounts()
    announce("Counts")
end)

function service.RunVote(seconds)
    if opened then
        return
    end

    local eligibleCount = 0

    for _, p in ipairs(Players:GetPlayers()) do
        if eligible(p) then
            eligibleCount += 1
        end
    end

    if eligibleCount == 0 then
        return
    end

    options = chooseThree()

    if #options == 0 then
        warn("[V6 Voting] Empty MapLibrary")
        return
    end

    ballots = {}
    calculateCounts()

    opened = true
    deadline = Workspace:GetServerTimeNow() + (seconds or 7)

    announce("Open")

    while Workspace:GetServerTimeNow() < deadline do
        task.wait(0.15)
    end

    opened = false
    calculateCounts()

    local highest = -1
    local tied = {}

    for _, name in ipairs(options) do
        local votes = counts[name] or 0

        if votes > highest then
            highest = votes
            tied = {name}
        elseif votes == highest then
            table.insert(tied, name)
        end
    end

    if #tied > 0 then
        local winner = tied[rng:NextInteger(1, #tied)]

        if swapMap(winner) then
            announce("Result")
        else
            announce("Close")
        end
    else
        announce("Close")
    end

    task.wait(1)
    announce("Close")
end

return service
