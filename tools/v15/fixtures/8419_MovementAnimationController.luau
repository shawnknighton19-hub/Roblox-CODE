--!nonstrict

local Players =
	game:GetService("Players")

local RunService =
	game:GetService("RunService")

------------------------------------------------------------
-- CONTROLLER
------------------------------------------------------------

local MovementAnimationController = {}

local localPlayer =
	Players.LocalPlayer

------------------------------------------------------------
-- CUSTOM ANIMATIONS
------------------------------------------------------------

local SPRINT_ANIMATION_ID =
	"rbxassetid://99070971416334"

local SLIDE_ANIMATION_ID =
	"rbxassetid://11663166420"

------------------------------------------------------------
-- SPEED REFERENCES
------------------------------------------------------------

local SPRINT_REFERENCE_SPEED = 34
local SLIDE_REFERENCE_SPEED = 32

------------------------------------------------------------
-- CHARACTER
------------------------------------------------------------

local character = nil
local humanoid = nil
local root = nil
local animator = nil

------------------------------------------------------------
-- ANIMATION OBJECTS
------------------------------------------------------------

local sprintAnimation = nil
local slideAnimation = nil

------------------------------------------------------------
-- TRACKS
------------------------------------------------------------

local sprintTrack = nil
local slideTrack = nil

------------------------------------------------------------
-- CONNECTIONS
------------------------------------------------------------

local characterConnections = {}

------------------------------------------------------------
-- CLEAN CONNECTIONS
------------------------------------------------------------

local function clearConnections()

	for _, connection in ipairs(
		characterConnections
		) do

		connection:Disconnect()
	end

	table.clear(
		characterConnections
	)
end

------------------------------------------------------------
-- HORIZONTAL SPEED
------------------------------------------------------------

local function getHorizontalSpeed()

	if not root then
		return 0
	end

	return Vector3.new(
		root.AssemblyLinearVelocity.X,
		0,
		root.AssemblyLinearVelocity.Z
	).Magnitude
end

------------------------------------------------------------
-- STOP SPRINT
------------------------------------------------------------

local function stopSprint()

	if not sprintTrack then
		return
	end

	if sprintTrack.IsPlaying then

		sprintTrack:Stop(
			0.10
		)
	end
end

------------------------------------------------------------
-- STOP SLIDE
------------------------------------------------------------

local function stopSlide()

	if not slideTrack then
		return
	end

	if slideTrack.IsPlaying then

		slideTrack:Stop(
			0.08
		)
	end
end

------------------------------------------------------------
-- LOAD ONE ANIMATION
------------------------------------------------------------

local function loadAnimationTrack(
	name,
	animationId,
	priority,
	looped
)

	local animation =
		Instance.new("Animation")

	animation.Name =
		name

	animation.AnimationId =
		animationId

	local success,
		track =
		pcall(
			function()

				return animator:LoadAnimation(
					animation
				)
			end
		)

	if not success
		or not track then

		warn(
			"[MovementAnimationController] Failed to load:",
			name,
			animationId
		)

		animation:Destroy()

		return nil,
			nil
	end

	track.Priority =
		priority

	track.Looped =
		looped

	return animation,
		track
end

------------------------------------------------------------
-- LOAD CUSTOM TRACKS
------------------------------------------------------------

local function createTracks()

	--------------------------------------------------------
	-- CLEAN OLD TRACKS
	--------------------------------------------------------

	stopSprint()
	stopSlide()

	if sprintAnimation then

		sprintAnimation:Destroy()
		sprintAnimation =
			nil
	end

	if slideAnimation then

		slideAnimation:Destroy()
		slideAnimation =
			nil
	end

	sprintTrack =
		nil

	slideTrack =
		nil

	--------------------------------------------------------
	-- SPRINT
	--------------------------------------------------------

	sprintAnimation,
		sprintTrack =
		loadAnimationTrack(
			"BombTagSprint",

			SPRINT_ANIMATION_ID,

			Enum.AnimationPriority.Action,

			true
		)

	--------------------------------------------------------
	-- SLIDE
	--
	-- Action4 gives slide higher priority than sprint and
	-- Roblox's normal running animations.
	--------------------------------------------------------

	slideAnimation,
		slideTrack =
		loadAnimationTrack(
			"BombTagSlide",

			SLIDE_ANIMATION_ID,

			Enum.AnimationPriority.Action4,

			true
		)

	if sprintTrack then

		print(
			"[MovementAnimationController] Sprint loaded:",
			SPRINT_ANIMATION_ID
		)
	end

	if slideTrack then

		print(
			"[MovementAnimationController] Slide loaded:",
			SLIDE_ANIMATION_ID
		)
	end
end

------------------------------------------------------------
-- UPDATE CURRENT ANIMATION STATE
------------------------------------------------------------

local function updateMovementAnimations()

	if not character
		or not humanoid
		or not root then

		return
	end

	if humanoid.Health <= 0 then

		stopSprint()
		stopSlide()

		return
	end

	local movementState =
		character:GetAttribute(
			"MovementState"
		)

	--------------------------------------------------------
	-- SLIDE
	--
	-- Slide gets first priority.
	--------------------------------------------------------

	if movementState == "Slide"
		and not root.Anchored
	then

		stopSprint()

		if slideTrack
			and not slideTrack.IsPlaying then

			slideTrack:Play(
				0.07,
				1,
				1
			)
		end

		return
	end

	--------------------------------------------------------
	-- NOT SLIDING
	--------------------------------------------------------

	stopSlide()

	--------------------------------------------------------
	-- SPRINT
	--------------------------------------------------------

	if movementState == "Sprint"
		and humanoid.MoveDirection.Magnitude > 0.05
		and not root.Anchored
	then

		if sprintTrack
			and not sprintTrack.IsPlaying then

			sprintTrack:Play(
				0.10,
				1,
				1
			)
		end

		return
	end

	--------------------------------------------------------
	-- EVERYTHING ELSE
	--------------------------------------------------------

	stopSprint()
end

------------------------------------------------------------
-- UPDATE PLAYBACK SPEEDS
------------------------------------------------------------

local function updatePlaybackSpeeds()

	local speed =
		getHorizontalSpeed()

	--------------------------------------------------------
	-- SPRINT SPEED
	--------------------------------------------------------

	if sprintTrack
		and sprintTrack.IsPlaying then

		local sprintPlaybackSpeed =
			math.clamp(
				speed
				/ SPRINT_REFERENCE_SPEED,

				0.75,
				1.35
			)

		sprintTrack:AdjustSpeed(
			sprintPlaybackSpeed
		)
	end

	--------------------------------------------------------
	-- SLIDE SPEED
	--------------------------------------------------------

	if slideTrack
		and slideTrack.IsPlaying then

		local slidePlaybackSpeed =
			math.clamp(
				speed
				/ SLIDE_REFERENCE_SPEED,

				0.70,
				1.25
			)

		slideTrack:AdjustSpeed(
			slidePlaybackSpeed
		)
	end
end

------------------------------------------------------------
-- CHARACTER SETUP
------------------------------------------------------------

local function setupCharacter(
	newCharacter
)

	--------------------------------------------------------
	-- CLEAN OLD CHARACTER
	--------------------------------------------------------

	clearConnections()

	stopSprint()
	stopSlide()

	character =
		newCharacter

	humanoid =
		newCharacter:WaitForChild(
			"Humanoid"
		)

	root =
		newCharacter:WaitForChild(
			"HumanoidRootPart"
		)

	--------------------------------------------------------
	-- KEEP ROBLOX DEFAULT ANIMATIONS ENABLED
	--------------------------------------------------------

	local animate =
		newCharacter:WaitForChild(
			"Animate",
			5
		)

	if animate then

		animate.Disabled =
			false
	end

	--------------------------------------------------------
	-- GET ROBLOX ANIMATOR
	--------------------------------------------------------

	animator =
		humanoid:FindFirstChildOfClass(
			"Animator"
		)

	if not animator then

		animator =
			humanoid:WaitForChild(
				"Animator",
				5
			)
	end

	if not animator then

		warn(
			"[MovementAnimationController] Animator not found."
		)

		return
	end

	--------------------------------------------------------
	-- LOAD CUSTOM ANIMATIONS
	--------------------------------------------------------

	createTracks()

	--------------------------------------------------------
	-- MOVEMENT STATE
	--------------------------------------------------------

	table.insert(
		characterConnections,

		character
			:GetAttributeChangedSignal(
				"MovementState"
			)
			:Connect(
				updateMovementAnimations
			)
	)

	--------------------------------------------------------
	-- MOVEMENT ACTION
	--
	-- This makes slide transitions respond immediately
	-- when MovementController fires SlideStart / SlideEnd.
	--------------------------------------------------------

	table.insert(
		characterConnections,

		character
			:GetAttributeChangedSignal(
				"MovementActionId"
			)
			:Connect(
				updateMovementAnimations
			)
	)

	--------------------------------------------------------
	-- DEATH
	--------------------------------------------------------

	table.insert(
		characterConnections,

		humanoid.Died:Connect(
			function()

				stopSprint()
				stopSlide()
			end
		)
	)

	updateMovementAnimations()
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------

function MovementAnimationController.Init()

	--------------------------------------------------------
	-- RESPAWN
	--------------------------------------------------------

	localPlayer.CharacterAdded:Connect(
		setupCharacter
	)

	if localPlayer.Character then

		setupCharacter(
			localPlayer.Character
		)
	end

	--------------------------------------------------------
	-- MATCH ANIMATION SPEED TO ACTUAL MOVEMENT
	--------------------------------------------------------

	RunService.RenderStepped:Connect(
		updatePlaybackSpeeds
	)

	print(
		"[MovementAnimationController] Sprint + slide animations initialized"
	)
end

return MovementAnimationController