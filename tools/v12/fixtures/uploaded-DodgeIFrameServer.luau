--!nonstrict

------------------------------------------------------------
-- BOMB TAG - SERVER AUTHORITATIVE DODGE I-FRAMES
--
-- ALSO:
-- Player highlights WHITE for the exact duration
-- of the dodge i-frame window.
------------------------------------------------------------

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------

-- Change this one number whenever we tune i-frame duration.
local IFRAME_DURATION = 0.45

-- Client dodge cooldown is 1.5 seconds.
local MIN_REQUEST_INTERVAL = 1.35

------------------------------------------------------------
-- WHITE I-FRAME VISUAL
------------------------------------------------------------

local HIGHLIGHT_NAME =
	"DodgeIFrameHighlight"

local HIGHLIGHT_FILL_TRANSPARENCY =
	0.25

local HIGHLIGHT_OUTLINE_TRANSPARENCY =
	0

------------------------------------------------------------
-- NETWORK
------------------------------------------------------------

local Shared =
	ReplicatedStorage:WaitForChild("Shared")

local Net =
	Shared:WaitForChild("Net")

local DodgeIFrameRequest =
	Net:FindFirstChild(
		"DodgeIFrameRequest"
	)

if not DodgeIFrameRequest then

	DodgeIFrameRequest =
		Instance.new("RemoteEvent")

	DodgeIFrameRequest.Name =
		"DodgeIFrameRequest"

	DodgeIFrameRequest.Parent =
		Net
end

------------------------------------------------------------
-- REQUEST HISTORY
------------------------------------------------------------

local lastRequest =
	{}

------------------------------------------------------------
-- REMOVE WHITE HIGHLIGHT
------------------------------------------------------------

local function removeIFrameHighlight(
	character
)

	if not character then
		return
	end

	local highlight =
		character:FindFirstChild(
			HIGHLIGHT_NAME
		)

	if highlight then

		highlight:Destroy()
	end
end

------------------------------------------------------------
-- CREATE WHITE HIGHLIGHT
------------------------------------------------------------

local function showIFrameHighlight(
	character
)

	if not character then
		return
	end

	--------------------------------------------------------
	-- REMOVE OLD ONE FIRST
	--------------------------------------------------------

	removeIFrameHighlight(
		character
	)

	--------------------------------------------------------
	-- CREATE NEW HIGHLIGHT
	--------------------------------------------------------

	local highlight =
		Instance.new("Highlight")

	highlight.Name =
		HIGHLIGHT_NAME

	highlight.Adornee =
		character

	--------------------------------------------------------
	-- PURE WHITE
	--------------------------------------------------------

	highlight.FillColor =
		Color3.fromRGB(
			255,
			255,
			255
		)

	highlight.OutlineColor =
		Color3.fromRGB(
			255,
			255,
			255
		)

	highlight.FillTransparency =
		HIGHLIGHT_FILL_TRANSPARENCY

	highlight.OutlineTransparency =
		HIGHLIGHT_OUTLINE_TRANSPARENCY

	--------------------------------------------------------
	-- SHOW THROUGH OTHER CHARACTERS / OBJECTS
	--------------------------------------------------------

	highlight.DepthMode =
		Enum.HighlightDepthMode.AlwaysOnTop

	highlight.Enabled =
		true

	highlight.Parent =
		character
end

------------------------------------------------------------
-- VECTOR VALIDATION
------------------------------------------------------------

local function validDirection(
	direction
)

	if typeof(direction)
		~= "Vector3" then

		return false
	end

	--------------------------------------------------------
	-- NAN CHECK
	--------------------------------------------------------

	if direction.X ~= direction.X
		or direction.Y ~= direction.Y
		or direction.Z ~= direction.Z then

		return false
	end

	--------------------------------------------------------
	-- SHOULD BE MOSTLY HORIZONTAL
	--------------------------------------------------------

	if math.abs(direction.Y)
		> 0.15 then

		return false
	end

	local magnitude =
		Vector3.new(
			direction.X,
			0,
			direction.Z
		).Magnitude

	if magnitude < 0.5
		or magnitude > 1.5 then

		return false
	end

	return true
end

------------------------------------------------------------
-- VALIDATE REQUEST
------------------------------------------------------------

local function canGrantIFrame(
	player,
	direction
)

	if not validDirection(
		direction
		) then

		return false
	end

	local character =
		player.Character

	if not character then
		return false
	end

	local humanoid =
		character:FindFirstChildOfClass(
			"Humanoid"
		)

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not humanoid
		or not root then

		return false
	end

	if humanoid.Health <= 0 then
		return false
	end

	--------------------------------------------------------
	-- NO I-FRAMES DURING ROUND COUNTDOWN
	--------------------------------------------------------

	if root.Anchored then
		return false
	end

	--------------------------------------------------------
	-- DODGE MUST START ON GROUND
	--------------------------------------------------------

	if humanoid.FloorMaterial
		== Enum.Material.Air then

		return false
	end

	--------------------------------------------------------
	-- SERVER COOLDOWN
	--------------------------------------------------------

	local now =
		workspace:GetServerTimeNow()

	local previous =
		lastRequest[player]
		or -math.huge

	if now - previous
		< MIN_REQUEST_INTERVAL then

		return false
	end

	lastRequest[player] =
		now

	return true
end

------------------------------------------------------------
-- GRANT I-FRAMES
------------------------------------------------------------

local function grantIFrames(
	player
)

	local character =
		player.Character

	if not character then
		return
	end

	local now =
		workspace:GetServerTimeNow()

	local immunityEnds =
		now
		+ IFRAME_DURATION

	--------------------------------------------------------
	-- AUTHORITATIVE TIMESTAMP
	--------------------------------------------------------

	character:SetAttribute(
		"BombTagIFrameUntil",
		immunityEnds
	)

	character:SetAttribute(
		"BombTagIFrameActive",
		true
	)

	--------------------------------------------------------
	-- WHITE FLASH / HIGHLIGHT
	--------------------------------------------------------

	showIFrameHighlight(
		character
	)

	--------------------------------------------------------
	-- END I-FRAMES
	--------------------------------------------------------

	task.delay(
		IFRAME_DURATION,
		function()

			------------------------------------------------
			-- MAKE SURE IT IS STILL THE SAME CHARACTER
			------------------------------------------------

			if player.Character
				~= character then

				return
			end

			local storedEnd =
				character:GetAttribute(
					"BombTagIFrameUntil"
				) or 0

			------------------------------------------------
			-- ONLY REMOVE IF IMMUNITY ACTUALLY EXPIRED
			------------------------------------------------

			if workspace:GetServerTimeNow()
				>= storedEnd then

				character:SetAttribute(
					"BombTagIFrameActive",
					false
				)

				removeIFrameHighlight(
					character
				)
			end
		end
	)
end

------------------------------------------------------------
-- CLIENT REQUEST
------------------------------------------------------------

DodgeIFrameRequest.OnServerEvent:Connect(
	function(
		player,
		direction
	)

		if not canGrantIFrame(
			player,
			direction
			) then

			return
		end

		grantIFrames(
			player
		)
	end
)

------------------------------------------------------------
-- CHARACTER SETUP
------------------------------------------------------------

local function setupCharacter(
	character
)

	character:SetAttribute(
		"BombTagIFrameUntil",
		0
	)

	character:SetAttribute(
		"BombTagIFrameActive",
		false
	)

	removeIFrameHighlight(
		character
	)
end

------------------------------------------------------------
-- PLAYER SETUP
------------------------------------------------------------

local function setupPlayer(
	player
)

	player.CharacterAdded:Connect(
		function(character)

			setupCharacter(
				character
			)
		end
	)

	if player.Character then

		setupCharacter(
			player.Character
		)
	end
end

------------------------------------------------------------
-- EXISTING PLAYERS
------------------------------------------------------------

for _, player in ipairs(
	Players:GetPlayers()
	) do

	setupPlayer(
		player
	)
end

------------------------------------------------------------
-- NEW PLAYERS
------------------------------------------------------------

Players.PlayerAdded:Connect(
	setupPlayer
)

------------------------------------------------------------
-- CLEANUP
------------------------------------------------------------

Players.PlayerRemoving:Connect(
	function(player)

		lastRequest[player] =
			nil
	end
)

------------------------------------------------------------
-- READY
------------------------------------------------------------

print(
	"[DodgeIFrameServer] Dodge i-frames initialized"
)

print(
	"[DodgeIFrameServer] I-frame duration:",
	IFRAME_DURATION
)

print(
	"[DodgeIFrameServer] White dodge highlight enabled"
)