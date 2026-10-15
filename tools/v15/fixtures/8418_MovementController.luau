--!nonstrict

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local RunService =
	game:GetService("RunService")

local ContextActionService =
	game:GetService("ContextActionService")

local UserInputService =
	game:GetService("UserInputService")

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------

local MovementConfig =
	require(
		ReplicatedStorage
		.Shared
		.Config
		.MovementConfig
	)

------------------------------------------------------------
-- CONTROLLER
------------------------------------------------------------

local MovementController = {}

local localPlayer =
	Players.LocalPlayer

------------------------------------------------------------
-- CHARACTER
------------------------------------------------------------

local character = nil
local humanoid = nil
local root = nil

------------------------------------------------------------
-- INPUT STATE
------------------------------------------------------------

local sprintHeld = false
local qHeld = false

local heldDirections = {

	[Enum.KeyCode.W] = false,

	[Enum.KeyCode.A] = false,

	[Enum.KeyCode.S] = false,

	[Enum.KeyCode.D] = false,
}

local lastDirectionPressed = nil

------------------------------------------------------------
-- NORMAL MOVEMENT
------------------------------------------------------------

local currentWalkSpeed =
	MovementConfig.BaseWalkSpeed

------------------------------------------------------------
-- SLIDE
------------------------------------------------------------

local sliding = false

local slideStartedAt = 0
local slideEndedAt = -100

local slideSpeed = 0

local slideDirection =
	Vector3.new(
		0,
		0,
		-1
	)

------------------------------------------------------------
-- Q EVASIVE MOVEMENT
------------------------------------------------------------

-- Possible values:
--
-- nil
-- "Side"
-- "ForwardDash"
-- "BackDash"

local evadeType = nil

local evadeStartedAt = 0

-- Shared cooldown timestamp for:
--
-- W + Q
-- A + Q
-- S + Q
-- D + Q
local lastEvadeStartedAt = -100

local evadeSpeed = 0

local evadeDirection =
	Vector3.new(
		0,
		0,
		-1
	)

local evadeTargetDirection =
	Vector3.new(
		0,
		0,
		-1
	)

local evadeDirectionKey = nil

------------------------------------------------------------
-- MOMENTUM CARRY
------------------------------------------------------------

local carryingMomentum = false

local momentumStartedAt = 0

local momentumSpeed = 0

local momentumDirection =
	Vector3.new(
		0,
		0,
		-1
	)

------------------------------------------------------------
-- CAMERA
------------------------------------------------------------

local currentCameraOffset =
	Vector3.zero

------------------------------------------------------------
-- ANIMATION COMMUNICATION
------------------------------------------------------------

local movementActionId = 0

local currentMovementState = ""

------------------------------------------------------------
-- VECTOR HELPERS
------------------------------------------------------------

local function horizontal(vector)

	return Vector3.new(
		vector.X,
		0,
		vector.Z
	)
end

local function responseAlpha(
	responseSpeed,
	deltaTime
)

	return 1
	- math.exp(
		-responseSpeed
			* deltaTime
	)
end

------------------------------------------------------------
-- VELOCITY
------------------------------------------------------------

local function getHorizontalVelocity()

	if not root then

		return Vector3.zero
	end

	return horizontal(
		root.AssemblyLinearVelocity
	)
end

local function getHorizontalSpeed()

	return getHorizontalVelocity().Magnitude
end

------------------------------------------------------------
-- GROUND
------------------------------------------------------------

local function isGrounded()

	if not humanoid then

		return false
	end

	return humanoid.FloorMaterial
		~= Enum.Material.Air
end

------------------------------------------------------------
-- NORMAL DESIRED SPEED
------------------------------------------------------------

local function getDesiredRunSpeed()

	if sprintHeld then

		return MovementConfig.SprintSpeed
	end

	return MovementConfig.BaseWalkSpeed
end

------------------------------------------------------------
-- ANIMATION STATE
------------------------------------------------------------

local function setMovementState(state)

	if not character then
		return
	end

	if currentMovementState == state then
		return
	end

	currentMovementState =
		state

	character:SetAttribute(
		"MovementState",
		state
	)
end

local function fireMovementAction(
	actionName
)

	if not character then
		return
	end

	movementActionId += 1

	character:SetAttribute(
		"MovementAction",
		actionName
	)

	character:SetAttribute(
		"MovementActionId",
		movementActionId
	)
end

------------------------------------------------------------
-- CAMERA-RELATIVE DIRECTIONS
------------------------------------------------------------

local function getCameraDirections()

	local camera =
		workspace.CurrentCamera

	local fallbackForward =
		Vector3.new(
			0,
			0,
			-1
		)

	local fallbackRight =
		Vector3.new(
			1,
			0,
			0
		)

	--------------------------------------------------------
	-- FALLBACK TO CHARACTER
	--------------------------------------------------------

	if root then

		local characterForward =
			horizontal(
				root.CFrame.LookVector
			)

		if characterForward.Magnitude > 0.05 then

			fallbackForward =
				characterForward.Unit
		end

		local characterRight =
			horizontal(
				root.CFrame.RightVector
			)

		if characterRight.Magnitude > 0.05 then

			fallbackRight =
				characterRight.Unit
		end
	end

	--------------------------------------------------------
	-- NO CAMERA
	--------------------------------------------------------

	if not camera then

		return fallbackForward,
			fallbackRight
	end

	--------------------------------------------------------
	-- CAMERA DIRECTIONS
	--------------------------------------------------------

	local forward =
		horizontal(
			camera.CFrame.LookVector
		)

	local right =
		horizontal(
			camera.CFrame.RightVector
		)

	if forward.Magnitude > 0.05 then

		forward =
			forward.Unit

	else

		forward =
			fallbackForward
	end

	if right.Magnitude > 0.05 then

		right =
			right.Unit

	else

		right =
			fallbackRight
	end

	return forward,
		right
end

------------------------------------------------------------
-- CARDINAL DIRECTION FROM KEY
------------------------------------------------------------

local function getDirectionFromKey(
	keyCode
)

	local forward,
		right =
		getCameraDirections()

	if keyCode == Enum.KeyCode.W then

		return forward

	elseif keyCode == Enum.KeyCode.S then

		return -forward

	elseif keyCode == Enum.KeyCode.A then

		return -right

	elseif keyCode == Enum.KeyCode.D then

		return right
	end

	return nil
end

------------------------------------------------------------
-- ANIMATION ACTION NAME
------------------------------------------------------------

local function getEvadeActionName(
	keyCode
)

	if keyCode == Enum.KeyCode.W then

		return "WeaveForward"

	elseif keyCode == Enum.KeyCode.S then

		return "WeaveBack"

	elseif keyCode == Enum.KeyCode.A then

		return "WeaveLeft"

	elseif keyCode == Enum.KeyCode.D then

		return "WeaveRight"
	end

	return ""
end

------------------------------------------------------------
-- MOMENTUM CARRY
------------------------------------------------------------

local function clearMomentumCarry()

	carryingMomentum =
		false

	momentumStartedAt =
		0

	momentumSpeed =
		0
end

local function beginMomentumCarry()

	if not root then
		return
	end

	local velocity =
		getHorizontalVelocity()

	local speed =
		velocity.Magnitude

	local targetSpeed =
		getDesiredRunSpeed()

	--------------------------------------------------------
	-- ONLY PRESERVE SPEED ABOVE NORMAL MOVEMENT
	--------------------------------------------------------

	if speed <= targetSpeed + 0.25 then

		clearMomentumCarry()

		return
	end

	momentumSpeed =
		math.min(
			speed,
			MovementConfig.MaxMovementSpeed
		)

	if velocity.Magnitude > 0.05 then

		momentumDirection =
			velocity.Unit
	end

	momentumStartedAt =
		os.clock()

	carryingMomentum =
		true
end

------------------------------------------------------------
-- END Q EVASIVE MOVE
------------------------------------------------------------

local function endEvade()

	if not evadeType then
		return
	end

	local finishedType =
		evadeType

	evadeType =
		nil

	--------------------------------------------------------
	-- RESTORE HUMANOID
	--------------------------------------------------------

	if humanoid then

		humanoid.AutoRotate =
			true

		humanoid.JumpPower =
			MovementConfig.JumpPower
	end

	--------------------------------------------------------
	-- FORWARD / BACK DASH
	--
	-- IMPORTANT:
	--
	-- The fixed dash velocity ends HERE.
	--
	-- We intentionally do not preserve 38 studs/sec after
	-- the forward dash.
	--------------------------------------------------------

	if finishedType == "ForwardDash"
		or finishedType == "BackDash" then

		if root then

			local normalSpeed =
				getDesiredRunSpeed()

			local currentVelocity =
				getHorizontalVelocity()

			local exitDirection =
				evadeDirection

			if currentVelocity.Magnitude > 0.05 then

				exitDirection =
					currentVelocity.Unit
			end

			local verticalVelocity =
				root.AssemblyLinearVelocity.Y

			root.AssemblyLinearVelocity =
				exitDirection
				* normalSpeed
				+ Vector3.new(
					0,
					verticalVelocity,
					0
				)
		end

		clearMomentumCarry()

		if humanoid then

			currentWalkSpeed =
				getDesiredRunSpeed()

			humanoid.WalkSpeed =
				currentWalkSpeed
		end

		return
	end

	--------------------------------------------------------
	-- SIDE WEAVE
	--
	-- Side dodges are momentum-based, so if you still
	-- possess EXTRA speed after the cut, preserve it using
	-- the existing momentum-carry system.
	--------------------------------------------------------

	beginMomentumCarry()
end

------------------------------------------------------------
-- BEGIN SIDE WEAVE
------------------------------------------------------------

local function beginSideWeave(
	keyCode,
	direction
)

	local velocity =
		getHorizontalVelocity()

	local speed =
		velocity.Magnitude

	--------------------------------------------------------
	-- SIDE WEAVE REQUIRES EXISTING SPEED
	--------------------------------------------------------

	if speed
		< MovementConfig.SideWeaveMinimumSpeed then

		return
	end

	evadeType =
		"Side"

	evadeStartedAt =
		os.clock()

	lastEvadeStartedAt =
		evadeStartedAt

	evadeDirectionKey =
		keyCode

	evadeSpeed =
		math.min(
			speed,
			MovementConfig.MaxMovementSpeed
		)

	if velocity.Magnitude > 0.05 then

		evadeDirection =
			velocity.Unit

	else

		evadeDirection =
			direction
	end

	evadeTargetDirection =
		direction

	--------------------------------------------------------
	-- SPECIAL MOVEMENT OWNS VELOCITY
	--------------------------------------------------------

	clearMomentumCarry()

	humanoid.AutoRotate =
		false

	humanoid.WalkSpeed =
		0

	--------------------------------------------------------
	-- ANIMATION
	--------------------------------------------------------

	fireMovementAction(
		getEvadeActionName(
			keyCode
		)
	)

	if MovementConfig.DebugPrints then

		print(
			"[Movement] Side weave:",
			getEvadeActionName(keyCode)
		)
	end
end

------------------------------------------------------------
-- BEGIN FORWARD / BACK DASH
------------------------------------------------------------

local function beginDash(
	keyCode,
	direction
)

	--------------------------------------------------------
	-- FORWARD
	--------------------------------------------------------

	if keyCode == Enum.KeyCode.W then

		evadeType =
			"ForwardDash"

		evadeSpeed =
			MovementConfig.ForwardDashSpeed

		--------------------------------------------------------
		-- BACK
		--------------------------------------------------------

	elseif keyCode == Enum.KeyCode.S then

		evadeType =
			"BackDash"

		evadeSpeed =
			MovementConfig.BackDashSpeed

	else

		return
	end

	evadeStartedAt =
		os.clock()

	lastEvadeStartedAt =
		evadeStartedAt

	evadeDirectionKey =
		keyCode

	evadeDirection =
		direction

	evadeTargetDirection =
		direction

	--------------------------------------------------------
	-- DASH REPLACES EXISTING SPECIAL MOMENTUM.
	--
	-- This prevents:
	--
	-- slide momentum
	-- +
	-- dash speed
	--
	-- from stacking into ridiculous velocity.
	--------------------------------------------------------

	clearMomentumCarry()

	humanoid.AutoRotate =
		false

	humanoid.WalkSpeed =
		0

	--------------------------------------------------------
	-- APPLY IMMEDIATELY
	--------------------------------------------------------

	local verticalVelocity =
		root.AssemblyLinearVelocity.Y

	root.AssemblyLinearVelocity =
		direction
		* evadeSpeed
		+ Vector3.new(
			0,
			verticalVelocity,
			0
		)

	--------------------------------------------------------
	-- ANIMATION
	--------------------------------------------------------

	fireMovementAction(
		getEvadeActionName(
			keyCode
		)
	)

	if MovementConfig.DebugPrints then

		print(
			"[Movement] Short dash:",
			getEvadeActionName(keyCode)
		)
	end
end

------------------------------------------------------------
-- TRY TO BEGIN Q MOVE
------------------------------------------------------------

local function beginEvade(
	keyCode
)

	if not humanoid
		or not root
		or humanoid.Health <= 0 then

		return
	end

	--------------------------------------------------------
	-- COUNTDOWN LOCK
	--------------------------------------------------------

	if root.Anchored then
		return
	end

	--------------------------------------------------------
	-- GROUND ONLY
	--------------------------------------------------------

	if not isGrounded() then
		return
	end

	--------------------------------------------------------
	-- CAN'T EVADE DURING SLIDE
	--------------------------------------------------------

	if sliding then
		return
	end

	--------------------------------------------------------
	-- ALREADY EVADING
	--------------------------------------------------------

	if evadeType then
		return
	end

	--------------------------------------------------------
	-- SHARED 1.5 SECOND COOLDOWN
	--------------------------------------------------------

	local timeSinceLastEvade =
		os.clock()
	- lastEvadeStartedAt

	if timeSinceLastEvade
		< MovementConfig.WeaveCooldown then

		return
	end

	--------------------------------------------------------
	-- DIRECTION
	--------------------------------------------------------

	local direction =
		getDirectionFromKey(
			keyCode
		)

	if not direction then
		return
	end

	--------------------------------------------------------
	-- W = FORWARD DASH
	--------------------------------------------------------

	if keyCode == Enum.KeyCode.W then

		beginDash(
			keyCode,
			direction
		)

		--------------------------------------------------------
		-- S = BACK DASH
		--------------------------------------------------------

	elseif keyCode == Enum.KeyCode.S then

		beginDash(
			keyCode,
			direction
		)

		--------------------------------------------------------
		-- A / D = MOMENTUM WEAVE
		--------------------------------------------------------

	elseif keyCode == Enum.KeyCode.A
		or keyCode == Enum.KeyCode.D then

		beginSideWeave(
			keyCode,
			direction
		)
	end
end

------------------------------------------------------------
-- TRY HELD Q + DIRECTION
------------------------------------------------------------

local function tryDirectionalEvade()

	if not qHeld then
		return
	end

	--------------------------------------------------------
	-- MOST RECENTLY PRESSED DIRECTION WINS
	--------------------------------------------------------

	if lastDirectionPressed
		and heldDirections[
		lastDirectionPressed
		] then

		beginEvade(
			lastDirectionPressed
		)

		return
	end

	--------------------------------------------------------
	-- FALLBACK ORDER
	--------------------------------------------------------

	local keys = {

		Enum.KeyCode.W,

		Enum.KeyCode.A,

		Enum.KeyCode.S,

		Enum.KeyCode.D,
	}

	for _, keyCode in ipairs(keys) do

		if heldDirections[
			keyCode
			] then

			beginEvade(
				keyCode
			)

			return
		end
	end
end

------------------------------------------------------------
-- UPDATE SIDE WEAVE
------------------------------------------------------------

local function updateSideWeave(
	deltaTime
)

	local elapsed =
		os.clock()
	- evadeStartedAt

	--------------------------------------------------------
	-- TURN HARD INTO SIDE DIRECTION
	--------------------------------------------------------

	local turnAlpha =
		responseAlpha(
			MovementConfig.SideWeaveTurnRate,
			deltaTime
		)

	local newDirection =
		evadeDirection:Lerp(
			evadeTargetDirection,
			turnAlpha
		)

	if newDirection.Magnitude > 0.01 then

		evadeDirection =
			newDirection.Unit
	end

	--------------------------------------------------------
	-- LOSE A LITTLE SPEED
	--------------------------------------------------------

	evadeSpeed =
		math.max(
			0,

			evadeSpeed
			- MovementConfig.SideWeaveFriction
			* deltaTime
		)

	--------------------------------------------------------
	-- APPLY
	--------------------------------------------------------

	local verticalVelocity =
		root.AssemblyLinearVelocity.Y

	root.AssemblyLinearVelocity =
		evadeDirection
		* evadeSpeed
		+ Vector3.new(
			0,
			verticalVelocity,
			0
		)

	--------------------------------------------------------
	-- FINISHED
	--------------------------------------------------------

	if elapsed
		>= MovementConfig.SideWeaveDuration then

		endEvade()
	end
end

------------------------------------------------------------
-- UPDATE FORWARD/BACK DASH
------------------------------------------------------------

local function updateDash()

	local elapsed =
		os.clock()
	- evadeStartedAt

	local duration

	if evadeType
		== "ForwardDash" then

		duration =
			MovementConfig.ForwardDashDuration

	else

		duration =
			MovementConfig.BackDashDuration
	end

	--------------------------------------------------------
	-- KEEP THE BURST CONSISTENT FOR ITS VERY SHORT
	-- DURATION.
	--------------------------------------------------------

	local verticalVelocity =
		root.AssemblyLinearVelocity.Y

	root.AssemblyLinearVelocity =
		evadeDirection
		* evadeSpeed
		+ Vector3.new(
			0,
			verticalVelocity,
			0
		)

	--------------------------------------------------------
	-- DO NOT TURN THE CHARACTER 180 DEGREES ON BACK DASH.
	--
	-- The upcoming procedural animation will visually
	-- communicate the retreat instead.
	--------------------------------------------------------

	if elapsed >= duration then

		endEvade()
	end
end

------------------------------------------------------------
-- UPDATE EVASIVE MOVE
------------------------------------------------------------

local function updateEvade(
	deltaTime
)

	if not evadeType then
		return
	end

	if not humanoid
		or not root
		or humanoid.Health <= 0 then

		evadeType =
			nil

		return
	end

	--------------------------------------------------------
	-- ROUND LOCK
	--------------------------------------------------------

	if root.Anchored then

		evadeType =
			nil

		return
	end

	--------------------------------------------------------
	-- LEAVING FLOOR ENDS EVADE
	--------------------------------------------------------

	if not isGrounded() then

		endEvade()

		return
	end

	--------------------------------------------------------
	-- SIDE
	--------------------------------------------------------

	if evadeType == "Side" then

		updateSideWeave(
			deltaTime
		)

		--------------------------------------------------------
		-- FORWARD/BACK
		--------------------------------------------------------

	else

		updateDash()
	end
end

------------------------------------------------------------
-- END SLIDE
------------------------------------------------------------

local function endSlide(
	preserveMomentum
)

	if not sliding then
		return
	end

	sliding =
		false

	slideEndedAt =
		os.clock()

	if humanoid then

		humanoid.AutoRotate =
			true

		humanoid.JumpPower =
			MovementConfig.JumpPower
	end

	fireMovementAction(
		"SlideEnd"
	)

	if preserveMomentum then

		beginMomentumCarry()

	else

		clearMomentumCarry()
	end
end

------------------------------------------------------------
-- BEGIN SLIDE
------------------------------------------------------------

local function beginSlide()

	if not humanoid
		or not root
		or humanoid.Health <= 0 then

		return
	end

	if root.Anchored then
		return
	end

	--------------------------------------------------------
	-- DON'T SLIDE DURING Q MOVE
	--------------------------------------------------------

	if evadeType then
		return
	end

	--------------------------------------------------------
	-- PRESSING SLIDE AGAIN = CANCEL
	--------------------------------------------------------

	if sliding then

		local elapsed =
			os.clock()
		- slideStartedAt

		if elapsed
			>= MovementConfig.SlideCancelDelay then

			endSlide(
				true
			)
		end

		return
	end

	--------------------------------------------------------
	-- COOLDOWN
	--------------------------------------------------------

	if os.clock()
		- slideEndedAt
			< MovementConfig.SlideCooldown then

		return
	end

	if not isGrounded() then
		return
	end

	--------------------------------------------------------
	-- CURRENT REAL MOMENTUM
	--------------------------------------------------------

	local velocity =
		getHorizontalVelocity()

	local speed =
		velocity.Magnitude

	if speed
		< MovementConfig.SlideMinimumEntrySpeed then

		return
	end

	if velocity.Magnitude > 0.05 then

		slideDirection =
			velocity.Unit

	else

		return
	end

	--------------------------------------------------------
	-- MOMENTUM-BASED SLIDE
	--------------------------------------------------------

	slideSpeed =
		speed
		* MovementConfig.SlideEntryMomentumMultiplier

	slideSpeed =
		math.clamp(
			slideSpeed,
			0,
			MovementConfig.MaxMovementSpeed
		)

	sliding =
		true

	slideStartedAt =
		os.clock()

	clearMomentumCarry()

	humanoid.AutoRotate =
		false

	humanoid.WalkSpeed =
		0

	humanoid.JumpPower =
		0

	fireMovementAction(
		"SlideStart"
	)
end

------------------------------------------------------------
-- UPDATE SLIDE
------------------------------------------------------------

local function updateSlide(
	deltaTime
)

	if not sliding then
		return
	end

	if not humanoid
		or not root
		or humanoid.Health <= 0 then

		endSlide(
			false
		)

		return
	end

	if root.Anchored then

		endSlide(
			false
		)

		return
	end

	if not isGrounded() then

		endSlide(
			true
		)

		return
	end

	local elapsed =
		os.clock()
	- slideStartedAt

	--------------------------------------------------------
	-- SLIDE STEERING
	--------------------------------------------------------

	local desiredDirection =
		humanoid.MoveDirection

	if desiredDirection.Magnitude > 0.1 then

		local steerAlpha =
			responseAlpha(
				MovementConfig.SlideSteerRate,
				deltaTime
			)

		local newDirection =
			slideDirection:Lerp(
				desiredDirection.Unit,
				steerAlpha
			)

		if newDirection.Magnitude > 0.01 then

			slideDirection =
				newDirection.Unit
		end
	end

	--------------------------------------------------------
	-- FRICTION
	--------------------------------------------------------

	slideSpeed =
		math.max(
			0,

			slideSpeed
			- MovementConfig.SlideFriction
			* deltaTime
		)

	--------------------------------------------------------
	-- APPLY
	--------------------------------------------------------

	local verticalVelocity =
		root.AssemblyLinearVelocity.Y

	root.AssemblyLinearVelocity =
		slideDirection
		* slideSpeed
		+ Vector3.new(
			0,
			verticalVelocity,
			0
		)

	--------------------------------------------------------
	-- FACE SLIDE DIRECTION
	--------------------------------------------------------

	if slideDirection.Magnitude > 0.05 then

		root.CFrame =
			CFrame.lookAt(
				root.Position,

				root.Position
				+ slideDirection
			)
	end

	--------------------------------------------------------
	-- END
	--------------------------------------------------------

	if elapsed
		>= MovementConfig.SlideMaximumDuration then

		endSlide(
			true
		)

		return
	end

	if slideSpeed
		<= MovementConfig.SlideStopSpeed then

		endSlide(
			false
		)
	end
end

------------------------------------------------------------
-- UPDATE MOMENTUM CARRY
------------------------------------------------------------

local function updateMomentumCarry(
	deltaTime
)

	if not carryingMomentum then
		return
	end

	if not humanoid
		or not root
		or humanoid.Health <= 0 then

		clearMomentumCarry()

		return
	end

	if root.Anchored then

		clearMomentumCarry()

		return
	end

	if not isGrounded() then

		clearMomentumCarry()

		return
	end

	--------------------------------------------------------
	-- DON'T FIGHT SPECIAL MOVEMENT
	--------------------------------------------------------

	if sliding
		or evadeType then

		return
	end

	local elapsed =
		os.clock()
	- momentumStartedAt

	--------------------------------------------------------
	-- TIME EXPIRED
	--------------------------------------------------------

	if elapsed
		>= MovementConfig.MomentumCarryDuration then

		clearMomentumCarry()

		currentWalkSpeed =
			getDesiredRunSpeed()

		humanoid.WalkSpeed =
			currentWalkSpeed

		return
	end

	--------------------------------------------------------
	-- STEER
	--------------------------------------------------------

	local desired =
		humanoid.MoveDirection

	if desired.Magnitude > 0.1 then

		local steerAlpha =
			responseAlpha(
				MovementConfig.MomentumCarrySteerRate,
				deltaTime
			)

		local newDirection =
			momentumDirection:Lerp(
				desired.Unit,
				steerAlpha
			)

		if newDirection.Magnitude > 0.01 then

			momentumDirection =
				newDirection.Unit
		end
	end

	--------------------------------------------------------
	-- FRICTION
	--------------------------------------------------------

	momentumSpeed -=
		MovementConfig.MomentumCarryFriction
		* deltaTime

	local normalSpeed =
		getDesiredRunSpeed()

	--------------------------------------------------------
	-- NORMAL MOVEMENT TAKES OVER
	--------------------------------------------------------

	if momentumSpeed <= normalSpeed then

		clearMomentumCarry()

		currentWalkSpeed =
			normalSpeed

		humanoid.WalkSpeed =
			normalSpeed

		return
	end

	momentumSpeed =
		math.min(
			momentumSpeed,
			MovementConfig.MaxMovementSpeed
		)

	local verticalVelocity =
		root.AssemblyLinearVelocity.Y

	root.AssemblyLinearVelocity =
		momentumDirection
		* momentumSpeed
		+ Vector3.new(
			0,
			verticalVelocity,
			0
		)
end

------------------------------------------------------------
-- WALK SPEED
------------------------------------------------------------

local function updateWalkSpeed(
	deltaTime
)

	if not humanoid
		or not root
		or humanoid.Health <= 0 then

		return
	end

	if root.Anchored then
		return
	end

	if sliding
		or evadeType
		or carryingMomentum then

		return
	end

	local targetSpeed =
		getDesiredRunSpeed()

	local alpha =
		responseAlpha(
			MovementConfig.WalkSpeedResponse,
			deltaTime
		)

	currentWalkSpeed +=
		(
			targetSpeed
			- currentWalkSpeed
		)
		* alpha

	humanoid.WalkSpeed =
		currentWalkSpeed
end

------------------------------------------------------------
-- AIR CONTROL
------------------------------------------------------------

local function updateAirControl(
	deltaTime
)

	if not humanoid
		or not root then

		return
	end

	if isGrounded() then
		return
	end

	if sliding
		or evadeType
		or carryingMomentum then

		return
	end

	local desired =
		humanoid.MoveDirection

	if desired.Magnitude < 0.05 then
		return
	end

	local velocity =
		getHorizontalVelocity()

	if velocity.Magnitude < 1 then
		return
	end

	local alpha =
		responseAlpha(
			MovementConfig.AirTurnRate,
			deltaTime
		)

	local direction =
		velocity.Unit:Lerp(
			desired.Unit,
			alpha
		)

	if direction.Magnitude <= 0.01 then
		return
	end

	direction =
		direction.Unit

	local verticalVelocity =
		root.AssemblyLinearVelocity.Y

	--------------------------------------------------------
	-- DIRECTION CHANGES.
	-- SPEED DOES NOT INCREASE.
	--------------------------------------------------------

	root.AssemblyLinearVelocity =
		direction
		* velocity.Magnitude
		+ Vector3.new(
			0,
			verticalVelocity,
			0
		)
end

------------------------------------------------------------
-- ANIMATION MOVEMENT STATE
------------------------------------------------------------

local function updateMovementState()

	if not humanoid
		or not root then

		return
	end

	if root.Anchored then

		setMovementState(
			"Locked"
		)

	elseif sliding then

		setMovementState(
			"Slide"
		)

	elseif evadeType then

		----------------------------------------------------
		-- Keep using "Weave" for now so our current
		-- animation communication remains compatible.
		--
		-- The individual action tells the animation system:
		--
		-- WeaveForward
		-- WeaveBack
		-- WeaveLeft
		-- WeaveRight
		----------------------------------------------------

		setMovementState(
			"Weave"
		)

	elseif not isGrounded() then

		setMovementState(
			"Air"
		)

	elseif carryingMomentum then

		setMovementState(
			"Momentum"
		)

	elseif humanoid.MoveDirection.Magnitude
		<= 0.05 then

		setMovementState(
			"Idle"
		)

	elseif sprintHeld then

		setMovementState(
			"Sprint"
		)

	else

		setMovementState(
			"Run"
		)
	end
end

------------------------------------------------------------
-- CAMERA
------------------------------------------------------------

local function updateCamera(
	deltaTime
)

	if not humanoid then
		return
	end

	local camera =
		workspace.CurrentCamera

	if not camera then
		return
	end

	--------------------------------------------------------
	-- FOV
	--------------------------------------------------------

	local targetFOV =
		MovementConfig.NormalFOV

	if sliding then

		targetFOV =
			MovementConfig.SlideFOV

	elseif sprintHeld
		and humanoid.MoveDirection.Magnitude > 0.05 then

		targetFOV =
			MovementConfig.SprintFOV
	end

	local fovAlpha =
		responseAlpha(
			MovementConfig.FOVResponseSpeed,
			deltaTime
		)

	camera.FieldOfView +=
		(
			targetFOV
			- camera.FieldOfView
		)
		* fovAlpha

	--------------------------------------------------------
	-- CAMERA HEIGHT
	--------------------------------------------------------

	local targetOffset =
		Vector3.zero

	if sliding then

		targetOffset =
			MovementConfig.SlideCameraOffset
	end

	local offsetAlpha =
		responseAlpha(
			MovementConfig.CameraOffsetResponseSpeed,
			deltaTime
		)

	currentCameraOffset =
		currentCameraOffset:Lerp(
			targetOffset,
			offsetAlpha
		)

	humanoid.CameraOffset =
		currentCameraOffset
end

------------------------------------------------------------
-- SPRINT INPUT
------------------------------------------------------------

local function sprintAction(
	actionName,
	inputState,
	inputObject
)

	if inputState
		== Enum.UserInputState.Begin then

		sprintHeld =
			true

	elseif inputState
		== Enum.UserInputState.End
		or inputState
		== Enum.UserInputState.Cancel then

		sprintHeld =
			false
	end

	return Enum.ContextActionResult.Sink
end

------------------------------------------------------------
-- SLIDE INPUT
------------------------------------------------------------

local function slideAction(
	actionName,
	inputState,
	inputObject
)

	if inputState
		== Enum.UserInputState.Begin then

		beginSlide()
	end

	return Enum.ContextActionResult.Sink
end

------------------------------------------------------------
-- Q + WASD INPUT
------------------------------------------------------------

local function onInputBegan(
	inputObject,
	gameProcessed
)

	if gameProcessed then
		return
	end

	local keyCode =
		inputObject.KeyCode

	--------------------------------------------------------
	-- WASD
	--------------------------------------------------------

	if heldDirections[keyCode]
		~= nil then

		heldDirections[keyCode] =
			true

		lastDirectionPressed =
			keyCode

		----------------------------------------------------
		-- Q WAS PRESSED FIRST
		----------------------------------------------------

		if qHeld then

			tryDirectionalEvade()
		end

		return
	end

	--------------------------------------------------------
	-- Q
	--------------------------------------------------------

	if keyCode == Enum.KeyCode.Q then

		qHeld =
			true

		----------------------------------------------------
		-- DIRECTION WAS PRESSED FIRST
		----------------------------------------------------

		tryDirectionalEvade()
	end
end

local function onInputEnded(
	inputObject,
	gameProcessed
)

	local keyCode =
		inputObject.KeyCode

	--------------------------------------------------------
	-- WASD
	--------------------------------------------------------

	if heldDirections[keyCode]
		~= nil then

		heldDirections[keyCode] =
			false

		if lastDirectionPressed
			== keyCode then

			lastDirectionPressed =
				nil
		end

		return
	end

	--------------------------------------------------------
	-- Q
	--------------------------------------------------------

	if keyCode == Enum.KeyCode.Q then

		qHeld =
			false
	end
end

------------------------------------------------------------
-- JUMP
------------------------------------------------------------

local function onJumpRequested()

	if not humanoid
		or not root then

		return
	end

	if root.Anchored then
		return
	end

	--------------------------------------------------------
	-- Q MOVE ENDS WHEN PLAYER JUMPS
	--------------------------------------------------------

	if evadeType then

		endEvade()

		return
	end

	--------------------------------------------------------
	-- ONLY SPECIAL-CASE SLIDE JUMP
	--------------------------------------------------------

	if not sliding then
		return
	end

	local elapsed =
		os.clock()
	- slideStartedAt

	if elapsed
		< MovementConfig.SlideCancelDelay then

		return
	end

	--------------------------------------------------------
	-- SAVE PLANAR SLIDE MOMENTUM
	--------------------------------------------------------

	local savedHorizontal =
		getHorizontalVelocity()

	endSlide(
		false
	)

	humanoid.JumpPower =
		MovementConfig.JumpPower

	local existingY =
		root.AssemblyLinearVelocity.Y

	root.AssemblyLinearVelocity =
		savedHorizontal
		+ Vector3.new(
			0,
			existingY,
			0
		)

	humanoid.Jump =
		true
end

------------------------------------------------------------
-- CHARACTER SETUP
------------------------------------------------------------

local function setupCharacter(
	newCharacter
)

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
	-- INPUT RESET
	--------------------------------------------------------

	sprintHeld =
		false

	qHeld =
		false

	lastDirectionPressed =
		nil

	for keyCode, _ in pairs(
		heldDirections
		) do

		heldDirections[keyCode] =
			false
	end

	--------------------------------------------------------
	-- STATE RESET
	--------------------------------------------------------

	sliding =
		false

	evadeType =
		nil

	slideStartedAt =
		0

	slideEndedAt =
		-100

	lastEvadeStartedAt =
		-100

	slideSpeed =
		0

	evadeSpeed =
		0

	clearMomentumCarry()

	currentWalkSpeed =
		MovementConfig.BaseWalkSpeed

	currentCameraOffset =
		Vector3.zero

	--------------------------------------------------------
	-- ANIMATION RESET
	--------------------------------------------------------

	movementActionId =
		0

	currentMovementState =
		""

	--------------------------------------------------------
	-- HUMANOID
	--------------------------------------------------------

	humanoid.UseJumpPower =
		true

	humanoid.JumpPower =
		MovementConfig.JumpPower

	humanoid.WalkSpeed =
		MovementConfig.BaseWalkSpeed

	humanoid.AutoRotate =
		true

	humanoid.CameraOffset =
		Vector3.zero

	--------------------------------------------------------
	-- ANIMATION ATTRIBUTES
	--------------------------------------------------------

	character:SetAttribute(
		"MovementState",
		"Idle"
	)

	character:SetAttribute(
		"MovementAction",
		""
	)

	character:SetAttribute(
		"MovementActionId",
		0
	)

	--------------------------------------------------------
	-- CAMERA
	--------------------------------------------------------

	local camera =
		workspace.CurrentCamera

	if camera then

		camera.FieldOfView =
			MovementConfig.NormalFOV
	end
end

------------------------------------------------------------
-- PHYSICS
------------------------------------------------------------

local function updatePhysics(
	deltaTime
)

	if not humanoid
		or not root
		or humanoid.Health <= 0 then

		return
	end

	--------------------------------------------------------
	-- ROUND COUNTDOWN OWNS PLAYER WHILE ANCHORED
	--------------------------------------------------------

	if root.Anchored then

		if sliding then

			endSlide(
				false
			)
		end

		evadeType =
			nil

		clearMomentumCarry()

		root.AssemblyLinearVelocity =
			Vector3.zero

		updateMovementState()

		return
	end

	--------------------------------------------------------
	-- SPECIAL MOVEMENT
	--------------------------------------------------------

	updateSlide(
		deltaTime
	)

	updateEvade(
		deltaTime
	)

	updateMomentumCarry(
		deltaTime
	)

	--------------------------------------------------------
	-- NORMAL MOVEMENT
	--------------------------------------------------------

	updateWalkSpeed(
		deltaTime
	)

	updateAirControl(
		deltaTime
	)

	--------------------------------------------------------
	-- ANIMATION STATE
	--------------------------------------------------------

	updateMovementState()
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------

function MovementController.Init()

	--------------------------------------------------------
	-- SPRINT
	--------------------------------------------------------

	ContextActionService:BindAction(
		"BombTag_Sprint",

		sprintAction,

		true,

		Enum.KeyCode.LeftShift,
		Enum.KeyCode.ButtonL3
	)

	ContextActionService:SetTitle(
		"BombTag_Sprint",
		"SPRINT"
	)

	--------------------------------------------------------
	-- SLIDE
	--------------------------------------------------------

	ContextActionService:BindAction(
		"BombTag_Slide",

		slideAction,

		true,

		Enum.KeyCode.LeftControl,
		Enum.KeyCode.C,
		Enum.KeyCode.ButtonB
	)

	ContextActionService:SetTitle(
		"BombTag_Slide",
		"SLIDE"
	)

	--------------------------------------------------------
	-- Q + WASD
	--------------------------------------------------------

	UserInputService.InputBegan:Connect(
		onInputBegan
	)

	UserInputService.InputEnded:Connect(
		onInputEnded
	)

	--------------------------------------------------------
	-- JUMP
	--------------------------------------------------------

	UserInputService.JumpRequest:Connect(
		onJumpRequested
	)

	--------------------------------------------------------
	-- CHARACTER
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
	-- PHYSICS
	--------------------------------------------------------

	RunService.Heartbeat:Connect(
		updatePhysics
	)

	--------------------------------------------------------
	-- CAMERA
	--------------------------------------------------------

	RunService.RenderStepped:Connect(
		updateCamera
	)

	print(
		"[MovementController] Side weaves + short forward/back dashes initialized"
	)
end

return MovementController