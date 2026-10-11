--!nonstrict
-- ModuleScript in ServerStorage. Use from Studio's Command Bar while Play is stopped.
local Installer = {}
function Installer.Rebuild()
    assert(game:GetService("RunService"):IsStudio(), "Use this in Roblox Studio")
    assert(not game:GetService("RunService"):IsRunning(), "Stop Play before rebuilding maps")
    local storage = game:GetService("ServerStorage")
    local replicated = game:GetService("ReplicatedStorage")
    local anchor = workspace:FindFirstChild("ActiveArenaAnchor")
    local oldLibrary = storage:FindFirstChild("MapLibrary")
    local maps = workspace:FindFirstChild("Maps")
    assert(anchor and anchor:IsA("BasePart") and oldLibrary and maps, "Open your Huss A Bomb place first")
    local builderScript = storage:FindFirstChild("DetailedMapBuilder")
    assert(builderScript and builderScript:IsA("ModuleScript"), "DetailedMapBuilder is missing")
    local temporary = builderScript:Clone()
    temporary.Name, temporary.Parent = "BuildingDetailedMaps", storage
    local ok, builder = pcall(require, temporary)
    if not ok then temporary:Destroy(); error(builder) end
    local library = Instance.new("Folder")
    library.Name = "MapLibrary"
    local previews = Instance.new("Folder")
    previews.Name = "BombTagV6Previews"
    local lobby, arena, displayName
    ok, builder = pcall(function()
        local built = builder.BuildInto(library)
        assert(#built == 12, "Expected twelve completed map templates")
        for _, model in ipairs(built) do
            assert(model.PrimaryPart and model:FindFirstChild("Floor") and #model.Spawns:GetChildren() == 16,
                "Incomplete map: " .. model.Name)
            local preview = model:Clone()
            for _, object in ipairs(preview:GetDescendants()) do
                if object.Name == "Spawns" or object:IsA("LuaSourceContainer") or object:IsA("SurfaceGui")
                    or object:IsA("Light") or (object:IsA("BasePart") and object.Transparency >= 1) then
                    object:Destroy()
                end
            end
            preview.Parent = previews
        end
        lobby = builder.BuildLobby(nil)
        displayName = workspace:GetAttribute("CurrentVotedMap") or "Sky Garden"
        local template = library:FindFirstChild(displayName) or library:FindFirstChild("Sky Garden")
        displayName = template.Name
        arena = template:Clone()
        local config = require(replicated.Shared.Config.GameConfig)
        arena.Name = config.MapName
        local top = arena.Floor.Position + Vector3.new(0, arena.Floor.Size.Y / 2, 0)
        arena:PivotTo(arena:GetPivot() + (anchor.Position - top))
        arena:SetAttribute("DisplayName", displayName)
        arena:SetAttribute("VotedMap", displayName)
    end)
    temporary:Destroy()
    if not ok then
        library:Destroy(); previews:Destroy()
        if lobby then lobby:Destroy() end
        if arena then arena:Destroy() end
        error(builder)
    end
    -- Archive only after the complete replacement has been successfully built.
    local backup = Instance.new("Folder")
    local baseName = "DetailedMapsBackup_" .. tostring(os.time())
    local backupName, suffix = baseName, 1
    while storage:FindFirstChild(backupName) do
        suffix += 1
        backupName = baseName .. "_" .. tostring(suffix)
    end
    backup.Name = backupName
    backup.Parent = storage
    oldLibrary.Parent = backup
    local oldPreviews = replicated:FindFirstChild("BombTagV6Previews")
    if oldPreviews then oldPreviews.Parent = backup end
    local oldLobby = workspace:FindFirstChild("Lobby")
    if oldLobby then oldLobby.Parent = backup end
    local oldArena = Instance.new("Folder")
    oldArena.Name, oldArena.Parent = "PreviousArena", backup
    for _, model in ipairs(maps:GetChildren()) do
        if model:IsA("Model") then model.Parent = oldArena end
    end
    library.Parent, previews.Parent, lobby.Parent, arena.Parent = storage, replicated, workspace, maps
    workspace:SetAttribute("CurrentVotedMap", displayName)
    -- This is the exact region owned by the retired SunsetDocksTerrainV9 script.
    workspace.Terrain:FillBlock(CFrame.new(anchor.Position + Vector3.new(0, -7, 0)),
        Vector3.new(466, 78, 402), Enum.Material.Air)
    workspace:SetAttribute("SunsetV9TerrainActive", false)
    workspace:SetAttribute("DetailedMapsTerrainMigrated", 1)
    print("Built all 12 maps, map previews and lobby. Originals are in ServerStorage/" .. backup.Name)
    return library
end
return Installer
