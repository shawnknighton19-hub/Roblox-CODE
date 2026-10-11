--!nonstrict
-- Exact reviewed Animate source, allowing only the four existing base animation ID edits.
local A = {}
local uploaded = [========[
--!nonstrict

------------------------------------------------------------
-- BOMB TAG - R6 ANIMATION CONTROLLER
--
-- SnappyMovement controls all movement physics.
-- This script controls animations only.
--
-- Supports:
-- Idle
-- Walk
-- Sprint
-- Fall
-- Forward Dodge
-- Backward Dodge
-- Left Dodge
-- Right Dodge
------------------------------------------------------------

local RunService =
	game:GetService("RunService")

------------------------------------------------------------
-- CHARACTER
------------------------------------------------------------

local character =
	script.Parent

local humanoid =
	character:WaitForChild("Humanoid")

local root =
	character:WaitForChild("HumanoidRootPart")

------------------------------------------------------------
-- ANIMATOR
------------------------------------------------------------

local animator =
	humanoid:FindFirstChildOfClass(
		"Animator"
	)

if not animator then

	animator =
		Instance.new("Animator")

	animator.Parent =
		humanoid
end

------------------------------------------------------------
-- BASE ANIMATION IDS
------------------------------------------------------------

local IDLE_ID =
	"rbxassetid://86722180453998"

local WALK_ID =
	"rbxassetid://128318370222834"

local RUN_ID =
	"rbxassetid://124106396906271"

local FALL_ID =
	"rbxassetid://103035488330716"

------------------------------------------------------------
-- DIRECTIONAL DODGE IDS
--
-- REPLACE THESE AS YOU PUBLISH NEW ANIMATIONS.
--
-- For now they all use your current dodge animation.
------------------------------------------------------------

local DODGE_FORWARD_ID =
	"rbxassetid://140160678402253"

local DODGE_BACK_ID =
	"rbxassetid://140160678402253"

local DODGE_LEFT_ID =
	"rbxassetid://140160678402253"

local DODGE_RIGHT_ID =
	"rbxassetid://140160678402253"

------------------------------------------------------------
-- ANIMATION SETTINGS
------------------------------------------------------------

local NORMAL_FADE_TIME =
	0.15

local DODGE_FADE_IN =
	0.04

local DODGE_FADE_OUT =
	0.10

local WALK_ANIMATION_SPEED =
	1.00

local RUN_ANIMATION_SPEED =
	1.00

local FALL_ANIMATION_SPEED =
	1.00

local DODGE_FORWARD_SPEED =
	1.00

local DODGE_BACK_SPEED =
	1.00

local DODGE_LEFT_SPEED =
	1.00

local DODGE_RIGHT_SPEED =
	1.00

------------------------------------------------------------
-- CREATE TRACK
------------------------------------------------------------

local function createTrack(
	animationId,
	priority,
	looped
)

	local animation =
		Instance.new("Animation")

	animation.AnimationId =
		animationId

	local track =
		animator:LoadAnimation(
			animation
		)

	track.Priority =
		priority

	track.Looped =
		looped

	return track
end

------------------------------------------------------------
-- NORMAL TRACKS
------------------------------------------------------------

local idleTrack =
	createTrack(
		IDLE_ID,
		Enum.AnimationPriority.Idle,
		true
	)

local walkTrack =
	createTrack(
		WALK_ID,
		Enum.AnimationPriority.Movement,
		true
	)

local runTrack =
	createTrack(
		RUN_ID,
		Enum.AnimationPriority.Movement,
		true
	)

local fallTrack =
	createTrack(
		FALL_ID,
		Enum.AnimationPriority.Movement,
		true
	)

------------------------------------------------------------
-- DODGE TRACKS
------------------------------------------------------------

local dodgeForwardTrack =
	createTrack(
		DODGE_FORWARD_ID,
		Enum.AnimationPriority.Action,
		false
	)

local dodgeBackTrack =
	createTrack(
		DODGE_BACK_ID,
		Enum.AnimationPriority.Action,
		false
	)

local dodgeLeftTrack =
	createTrack(
		DODGE_LEFT_ID,
		Enum.AnimationPriority.Action,
		false
	)

local dodgeRightTrack =
	createTrack(
		DODGE_RIGHT_ID,
		Enum.AnimationPriority.Action,
		false
	)

------------------------------------------------------------
-- TRACK TABLES
------------------------------------------------------------

local normalTracks = {
	idleTrack,
	walkTrack,
	runTrack,
	fallTrack,
}

local dodgeTracks = {
	dodgeForwardTrack,
	dodgeBackTrack,
	dodgeLeftTrack,
	dodgeRightTrack,
}

------------------------------------------------------------
-- STATE
------------------------------------------------------------

local currentNormalTrack =
	nil

local currentNormalName =
	""

local activeDodgeTrack =
	nil

------------------------------------------------------------
-- STOP NORMAL TRACKS
------------------------------------------------------------

local function stopNormalTracks(
	exceptTrack
)

	for _, track in ipairs(
		normalTracks
		) do

		if track ~= exceptTrack
			and track.IsPlaying then

			track:Stop(
				NORMAL_FADE_TIME
			)
		end
	end
end

------------------------------------------------------------
-- STOP DODGE TRACKS
------------------------------------------------------------

local function stopDodgeTracks(
	exceptTrack
)

	for _, track in ipairs(
		dodgeTracks
		) do

		if track ~= exceptTrack
			and track.IsPlaying then

			track:Stop(
				0
			)
		end
	end
end

------------------------------------------------------------
-- IS DODGING
------------------------------------------------------------

local function isDodgePlaying()

	for _, track in ipairs(
		dodgeTracks
		) do

		if track.IsPlaying then
			return true
		end
	end

	return false
end

------------------------------------------------------------
-- PLAY NORMAL ANIMATION
------------------------------------------------------------

local function playNormal(
	name,
	track,
	speed
)

	--------------------------------------------------------
	-- Dodge animations override normal animations.
	--------------------------------------------------------

	if isDodgePlaying() then
		return
	end

	if currentNormalTrack == track
		and currentNormalName == name
		and track.IsPlaying then

		track:AdjustSpeed(
			speed or 1
		)

		return
	end

	stopNormalTracks(
		track
	)

	if not track.IsPlaying then

		track:Play(
			NORMAL_FADE_TIME,
			1,
			speed or 1
		)

	else

		track:AdjustSpeed(
			speed or 1
		)
	end

	currentNormalTrack =
		track

	currentNormalName =
		name
end

------------------------------------------------------------
-- PLAY DIRECTIONAL DODGE
------------------------------------------------------------

local function playDodge(
	track,
	speed
)

	--------------------------------------------------------
	-- Stop any previous dodge immediately.
	--------------------------------------------------------

	stopDodgeTracks(
		track
	)

	if track.IsPlaying then

		track:Stop(
			0
		)
	end

	--------------------------------------------------------
	-- Fade out normal movement animation.
	--------------------------------------------------------

	for _, normalTrack in ipairs(
		normalTracks
		) do

		if normalTrack.IsPlaying then

			normalTrack:Stop(
				DODGE_FADE_IN
			)
		end
	end

	currentNormalTrack =
		nil

	currentNormalName =
		""

	activeDodgeTrack =
		track

	track:Play(
		DODGE_FADE_IN,
		1,
		speed or 1
	)
end

------------------------------------------------------------
-- MOVEMENT ACTION LISTENER
------------------------------------------------------------

local lastActionId =
	character:GetAttribute(
		"MovementActionId"
	) or 0

local function checkMovementAction()

	local newActionId =
		character:GetAttribute(
			"MovementActionId"
		) or 0

	if newActionId == lastActionId then
		return
	end

	lastActionId =
		newActionId

	local action =
		character:GetAttribute(
			"MovementAction"
		) or ""

	--------------------------------------------------------
	-- FORWARD
	--------------------------------------------------------

	if action == "DiveForward" then

		playDodge(
			dodgeForwardTrack,
			DODGE_FORWARD_SPEED
		)

		return
	end

	--------------------------------------------------------
	-- BACKWARD
	--------------------------------------------------------

	if action == "DiveBack" then

		playDodge(
			dodgeBackTrack,
			DODGE_BACK_SPEED
		)

		return
	end

	--------------------------------------------------------
	-- LEFT
	--------------------------------------------------------

	if action == "DiveLeft" then

		playDodge(
			dodgeLeftTrack,
			DODGE_LEFT_SPEED
		)

		return
	end

	--------------------------------------------------------
	-- RIGHT
	--------------------------------------------------------

	if action == "DiveRight" then

		playDodge(
			dodgeRightTrack,
			DODGE_RIGHT_SPEED
		)

		return
	end

	--------------------------------------------------------
	-- FORWARD DIAGONALS
	--
	-- For now:
	-- Forward-left/right reuse forward dodge.
	--------------------------------------------------------

	if action == "DiveForwardLeft"
		or action == "DiveForwardRight" then

		playDodge(
			dodgeForwardTrack,
			DODGE_FORWARD_SPEED
		)

		return
	end

	--------------------------------------------------------
	-- BACKWARD DIAGONALS
	--
	-- For now:
	-- Back-left/right reuse backward dodge.
	--------------------------------------------------------

	if action == "DiveBackLeft"
		or action == "DiveBackRight" then

		playDodge(
			dodgeBackTrack,
			DODGE_BACK_SPEED
		)

		return
	end
end

------------------------------------------------------------
-- LISTEN FOR NEW DODGES
------------------------------------------------------------

character:GetAttributeChangedSignal(
	"MovementActionId"
):Connect(
	checkMovementAction
)

------------------------------------------------------------
-- DODGE FINISHED
------------------------------------------------------------

local function dodgeStopped(
	track
)

	if activeDodgeTrack == track then

		activeDodgeTrack =
			nil

		currentNormalTrack =
			nil

		currentNormalName =
			""
	end
end

dodgeForwardTrack.Stopped:Connect(
	function()

		dodgeStopped(
			dodgeForwardTrack
		)
	end
)

dodgeBackTrack.Stopped:Connect(
	function()

		dodgeStopped(
			dodgeBackTrack
		)
	end
)

dodgeLeftTrack.Stopped:Connect(
	function()

		dodgeStopped(
			dodgeLeftTrack
		)
	end
)

dodgeRightTrack.Stopped:Connect(
	function()

		dodgeStopped(
			dodgeRightTrack
		)
	end
)

------------------------------------------------------------
-- STOP EVERYTHING
------------------------------------------------------------

local function stopEverything()

	for _, track in ipairs(
		dodgeTracks
		) do

		if track.IsPlaying then

			track:Stop(
				DODGE_FADE_OUT
			)
		end
	end

	for _, track in ipairs(
		normalTracks
		) do

		if track.IsPlaying then

			track:Stop(
				NORMAL_FADE_TIME
			)
		end
	end

	currentNormalTrack =
		nil

	currentNormalName =
		""

	activeDodgeTrack =
		nil
end

------------------------------------------------------------
-- MAIN ANIMATION UPDATE
------------------------------------------------------------

RunService.RenderStepped:Connect(
	function()

		if humanoid.Health <= 0 then

			stopEverything()

			return
		end

		local movementState =
			character:GetAttribute(
				"MovementState"
			) or "Idle"

		----------------------------------------------------
		-- DODGE OVERRIDES EVERYTHING
		----------------------------------------------------

		if isDodgePlaying() then
			return
		end

		----------------------------------------------------
		-- ROUND LOCK
		----------------------------------------------------

		if root.Anchored
			or movementState == "Locked" then

			playNormal(
				"Idle",
				idleTrack,
				1
			)

			return
		end

		----------------------------------------------------
		-- FALLING
		----------------------------------------------------

		if humanoid.FloorMaterial
			== Enum.Material.Air then

			playNormal(
				"Fall",
				fallTrack,
				FALL_ANIMATION_SPEED
			)

			return
		end

		----------------------------------------------------
		-- DIVE PHYSICS MAY STILL BE ACTIVE AFTER THE
		-- DODGE ANIMATION FINISHES.
		--
		-- Transition into run instead of freezing.
		----------------------------------------------------

		if movementState == "Dive" then

			playNormal(
				"DiveRunOut",
				runTrack,
				RUN_ANIMATION_SPEED
			)

			return
		end

		----------------------------------------------------
		-- SPRINT
		----------------------------------------------------

		if movementState == "Sprint" then

			playNormal(
				"Sprint",
				runTrack,
				RUN_ANIMATION_SPEED
			)

			return
		end

		----------------------------------------------------
		-- WALK
		----------------------------------------------------

		if movementState == "Run" then

			playNormal(
				"Walk",
				walkTrack,
				WALK_ANIMATION_SPEED
			)

			return
		end

		----------------------------------------------------
		-- INPUT FALLBACK
		----------------------------------------------------

		if humanoid.MoveDirection.Magnitude
			> 0.05 then

			playNormal(
				"Walk",
				walkTrack,
				WALK_ANIMATION_SPEED
			)

			return
		end

		----------------------------------------------------
		-- IDLE
		----------------------------------------------------

		playNormal(
			"Idle",
			idleTrack,
			1
		)
	end
)

------------------------------------------------------------
-- DEATH
------------------------------------------------------------

humanoid.Died:Connect(
	function()

		stopEverything()
	end
)

------------------------------------------------------------
-- START
------------------------------------------------------------

playNormal(
	"Idle",
	idleTrack,
	1
)

print(
	"[Animate] 4-direction R6 dodge animation controller initialized"
)]========]
local v5 = uploaded:gsub("local function checkMovementAction%(%)", "local function checkMovementAction()\n if workspace:GetAttribute('HussDodgeV5') == true then return end -- HussDodgeV5", 1)
local names = {"IDLE_ID", "WALK_ID", "RUN_ID", "FALL_ID"}
local function normalize(source)
 return (source:gsub("\r\n", "\n"):gsub("[ \t]+\n", "\n"):gsub("%s+$", ""))
end
local function inspect(source)
 assert(type(source)=="string", "Animate Source is not a string.")
 local ids = {}
 local masked = normalize(source)
 for _,name in ipairs(names) do
  local pattern = "local%s+"..name..'%s*=%s*"([^"\r\n]+)"'
  local count = 0
  masked = masked:gsub(pattern, function(id)
   count += 1
   assert(id:match("^rbxassetid://[1-9]%d*$") and #id<=29 and tonumber(id:sub(14))<=9007199254740991, "Animate "..name.." needs a positive Roblox asset ID.")
   ids[name]=id
   return 'local '..name..' = "__APPROVED_ID__"'
  end)
  assert(count==1, "Animate "..name.." definition differs from the reviewed controller.")
 end
 return masked,ids
end
function A.Adapt(source, target)
 local masked, ids = inspect(source)
 local old = inspect(uploaded)
 local oldV5 = inspect(v5)
 local new = inspect(target)
 assert(masked==old or masked==oldV5 or masked==new, "StarterCharacterScripts.Animate contains unreviewed source. Original preserved; compare it with the uploaded/V5 Animate before adapting.")
 local result = target
 for _,name in ipairs(names) do
  local pattern = "local%s+"..name..'%s*=%s*"([^"\r\n]+)"'
  result = result:gsub(pattern,function() return 'local '..name..' = "'..ids[name]..'"' end,1)
 end
 return result
end
function A.ValidateChildren(object)
 assert(object:IsA("LocalScript"), "Animate must be a LocalScript.")
 -- Both reviewed controllers use source IDs. Preserve every child as-is; never
 -- destroy user's Animation objects or reinterpret them as replacement settings.
 return {}
end
return A
