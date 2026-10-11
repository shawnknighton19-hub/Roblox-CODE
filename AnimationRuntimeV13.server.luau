--!nonstrict
-- Huss V13: the Animator must originate on the server for player clips to replicate.
-- This does not replace characters, change movement or rewrite the avatar setting.
local Players = game:GetService("Players")
local players, links, stopped = {}, {}, false
local function characterAdded(player, character, record)
	record.generation += 1
	local generation = record.generation
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if stopped or players[player] ~= record or generation ~= record.generation or player.Character ~= character or not humanoid then return end
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator:SetAttribute("HussServerAnimatorV13", true)
			animator.Parent = humanoid
		else
			animator:SetAttribute("HussServerAnimatorV13", true)
		end
		if humanoid.RigType ~= Enum.HumanoidRigType.R6 and not record.warned then
			record.warned = true
			warn("[Huss V13 rig] " .. player.Name .. " spawned as R15. Set File > Avatar Settings > ... > R6 in Studio, save settings, publish, then test a fresh server. A Command Bar script cannot change this protected experience setting.")
		end
	end)
end
local function removePlayer(player)
	local record = players[player]
	if not record then return end
	record.generation += 1
	for _, connection in ipairs(record.links) do connection:Disconnect() end
	players[player] = nil
end
local function addPlayer(player)
	if players[player] or stopped then return end
	local record = {generation=0, links={}}
	players[player] = record
	table.insert(record.links, player.CharacterAdded:Connect(function(character) characterAdded(player, character, record) end))
	table.insert(record.links, player.CharacterRemoving:Connect(function() record.generation += 1 end))
	if player.Character then characterAdded(player, player.Character, record) end
end
table.insert(links, Players.PlayerAdded:Connect(addPlayer))
table.insert(links, Players.PlayerRemoving:Connect(removePlayer))
for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end
table.insert(links, script.Destroying:Connect(function()
	stopped = true
	for _, connection in ipairs(links) do connection:Disconnect() end
	local copy = {}
	for player in pairs(players) do table.insert(copy, player) end
	for _, player in ipairs(copy) do removePlayer(player) end
end))
