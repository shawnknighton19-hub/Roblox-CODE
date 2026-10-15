-- Add near the top of TrueHealthController, alongside your other services:
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FallDamageEvent = ReplicatedStorage:WaitForChild("FallDamageEvent")

-- Same fall-damage math as your client script, so the server computes its own
-- trusted number instead of accepting a raw damage value from the client.
local FALL_CONFIG = {
	MinDamageHeight = 4,
	DamageMultiplier = 1.5,
}

local function calculateFallDamage(fallDistance)
	local damage = 0
	if fallDistance > FALL_CONFIG.MinDamageHeight then
		damage = (fallDistance - FALL_CONFIG.MinDamageHeight) * FALL_CONFIG.DamageMultiplier
	end
	return math.floor(damage)
end

FallDamageEvent.OnServerEvent:Connect(function(player, fallDistance)
	-- Basic sanity check so a modified client can't send a fake huge number
	if type(fallDistance) ~= "number" or fallDistance <= 0 or fallDistance > 500 then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local damage = calculateFallDamage(fallDistance)
	if damage > 0 then
		humanoid:TakeDamage(damage) -- this fires HealthChanged, which TrueHealthController already handles correctly
	end
end)