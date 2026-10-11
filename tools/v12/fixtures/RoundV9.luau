--!nonstrict

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

------------------------------------------------------------
-- DEPENDENCIES
------------------------------------------------------------

local Shared =
	ReplicatedStorage:WaitForChild("Shared")

local GameConfig =
	require(
		Shared.Config.GameConfig
	)

local Remotes =
	require(
		Shared.Net.Remotes
	)

local BombService =
	require(
		script.Parent.BombService
	)

------------------------------------------------------------
-- SERVICE
------------------------------------------------------------

local MapVoteService = require(script.Parent:WaitForChild("BombTagMapVoteServiceV6"))

-- HussEconomyHooksV9
local Economy=require(script.Parent:WaitForChild('EconomyServiceV9'))
local RoundService = {}

local roundRemote = nil
local running = false

------------------------------------------------------------
-- PLAYER HELPERS
------------------------------------------------------------

local function getHumanoid(player)

	local character =
		player.Character

	if not character then
		return nil
	end

	return character:FindFirstChildOfClass(
		"Humanoid"
	)
end

local function getRoot(player)

	local character =
		player.Character

	if not character then
		return nil
	end

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if root
		and root:IsA("BasePart") then

		return root
	end

	return nil
end

------------------------------------------------------------
-- GET ALIVE PLAYERS
------------------------------------------------------------

-- BOMB_TAG_AFK_MATCHMAKING_V1
local function getMatchmakingPlayers()
    local eligible = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player:GetAttribute("BombTagAFK") ~= true then
            table.insert(eligible, player)
        end
    end

    return eligible
end

local function getAlivePlayers()

	local alivePlayers = {}

	for _, player in ipairs(
		Players:GetPlayers()
		) do

		if player:GetAttribute("InRound")
			== true then

			local humanoid =
				getHumanoid(player)

			if humanoid
				and humanoid.Health > 0 then

				table.insert(
					alivePlayers,
					player
				)
			end
		end
	end

	return alivePlayers
end

------------------------------------------------------------
-- LEADERSTATS
------------------------------------------------------------

------------------------------------------------------------
-- LOBBY SPAWN
------------------------------------------------------------

local function getLobbySpawn()

	local lobby =
		workspace:WaitForChild(
			"Lobby"
		)

	local lobbySpawn =
		lobby:WaitForChild(
			"LobbySpawn"
		)

	assert(
		lobbySpawn:IsA("SpawnLocation"),

		"Workspace > Lobby > LobbySpawn MUST be a SpawnLocation"
	)

	return lobbySpawn
end

------------------------------------------------------------
-- CHARACTER DEATH
------------------------------------------------------------

local function hookCharacter(
	player,
	character
)

	local humanoid =
		character:WaitForChild(
			"Humanoid"
		)

	humanoid.Died:Connect(
		function()

			if player:GetAttribute(
				"InRound"
				) == true then

				player:SetAttribute(
					"InRound",
					false
				)
			end
		end
	)
end

------------------------------------------------------------
-- LOAD PLAYER INTO LOBBY
------------------------------------------------------------

local function loadLobbyCharacter(player)

	if not player.Parent then
		return
	end

	player:SetAttribute(
		"InRound",
		false
	)

	player.RespawnLocation =
		getLobbySpawn()

	player:LoadCharacter()
end

------------------------------------------------------------
-- PLAYER SETUP
------------------------------------------------------------

local function setupPlayer(player)


	player:SetAttribute(
		"InRound",
		false
	)

	player.RespawnLocation =
		getLobbySpawn()

	player.CharacterAdded:Connect(
		function(character)

			hookCharacter(
				player,
				character
			)
		end
	)

	task.defer(
		function()

			if player.Parent
				and not player.Character then

				loadLobbyCharacter(
					player
				)
			end
		end
	)
end

------------------------------------------------------------
-- SEND ROUND STATE
------------------------------------------------------------

local function sendRoundState(
	state,
	timeLeft,
	winner
)

	roundRemote:FireAllClients({

		State =
			state,

		TimeLeft =
			timeLeft or 0,

		Alive =
			#getAlivePlayers(),

		Winner =
			winner
			and winner.DisplayName
			or "",
	})
end

------------------------------------------------------------
-- MAP
------------------------------------------------------------

local function getMap()

	local maps =
		workspace:WaitForChild(
			"Maps"
		)

	local map =
		maps:WaitForChild(
			GameConfig.MapName
		)

	assert(
		map:IsA("Model"),

		"Workspace > Maps > "
			.. tostring(GameConfig.MapName)
			.. " MUST be a Model"
	)

	return map
end

------------------------------------------------------------
-- SPAWN PARTS
------------------------------------------------------------

local function getSpawnParts()

	local map =
		getMap()

	local spawnFolder =
		map:WaitForChild(
			"Spawns"
		)

	local spawnParts = {}

	for _, object in ipairs(
		spawnFolder:GetChildren()
		) do

		if object:IsA("BasePart") then

			table.insert(
				spawnParts,
				object
			)
		end
	end

	table.sort(
		spawnParts,

		function(a, b)

			return a.Name
				< b.Name
		end
	)

	assert(
		#spawnParts > 0,

		"Workspace > Maps > "
			.. tostring(GameConfig.MapName)
			.. " > Spawns has NO spawn Parts"
	)

	return spawnParts
end

------------------------------------------------------------
-- PUT CHARACTER FEET ON FLOOR
------------------------------------------------------------

local function groundCharacter(
	character,
	spawnPart
)

	local root =
		character:WaitForChild(
			"HumanoidRootPart"
		)

	--------------------------------------------------------
	-- FIRST PUT CHARACTER ABOVE THE SPAWN LOCATION.
	--
	-- We intentionally place them high for a moment.
	-- They will NOT be left here.
	--------------------------------------------------------

	character:PivotTo(
		CFrame.new(
			spawnPart.Position
				+ Vector3.new(
					0,
					10,
					0
				)
		)
			* CFrame.Angles(
				0,
				math.rad(
					spawnPart.Orientation.Y
				),
				0
			)
	)

	--------------------------------------------------------
	-- RAYCAST DOWNWARD TO FIND THE REAL FLOOR.
	--------------------------------------------------------

	local raycastParameters =
		RaycastParams.new()

	raycastParameters.FilterType =
		Enum.RaycastFilterType.Exclude

	raycastParameters.FilterDescendantsInstances =
		{
			character,
		}

	raycastParameters.IgnoreWater =
		true

	local rayOrigin =
		spawnPart.Position
		+ Vector3.new(
			0,
			25,
			0
		)

	local rayDirection =
		Vector3.new(
			0,
			-60,
			0
		)

	local result =
		workspace:Raycast(
			rayOrigin,
			rayDirection,
			raycastParameters
		)

	--------------------------------------------------------
	-- FALLBACK
	--------------------------------------------------------

	if not result then

		warn(
			"[RoundService] Could not find floor under",
			spawnPart.Name
		)

		character:PivotTo(
			spawnPart.CFrame
				+ Vector3.new(
					0,
					3,
					0
				)
		)

		return
	end

	--------------------------------------------------------
	-- GET CURRENT CHARACTER BOUNDING BOX.
	--------------------------------------------------------

	local boundingCFrame,
		boundingSize =
		character:GetBoundingBox()

	--------------------------------------------------------
	-- FIND BOTTOM OF CHARACTER.
	--------------------------------------------------------

	local currentBottomY =
		boundingCFrame.Position.Y
	- (
		boundingSize.Y
			/ 2
	)

	--------------------------------------------------------
	-- FLOOR SURFACE HEIGHT.
	--------------------------------------------------------

	local desiredBottomY =
		result.Position.Y
		+ 0.05

	--------------------------------------------------------
	-- CALCULATE HOW FAR CHARACTER NEEDS TO MOVE DOWN.
	--------------------------------------------------------

	local verticalAdjustment =
		desiredBottomY
	- currentBottomY

	--------------------------------------------------------
	-- MOVE WHOLE CHARACTER DOWN SO FEET TOUCH FLOOR.
	--------------------------------------------------------

	local currentPivot =
		character:GetPivot()

	character:PivotTo(
		currentPivot
			+ Vector3.new(
				0,
				verticalAdjustment,
				0
			)
	)

	--------------------------------------------------------
	-- CLEAR ALL VELOCITY.
	--------------------------------------------------------

	root.AssemblyLinearVelocity =
		Vector3.zero

	root.AssemblyAngularVelocity =
		Vector3.zero
end

------------------------------------------------------------
-- LOAD ONE PLAYER INTO ARENA
------------------------------------------------------------

local function loadRoundCharacter(
	player,
	spawnPart
)

	if not player.Parent then
		return
	end

	--------------------------------------------------------
	-- TEMPORARILY NOT ACTIVE
	--------------------------------------------------------

	player:SetAttribute(
		"InRound",
		false
	)

	--------------------------------------------------------
	-- FRESH CHARACTER
	--------------------------------------------------------

	player:LoadCharacter()

	local character =
		player.Character
		or player.CharacterAdded:Wait()

	local root =
		character:WaitForChild(
			"HumanoidRootPart"
		)

	local humanoid =
		character:WaitForChild(
			"Humanoid"
		)

	--------------------------------------------------------
	-- FULL HEALTH
	--------------------------------------------------------

	humanoid.Health =
		humanoid.MaxHealth

	--------------------------------------------------------
	-- PUT THE PLAYER ON THE ACTUAL FLOOR.
	--
	-- THIS FIXES THE FLOATING PROBLEM.
	--------------------------------------------------------

	groundCharacter(
		character,
		spawnPart
	)

	--------------------------------------------------------
	-- CLEAR VELOCITY AGAIN AFTER POSITIONING.
	--------------------------------------------------------

	root.AssemblyLinearVelocity =
		Vector3.zero

	root.AssemblyAngularVelocity =
		Vector3.zero

	--------------------------------------------------------
	-- NOW FREEZE THEM.
	--
	-- Because their feet are already sitting on the floor,
	-- they look planted instead of floating.
	--------------------------------------------------------

	root.Anchored =
		true

	--------------------------------------------------------
	-- PLAYER IS ACTIVE IN ROUND
	--------------------------------------------------------

	player:SetAttribute(
		"InRound",
		true
	)
end

------------------------------------------------------------
-- PREPARE PLAYERS
------------------------------------------------------------

local function preparePlayers()

	local players =
		getMatchmakingPlayers()

	local spawnParts =
		getSpawnParts()

	if GameConfig.DebugPrints then

		print(
			"[RoundService] Preparing",
			#players,
			"player(s) for arena"
		)
	end

	for index, player in ipairs(
		players
		) do

		local spawnIndex =
			((index - 1)
				% #spawnParts)
			+ 1

		local spawnPart =
			spawnParts[
		spawnIndex
		]

		loadRoundCharacter(
			player,
			spawnPart
		)
	end

	if GameConfig.DebugPrints then

		print(
			"[RoundService] Players grounded and frozen"
		)
	end
end

------------------------------------------------------------
-- FREEZE PLAYERS
------------------------------------------------------------

local function freezeRoundPlayers()

	for _, player in ipairs(
		getAlivePlayers()
		) do

		local root =
			getRoot(player)

		if root then

			root.AssemblyLinearVelocity =
				Vector3.zero

			root.AssemblyAngularVelocity =
				Vector3.zero

			root.Anchored =
				true
		end
	end

	if GameConfig.DebugPrints then

		print(
			"[RoundService] Movement LOCKED"
		)
	end
end

------------------------------------------------------------
-- RELEASE PLAYERS
------------------------------------------------------------

local function releaseRoundPlayers()

	for _, player in ipairs(
		getAlivePlayers()
		) do

		local root =
			getRoot(player)

		if root then

			root.AssemblyLinearVelocity =
				Vector3.zero

			root.AssemblyAngularVelocity =
				Vector3.zero

			root.Anchored =
				false
		end
	end

	if GameConfig.DebugPrints then

		print(
			"[RoundService] GO! Movement UNLOCKED"
		)
	end
end

------------------------------------------------------------
-- RETURN TO LOBBY
------------------------------------------------------------

local function returnEveryoneToLobby()
	Economy.AbortRound()

	BombService.Stop()

	for _, player in ipairs(
		Players:GetPlayers()
		) do

		player:SetAttribute(
			"InRound",
			false
		)
	end

	for _, player in ipairs(
		Players:GetPlayers()
		) do

		if player.Parent then

			loadLobbyCharacter(
				player
			)
		end
	end
end

------------------------------------------------------------
-- WAIT FOR PLAYER
------------------------------------------------------------

local function waitForAtLeastOnePlayer()

	if GameConfig.DebugPrints then

		print(
			"[RoundService] Waiting until server has at least one player..."
		)
	end

	while running do

		if #getMatchmakingPlayers()
			>= GameConfig.AbsoluteMinimumPlayers then

			if GameConfig.DebugPrints then

				print(
					"[RoundService] Player detected. Starting auto-start timer."
				)
			end

			return true
		end

		task.wait(0.25)
	end

	return false
end

------------------------------------------------------------
-- RANDOM START TIME
------------------------------------------------------------

local function chooseStartSeconds()

	local minimum =
		math.floor(
			GameConfig.AutoStartMinSeconds
		)

	local maximum =
		math.floor(
			GameConfig.AutoStartMaxSeconds
		)

	if minimum > maximum then

		minimum,
			maximum =
			maximum,
			minimum
	end

	return math.random(
		minimum,
		maximum
	)
end

------------------------------------------------------------
-- LOBBY TIMER
------------------------------------------------------------

local function runLobbyStartTimer()

	local totalSeconds =
		chooseStartSeconds()

	local dramaticSeconds =
		GameConfig.RoundStartCountdownSeconds

	local lobbySeconds =
		totalSeconds
	- dramaticSeconds

	lobbySeconds =
		math.max(
			1,
			lobbySeconds
		)

	if GameConfig.DebugPrints then

		print(
			"[RoundService] --------------------------------"
		)

		print(
			"[RoundService] NEW ROUND TIMER"
		)

		print(
			"[RoundService] Total start time:",
			totalSeconds
		)

		print(
			"[RoundService] Lobby portion:",
			lobbySeconds
		)

		print(
			"[RoundService] --------------------------------"
		)
	end

	for remaining =
		lobbySeconds,
		1,
		-1
	do

		----------------------------------------------------
		-- CANCEL ONLY IF SERVER IS EMPTY
		----------------------------------------------------

		if #getMatchmakingPlayers()
			< GameConfig.AbsoluteMinimumPlayers then

			return false
		end

		local totalRemaining =
			remaining
			+ dramaticSeconds

		sendRoundState(
			"WAITING",
			totalRemaining,
			nil
		)

		task.wait(1)
	end

	return true
end

------------------------------------------------------------
-- DRAMATIC COUNTDOWN
------------------------------------------------------------

local function runDramaticCountdown()

	--------------------------------------------------------
	-- PLAYER IS ALREADY GROUNDED.
	--
	-- KEEP THEM LOCKED THROUGH 3 / 2 / 1.
	--------------------------------------------------------

	freezeRoundPlayers()

	for remaining =
		GameConfig.RoundStartCountdownSeconds,
		1,
		-1
	do

		sendRoundState(
			"STARTING",
			remaining,
			nil
		)

		if GameConfig.DebugPrints then

			print(
				"[RoundService] Countdown:",
				remaining
			)
		end

		task.wait(1)
	end

	--------------------------------------------------------
	-- GO!
	--------------------------------------------------------

	releaseRoundPlayers()
end

------------------------------------------------------------
-- SOLO PRACTICE
------------------------------------------------------------

local function runSoloPractice()

	local players =
		getMatchmakingPlayers()

	if #players ~= 1 then
		return
	end

	local player =
		players[1]

	if GameConfig.DebugPrints then

		print(
			"[RoundService] SOLO PRACTICE STARTED"
		)
	end

	for remaining =
		GameConfig.SoloPracticeSeconds,
		1,
		-1
	do

		if #getMatchmakingPlayers() >= 2 then

			sendRoundState(
				"PRACTICE_ENDING",
				0,
				nil
			)

			task.wait(1)

			return
		end

		if not player.Parent then
			return
		end

		local humanoid =
			getHumanoid(
				player
			)

		if not humanoid
			or humanoid.Health <= 0 then

			return
		end

		sendRoundState(
			"PRACTICE",
			remaining,
			nil
		)

		task.wait(1)
	end
end

------------------------------------------------------------
-- AWARD WIN
------------------------------------------------------------

------------------------------------------------------------
-- BOMB MATCH
------------------------------------------------------------

local function runBombMatch()
	Economy.BeginRound(getAlivePlayers())

	local finalDuelAnnounced =
		false

	while running do

		local alivePlayers =
			getAlivePlayers()

		if #alivePlayers <= 1 then
			break
		end

		local finalDuel =
			#alivePlayers == 2

		if finalDuel
			and not finalDuelAnnounced then

			finalDuelAnnounced =
				true

			sendRoundState(
				"FINAL_DUEL",
				0,
				nil
			)

			task.wait(0.75)

		else

			sendRoundState(
				"ROUND",
				0,
				nil
			)
		end

		local fuseSeconds

		if finalDuel then

			fuseSeconds =
				GameConfig.FinalDuelBombFuseSeconds

		else

			fuseSeconds =
				GameConfig.NormalBombFuseSeconds
		end

		BombService.RunBombCycle(
			getAlivePlayers,
			fuseSeconds
		)

		task.wait(
			GameConfig.BetweenBombsSeconds
		)
	end

	--------------------------------------------------------
	-- WINNER
	--------------------------------------------------------

	BombService.Stop()

	local survivors =
		getAlivePlayers()

	local winner = nil

	if #survivors == 1 then

		winner =
			survivors[1]

	end

	--------------------------------------------------------
	-- RESULTS
	--------------------------------------------------------

	Economy.EndRound(winner)

	for remaining =
		GameConfig.ResultsSeconds,
		1,
		-1
	do

		sendRoundState(
			"RESULT",
			remaining,
			winner
		)

		task.wait(1)
	end
end

------------------------------------------------------------
-- ROUND CYCLE
------------------------------------------------------------

local function runRoundCycle()

	local playerExists =
		waitForAtLeastOnePlayer()

	if not playerExists then
		return
	end

	--------------------------------------------------------
	-- 10-15 SECOND START
	--------------------------------------------------------

	MapVoteService.RunVote(7)

	local timerFinished = runLobbyStartTimer()

	if not timerFinished then
		return
	end

	--------------------------------------------------------
	-- TELEPORT + GROUND + FREEZE
	--------------------------------------------------------

	preparePlayers()

	--------------------------------------------------------
	-- 3 / 2 / 1
	--------------------------------------------------------

	runDramaticCountdown()

	--------------------------------------------------------
	-- DETERMINE ROUND TYPE
	--------------------------------------------------------

	local alivePlayers =
		getAlivePlayers()

	if #alivePlayers == 0 then

		returnEveryoneToLobby()

		return
	end

	if #alivePlayers == 1 then

		runSoloPractice()

	else

		runBombMatch()
	end

	--------------------------------------------------------
	-- BACK TO LOBBY
	--------------------------------------------------------

	returnEveryoneToLobby()

	task.wait(0.5)
end

------------------------------------------------------------
-- MAIN LOOP
------------------------------------------------------------

local function gameLoop()

	print(
		"[RoundService] GAME LOOP IS RUNNING"
	)

	while running do

		local success,
			errorMessage =
			pcall(
				runRoundCycle
			)

		if not success then
			Economy.AbortRound()

			warn(
				"[RoundService] ROUND ERROR:",
				errorMessage
			)

			------------------------------------------------
			-- NEVER LEAVE PLAYERS FROZEN AFTER AN ERROR
			------------------------------------------------

			releaseRoundPlayers()

			task.wait(2)
		end
	end
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------

function RoundService.Init()

	if running then
		return
	end

	running =
		true

	Players.CharacterAutoLoads =
		false

	roundRemote =
		Remotes.Get(
			"RoundState"
		)

	for _, player in ipairs(
		Players:GetPlayers()
		) do

		setupPlayer(
			player
		)

		if not player.Character then

			loadLobbyCharacter(
				player
			)
		end
	end

	Players.PlayerAdded:Connect(
		function(player)

			setupPlayer(
				player
			)
		end
	)

	task.spawn(
		gameLoop
	)

	print(
		"[RoundService] INITIALIZED"
	)
end

return RoundService