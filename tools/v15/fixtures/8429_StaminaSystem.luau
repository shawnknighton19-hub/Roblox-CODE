--[[
    Pixel-Art Stamina Meter UI + Sprint Gatekeeper
    Place in: StarterPlayerScripts as a LocalScript
    
    IMPORTANT:
    This script does NOT control WalkSpeed. Your crouch/movement script
    already owns WalkSpeed. This script only:
      1. Tracks stamina (drains when sprinting, regens when not)
      2. Displays the UI
      3. Sets HRP attribute "CanSprint" (true/false)
      4. Forces sprint to stop when stamina hits 0
    
    Your crouch script must read "CanSprint" in startSprint() — see Step 2.
--]]

local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local TweenService         = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

------------------------------------------------------------
-- CLEANUP
------------------------------------------------------------
local existing = playerGui:FindFirstChild("PixelStaminaGui")
if existing then existing:Destroy() end

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local CONFIG = {
	-- Stamina
	MaxStamina       = 100,
	DrainRate        = 22,
	RegenRate        = 14,
	RegenDelay       = 1.2,
	MinStaminaSprint = 15,

	-- Detection threshold — matches your crouch script's SprintSpeed
	SprintSpeedThreshold = 20,

	-- UI
	SegmentCount = 10,
	BarWidth     = 220,
	BarHeight    = 22,
	SegmentGap   = 3,

	-- Colors
	ColorFull      = Color3.fromRGB(80, 200, 120),
	ColorMid       = Color3.fromRGB(200, 220, 60),
	ColorLow       = Color3.fromRGB(220, 100, 40),
	ColorEmpty     = Color3.fromRGB(25, 25, 25),
	ColorExhausted = Color3.fromRGB(180, 60, 60),
}

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local stamina     = CONFIG.MaxStamina
local exhausted   = false
local regenTimer  = 0

------------------------------------------------------------
-- SCREEN GUI
------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "PixelStaminaGui"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.Parent         = playerGui

local basePosition = UDim2.new(0, 170, 1, -90)

local container = Instance.new("Frame")
container.Name                 = "StaminaContainer"
container.Size                 = UDim2.new(0, 40 + CONFIG.BarWidth + 70, 0, CONFIG.BarHeight + 10)
container.Position             = basePosition
container.AnchorPoint          = Vector2.new(0.5, 0.5)
container.BackgroundTransparency = 1
container.Parent               = screenGui

------------------------------------------------------------
-- SHADOW
------------------------------------------------------------
local SHADOW_OFFSET = 4

local barShadow = Instance.new("Frame")
barShadow.Size                   = UDim2.new(0, CONFIG.BarWidth, 0, CONFIG.BarHeight)
barShadow.Position               = UDim2.new(0, 40 + SHADOW_OFFSET, 0.5, SHADOW_OFFSET)
barShadow.AnchorPoint            = Vector2.new(0, 0.5)
barShadow.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
barShadow.BackgroundTransparency = 0.55
barShadow.BorderSizePixel        = 0
barShadow.ZIndex                 = 1
barShadow.Parent                 = container

local barShadowCorner = Instance.new("UICorner")
barShadowCorner.CornerRadius = UDim.new(0, 3)
barShadowCorner.Parent = barShadow

------------------------------------------------------------
-- BOLT ICON
------------------------------------------------------------
local boltMatrix = {
	{0,0,1,1,1,0},
	{0,1,1,1,0,0},
	{1,1,1,1,1,0},
	{0,0,1,1,0,0},
	{0,1,1,0,0,0},
	{1,1,0,0,0,0},
}
local pixelSize = 4

local boltShadowHolder = Instance.new("Frame")
boltShadowHolder.Size                   = UDim2.new(0, 28, 0, 28)
boltShadowHolder.Position               = UDim2.new(0, 4 + SHADOW_OFFSET, 0.5, SHADOW_OFFSET)
boltShadowHolder.AnchorPoint            = Vector2.new(0, 0.5)
boltShadowHolder.BackgroundTransparency = 1
boltShadowHolder.ZIndex                 = 1
boltShadowHolder.Parent                 = container

for row = 1, #boltMatrix do
	for col = 1, #boltMatrix[row] do
		if boltMatrix[row][col] == 1 then
			local px = Instance.new("Frame")
			px.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
			px.BackgroundTransparency = 0.55
			px.BorderSizePixel        = 0
			px.ZIndex                 = 1
			px.Size                   = UDim2.new(0, pixelSize, 0, pixelSize)
			px.Position               = UDim2.new(0, (col-1)*pixelSize, 0, (row-1)*pixelSize)
			px.Parent                 = boltShadowHolder
		end
	end
end

local boltHolder = Instance.new("Frame")
boltHolder.Size                   = UDim2.new(0, 28, 0, 28)
boltHolder.Position               = UDim2.new(0, 4, 0.5, 0)
boltHolder.AnchorPoint            = Vector2.new(0, 0.5)
boltHolder.BackgroundTransparency = 1
boltHolder.ZIndex                 = 3
boltHolder.Parent                 = container

local boltCells = {}
for row = 1, #boltMatrix do
	for col = 1, #boltMatrix[row] do
		if boltMatrix[row][col] == 1 then
			local px = Instance.new("Frame")
			px.BackgroundColor3 = CONFIG.ColorFull
			px.BorderSizePixel  = 0
			px.ZIndex           = 3
			px.Size             = UDim2.new(0, pixelSize, 0, pixelSize)
			px.Position         = UDim2.new(0, (col-1)*pixelSize, 0, (row-1)*pixelSize)
			px.Parent           = boltHolder
			table.insert(boltCells, px)
		end
	end
end

------------------------------------------------------------
-- BAR
------------------------------------------------------------
local barOuter = Instance.new("Frame")
barOuter.Size             = UDim2.new(0, CONFIG.BarWidth, 0, CONFIG.BarHeight)
barOuter.Position         = UDim2.new(0, 40, 0.5, 0)
barOuter.AnchorPoint      = Vector2.new(0, 0.5)
barOuter.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
barOuter.BorderSizePixel  = 0
barOuter.ZIndex           = 2
barOuter.Parent           = container

local barStroke = Instance.new("UIStroke")
barStroke.Color     = Color3.fromRGB(255, 255, 255)
barStroke.Thickness = 2
barStroke.Parent    = barOuter

local segLayout = Instance.new("UIListLayout")
segLayout.FillDirection       = Enum.FillDirection.Horizontal
segLayout.Padding             = UDim.new(0, CONFIG.SegmentGap)
segLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
segLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
segLayout.SortOrder           = Enum.SortOrder.LayoutOrder
segLayout.Parent              = barOuter

local segPadding = Instance.new("UIPadding")
segPadding.PaddingLeft   = UDim.new(0, 4)
segPadding.PaddingRight  = UDim.new(0, 4)
segPadding.PaddingTop    = UDim.new(0, 4)
segPadding.PaddingBottom = UDim.new(0, 4)
segPadding.Parent        = barOuter

local segments = {}
local segWidth = (CONFIG.BarWidth - 8 - (CONFIG.SegmentGap * (CONFIG.SegmentCount - 1))) / CONFIG.SegmentCount

for i = 1, CONFIG.SegmentCount do
	local seg = Instance.new("Frame")
	seg.Name             = "StamSeg" .. i
	seg.Size             = UDim2.new(0, segWidth, 1, 0)
	seg.BackgroundColor3 = CONFIG.ColorFull
	seg.BorderSizePixel  = 0
	seg.ZIndex           = 4
	seg.LayoutOrder      = i
	seg.Parent           = barOuter

	local segCorner = Instance.new("UICorner")
	segCorner.CornerRadius = UDim.new(0, 2)
	segCorner.Parent = seg

	segments[i] = seg
end

------------------------------------------------------------
-- PERCENT TEXT
------------------------------------------------------------
local percentShadow = Instance.new("TextLabel")
percentShadow.Size                   = UDim2.new(0, 60, 1, 0)
percentShadow.Position               = UDim2.new(0, 40 + CONFIG.BarWidth + 10 + SHADOW_OFFSET, 0.5, SHADOW_OFFSET)
percentShadow.AnchorPoint            = Vector2.new(0, 0.5)
percentShadow.BackgroundTransparency = 1
percentShadow.Font                   = Enum.Font.Code
percentShadow.TextSize               = 18
percentShadow.TextColor3             = Color3.fromRGB(0, 0, 0)
percentShadow.TextTransparency       = 0.45
percentShadow.TextXAlignment         = Enum.TextXAlignment.Left
percentShadow.Text                   = "100%"
percentShadow.ZIndex                 = 1
percentShadow.Parent                 = container

local percentLabel = Instance.new("TextLabel")
percentLabel.Size                   = UDim2.new(0, 60, 1, 0)
percentLabel.Position               = UDim2.new(0, 40 + CONFIG.BarWidth + 10, 0.5, 0)
percentLabel.AnchorPoint            = Vector2.new(0, 0.5)
percentLabel.BackgroundTransparency = 1
percentLabel.Font                   = Enum.Font.Code
percentLabel.TextSize               = 18
percentLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
percentLabel.TextXAlignment         = Enum.TextXAlignment.Left
percentLabel.Text                   = "100%"
percentLabel.ZIndex                 = 3
percentLabel.Parent                 = container

------------------------------------------------------------
-- EXHAUSTED FLASH (stroke-based, no overlay)
------------------------------------------------------------
local exhaustFlashActive = false

local function flashExhausted()
	if exhaustFlashActive then return end
	exhaustFlashActive = true

	local originalColor     = barStroke.Color
	local originalThickness = barStroke.Thickness

	barStroke.Color     = Color3.fromRGB(255, 120, 0)
	barStroke.Thickness = 4

	TweenService:Create(barStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Color     = originalColor,
		Thickness = originalThickness
	}):Play()

	task.delay(0.55, function()
		exhaustFlashActive = false
	end)
end

------------------------------------------------------------
-- UPDATE UI
------------------------------------------------------------
local function updateStaminaUI()
	local pct         = math.clamp(stamina / CONFIG.MaxStamina, 0, 1)
	local filledCount = math.ceil(pct * CONFIG.SegmentCount)

	local segColor
	if exhausted then
		segColor = CONFIG.ColorExhausted
	elseif pct > 0.5 then
		segColor = CONFIG.ColorFull
	elseif pct > 0.25 then
		segColor = CONFIG.ColorMid
	else
		segColor = CONFIG.ColorLow
	end

	local iconColor = exhausted and CONFIG.ColorExhausted
		or (pct > 0.5 and CONFIG.ColorFull
			or (pct > 0.25 and CONFIG.ColorMid
				or CONFIG.ColorLow))

	for _, px in ipairs(boltCells) do
		px.BackgroundColor3 = iconColor
	end

	for i, seg in ipairs(segments) do
		if i <= filledCount and stamina > 0 then
			seg.BackgroundColor3 = segColor
		else
			seg.BackgroundColor3 = CONFIG.ColorEmpty
		end
	end

	local displayPct = math.floor(pct * 100)
	percentLabel.Text  = displayPct .. "%"
	percentShadow.Text = displayPct .. "%"
end

------------------------------------------------------------
-- AUTO-HIDE
------------------------------------------------------------
local barVisible     = true
local autoHideTimer  = 0

local function setBarVisible(visible)
	if barVisible == visible then return end
	barVisible = visible

	local elements = { barOuter, barShadow, percentLabel, percentShadow }
	for _, el in ipairs(elements) do
		TweenService:Create(el, TweenInfo.new(0.4), {
			BackgroundTransparency = visible and (el == barShadow and 0.55 or (el == barOuter and 0 or 1))
		}):Play()
		if el:IsA("TextLabel") then
			local baseTrans = el == percentLabel and 0 or 0.45
			TweenService:Create(el, TweenInfo.new(0.4), {
				TextTransparency = visible and baseTrans or 1
			}):Play()
		end
	end
	for _, seg in ipairs(segments) do
		TweenService:Create(seg, TweenInfo.new(0.4), {
			BackgroundTransparency = visible and 0 or 1
		}):Play()
	end
	for _, px in ipairs(boltCells) do
		TweenService:Create(px, TweenInfo.new(0.4), {
			BackgroundTransparency = visible and 0 or 1
		}):Play()
	end
end

------------------------------------------------------------
-- CHARACTER HELPERS
------------------------------------------------------------
local function getHumanoid()
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

local function getHRP()
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

------------------------------------------------------------
-- MAIN LOOP
-- The KEY change: we DON'T touch WalkSpeed. We just:
--   • Detect if player is currently sprinting (WalkSpeed >= threshold)
--   • Drain stamina if so
--   • When exhausted, set CanSprint = false so crouch script blocks sprint
--   • Regen when not sprinting
------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	local hum = getHumanoid()
	local hrp = getHRP()
	if not hum or not hrp then return end

	-- Detect sprint via WalkSpeed (owned by crouch script)
	local isActuallySprinting = hum.WalkSpeed >= CONFIG.SprintSpeedThreshold

	-- Detect actual movement
	local vel        = hrp.Velocity
	local horizSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local isMoving   = horizSpeed > 1.0

	-- ── DRAIN ────────────────────────────────────────────────
	if isActuallySprinting and isMoving then
		stamina    = math.max(stamina - CONFIG.DrainRate * dt, 0)
		regenTimer = CONFIG.RegenDelay

		if stamina <= 0 then
			exhausted = true
			hrp:SetAttribute("CanSprint", false)
			flashExhausted()
			-- Force crouch script's sprint state to end by simulating
			-- a "moving backwards" condition? No — cleanest way is:
			-- The crouch script checks CanSprint in startSprint(), but
			-- to stop an ACTIVE sprint we need to set another attribute.
			hrp:SetAttribute("ForceStopSprint", true)
		end
	else
		-- ── REGEN ────────────────────────────────────────────
		if regenTimer > 0 then
			regenTimer = math.max(regenTimer - dt, 0)
		else
			if stamina < CONFIG.MaxStamina then
				stamina = math.min(stamina + CONFIG.RegenRate * dt, CONFIG.MaxStamina)
			end
		end

		-- Recover from exhaustion once enough stamina back
		if exhausted and stamina >= CONFIG.MinStaminaSprint then
			exhausted = false
			hrp:SetAttribute("CanSprint", true)
			hrp:SetAttribute("ForceStopSprint", false)
		end
	end

	updateStaminaUI()

	-- Auto-hide when full
	if stamina >= CONFIG.MaxStamina and not isActuallySprinting then
		autoHideTimer = autoHideTimer + dt
		if autoHideTimer >= 3.0 and barVisible then
			setBarVisible(false)
		end
	else
		autoHideTimer = 0
		if not barVisible then
			setBarVisible(true)
		end
	end
end)

------------------------------------------------------------
-- RESPAWN
------------------------------------------------------------
local function onCharacterAdded(char)
	stamina    = CONFIG.MaxStamina
	exhausted  = false
	regenTimer = 0

	local hrp = char:WaitForChild("HumanoidRootPart")
	hrp:SetAttribute("CanSprint", true)
	hrp:SetAttribute("ForceStopSprint", false)

	updateStaminaUI()
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)