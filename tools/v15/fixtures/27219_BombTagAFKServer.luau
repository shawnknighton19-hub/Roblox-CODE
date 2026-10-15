--!nonstrict
-- BOMB TAG AFK SERVER
-- Authoritative status, matchmaking flag, overhead badge.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild(
    "BombTagAFKRequest"
)

local lastToggle = {}

--------------------------------------------------
-- OVERHEAD BADGE
--------------------------------------------------

local function updateBadge(player)
    local character = player.Character

    if not character then
        return
    end

    local head = character:FindFirstChild("Head")

    if not head or not head:IsA("BasePart") then
        return
    end

    local previous = head:FindFirstChild(
        "BombTagAFKOverhead"
    )

    if previous then
        previous:Destroy()
    end

    if player:GetAttribute("BombTagAFK") ~= true then
        return
    end

    local gui = Instance.new("BillboardGui")

    gui.Name = "BombTagAFKOverhead"
    gui.Adornee = head
    gui.Size = UDim2.fromOffset(92, 28)
    gui.StudsOffsetWorldSpace = Vector3.new(0, 3.25, 0)

    gui.AlwaysOnTop = true
    gui.MaxDistance = 110
    gui.ResetOnSpawn = false
    gui.Parent = head

    local background = Instance.new("Frame")

    background.Name = "BadgeBackground"
    background.Size = UDim2.fromScale(1, 1)
    background.BackgroundColor3 =
        Color3.fromRGB(29, 31, 38)

    background.BackgroundTransparency = 0.08
    background.BorderSizePixel = 0
    background.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = background

    local outline = Instance.new("UIStroke")
    outline.Color = Color3.fromRGB(255, 198, 99)
    outline.Thickness = 1.8
    outline.Parent = background

    local text = Instance.new("TextLabel")

    text.Name = "AFKText"
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1

    text.Text = "AFK"
    text.Font = Enum.Font.GothamBlack
    text.TextSize = 18

    text.TextColor3 = Color3.fromRGB(255, 215, 125)
    text.TextStrokeColor3 = Color3.new(0, 0, 0)
    text.TextStrokeTransparency = 0

    text.Parent = background
end

--------------------------------------------------
-- PLAYER SETUP
--------------------------------------------------

local function setupPlayer(player)
    if player:GetAttribute("BombTagAFK") == nil then
        player:SetAttribute("BombTagAFK", false)
    end

    player:GetAttributeChangedSignal(
        "BombTagAFK"
    ):Connect(function()
        updateBadge(player)
    end)

    player.CharacterAdded:Connect(function(character)
        local head = character:WaitForChild("Head", 10)

        if head then
            updateBadge(player)
        end
    end)

    if player.Character then
        task.defer(updateBadge, player)
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
    lastToggle[player] = nil
end)

--------------------------------------------------
-- ACCEPT OR REJECT AFK CHANGES
--------------------------------------------------

remote.OnServerEvent:Connect(function(player, requested)
    if typeof(requested) ~= "boolean" then
        return
    end

    -- Cannot change matchmaking status mid-round.
    if player:GetAttribute("InRound") == true then
        return
    end

    local now = os.clock()

    if now - (lastToggle[player] or -100) < 0.45 then
        return
    end

    lastToggle[player] = now

    player:SetAttribute("BombTagAFK", requested)

    print(
        "[AFK]",
        player.Name,
        requested and "is now AFK" or "is now READY"
    )
end)

print("[AFK] Server matchmaking status system ready.")
