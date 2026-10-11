--!nonstrict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Controllers > HudController
-- Preserves the existing RoundState, BombState and SnappyMovement contracts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local GameConfig = require(Shared.Config.GameConfig)

local HudController = {}
local C = {
	ink = Color3.fromRGB(7, 10, 9), panel = Color3.fromRGB(19, 25, 22),
	line = Color3.fromRGB(83, 106, 93), white = Color3.fromRGB(245, 249, 245),
	muted = Color3.fromRGB(160, 177, 166), green = Color3.fromRGB(144, 255, 106),
	red = Color3.fromRGB(255, 91, 104), gold = Color3.fromRGB(255, 209, 105),
}
local PHASES = {WAITING = "WAITING FOR PLAYERS", INTERMISSION = "NEXT MATCH",
	STARTING = "GET READY", PRACTICE = "PRACTICE", PRACTICE_ENDING = "PLAYER JOINING",
	ROUND = "MATCH LIVE", FINAL_DUEL = "FINAL DUEL", RESULT = "ROUND COMPLETE"}
local COOLDOWN = 1.5
local ui, connections, characterConnections, hiddenHealth = {}, {}, {}, {}
local tweens = {}
local started, reduced, activeMenu = false, false, nil
local phase, phaseDuration, phaseAt, alive = "WAITING", nil, 0, nil
local bombActive, bombOwner, bombName, bombEnd = false, 0, "", 0
local character, humanoid, lastDodge = nil, nil, -math.huge
local life, countToken, toastToken, lastCount = 0, 0, 0, nil
local lastSize, lastRound, elapsed, statsElapsed = Vector2.zero, nil, 0, 0
local inputType = UserInputService:GetLastInputType()
local refresh, layout, closeModal, showModal

local function number(value, fallback)
	local n = tonumber(value)
	return n and n == n and math.abs(n) < math.huge and n or fallback
end
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
local function set(object, key, value)
	if object[key] ~= value then object[key] = value end
end
local function corner(object, radius)
	make("UICorner", object, {CornerRadius = UDim.new(0, radius or 6)})
end
local function outline(object, color, transparency)
	return make("UIStroke", object, {Color = color or C.line, Thickness = 1,
		Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end
local function box(parent, name, x, y, w, h, color, z, transparency)
	return make("Frame", parent, {Name = name, Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h), BackgroundColor3 = color or C.ink,
		BackgroundTransparency = transparency or 0, BorderSizePixel = 0, ZIndex = z or 1})
end
local function label(parent, name, value, x, y, w, h, size, color, z, align)
	local object = make("TextLabel", parent, {Name = name, Text = value,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.GothamBold,
		TextSize = size, TextScaled = true, TextColor3 = color or C.white,
		TextStrokeColor3 = C.ink, TextStrokeTransparency = 0.45,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center, ZIndex = z or 4})
	make("UITextSizeConstraint", object, {MinTextSize = 8, MaxTextSize = size})
	return object
end
local function animate(object, seconds, target)
	if tweens[object] then tweens[object]:Cancel() end
	if reduced then
		for key, value in pairs(target) do object[key] = value end
		return
	end
	local tween = TweenService:Create(object, TweenInfo.new(seconds,
		Enum.EasingStyle.Quart, Enum.EasingDirection.Out), target)
	tweens[object] = tween
	tween:Play()
end
local function panel(parent, name, w, h, z, accent)
	local holder = box(parent, name, 0, 0, w, h, C.ink, z, 1)
	local shadow = box(holder, "Shadow", 0, 4, w, h, C.ink, z, 0.65)
	shadow.Size = UDim2.fromScale(1, 1)
	corner(shadow, 8)
	local face = box(holder, "Panel", 0, 0, w, h, C.panel, z + 1, 0.13)
	face.Size = UDim2.fromScale(1, 1)
	corner(face, 8)
	local rim = outline(face, accent or C.line, accent and 0.12 or 0.3)
	make("UIGradient", face, {Color = ColorSequence.new(C.white, Color3.fromRGB(145, 163, 151)), Rotation = 90})
	local glint = box(face, "TopEdge", 9, 1, w - 18, 1, accent or C.white, z + 2, 0.8)
	glint.Size = UDim2.new(1, -18, 0, 1)
	return holder, face, make("UIScale", holder, {Scale = 1}), rim
end
local function action(parent, name, caption, x, y, w, h, callback, danger)
	local object = make("TextButton", parent, {Name = name, Text = caption,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BorderSizePixel = 0,
		BackgroundColor3 = danger and C.red or C.panel, BackgroundTransparency = danger and 0 or 0.1,
		TextColor3 = danger and C.ink or C.white, Font = Enum.Font.GothamBold,
		TextSize = 14, AutoButtonColor = false, ZIndex = parent.ZIndex + 3})
	corner(object, 5)
	local rim = outline(object, danger and C.red or C.line, 0.1)
	local function highlight(on)
		animate(rim, 0.13, {Color = on and C.green or (danger and C.red or C.line)})
		animate(object, 0.13, {BackgroundColor3 = on and C.panel:Lerp(C.green, 0.13) or (danger and C.red or C.panel)})
	end
	connect(object.MouseEnter, function() highlight(true) end)
	connect(object.MouseLeave, function() highlight(false) end)
	connect(object.SelectionGained, function() highlight(true) end)
	connect(object.SelectionLost, function() highlight(false) end)
	connect(object.Activated, callback)
	return object
end
local function bar(parent, name, x, y, w, h, color)
	local track = box(parent, name .. "Track", x, y, w, h, C.ink, parent.ZIndex + 2)
	corner(track, 2)
	local fill = box(track, name .. "Fill", 0, 0, w, h, color, track.ZIndex + 1)
	fill.Size = UDim2.fromScale(1, 1)
	corner(fill, 2)
	return fill
end
local function stat(key)
	local folder = player:FindFirstChild("leaderstats")
	local value = folder and folder:FindFirstChild(key)
	if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then return number(value.Value) end
	return number(player:GetAttribute(key))
end
local function formatStat(value)
	if value == nil then return "—" end
	local result = tostring(math.floor(value))
	return (result:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end
local function keyboard()
	return inputType ~= Enum.UserInputType.Touch and not string.find(inputType.Name, "Gamepad")
end
local function gamepad()
	return string.find(inputType.Name, "Gamepad") ~= nil
end

local function buildUI()
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("BombTagHUD")
	if old then old:Destroy() end
	ui.Gui = make("ScreenGui", pg, {Name = "BombTagHUD", ResetOnSpawn = false,
		DisplayOrder = 120, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
	ui.Root = box(ui.Gui, "SafeRoot", 0, 0, 1, 1, C.ink, 1, 1)
	ui.Root.Size = UDim2.fromScale(1, 1)
	local top, face, scale = panel(ui.Root, "RoundStatus", 280, 62, 5)
	ui.Top, ui.TopScale = top, scale
	ui.TopIndicator = box(face, "StatusBar", 13, 16, 3, 30, C.green, 8)
	label(face, "Brand", "B O M B  T A G", 28, 8, 237, 14, 10, C.muted, 8, Enum.TextXAlignment.Center)
	ui.TopTitle = label(face, "Phase", "WAITING FOR PLAYERS", 27, 25, 239, 22, 19, C.white, 8, Enum.TextXAlignment.Center)
	ui.TopDetail = label(face, "Subtitle", "", 26, 47, 240, 12, 10, C.green, 8, Enum.TextXAlignment.Center)
	local alivePanel, aliveFace, aliveScale = panel(ui.Root, "PlayersBadge", 112, 58, 5)
	ui.Alive, ui.AliveScale = alivePanel, aliveScale
	ui.AliveCount = label(aliveFace, "PlayerNumber", "1", 12, 10, 39, 36, 29, C.white, 8)
	ui.AliveText = label(aliveFace, "PlayerCaption", "PLAYERS", 55, 19, 50, 20, 10, C.green, 8)
	local health, healthFace, healthScale = panel(ui.Root, "HealthBadge", 178, 58, 5)
	ui.Health, ui.HealthScale = health, healthScale
	label(healthFace, "Caption", "VITALS", 12, 8, 66, 15, 10, C.muted, 8)
	ui.HealthText = label(healthFace, "Health", "100 / 100", 77, 7, 88, 20, 14, C.white, 8, Enum.TextXAlignment.Right)
	ui.HealthFill = bar(healthFace, "Health", 12, 36, 154, 6, C.green)
	local bomb, bombFace, bombScale, bombRim = panel(ui.Root, "BombStatus", 218, 116, 5)
	ui.Bomb, ui.BombScale, ui.BombRim = bomb, bombScale, bombRim
	ui.BombTitle = label(bombFace, "Title", "BOMB ACTIVE", 12, 9, 194, 17, 12, C.gold, 8)
	ui.BombTime = label(bombFace, "Time", "14.0", 12, 27, 153, 43, 39, C.white, 8)
	label(bombFace, "Seconds", "SEC", 164, 47, 39, 18, 10, C.muted, 8)
	ui.BombOwner = label(bombFace, "Carrier", "", 12, 76, 194, 17, 12, C.muted, 8)
	ui.BombFill = bar(bombFace, "Fuse", 12, 102, 194, 4, C.gold)
	local dash, dashFace, dashScale = panel(ui.Root, "DashStrip", 400, 66, 5, C.green)
	ui.Dash, ui.DashScale = dash, dashScale
	ui.DashTitle = label(dashFace, "DashTitle", "DODGE", 14, 8, 125, 22, 18, C.white, 8)
	ui.DashHint = label(dashFace, "Hint", "WASD + SPACE", 14, 30, 166, 15, 10, C.muted, 8)
	ui.DashStatus = label(dashFace, "DashStatus", "READY", 192, 13, 192, 29, 19, C.green, 8, Enum.TextXAlignment.Right)
	ui.DashFill = bar(dashFace, "Dash", 14, 53, 372, 4, C.green)
	local immune, immuneFace, immuneScale = panel(ui.Root, "IFrameIndicator", 176, 27, 9, C.green)
	ui.Immune, ui.ImmuneScale = immune, immuneScale
	label(immuneFace, "Text", "DODGE IMMUNITY", 6, 4, 164, 19, 11, C.green, 12, Enum.TextXAlignment.Center)

	ui.Menu = box(ui.Root, "LobbyMenu", 0, 0, 190, 274, C.ink, 10, 1)
	label(ui.Menu, "Caption", "L O B B Y", 4, 0, 150, 16, 10, C.muted, 11)
	ui.MenuScroll = make("ScrollingFrame", ui.Menu, {Name = "MenuOptions", Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 1, -22), CanvasSize = UDim2.fromOffset(0, 254), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = C.green,
		ScrollingDirection = Enum.ScrollingDirection.Y, ClipsDescendants = true, ZIndex = 11})
	ui.MenuButtons = {}
	for i, page in ipairs({"STATS", "CONTROLS", "HOW TO PLAY", "MAPS", "SETTINGS"}) do
		local row = action(ui.MenuScroll, page .. "Button", "", 3, (i - 1) * 52 + 1, 180, 44, function() showModal(page) end)
		local stripe = box(row, "Accent", 0, 9, 2, 26, C.green, 15)
		stripe.BackgroundTransparency = 0.25
		label(row, "Index", string.format("%02d", i), 11, 12, 24, 18, 10, C.green, 16)
		local caption = label(row, "Caption", page, 40, 10, 117, 23, 13, C.white, 16)
		caption.Size = UDim2.new(1, -58, 0, 23)
		label(row, "Arrow", ">", 161, 12, 12, 18, 13, C.muted, 16).Position = UDim2.new(1, -21, 0, 12)
		table.insert(ui.MenuButtons, row)
	end
	ui.Currency = box(ui.Root, "Currency", 0, 0, 240, 43, C.ink, 5, 1)
	ui.CurrencyScale = make("UIScale", ui.Currency, {Scale = 1})
	for i, key in ipairs({"Coins", "Gems"}) do
		local card, body = panel(ui.Currency, key .. "Card", 116, 43, 6)
		card.Position = UDim2.fromOffset((i - 1) * 124, 0)
		label(body, "Caption", key:upper(), 10, 5, 96, 12, 9, key == "Coins" and C.gold or C.green, 9)
		ui[key] = label(body, "Value", "", 10, 19, 96, 20, 17, C.white, 9)
		ui[key .. "Card"] = card
	end
	local toast, toastFace, toastScale = panel(ui.Root, "ExplodedToast", 350, 60, 35, C.red)
	ui.Toast, ui.ToastScale = toast, toastScale
	label(toastFace, "Caption", "ELIMINATED", 12, 7, 326, 13, 10, C.red, 38, Enum.TextXAlignment.Center)
	ui.ToastText = label(toastFace, "Explosion", "", 12, 25, 326, 25, 20, C.white, 38, Enum.TextXAlignment.Center)
	toast.Visible = false
	local countdown = box(ui.Root, "Countdown", 0, 0, 1, 1, C.ink, 40, 1)
	countdown.Size = UDim2.fromScale(1, 1)
	ui.Countdown = countdown
	local countCard = box(countdown, "Center", 0, 0, 320, 234, C.ink, 41, 1)
	countCard.AnchorPoint, countCard.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.48)
	ui.CountScale = make("UIScale", countCard, {Scale = 1})
	label(countCard, "Title", "MATCH STARTING", 10, 7, 300, 23, 15, C.muted, 42, Enum.TextXAlignment.Center)
	ui.CountText = label(countCard, "Count", "3", 10, 33, 300, 151, 130, C.white, 42, Enum.TextXAlignment.Center)
	ui.CountText.Font = Enum.Font.GothamBlack
	ui.CountSub = label(countCard, "Sub", "GET READY TO RUN", 10, 199, 300, 21, 12, C.green, 42, Enum.TextXAlignment.Center)
	countdown.Visible = false

	ui.Results = box(ui.Root, "Results", 0, 0, 1, 1, C.ink, 50, 1)
	ui.Results.Size, ui.Results.Visible = UDim2.fromScale(1, 1), false
	local winner, winnerFace, winnerScale = panel(ui.Results, "Winner", 540, 326, 51, C.green)
	ui.Winner, ui.WinnerScale = winner, winnerScale
	winner.AnchorPoint, winner.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	label(winnerFace, "Caption", "B O M B  T A G   /   R E S U L T S", 22, 21, 448, 17, 11, C.muted, 55)
	ui.WinnerTitle = label(winnerFace, "Title", "WINNER", 24, 69, 492, 28, 20, C.green, 55, Enum.TextXAlignment.Center)
	ui.WinnerName = label(winnerFace, "Name", "", 28, 110, 484, 72, 48, C.white, 55, Enum.TextXAlignment.Center)
	ui.WinnerName.Font = Enum.Font.GothamBlack
	ui.WinnerDetail = label(winnerFace, "Detail", "LAST PLAYER STANDING", 24, 193, 492, 19, 12, C.muted, 55, Enum.TextXAlignment.Center)
	box(winnerFace, "Rule", 24, 234, 492, 1, C.line, 55, 0.5)
	ui.WinnerFooter = label(winnerFace, "Footer", "NEXT MATCH COMING UP", 24, 255, 326, 43, 12, C.green, 55)
	action(winnerFace, "Continue", "CONTINUE  >", 367, 258, 149, 42, function() ui.Results.Visible = false; refresh() end)
	action(winnerFace, "Close", "X", 484, 13, 44, 44, function() ui.Results.Visible = false; refresh() end, true)
	ui.ModalShade = box(ui.Root, "MenuBackdrop", 0, 0, 1, 1, C.ink, 70, 1)
	ui.ModalShade.Size, ui.ModalShade.Visible = UDim2.fromScale(1, 1), false
	local dismiss = make("TextButton", ui.ModalShade, {Name = "Dismiss", Text = "", Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Selectable = false,
		Active = true, ZIndex = 70})
	connect(dismiss.Activated, function() closeModal() end)
	local modal, modalFace, modalScale = panel(ui.ModalShade, "Popup", 600, 396, 71)
	ui.Modal, ui.ModalScale = modal, modalScale
	modal.AnchorPoint, modal.Position, modalFace.Active = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), true
	label(modalFace, "Badge", "B O M B  T A G   /   L O B B Y", 24, 18, 440, 16, 11, C.green, 75)
	ui.ModalTitle = label(modalFace, "Title", "", 24, 43, 466, 39, 31, C.white, 75)
	ui.CloseButton = action(modalFace, "Close", "X", 536, 18, 44, 44, function() closeModal() end, true)
	box(modalFace, "Separator", 24, 98, 552, 1, C.line, 75, 0.35)
	ui.ModalBody = make("ScrollingFrame", modalFace, {Name = "Body", Position = UDim2.fromOffset(24, 115),
		Size = UDim2.new(1, -48, 1, -135), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.green, ZIndex = 75})
	make("UIListLayout", ui.ModalBody, {Padding = UDim.new(0, 20), SortOrder = Enum.SortOrder.LayoutOrder})
	make("UIPadding", ui.ModalBody, {PaddingRight = UDim.new(0, 7), PaddingBottom = UDim.new(0, 6)})
	ui.ModalInfo = label(ui.ModalBody, "Content", "", 0, 0, 552, 0, 18, C.white, 76)
	ui.ModalInfo.TextWrapped, ui.ModalInfo.TextYAlignment = true, Enum.TextYAlignment.Top
	ui.ModalInfo.TextScaled, ui.ModalInfo.AutomaticSize = false, Enum.AutomaticSize.Y
	ui.ModalInfo.Size, ui.ModalInfo.LayoutOrder = UDim2.new(1, 0, 0, 0), 1
	ui.ModalAction = action(ui.ModalBody, "ModalAction", "REDUCE EFFECTS", 0, 0, 552, 50, function()
		reduced = not reduced
		for _, tween in pairs(tweens) do tween:Cancel() end
		ui.WinnerScale.Scale = ui.WinnerTarget or 1
		ui.ToastScale.Scale = ui.ToastTarget or 1
		ui.CountScale.Scale = ui.CountTarget or 1
		showModal("SETTINGS")
	end)
	ui.ModalAction.Size, ui.ModalAction.LayoutOrder = UDim2.new(1, 0, 0, 50), 3
	ui.MapPreview = box(ui.ModalBody, "MapPreview", 0, 0, 552, 153, C.ink, 76, 0.1)
	ui.MapPreview.Size, ui.MapPreview.LayoutOrder = UDim2.new(1, 0, 0, 153), 2
	corner(ui.MapPreview, 6)
	outline(ui.MapPreview, C.green, 0.35)
	label(ui.MapPreview, "Caption", "CURRENT ARENA", 20, 19, 512, 18, 11, C.green, 77).Size = UDim2.new(1, -40, 0, 18)
	ui.MapTitle = label(ui.MapPreview, "MapTitle", "ARENA01", 20, 52, 512, 42, 32, C.white, 76)
	ui.MapTitle.Size = UDim2.new(1, -40, 0, 42)
	label(ui.MapPreview, "Note", "STAY MOVING. KEEP THE FUSE AWAY.", 20, 113, 512, 17, 11, C.muted, 77).Size = UDim2.new(1, -40, 0, 17)
end

layout = function()
	local size = ui.Root.AbsoluteSize
	if size.X < 1 or size.Y < 1 then return end
	lastSize = size
	local w, h, margin = size.X, size.Y, 12
	local short = h < 430
	local narrow = w < 640 and not (short and w >= 500)
	local scale = math.clamp(math.min(w / 1100, h / 720), 0.84, 1.06)
	if short and not narrow then scale = math.min(scale, (w - 40) / 636) end
	local function place(object, scaling, x, y, ax, ay)
		object.AnchorPoint = Vector2.new(ax or 0, ay or 0)
		object.Position = UDim2.fromOffset(x, y)
		if scaling then scaling.Scale = scale end
	end
	place(ui.Top, ui.TopScale, w / 2, margin, 0.5, 0)
	local secondRow = narrow and (margin + 62 * scale + 10) or margin
	place(ui.Health, ui.HealthScale, margin, secondRow)
	place(ui.Alive, ui.AliveScale, w - margin, secondRow, 1, 0)
	place(ui.Bomb, ui.BombScale, w - margin, secondRow + 58 * scale + 10, 1, 0)
	local dashWidth = math.min(400, w - 2 * margin)
	if short and UserInputService.TouchEnabled then dashWidth = math.max(220, math.min(300, w - 260)) end
	local bottom = UserInputService.TouchEnabled and not short and 118 or 14
	ui.Dash.Size = UDim2.fromOffset(dashWidth, 66)
	place(ui.Dash, nil, w / 2, h - bottom, 0.5, 1)
	ui.DashStatus.Position, ui.DashStatus.Size = UDim2.new(0.5, 0, 0, 13), UDim2.new(0.5, -14, 0, 29)
	ui.DashTitle.Size, ui.DashHint.Size = UDim2.new(0.5, -20, 0, 22), UDim2.new(0.5, -20, 0, 15)
	ui.DashFill.Parent.Size = UDim2.new(1, -28, 0, 4)
	local immuneX = w / 2
	if short and UserInputService.TouchEnabled then immuneX = math.min(immuneX, w - margin - 218 * scale - 100) end
	place(ui.Immune, nil, immuneX, h - bottom - 74, 0.5, 1)
	local menuTop = margin + 62 * scale + 16
	local menuBottom = h - 62
	local menuHeight = math.max(66, math.min(278, menuBottom - menuTop))
	ui.Menu.Size = UDim2.fromOffset(narrow and 162 or 190, menuHeight)
	ui.Menu.Position = UDim2.fromOffset(margin, math.clamp((h - menuHeight) / 2, menuTop, math.max(menuTop, menuBottom - menuHeight)))
	for _, row in ipairs(ui.MenuButtons) do row.Size = UDim2.new(1, -9, 0, 44) end
	ui.CurrencyScale.Scale = math.min(1, (w - margin * 2) / 240)
	place(ui.Currency, nil, margin, h - margin, 0, 1)
	ui.ToastTarget = math.min(1, (w - 24) / 350)
	ui.ToastScale.Scale = ui.ToastTarget
	place(ui.Toast, nil, w / 2, math.max(100, h * 0.3), 0.5, 0)
	ui.CountTarget = math.min(1, (w - 24) / 320, (h - 20) / 234)
	ui.CountScale.Scale = ui.CountTarget
	-- Reflow results instead of shrinking its touch targets.
	ui.WinnerTarget, ui.WinnerScale.Scale = 1, 1
	local resultWidth, resultHeight = math.min(540, w - 24), math.min(326, h - 24)
	ui.Winner.Size = UDim2.fromOffset(resultWidth, resultHeight)
	local winnerFace = ui.WinnerName.Parent
	winnerFace.Caption.Size = UDim2.new(1, -94, 0, 17)
	winnerFace.Close.Position = UDim2.new(1, -60, 0, 13)
	ui.WinnerTitle.Visible = resultHeight >= 300
	ui.WinnerTitle.Position, ui.WinnerTitle.Size = UDim2.fromOffset(24, 65), UDim2.new(1, -48, 0, 28)
	ui.WinnerName.Position = UDim2.fromOffset(24, resultHeight < 300 and 64 or 106)
	ui.WinnerName.Size = UDim2.new(1, -48, 0, resultHeight < 300 and 54 or 72)
	ui.WinnerDetail.Position = UDim2.fromOffset(24, resultHeight < 300 and 126 or 191)
	ui.WinnerDetail.Size = UDim2.new(1, -48, 0, 19)
	winnerFace.Rule.Position, winnerFace.Rule.Size = UDim2.fromOffset(24, resultHeight - 91), UDim2.new(1, -48, 0, 1)
	ui.WinnerFooter.Position, ui.WinnerFooter.Size = UDim2.fromOffset(24, resultHeight - 83), UDim2.new(1, -48, 0, 18)
	winnerFace.Continue.Position, winnerFace.Continue.Size = UDim2.fromOffset(24, resultHeight - 58), UDim2.new(1, -48, 0, 44)
	local modalWidth = math.min(600, w - 24)
	ui.Modal.Size = UDim2.fromOffset(modalWidth, math.min(420, h - 24))
	ui.CloseButton.Position = UDim2.new(1, -64, 0, 18)
	ui.ModalTitle.Size = UDim2.new(1, -104, 0, 39)
	ui.ModalTitle.Parent.Badge.Size = UDim2.new(1, -102, 0, 16)
	ui.ModalTitle.Parent.Separator.Size = UDim2.new(1, -48, 0, 1)
end

closeModal = function()
	activeMenu = nil
	if ui.ModalShade then ui.ModalShade.Visible = false end
	local selected = GuiService.SelectedObject
	if selected and ui.Modal and selected:IsDescendantOf(ui.Modal) then GuiService.SelectedObject = nil end
	if refresh then refresh() end
end
showModal = function(page)
	if player:GetAttribute("InRound") == true or ui.Results.Visible then return end
	local wasOpen = activeMenu == page
	activeMenu = page
	ui.ModalTitle.Text, ui.ModalShade.Visible = page, true
	ui.MapPreview.Visible, ui.ModalAction.Visible = page == "MAPS", page == "SETTINGS"
	if not wasOpen then ui.ModalBody.CanvasPosition = Vector2.zero end
	if page == "CONTROLS" then
		ui.ModalInfo.Text = "MOVE   /   W A S D\n\nSPRINT   /   LEFT SHIFT\n\nDIRECTIONAL DODGE   /   MOVE + SPACE\n\nPASS THE BOMB   /   Get close to another player."
	elseif page == "HOW TO PLAY" then
		ui.ModalInfo.Text = "01   KEEP MOVING\nAvoid the carrier. If the bomb is yours, get close to another player to pass it.\n\n02   WATCH THE FUSE\nPassing the bomb does not reset its timer.\n\n03   TIME YOUR ESCAPE\nA directional dodge gives brief immunity. Be the last player standing."
	elseif page == "STATS" then
		ui.ModalInfo.Text = "WINS     " .. formatStat(stat("Wins")) .. "\n\nCOINS     " .. formatStat(stat("Coins"))
			.. "\n\nGAMES PLAYED     " .. formatStat(stat("GamesPlayed"))
	elseif page == "SETTINGS" then
		ui.ModalInfo.Text = "HUD MOTION\n\n" .. (reduced and "Reduced. Panels and notifications appear without animation." or "Full. Subtle transitions for panels and notifications.")
		ui.ModalAction.Text = reduced and "ENABLE ANIMATIONS" or "REDUCE ANIMATIONS"
	elseif page == "MAPS" then
		ui.ModalInfo.Text = "Know your arena. Use its space to break away from the carrier."
		ui.MapTitle.Text = tostring(workspace:GetAttribute("CurrentVotedMap") or GameConfig.MapName or "Sky Garden"):upper()
	end
	if gamepad() then GuiService.SelectedObject = ui.CloseButton end
	refresh()
end

local function stopCountdown()
	countToken += 1
	lastCount = nil
	ui.Countdown.Visible = false
end
local function countdown(value)
	if lastCount == value then return end
	countToken += 1
	lastCount = value
	ui.Countdown.Visible = true
	ui.CountText.Text = tostring(value)
	ui.CountText.TextColor3 = value == "GO!" and C.green or (value == 1 and C.red or C.white)
	ui.CountSub.Text = value == "GO!" and "RUN. PASS. SURVIVE." or "GET READY TO RUN"
	local target = ui.CountTarget or 1
	ui.CountScale.Scale = reduced and target or target * 0.9
	animate(ui.CountScale, 0.22, {Scale = target})
	if value == "GO!" then
		local token, session = countToken, life
		task.delay(0.7, function()
			if started and session == life and token == countToken then stopCountdown() end
		end)
	end
end
local function onRoundState(data)
	if typeof(data) ~= "table" or typeof(data.State) ~= "string" then return end
	local previous = phase
	phase, phaseDuration, phaseAt = data.State, number(data.TimeLeft), time()
	alive = (phase == "ROUND" or phase == "FINAL_DUEL") and number(data.Alive, phase == "FINAL_DUEL" and 2 or alive) or nil
	if phase == "STARTING" then
		local n = number(data.TimeLeft)
		if n and n >= 1 and n <= 3 then countdown(math.ceil(n)) end
	elseif phase == "ROUND" or phase == "FINAL_DUEL" or phase == "PRACTICE" then
		if lastCount and lastCount ~= "GO!" then countdown("GO!") end
	else
		stopCountdown()
	end
	if phase ~= "RESULT" then ui.Results.Visible = false end
	if phase == "RESULT" and previous ~= "RESULT" then
		closeModal()
		ui.Toast.Visible, ui.Results.Visible = false, true
		local winner = tostring(data.Winner or "")
		ui.WinnerName.Text = winner ~= "" and winner or "GOOD GAME!"
		ui.WinnerTitle.Text = winner ~= "" and "WINNER" or "ROUND COMPLETE"
		ui.WinnerDetail.Text = winner ~= "" and "LAST PLAYER STANDING" or "ANOTHER ROUND. ANOTHER CHANCE."
		local target = ui.WinnerTarget or 1
		ui.WinnerScale.Scale = reduced and target or target * 0.94
		animate(ui.WinnerScale, 0.25, {Scale = target})
	end
	if phase == "WAITING" or phase == "INTERMISSION" or phase == "RESULT" then bombActive = false end
	refresh()
end
local function onBombState(data)
	if typeof(data) ~= "table" then return end
	if data.Event == "Exploded" then
		bombActive = false
		toastToken += 1
		local token, session = toastToken, life
		ui.ToastText.Text = tostring(data.CarrierName or "PLAYER") .. " EXPLODED"
		ui.Toast.Visible = phase ~= "RESULT"
		local target = ui.ToastTarget or 1
		ui.ToastScale.Scale = reduced and target or target * 0.94
		animate(ui.ToastScale, 0.18, {Scale = target})
		task.delay(1.7, function()
			if started and session == life and token == toastToken then ui.Toast.Visible = false end
		end)
	else
		bombActive, bombOwner = data.Active == true, number(data.CarrierUserId, 0)
		bombName, bombEnd = tostring(data.CarrierName or ""), number(data.EndTime, 0)
		if bombActive then toastToken += 1; ui.Toast.Visible = false end
	end
	refresh()
end
local function bindCharacter(newCharacter)
	disconnect(characterConnections)
	character, humanoid, lastDodge = newCharacter, nil, -math.huge
	if not newCharacter then return end
	humanoid = newCharacter:FindFirstChildOfClass("Humanoid")
	connect(newCharacter.ChildAdded, function(child)
		if character == newCharacter and child:IsA("Humanoid") then humanoid = child end
	end, characterConnections)
	local lastAction = newCharacter:GetAttribute("MovementActionId")
	connect(newCharacter:GetAttributeChangedSignal("MovementActionId"), function()
		local id = newCharacter:GetAttribute("MovementActionId")
		if id == lastAction then return end
		lastAction = id
		local actionName = tostring(newCharacter:GetAttribute("MovementAction") or "")
		if actionName:sub(1, 4) == "Dive" and actionName ~= "DiveEnd" and actionName ~= "DiveRecover" then lastDodge = time() end
	end, characterConnections)
end

refresh = function()
	if not ui.Gui then return end
	local now, serverNow = time(), workspace:GetServerTimeNow()
	local inRound = player:GetAttribute("InRound") == true
	if inRound and activeMenu then activeMenu = nil; ui.ModalShade.Visible = false; GuiService.SelectedObject = nil end
	local blocked = activeMenu ~= nil or ui.Results.Visible
	set(ui.Menu, "Visible", not inRound and not blocked and not ui.Countdown.Visible)
	set(ui.Currency, "Visible", not inRound and not blocked)
	set(ui.Health, "Visible", inRound and humanoid ~= nil and not blocked and phase ~= "RESULT")
	set(ui.Dash, "Visible", inRound and not blocked and phase ~= "RESULT")
	local live = phase == "ROUND" or phase == "FINAL_DUEL" or phase == "PRACTICE"
	set(ui.Bomb, "Visible", bombActive and live and not blocked)
	set(ui.Immune, "Visible", ui.Dash.Visible and character ~= nil and serverNow < number(character:GetAttribute("BombTagIFrameUntil"), 0))
	if humanoid then
		local maximum, health = math.max(1, humanoid.MaxHealth), math.max(0, humanoid.Health)
		set(ui.HealthText, "Text", string.format("%d / %d", math.ceil(health), math.ceil(maximum)))
		set(ui.HealthFill, "Size", UDim2.fromScale(math.clamp(health / maximum, 0, 1), 1))
		set(ui.HealthFill, "BackgroundColor3", health / maximum <= 0.3 and C.red or C.green)
	end
	local cooldown = math.max(0, COOLDOWN - (now - lastDodge))
	set(ui.DashHint, "Text", keyboard() and "WASD + SPACE" or "DODGE COOLDOWN")
	set(ui.DashStatus, "Text", cooldown <= 0 and "READY" or string.format("%.1fs", cooldown))
	set(ui.DashStatus, "TextColor3", cooldown <= 0 and C.green or C.gold)
	set(ui.DashFill, "BackgroundColor3", cooldown <= 0 and C.green or C.gold)
	set(ui.DashFill, "Size", UDim2.fromScale(math.clamp(1 - cooldown / COOLDOWN, 0, 1), 1))
	set(ui.TopTitle, "Text", PHASES[phase] or "BOMB TAG")
	local seconds = phaseDuration and math.max(0, math.ceil(phaseDuration - (now - phaseAt)))
	local detail = "PASS IT ON. STAY ALIVE."
	if phase == "FINAL_DUEL" or (phase == "ROUND" and alive == 2) then detail = "LAST TWO PLAYERS"
	elseif phase == "RESULT" then detail = "MATCH FINISHED"
	elseif seconds and (phase == "STARTING" or phase == "INTERMISSION" or phase == "PRACTICE") then detail = tostring(seconds) .. "s REMAINING" end
	set(ui.TopDetail, "Text", detail)
	set(ui.TopIndicator, "BackgroundColor3", phase == "FINAL_DUEL" and C.red or (phase == "STARTING" and C.gold or C.green))
	set(ui.AliveCount, "Text", tostring(alive or #Players:GetPlayers()))
	set(ui.AliveText, "Text", alive and "ALIVE" or "PLAYERS")
	set(ui.WinnerFooter, "Text", seconds and ("NEXT MATCH  /  " .. seconds .. "s") or "NEXT MATCH COMING UP")
	if bombActive then
		local remaining, yours = math.max(0, bombEnd - serverNow), bombOwner == player.UserId
		local duel = phase == "FINAL_DUEL" or (phase == "ROUND" and alive and alive <= 2)
		local fuse = math.max(0.1, number(duel and GameConfig.FinalDuelBombFuseSeconds or GameConfig.NormalBombFuseSeconds, duel and 9 or 14))
		local danger = remaining <= 3
		set(ui.BombTitle, "Text", yours and "YOU HAVE THE BOMB" or "BOMB ACTIVE")
		set(ui.BombTitle, "TextColor3", yours and C.red or C.gold)
		set(ui.BombRim, "Color", (yours or danger) and C.red or C.line)
		set(ui.BombTime, "Text", string.format("%.1f", remaining))
		set(ui.BombTime, "TextColor3", danger and C.red or C.white)
		set(ui.BombOwner, "Text", yours and "GET CLOSE. PASS IT ON." or bombName)
		set(ui.BombFill, "BackgroundColor3", danger and C.red or C.gold)
		set(ui.BombFill, "Size", UDim2.fromScale(math.clamp(remaining / fuse, 0, 1), 1))
	end
end
local function refreshStats()
	local coins, gems = stat("Coins"), stat("Gems")
	ui.CoinsCard.Visible, ui.GemsCard.Visible = coins ~= nil, gems ~= nil
	ui.Coins.Text, ui.Gems.Text = formatStat(coins), formatStat(gems)
	ui.GemsCard.Position = UDim2.fromOffset(coins ~= nil and 124 or 0, 0)
	if activeMenu == "STATS" then showModal("STATS") end
end

function HudController.Init()
	if started then return end
	started, life = true, life + 1
	phase, phaseDuration, phaseAt, alive = "WAITING", nil, time(), nil
	bombActive, bombOwner, bombName, bombEnd = false, 0, "", 0
	lastSize, lastRound, elapsed, statsElapsed = Vector2.zero, nil, 0, 0
	inputType = UserInputService:GetLastInputType()
	buildUI()
	connect(Remotes.Get("RoundState").OnClientEvent, onRoundState)
	connect(Remotes.Get("BombState").OnClientEvent, onBombState)
	connect(player.CharacterAdded, bindCharacter)
	connect(player.CharacterRemoving, function(old) if character == old then bindCharacter(nil) end end)
	bindCharacter(player.Character)
	-- The supplied place also creates a separate health-only ScreenGui.
	local pg = player:WaitForChild("PlayerGui")
	local function hideLegacyHealth(child)
		if child.Name == "PixelHealthGui" and child:IsA("ScreenGui") then
			hiddenHealth[child] = child.Enabled
			child.Enabled = false
		end
	end
	connect(pg.ChildAdded, hideLegacyHealth)
	for _, child in ipairs(pg:GetChildren()) do hideLegacyHealth(child) end
	connect(UserInputService.LastInputTypeChanged, function(kind) inputType = kind; refresh() end)
	connect(UserInputService.InputBegan, function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if activeMenu then closeModal()
			elseif ui.Results.Visible then ui.Results.Visible = false; refresh() end
		end
	end)
	layout()
	refreshStats()
	refresh()
	connect(RunService.RenderStepped, function(dt)
		elapsed += dt
		statsElapsed += dt
		local inRound = player:GetAttribute("InRound") == true
		if ui.Root.AbsoluteSize ~= lastSize or inRound ~= lastRound then lastRound = inRound; layout() end
		if elapsed >= 1 / 30 then elapsed = 0; refresh() end
		if statsElapsed >= 0.5 then statsElapsed = 0; refreshStats() end
	end)
end

function HudController.Destroy()
	if not started then return end
	started, life = false, life + 1
	disconnect(connections)
	disconnect(characterConnections)
	for _, tween in pairs(tweens) do tween:Cancel() end
	table.clear(tweens)
	for gui, enabled in pairs(hiddenHealth) do if gui.Parent then gui.Enabled = enabled end end
	table.clear(hiddenHealth)
	if ui.Gui then
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(ui.Gui) then GuiService.SelectedObject = nil end
		ui.Gui:Destroy()
	end
	ui, character, humanoid, activeMenu, lastCount = {}, nil, nil, nil, nil
end

return HudController