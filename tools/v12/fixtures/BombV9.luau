--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared =
	ReplicatedStorage:WaitForChild("Shared")

local GameConfig =
	require(Shared.Config.GameConfig)

local Remotes =
	require(Shared.Net.Remotes)

-- HussEconomyHooksV9
local Economy=require(script.Parent:WaitForChild('EconomyServiceV9'))
local BombService = {}

local bombRemote = nil

local activeBombPart = nil
local activeHighlight = nil

------------------------------------------------------------
-- PLAYER HELPERS
------------------------------------------------------------

local function getHumanoid(player)

	local character = player.Character

	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function getRoot(player)

	local character = player.Character

	if not character then
		return nil
	end

	local root =
		character:FindFirstChild("HumanoidRootPart")

	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function isAlive(player)

	if not player then
		return false
	end

	if not player.Parent then
		return false
	end

	if player:GetAttribute("InRound") ~= true then
		return false
	end

	local humanoid = getHumanoid(player)

	if not humanoid then
		return false
	end

	return humanoid.Health > 0
end

------------------------------------------------------------
-- DODGE I-FRAMES
------------------------------------------------------------

local function hasDodgeIFrames(player)

	if not player then
		return false
	end

	local character = player.Character

	if not character then
		return false
	end

	local immuneUntil =
		character:GetAttribute("BombTagIFrameUntil")
		or 0

	return workspace:GetServerTimeNow()
		< immuneUntil
end

------------------------------------------------------------
-- BOMB VISUAL
------------------------------------------------------------

local function clearBombVisual()

	if activeBombPart then
		activeBombPart:Destroy()
		activeBombPart = nil
	end

	if activeHighlight then
		activeHighlight:Destroy()
		activeHighlight = nil
	end
end

local function attachBombVisual(player)

	clearBombVisual()

	local character = player.Character

	if not character then
		return
	end

	local torso =
		character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("HumanoidRootPart")

	if not torso or not torso:IsA("BasePart") then
		return
	end

	--------------------------------------------------------
	-- BOMB
	--------------------------------------------------------

	local bomb = Instance.new("Part")

	bomb.Name = "ActiveBomb"

	bomb.Shape = Enum.PartType.Ball

	bomb.Size =
		Vector3.new(2.25, 2.25, 2.25)

	bomb.Color =
		Color3.fromRGB(32, 32, 38)

	bomb.Material =
		Enum.Material.Metal

	bomb.CanCollide = false
	bomb.CanTouch = false
	bomb.CanQuery = false

	bomb.Massless = true
	bomb.Anchored = false

	bomb.CFrame =
		torso.CFrame
		* CFrame.new(0, 1.2, 1.15)

	bomb.Parent = character

	local weld =
		Instance.new("WeldConstraint")

	weld.Part0 = torso
	weld.Part1 = bomb
	weld.Parent = bomb

	--------------------------------------------------------
	-- RED LIGHT
	--------------------------------------------------------

	local light =
		Instance.new("PointLight")

	light.Color =
		Color3.fromRGB(255, 60, 60)

	light.Brightness = 4
	light.Range = 13

	light.Parent = bomb

	--------------------------------------------------------
	-- BILLBOARD
	--------------------------------------------------------

	local billboard =
		Instance.new("BillboardGui")

	billboard.Name = "BombBillboard"

	billboard.Size =
		UDim2.fromOffset(160, 48)

	billboard.StudsOffset =
		Vector3.new(0, 2.6, 0)

	billboard.AlwaysOnTop = true
	billboard.Adornee = bomb

	billboard.Parent = bomb

	local label =
		Instance.new("TextLabel")

	label.Size =
		UDim2.fromScale(1, 1)

	label.BackgroundTransparency = 1

	label.Font =
		Enum.Font.GothamBlack

	label.Text = "💣 BOMB"

	label.TextColor3 =
		Color3.fromRGB(255, 80, 80)

	label.TextStrokeTransparency = 0.1
	label.TextScaled = true

	label.Parent = billboard

	--------------------------------------------------------
	-- CARRIER HIGHLIGHT
	--------------------------------------------------------

	local highlight =
		Instance.new("Highlight")

	highlight.Name =
		"BombCarrierHighlight"

	highlight.FillColor =
		Color3.fromRGB(255, 55, 55)

	highlight.FillTransparency = 0.72

	highlight.OutlineColor =
		Color3.fromRGB(255, 80, 80)

	highlight.OutlineTransparency = 0

	highlight.Parent = character

	activeBombPart = bomb
	activeHighlight = highlight
end

------------------------------------------------------------
-- NETWORK
------------------------------------------------------------

local function sendBombState(
	active,
	carrier,
	endTime,
	eventName
)

	bombRemote:FireAllClients({
		Active = active,

		CarrierUserId =
			carrier and carrier.UserId or 0,

		CarrierName =
			carrier and carrier.DisplayName or "",

		EndTime = endTime or 0,

		Event = eventName or "",
	})
end

local function setCarrier(
	player,
	endTime,
	eventName
)

	attachBombVisual(player)

	sendBombState(
		true,
		player,
		endTime,
		eventName
	)
end

------------------------------------------------------------
-- HIGH SPEED TAG DETECTION
------------------------------------------------------------

-- At high movement speeds, players can cross each other's
-- positions between server checks.
--
-- Instead of only asking:
-- "Are they close RIGHT NOW?"
--
-- this calculates the minimum distance during the short
-- movement segment between the previous check and this check.

local function segmentMinimumDistance(
	previousCarrier,
	currentCarrier,
	previousTarget,
	currentTarget
)

	local relativeStart =
		previousTarget - previousCarrier

	local relativeEnd =
		currentTarget - currentCarrier

	local delta =
		relativeEnd - relativeStart

	local denominator =
		delta:Dot(delta)

	if denominator <= 0.00001 then
		return relativeStart.Magnitude
	end

	local t =
		-math.clamp(
			relativeStart:Dot(delta) / denominator,
			-1,
			0
		)

	-- Correctly clamp between 0 and 1.
	t = math.clamp(
		-relativeStart:Dot(delta) / denominator,
		0,
		1
	)

	local closest =
		relativeStart + delta * t

	return closest.Magnitude
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------

function BombService.Init()

	bombRemote =
		Remotes.Get("BombState")

	if GameConfig.DebugPrints then
		print("[BombService] Initialized")
	end
end

------------------------------------------------------------
-- STOP
------------------------------------------------------------

function BombService.Stop()

	clearBombVisual()

	sendBombState(
		false,
		nil,
		0,
		"Stopped"
	)
end

------------------------------------------------------------
-- BOMB CYCLE
------------------------------------------------------------

function BombService.RunBombCycle(
	aliveProvider,
	fuseSeconds
)

	local alivePlayers =
		aliveProvider()

	if #alivePlayers <= 1 then
		return nil
	end

	--------------------------------------------------------
	-- CHOOSE CARRIER
	--------------------------------------------------------

	local carrier =
		alivePlayers[
	math.random(1, #alivePlayers)
	]

	local endTime =
		workspace:GetServerTimeNow()
		+ fuseSeconds

	local protectedUserId = nil
	local protectedUntil = 0

	local carrierLockedUntil =
		workspace:GetServerTimeNow()
		+ GameConfig.NewCarrierLockSeconds

	--------------------------------------------------------
	-- POSITION HISTORY
	--------------------------------------------------------

	local previousPositions = {}

	for _, player in ipairs(alivePlayers) do

		local root = getRoot(player)

		if root then
			previousPositions[player.UserId] =
				root.Position
		end
	end

	--------------------------------------------------------
	-- START
	--------------------------------------------------------

	setCarrier(
		carrier,
		endTime,
		"Started"
	)

	--------------------------------------------------------
	-- LOOP
	--------------------------------------------------------

	while workspace:GetServerTimeNow() < endTime do

		local now =
			workspace:GetServerTimeNow()

		alivePlayers =
			aliveProvider()

		if #alivePlayers <= 1 then

			BombService.Stop()

			return nil
		end

		----------------------------------------------------
		-- CARRIER DIED / LEFT
		----------------------------------------------------

		if not isAlive(carrier) then

			carrier =
				alivePlayers[
			math.random(
				1,
				#alivePlayers
			)
			]

			carrierLockedUntil =
				now
				+ GameConfig.NewCarrierLockSeconds

			setCarrier(
				carrier,
				endTime,
				"Reassigned"
			)
		end

		----------------------------------------------------
		-- TAGGING
		----------------------------------------------------

		if now >= carrierLockedUntil
			and isAlive(carrier) then

			local carrierRoot =
				getRoot(carrier)

			if carrierRoot then

				local carrierCurrent =
					carrierRoot.Position

				local carrierPrevious =
					previousPositions[
				carrier.UserId
				]
					or carrierCurrent

				for _, candidate in ipairs(alivePlayers) do

					if candidate == carrier then
						continue
					end

					if not isAlive(candidate) then
						continue
					end

					------------------------------------------------
					-- DODGE I-FRAMES
					--
					-- During the short server-authoritative dodge
					-- window, this player cannot RECEIVE the bomb.
					--
					-- This happens before both the direct-distance
					-- and swept-distance checks.
					------------------------------------------------

					if hasDodgeIFrames(candidate) then
						continue
					end

					------------------------------------------------
					-- ANTI-TAGBACK
					------------------------------------------------

					local tagBackProtected =
						candidate.UserId
						== protectedUserId
						and now
						< protectedUntil

					if tagBackProtected then
						continue
					end

					local candidateRoot =
						getRoot(candidate)

					if not candidateRoot then
						continue
					end

					local candidateCurrent =
						candidateRoot.Position

					local candidatePrevious =
						previousPositions[
					candidate.UserId
					]
						or candidateCurrent

					------------------------------------------------
					-- DIRECT DISTANCE
					------------------------------------------------

					local directDistance =
						(
							candidateCurrent
							- carrierCurrent
						).Magnitude

					------------------------------------------------
					-- SWEPT DISTANCE
					------------------------------------------------

					local sweptDistance =
						segmentMinimumDistance(
							carrierPrevious,
							carrierCurrent,
							candidatePrevious,
							candidateCurrent
						)

					------------------------------------------------
					-- BEST DISTANCE
					------------------------------------------------

					local distance =
						math.min(
							directDistance,
							sweptDistance
						)

					------------------------------------------------
					-- TRANSFER
					------------------------------------------------

					if distance
						<= GameConfig.BombTagRadius then

						local oldCarrier =
							carrier

						carrier =
							candidate

						------------------------------------------------
						-- OLD CARRIER IS TEMPORARILY SAFE
						------------------------------------------------

						protectedUserId =
							oldCarrier.UserId

						protectedUntil =
							now
							+ GameConfig.AntiTagBackSeconds

						------------------------------------------------
						-- NEW CARRIER SHORT LOCK
						------------------------------------------------

						carrierLockedUntil =
							now
							+ GameConfig.NewCarrierLockSeconds

						setCarrier(
							carrier,
							endTime,
							"Transferred"
						)
						Economy.Pass(oldCarrier,carrier)

						if GameConfig.DebugPrints then

							print(
								"[BombService]",
								oldCarrier.Name,
								"tagged",
								carrier.Name
							)
						end

						break
					end
				end
			end
		end

		----------------------------------------------------
		-- UPDATE POSITION HISTORY
		----------------------------------------------------

		for _, player in ipairs(alivePlayers) do

			local root = getRoot(player)

			if root then
				previousPositions[player.UserId] =
					root.Position
			end
		end

		task.wait(
			GameConfig.TagCheckInterval
		)
	end

	--------------------------------------------------------
	-- EXPLODE
	--------------------------------------------------------

	local victim = carrier

	if victim and isAlive(victim) then

		sendBombState(
			false,
			victim,
			0,
			"Exploded"
		)

		clearBombVisual()

		local humanoid =
			getHumanoid(victim)

		if humanoid then
			humanoid.Health = 0
		end

		if GameConfig.DebugPrints then
			print(
				"[BombService]",
				victim.Name,
				"exploded"
			)
		end

	else

		BombService.Stop()
	end

	return victim
end

return BombService