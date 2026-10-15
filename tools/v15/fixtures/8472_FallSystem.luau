
-- Settings
local Config = {
	MinDamageHeight = 4,          -- Below this = "normal" landing, no damage
	HighFallThreshold = 15,       -- Above this = long/large fall

	DamageMultiplier = 1.5,       -- Damage scaling for long falls

	NormalLandAnimStopTime = 0.6, -- How long the tiny/normal land anim plays
	SmallFallAnimStopTime = 0.5,  -- Short fall anim duration
	LargeFallAnimStopTime = 1.5,  -- Set to 0.1 for R6 // Set to 1.5 for R15

	-- Camera shake tuning
	ShortFallShakeMagnitude = 0.15, -- Fixed, small shake for short falls
	ShortFallShakeDuration = 0.35,

	baseShakeDuration = 0.3,      -- Base duration for long falls (scales with distance)
	baseShakeMagnitude = 0.2,     -- Base intensity for long falls (scales with distance)
	maxShakeMagnitude = 2.0,
	maxShakeDuration = 0.7,
}

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FallDamageEvent = ReplicatedStorage:WaitForChild("FallDamageEvent")

-- Variables
local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Animation Instances
local animLong = Instance.new("Animation")
local animSmall = Instance.new("Animation")
local animNormal = Instance.new("Animation")


animLong.AnimationId = "rbxassetid://139926249685852"   -- Long fall animation ID
animSmall.AnimationId = "rbxassetid://106589219571750"   -- Short fall animation ID
animNormal.AnimationId = "rbxassetid://87548732833386" -- Normal/tiny landing animation ID

local playFallAnim = Humanoid:LoadAnimation(animLong)
local playLandAnim = Humanoid:LoadAnimation(animSmall)
local playNormalAnim = Humanoid:LoadAnimation(animNormal)

-- Sound Instances
local soundLand = SoundService:WaitForChild("FallSounds"):WaitForChild("SmallFall")
local soundLargeFall = SoundService:WaitForChild("FallSounds"):WaitForChild("LargeFall")
local DustTemplate = ReplicatedStorage:WaitForChild("FallSystem"):WaitForChild("Dust")

-- Small dust attachment (for the tiny/normal landing), same setup as your old script
local FOOT_OFFSET = Vector3.new(0, -3, 0)
local impactTemplate = script:FindFirstChild("LandingImpact")
local dustEmitter

if impactTemplate then
	local impactAttachment = impactTemplate:Clone()
	impactAttachment.Position = FOOT_OFFSET
	impactAttachment.Orientation = Vector3.new(-90, 0, 0)
	impactAttachment.Parent = HumanoidRootPart
	dustEmitter = impactAttachment:FindFirstChildWhichIsA("ParticleEmitter")
	if not dustEmitter then
		warn("[Landing] No ParticleEmitter found inside LandingImpact.")
	end
else
	warn("[Landing] No 'LandingImpact' Attachment found under this script.")
end

-- Camera Shake and Movement Variables
local isFalling = false
local previousHeight

-- Helper Functions
local function calculateFallDamage(fallDistance)
	local damage = 0
	if fallDistance > Config.MinDamageHeight then
		damage = (fallDistance - Config.MinDamageHeight) * Config.DamageMultiplier
	end
	return math.floor(damage)
end

local function createImpactEffect(position)
	local dustEffect = DustTemplate:Clone()
	dustEffect.Parent = workspace
	dustEffect.Position = position
	dustEffect:FindFirstChild("Attachment"):FindFirstChild("Dust"):Emit(10)
	game.Debris:AddItem(dustEffect, 2)
end

-- Smooth, organic camera shake using Perlin noise instead of a repeating sine
-- wave, with a quick fade-in, an eased fade-out, and a small subtle rotation
-- layered on top of the left/right/up/down movement.
local function shakeCamera(duration, magnitude)
	local startTime = tick()
	local noiseSpeed = 8 -- how fast the noise "wobbles" -- higher = jitterier
	local seedX = math.random(0, 1000)
	local seedY = math.random(0, 1000)
	local seedZ = math.random(0, 1000)

	-- keep the rotation subtle no matter how big the positional shake is
	local rotationMagnitude = math.min(magnitude * 1.2, 4) -- degrees, capped

	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		if elapsed < duration then
			local progress = elapsed / duration

			-- fade in over the first 15% of the shake, then ease out (quadratic)
			-- for the rest -- avoids any sudden snap at the start or end
			local fadeIn = math.min(elapsed / (duration * 0.15), 1)
			local fadeOut = (1 - progress) * (1 - progress)
			local envelope = fadeIn * fadeOut

			local intensity = magnitude * envelope
			local rotIntensity = rotationMagnitude * envelope

			-- Perlin noise gives smooth continuous drift instead of a jittery
			-- fixed-frequency wobble
			local offsetX = (math.noise(elapsed * noiseSpeed, seedX, 0) * 2) * intensity
			local offsetY = (math.noise(elapsed * noiseSpeed, seedY, 0) * 2) * intensity
			local rotZ = (math.noise(elapsed * noiseSpeed, seedZ, 0) * 2) * rotIntensity

			Camera.CFrame = Camera.CFrame
				* CFrame.new(offsetX, offsetY, 0)
				* CFrame.Angles(0, 0, math.rad(rotZ))
		else
			connection:Disconnect()
		end
	end)
end

local function lerp(a, b, c)
	return a + (b - a) * c
end

local function bobbing(deltaTime)
	local func1, func2, func3, func4, val, val2 = 0, 0, 0, 0, 0, 0
	local int, int2 = 5, 5
	local vect3 = Vector3.new()
	vect3 = lerp(vect3, Camera.CFrame.LookVector, 0.125 * deltaTime)
	if Humanoid.Health <= 0 then return end
	local rootMagnitude = (HumanoidRootPart.Velocity * Vector3.new(1, 0, 1)).Magnitude
	local calcRootMagnitude = math.min(rootMagnitude, 25)
	if deltaTime > 1.5 then
		func1, func2 = 0, 0
	else
		func1 = lerp(func1, math.cos(tick() * 0.5 * math.random(5, 7.5)) * 0.1 * deltaTime, 0.05 * deltaTime)
		func2 = lerp(func2, math.cos(tick() * 0.5 * math.random(2.5, 5)) * 0.05 * deltaTime, 0.05 * deltaTime)
	end
	Camera.CFrame = Camera.CFrame *
		(CFrame.Angles(0, 0, math.rad(func3)) *
			CFrame.Angles(math.rad(func4 * deltaTime), math.rad(val * deltaTime), val2) *
			CFrame.Angles(0, 0, math.rad(func4 * deltaTime * (calcRootMagnitude / 5))) *
			CFrame.Angles(math.rad(func1), math.rad(func2), math.rad(func2 * 10)))
	val2 = math.clamp(lerp(val2, -Camera.CFrame:VectorToObjectSpace(HumanoidRootPart.Velocity / math.max(Humanoid.WalkSpeed, 0.01)).X * 0.04, 0.1 * deltaTime), -0.12, 0.1)
	func3 = lerp(func3, math.clamp(UserInputService:GetMouseDelta().X, -2.5, 2.5), 0.25 * deltaTime)
	func4 = lerp(func4, math.sin(tick() * int) / 5 * math.min(1, int2 / 10), 0.25 * deltaTime)
	val = lerp(val, rootMagnitude > 1 and math.cos(tick() * 0.5 * math.floor(int)) * (int / 200) or 0, 0.25 * deltaTime)
	int, int2 = rootMagnitude > 6 and 10 or 6, rootMagnitude > 6 and 9 or 7
end

-- Main Logic
Humanoid.StateChanged:Connect(function(_, state)
	if state == Enum.HumanoidStateType.Freefall then
		previousHeight = HumanoidRootPart.Position.Y
		isFalling = true
	elseif state == Enum.HumanoidStateType.Landed then
		if previousHeight then
			local currentHeight = HumanoidRootPart.Position.Y
			local fallDistance = previousHeight - currentHeight
			isFalling = false

			if fallDistance <= Config.MinDamageHeight then
				-- TIER 1: tiny drop / in-place jump -> normal landing anim only
				playNormalAnim:Play()
				if dustEmitter then
					dustEmitter:Emit(1)
				end
				task.wait(Config.NormalLandAnimStopTime)
				playNormalAnim:Stop()

			elseif fallDistance <= Config.HighFallThreshold then
				-- TIER 2: short fall -> short fall anim, small smooth shake, no damage
				local shakeMagnitude = Config.ShortFallShakeMagnitude
				local shakeDuration = Config.ShortFallShakeDuration
				shakeCamera(shakeDuration, shakeMagnitude)

				Humanoid.WalkSpeed, Humanoid.JumpPower = 0, 0
				soundLand:Play()
				playLandAnim:Play()
				createImpactEffect(HumanoidRootPart.Position)
				task.wait(Config.SmallFallAnimStopTime)
				playLandAnim:Stop()
				Humanoid.WalkSpeed, Humanoid.JumpPower = 16, 50

			else
				-- TIER 3: long fall -> long fall anim, scaled shake, damage (no popup)
				local shakeMagnitude = math.min(Config.baseShakeMagnitude + fallDistance / 10, Config.maxShakeMagnitude)
				local shakeDuration = math.min(Config.baseShakeDuration + fallDistance / 50, Config.maxShakeDuration)
				shakeCamera(shakeDuration, shakeMagnitude)

				soundLargeFall:Play()
				playFallAnim:Play()
				Humanoid.WalkSpeed, Humanoid.JumpPower = 0, 0
				createImpactEffect(HumanoidRootPart.Position)

				local fallDamage = calculateFallDamage(fallDistance)
				if fallDamage > 0 then
					FallDamageEvent:FireServer(fallDistance) -- send raw distance, let server decide damage
				end

				task.wait(Config.LargeFallAnimStopTime)
				playFallAnim:Stop()
				Humanoid.WalkSpeed, Humanoid.JumpPower = 16, 50
			end
		end
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	bobbing(deltaTime)
end)