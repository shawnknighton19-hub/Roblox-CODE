--!nonstrict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Controllers > MapVoteController
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)
local player = Players.LocalPlayer
local Controller = {}
local C = {ink = Color3.fromRGB(7, 10, 9), panel = Color3.fromRGB(19, 25, 22),
	line = Color3.fromRGB(83, 106, 93), white = Color3.fromRGB(245, 249, 245),
	muted = Color3.fromRGB(160, 177, 166), green = Color3.fromRGB(144, 255, 106),
	red = Color3.fromRGB(255, 91, 104)}
local ui, cards, connections, cardConnections = {}, {}, {}, {}
local state, started, visible, visibilityChanged = nil, false, false, nil
local revision, openedVote, lastCast, elapsed = -1, nil, -math.huge, 0
local signature, lastSize = "", Vector2.zero
local layout, refresh

local function connect(signal, callback, bucket)
	local connection = signal:Connect(callback)
	table.insert(bucket or connections, connection)
	return connection
end
local function disconnect(bucket)
	for _, connection in ipairs(bucket) do connection:Disconnect() end
	table.clear(bucket)
end
local function make(class, parent, properties)
	local object = Instance.new(class)
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end
local function frame(parent, name, color, z)
	return make("Frame", parent, {Name = name, BackgroundColor3 = color or C.panel,
		BorderSizePixel = 0, ZIndex = z or 1})
end
local function corner(object, radius)
	make("UICorner", object, {CornerRadius = UDim.new(0, radius or 7)})
end
local function stroke(object, color)
	return make("UIStroke", object, {Color = color or C.line, Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end
local function label(parent, name, text, size, color)
	local object = make("TextLabel", parent, {Name = name, Text = text, BackgroundTransparency = 1,
		BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = size, TextScaled = true,
		TextColor3 = color or C.white, TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = C.ink, TextStrokeTransparency = 0.45, ZIndex = parent.ZIndex + 2})
	make("UITextSizeConstraint", object, {MinTextSize = 10, MaxTextSize = size})
	return object
end
local function rect(object, x, y, w, h)
	object.Position, object.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
end
local function remaining()
	return state and math.max(0, (tonumber(state.EndsAt) or 0) - workspace:GetServerTimeNow()) or 0
end
local function canVote()
	return state and state.Active == true and remaining() > 0 and player:GetAttribute("InRound") ~= true
end
local function focusWithin()
	local selected = GuiService.SelectedObject
	return selected and ui.Gui and selected:IsDescendantOf(ui.Gui)
end
function Controller.Close()
	if not visible then return end
	visible = false
	ui.Root.Visible = false
	if focusWithin() then GuiService.SelectedObject = nil end
	if visibilityChanged then visibilityChanged(false) end
end
function Controller.Open()
	if not started or player:GetAttribute("InRound") == true then return end
	if not visible then
		visible, ui.Root.Visible = true, true
		if visibilityChanged then visibilityChanged(true) end
	end
	layout()
	refresh()
	if UserInputService:GetLastInputType().Name:find("Gamepad") then
		GuiService.SelectedObject = cards[1] and cards[1].Button or ui.Close
	end
end
function Controller.GetActiveMapName()
	if state then
		for _, option in ipairs(state.Options or {}) do
			if option.Id == state.ActiveMapId then return option.Name end
		end
	end
	return "Arena"
end

local function build()
	ui.Gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "BombTagMapVote",
		ResetOnSpawn = false, DisplayOrder = 130, IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
	ui.Root = frame(ui.Gui, "SafeRoot", C.ink)
	ui.Root.Size, ui.Root.BackgroundTransparency, ui.Root.Visible = UDim2.fromScale(1, 1), 1, false
	local backdrop = make("TextButton", ui.Root, {Name = "Dismiss", Text = "", Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Selectable = false, ZIndex = 1})
	connect(backdrop.Activated, Controller.Close)
	ui.Panel = frame(ui.Root, "MapPicker", C.panel, 3)
	ui.Panel.AnchorPoint, ui.Panel.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	ui.Panel.BackgroundTransparency, ui.Panel.Active = 0.06, true
	corner(ui.Panel, 9)
	stroke(ui.Panel)
	ui.Brand = label(ui.Panel, "Brand", "B O M B  T A G   /   M A P S", 10, C.green)
	ui.Title = label(ui.Panel, "Title", "CHOOSE AN ARENA", 29)
	ui.Timer = label(ui.Panel, "Timer", "", 16, C.green)
	ui.Timer.TextXAlignment = Enum.TextXAlignment.Right
	ui.Close = make("TextButton", ui.Panel, {Name = "Close", Text = "X", AutoButtonColor = true,
		BackgroundColor3 = C.red, BorderSizePixel = 0, TextColor3 = C.ink,
		Font = Enum.Font.GothamBold, TextSize = 19, ZIndex = 8})
	corner(ui.Close, 5)
	connect(ui.Close.Activated, Controller.Close)
	ui.Rule = frame(ui.Panel, "Divider", C.line, 5)
	ui.Rule.BackgroundTransparency = 0.45
	ui.Cards = make("ScrollingFrame", ui.Panel, {Name = "Arenas", BackgroundTransparency = 1,
		BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(0, 0), ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.green, ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true, ZIndex = 5})
	ui.Footer = label(ui.Panel, "Footer", "Loading arenas...", 12, C.muted)
	ui.Footer.TextWrapped = true
end
local function rebuild(options)
	disconnect(cardConnections)
	for _, card in ipairs(cards) do card.Button:Destroy() end
	table.clear(cards)
	for index, option in ipairs(options) do
		local button = make("TextButton", ui.Cards, {Name = option.Id .. "Card", Text = "",
			AutoButtonColor = false, BackgroundColor3 = C.ink, BackgroundTransparency = 0.12,
			BorderSizePixel = 0, ZIndex = 6, LayoutOrder = index})
		corner(button)
		local card = {Button = button, Rim = stroke(button), Id = option.Id, Hovered = false}
		card.Accent = typeof(option.Accent) == "Color3" and option.Accent or C.green
		card.Preview = frame(button, "TopView", C.panel:Lerp(card.Accent, 0.12), 7)
		card.Preview.ClipsDescendants = true
		corner(card.Preview, 3)
		for i = 1, 3 do
			local x, z = frame(card.Preview, "GridX", C.line, 8), frame(card.Preview, "GridZ", C.line, 8)
			x.Position, x.Size = UDim2.fromScale(i / 4, 0), UDim2.new(0, 1, 1, 0)
			z.Position, z.Size = UDim2.fromScale(0, i / 4), UDim2.new(1, 0, 0, 1)
			x.BackgroundTransparency, z.BackgroundTransparency = 0.65, 0.65
		end
		for i, footprint in ipairs(option.Layout or {}) do
			local color = footprint.Kind == "Water" and Color3.fromRGB(54, 128, 155) or card.Accent:Lerp(C.white, 0.15)
			local shape = frame(card.Preview, "Footprint" .. i, color, 9)
			shape.AnchorPoint = Vector2.new(0.5, 0.5)
			shape.Position = UDim2.fromScale(footprint.X, footprint.Z)
			shape.Size = UDim2.fromScale(footprint.W, footprint.D)
			shape.BackgroundTransparency = footprint.Kind == "Path" and 0.6 or 0.22
		end
		card.ViewLabel = label(button, "PreviewCaption", "TOP VIEW", 9, C.muted)
		card.Name = label(button, "MapName", tostring(option.Name):upper(), 21)
		card.Name.TextWrapped = true
		card.Subtitle = label(button, "Description", tostring(option.Subtitle or "OPEN LANES / ROOM TO DODGE"), 11, C.muted)
		card.Subtitle.TextWrapped = true
		card.Status = label(button, "SelectionStatus", "VOTE", 11, C.green)
		card.Count = label(button, "VoteCount", "0 VOTES", 12, C.white)
		card.Count.TextXAlignment = Enum.TextXAlignment.Right
		connect(button.Activated, function()
			if canVote() and time() - lastCast >= 0.15 then
				lastCast = time()
				Remotes.Get("MapVoteCast"):FireServer(state.VoteId, option.Id)
			end
		end, cardConnections)
		local function highlight(value) card.Hovered = value; refresh() end
		connect(button.MouseEnter, function() highlight(true) end, cardConnections)
		connect(button.MouseLeave, function() highlight(false) end, cardConnections)
		connect(button.SelectionGained, function() highlight(true) end, cardConnections)
		connect(button.SelectionLost, function() highlight(false) end, cardConnections)
		table.insert(cards, card)
	end
	layout()
end

layout = function()
	local size = ui.Root.AbsoluteSize
	if size.X < 1 or size.Y < 1 then return end
	lastSize = size
	local portrait = size.X < 570 and size.Y >= 420
	local width, height = math.min(940, size.X - 24), math.min(portrait and 640 or 490, size.Y - 24)
	local padding, gap = width < 600 and 14 or 22, 12
	local bodyWidth, bodyHeight = width - padding * 2, height - 146
	ui.Panel.Size = UDim2.fromOffset(width, height)
	rect(ui.Brand, padding, 14, width - padding * 2 - 60, 14)
	rect(ui.Title, padding, 37, width - padding * 2 - 60, 34)
	rect(ui.Close, width - padding - 44, 16, 44, 44)
	rect(ui.Timer, width - padding - 128, 73, 128, 17)
	rect(ui.Rule, padding, 98, bodyWidth, 1)
	rect(ui.Cards, padding, 109, bodyWidth, bodyHeight)
	rect(ui.Footer, padding, height - 30, bodyWidth, 23)
	local cardWidth = portrait and bodyWidth - 5 or (bodyWidth - gap * 2 - 5) / 3
	local cardHeight = portrait and 132 or math.max(155, bodyHeight - 2)
	ui.Cards.CanvasSize = UDim2.fromOffset(0, portrait and #cards * (cardHeight + gap) - gap + 2 or cardHeight + 2)
	for index, card in ipairs(cards) do
		rect(card.Button, 1 + (portrait and 0 or (index - 1) * (cardWidth + gap)), portrait and (index - 1) * (cardHeight + gap) + 1 or 1, cardWidth - 2, cardHeight)
		local previewSize = portrait and 88 or math.max(48, math.min(cardWidth - 24, cardHeight - 122))
		rect(card.Preview, portrait and 12 or (cardWidth - previewSize) / 2 - 1, 12, previewSize, previewSize)
		if portrait then
			local textX, textWidth = 113, cardWidth - 128
			rect(card.ViewLabel, 12, 104, 90, 13)
			rect(card.Name, textX, 12, textWidth, 40)
			rect(card.Subtitle, textX, 57, textWidth, 32)
			rect(card.Status, textX, 101, textWidth * 0.53, 18)
			rect(card.Count, textX + textWidth * 0.53, 101, textWidth * 0.47, 18)
		else
			rect(card.ViewLabel, 12, previewSize + 16, cardWidth - 24, 12)
			rect(card.Name, 12, previewSize + 35, cardWidth - 24, 32)
			rect(card.Subtitle, 12, previewSize + 70, cardWidth - 24, 24)
			rect(card.Status, 12, cardHeight - 24, (cardWidth - 24) * 0.53, 16)
			rect(card.Count, cardWidth * 0.53 - 1, cardHeight - 24, (cardWidth - 24) * 0.47, 16)
		end
	end
end
refresh = function()
	if not started then return end
	local active = state and state.Active == true
	ui.Title.Text = active and "CHOOSE AN ARENA" or "THE ARENAS"
	ui.Timer.Text = active and (remaining() > 0 and (math.ceil(remaining()) .. "s TO VOTE") or "CHOOSING MAP...") or "3 ARENAS"
	ui.Footer.Text = not state and "Loading arenas..." or (active and "Tap an arena to vote. You can change your vote." or "Voting opens before each round.")
	for _, card in ipairs(cards) do
		local selected = state and (active and state.YourVote == card.Id or not active and state.ActiveMapId == card.Id)
		card.Rim.Color = selected and C.green or (card.Hovered and card.Accent or C.line)
		card.Rim.Thickness = selected and 2 or 1
		card.Button.BackgroundColor3 = selected and C.panel:Lerp(C.green, 0.07) or C.ink
		card.Status.Text = active and (selected and "YOUR VOTE" or "VOTE") or (selected and "CURRENT" or "ARENA")
		card.Status.TextColor3 = selected and C.green or C.muted
		local count = math.max(0, math.floor(tonumber(state and state.Counts and state.Counts[card.Id]) or 0))
		card.Count.Text = active and (count .. (count == 1 and " VOTE" or " VOTES")) or ""
	end
end
local function receive(data)
	if typeof(data) ~= "table" or typeof(data.Options) ~= "table" then return end
	local nextRevision = tonumber(data.Revision) or 0
	if nextRevision < revision then return end
	local wasActive = state and state.Active == true
	state, revision = data, nextRevision
	local parts = {}
	for _, option in ipairs(data.Options) do table.insert(parts, tostring(option.Id)) end
	local nextSignature = table.concat(parts, "|")
	if nextSignature ~= signature then signature = nextSignature; rebuild(data.Options) end
	refresh()
	if data.Active == true and data.VoteId ~= openedVote then
		openedVote = data.VoteId
		Controller.Open()
	elseif wasActive and data.Active ~= true then
		Controller.Close()
	end
end
function Controller.Init(onVisibilityChanged)
	if started then return end
	started, visibilityChanged = true, onVisibilityChanged
	build()
	connect(Remotes.Get("MapVoteState").OnClientEvent, receive)
	connect(UserInputService.InputBegan, function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then Controller.Close() end
	end)
	connect(player:GetAttributeChangedSignal("InRound"), function()
		if player:GetAttribute("InRound") == true then Controller.Close() end
	end)
	connect(RunService.RenderStepped, function(dt)
		if ui.Root.AbsoluteSize ~= lastSize then layout() end
		elapsed += dt
		if visible and elapsed >= 0.1 then elapsed = 0; refresh() end
	end)
	layout()
	refresh()
	Remotes.Get("MapVoteSync"):FireServer()
end
function Controller.Destroy()
	if not started then return end
	Controller.Close()
	disconnect(connections)
	disconnect(cardConnections)
	ui.Gui:Destroy()
	ui, cards, state, visibilityChanged = {}, {}, nil, nil
	started, revision, openedVote, signature = false, -1, nil, ""
	lastSize, lastCast, elapsed = Vector2.zero, -math.huge, 0
end
return Controller
