--!nonstrict

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapService = {}

local MapLibrary
local MapsFolder

local function getFloor(model)
	return model:FindFirstChild("Floor", true) or model.PrimaryPart
end

local function getFloorTop(model)
	local floor = getFloor(model)
	assert(floor and floor:IsA("BasePart"), "No floor found in map: " .. model.Name)
	return floor.Position + Vector3.new(0, floor.Size.Y / 2, 0)
end

local function moveModelToFloorTop(model, targetTop)
	local currentTop = getFloorTop(model)
	local delta = targetTop - currentTop
	model:PivotTo(model:GetPivot() + delta)
end

local function clearWorkspaceMaps()
	for _, child in ipairs(MapsFolder:GetChildren()) do
		child:Destroy()
	end
end

function MapService.Init()
	MapLibrary = ServerStorage:WaitForChild("MapLibrary")
	MapsFolder = Workspace:WaitForChild("Maps")
end

function MapService.GetMapNames()
	local results = {}

	for _, child in ipairs(MapLibrary:GetChildren()) do
		if child:IsA("Model") then
			table.insert(results, child.Name)
		end
	end

	table.sort(results)
	return results
end

function MapService.GetActiveMap()
	for _, child in ipairs(MapsFolder:GetChildren()) do
		if child:IsA("Model") then
			return child
		end
	end
	return nil
end

function MapService.LoadMap(mapName)
	assert(MapLibrary, "MapService.Init() was not called")

	local template = MapLibrary:FindFirstChild(mapName)
	assert(template and template:IsA("Model"), "Map not found in MapLibrary: " .. tostring(mapName))

	local activeAnchor = Workspace:FindFirstChild("ActiveArenaAnchor")
	assert(activeAnchor and activeAnchor:IsA("BasePart"), "Workspace.ActiveArenaAnchor missing")

	clearWorkspaceMaps()

	local clone = template:Clone()
	clone.Name = mapName
	clone.Parent = MapsFolder

	moveModelToFloorTop(clone, activeAnchor.Position)

	print("[MapService] Loaded map:", mapName)

	return clone
end

function MapService.LoadConfiguredMap()
	local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
	return MapService.LoadMap(GameConfig.MapName)
end

return MapService