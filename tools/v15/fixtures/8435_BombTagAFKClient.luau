--!nonstrict
-- BOMB TAG AFK BUTTON
-- Separate from your custom HudController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild(
    "BombTagAFKRequest"
)

local gui = Instance.new("ScreenGui")
gui.Name = "BombTagAFKGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 145
gui.Parent = player:WaitForChild("PlayerGui")

--------------------------------------------------
-- LOBBY BUTTON
--------------------------------------------------

local button = Instance.new("TextButton")

button.Name = "AFKButton"
button.AnchorPoint = Vector2.new(0, 1)
button.Position = UDim2.new(0, 16, 1, -18)

button.Size = UDim2.fromOffset(145, 44)

button.BackgroundColor3 =
    Color3.fromRGB(39, 46, 54)

button.Text = ""
button.AutoButtonColor = false
button.BorderSizePixel = 0

button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 9)
corner.Parent = button

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(94, 225, 147)
stroke.Parent = button

local title = Instance.new("TextLabel")

title.Name = "ButtonLabel"
title.Size = UDim2.fromScale(1, 1)
title.BackgroundTransparency = 1

title.Text = "AFK"
title.Font = Enum.Font.GothamBlack
title.TextSize = 18

title.TextColor3 = Color3.fromRGB(245, 249, 246)
title.TextStrokeColor3 = Color3.new(0, 0, 0)
title.TextStrokeTransparency = 0.3

title.Parent = button

--------------------------------------------------
-- STATUS UNDER BUTTON
--------------------------------------------------

local status = Instance.new("TextLabel")

status.Name = "MatchmakingStatus"

status.AnchorPoint = Vector2.new(0, 1)
status.Position = UDim2.new(0, 17, 1, -67)
status.Size = UDim2.fromOffset(170, 20)

status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamBold
status.TextSize = 12

status.TextXAlignment = Enum.TextXAlignment.Left
status.TextColor3 = Color3.fromRGB(160, 255, 189)

status.TextStrokeTransparency = 0.5
status.Parent = gui

--------------------------------------------------
-- VISUAL UPDATE
--------------------------------------------------

local function refresh()
    local afk =
        player:GetAttribute("BombTagAFK") == true

    local inRound =
        player:GetAttribute("InRound") == true

    button.Visible = not inRound
    status.Visible = not inRound

    if afk then
        button.BackgroundColor3 =
            Color3.fromRGB(101, 65, 40)

        stroke.Color =
            Color3.fromRGB(255, 193, 91)

        title.Text = "RETURN TO GAME"

        title.TextSize = 14

        status.Text = "AFK • MATCHMAKING OFF"

        status.TextColor3 =
            Color3.fromRGB(255, 205, 119)
    else
        button.BackgroundColor3 =
            Color3.fromRGB(36, 69, 53)

        stroke.Color =
            Color3.fromRGB(90, 236, 137)

        title.Text = "GO AFK"

        title.TextSize = 18

        status.Text = "READY • MATCHMAKING ON"

        status.TextColor3 =
            Color3.fromRGB(160, 255, 189)
    end
end

button.Activated:Connect(function()
    if player:GetAttribute("InRound") == true then
        return
    end

    local currentlyAFK =
        player:GetAttribute("BombTagAFK") == true

    remote:FireServer(not currentlyAFK)
end)

player:GetAttributeChangedSignal(
    "BombTagAFK"
):Connect(refresh)

player:GetAttributeChangedSignal(
    "InRound"
):Connect(refresh)

refresh()
