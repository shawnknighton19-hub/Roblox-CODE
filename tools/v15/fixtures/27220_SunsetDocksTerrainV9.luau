--!nonstrict
local Workspace=game:GetService('Workspace')
local maps=Workspace:WaitForChild('Maps')
local Terrain=workspace.Terrain

local function sculptHarbor(origin)
    local function W(x,y,z)
        return origin+Vector3.new(x,y,z)
    end

    -- Curved water and seabed, not a giant square plane.

    for _,v in ipairs({
        {-70,10,160},
        {85,8,145},
        {0,76,112},
    }) do
        Terrain:FillCylinder(
            CFrame.new(W(v[1],-25,v[2])),
            14,v[3],Enum.Material.Sand
        )

        Terrain:FillCylinder(
            CFrame.new(W(v[1],-8,v[2])),
            18,v[3],Enum.Material.Water
        )
    end

    -- Rocky waterfront landforms.

    for _,v in ipairs({
        {-124,-111,190,70,Enum.Material.Rock},
        {106,-116,185,63,Enum.Material.Rock},
        {-161,-14,57,128,Enum.Material.Rock},
        {166,0,58,151,Enum.Material.Rock},
    }) do
        Terrain:FillBlock(
            CFrame.new(W(v[1],-8,v[2])),
            Vector3.new(v[3],19,v[4]),
            v[5]
        )
    end

    -- Irregular rock shoulders.

    for _,v in ipairs({
        {-204,-136,20},{-209,-91,23},
        {-200,-36,20},{-205,42,22},
        {-195,120,19},{207,-137,17},
        {205,-77,21},{212,-24,21},
        {210,59,19},{203,126,23},
        {-167,-152,19},{150,-153,24},
    }) do
        Terrain:FillBall(
            W(v[1],-8,v[2]),
            v[3],
            Enum.Material.Rock
        )
    end

    for _,v in ipairs({
        {-206,-105,13},{-205,37,12},
        {208,90,15},{-198,145,13},
        {191,-150,15},
    }) do
        Terrain:FillBall(
            W(v[1],-5,v[2]),
            v[3],
            Enum.Material.Ground
        )
    end
end

local function clearHarbor(origin)
    Terrain:FillBlock(
        CFrame.new(origin+Vector3.new(0,-7,0)),
        Vector3.new(466,78,402),
        Enum.Material.Air
    )
end
local painting=false
local lastSelected=false

local function refresh()
    if painting then return end
    painting=true

    local anchor=Workspace:FindFirstChild('ActiveArenaAnchor')
    local model=maps:FindFirstChildWhichIsA('Model')

    if anchor and model then
        local visual=model:GetAttribute('DisplayName') or model.Name
        local selected=(visual=='Sunset Docks')

        if selected then
            clearHarbor(anchor.Position)
            sculptHarbor(anchor.Position)

            Workspace:SetAttribute(
                'SunsetV9TerrainActive',true
            )

        elseif lastSelected
            or Workspace:GetAttribute('SunsetV9TerrainActive')==true then

            clearHarbor(anchor.Position)

            Workspace:SetAttribute(
                'SunsetV9TerrainActive',false
            )
        end

        lastSelected=selected
    end

    painting=false
end

Workspace:GetAttributeChangedSignal(
    'CurrentVotedMap'
):Connect(function()
    task.defer(refresh)
end)

maps.ChildAdded:Connect(function()
    task.defer(refresh)
end)

task.defer(refresh)
