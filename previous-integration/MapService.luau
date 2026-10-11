--!nonstrict
-- ModuleScript: ServerScriptService > Services > MapService
-- Clients choose an option; only the server opens, closes and resolves voting.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)
local MapBuilder = require(script.Parent.MapBuilder)

local MapService = {}
local initialized = false
local stateRemote, syncCallback
local catalog, options, eligible = {}, {}, {}
local votes, lastCast, lastSync = {}, {}, {}
local voteId, revision, endsAt = 0, 0, 0
local active, winnerId = false, nil
local random = Random.new()

local function counts()
	local result = {}
	for _, option in ipairs(options) do result[option.Id] = 0 end
	for _, id in pairs(votes) do
		if result[id] ~= nil then result[id] += 1 end
	end
	return result
end

local function snapshot(player, tally)
	return {
		VoteId = voteId,
		Revision = revision,
		Active = active,
		EndsAt = endsAt,
		Options = options,
		Counts = tally or counts(),
		YourVote = votes[player.UserId],
		WinnerId = winnerId,
		ActiveMapId = MapBuilder.GetActiveId(),
	}
end

local function broadcast()
	revision += 1
	local tally = counts()
	for _, player in ipairs(Players:GetPlayers()) do
		stateRemote:FireClient(player, snapshot(player, tally))
	end
end

local function sync(player)
	if player.Parent ~= Players then return end
	stateRemote:FireClient(player, snapshot(player))
	if syncCallback then syncCallback(player) end
end

function MapService.Init()
	if initialized then return end
	MapBuilder.Init()
	catalog = MapBuilder.GetMaps()
	assert(#catalog >= 1, "MapBuilder must provide at least one arena")
	for _, map in ipairs(catalog) do
		assert(typeof(map.Id) == "string" and not eligible[map.Id], "Map IDs must be unique strings")
		eligible[map.Id] = true
		-- Never send ServerStorage templates or client-defined map instances.
		table.insert(options, {
			Id = map.Id, Name = map.Name, Subtitle = map.Subtitle,
			Accent = map.Accent, Layout = map.Layout, Footprint = map.Footprint,
		})
	end
	stateRemote = Remotes.Get("MapVoteState")
	Remotes.Get("MapVoteCast").OnServerEvent:Connect(function(player, requestedVoteId, mapId)
		if player.Parent ~= Players or not active then return end
		if workspace:GetServerTimeNow() >= endsAt then return end
		if typeof(requestedVoteId) ~= "number" or requestedVoteId ~= voteId then return end
		if typeof(mapId) ~= "string" or #mapId > 48 or not eligible[mapId] then return end
		if player:GetAttribute("InRound") == true then return end
		local now = workspace:GetServerTimeNow()
		if now - (lastCast[player.UserId] or -math.huge) < 0.15 then return end
		lastCast[player.UserId] = now
		if votes[player.UserId] == mapId then return end
		votes[player.UserId] = mapId
		broadcast()
	end)
	Remotes.Get("MapVoteSync").OnServerEvent:Connect(function(player)
		if player.Parent ~= Players then return end
		local now = workspace:GetServerTimeNow()
		if now - (lastSync[player.UserId] or -math.huge) < 0.75 then return end
		lastSync[player.UserId] = now
		sync(player)
	end)
	Players.PlayerAdded:Connect(function(player)
		task.defer(function() sync(player) end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local hadVote = votes[player.UserId] ~= nil
		votes[player.UserId], lastCast[player.UserId], lastSync[player.UserId] = nil, nil, nil
		if active and hadVote then broadcast() end
	end)
	initialized = true
end

function MapService.SetStateSync(callback)
	syncCallback = callback
end

function MapService.GetActiveMap()
	return MapBuilder.GetActiveMap()
end

function MapService.GetLobbySpawn()
	return MapBuilder.GetLobbySpawn()
end

function MapService.GetActiveId()
	return MapBuilder.GetActiveId()
end

function MapService.GetMapName()
	local id = MapBuilder.GetActiveId()
	for _, map in ipairs(catalog) do
		if map.Id == id then return map.Name end
	end
	return "Arena"
end

function MapService.CancelVote()
	if not active then return end
	active, winnerId, endsAt = false, nil, 0
	table.clear(votes)
	broadcast()
end

function MapService.RunVote(seconds, shouldContinue, onTick)
	assert(initialized, "MapService.Init() must run before voting")
	assert(not active, "A map vote is already running")
	assert(typeof(seconds) == "number" and seconds == seconds and seconds > 0 and seconds < math.huge,
		"Map vote duration must be a positive finite number")
	voteId += 1
	local thisVoteId = voteId
	table.clear(votes)
	table.clear(lastCast)
	winnerId, active = nil, true
	endsAt = workspace:GetServerTimeNow() + seconds
	broadcast()
	local lastSecond
	while active and voteId == thisVoteId do
		if shouldContinue and not shouldContinue() then
			MapService.CancelVote()
			return nil
		end
		local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
		if remaining == 0 then break end
		if remaining ~= lastSecond then
			lastSecond = remaining
			if onTick then onTick(remaining) end
		end
		task.wait(0.1)
	end
	if not active or voteId ~= thisVoteId then return nil end
	if shouldContinue and not shouldContinue() then
		MapService.CancelVote()
		return nil
	end
	-- Close first so no vote can race map creation after the deadline.
	active = false
	local tally, highest, tied = counts(), -1, {}
	for _, option in ipairs(options) do
		local total = tally[option.Id]
		if total > highest then highest, tied = total, {option.Id}
		elseif total == highest then table.insert(tied, option.Id) end
	end
	-- With no votes, rotate away from the current map when alternatives exist.
	if highest == 0 and #tied > 1 then
		local previous = MapBuilder.GetActiveId()
		for index = #tied, 1, -1 do
			if tied[index] == previous then table.remove(tied, index) end
		end
	end
	local selected = tied[random:NextInteger(1, #tied)]
	local success, result = pcall(function()
		local map = MapBuilder.Activate(selected)
		assert(map and MapBuilder.GetActiveMap() == map and MapBuilder.GetActiveId() == selected,
			"MapBuilder did not activate the winning arena")
		return map
	end)
	if not success then
		winnerId, endsAt = nil, 0
		table.clear(votes)
		broadcast()
		error(result)
	end
	winnerId = selected
	broadcast()
	return selected
end

return MapService
