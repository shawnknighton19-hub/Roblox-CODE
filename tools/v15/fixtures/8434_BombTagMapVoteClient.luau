--!nonstrict
-- BOMB TAG V5 PREMIUM 3D MAP VOTING CLIENT
-- Separate from your custom HUD.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local p = Players.LocalPlayer
local remote = RS:WaitForChild("BombTagMapVoteEvent")
local gallery = RS:WaitForChild("BombTagPreviewGalleryV5")

local pg = p:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("BombTagMapVoteGui")

if old then
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "BombTagMapVoteGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 175
gui.IgnoreGuiInset = false
gui.Parent = pg

--------------------------------------------------
-- GUI HELPERS
--------------------------------------------------

local function new(class, parent, properties)
    local x = Instance.new(class)

    for k, v in pairs(properties) do
        x[k] = v
    end

    x.Parent = parent
    return x
end

local function corner(parent, radius)
    new("UICorner", parent, {
        CornerRadius = UDim.new(0, radius),
    })
end

local function outline(parent, color, thickness)
    return new("UIStroke", parent, {
        Color = color,
        Thickness = thickness or 1.5,
    })
end

local white = Color3.fromRGB(246, 249, 250)
local green = Color3.fromRGB(72, 239, 113)
local gray = Color3.fromRGB(104, 116, 113)

--------------------------------------------------
-- MAIN WINDOW
--------------------------------------------------

local root = new("Frame", gui, {
    Name = "VotingWindow",

    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(935, 484),

    BackgroundColor3 = Color3.fromRGB(22, 26, 29),
    BackgroundTransparency = 0.025,
    BorderSizePixel = 0,

    Visible = false,
    ZIndex = 10,
})

corner(root, 12)
outline(root, gray, 2)

local function label(parent, value, pos, size, fontSize, color, z)
    return new("TextLabel", parent, {
        BackgroundTransparency = 1,
        Position = pos,
        Size = size,

        Text = value,
        TextColor3 = color or white,

        Font = Enum.Font.GothamBold,
        TextScaled = true,
        TextSize = fontSize,
        TextStrokeTransparency = 0.6,

        ZIndex = z or 12,
    })
end

local caption = label(
    root,
    "BOMB TAG  /  NEXT ARENA",
    UDim2.fromOffset(18, 10),
    UDim2.fromOffset(400, 18),
    13, green
)

caption.TextXAlignment = Enum.TextXAlignment.Left

local title = label(
    root,
    "CHOOSE A MAP",
    UDim2.fromOffset(18, 31),
    UDim2.fromOffset(650, 41),
    30, white
)

title.TextXAlignment = Enum.TextXAlignment.Left

local time = label(
    root,
    "8s",
    UDim2.new(1, -108, 0, 21),
    UDim2.fromOffset(90, 43),
    27,
    Color3.fromRGB(255, 210, 115)
)

local footer = label(
    root,
    "TAP A MAP TO VOTE  •  MOST VOTES WINS",
    UDim2.new(0, 17, 1, -29),
    UDim2.new(1, -34, 0, 19),
    12,
    Color3.fromRGB(166, 183, 173)
)

footer.TextXAlignment = Enum.TextXAlignment.Left

--------------------------------------------------
-- VOTING STATE
--------------------------------------------------

local cards = {}
local options = {}
local counts = {}

local selected = nil
local open = false
local endsAt = 0

local backgrounds = {
    ["Sky Garden"] = Color3.fromRGB(83, 151, 107),
    ["Sunset Docks"] = Color3.fromRGB(129, 95, 74),
    ["Neon District"] = Color3.fromRGB(38, 68, 101),
    ["Crystal Cavern"] = Color3.fromRGB(69, 52, 100),
}

local subt = {
    ["Sky Garden"] = "GARDENS • FOUNTAIN • HEDGE HIDES",
    ["Sunset Docks"] = "HARBOR • CRANES • CARGO HIDES",
    ["Neon District"] = "STREETS • ALLEYS • NEON",
    ["Crystal Cavern"] = "GLOWING CRYSTALS • ROCK CAVES",
}

--------------------------------------------------
-- CREATE THREE VOTING CARDS
--------------------------------------------------

for i = 1, 3 do
    local box = new("TextButton", root, {
        Name = "VoteCard" .. i,
        Text = "",

        BackgroundColor3 = Color3.fromRGB(34, 41, 44),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 12,
    })

    corner(box, 10)

    local stroke = outline(box, gray, 1.7)

    -- Each card renders a real miniature 3D arena.

    local view = new("ViewportFrame", box, {
        Name = "Live3DPreview",

        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.new(1, -16, 1, -100),

        BackgroundColor3 = Color3.fromRGB(58, 88, 74),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,

        Ambient = Color3.fromRGB(190, 204, 224),
        LightColor = Color3.fromRGB(255, 245, 229),
        LightDirection = Vector3.new(-0.6, -1, -0.3),

        ZIndex = 13,
    })

    corner(view, 7)

    local world = new("WorldModel", view, {})

    local camera = new("Camera", view, {
        FieldOfView = 42,
    })

    camera.CFrame = CFrame.lookAt(
        Vector3.new(42, 35, 44),
        Vector3.new(0, 2, 0)
    )

    view.CurrentCamera = camera

    local name = label(
        box,
        "MAP",
        UDim2.new(0, 13, 1, -87),
        UDim2.new(1, -26, 0, 29),
        21, white, 15
    )

    name.TextXAlignment = Enum.TextXAlignment.Left

    local info = label(
        box,
        "",
        UDim2.new(0, 13, 1, -57),
        UDim2.new(1, -26, 0, 19),
        11, green, 15
    )

    info.TextXAlignment = Enum.TextXAlignment.Left

    local voteCount = label(
        box,
        "0 VOTES",
        UDim2.new(0, 13, 1, -31),
        UDim2.new(1, -26, 0, 20),
        16, white, 15
    )

    voteCount.TextXAlignment = Enum.TextXAlignment.Left

    local tick = label(
        box,
        "✓ VOTED",
        UDim2.new(1, -96, 1, -34),
        UDim2.fromOffset(84, 25),
        13, green, 16
    )

    tick.Visible = false

    local entry = {
        box = box,
        stroke = stroke,
        view = view,
        world = world,
        name = name,
        info = info,
        votes = voteCount,
        tick = tick,
        renderedName = nil,
    }

    cards[i] = entry

    box.Activated:Connect(function()
        if not open or not options[i] then
            return
        end

        selected = options[i]
        remote:FireServer("Vote", selected)

        for j, item in ipairs(cards) do
            item.stroke.Color =
                options[j] == selected and green or gray

            item.tick.Visible =
                options[j] == selected
        end
    end)
end

--------------------------------------------------
-- RESPONSIVE SCREEN LAYOUT
--------------------------------------------------

local lastScreen = Vector2.zero

local function layout()
    local cam = workspace.CurrentCamera

    local s =
        cam and cam.ViewportSize
        or Vector2.new(1280, 720)

    if s.X < 50 then
        return
    end

    local compact = s.X < 720

    local w = math.min(s.X - 18, 935)

    local h =
        compact
        and math.min(s.Y - 18, 550)
        or math.min(s.Y - 18, 484)

    root.Size = UDim2.fromOffset(w, h)

    local start = compact and 78 or 85
    local spacing = compact and 7 or 11

    local cardW =
        compact
        and w - 32
        or (w - 32 - 2 * spacing) / 3

    local cardH =
        compact
        and (h - start - 34 - spacing * 2) / 3
        or (h - start - 36)

    for i, e in ipairs(cards) do
        e.box.Position = UDim2.fromOffset(
            16 + (
                compact
                and 0
                or (i - 1) * (cardW + spacing)
            ),

            start + (
                compact
                and (i - 1) * (cardH + spacing)
                or 0
            )
        )

        e.box.Size = UDim2.fromOffset(cardW, cardH)

        if compact then
            local vw = math.max(
                72,
                math.min(140, cardW * 0.38)
            )

            e.view.Position = UDim2.fromOffset(7, 7)
            e.view.Size = UDim2.new(0, vw, 1, -14)

            local x = vw + 13

            e.name.Position = UDim2.fromOffset(x, 7)
            e.name.Size = UDim2.new(1, -x - 7, 0, 28)

            e.info.Position = UDim2.fromOffset(x, 35)
            e.info.Size = UDim2.new(1, -x - 7, 0, 22)

            e.votes.Position = UDim2.new(0, x, 1, -29)
            e.votes.Size = UDim2.new(1, -x - 7, 0, 21)

            e.tick.Position = UDim2.new(1, -89, 0, 5)

        else
            e.view.Position = UDim2.fromOffset(8, 8)
            e.view.Size = UDim2.new(1, -16, 1, -107)

            e.name.Position = UDim2.new(0, 13, 1, -94)
            e.name.Size = UDim2.new(1, -26, 0, 33)

            e.info.Position = UDim2.new(0, 13, 1, -62)
            e.info.Size = UDim2.new(1, -26, 0, 19)

            e.votes.Position = UDim2.new(0, 13, 1, -32)
            e.votes.Size = UDim2.new(1, -26, 0, 20)

            e.tick.Position = UDim2.new(1, -96, 1, -33)
        end
    end
end

--------------------------------------------------
-- DISPLAY ACTUAL 3D MAP PREVIEWS
--------------------------------------------------

local function redraw()
    for i, e in ipairs(cards) do
        local name = options[i]

        e.box.Visible = name ~= nil

        if name then
            e.name.Text = name:upper()
            e.info.Text = subt[name] or "BOMB TAG ARENA"

            e.view.BackgroundColor3 =
                backgrounds[name] or gray

            e.votes.Text =
                tostring(counts[name] or 0) .. " VOTES"

            e.tick.Visible = selected == name
            e.stroke.Color = selected == name and green or gray

            if e.renderedName ~= name then
                for _, o in ipairs(e.world:GetChildren()) do
                    o:Destroy()
                end

                local preview = gallery:FindFirstChild(name)

                if preview then
                    preview:Clone().Parent = e.world
                end

                e.renderedName = name
            end
        end
    end

    layout()
end

--------------------------------------------------
-- SERVER EVENTS
--------------------------------------------------

local resultSerial = 0

remote.OnClientEvent:Connect(function(kind, data)
    data = data or {}

    if kind == "Open" or kind == "Sync" then
        open = data.Open == true

        options = data.Options or {}
        counts = data.Counts or {}
        endsAt = data.EndsAt or 0

        if open then
            selected = nil
            title.Text = "CHOOSE A MAP"
            redraw()
        end

        root.Visible = open

    elseif kind == "Counts" then
        counts = data.Counts or {}
        redraw()

    elseif kind == "Result" then
        open = false
        resultSerial += 1

        local id = resultSerial

        title.Text =
            "WINNING MAP: "
            .. tostring(data.Chosen or "UNKNOWN"):upper()

        root.Visible = true

        task.delay(1.4, function()
            if id == resultSerial and not open then
                root.Visible = false
            end
        end)

    elseif kind == "Close" then
        open = false
        resultSerial += 1
        root.Visible = false
    end
end)

--------------------------------------------------
-- VOTING TIMER
--------------------------------------------------

RunService.RenderStepped:Connect(function()
    local cam = workspace.CurrentCamera

    local size =
        cam and cam.ViewportSize
        or Vector2.new(1280, 720)

    if (size - lastScreen).Magnitude > 2 then
        lastScreen = size
        layout()
    end

    if open then
        time.Text =
            tostring(
                math.max(
                    0,
                    math.ceil(
                        endsAt - workspace:GetServerTimeNow()
                    )
                )
            ) .. "s"
    end
end)

layout()
remote:FireServer("Sync")
