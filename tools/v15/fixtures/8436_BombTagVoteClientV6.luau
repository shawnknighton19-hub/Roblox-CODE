--!nonstrict
-- BOMB TAG V6: COMPACT LOBBY MAP VOTING

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("BombTagVoteV6")
local previews = ReplicatedStorage:WaitForChild("BombTagV6Previews")

local pg = player:WaitForChild("PlayerGui")

local old = pg:FindFirstChild("BombTagV6VoteGui")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "BombTagV6VoteGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 152
gui.Parent = pg

local function new(class, parent, properties)
    local o = Instance.new(class)
    for k, v in pairs(properties) do o[k] = v end
    o.Parent = parent
    return o
end

local white = Color3.fromRGB(246, 247, 242)
local green = Color3.fromRGB(99, 239, 138)

local panel = new("Frame", gui, {
    Name = "CompactVotePanel",

    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -18, 0, 116),
    Size = UDim2.fromOffset(480, 240),

    BackgroundColor3 = Color3.fromRGB(26, 32, 36),
    BackgroundTransparency = 0.05,
    BorderSizePixel = 0,

    Visible = false,
})

new("UICorner", panel, {
    CornerRadius = UDim.new(0, 10)
})

new("UIStroke", panel, {
    Color = Color3.fromRGB(114, 150, 131),
    Thickness = 1.7,
})

local scale = new("UIScale", panel, {Scale = 1})

local function text(parent, value, pos, size, pointSize, color)
    return new("TextLabel", parent, {
        BackgroundTransparency = 1,
        Position = pos,
        Size = size,
        Text = value,
        Font = Enum.Font.GothamBold,
        TextColor3 = color or white,
        TextSize = pointSize,
        TextScaled = true,
        TextStrokeTransparency = 0.55,
    })
end

local title = text(
    panel, "VOTE FOR THE NEXT MAP",
    UDim2.fromOffset(12, 9),
    UDim2.fromOffset(370, 27),
    21, white
)

title.TextXAlignment = Enum.TextXAlignment.Left

local countdown = text(
    panel, "7s",
    UDim2.fromOffset(409, 8),
    UDim2.fromOffset(58, 27),
    21, green
)

local cards = {}
local options = {}
local counts = {}
local selected
local opened = false
local deadline = 0

for i = 1, 3 do
    local button = new("TextButton", panel, {
        Name = "MapCard" .. i,
        Position = UDim2.fromOffset(12 + (i - 1) * 154, 46),
        Size = UDim2.fromOffset(148, 181),
        BackgroundColor3 = Color3.fromRGB(41, 50, 54),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
    })

    new("UICorner", button, {
        CornerRadius = UDim.new(0, 7)
    })

    local border = new("UIStroke", button, {
        Color = Color3.fromRGB(106, 121, 115),
        Thickness = 1.3,
    })

    local viewport = new("ViewportFrame", button, {
        Position = UDim2.fromOffset(5, 5),
        Size = UDim2.fromOffset(138, 104),
        BackgroundColor3 = Color3.fromRGB(73, 99, 107),
        BorderSizePixel = 0,
        Ambient = Color3.fromRGB(195, 203, 215),
        LightColor = Color3.fromRGB(255, 243, 210),
        LightDirection = Vector3.new(-1, -1, -0.5),
    })

    new("UICorner", viewport, {
        CornerRadius = UDim.new(0, 5)
    })

    local world = new("WorldModel", viewport, {})
    local camera = new("Camera", viewport, {
        FieldOfView = 43,
        CFrame = CFrame.lookAt(
            Vector3.new(37, 32, 38),
            Vector3.new(0, 2, 0)
        )
    })

    viewport.CurrentCamera = camera

    local mapName = text(
        button, "",
        UDim2.fromOffset(6, 114),
        UDim2.fromOffset(136, 30),
        15, white
    )

    local votes = text(
        button, "",
        UDim2.fromOffset(6, 149),
        UDim2.fromOffset(136, 23),
        13, green
    )

    cards[i] = {
        button = button,
        border = border,
        world = world, camera = camera, loadedName = nil,
        name = mapName,
        votes = votes,
    }

    button.Activated:Connect(function()
        if opened and options[i] then
            selected = options[i]
            remote:FireServer("Vote", selected)

            for j, entry in ipairs(cards) do
                entry.border.Color =
                    options[j] == selected
                    and green
                    or Color3.fromRGB(106, 121, 115)
            end
        end
    end)
end

local function redraw()
    for i, entry in ipairs(cards) do
        local name = options[i]

        entry.button.Visible = name ~= nil

        if name then
            entry.name.Text = name:upper()
            entry.votes.Text = tostring(counts[name] or 0) .. " VOTES"

            			if entry.loadedName ~= name then
				for _, child in ipairs(entry.world:GetChildren()) do
					child:Destroy()
				end
				local template = previews:FindFirstChild(name)
				if template and template:IsA("Model") then
					local model = template:Clone()
					model.Parent = entry.world
					local bounds, size = model:GetBoundingBox()
					local distance = math.max(size.Magnitude / 2, 1)
						/ math.sin(math.rad(entry.camera.FieldOfView / 2)) * 1.08
					entry.camera.CFrame = CFrame.lookAt(
						bounds.Position + Vector3.new(1, 0.95, 1).Unit * distance,
						bounds.Position
					)
					entry.loadedName = name
				else
					entry.loadedName = nil
				end
			end

            entry.border.Color =
                selected == name
                and green
                or Color3.fromRGB(106, 121, 115)
        end
    end
end

local resultId = 0

remote.OnClientEvent:Connect(function(kind, data)
    data = data or {}

    if kind == "Open" or kind == "Sync" then
        opened = data.Open == true
        options = data.Options or {}
        counts = data.Counts or {}
        deadline = data.EndsAt or 0

        selected = nil

        panel.Visible =
            opened
            and player:GetAttribute("BombTagAFK") ~= true

        if opened then
            title.Text = "VOTE FOR THE NEXT MAP"
            redraw()
        end

    elseif kind == "Counts" then
        counts = data.Counts or {}
        redraw()

    elseif kind == "Result" then
        opened = false
        resultId += 1
        local id = resultId

        title.Text = "WINNER: " .. tostring(data.Chosen):upper()
        panel.Visible = player:GetAttribute("BombTagAFK") ~= true

        task.delay(1.0, function()
            if id == resultId and not opened then
                panel.Visible = false
            end
        end)

    elseif kind == "Close" then
        opened = false
        resultId += 1
        panel.Visible = false
    end
end)

player:GetAttributeChangedSignal("BombTagAFK"):Connect(function()
    panel.Visible =
        opened
        and player:GetAttribute("BombTagAFK") ~= true
end)

RunService.RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera

    if camera then
        local viewport = camera.ViewportSize

        scale.Scale = math.clamp(
            (viewport.X - 24) / 500,
            0.58,
            1
        )
    end

    if opened then
        countdown.Text =
            tostring(
                math.max(
                    0,
                    math.ceil(deadline - workspace:GetServerTimeNow())
                )
            ) .. "s"
    end
end)

remote:FireServer("Sync")
