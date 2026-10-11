--!nonstrict
-- Retire the old procedural harbor inside its original, explicitly owned region.
-- New maps supply their own water/scenery. Preserve terrain outside this region.
local Workspace = game:GetService("Workspace")
local anchor = Workspace:WaitForChild("ActiveArenaAnchor")
if Workspace:GetAttribute("DetailedMapsTerrainMigrated") ~= 1 then
    Workspace.Terrain:FillBlock(
        CFrame.new(anchor.Position + Vector3.new(0, -7, 0)),
        Vector3.new(466, 78, 402),
        Enum.Material.Air
    )
    Workspace:SetAttribute("SunsetV9TerrainActive", false)
    Workspace:SetAttribute("DetailedMapsTerrainMigrated", 1)
end
