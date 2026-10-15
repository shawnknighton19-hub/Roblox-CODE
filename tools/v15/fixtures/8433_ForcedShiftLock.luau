--!nonstrict

------------------------------------------------------------
-- BOMB TAG - ROUND ONLY FORCED SHIFT LOCK
--
-- LOBBY:
-- • Roblox controls mouse normally
-- • Right-click camera dragging works
-- • Free cursor
-- • No crosshair
-- • No shoulder offset
--
-- ROUND:
-- • Forced Shift Lock
-- • Center crosshair
-- • Shoulder camera
-- • Character faces camera
--
-- DODGE:
-- • Shift lock controls facing; SnappyMovement controls travel
------------------------------------------------------------

local Players =
	game:GetService("Players")

local RunService =
	game:GetService("RunService")

local UserInputService =
	game:GetService("UserInputService")

local ContextActionService =
	game:GetService("ContextActionService")

local GuiService =
	game:GetService("GuiService")

------------------------------------------------------------
-- PLAYER
------------------------------------------------------------

local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")

------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------

local CAMERA_OFFSET =
	Vector3.new(
		1.75,
		0.15,
		0
	)

local CAMERA_RESPONSE =
	18

local TURN_RESPONSIVENESS =
	100

------------------------------------------------------------
-- CHARACTER
------------------------------------------------------------

local character = nil
local humanoid = nil
local root = nil

------------------------------------------------------------
-- ROTATION
------------------------------------------------------------

local rotationAttachment = nil
local alignOrientation = nil

------------------------------------------------------------
-- CAMERA
------------------------------------------------------------

local currentCameraOffset =
	Vector3.zero

------------------------------------------------------------
-- STATE
------------------------------------------------------------

local windowFocused =
	true

local menuOpen =
	false

local wasInRound =
	false

------------------------------------------------------------
-- REMOVE OLD GUI
------------------------------------------------------------

local oldGui =
	playerGui:FindFirstChild(
		"ForcedShiftLockUI"
	)

if oldGui then
	oldGui:Destroy()
end

------------------------------------------------------------
-- CREATE GUI
------------------------------------------------------------

local screenGui =
	Instance.new("ScreenGui")

screenGui.Name =
	"ForcedShiftLockUI"

screenGui.ResetOnSpawn =
	false

screenGui.IgnoreGuiInset =
	true

screenGui.DisplayOrder =
	100

screenGui.ZIndexBehavior =
	Enum.ZIndexBehavior.Sibling

screenGui.Parent =
	playerGui

------------------------------------------------------------
-- CROSSHAIR
------------------------------------------------------------

local reticle =
	Instance.new("Frame")

reticle.Name =
	"ShiftLockReticle"

reticle.AnchorPoint =
	Vector2.new(
		0.5,
		0.5
	)

reticle.Position =
	UDim2.fromScale(
		0.5,
		0.5
	)

reticle.Size =
	UDim2.fromOffset(
		32,
		32
	)

reticle.BackgroundTransparency =
	1

reticle.Visible =
	false

reticle.Parent =
	screenGui

------------------------------------------------------------
-- CENTER DOT
------------------------------------------------------------

local centerDot =
	Instance.new("Frame")

centerDot.Name =
	"CenterDot"

centerDot.AnchorPoint =
	Vector2.new(
		0.5,
		0.5
	)

centerDot.Position =
	UDim2.fromScale(
		0.5,
		0.5
	)

centerDot.Size =
	UDim2.fromOffset(
		4,
		4
	)

centerDot.BackgroundColor3 =
	Color3.fromRGB(
		255,
		255,
		255
	)

centerDot.BorderSizePixel =
	0

centerDot.Parent =
	reticle

local centerCorner =
	Instance.new("UICorner")

centerCorner.CornerRadius =
	UDim.new(
		1,
		0
	)

centerCorner.Parent =
	centerDot

------------------------------------------------------------
-- CROSSHAIR LINE CREATOR
------------------------------------------------------------

local function createReticleLine(
	name,
	position,
	size
)

	local line =
		Instance.new("Frame")

	line.Name =
		name

	line.AnchorPoint =
		Vector2.new(
			0.5,
			0.5
		)

	line.Position =
		position

	line.Size =
		size

	line.BackgroundColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)

	line.BackgroundTransparency =
		0.15

	line.BorderSizePixel =
		0

	line.Parent =
		reticle

	local corner =
		Instance.new("UICorner")

	corner.CornerRadius =
		UDim.new(
			1,
			0
		)

	corner.Parent =
		line
end

------------------------------------------------------------
-- CROSSHAIR LINES
------------------------------------------------------------

createReticleLine(
	"Top",
	UDim2.new(
		0.5,
		0,
		0.5,
		-10
	),
	UDim2.fromOffset(
		2,
		7
	)
)

createReticleLine(
	"Bottom",
	UDim2.new(
		0.5,
		0,
		0.5,
		10
	),
	UDim2.fromOffset(
		2,
		7
	)
)

createReticleLine(
	"Left",
	UDim2.new(
		0.5,
		-10,
		0.5,
		0
	),
	UDim2.fromOffset(
		7,
		2
	)
)

createReticleLine(
	"Right",
	UDim2.new(
		0.5,
		10,
		0.5,
		0
	),
	UDim2.fromOffset(
		7,
		2
	)
)

------------------------------------------------------------
-- ROUND CHECK
------------------------------------------------------------

local function isInRound()

	return player:GetAttribute(
		"InRound"
	) == true
end

------------------------------------------------------------
-- CLEANUP ROTATION
------------------------------------------------------------

local function cleanupRotation()

	if alignOrientation then

		alignOrientation:Destroy()

		alignOrientation =
			nil
	end

	if rotationAttachment then

		rotationAttachment:Destroy()

		rotationAttachment =
			nil
	end
end

------------------------------------------------------------
-- CREATE ROTATION SYSTEM
------------------------------------------------------------

local function createRotationSystem()

	cleanupRotation()

	if not root then
		return
	end

	rotationAttachment =
		Instance.new("Attachment")

	rotationAttachment.Name =
		"ForcedShiftLockAttachment"

	rotationAttachment.Parent =
		root

	alignOrientation =
		Instance.new("AlignOrientation")

	alignOrientation.Name =
		"ForcedShiftLockOrientation"

	alignOrientation.Mode =
		Enum.OrientationAlignmentMode.OneAttachment

	alignOrientation.Attachment0 =
		rotationAttachment

	alignOrientation.RigidityEnabled =
		false

	alignOrientation.Responsiveness =
		TURN_RESPONSIVENESS

	alignOrientation.MaxTorque =
		math.huge

	alignOrientation.MaxAngularVelocity =
		math.huge

	alignOrientation.Enabled =
		false

	alignOrientation.Parent =
		root
end

------------------------------------------------------------
-- CHARACTER SETUP
------------------------------------------------------------

local updateCharacterRotation
local function setupCharacter(
	newCharacter
)

	cleanupRotation()

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

	currentCameraOffset =
		Vector3.zero

	humanoid.CameraOffset =
		Vector3.zero

	humanoid.AutoRotate =
		true

	createRotationSystem()
 if updateCharacterRotation then updateCharacterRotation() end
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
-- ALT
--
-- Only blocked during gameplay.
------------------------------------------------------------

local function handleAlt(
	actionName,
	inputState,
	inputObject
)

	if isInRound() then

		return Enum.ContextActionResult.Sink
	end

	return Enum.ContextActionResult.Pass
end

ContextActionService:BindActionAtPriority(
	"BombTagBlockAlt",
	handleAlt,
	false,
	10000,
	Enum.KeyCode.LeftAlt,
	Enum.KeyCode.RightAlt
)

------------------------------------------------------------
-- WINDOW FOCUS
------------------------------------------------------------

UserInputService.WindowFocused:Connect(
	function()

		windowFocused =
			true
	end
)

UserInputService.WindowFocusReleased:Connect(
	function()

		windowFocused =
			false
	end
)

------------------------------------------------------------
-- ROBLOX MENU
------------------------------------------------------------

GuiService.MenuOpened:Connect(
	function()

		menuOpen =
			true

		reticle.Visible =
			false
	end
)

GuiService.MenuClosed:Connect(
	function()

		menuOpen =
			false
	end
)

------------------------------------------------------------
-- SHIFT LOCK ACTIVE?
------------------------------------------------------------

local function shouldUseShiftLock()

	if not isInRound() then
		return false
	end

	if not windowFocused then
		return false
	end

	if menuOpen then
		return false
	end

	return true
end

------------------------------------------------------------
-- MOUSE
--
-- IMPORTANT:
--
-- In lobby we DO NOT touch MouseBehavior.
-- Roblox's normal camera script needs to temporarily change
-- MouseBehavior while right-click dragging.
------------------------------------------------------------

local function updateMouse()

	if shouldUseShiftLock() then

		UserInputService.MouseBehavior =
			Enum.MouseBehavior.LockCenter

		UserInputService.MouseIconEnabled =
			false

		reticle.Visible =
			true

	else

		reticle.Visible =
			false

		----------------------------------------------------
		-- DO NOT FORCE:
		--
		-- MouseBehavior = Default
		--
		-- here.
		--
		-- This is what was breaking right-click camera drag.
		----------------------------------------------------
	end
end

------------------------------------------------------------
-- CAMERA OFFSET
------------------------------------------------------------

local function updateCameraOffset(
	dt
)

	if not humanoid then
		return
	end

	local targetOffset =
		Vector3.zero

	if isInRound() then

		targetOffset =
			CAMERA_OFFSET
	end

	local alpha =
		1
	- math.exp(
		-CAMERA_RESPONSE
			* dt
	)

	currentCameraOffset =
		currentCameraOffset:Lerp(
			targetOffset,
			alpha
		)

	humanoid.CameraOffset =
		currentCameraOffset
end

------------------------------------------------------------
-- CHARACTER ROTATION
------------------------------------------------------------

updateCharacterRotation=function()
 -- HussShiftLockV7: stay camera-facing during every directional dodge.
 if not humanoid or not root or not alignOrientation then return end
 local camera=workspace.CurrentCamera
 local mode=humanoid:GetState()
 local blocked=humanoid.Health<=0 or root.Anchored or humanoid.PlatformStand or humanoid.Sit
  or character:GetAttribute('Ragdolled')==true or character:GetAttribute('IsRagdoll')==true
  or player:GetAttribute('HussGamePaused')==true or workspace:GetAttribute('HussGamePaused')==true
  or mode==Enum.HumanoidStateType.Dead or mode==Enum.HumanoidStateType.Ragdoll
  or mode==Enum.HumanoidStateType.Physics or mode==Enum.HumanoidStateType.Seated
 local owns=shouldUseShiftLock() and not blocked and camera~=nil
 if owns then
  local look=camera.CFrame.LookVector
  local flat=Vector3.new(look.X,0,look.Z)
  if flat.Magnitude>.001 then
   alignOrientation.CFrame=CFrame.lookAt(Vector3.zero,flat.Unit,Vector3.yAxis)
  elseif not alignOrientation.Enabled then
   local facing=root.CFrame.LookVector
   flat=Vector3.new(facing.X,0,facing.Z)
   if flat.Magnitude>.001 then alignOrientation.CFrame=CFrame.lookAt(Vector3.zero,flat.Unit,Vector3.yAxis)
   else owns=false end
  end
 end
 alignOrientation.Enabled=owns
 humanoid.AutoRotate=not owns and not blocked and character:GetAttribute('MovementState')~='Dive'
end
updateCharacterRotation()

------------------------------------------------------------
-- ROUND TRANSITION
------------------------------------------------------------

local function updateRoundTransition()

	local currentlyInRound =
		isInRound()

	--------------------------------------------------------
	-- JUST ENTERED ROUND
	--------------------------------------------------------

	if currentlyInRound
		and not wasInRound then

		if humanoid then

			humanoid.AutoRotate =
				false
		end
	end

	--------------------------------------------------------
	-- JUST LEFT ROUND
	--------------------------------------------------------

	if not currentlyInRound
		and wasInRound then

		if alignOrientation then

			alignOrientation.Enabled =
				false
		end

		if humanoid then

			humanoid.AutoRotate =
				true

			humanoid.CameraOffset =
				Vector3.zero
		end

		currentCameraOffset =
			Vector3.zero

		----------------------------------------------------
		-- RELEASE IT ONCE.
		--
		-- After this, Roblox owns the lobby mouse again.
		----------------------------------------------------

		UserInputService.MouseBehavior =
			Enum.MouseBehavior.Default

		UserInputService.MouseIconEnabled =
			true

		reticle.Visible =
			false
	end

	wasInRound =
		currentlyInRound
end

------------------------------------------------------------
-- MAIN UPDATE
------------------------------------------------------------

RunService:BindToRenderStep(
	"BombTagForcedShiftLock",
	Enum.RenderPriority.Camera.Value + 10,
	function(dt)

		updateRoundTransition()

		updateMouse()

		if not humanoid
			or not root then

			return
		end

		updateCameraOffset(
			dt
		)

		updateCharacterRotation()
	end
)

------------------------------------------------------------
-- PROTECT ROUND MOUSE LOCK
--
-- Only active during gameplay.
------------------------------------------------------------

UserInputService
	:GetPropertyChangedSignal(
		"MouseBehavior"
	)
	:Connect(
		function()

			if not shouldUseShiftLock() then

				------------------------------------------------
				-- LOBBY:
				-- DO ABSOLUTELY NOTHING.
				------------------------------------------------

				return
			end

			if UserInputService.MouseBehavior
				~= Enum.MouseBehavior.LockCenter then

				UserInputService.MouseBehavior =
				Enum.MouseBehavior.LockCenter
			end
		end
	)

------------------------------------------------------------
-- CLEANUP
------------------------------------------------------------

script.Destroying:Connect(
	function()

		RunService:UnbindFromRenderStep(
			"BombTagForcedShiftLock"
		)

		ContextActionService:UnbindAction(
			"BombTagBlockAlt"
		)

		cleanupRotation()

		if humanoid then

			humanoid.CameraOffset =
				Vector3.zero

			humanoid.AutoRotate =
				true
		end

		UserInputService.MouseBehavior =
			Enum.MouseBehavior.Default

		UserInputService.MouseIconEnabled =
			true
	end
)

------------------------------------------------------------
-- INITIAL STATE
------------------------------------------------------------

wasInRound =
	isInRound()

print(
	"[ForcedShiftLock] Lobby free-camera + round Shift Lock initialized"
)