--!nonstrict

------------------------------------------------------------
-- BOMB TAG - CONTINUOUS FLUID DIVE + I-FRAME REQUEST
--
-- WASD          = Move
-- Shift         = Sprint
-- WASD + Space  = Directional Dive
--
-- Space alone   = Nothing
-- Normal jumping is disabled
--
-- Dive start requests a short server-authoritative
-- Bomb Tag i-frame window.
------------------------------------------------------------

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local UserInputService =
	game:GetService("UserInputService")

local ContextActionService =
	game:GetService("ContextActionService")

local RunService =
	game:GetService("RunService")

------------------------------------------------------------
-- PLAYER
------------------------------------------------------------

local player =
	Players.LocalPlayer

------------------------------------------------------------
-- I-FRAME REMOTE
------------------------------------------------------------

local Shared =
	ReplicatedStorage:WaitForChild("Shared")

local Net =
	Shared:WaitForChild("Net")

local DodgeIFrameRequest =
	Net:WaitForChild("DodgeIFrameRequest")

------------------------------------------------------------
-- NORMAL MOVEMENT
------------------------------------------------------------

local WALK_SPEED = 24
local SPRINT_SPEED = 32

------------------------------------------------------------
-- DIVE DISTANCE / POWER
------------------------------------------------------------

local DIVE_MIN_START_SPEED = 74

local DIVE_MOMENTUM_BONUS = 44

local DIVE_MAX_START_SPEED = 84

local DIVE_DURATION = 0.72

local DIVE_COOLDOWN = 1.5

------------------------------------------------------------
-- DIVE DRAG
------------------------------------------------------------

local DIVE_EARLY_DRAG = 1
local DIVE_LATE_DRAG = 2.7

local DIVE_STOP_SPEED = 5

------------------------------------------------------------
-- DIVE STEERING
------------------------------------------------------------

local CONTROL_RETURN_START = 0.34

local FULL_CONTROL_POINT = 0.86

local DIVE_STEER_RESPONSE = 5.5

------------------------------------------------------------
-- RUNNING HANDOFF
------------------------------------------------------------

local HANDOFF_START = 0.55

local HANDOFF_RESPONSE = 8.5

------------------------------------------------------------
-- DIRECTION MULTIPLIERS
------------------------------------------------------------

local FORWARD_MULTIPLIER = 1.00

local SIDE_MULTIPLIER = 0.98

local BACKWARD_MULTIPLIER = 0.91

local DIAGONAL_MULTIPLIER = 0.99

------------------------------------------------------------
-- CHARACTER TURNING
------------------------------------------------------------

local DIVE_TURN_RESPONSE = 13

------------------------------------------------------------
-- CAMERA
------------------------------------------------------------

local NORMAL_FOV = 70
local SPRINT_FOV = 74
local DIVE_FOV = 77

local FOV_RESPONSE = 14

------------------------------------------------------------
-- CHARACTER
------------------------------------------------------------

local character = nil
local humanoid = nil
local root = nil

------------------------------------------------------------
-- INPUT
------------------------------------------------------------

local held = {
	W = false,
	A = false,
	S = false,
	D = false,
}

local sprintHeld =
	false

------------------------------------------------------------
-- DIVE STATE
------------------------------------------------------------

local diving =
	false

local diveVelocity =
	Vector3.zero

local diveDirection =
	Vector3.zero

local diveStartedAt =
	0

local lastDiveAt =
	-math.huge

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------

-- HussShiftLockV7: inspect the actual facing constraint, not a delayed flag.
-- HussPerfectMovementV11
local function boostedSpeed(base)
 local untilTime=character and character:GetAttribute('HussPerfectBoostUntil')
 if player:GetAttribute('InRound')==true and type(untilTime)=='number' and workspace:GetServerTimeNow()<untilTime then return base+6 end
 return base
end
local function cameraOwnsFacing()
 local lock=root and root:FindFirstChild('ForcedShiftLockOrientation')
 return lock~=nil and lock:IsA('AlignOrientation') and lock.Enabled
end

local function horizontal(
	vector
)

	return Vector3.new(
		vector.X,
		0,
		vector.Z
	)
end

------------------------------------------------------------

local function smoothStep(
	value
)

	value =
		math.clamp(
			value,
			0,
			1
		)

	return value
		* value
		* (
			3
			- 2
			* value
		)
end

------------------------------------------------------------

local function getHorizontalSpeed()

	if not root then
		return 0
	end

	return horizontal(
		root.AssemblyLinearVelocity
	).Magnitude
end

------------------------------------------------------------

local function isGrounded()

	if not humanoid then
		return false
	end

	return humanoid.FloorMaterial
		~= Enum.Material.Air
end

------------------------------------------------------------

local function movementLocked()

	if not character
		or not humanoid
		or not root then

		return true
	end

	if humanoid.Health <= 0 or humanoid.PlatformStand or humanoid.Sit
  or character:GetAttribute('Ragdolled')==true or character:GetAttribute('IsRagdoll')==true
  or player:GetAttribute('HussGamePaused')==true or workspace:GetAttribute('HussGamePaused')==true
  or humanoid:GetState()==Enum.HumanoidStateType.Physics
  or humanoid:GetState()==Enum.HumanoidStateType.Ragdoll
  or humanoid:GetState()==Enum.HumanoidStateType.Seated then
		return true
	end

	--------------------------------------------------------
	-- RoundService anchors the root during 3 / 2 / 1.
	--------------------------------------------------------

	if root.Anchored then
		return true
	end

	return false
end

------------------------------------------------------------
-- ATTRIBUTES
------------------------------------------------------------

local function setMovementState(
	state
)

	if not character then
		return
	end

	character:SetAttribute(
		"MovementState",
		state
	)
end

------------------------------------------------------------

local function fireMovementAction(
	action
)

	if not character then
		return
	end

	character:SetAttribute(
		"MovementAction",
		action
	)

	local actionId =
		character:GetAttribute(
			"MovementActionId"
		) or 0

	character:SetAttribute(
		"MovementActionId",
		actionId + 1
	)
end

------------------------------------------------------------
-- CAMERA RELATIVE DIRECTIONS
------------------------------------------------------------

local function getCameraDirections()

	local camera =
		workspace.CurrentCamera

	if not camera then

		return
			Vector3.new(
				0,
				0,
				-1
			),

			Vector3.new(
				1,
				0,
				0
			)
	end

	local forward =
		horizontal(
			camera.CFrame.LookVector
		)

	local right =
		horizontal(
			camera.CFrame.RightVector
		)

	if forward.Magnitude <= 0.01 then

		forward =
			Vector3.new(
				0,
				0,
				-1
			)

	else

		forward =
			forward.Unit
	end

	if right.Magnitude <= 0.01 then

		right =
			Vector3.new(
				1,
				0,
				0
			)

	else

		right =
			right.Unit
	end

	return forward,
		right
end

------------------------------------------------------------
-- HELD WASD DIRECTION
------------------------------------------------------------

local function getInputDirection()

	local forward,
		right =
		getCameraDirections()

	local direction =
		Vector3.zero

	if held.W then

		direction +=
			forward
	end

	if held.S then

		direction -=
			forward
	end

	if held.D then

		direction +=
			right
	end

	if held.A then

		direction -=
			right
	end

	--------------------------------------------------------
	-- SPACE ALONE DOES NOTHING
	--------------------------------------------------------

	if direction.Magnitude <= 0.01 then

		return nil
	end

	return direction.Unit
end

------------------------------------------------------------
-- DETERMINE DIVE TYPE
------------------------------------------------------------

local function getDiveType(
	direction
)

	local forward,
		right =
		getCameraDirections()

	local forwardDot =
		direction:Dot(
			forward
		)

	local rightDot =
		direction:Dot(
			right
		)

	local absForward =
		math.abs(
			forwardDot
		)

	local absRight =
		math.abs(
			rightDot
		)

	--------------------------------------------------------
	-- DIAGONALS
	--------------------------------------------------------

	if absForward > 0.35
		and absRight > 0.35 then

		if forwardDot > 0
			and rightDot > 0 then

			return
				DIAGONAL_MULTIPLIER,
				"DiveForwardRight"

		elseif forwardDot > 0
			and rightDot < 0 then

			return
				DIAGONAL_MULTIPLIER,
				"DiveForwardLeft"

		elseif forwardDot < 0
			and rightDot > 0 then

			return
				DIAGONAL_MULTIPLIER,
				"DiveBackRight"

		else

			return
				DIAGONAL_MULTIPLIER,
				"DiveBackLeft"
		end
	end

	--------------------------------------------------------
	-- FORWARD
	--------------------------------------------------------

	if forwardDot > 0.5 then

		return
			FORWARD_MULTIPLIER,
			"DiveForward"
	end

	--------------------------------------------------------
	-- BACKWARD
	--------------------------------------------------------

	if forwardDot < -0.5 then

		return
			BACKWARD_MULTIPLIER,
			"DiveBack"
	end

	--------------------------------------------------------
	-- LEFT
	--------------------------------------------------------

	if rightDot < 0 then

		return
			SIDE_MULTIPLIER,
			"DiveLeft"
	end

	--------------------------------------------------------
	-- RIGHT
	--------------------------------------------------------

	return
		SIDE_MULTIPLIER,
		"DiveRight"
end

------------------------------------------------------------
-- FACE MOVEMENT DIRECTION
------------------------------------------------------------

local function faceDirection(
	direction,
	dt
)
 if cameraOwnsFacing() then return end

	if not root then
		return
	end

	direction =
		horizontal(
			direction
		)

	if direction.Magnitude <= 0.01 then
		return
	end

	direction =
		direction.Unit

	local position =
		root.Position

	local target =
		CFrame.lookAt(
			position,
			position + direction,
			Vector3.yAxis
		)

	local alpha =
		1
	- math.exp(
		-DIVE_TURN_RESPONSE
			* dt
	)

	root.CFrame =
		root.CFrame:Lerp(
			target,
			alpha
		)
end

------------------------------------------------------------
-- END DIVE
------------------------------------------------------------

local function finishDive()

	if not diving then
		return
	end

	diving =
		false

	humanoid.AutoRotate = not cameraOwnsFacing()

	--------------------------------------------------------
	-- DO NOT ZERO VELOCITY.
	--------------------------------------------------------

	if sprintHeld
		and humanoid.MoveDirection.Magnitude
		> 0.05 then

		humanoid.WalkSpeed =
			boostedSpeed(SPRINT_SPEED)

	else

		humanoid.WalkSpeed =
			boostedSpeed(WALK_SPEED)
	end

	fireMovementAction(
		"DiveEnd"
	)
end

------------------------------------------------------------
-- START DIVE
------------------------------------------------------------

local function attemptDive()

	if movementLocked() then
		return
	end

	if diving then
		return
	end

	if not isGrounded() then
		return
	end

	local now =
		time()

	if now - lastDiveAt
		< DIVE_COOLDOWN then

		return
	end

	local direction =
		getInputDirection()

	if not direction then
		return
	end

	--------------------------------------------------------
	-- CURRENT MOMENTUM
	--------------------------------------------------------

	local currentSpeed =
		getHorizontalSpeed()

	local startingSpeed =
		math.clamp(
			currentSpeed
			+ DIVE_MOMENTUM_BONUS,

			DIVE_MIN_START_SPEED,

			DIVE_MAX_START_SPEED
		)

	--------------------------------------------------------
	-- DIRECTION TYPE
	--------------------------------------------------------

	local multiplier,
		action =
		getDiveType(
			direction
		)

	startingSpeed =
		startingSpeed
		* multiplier

	--------------------------------------------------------
	-- START DIVE
	--------------------------------------------------------

	lastDiveAt =
		now

	diveStartedAt =
		now

	diveDirection =
		direction

	diveVelocity =
		direction
		* startingSpeed

	diving =
		true

	humanoid.AutoRotate =
		false

	humanoid.WalkSpeed =
		0

	--------------------------------------------------------
	-- ASK SERVER FOR DODGE I-FRAMES
	--------------------------------------------------------

	DodgeIFrameRequest:FireServer(direction, action) -- HussDodgeV5

	--------------------------------------------------------
	-- APPLY INITIAL DIVE VELOCITY
	--------------------------------------------------------

	local oldVelocity =
		root.AssemblyLinearVelocity

	root.AssemblyLinearVelocity =
		Vector3.new(
			diveVelocity.X,
			oldVelocity.Y,
			diveVelocity.Z
		)

	setMovementState(
		"Dive"
	)

	fireMovementAction(
		action
	)
end

------------------------------------------------------------
-- KEY INPUT
------------------------------------------------------------

UserInputService.InputBegan:Connect(
	function(
		input,
		gameProcessed
	)

		if gameProcessed then
			return
		end

		local key =
			input.KeyCode

		if key == Enum.KeyCode.W then

			held.W =
				true

		elseif key == Enum.KeyCode.A then

			held.A =
				true

		elseif key == Enum.KeyCode.S then

			held.S =
				true

		elseif key == Enum.KeyCode.D then

			held.D =
				true

		elseif key == Enum.KeyCode.LeftShift then

			sprintHeld =
				true
		end
	end
)

------------------------------------------------------------

UserInputService.InputEnded:Connect(
	function(input)

		local key =
			input.KeyCode

		if key == Enum.KeyCode.W then

			held.W =
				false

		elseif key == Enum.KeyCode.A then

			held.A =
				false

		elseif key == Enum.KeyCode.S then

			held.S =
				false

		elseif key == Enum.KeyCode.D then

			held.D =
				false

		elseif key == Enum.KeyCode.LeftShift then

			sprintHeld =
				false
		end
	end
)

------------------------------------------------------------
-- SPACE = DIVE
------------------------------------------------------------

local function handleSpace(
	actionName,
	inputState,
	inputObject
)

	if inputState
		== Enum.UserInputState.Begin then

		attemptDive()
	end

	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(
	"BombTagDirectionalDive",
	handleSpace,
	false,
	3000,
	Enum.KeyCode.Space
)

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
	-- DISABLE NORMAL JUMPING
	--------------------------------------------------------

	humanoid.UseJumpPower =
		true

	humanoid.JumpPower =
		0

	humanoid.JumpHeight =
		0

	humanoid:SetStateEnabled(
		Enum.HumanoidStateType.Jumping,
		false
	)

	humanoid.Jump =
		false

	--------------------------------------------------------
	-- NORMAL MOVEMENT
	--------------------------------------------------------

	humanoid.WalkSpeed =
		boostedSpeed(WALK_SPEED)

	humanoid.AutoRotate = not cameraOwnsFacing()

	diving =
		false

	sprintHeld =
		false

	diveVelocity =
		Vector3.zero

	diveDirection =
		Vector3.zero

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

	print(
		"[SnappyMovement] Character ready"
	)
end

------------------------------------------------------------
-- RESPAWN
------------------------------------------------------------

player.CharacterAdded:Connect(
	setupCharacter
)

if player.Character then

	setupCharacter(
		player.Character
	)
end

------------------------------------------------------------
-- PHYSICS
------------------------------------------------------------

RunService.Heartbeat:Connect(
	function(dt)

		if not character
			or not humanoid
			or not root then

			return
		end

		----------------------------------------------------
		-- NEVER ALLOW NORMAL JUMP
		----------------------------------------------------

		humanoid.Jump =
			false

		----------------------------------------------------
		-- ROUND COUNTDOWN LOCK
		----------------------------------------------------

		if movementLocked() then

			diving =
				false

			humanoid.WalkSpeed =
				0

			setMovementState(
				"Locked"
			)

			return
		end

		----------------------------------------------------
		-- ACTIVE DIVE
		----------------------------------------------------

		if diving then

			local elapsed =
				time()
			- diveStartedAt

			local progress =
				math.clamp(
					elapsed
					/ DIVE_DURATION,

					0,
					1
				)

			local speed =
				diveVelocity.Magnitude

			if elapsed >= DIVE_DURATION
				or speed <= DIVE_STOP_SPEED then

				finishDive()

				return
			end

			------------------------------------------------
			-- CURRENT INPUT
			------------------------------------------------

			local inputDirection =
				getInputDirection()

			------------------------------------------------
			-- STEERING CONTROL CURVE
			------------------------------------------------

			local controlAmount =
				0

			if progress
				> CONTROL_RETURN_START then

				controlAmount =
					(
						progress
						- CONTROL_RETURN_START
					)
					/
					(
						FULL_CONTROL_POINT
						- CONTROL_RETURN_START
					)

				controlAmount =
					smoothStep(
						controlAmount
					)
			end

			------------------------------------------------
			-- CURVE DIVE
			------------------------------------------------

			if inputDirection
				and controlAmount > 0 then

				local desiredVelocity =
					inputDirection
					* speed

				local steerAlpha =
					1
				- math.exp(
					-DIVE_STEER_RESPONSE
						* controlAmount
						* dt
				)

				diveVelocity =
					diveVelocity:Lerp(
						desiredVelocity,
						steerAlpha
					)

				if diveVelocity.Magnitude
					> 0.01 then

					diveDirection =
						diveVelocity.Unit
				end
			end

			------------------------------------------------
			-- VARIABLE DRAG
			------------------------------------------------

			local dragProgress =
				smoothStep(
					progress
				)

			local currentDrag =
				DIVE_EARLY_DRAG
				+ (
					DIVE_LATE_DRAG
					- DIVE_EARLY_DRAG
				)
				* dragProgress

			local dragMultiplier =
				math.exp(
					-currentDrag
					* dt
				)

			diveVelocity *=
				dragMultiplier

			------------------------------------------------
			-- RUNNING HANDOFF
			------------------------------------------------

			local handoffAmount =
				0

			if progress
				> HANDOFF_START then

				handoffAmount =
					(
						progress
						- HANDOFF_START
					)
					/
					(
						1
						- HANDOFF_START
					)

				handoffAmount =
					smoothStep(
						handoffAmount
					)
			end

			local desiredSpeed =
				boostedSpeed(WALK_SPEED)

			if sprintHeld then

				desiredSpeed =
					boostedSpeed(SPRINT_SPEED)
			end

			------------------------------------------------
			-- BLEND INTO NORMAL RUNNING
			------------------------------------------------

			if inputDirection
				and handoffAmount > 0 then

				local targetRunVelocity =
					inputDirection
					* desiredSpeed

				local handoffAlpha =
					1
				- math.exp(
					-HANDOFF_RESPONSE
						* handoffAmount
						* dt
				)

				diveVelocity =
					diveVelocity:Lerp(
						targetRunVelocity,
						handoffAlpha
					)
			end

			------------------------------------------------
			-- HUMANOID CONTROL GRADUALLY RETURNS
			------------------------------------------------

			humanoid.WalkSpeed =
				desiredSpeed
				* handoffAmount

			------------------------------------------------
			-- APPLY VELOCITY
			------------------------------------------------

			local currentVelocity =
				root.AssemblyLinearVelocity

			root.AssemblyLinearVelocity =
				Vector3.new(
					diveVelocity.X,
					currentVelocity.Y,
					diveVelocity.Z
				)

			------------------------------------------------
			-- SMOOTH FACING
			------------------------------------------------

			if diveVelocity.Magnitude
				> 0.01 then

				faceDirection(
					diveVelocity.Unit,
					dt
				)
			end

			setMovementState(
				"Dive"
			)

			return
		end

		----------------------------------------------------
		-- NORMAL MOVEMENT
		----------------------------------------------------

		local moving =
			humanoid.MoveDirection.Magnitude
			> 0.05

		if sprintHeld
			and moving then

			humanoid.WalkSpeed =
				boostedSpeed(SPRINT_SPEED)

			setMovementState(
				"Sprint"
			)

		else

			humanoid.WalkSpeed =
				boostedSpeed(WALK_SPEED)

			if moving then

				setMovementState(
					"Run"
				)

			else

				setMovementState(
					"Idle"
				)
			end
		end
	end
)

------------------------------------------------------------
-- CAMERA
------------------------------------------------------------

RunService.RenderStepped:Connect(
	function(dt)

		local camera =
			workspace.CurrentCamera

		if not camera
			or not humanoid then

			return
		end

		local targetFOV =
			NORMAL_FOV

		if diving then

			local progress =
				math.clamp(
					(
						time()
						- diveStartedAt
					)
					/ DIVE_DURATION,

					0,
					1
				)

			local normalTarget =
				NORMAL_FOV

			if sprintHeld then

				normalTarget =
					SPRINT_FOV
			end

			local handoff =
				smoothStep(
					math.clamp(
						(
							progress
							- HANDOFF_START
						)
						/
						(
							1
							- HANDOFF_START
						),

						0,
						1
					)
				)

			targetFOV =
				DIVE_FOV
				+ (
					normalTarget
					- DIVE_FOV
				)
				* handoff

		elseif sprintHeld
			and humanoid.MoveDirection.Magnitude
			> 0.05 then

			targetFOV =
				SPRINT_FOV
		end

		local alpha =
			1
		- math.exp(
			-FOV_RESPONSE
				* dt
		)

		camera.FieldOfView =
			camera.FieldOfView
			+ (
				targetFOV
				- camera.FieldOfView
			)
			* alpha
	end
)

print(
	"[SnappyMovement] FLUID DIVE + I-FRAME CLIENT INITIALIZED"
)
-- HussActionV6: .72s burst; 1.5s cooldown and .45s server immunity are unchanged.
