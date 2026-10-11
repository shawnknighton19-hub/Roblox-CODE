--!nonstrict
-- BOMB TAG V5 SERVER MAP VOTING

local Players = game:GetService("Players")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")

local config = require(
    RS:WaitForChild("Shared")
        :WaitForChild("Config")
        :WaitForChild("GameConfig")
)

local NAME = tostring(config.MapName)
local maps = WS:WaitForChild("Maps")
local library = SS:WaitForChild("MapLibrary")

local remote = RS:FindFirstChild("BombTagMapVoteEvent")
    or Instance.new("RemoteEvent")

remote.Name = "BombTagMapVoteEvent"
remote.Parent = RS

local rng = Random.new()

local open = false
local options = {}
local votes = {}
local ballots = {}
local ends = 0

local selected =
    WS:GetAttribute("CurrentVotedMap") or "Sky Garden"

local serial = 0
local needsVote = true
local hadMatch = false
local lastActive = false

--------------------------------------------------
-- DETECT EXISTING MATCHES
--------------------------------------------------

local function inRound()
    for _, p in ipairs(Players:GetPlayers()) do
        if p:GetAttribute("InRound") == true then
            return true
        end
    end

    return false
end

local function snapshot()
    return {
        Open = open,
        Options = table.clone(options),
        Counts = table.clone(votes),
        EndsAt = ends,
        Chosen = selected,
    }
end

local function broadcast(kind, toPlayer)
    if toPlayer then
        remote:FireClient(toPlayer, kind, snapshot())
    else
        remote:FireAllClients(kind, snapshot())
    end
end

--------------------------------------------------
-- REPLACE ACTIVE SCENERY
-- PRESERVE EXISTING ROUND SYSTEM REFERENCES
--------------------------------------------------

local function swapMap(name)
    local template = library:FindFirstChild(name)
    local shell = maps:FindFirstChild(NAME)

    if not (template and shell) then
        warn(
            "[VoteV5] Template or active shell missing",
            name, NAME
        )

        return false
    end

    local sourceFloor = template:FindFirstChild("Floor", true)
    local sourceSpawns = template:FindFirstChild("Spawns")

    local floor = shell:FindFirstChild("Floor", true)
    local spawns = shell:FindFirstChild("Spawns", true)

    if not (sourceFloor and sourceSpawns and floor and spawns) then
        warn("[VoteV5] Floor/spawns missing")
        return false
    end

    local anchor = WS:FindFirstChild("ActiveArenaAnchor")

    local slot =
        anchor and anchor.Position
        or (
            floor.Position
            + Vector3.yAxis * (floor.Size.Y / 2)
        )

    local clone = template:Clone()

    local top =
        clone.Floor.Position
        + Vector3.yAxis * (clone.Floor.Size.Y / 2)

    clone:PivotTo(
        clone:GetPivot() + (slot - top)
    )

    local nextFloor = clone.Floor
    local nextSpawns = clone.Spawns

    -- Remove old environment.
    -- Keep the original Floor and Spawns instances.

    for _, child in ipairs(shell:GetChildren()) do
        if child ~= floor and child ~= spawns then
            child:Destroy()
        end
    end

    floor.CFrame = nextFloor.CFrame
    floor.Size = nextFloor.Size
    floor.Color = nextFloor.Color
    floor.Material = nextFloor.Material
    floor.Transparency = 0
    floor.Anchored = true
    floor.CanCollide = true

    floor.Parent = shell
    spawns.Parent = shell

    for _, marker in ipairs(nextSpawns:GetChildren()) do
        if marker:IsA("BasePart") then
            local old = spawns:FindFirstChild(marker.Name)

            if not (old and old:IsA("BasePart")) then
                old = Instance.new("Part")
                old.Name = marker.Name
                old.Parent = spawns
            end

            old.CFrame = marker.CFrame
            old.Size = marker.Size
            old.Anchored = true
            old.Transparency = 1
            old.CanCollide = false
            old.CanQuery = false
            old.CanTouch = false
        end
    end

    for _, child in ipairs(clone:GetChildren()) do
        if child ~= nextFloor and child ~= nextSpawns then
            child.Parent = shell
        end
    end

    shell.PrimaryPart = floor

    -- Keep the technical model name expected by RoundService.

    shell.Name = NAME
    shell:SetAttribute("DisplayName", name)
    shell:SetAttribute("VotedMap", name)

    WS:SetAttribute("CurrentVotedMap", name)

    clone:Destroy()

    selected = name

    print("[VoteV5] Map active:", name)
    return true
end

--------------------------------------------------
-- RANDOMLY SELECT THREE MAPS
--------------------------------------------------

local function candidates()
    local names = {}

    for _, v in ipairs(library:GetChildren()) do
        if v:IsA("Model") then
            table.insert(names, v.Name)
        end
    end

    for i = #names, 2, -1 do
        local j = rng:NextInteger(1, i)
        names[i], names[j] = names[j], names[i]
    end

    local result = {}

    for i = 1, math.min(3, #names) do
        table.insert(result, names[i])
    end

    return result
end

--------------------------------------------------
-- START A VOTE
--------------------------------------------------

local function beginVote()
    if open or inRound() or #Players:GetPlayers() == 0 then
        return
    end

    options = candidates()

    if #options == 0 then
        warn("[VoteV5] No map models in MapLibrary")
        return
    end

    votes = {}
    ballots = {}

    for _, n in ipairs(options) do
        votes[n] = 0
    end

    open = true
    ends = WS:GetServerTimeNow() + 7.5
    serial += 1

    local id = serial

    broadcast("Open")

    task.spawn(function()
        while open
            and serial == id
            and WS:GetServerTimeNow() < ends do

            if inRound() then
                open = false
                broadcast("Close")
                return
            end

            task.wait(0.15)
        end

        if not open or serial ~= id then
            return
        end

        open = false

        local highest = -1
        local leaders = {}

        for _, n in ipairs(options) do
            local count = votes[n] or 0

            if count > highest then
                highest = count
                leaders = {n}
            elseif count == highest then
                table.insert(leaders, n)
            end
        end

        -- Randomly choose among tied maps.

        local winner =
            leaders[rng:NextInteger(1, #leaders)]

        if inRound() then
            broadcast("Close")
            return
        end

        swapMap(winner)
        broadcast("Result")

        task.wait(1.5)

        broadcast("Close")
    end)
end

--------------------------------------------------
-- SERVER-VALIDATED VOTES
--------------------------------------------------

remote.OnServerEvent:Connect(function(p, command, value)
    if command == "Sync" then
        broadcast("Sync", p)
        return
    end

    if command ~= "Vote" or not open or inRound() then
        return
    end

    if typeof(value) ~= "string"
        or votes[value] == nil
        or ballots[p.UserId] == value then
        return
    end

    local before = ballots[p.UserId]

    if before then
        votes[before] = math.max(0, votes[before] - 1)
    end

    ballots[p.UserId] = value
    votes[value] += 1

    broadcast("Counts")
end)

Players.PlayerRemoving:Connect(function(p)
    local previous = ballots[p.UserId]

    if previous and votes[previous] then
        votes[previous] = math.max(
            0,
            votes[previous] - 1
        )
    end

    ballots[p.UserId] = nil

    if open then
        broadcast("Counts")
    end
end)

--------------------------------------------------
-- REPEAT BETWEEN EXISTING ROUNDS
--------------------------------------------------

task.spawn(function()
    task.wait(0.8)

    while true do
        local active = inRound()

        if active then
            hadMatch = true
            needsVote = false

            if open then
                open = false
                serial += 1
                broadcast("Close")
            end

        elseif lastActive and hadMatch then
            hadMatch = false
            needsVote = true
        end

        if not active
            and needsVote
            and not open
            and #Players:GetPlayers() > 0 then

            needsVote = false
            beginVote()
        end

        lastActive = active

        task.wait(0.25)
    end
end)

print("[VoteV5] Started. Stable round shell:", NAME)
