local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false

local deathEvent = Instance.new("RemoteEvent")
deathEvent.Name = "PlayerDied"
deathEvent.Parent = ReplicatedStorage

local whiteFadeIn = Instance.new("RemoteEvent")
whiteFadeIn.Name = "WhiteFadeIn"
whiteFadeIn.Parent = ReplicatedStorage

local whiteFadeOut = Instance.new("RemoteEvent")
whiteFadeOut.Name = "WhiteFadeOut"
whiteFadeOut.Parent = ReplicatedStorage

local DEATH_SCREEN_TIME = 4.5
local FADE_TIME = 1.1

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.Died:Connect(function()
		local deaths = (player:GetAttribute("Deaths") or 0) + 1
		player:SetAttribute("Deaths", deaths)

		deathEvent:FireClient(player, DEATH_SCREEN_TIME, deaths)

		task.wait(DEATH_SCREEN_TIME)

		whiteFadeIn:FireClient(player)
		task.wait(FADE_TIME)

		player:LoadCharacter()

		task.wait(0.5)
		whiteFadeOut:FireClient(player)
	end)
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("Deaths", 0)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player:LoadCharacter()
end)