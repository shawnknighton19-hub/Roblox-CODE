--!nonstrict
-- Original, asset-free Bomb Tag environments. All gameplay elevation has wide ramp access.
-- BuildInto(parent) is safe in Studio edit mode: it only ADDS twelve new map models.
-- It never deletes the user's map library, terrain, lobby, lighting or scripts.
local ServerStorage = game:GetService("ServerStorage")
local MapBuilder = {}
local V, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local VERSION = "BombTagDetailedWorld_3"
local WHITE, INK = RGB(229, 231, 218), RGB(37, 45, 44)
local SAGE, GOLD, ICE = RGB(162, 217, 124), RGB(239, 176, 91), RGB(140, 206, 223)
local STONE, WOOD = RGB(172, 165, 141), RGB(133, 95, 63)
local catalog = {
	{Id = "valley", Name = "Sky Garden", Subtitle = "COMPACT / ARCADE & GARDENS", Width = 156, Depth = 144,
		Description = "A warm stone courtyard with an elevated arcade, flower gardens and two generous terrace ramps.", Accent = SAGE},
	{Id = "depot", Name = "Sunset Docks", Subtitle = "MEDIUM / LOADING DECKS & OVERPASS", Width = 196, Depth = 166,
		Description = "A working freight yard with detailed warehouses, cargo cover and a connected loading-deck overpass.", Accent = GOLD},
	{Id = "frost", Name = "Frostfall Village", Subtitle = "LARGE / LODGE & WATER GARDENS", Width = 224, Depth = 180,
		Description = "An alpine lodge garden with a raised promenade, snowy planting beds and a ramped bridge between reflective ponds.", Accent = ICE},
}
local function group(parent, name, class)
	local object = Instance.new(class or "Folder")
	object.Name, object.Parent = name, parent
	return object
end
local surfaceLayer = 0
local function part(parent, name, size, position, color, material, collision, rotation, class)
	-- Separate overlapping ground decals/paving to avoid coplanar flickering.
	if collision == false and size.Y <= .2 and position.Y >= 0 and position.Y < .3 and (not rotation or rotation.UpVector.Y > .999) then
		surfaceLayer += 1
		position += V(0, surfaceLayer * .001, 0)
	end
	local object = Instance.new(class or "Part")
	object.Name, object.Size = name, size
	object.CFrame = CF(position) * (rotation or CFrame.identity)
	object.Color, object.Material = color, material or Enum.Material.SmoothPlastic
	object.Anchored, object.CanCollide, object.CanTouch = true, collision ~= false, false
	object.CanQuery = collision ~= false
	object.TopSurface, object.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	object.Parent = parent
	return object
end
local function box(parent, name, x, y, z, w, h, d, color, material, collision)
	return part(parent, name, V(w, h, d), V(x, y, z), color, material, collision)
end
local function trim(parent, name, x, y, z, w, h, d, color, material)
	return box(parent, name, x, y, z, w, h, d, color, material, false)
end
local function cylinder(parent, name, x, y, z, diameter, height, color, material, collision)
	local object = part(parent, name, V(height, diameter, diameter), V(x, y, z), color, material, collision, CFrame.Angles(0, 0, math.pi / 2))
	object.Shape = Enum.PartType.Cylinder
	return object
end
local function ball(parent, name, x, y, z, size, color, material)
	local object = trim(parent, name, x, y, z, size, size, size, color, material)
	object.Shape = Enum.PartType.Ball
	return object
end
local function beam(parent, name, a, b, width, depth, color, material, collision)
	return part(parent, name, V(width, depth, (b - a).Magnitude), (a + b) / 2, color, material, collision, CFrame.lookAt(a, b).Rotation)
end
local function footprint(entry, x, z, w, d, kind)
	table.insert(entry.Layout, {X = x / entry.Width + 0.5, Z = z / entry.Depth + 0.5,
		W = w / entry.Width, D = d / entry.Depth, Kind = kind or "cover"})
end
local function route(entry, name, x1, z1, x2, z2, width, elevation)
	table.insert(entry.Geometry.Routes, {Name = name, X1 = x1, Z1 = z1, X2 = x2, Z2 = z2, Width = width, Y = elevation or 0})
end
local function obstacle(entry, name, x, z, w, d, height)
	table.insert(entry.Geometry.Obstacles, {Name = name, X = x, Z = z, Width = w, Depth = d, Height = height})
	footprint(entry, x, z, w, d)
end
local function sign(board, title, subtitle, accent)
	local surface = Instance.new("SurfaceGui")
	surface.Name, surface.Face, surface.CanvasSize = "Sign", Enum.NormalId.Back, Vector2.new(900, 240)
	surface.LightInfluence, surface.Parent = 0.2, board
	for i, data in ipairs({{title, 34, 104, 56, WHITE}, {subtitle, 147, 50, 25, accent}}) do
		local text = Instance.new("TextLabel")
		text.Name, text.BackgroundTransparency = "Line" .. i, 1
		text.Size, text.Position = UDim2.new(1, -36, 0, data[3]), UDim2.fromOffset(18, data[2])
		text.Font, text.TextSize, text.TextColor3 = Enum.Font.GothamBold, data[4], data[5]
		text.Text, text.TextWrapped, text.Parent = data[1], true, surface
	end
end
local function rail(parent, name, a, b, color)
	local model = group(parent, name, "Model")
	beam(model, "TopRail", a + V(0, 3.2, 0), b + V(0, 3.2, 0), 0.3, 0.35, color, Enum.Material.Metal, false)
	beam(model, "MiddleRail", a + V(0, 1.7, 0), b + V(0, 1.7, 0), 0.2, 0.2, color, Enum.Material.Metal, false)
	local count = math.max(1, math.ceil((b - a).Magnitude / 7))
	for i = 0, count do
		local p = a:Lerp(b, i / count)
		box(model, "RailPost", p.X, p.Y + 1.65, p.Z, 0.4, 3.3, 0.4, color, Enum.Material.Metal, false)
	end
	local safety = beam(model, "SmoothRailCollider", a + V(0, 1.6, 0), b + V(0, 1.6, 0), 0.45, 3.2, color, nil, true)
	safety.Transparency, safety.CastShadow = 1, false
	return model
end
local function ramp(parent, entry, name, x1, z1, x2, z2, rise, width, material, color, baseY)
	baseY = baseY or 0
	local dx, dz = x2 - x1, z2 - z1
	local run = math.sqrt(dx * dx + dz * dz)
	assert(width >= 12 and math.deg(math.atan(rise / run)) <= 18, "Unsafe no-jump ramp " .. name)
	local direction = V(dx / run, 0, dz / run)
	local midpoint = V((x1 + x2) / 2, baseY + rise / 2, (z1 + z2) / 2)
	local model = group(parent, name, "Model")
	-- Roblox wedges rise toward local +Z. This gives a truly flush floor-to-deck incline.
	local wedge = part(model, "WalkableRamp", V(width, rise, run), midpoint, color, material, true,
		CFrame.lookAt(midpoint, midpoint - direction).Rotation, "WedgePart")
	wedge:SetAttribute("NoJumpRoute", true)
	wedge:SetAttribute("SlopeDegrees", math.deg(math.atan(rise / run)))
	local side = V(direction.Z, 0, -direction.X) * (width / 2 - 0.2)
	for _, s in ipairs({-1, 1}) do
		rail(model, "RampHandrail", V(x1, baseY, z1) + side * s, V(x2, baseY + rise, z2) + side * s, INK)
	end
	-- Noncolliding tread marks never introduce steps or snag a sprint/dodge.
	local tilt = CFrame.lookAt(midpoint, midpoint - direction).Rotation * CFrame.Angles(-math.atan(rise / run), 0, 0)
	for i = 1, math.floor(run / 4) - 1 do
		local t = i * 4 / run
		part(model, "FlushTractionStripe", V(width - 1.2, 0.035, 0.15), V(x1 + dx * t, baseY + rise * t + 0.03, z1 + dz * t), color:Lerp(WHITE, 0.35), material, false, tilt)
	end
	table.insert(entry.Geometry.Ramps, {Name = name, X1 = x1, Z1 = z1, X2 = x2, Z2 = z2,
		BaseY = baseY, Rise = rise, Run = run, Width = width, SlopeDegrees = math.deg(math.atan(rise / run))})
	footprint(entry, (x1 + x2) / 2, (z1 + z2) / 2, math.abs(dx) < 0.01 and width or run, math.abs(dz) < 0.01 and width or run, "ramp")
	return model
end
local function deck(parent, entry, name, x, z, w, d, elevation, hollow)
	local depth = hollow and 0.8 or elevation
	local surface = box(parent, name, x, elevation - depth / 2, z, w, depth, d, STONE, Enum.Material.Concrete)
	surface:SetAttribute("WalkableElevation", elevation)
	trim(parent, name .. "Fascia", x, elevation - 0.3, z + d / 2 + 0.05, w, 0.6, 0.12, WHITE, Enum.Material.Concrete)
	table.insert(entry.Geometry.Decks, {Name = name, X = x, Z = z, Width = w, Depth = d, Y = elevation,
		Clearance = hollow and elevation - depth or 0, AccessRoutes = 2, SolidBase = not hollow})
	footprint(entry, x, z, w, d, "terrace")
	return surface
end
local function paving(parent, name, x, z, w, d, color, material, y)
	return trim(parent, name, x, (y or 0) + 0.025, z, w, 0.05, d, color, material or Enum.Material.Concrete)
end
local function tiles(parent, x, z, w, d, step, color, y)
	y = (y or 0) + 0.06
	for dx = -w / 2 + step, w / 2 - 0.5, step do trim(parent, "PaverJoint", x + dx, y, z, 0.07, 0.025, d, color) end
	for dz = -d / 2 + step, d / 2 - 0.5, step do trim(parent, "PaverJoint", x, y, z + dz, w, 0.025, 0.07, color) end
end
local function lamp(parent, x, z, accent, height, baseY)
	height, baseY = height or 12, baseY or 0
	local model = group(parent, "Lantern", "Model")
	box(model, "Foot", x, baseY + 0.25, z, 1.6, 0.5, 1.6, INK, Enum.Material.Metal, false)
	box(model, "Post", x, baseY + height / 2, z, 0.55, height, 0.55, INK, Enum.Material.Metal, false)
	box(model, "LanternFrame", x, baseY + height - 0.2, z, 2.2, 2, 2.2, INK, Enum.Material.Metal, false)
	local glass = trim(model, "WarmGlass", x, baseY + height - 0.2, z, 1.85, 1.65, 1.85, accent, Enum.Material.Neon)
	trim(model, "LanternRoof", x, baseY + height + 1, z, 2.8, 0.35, 2.8, INK, Enum.Material.Metal)
	-- Only a restrained subset of lamps emits real lights; neon handles the rest cheaply.
	if math.floor(x + z) % 3 == 0 then
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows, light.Parent = accent, 0.7, 18, false, glass
	end
end
local function tree(parent, x, z, snowy, scale, baseY)
	scale, baseY = scale or 1, baseY or 0
	local model = group(parent, snowy and "SnowPine" or "GardenTree", "Model")
	box(model, "Trunk", x, baseY + 5 * scale, z, 1.5 * scale, 10 * scale, 1.5 * scale, WOOD, Enum.Material.Wood, false)
	if snowy then
		for level = 0, 3 do
			local width = (12 - level * 2.3) * scale
			local position = V(x, baseY + (7.4 + level * 2.8) * scale, z)
			local rotation = CFrame.Angles(0, math.rad(level * 19 + 30), 0)
			part(model, "LayeredPineBough", V(width, 3 * scale, width), position, RGB(64 + level * 4, 103 + level * 4, 91 + level * 4), Enum.Material.Grass, false, rotation)
			part(model, "PowderSnow", V(width * 0.9, 0.65 * scale, width * 0.9), position + V(0, 1.5 * scale, 0), RGB(232, 239, 231), Enum.Material.Snow, false, rotation)
		end
	else
		for i, item in ipairs({{-3, 10, 0, 8}, {3, 11, 1, 8}, {0, 14, -1, 9}, {1, 9, -3, 7}}) do
			local crown = ball(model, "LeafCluster", x + item[1] * scale, baseY + item[2] * scale, z + item[3] * scale, item[4] * scale, RGB(84 + i * 6, 119 + i * 9, 61 + i * 5), Enum.Material.Grass)
			crown.Size = V(item[4] * scale, item[4] * 0.7 * scale, item[4] * scale)
		end
	end
end
local function flowers(parent, x, z, w, d, baseY, snowy)
	for i = 1, math.max(5, math.floor(w * d / 16)) do
		local px = x + ((i * 7.13) % math.max(1, w - 2)) - (w - 2) / 2
		local pz = z + ((i * 4.77) % math.max(1, d - 2)) - (d - 2) / 2
		trim(parent, "LeafSprig", px, baseY + 0.4, pz, 0.22, 0.8, 0.22, RGB(78, 112, 60), Enum.Material.Grass)
		ball(parent, snowy and "WinterBerry" or "Flower", px, baseY + 0.8, pz, 0.65, snowy and RGB(181, 92, 86) or ({RGB(220, 168, 106), RGB(200, 128, 137), RGB(230, 220, 164)})[i % 3 + 1], Enum.Material.SmoothPlastic)
	end
end
local function planter(parent, entry, name, x, z, w, d, snowy, withTree, baseY)
	baseY = baseY or 0
	local model = group(parent, name, "Model")
	box(model, "StoneBed", x, baseY + 0.9, z, w, 1.8, d, snowy and RGB(135, 154, 158) or RGB(142, 146, 119), Enum.Material.Slate)
	trim(model, "Soil", x, baseY + 1.84, z, w - 0.8, 0.12, d - 0.8, snowy and RGB(233, 239, 231) or RGB(92, 102, 57), snowy and Enum.Material.Snow or Enum.Material.Grass)
	for _, s in ipairs({-1, 1}) do
		trim(model, "Coping", x + s * (w / 2 - 0.2), baseY + 1.9, z, 0.4, 0.3, d, WHITE, Enum.Material.Concrete)
		trim(model, "Coping", x, baseY + 1.9, z + s * (d / 2 - 0.2), w, 0.3, 0.4, WHITE, Enum.Material.Concrete)
	end
	flowers(model, x, z, w, d, baseY + 1.8, snowy)
	if withTree then tree(model, x, z, snowy, 0.85, baseY + 1.8) end
	if entry then obstacle(entry, name, x, z, w, d, baseY + 1.8) end
end
local function bench(parent, x, z, yaw, baseY)
	baseY = baseY or 0
	local model = group(parent, "ParkBench", "Model")
	local pivot = CF(x, baseY, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	local function p(name, size, position, color, material)
		return part(model, name, size, (pivot * CF(position)).Position, color, material, false, pivot.Rotation)
	end
	for i = -1, 1 do p("SeatSlat", V(8, 0.3, 0.68), V(0, 2, i * 0.8), WOOD, Enum.Material.WoodPlanks) end
	for i = 0, 2 do p("BackSlat", V(8, 0.5, 0.3), V(0, 2.8 + i * 0.65, -1), WOOD, Enum.Material.WoodPlanks) end
	for _, s in ipairs({-1, 1}) do
		p("IronLeg", V(0.45, 2, 2.3), V(s * 2.8, 1, 0), INK, Enum.Material.Metal)
		p("IronBack", V(0.3, 3.8, 0.3), V(s * 2.8, 1.9, -1), INK, Enum.Material.Metal)
	end
end
local function wall(parent, name, x, z, w, d, h, color)
	box(parent, name, x, h / 2, z, w, h, d, color, Enum.Material.Brick)
	trim(parent, "WallPlinth", x, 0.45, z, w + 0.3, 0.9, d + 0.3, color:Lerp(INK, 0.15), Enum.Material.Concrete)
	trim(parent, "WallCoping", x, h, z, w + 0.4, 0.35, d + 0.4, WHITE, Enum.Material.Concrete)
end
local function boundaries(parent, entry, color)
	local model = group(parent, "PerimeterArchitecture")
	local hx, hz = entry.Width / 2 + 1, entry.Depth / 2 + 1
	wall(model, "NorthWall", 0, -hz, entry.Width + 4, 2, 7, color)
	wall(model, "SouthWall", 0, hz, entry.Width + 4, 2, 7, color)
	wall(model, "WestWall", -hx, 0, 2, entry.Depth + 4, 7, color)
	wall(model, "EastWall", hx, 0, 2, entry.Depth + 4, 7, color)
	for _, side in ipairs({-1, 1}) do
		for x = -hx + 7, hx - 6, 22 do
			box(model, "MasonryPier", x, 4.3, side * hz, 2.6, 8.6, 3, color:Lerp(WHITE, 0.1), Enum.Material.Concrete)
			trim(model, "PierCap", x, 8.6, side * hz, 3.2, 0.4, 3.6, WHITE)
		end
		for z = -hz + 11, hz - 10, 22 do
			box(model, "MasonryPier", side * hx, 4.3, z, 3, 8.6, 2.6, color:Lerp(WHITE, 0.1), Enum.Material.Concrete)
		end
	end
	for _, info in ipairs({{0, -hz, entry.Width + 4, 2}, {0, hz, entry.Width + 4, 2}, {-hx, 0, 2, entry.Depth + 4}, {hx, 0, 2, entry.Depth + 4}}) do
		local blocker = box(model, "InvisibleSafetyBoundary", info[1], 48, info[2], info[3], 96, info[4], color)
		blocker.Transparency, blocker.CastShadow = 1, false
	end
end
local function ground(model, entry, color, material)
	local floor = box(model, "Floor", 0, -2, 0, entry.Width, 4, entry.Depth, color, material)
	model.PrimaryPart = floor
	entry.Geometry.Floor = {Width = entry.Width, Depth = entry.Depth, Y = 0}
	return floor
end
local function spawns(model, entry, positions)
	assert(#positions == 16, "Every map requires sixteen safe spawn positions")
	local folder = group(model, "Spawns")
	for i, data in ipairs(positions) do
		local position = V(data[1], 0.25, data[2])
		local marker = part(folder, string.format("Spawn%02d", i), V(4, 0.2, 4), position, WHITE, nil, false)
		marker.CFrame, marker.Transparency, marker.CastShadow = CFrame.lookAt(position, V(0, 0.25, 0)), 1, false
		table.insert(entry.Geometry.Spawns, {Name = marker.Name, X = data[1], Z = data[2], Y = 0.25})
	end
end
local function window(parent, x, y, z, w, h, accent)
	trim(parent, "WindowFrame", x, y, z, w, h, 0.28, INK, Enum.Material.Metal)
	trim(parent, "WindowGlass", x, y, z + 0.18, w - 0.55, h - 0.55, 0.1, accent, Enum.Material.Glass)
	trim(parent, "WindowMullion", x, y, z + 0.26, 0.18, h, 0.14, WHITE)
	trim(parent, "WindowTransom", x, y, z + 0.26, w, 0.18, 0.14, WHITE)
	trim(parent, "WindowSill", x, y - h / 2, z + 0.1, w + 0.7, 0.35, 0.65, STONE)
end
local function kiosk(parent, x, z, labelText)
	local model = group(parent, "GardenKiosk", "Model")
	box(model, "KioskBody", x, 5.5, z, 14, 11, 14, RGB(197, 185, 153), Enum.Material.Brick)
	trim(model, "FoundationBand", x, 0.5, z, 14.6, 1, 14.6, STONE, Enum.Material.Concrete)
	trim(model, "RoofCornice", x, 11.2, z, 16, 0.65, 16, WHITE, Enum.Material.Concrete)
	trim(model, "GreenRoof", x, 11.8, z, 16.6, 0.55, 16.6, RGB(89, 121, 97), Enum.Material.Metal)
	for _, dx in ipairs({-5.8, 5.8}) do trim(model, "FacadeColumn", x + dx, 5.5, z + 7.1, 0.7, 10, 0.35, WHITE) end
	window(model, x, 5.4, z + 7.12, 9, 5, RGB(141, 181, 168))
	local board = trim(model, "KioskSign", x, 9.8, z + 7.25, 11, 1.9, 0.3, INK)
	sign(board, labelText, "SKY GARDEN", SAGE)
end

local function valley(model, entry)
	ground(model, entry, RGB(124, 148, 87), Enum.Material.Grass)
	local architecture, landscape, details = group(model, "ArcadeAndTerrace"), group(model, "CourtyardGardens"), group(model, "SmallDetails")
	paving(landscape, "MainSquare", 0, 16, 102, 82, RGB(183, 175, 147), Enum.Material.Cobblestone)
	paving(landscape, "NorthApproach", 0, -27, 38, 34, RGB(194, 186, 162))
	paving(landscape, "WestPromenade", -64, -4, 20, 126, RGB(185, 178, 152))
	paving(landscape, "EastPromenade", 64, -4, 20, 126, RGB(185, 178, 152))
	paving(landscape, "SouthPromenade", 0, 60, 144, 18, RGB(185, 178, 152))
	tiles(details, 0, 17, 100, 76, 8, RGB(149, 145, 124))
	deck(architecture, entry, "ArcadeTerrace", 0, -49, 108, 26, 6, false)
	paving(architecture, "TerraceFlagstones", 0, -49, 107, 25, RGB(193, 185, 160), nil, 6)
	tiles(architecture, 0, -49, 106, 24, 6, RGB(158, 153, 132), 6)
	ramp(architecture, entry, "WestTerraceRamp", -45, -12, -45, -36, 6, 16, Enum.Material.Concrete, STONE)
	ramp(architecture, entry, "EastTerraceRamp", 45, -12, 45, -36, 6, 16, Enum.Material.Concrete, STONE)
	rail(architecture, "TerraceFrontBalustrade", V(-35, 6, -36), V(35, 6, -36), INK)
	for _, s in ipairs({-1, 1}) do rail(architecture, "TerraceSideBalustrade", V(s * 54, 6, -36), V(s * 54, 6, -62), INK) end
	box(architecture, "ArcadeBackWall", 0, 11.5, -61, 108, 11, 2, RGB(186, 172, 143), Enum.Material.Brick)
	trim(architecture, "ArcadeRoof", 0, 17.5, -54, 112, 1, 18, RGB(114, 137, 108), Enum.Material.Slate)
	trim(architecture, "ArcadeCornice", 0, 16.85, -44.8, 111, 0.6, 0.5, WHITE)
	for _, x in ipairs({-51, -27, -3, 21, 51}) do
		box(architecture, "ArcadeColumn", x, 11.4, -46, 1.8, 10.8, 1.8, STONE, Enum.Material.Concrete)
		trim(architecture, "ColumnBase", x, 6.3, -46, 2.6, 0.6, 2.6, WHITE)
		trim(architecture, "ColumnCapital", x, 16.35, -46, 2.8, 0.55, 2.8, WHITE)
	end
	for _, x in ipairs({-39, -15, 9, 36}) do
		window(architecture, x, 11.6, -59.8, 12, 6, RGB(124, 159, 143))
		trim(architecture, "ArcadeLintel", x, 15.5, -45.8, 21, 1.3, 1.7, STONE)
	end
	for _, x in ipairs({-39, 39}) do bench(details, x, -56, 0, 6) end
	local fountain = group(landscape, "CourtyardFountain", "Model")
	cylinder(fountain, "StoneBasin", 0, 0.85, 9, 18, 1.7, STONE, Enum.Material.Slate)
	cylinder(fountain, "BasinWater", 0, 1.74, 9, 15.4, 0.1, RGB(114, 178, 168), Enum.Material.Glass, false)
	cylinder(fountain, "CenterPedestal", 0, 2.7, 9, 3.8, 3, RGB(200, 197, 172), Enum.Material.Concrete, false)
	cylinder(fountain, "UpperBowl", 0, 4.35, 9, 8, 0.7, STONE, Enum.Material.Slate, false)
	cylinder(fountain, "UpperWater", 0, 4.72, 9, 6.8, 0.08, RGB(140, 197, 179), Enum.Material.Glass, false)
	ball(fountain, "FountainFinial", 0, 5.8, 9, 1.6, WHITE)
	obstacle(entry, "Fountain", 0, 9, 18, 18, 2)
	for _, x in ipairs({-38, 38}) do
		planter(landscape, entry, "FlowerCourt", x, 31, 15, 14, false, true)
		bench(details, x, 44, 0)
		lamp(details, x, 19, RGB(247, 223, 168), 11)
	end
	for _, s in ipairs({-1, 1}) do
		kiosk(architecture, s * 65, 8, s == -1 and "GARDEN CAFE" or "BOTANICALS")
		obstacle(entry, "GardenKiosk", s * 65, 8, 14, 14, 11)
		planter(landscape, entry, "CornerFlowerBed", s * 65, 54, 13, 10, false, true)
		lamp(details, s * 69, -34, RGB(247, 223, 168), 11)
		planter(landscape, entry, "TerraceRearGarden", s * 35, -68, 15, 5, false, false)
	end
	for _, x in ipairs({-20, 20}) do planter(landscape, entry, "EntryFlowerBed", x, -18, 8, 10, false, false) end
	boundaries(model, entry, RGB(133, 145, 115))
	route(entry, "WestCourtLoop", -20, -7, -20, 54, 18)
	route(entry, "EastCourtLoop", 20, -7, 20, 54, 18)
	route(entry, "SouthCrossing", -57, 59, 57, 59, 18)
	route(entry, "ArcadeUpperLoop", -45, -40, 45, -40, 8, 6)
	spawns(model, entry, {{-65,-22},{65,-22},{-65,35},{65,35},{-26,59},{0,59},{26,59},{-46,59},{46,59},{-65,-57},{65,-57},{-22,7},{22,7},{-18,35},{18,35},{0,-18}})
end

local function container(parent, entry, x, z, color, number)
	local model = group(parent, "FreightContainer" .. number, "Model")
	box(model, "CargoShell", x, 4.5, z, 15, 9, 25, color, Enum.Material.Metal)
	for _, s in ipairs({-1, 1}) do
		for offset = -11, 11, 2.75 do trim(model, "CorrugatedSide", x + s * 7.55, 4.5, z + offset, 0.18, 8.4, 0.42, color:Lerp(INK, 0.17), Enum.Material.Metal) end
		trim(model, "UpperCornerRail", x + s * 7.3, 9.1, z, 0.4, 0.25, 25.2, WHITE, Enum.Material.Metal)
		trim(model, "CargoDoor", x + s * 3.65, 4.5, z + 12.55, 7.1, 8.4, 0.18, color:Lerp(INK, 0.18), Enum.Material.Metal)
		trim(model, "LockingBar", x + s * 4.5, 4.5, z + 12.7, 0.16, 7.9, 0.15, WHITE, Enum.Material.Metal)
		for y = 1.5, 7.5, 3 do trim(model, "DoorHinge", x + s * 6.85, y, z + 12.7, 0.55, 0.3, 0.2, WHITE) end
	end
	local board = trim(model, "ContainerBadge", x, 6.8, z + 12.8, 4.5, 1.8, 0.15, INK)
	sign(board, "BT " .. number, "FREIGHT", GOLD)
	obstacle(entry, "CargoContainer", x, z, 15, 25, 9)
end
local function crate(parent, entry, x, z, w, d, h)
	local model = group(parent, "BandedCargoCrate", "Model")
	box(model, "CrateBody", x, h / 2, z, w, h, d, RGB(159, 121, 77), Enum.Material.WoodPlanks)
	for _, s in ipairs({-1, 1}) do
		trim(model, "SteelBand", x + s * w * 0.31, h / 2, z + d / 2 + 0.05, 0.35, h, 0.12, INK, Enum.Material.Metal)
		trim(model, "SteelBandTop", x + s * w * 0.31, h + 0.05, z, 0.35, 0.12, d, INK, Enum.Material.Metal)
	end
	for y = 0.25, h - 0.2, math.max(1, h - 0.5) do trim(model, "CrateFrame", x, y, z + d / 2 + 0.1, w, 0.45, 0.2, RGB(187, 149, 95), Enum.Material.Wood) end
	obstacle(entry, "CargoCrate", x, z, w, d, h)
end
local function depot(model, entry)
	ground(model, entry, RGB(112, 110, 100), Enum.Material.Concrete)
	local architecture, cargo, details = group(model, "LoadingComplex"), group(model, "FreightYard"), group(model, "DepotDetails")
	paving(details, "CentralAsphalt", 0, 17, 90, 126, RGB(74, 81, 80), Enum.Material.Asphalt)
	paving(details, "WestAsphaltLane", -84, 0, 21, 154, RGB(82, 88, 84), Enum.Material.Asphalt)
	paving(details, "EastAsphaltLane", 84, 0, 21, 154, RGB(82, 88, 84), Enum.Material.Asphalt)
	for _, s in ipairs({-1, 1}) do
		for z = -62, 65, 13 do trim(details, "RoadDash", s * 41, 0.09, z, 0.35, 0.04, 5, RGB(218, 183, 110)) end
	end
	box(architecture, "WarehouseBody", 0, 12, -68.5, 148, 24, 19, RGB(120, 124, 116), Enum.Material.Brick)
	trim(architecture, "WarehouseFoundation", 0, 1, -58.8, 148, 2, 0.4, RGB(165, 156, 130), Enum.Material.Concrete)
	trim(architecture, "WarehouseRoof", 0, 24.4, -68.5, 152, 0.8, 22, RGB(77, 91, 90), Enum.Material.Metal)
	trim(architecture, "WarehouseGutter", 0, 24, -57.4, 152, 0.5, 0.6, INK, Enum.Material.Metal)
	for x = -70, 70, 14 do
		trim(architecture, "WarehousePilaster", x, 12, -58.8, 1.1, 24, 0.55, RGB(159, 153, 133), Enum.Material.Concrete)
		window(architecture, x + 5.9, 19.7, -58.7, 8.5, 5, RGB(137, 173, 170))
	end
	for _, x in ipairs({-48, 0, 48}) do
		trim(architecture, "RollerDoorFrame", x, 7.8, -58.5, 25, 15.6, 0.6, INK, Enum.Material.Metal)
		trim(architecture, "RollerDoor", x, 7.5, -58.1, 22.6, 14.7, 0.3, RGB(153, 163, 149), Enum.Material.Metal)
		for y = 1, 14, 1.3 do trim(architecture, "RollerDoorSlat", x, y, -57.9, 22.6, 0.14, 0.2, RGB(103, 115, 105), Enum.Material.Metal) end
		for _, s in ipairs({-1, 1}) do trim(architecture, "LoadingBumper", x + s * 11.2, 1.2, -57.6, 1, 2.4, 0.8, INK) end
	end
	local warehouseSign = trim(architecture, "WarehouseSign", 0, 27, -57.6, 62, 5, 0.8, INK, Enum.Material.Metal)
	sign(warehouseSign, "SUNSET DOCKS", "FREIGHT TERMINAL / BAY 04", GOLD)
	obstacle(entry, "Warehouse", 0, -68.5, 148, 19, 24)
	for _, s in ipairs({-1, 1}) do
		deck(architecture, entry, s == -1 and "WestLoadingDeck" or "EastLoadingDeck", s * 57, -26, 30, 48, 8, false)
		paving(architecture, "LoadingDeckSurface", s * 57, -26, 29.5, 47.5, RGB(150, 148, 126), nil, 8)
		ramp(architecture, entry, s == -1 and "WestLoadingRamp" or "EastLoadingRamp", s * 57, 30, s * 57, -2, 8, 18, Enum.Material.Concrete, RGB(158, 157, 138))
		rail(architecture, "OuterLoadingRail", V(s * 72, 8, -50), V(s * 72, 8, -2), INK)
		rail(architecture, "RearLoadingRail", V(s * 42, 8, -50), V(s * 72, 8, -50), INK)
		rail(architecture, "InnerLoadingRailFront", V(s * 42, 8, -27), V(s * 42, 8, -2), INK)
		rail(architecture, "InnerLoadingRailRear", V(s * 42, 8, -50), V(s * 42, 8, -45), INK)
		trim(architecture, "LoadingCanopy", s * 57, 17.4, -39, 32, 0.6, 24, RGB(77, 99, 96), Enum.Material.Metal)
		for _, dx in ipairs({-13, 13}) do box(architecture, "CanopySupport", s * 57 + dx, 12.5, -48, 0.8, 9, 0.8, INK, Enum.Material.Metal) end
		for _, z in ipairs({-45, -33}) do trim(architecture, "CanopyCrossbeam", s * 57, 16.9, z, 30, 0.45, 0.6, INK, Enum.Material.Metal) end
		container(cargo, entry, s * 20, 26, s == -1 and RGB(160, 94, 67) or RGB(101, 133, 128), s == -1 and "21" or "08")
		crate(cargo, entry, s * 62, 61, 14, 12, 5)
		lamp(details, s * 92, -44, RGB(255, 212, 145), 17)
		lamp(details, s * 91, 46, RGB(255, 212, 145), 17)
		for z = -20, 15, 7 do trim(details, "DrainGrate", s * 90, 0.08, z, 4, 0.05, 1.7, INK, Enum.Material.Metal) end
	end
	deck(architecture, entry, "FreightOverpass", 0, -36, 84, 18, 8, true)
	paving(architecture, "OverpassTread", 0, -36, 84, 17.5, RGB(154, 157, 139), Enum.Material.DiamondPlate, 8)
	for _, z in ipairs({-45, -27}) do
		rail(architecture, "OverpassRail", V(-42, 8, z), V(42, 8, z), INK)
		trim(architecture, "OverpassIBeam", 0, 7.35, z, 84, 0.3, 0.65, INK, Enum.Material.Metal)
	end
	for _, x in ipairs({-35, 35}) do
		for _, z in ipairs({-43, -29}) do box(architecture, "BridgeSupport", x, 3.6, z, 1.2, 7.2, 1.2, INK, Enum.Material.Metal) end
	end
	for z = -18, 65, 14 do trim(details, "CenterLaneMark", 0, 0.1, z, 0.45, 0.05, 5.5, GOLD) end
	crate(cargo, entry, 0, 65, 16, 9, 4.5)
	boundaries(model, entry, RGB(128, 121, 105))
	route(entry, "CentralSprintLane", 0, -51, 0, 52, 24)
	route(entry, "WestOuterLane", -84, -65, -84, 66, 20)
	route(entry, "EastOuterLane", 84, -65, 84, 66, 20)
	route(entry, "DeckToDeckRoute", -57, -36, 57, -36, 16, 8)
	spawns(model, entry, {{-84,-62},{-84,-29},{-84,3},{-84,35},{-84,66},{84,-62},{84,-29},{84,3},{84,35},{84,66},{-34,64},{34,64},{-24,-52},{0,-52},{24,-52},{0,5}})
end

local function lodge(parent)
	local model = group(parent, "AlpineLodge", "Model")
	box(model, "LodgeBody", 0, 14, -61, 66, 14, 18, RGB(153, 132, 104), Enum.Material.WoodPlanks)
	trim(model, "StoneFooting", 0, 8.2, -51.8, 67, 2.4, 0.5, RGB(148, 159, 150), Enum.Material.Slate)
	for _, x in ipairs({-31, -15, 15, 31}) do trim(model, "TimberUpright", x, 14, -51.7, 1, 14, 0.7, RGB(93, 83, 66), Enum.Material.Wood) end
	for y = 10, 19, 4.5 do trim(model, "TimberCrossbeam", 0, y, -51.6, 66, 0.8, 0.8, RGB(93, 83, 66), Enum.Material.Wood) end
	for _, x in ipairs({-23, 23}) do window(model, x, 15, -51.2, 11, 6, RGB(201, 183, 131)) end
	trim(model, "DoorFrame", 0, 12, -51.3, 12, 10, 0.6, INK)
	trim(model, "DoubleDoor", 0, 11.6, -50.9, 10.6, 9.2, 0.3, RGB(95, 125, 111), Enum.Material.Wood)
	for _, s in ipairs({-1, 1}) do trim(model, "BrassHandle", s * 0.65, 11.5, -50.6, 0.15, 1.5, 0.25, GOLD, Enum.Material.Metal) end
	-- Roof is scenery: no inaccessible gameplay platform or false jump route.
	for _, s in ipairs({-1, 1}) do
		local slope = CFrame.Angles(math.rad(s * 19), 0, 0)
		part(model, "SlopingRoof", V(72, 0.7, 12.1), V(0, 22.6, -61 + s * 5.5), RGB(85, 108, 102), Enum.Material.Slate, false, slope)
		part(model, "RoofSnow", V(71.8, 0.28, 12), V(0, 23.03, -61 + s * 5.5), RGB(231, 238, 230), Enum.Material.Snow, false, slope)
	end
	trim(model, "RoofRidge", 0, 24.8, -61, 73, 0.7, 0.7, WHITE)
	trim(model, "Chimney", 22, 24.5, -64, 4.5, 11, 4.5, RGB(147, 147, 134), Enum.Material.Brick)
	trim(model, "ChimneyCap", 22, 30, -64, 5.5, 0.6, 5.5, WHITE)
	local board = trim(model, "LodgeName", 0, 19.3, -50.8, 29, 3, 0.5, INK)
	sign(board, "FROSTFALL LODGE", "EST. 1986 / GARDEN PROMENADE", ICE)
end
local function pond(parent, entry, x, z)
	local model = group(parent, "ReflectingPond", "Model")
	-- A single solid footprint prevents no-jump players entering an inescapable basin.
	local core = box(model, "SealedPondFootprint", x, 0.7, z, 42, 1.4, 30, RGB(124, 158, 160), Enum.Material.Slate)
	trim(model, "ReflectiveWater", x, 1.43, z, 40.2, 0.12, 28.2, RGB(116, 170, 175), Enum.Material.Glass)
	for _, s in ipairs({-1, 1}) do
		trim(model, "PondCoping", x + s * 20.6, 1.55, z, 0.8, 0.5, 30, WHITE, Enum.Material.Concrete)
		trim(model, "PondCoping", x, 1.55, z + s * 14.6, 42, 0.5, 0.8, WHITE, Enum.Material.Concrete)
	end
	for i = 1, 6 do
		local px, pz = x + (i * 5.7 % 29) - 14.5, z + (i * 4.6 % 17) - 8.5
		cylinder(model, "IceLily", px, 1.55, pz, 1.7, 0.05, RGB(166, 190, 162), Enum.Material.Grass, false)
	end
	obstacle(entry, "WaterGarden", x, z, 42, 30, 1.8)
end
local function frost(model, entry)
	ground(model, entry, RGB(211, 223, 210), Enum.Material.Snow)
	local architecture, garden, details = group(model, "LodgePromenade"), group(model, "WaterGardens"), group(model, "AlpineDetails")
	paving(garden, "MainGardenWalk", 0, -5, 190, 22, RGB(163, 183, 181), Enum.Material.Cobblestone)
	paving(garden, "WestGardenWalk", -83, 9, 25, 144, RGB(163, 183, 181), Enum.Material.Cobblestone)
	paving(garden, "EastGardenWalk", 83, 9, 25, 144, RGB(163, 183, 181), Enum.Material.Cobblestone)
	paving(garden, "SouthGardenWalk", 0, 70, 190, 22, RGB(163, 183, 181), Enum.Material.Cobblestone)
	paving(garden, "CentralBridgeApproach", 0, 24, 28, 104, RGB(172, 190, 185), Enum.Material.Concrete)
	tiles(details, 0, 70, 185, 20, 7, RGB(142, 163, 159))
	deck(architecture, entry, "LodgePromenade", 0, -55, 132, 30, 7, false)
	paving(architecture, "PromenadePaving", 0, -55, 131, 29, RGB(179, 195, 189), Enum.Material.Cobblestone, 7)
	lodge(architecture)
	for _, s in ipairs({-1, 1}) do
		ramp(architecture, entry, s == -1 and "WestLodgeRamp" or "EastLodgeRamp", s * 57, -10, s * 57, -40, 7, 16, Enum.Material.Concrete, RGB(166, 184, 177))
		rail(architecture, "PromenadeSideRail", V(s * 66, 7, -70), V(s * 66, 7, -40), INK)
		bench(details, s * 43, -59, s == -1 and -90 or 90, 7)
		lamp(details, s * 46, -48, RGB(250, 218, 156), 9, 7)
		pond(garden, entry, s * 36, 24)
		planter(garden, entry, "PineGardenNorth", s * 86, -51, 15, 15, true, true)
		planter(garden, entry, "PineGardenSouth", s * 84, 51, 15, 15, true, true)
		planter(garden, entry, "LodgeSidePines", s * 39, -80, 18, 9, true, true)
		planter(garden, entry, "WinterFlowerBank", s * 41, 52, 20, 6, true, false)
		bench(details, s * 62, 43, s == -1 and -90 or 90)
		lamp(details, s * 68, -6, RGB(242, 220, 168), 12)
		lamp(details, s * 61, 68, RGB(242, 220, 168), 12)
	end
	rail(architecture, "PromenadeFrontRail", V(-47, 7, -40), V(47, 7, -40), INK)
	deck(architecture, entry, "GardenBridge", 0, 24, 24, 40, 4, false)
	paving(architecture, "BridgeTimbers", 0, 24, 23.6, 40, RGB(153, 134, 104), Enum.Material.WoodPlanks, 4)
	ramp(architecture, entry, "NorthGardenBridgeRamp", 0, -12, 0, 4, 4, 24, Enum.Material.WoodPlanks, RGB(151, 134, 108))
	ramp(architecture, entry, "SouthGardenBridgeRamp", 0, 60, 0, 44, 4, 24, Enum.Material.WoodPlanks, RGB(151, 134, 108))
	for _, s in ipairs({-1, 1}) do
		rail(architecture, "GardenBridgeRail", V(s * 12, 4, 4), V(s * 12, 4, 44), INK)
		trim(architecture, "BridgeFascia", s * 12.1, 2.3, 24, 0.25, 2.5, 40, RGB(121, 125, 111), Enum.Material.Wood)
	end
	for z = 6, 42, 3 do trim(architecture, "BridgePlankJoint", 0, 4.09, z, 23.5, 0.04, 0.09, INK) end
	-- Framed, snowy garden pergolas sit beside clear outer routes, never across a ramp landing.
	for _, s in ipairs({-1, 1}) do
		local x = s * 95
		for _, z in ipairs({-13, 13}) do box(details, "PergolaColumn", x, 5.4, z, 1.1, 10.8, 1.1, RGB(116, 134, 122), Enum.Material.Wood) end
		trim(details, "PergolaBeam", x, 10.8, 0, 1.6, 0.7, 29, RGB(116, 134, 122), Enum.Material.Wood)
		for z = -12, 12, 4 do trim(details, "PergolaRafter", x, 11.25, z, 9, 0.5, 0.7, RGB(129, 146, 132), Enum.Material.Wood) end
	end
	boundaries(model, entry, RGB(144, 163, 156))
	route(entry, "WestGardenCircuit", -70, -28, -70, 70, 18)
	route(entry, "EastGardenCircuit", 70, -28, 70, 70, 18)
	route(entry, "SouthGardenCircuit", -95, 70, 95, 70, 20)
	route(entry, "BridgeCrossing", 0, -12, 0, 60, 23)
	route(entry, "LodgeUpperWalk", -57, -47, 57, -47, 7, 7)
	spawns(model, entry, {{-100,-72},{-100,-34},{-100,3},{-100,38},{-100,71},{100,-72},{100,-34},{100,3},{100,38},{100,71},{-35,72},{0,74},{35,72},{-24,-25},{0,-28},{24,-25}})
end


local folder, disk, surfaceText = group, cylinder, sign
-- Crystal Cavern, Emerald Ruins and Ember Keep.
-- Insertion fragment: shared builder supplies folder, box, part, V, CF, RGB,
-- and the navigation-aware deck/ramp helpers. All decoration is deterministic.

local function mineralCluster(parent, x, z, scale, color, rotation)
	local stone = RGB(66, 72, 88)
	for index, item in ipairs({{-3, 0, 3.4, 8}, {2.4, 1, 2.6, 11}, {0, -2.5, 2.7, 6}, {3.5, -2, 1.8, 5}}) do
		local height = item[4] * scale
		local crystal = part(parent, "QuartzCrystal", V(item[3] * scale, height, item[3] * scale),
			V(x + item[1] * scale, height / 2 + .55, z + item[2] * scale),
			color:Lerp(RGB(227, 241, 255), index * .09), Enum.Material.Glass, false,
			CFrame.Angles(math.rad(index == 2 and -12 or 8), math.rad((rotation or 0) + index * 32), math.rad(index == 1 and 17 or -9)))
		crystal.Transparency = .14
		box(parent, "CrystalCore", x + item[1] * scale, height * .47 + .55, z + item[2] * scale,
			item[3] * scale * .38, height * .74, item[3] * scale * .38, color, Enum.Material.Neon, false)
	end
	part(parent, "MineralBed", V(11 * scale, 1.4, 9 * scale), V(x, .7, z), stone, Enum.Material.Slate, true,
		CFrame.Angles(0, math.rad(rotation or 0), 0))
end

local function ruinColumn(parent, x, z, bottom, height, color, moss)
	box(parent, "ColumnFoot", x, bottom + .65, z, 5.2, 1.3, 5.2, color:Lerp(RGB(48, 63, 55), .16), Enum.Material.Slate)
	box(parent, "ColumnShaft", x, bottom + height / 2, z, 3.4, height, 3.4, color, Enum.Material.Limestone)
	box(parent, "ColumnCapital", x, bottom + height - .55, z, 5.8, 1.1, 5.8, color:Lerp(RGB(225, 219, 188), .2), Enum.Material.Limestone)
	for level = 1, math.floor(height / 4) do
		box(parent, "ColumnJoint", x, bottom + level * 3.1, z, 3.48, .12, 3.48, color:Lerp(RGB(31, 48, 38), .2), Enum.Material.Slate, false)
	end
	if moss then
		box(parent, "MossOnCapital", x - .4, bottom + height + .045, z, 4.6, .08, 4.9, moss, Enum.Material.Grass, false)
		box(parent, "TrailingMoss", x - 1.75, bottom + height - 1.4, z + .8, .1, 2.8, 1.3, moss, Enum.Material.Grass, false)
	end
end

local function stoneTile(parent, name, x, z, w, d, color, angle)
	return part(parent, name, V(w, .12, d), V(x, .065, z), color, Enum.Material.Slate, false,
		CFrame.Angles(0, math.rad(angle or 0), 0))
end

local function castleTorch(parent, x, z, y)
	box(parent, "TorchMount", x, y, z, 2.3, 1, 2.3, RGB(51, 45, 42), Enum.Material.Metal, false)
	box(parent, "BrazierBowl", x, y + .65, z, 3, .45, 3, RGB(86, 68, 47), Enum.Material.Metal, false)
	local flame = part(parent, "AmberEmber", V(1.5, 2.4, 1.5), V(x, y + 1.65, z), RGB(255, 162, 67),
		Enum.Material.Neon, false, CFrame.Angles(0, math.rad(45), math.rad(8)))
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = RGB(255, 184, 103), 15, .45, false
	light.Parent = flame
end

-- Helpers deliberately leave the walking faces untrimmed. The slope meets y=0
-- and the deck exactly; shallow cosmetic seams never become collision steps.
local function cavern(model, entry)
	local rock, slate, quartz = RGB(55, 62, 78), RGB(91, 107, 121), RGB(106, 192, 231)
	local p = folder(model, "CrystalGeology")
	local architecture = folder(model, "ExcavationGallery")
	local w, d = 184, 164
	-- A pale, uninterrupted cross and outer circuit read clearly against basalt.
	box(p, "BasaltCourt", 0, -.12, 0, w - 4, .2, d - 4, RGB(71, 80, 91), Enum.Material.Slate, false)
	stoneTile(p, "CentralMineralRoute", 0, 0, 26, 156, slate)
	stoneTile(p, "LateralMineralRoute", 0, 21, 174, 24, slate)
	for _, x in ipairs({-67, 67}) do stoneTile(p, "OuterCircuit", x, 0, 18, 147, slate:Lerp(rock, .18)) end
	for _, z in ipairs({-64, 63}) do stoneTile(p, "OuterCircuit", 0, z, 150, 16, slate:Lerp(rock, .18)) end
	for index = 1, 16 do
		local z = -69 + index * 8.6
		stoneTile(p, "RouteJoint", 0, z, 24, .12, rock)
	end
	-- High rock faces stay at the perimeter, leaving every spawn open to sky.
	for index = 0, 8 do
		local x = -80 + index * 20
		for _, side in ipairs({-1, 1}) do
			local height = 13 + ((index * 7 + (side + 1) * 3) % 13)
			part(p, "CavernWallMass", V(22, height, 9), V(x, height / 2 - .4, side * 79),
				rock:Lerp(slate, (index % 3) * .12), Enum.Material.Rock, true, CFrame.Angles(0, math.rad((index % 3 - 1) * 4), 0))
			part(p, "WallRockFacet", V(13, height * .52, 5), V(x - 2, height * .36, side * 74.9),
				rock:Lerp(RGB(122, 130, 146), .22), Enum.Material.Slate, false, CFrame.Angles(0, math.rad(side * 8), math.rad(index % 2 == 0 and 7 or -6)))
			box(p, "QuartzVein", x + 2, height * .55, side * 74.7, .32, height * .65, .16, quartz, Enum.Material.Neon, false)
			box(p, "BasaltWallFoot", x, 1.5, side * 76, 17, 3, 8, rock, Enum.Material.Rock, false)
		end
	end
	for index = 0, 6 do
		for _, side in ipairs({-1, 1}) do
			local z = -60 + index * 20
			local height = 16 + (index * 3 % 9)
			part(p, "SideCliff", V(9, height, 22), V(side * 89, height / 2, z), rock,
				Enum.Material.Rock, true, CFrame.Angles(0, math.rad((index % 2) * 5), 0))
			box(p, "SideCliffSeam", side * 84.4, height * .48, z - 3, .12, height * .6, .3, quartz:Lerp(slate, .4), Enum.Material.Neon, false)
			box(p, "SideRockLedge", side * 87, 4.5, z + 2, 7, 2, 14, slate, Enum.Material.Rock, false)
		end
	end
	-- A single north gallery has two independent, gentle approach ramps.
	deck(architecture, entry, "CrystalGalleryDeck", 0, -36, 110, 22, 8, true).Color = slate
	ramp(architecture, entry, "WestGalleryRamp", -46, 13, -46, -25, 8, 16, Enum.Material.Slate, slate)
	ramp(architecture, entry, "EastGalleryRamp", 46, 13, 46, -25, 8, 16, Enum.Material.Slate, slate)
	for _, x in ipairs({-49, -25, 0, 25, 49}) do
		for _, z in ipairs({-43, -29}) do
			box(architecture, "GalleryStonePier", x, 3.35, z, 3, 6.7, 3, rock, Enum.Material.Slate)
			box(architecture, "PierFoot", x, .6, z, 4.3, 1.2, 4.3, slate, Enum.Material.Slate, false)
		end
	end
	box(architecture, "GalleryBackParapet", 0, 9.3, -46.4, 110, 2.6, 1.2, rock, Enum.Material.Slate)
	for _, x in ipairs({-33, 0, 33}) do
		box(architecture, "GalleryFrontGuard", x, 9.15, -25.6, 15, 2.3, 1.1, rock, Enum.Material.Slate)
		box(architecture, "GalleryGuardQuartz", x, 10.35, -25.6, 14, .12, 1.2, quartz, Enum.Material.Neon, false)
	end
	for index = 0, 12 do
		box(architecture, "GalleryPavingSeam", -51 + index * 8.5, 8.018, -36, .1, .035, 19.5, rock, Enum.Material.Slate, false)
	end
	-- Crystals and ledges fill islands outside the central passing lanes.
	for index, point in ipairs({{-31, 39, 1.12}, {31, 39, .94}, {-45, -57, .62}, {43, -57, .7}, {-78, 29, .72}, {77, -32, .72}}) do
		mineralCluster(p, point[1], point[2], point[3], quartz:Lerp(RGB(188, 139, 224), (index % 3) * .19), index * 27)
	end
	for _, x in ipairs({-29, 29}) do
		for _, z in ipairs({-6, 57}) do
			box(p, "LowGeologyCover", x, 1.7, z, 9, 3.4, 5, slate, Enum.Material.Slate)
			part(p, "SlantedRockFace", V(8.7, 1.5, 4.7), V(x, 3.55, z), rock, Enum.Material.Rock, false,
				CFrame.Angles(math.rad(8), math.rad(x), 0))
		end
	end
	for _, x in ipairs({-77, 77}) do
		for _, z in ipairs({-46, 45}) do
			box(p, "SurveyLanternFoot", x, .6, z, 2.2, 1.2, 2.2, rock, Enum.Material.Slate)
			box(p, "SurveyLantern", x, 2.1, z, 1, 1.4, 1, RGB(175, 222, 242), Enum.Material.Neon, false)
			box(p, "SurveyLanternCap", x, 2.9, z, 1.5, .3, 1.5, rock, Enum.Material.Metal, false)
		end
	end
	for index = 1, 28 do
		local side = index % 2 == 0 and -1 or 1
		local x = side * (79 + (index % 3) * 1.3)
		local z = -66 + ((index * 23) % 130)
		part(p, "PeripheralScree", V(1 + index % 3, .6 + index % 2 * .5, 1.6), V(x, .3, z), slate,
			Enum.Material.Rock, false, CFrame.Angles(0, math.rad(index * 29), math.rad(index % 3 * 7)))
	end
end

local function themeDeck(parent, entry, name, x, z, w, d, y, color, material)
    local result=deck(parent,entry,name,x,z,w,d,y,false)
    result.Color,result.Material=color,material
    return result
end
local function themeRamp(parent,entry,name,x1,z1,x2,z2,width,rise,color,material)
    return ramp(parent,entry,name,x1,z1,x2,z2,rise,width,material,color)
end
--!nonstrict
-- Theme fragment for the detailed map generator. Insert inside its shared-helper scope.
-- Every gameplay terrace is connected to ground by two broad shallow ramps.

local function themedPole(parent, name, x, y, z, height, color, lightColor)
	box(parent, name .. "Post", x, y + height / 2, z, 0.75, height, 0.75, color, Enum.Material.Metal, false)
	box(parent, name .. "Cap", x, y + height, z, 2.6, 0.35, 2.6, color, Enum.Material.Metal, false)
	box(parent, name .. "Lantern", x, y + height - 0.8, z, 1.6, 1.1, 1.6, lightColor, Enum.Material.Neon, false)
end

local function themedCrate(parent, x, z, w, d, color)
	box(parent, "WoodenCargo", x, 2.2, z, w, 4.4, d, color, Enum.Material.WoodPlanks)
	for _, side in ipairs({-1, 1}) do
		box(parent, "CargoBand", x + side * (w / 2 - 0.6), 4.48, z, 0.6, 0.16, d, RGB(72, 69, 60), Enum.Material.Metal, false)
		box(parent, "CargoCorner", x + side * (w / 2 - 0.35), 2.2, z + d / 2 + 0.03, 0.7, 4.4, 0.18, color:Lerp(RGB(52, 43, 31), 0.2), Enum.Material.Wood, false)
	end
end

local function themedStall(parent, x, z, color, fabric, title, wide)
	local w = wide or 18
	local wood = RGB(98, 69, 45)
	box(parent, "StallBack", x, 4.5, z - 5.5, w, 9, 1, color, Enum.Material.WoodPlanks)
	for _, side in ipairs({-1, 1}) do
		box(parent, "StallPost", x + side * (w / 2 - 0.5), 6.4, z + 4.5, 0.9, 12.8, 0.9, wood, Enum.Material.Wood)
		box(parent, "StallSide", x + side * (w / 2 - 0.45), 2.4, z, 0.9, 4.8, 11, color, Enum.Material.WoodPlanks)
	end
	box(parent, "ShopCounter", x, 3.1, z + 4, w, 6.2, 2, wood, Enum.Material.WoodPlanks)
	box(parent, "CounterTop", x, 6.3, z + 4, w + 0.6, 0.25, 3, RGB(209, 174, 112), Enum.Material.Wood, false)
	for stripe = 1, 6 do
		box(parent, "AwningStripe", x - w / 2 + (stripe - 0.5) * w / 6, 12.9, z, w / 6, 0.65, 13,
			stripe % 2 == 0 and fabric or RGB(244, 226, 183), Enum.Material.Fabric, false)
		box(parent, "AwningValance", x - w / 2 + (stripe - 0.5) * w / 6, 12.2, z + 6.2, w / 6, 1.4, 0.45,
			stripe % 2 == 0 and fabric or RGB(244, 226, 183), Enum.Material.Fabric, false)
	end
	local board = box(parent, "ShopName", x, 9, z - 4.84, w - 2, 2.3, 0.2, wood, Enum.Material.Wood, false)
	surfaceText(board, title, "", RGB(247, 214, 147))
	for i = -1, 1 do
		box(parent, "GoodsTray", x + i * 4, 6.62, z + 3.8, 3.2, 0.5, 2.2, RGB(130, 88, 52), Enum.Material.Wood, false)
		box(parent, "MarketGoods", x + i * 4, 7.25, z + 3.8, 2.5, 0.8, 1.4, ({RGB(225, 147, 63), RGB(132, 156, 75), RGB(195, 92, 65)})[i + 2], Enum.Material.SmoothPlastic, false)
	end
end

local function themedRail(parent, x, top, z, w, d, color)
	box(parent, "PromenadeGuard", x, top + 1.7, z, w, 3.4, d, color, Enum.Material.WoodPlanks)
	box(parent, "GuardCap", x, top + 3.5, z, w + 0.2, 0.3, d + 0.2, color:Lerp(RGB(245, 226, 184), 0.3), Enum.Material.Wood, false)
end

local function sunstoneBazaar(model, entry)
	local p = folder(model, "SunstoneMarketArchitecture")
	local sand, cream, clay = RGB(191, 150, 100), RGB(235, 209, 164), RGB(174, 94, 67)
	local gold, teal = RGB(232, 183, 77), RGB(43, 123, 121)
	-- A broad central market ring and side lanes; seams sit flush with the floor.
	box(p, "CentralMarketPaving", 0, 0.04, 21, 108, 0.08, 104, RGB(213, 181, 132), Enum.Material.Sandstone, false)
	for _, x in ipairs({-52, 0, 52}) do
		box(p, "PavingInlay", x, 0.095, 20, 0.22, 0.025, 118, gold, Enum.Material.SmoothPlastic, false)
	end
	for _, z in ipairs({-5, 30, 65}) do
		box(p, "PavingInlay", 0, 0.1, z, 150, 0.03, 0.22, gold, Enum.Material.SmoothPlastic, false)
	end
	-- North arcade: 8-stud elevation, 16-stud ramps, 34-stud run.
	themeDeck(p, entry, "BazaarArcade", 0, -57, 122, 24, 8, cream, Enum.Material.Sandstone)
	themeRamp(p, entry, "BazaarWestRamp", -43, -11, -43, -45, 16, 8, cream, Enum.Material.Sandstone)
	themeRamp(p, entry, "BazaarEastRamp", 43, -11, 43, -45, 16, 8, cream, Enum.Material.Sandstone)
	themedRail(p, 0, 8, -69, 122, 1.3, clay)
	for _, edge in ipairs({{-56.5, 9}, {0, 68}, {56.5, 9}}) do themedRail(p, edge[1], 8, -45, edge[2], 1.1, clay) end
	for _, x in ipairs({-55, -27.5, 0, 27.5, 55}) do
		box(p, "ArcadeColumn", x, 14.5, -65, 2.4, 13, 2.4, sand, Enum.Material.Sandstone)
		box(p, "ColumnFoot", x, 8.8, -65, 3.4, 1.6, 3.4, gold, Enum.Material.Sandstone, false)
		box(p, "ColumnCapital", x, 20.3, -65, 4, 1.5, 3.8, cream, Enum.Material.Sandstone, false)
	end
	box(p, "ArcadeLintel", 0, 21.8, -65, 118, 2.2, 4.5, sand, Enum.Material.Sandstone)
	box(p, "ArcadeCornice", 0, 23.3, -65, 121, 0.8, 5.8, cream, Enum.Material.Sandstone, false)
	for x = -55, 55, 5 do box(p, "ArcadeDentil", x, 22.7, -62.7, 1.4, 0.8, 1.3, gold, Enum.Material.Sandstone, false) end
	for _, x in ipairs({-42, -14, 14, 42}) do
		box(p, "ArcadeShade", x, 22, -54, 24, 0.6, 17, x < 0 and teal or clay, Enum.Material.Fabric, false)
		themedPole(p, "ArcadeLamp", x, 8, -61, 8.4, RGB(86, 68, 48), RGB(255, 220, 135))
	end
	-- Tall framing buildings sit behind the route and make a finished skyline.
	for _, sign in ipairs({-1, 1}) do
		local x = sign * 77
		box(p, "MinaretTower", x, 13, -65, 17, 26, 25, sand, Enum.Material.Sandstone)
		box(p, "TowerTrim", x, 26.5, -65, 19, 1.2, 27, cream, Enum.Material.Sandstone, false)
		box(p, "TowerParapet", x, 29, -75.5, 19, 4, 2, clay, Enum.Material.Sandstone)
		for _, dx in ipairs({-6, 0, 6}) do
			box(p, "TowerBattlement", x + dx, 30, -75.5, 3, 3, 2.4, cream, Enum.Material.Sandstone, false)
			box(p, "TowerWindow", x + dx, 17, -52.35, 2.5, 6.5, 0.18, RGB(54, 72, 66), Enum.Material.SmoothPlastic, false)
		end
		for _, z in ipairs({-27, 16, 58}) do themedStall(p, sign * 73, z, sand, sign < 0 and teal or clay, sign < 0 and "SPICE HOUSE" or "SUNSTONE GOODS", 18) end
	end
	for _, x in ipairs({-25, 25}) do themedStall(p, x, 52, clay, teal, x < 0 and "WOVEN CLOTH" or "FRESH PRODUCE", 18) end
	-- Central fountain is an obvious isolated obstacle, with a generous loop around it.
	disk(p, "FountainBase", 0, 0.9, 10, 18, 1.8, cream, Enum.Material.Sandstone, true)
	disk(p, "FountainWater", 0, 1.84, 10, 15, 0.1, RGB(66, 170, 172), Enum.Material.Glass, false)
	disk(p, "FountainStem", 0, 4.1, 10, 3.5, 5.4, sand, Enum.Material.Sandstone, true)
	disk(p, "FountainBowl", 0, 6.5, 10, 9, 1, cream, Enum.Material.Sandstone, false)
	for i = 0, 7 do
		local a = i * math.pi / 4
		box(p, "FountainMosaic", math.cos(a) * 8.8, 1.7, 10 + math.sin(a) * 8.8, 1, 0.8, 1, teal, Enum.Material.SmoothPlastic, false)
	end
	for _, x in ipairs({-86, 86}) do for _, z in ipairs({-6, 37, 76}) do themedPole(p, "MarketLamp", x, 0, z, 12, RGB(88, 69, 49), RGB(255, 220, 145)) end end
	for _, x in ipairs({-48, 48}) do
		themedCrate(p, x, 76, 8, 6, RGB(151, 103, 59))
		for _, z in ipairs({-77, 78}) do
			box(p, "DesertGarden", x, 1.2, z, 14, 2.4, 6, clay, Enum.Material.Sandstone)
			for dx = -4, 4, 4 do box(p, "DesertPlant", x + dx, 3.5, z, 1.1, 4.8, 1.1, RGB(103, 125, 72), Enum.Material.Grass, false) end
		end
	end
end

local function pirateCove(model, entry)
	local p = folder(model, "PirateHarborArchitecture")
	local wood, pale, iron = RGB(116, 80, 48), RGB(181, 146, 92), RGB(54, 65, 69)
	local aqua, navy = RGB(74, 158, 169), RGB(39, 72, 85)
	-- Clear sand lanes between the customs buildings and the elevated ship.
	box(p, "HarborStreet", 0, 0.06, 0, 32, 0.12, 162, RGB(182, 168, 133), Enum.Material.Cobblestone, false)
	box(p, "HarborCrossStreet", 0, 0.07, 43, 198, 0.14, 26, RGB(182, 168, 133), Enum.Material.Cobblestone, false)
	for _, z in ipairs({-75, -37, 0, 37, 75}) do
		box(p, "StreetDrain", 0, 0.16, z, 14, 0.08, 0.5, RGB(133, 123, 101), Enum.Material.Slate, false)
	end
	-- A ship-sized continuous deck is playable; both ends have shallow gangways.
	themeDeck(p, entry, "CorsairDeck", 64, 0, 40, 78, 8, wood, Enum.Material.WoodPlanks)
	themeRamp(p, entry, "NorthGangway", 64, -73, 64, -39, 18, 8, pale, Enum.Material.WoodPlanks)
	themeRamp(p, entry, "SouthGangway", 64, 73, 64, 39, 18, 8, pale, Enum.Material.WoodPlanks)
	for _, x in ipairs({44, 84}) do
		themedRail(p, x, 8, 0, 1.4, 78, navy)
		box(p, "ShipHullSide", x, 3.6, 0, 1.4, 7.2, 78, navy, Enum.Material.WoodPlanks)
		for z = -35, 35, 10 do
			box(p, "HullRib", x + (x < 64 and -0.2 or 0.2), 4.1, z, 0.6, 7.2, 1.1, wood, Enum.Material.Wood, false)
			box(p, "BrassPorthole", x + (x < 64 and -0.51 or 0.51), 4.5, z, 0.15, 1.8, 2.8, RGB(213, 174, 91), Enum.Material.Metal, false)
		end
	end
	for _, z in ipairs({-39, 39}) do
		themedRail(p, 48.5, 8, z, 9, 1.2, navy)
		themedRail(p, 79.5, 8, z, 9, 1.2, navy)
	end
	for z = -36, 36, 6 do box(p, "DeckPlankSeam", 64, 8.025, z, 36, 0.03, 0.07, RGB(72, 50, 33), Enum.Material.Wood, false) end
	-- Mast is on the outer edge: the main deck keeps a 22-stud passing lane.
	box(p, "ShipMast", 79, 25, 0, 1.8, 34, 1.8, wood, Enum.Material.Wood)
	box(p, "MastCrossbar", 68, 37, 0, 24, 1.1, 1.1, wood, Enum.Material.Wood, false)
	box(p, "CanvasSail", 68, 29.2, 0, 22, 14, 0.3, RGB(229, 220, 185), Enum.Material.Fabric, false)
	box(p, "SailStripe", 68, 30, -0.2, 3, 11, 0.15, navy, Enum.Material.Fabric, false)
	for _, z in ipairs({-29, 29}) do
		themedPole(p, "ShipLantern", 79, 8, z, 7, iron, RGB(255, 213, 124))
		box(p, "DeckCargo", 48, 9.9, z, 5, 3.8, 5, pale, Enum.Material.WoodPlanks)
	end
	-- Harbor basin is inset scenery; collision rims keep runners on the dry routes.
	box(p, "HarborBasin", -67, 0.05, -59, 62, 0.1, 34, aqua, Enum.Material.Glass, false).Transparency = 0.14
	for _, z in ipairs({-77, -41}) do themedRail(p, -67, 0, z, 64, 1.4, wood) end
	for _, x in ipairs({-99, -35}) do themedRail(p, x, 0, -59, 1.4, 34, wood) end
	for i = 1, 8 do box(p, "HarborRipple", -91 + i * 6, 0.13, -57 + (i % 3) * 3, 7, 0.03, 0.18, RGB(137, 199, 195), Enum.Material.SmoothPlastic, false) end
	box(p, "MooredBoatHull", -67, 2.4, -61, 28, 4.8, 10, navy, Enum.Material.WoodPlanks)
	box(p, "MooredBoatDeck", -67, 4.86, -61, 25, 0.12, 8, pale, Enum.Material.WoodPlanks, false)
	box(p, "MooredBoatMast", -67, 14, -61, 0.8, 19, 0.8, wood, Enum.Material.Wood, false)
	box(p, "MooredBoatSail", -62, 17, -61, 10, 10, 0.2, RGB(227, 213, 173), Enum.Material.Fabric, false)
	-- Customs house is a real two-door passage with 18-stud clear opening.
	for _, x in ipairs({-87, -49}) do box(p, "CustomsSideWall", x, 9, 0, 2, 18, 38, RGB(140, 151, 139), Enum.Material.Brick) end
	for _, z in ipairs({-19, 19}) do
		for _, x in ipairs({-82, -54}) do box(p, "CustomsDoorPier", x, 9, z, 10, 18, 2, RGB(140, 151, 139), Enum.Material.Brick) end
		box(p, "CustomsDoorLintel", -68, 15.2, z, 18, 5.6, 2, pale, Enum.Material.Wood)
		for _, x in ipairs({-79, -57}) do box(p, "CustomsWindow", x, 11, z + (z > 0 and 1.05 or -1.05), 4.5, 5, 0.15, navy, Enum.Material.Glass, false) end
	end
	box(p, "CustomsRoof", -68, 19, 0, 44, 2, 44, RGB(83, 107, 115), Enum.Material.Slate)
	for _, x in ipairs({-83, -73, -63, -53}) do box(p, "RoofSeam", x, 20.06, 0, 0.28, 0.12, 44, pale, Enum.Material.Wood, false) end
	local board = box(p, "CustomsName", -68, 16.1, 20.18, 22, 3, 0.2, wood, Enum.Material.Wood, false)
	surfaceText(board, "COVE CUSTOMS", "", RGB(244, 221, 157))
	for _, x in ipairs({-88, -63, -37}) do
		themedCrate(p, x, 69, 12, 9, pale)
		themedPole(p, "DockLamp", x, 0, 82, 12, iron, RGB(255, 216, 143))
	end
	for _, z in ipairs({-73, -38, 0, 38, 73}) do
		box(p, "PierPiling", 99, 4, z, 2.4, 8, 2.4, wood, Enum.Material.Wood)
		box(p, "PilingCap", 99, 8.1, z, 3, 0.4, 3, pale, Enum.Material.Wood, false)
	end
	for _, z in ipairs({-83, 83}) do
		for _, x in ipairs({-21, 19}) do themedPole(p, "HarborLamp", x, 0, z, 13, iron, RGB(255, 216, 143)) end
	end
end

local function stardustCarnival(model, entry)
	local p = folder(model, "StardustMidwayArchitecture")
	local plum, coral, cream = RGB(91, 58, 115), RGB(218, 100, 108), RGB(239, 218, 172)
	local gold, blue = RGB(247, 198, 91), RGB(63, 142, 166)
	-- Three broad lanes join a roomy central carousel loop.
	box(p, "MidwayNorthSouth", 0, 0.055, 17, 30, 0.11, 148, RGB(112, 119, 133), Enum.Material.Cobblestone, false)
	box(p, "MidwayCrossing", 0, 0.06, 25, 184, 0.12, 26, RGB(112, 119, 133), Enum.Material.Cobblestone, false)
	for _, x in ipairs({-51, 51}) do box(p, "SideMidway", x, 0.04, 26, 24, 0.08, 120, RGB(112, 119, 133), Enum.Material.Cobblestone, false) end
	for _, z in ipairs({-15, 64}) do box(p, "MidwayGoldInlay", 0, 0.14, z, 174, 0.05, 0.2, gold, Enum.Material.SmoothPlastic, false) end
	themeDeck(p, entry, "TicketPromenade", 0, -64, 130, 26, 6, RGB(141, 119, 147), Enum.Material.WoodPlanks)
	themeRamp(p, entry, "WestTicketRamp", -43, -17, -43, -51, 18, 6, cream, Enum.Material.WoodPlanks)
	themeRamp(p, entry, "EastTicketRamp", 43, -17, 43, -51, 18, 6, cream, Enum.Material.WoodPlanks)
	themedRail(p, 0, 6, -77, 130, 1.3, plum)
	for _, span in ipairs({{-58.5, 13}, {0, 68}, {58.5, 13}}) do themedRail(p, span[1], 6, -51, span[2], 1.1, plum) end
	-- Elevated stage has open sides and two ways down through the promenade.
	box(p, "StageBackdrop", 0, 15, -73, 39, 18, 1.2, plum, Enum.Material.WoodPlanks)
	for _, x in ipairs({-19, 19}) do
		box(p, "StageColumn", x, 15, -64, 1.8, 18, 1.8, coral, Enum.Material.Wood)
		box(p, "StageFinial", x, 25, -64, 3, 2, 3, gold, Enum.Material.SmoothPlastic, false)
	end
	box(p, "StageCanopy", 0, 24.3, -66, 44, 0.8, 20, coral, Enum.Material.Fabric, false)
	local sign = box(p, "StardustStageSign", 0, 19, -72.25, 31, 6, 0.2, plum, Enum.Material.Wood, false)
	surfaceText(sign, "STARDUST", "THE MIDWAY", gold)
	for x = -16, 16, 4 do box(p, "StageBulb", x, 23.65, -55.95, 0.8, 0.8, 0.4, gold, Enum.Material.Neon, false) end
	for _, x in ipairs({-55, -28, 28, 55}) do themedPole(p, "PromenadeLamp", x, 6, -73, 10, plum, gold) end
	-- The carousel is scenery in the centre of a 24+ stud circulation loop.
	disk(p, "CarouselPlinth", 0, 0.8, 15, 29, 1.6, plum, Enum.Material.Concrete, true)
	disk(p, "CarouselTurntable", 0, 1.7, 15, 25, 0.3, cream, Enum.Material.WoodPlanks, false)
	disk(p, "CarouselRoof", 0, 16.8, 15, 31, 1.6, coral, Enum.Material.SmoothPlastic, false)
	disk(p, "CarouselCrown", 0, 18, 15, 18, 1.1, plum, Enum.Material.SmoothPlastic, false)
	box(p, "CarouselCentre", 0, 9, 15, 3.5, 16, 3.5, cream, Enum.Material.Wood)
	for i = 0, 7 do
		local a = i * math.pi / 4
		local x, z = math.sin(a) * 9.5, 15 + math.cos(a) * 9.5
		box(p, "CarouselPole", x, 9, z, 0.45, 14.5, 0.45, gold, Enum.Material.Metal, false)
		box(p, "CarouselHorse", x, 5, z, 2.5, 2.1, 4.5, i % 2 == 0 and blue or coral, Enum.Material.SmoothPlastic, false)
		box(p, "HorseNeck", x, 6.3, z - 1.8, 1.5, 3, 1.5, cream, Enum.Material.SmoothPlastic, false)
		box(p, "CarouselBulb", math.sin(a) * 15.4, 16.8, 15 + math.cos(a) * 15.4, 0.9, 0.9, 0.9, gold, Enum.Material.Neon, false)
	end
	local stallTitles = {"MOON POPCORN", "LUCKY STARS", "COMET GIFTS"}
	for _, side in ipairs({-1, 1}) do
		for i, z in ipairs({-9, 30, 71}) do
			themedStall(p, side * 79, z, plum, i % 2 == 0 and blue or coral, stallTitles[i], 18)
			box(p, "ShopPennant", side * 79, 16, z - 2, 0.6, 5, 0.6, gold, Enum.Material.Wood, false)
			box(p, "PennantFlag", side * 79 + 2.5, 17.7, z - 2, 5, 2.3, 0.2, i % 2 == 0 and gold or blue, Enum.Material.Fabric, false)
		end
	end
	-- A wheel silhouette fills the skyline; the ride is behind the northern rail.
	local wheelX, wheelY, wheelZ = 84, 25, -65
	for _, z in ipairs({wheelZ - 14, wheelZ + 14}) do
		local pole = box(p, "WheelSupport", wheelX, 12, z, 2.2, 25, 2.2, plum, Enum.Material.Metal)
		pole.CFrame = CF(wheelX, 12, z) * CFrame.Angles(math.rad(z < wheelZ and -18 or 18), 0, 0)
	end
	for i = 0, 15 do
		local a, b = i * math.pi / 8, (i + 1) * math.pi / 8
		local pa = V(wheelX, wheelY + math.sin(a) * 21, wheelZ + math.cos(a) * 21)
		local pb = V(wheelX, wheelY + math.sin(b) * 21, wheelZ + math.cos(b) * 21)
		local bar = part(p, "WheelRim", V(0.9, 0.9, (pb - pa).Magnitude), (pa + pb) / 2, cream, Enum.Material.Metal, false)
		bar.CFrame = CFrame.lookAt((pa + pb) / 2, pb, V(1, 0, 0))
		if i % 2 == 0 then
			local centre = V(wheelX, wheelY, wheelZ)
			local spoke = part(p, "WheelSpoke", V(0.55, 0.55, (pa - centre).Magnitude), (pa + centre) / 2, gold, Enum.Material.Metal, false)
			spoke.CFrame = CFrame.lookAt((pa + centre) / 2, pa, V(1, 0, 0))
			box(p, "WheelCabin", wheelX, pa.Y - 2, pa.Z, 5, 4, 5, i % 4 == 0 and coral or blue, Enum.Material.Metal, false)
			box(p, "CabinWindow", wheelX - 2.55, pa.Y - 1.8, pa.Z, 0.1, 2, 3.6, RGB(166, 218, 222), Enum.Material.Glass, false)
		end
	end
	for _, x in ipairs({-95, 95}) do for _, z in ipairs({-29, 11, 51, 89}) do themedPole(p, "MidwayLamp", x, 0, z, 13, plum, gold) end end
	-- Decorative ticket kiosks define the southern edge without narrowing exits.
	for _, x in ipairs({-27, 27}) do
		box(p, "TicketBooth", x, 5, 83, 12, 10, 9, coral, Enum.Material.WoodPlanks)
		box(p, "TicketRoof", x, 10.7, 83, 14, 1.4, 11, plum, Enum.Material.Slate, false)
		box(p, "TicketWindow", x, 6.5, 78.42, 8, 4, 0.16, RGB(92, 174, 180), Enum.Material.Glass, false)
		box(p, "TicketCounter", x, 4.5, 77.9, 9, 0.4, 1.5, cream, Enum.Material.Wood, false)
	end
end
-- Neon streets, working foundry, orbital concourse, ruined cloisters and a keep.
local function facade(parent, name, x, z, w, d, h, body, accent, style)
    local p = group(parent, name, "Model")
    box(p, "BuildingShell", x, h/2, z, w, h, d, body, style or Enum.Material.Brick)
    trim(p, "FoundationCourse", x, 0.7, z, w+0.6, 1.4, d+0.6, body:Lerp(INK, .2))
    trim(p, "RoofCornice", x, h+.3, z, w+1.5, .6, d+1.5, body:Lerp(WHITE, .35))
    for _, side in ipairs({-1,1}) do
        for xx = -w/2+4, w/2-3, 7 do
            for yy = 5, h-2, 7 do window(p, x+xx, yy, z+side*(d/2+.1), 4.2, 4.4, accent) end
        end
        trim(p, "FacadeBand", x, h-1.2, z+side*(d/2+.18), w, .35, .3, accent, Enum.Material.Neon)
    end
    for xx = -w/2+1, w/2, 10 do
        trim(p, "VerticalPilaster", x+xx, h/2, z+d/2+.28, .55, h, .4, body:Lerp(WHITE,.25))
    end
    trim(p, "RooftopVent", x-w*.18, h+1.8, z, 7, 3, 5, INK, Enum.Material.Metal)
    for xx=-2.5,2.5,1 do trim(p,"VentSlat",x-w*.18+xx,h+3.33,z,.14,.08,4.6,WHITE,Enum.Material.Metal) end
    return p
end
local function pipeRun(parent, x, z, y, length, accent)
    box(parent,"PipeRack",x,y,z,length,.7,.7,INK,Enum.Material.Metal,false)
    for xx=-length/2+2,length/2,6 do
        trim(parent,"PipeCollar",x+xx,y,z,.5,1.05,1.05,accent,Enum.Material.Metal)
    end
end
local function neon(model, entry)
    local p=group(model,"DistrictArchitecture")
    local asphalt, concrete, cyan, pink=RGB(55,64,77),RGB(112,126,139),RGB(77,206,208),RGB(213,105,169)
    ground(model,entry,asphalt,Enum.Material.Asphalt)
    paving(p,"CentralBoulevard",0,12,32,138,RGB(67,76,87),Enum.Material.Asphalt)
    paving(p,"CrossStreet",0,28,166,26,RGB(67,76,87),Enum.Material.Asphalt)
    for _,x in ipairs({-65,65}) do paving(p,"Sidewalk",x,9,23,140,concrete) end
    for _,z in ipairs({-21,51}) do
        for x=-12,12,5 do paving(p,"ZebraCrossing",x,z,2.8,11,WHITE) end
    end
    for z=-54,65,12 do paving(p,"RoadDash",0,z,.4,5,RGB(229,180,95)) end
    for _,s in ipairs({-1,1}) do
        facade(p,"CornerShop",s*35,54,28,23,20,RGB(92,101,125),s<0 and cyan or pink)
        facade(p,"ApartmentFront",s*69,-59,28,26,34,RGB(78,89,107),s<0 and pink or cyan)
        facade(p,"CafeBlock",s*72,-3,19,23,17,RGB(104,107,115),cyan)
        local awning=trim(p,"CafeAwning",s*72,10,10,21,.5,6,pink,Enum.Material.Metal)
        for x=-7,7,3.5 do trim(p,"AwningStripe",s*72+x,10.3,10,.45,.08,5.8,WHITE) end
        lamp(p,s*50,31,cyan,14)
        lamp(p,s*51,-29,pink,14)
        planter(p,entry,"StreetPlanter",s*33,2,10,12,false,true)
        bench(p,s*54,64,s<0 and 90 or -90)
        for z=-45,58,19 do trim(p,"Drain",s*17,.08,z,1.6,.08,4,INK,Enum.Material.Metal) end
    end
    deck(p,entry,"MetroSkywalk",0,-43,102,20,8,true).Color=concrete
    ramp(p,entry,"WestMetroRamp",-43,1,-43,-33,8,16,Enum.Material.Concrete,concrete)
    ramp(p,entry,"EastMetroRamp",43,1,43,-33,8,16,Enum.Material.Concrete,concrete)
    rail(p,"SkywalkBackRail",V(-51,8,-53),V(51,8,-53),INK)
    rail(p,"SkywalkFrontRail",V(-33,8,-33),V(33,8,-33),INK)
    for _,x in ipairs({-28,0,28}) do
        for _,z in ipairs({-50,-36}) do box(p,"SkywalkPier",x,3.6,z,1.4,7.2,1.4,INK,Enum.Material.Metal) end
        trim(p,"MetroCanopy",x,17,-43,25,.6,18,RGB(81,101,121),Enum.Material.Metal)
        for _,z in ipairs({-50,-36}) do box(p,"CanopyPost",x,12.5,z,.6,9,.6,INK,Enum.Material.Metal) end
    end
    local board=trim(p,"MetroSign",0,18.5,-32.5,34,4,.4,INK)
    sign(board,"NEON DISTRICT","RUN THE BOULEVARD",cyan)
    boundaries(model,entry,RGB(84,96,112))
end
local function foundry(model,entry)
    local p=group(model,"FoundryComplex")
    local iron,rust,amber=RGB(76,89,93),RGB(145,87,56),RGB(243,166,63)
    ground(model,entry,RGB(99,100,91),Enum.Material.Concrete)
    paving(p,"FoundryMainLane",0,0,28,178,RGB(126,127,111))
    paving(p,"FreightCrossing",0,50,204,24,RGB(129,125,109))
    for _,s in ipairs({-1,1}) do
        facade(p,"BrickWorkshop",s*81,-58,34,36,28,rust,RGB(198,177,117))
        for z=-38,70,10 do
            trim(p,"YardTrack",s*81,.09,z,1.2,.08,9.7,INK,Enum.Material.Metal)
            trim(p,"TrackSleeper",s*81,.04,z,10,.06,.6,RGB(79,71,58),Enum.Material.Wood)
        end
        for _,z in ipairs({-23,70}) do crate(p,entry,s*47,z,14,12,6) end
        cylinder(p,"BoilerBody",s*82,9,29,18,18,iron,Enum.Material.Metal)
        for y=2,17,5 do cylinder(p,"BoilerRivetBand",s*82,y,29,18.5,.55,amber,Enum.Material.Metal,false) end
        cylinder(p,"BoilerCap",s*82,18.5,29,19,1,iron,Enum.Material.Metal,false)
        box(p,"ExhaustStack",s*82,25,29,5,14,5,INK,Enum.Material.Metal,false)
        for y=20,31,3 do trim(p,"StackBand",s*82,y,29,5.4,.3,5.4,rust,Enum.Material.Metal) end
        pipeRun(p,s*65,-34,19,42,amber)
        lamp(p,s*103,43,amber,17)
        lamp(p,s*105,-75,amber,17)
    end
    -- A long east/west gantry has an approach from each side, leaving a broad underpass.
    deck(p,entry,"FoundryGantry",0,0,104,20,9,true).Color=iron
    ramp(p,entry,"WestGantryRamp",-88,0,-52,0,9,18,Enum.Material.DiamondPlate,iron)
    ramp(p,entry,"EastGantryRamp",88,0,52,0,9,18,Enum.Material.DiamondPlate,iron)
    for _,z in ipairs({-10,10}) do rail(p,"GantryGuard",V(-52,9,z),V(52,9,z),INK) end
    for _,x in ipairs({-43,-24,24,43}) do
        for _,z in ipairs({-8,8}) do box(p,"GantryColumn",x,4.1,z,1.4,8.2,1.4,iron,Enum.Material.Metal) end
    end
    for x=-47,47,7 do trim(p,"DeckSafetyInlay",x,9.06,0,.25,.05,18,amber) end
    -- Back wall furnace fronts create a strong landmark without a climbable dead end.
    facade(p,"FurnaceHall",0,-73,100,22,30,RGB(120,98,77),amber)
    for _,x in ipairs({-31,0,31}) do
        box(p,"FurnaceFrame",x,7,-61.6,20,14,.7,INK,Enum.Material.Metal)
        trim(p,"FurnaceGlow",x,7,-61.1,16,10,.1,RGB(236,131,58),Enum.Material.Neon)
        for dx=-7,7,2 do trim(p,"FurnaceGrille",x+dx,7,-60.9,.45,10,.3,iron,Enum.Material.Metal) end
        box(p,"ChimneyTower",x,36,-73,9,15,9,iron,Enum.Material.Metal,false)
    end
    for z=-49,77,14 do
        for _,s in ipairs({-1,1}) do trim(p,"SafetyLaneDash",s*15,.08,z,.5,.04,5,amber) end
    end
    boundaries(model,entry,RGB(108,108,92))
end
local function orbital(model,entry)
    local p=group(model,"OrbitalConcourse")
    local shell,dark,blue=RGB(186,200,203),RGB(51,67,84),RGB(106,208,231)
    ground(model,entry,RGB(94,112,127),Enum.Material.Metal)
    for x=-96,96,24 do
        for z=-80,80,20 do
            paving(p,"HullFloorPanel",x,z,23.4,19.4,RGB(116,133,145),Enum.Material.Metal)
            trim(p,"PanelFastener",x-10,.1,z-8,.5,.08,.5,dark,Enum.Material.Metal)
        end
    end
    paving(p,"CentralRunway",0,5,30,162,dark,Enum.Material.Metal)
    for z=-65,73,13 do
        for _,s in ipairs({-1,1}) do trim(p,"ConcourseGuideLight",s*15,.12,z,.45,.1,6,blue,Enum.Material.Neon) end
    end
    for _,s in ipairs({-1,1}) do
        facade(p,"HabitationWing",s*82,-65,43,25,24,shell,blue,Enum.Material.Metal)
        facade(p,"CargoAirlock",s*85,58,34,29,21,shell,RGB(168,191,231),Enum.Material.Metal)
        for _,z in ipairs({-14,20}) do
            local pod=group(p,"ResearchPod","Model")
            cylinder(pod,"PodBase",s*71,1,z,18,2,dark,Enum.Material.Metal)
            cylinder(pod,"ObservationTank",s*71,7,z,14,10,RGB(128,190,203),Enum.Material.Glass,false).Transparency=.2
            for _,dx in ipairs({-7,7}) do box(pod,"TankSpine",s*71+dx,7,z,1.4,12,1.4,shell,Enum.Material.Metal) end
            cylinder(pod,"PodRoof",s*71,13,z,19,1,shell,Enum.Material.Metal,false)
            cylinder(pod,"SpecimenCore",s*71,6,z,5,8,blue,Enum.Material.Neon,false)
        end
        lamp(p,s*110,15,blue,16)
        box(p,"DockClamp",s*104,5,-33,12,10,9,dark,Enum.Material.Metal)
        for y=2,9,2 do trim(p,"ClampLight",s*104,y,-28.3,9,.3,.2,blue,Enum.Material.Neon) end
    end
    -- Two longitudinal upper wings link through a north bridge; ramps are at opposite corners.
    deck(p,entry,"WestObservationWalk",-37,-25,20,62,8,true).Color=shell
    deck(p,entry,"EastObservationWalk",37,-25,20,62,8,true).Color=shell
    deck(p,entry,"CommandBridge",0,-46,54,20,8,true).Color=shell
    ramp(p,entry,"WestConcourseRamp",-37,40,-37,6,8,18,Enum.Material.Metal,shell)
    ramp(p,entry,"EastConcourseRamp",37,40,37,6,8,18,Enum.Material.Metal,shell)
    for _,s in ipairs({-1,1}) do
        rail(p,"OuterObservationRail",V(s*47,8,-56),V(s*47,8,6),dark)
        rail(p,"InnerObservationRail",V(s*27,8,-36),V(s*27,8,6),dark)
        for _,z in ipairs({-52,-15}) do box(p,"WalkPylon",s*43,3.6,z,1.2,7.2,1.2,dark,Enum.Material.Metal) end
        trim(p,"UpperGuideLight",s*47,8.12,-24,.4,.12,59,blue,Enum.Material.Neon)
    end
    rail(p,"BridgeNorthRail",V(-27,8,-56),V(27,8,-56),dark)
    rail(p,"BridgeSouthRail",V(-27,8,-36),V(27,8,-36),dark)
    local console=trim(p,"CommandSign",0,15,-57,32,4,.4,dark)
    sign(console,"ORBITAL STATION","CONCOURSE 07 / OPEN CIRCUIT",blue)
    for _,x in ipairs({-16,16}) do box(p,"SignSupport",x,11.5,-57,.7,7,.7,shell,Enum.Material.Metal,false) end
    boundaries(model,entry,RGB(132,153,165))
end
local function emerald(model,entry)
    local p=group(model,"OvergrownCloisters")
    local stone,moss=RGB(148,160,131),RGB(79,126,86)
    ground(model,entry,RGB(101,134,84),Enum.Material.Grass)
    paving(p,"OldProcessionalWay",0,8,26,158,RGB(178,182,149),Enum.Material.Cobblestone)
    paving(p,"GardenCrossway",0,32,183,22,RGB(169,176,143),Enum.Material.Cobblestone)
    for _,s in ipairs({-1,1}) do
        deck(p,entry,"RaisedCloister",s*47,-24,26,60,7,false).Color=stone
        ramp(p,entry,"CloisterAscent",s*47,34,s*47,6,7,18,Enum.Material.Cobblestone,stone)
        for _,z in ipairs({-49,-23,1}) do
            ruinColumn(p,s*57,z,7,12,stone,moss)
            trim(p,"CloisterLintel",s*57,19.5,z-7,4,1.3,19,stone,Enum.Material.Limestone)
        end
        rail(p,"CloisterInnerGuard",V(s*34,7,-32),V(s*34,7,6),stone)
        rail(p,"CloisterOuterGuard",V(s*60,7,-54),V(s*60,7,6),stone)
        for _,z in ipairs({-62,47}) do
            planter(p,entry,"OvergrownGarden",s*76,z,16,18,false,true)
            ruinColumn(p,s*77,z+17,0,8+(z<0 and 4 or 0),stone,moss)
        end
        for _,z in ipairs({-12,23}) do
            box(p,"RuinedWall",s*83,3,z,13,6,8,stone,Enum.Material.Limestone)
            for dx=-4,4,4 do trim(p,"WallMoss",s*83+dx,6.05,z,3,.15,7,moss,Enum.Material.Grass) end
        end
    end
    deck(p,entry,"SanctuaryCrossing",0,-44,68,20,7,true).Color=stone
    rail(p,"SanctuaryNorthGuard",V(-34,7,-54),V(34,7,-54),stone)
    rail(p,"SanctuarySouthGuard",V(-34,7,-34),V(34,7,-34),stone)
    for _,x in ipairs({-24,0,24}) do ruinColumn(p,x,-50,0,6.1,stone,moss) end
    cylinder(p,"SacredBasin",0,1,31,20,2,stone,Enum.Material.Slate)
    cylinder(p,"EmeraldWater",0,2.06,31,17,.1,RGB(81,155,122),Enum.Material.Glass,false)
    mineralCluster(p,0,31,.65,RGB(108,213,154),10)
    for _,x in ipairs({-26,26}) do
        for _,z in ipairs({-9,58}) do
            box(p,"BrokenPlinth",x,2,z,8,4,8,stone,Enum.Material.Limestone)
            trim(p,"PlinthMoss",x,4.05,z,7.4,.1,7.4,moss,Enum.Material.Grass)
        end
    end
    -- Broken rear portico is a backdrop; accessible upper route remains in front of it.
    for x=-30,30,20 do ruinColumn(p,x,-71,0,17,stone,moss) end
    trim(p,"PorticoLintel",0,17,-71,69,2.5,6,stone,Enum.Material.Limestone)
    for i=1,18 do trim(p,"FallenStone",-85+(i*23%170),.4,72+(i%2)*4,2.5,.8,2,stone,Enum.Material.Rock) end
    boundaries(model,entry,RGB(133,151,123))
end
local function ember(model,entry)
    local p=group(model,"CitadelArchitecture")
    local stone,dark,copper=RGB(145,126,111),RGB(76,76,81),RGB(211,141,82)
    ground(model,entry,RGB(114,113,106),Enum.Material.Cobblestone)
    paving(p,"KeepCourtyard",0,21,134,107,RGB(167,151,126),Enum.Material.Cobblestone)
    tiles(p,0,25,126,100,10,RGB(128,119,104))
    deck(p,entry,"WestBattlement",-57,-26,24,66,8,false).Color=stone
    deck(p,entry,"EastBattlement",57,-26,24,66,8,false).Color=stone
    deck(p,entry,"GatehouseGallery",0,-47,90,24,8,true).Color=stone
    ramp(p,entry,"WestBastionRamp",-57,41,-57,7,8,18,Enum.Material.Cobblestone,stone)
    ramp(p,entry,"EastBastionRamp",57,41,57,7,8,18,Enum.Material.Cobblestone,stone)
    for _,s in ipairs({-1,1}) do
        for _,z in ipairs({-59,52}) do
            facade(p,"FortifiedTower",s*85,z,22,26,30,stone,RGB(114,135,133))
            for dx=-8,8,8 do for dz=-10,10,10 do
                box(p,"TowerMerlon",s*85+dx,32,z+dz,5,4,4,dark,Enum.Material.Slate,false)
            end end
            for y=4,25,7 do trim(p,"TowerCourse",s*85,y,z,22.7,.55,26.7,dark,Enum.Material.Slate) end
        end
        rail(p,"BattlementOuterRail",V(s*69,8,-59),V(s*69,8,7),stone)
        rail(p,"BattlementInnerRail",V(s*45,8,-35),V(s*45,8,7),stone)
        for z=-53,2,11 do box(p,"BattlementMerlon",s*68,11,z,3,6,5,stone,Enum.Material.Brick) end
        for _,z in ipairs({-16,31}) do
            box(p,"SiegeSupply",s*30,2,z,12,4,8,RGB(115,87,60),Enum.Material.WoodPlanks)
            for dx=-4,4,8 do trim(p,"SupplyBinding",s*30+dx,4.08,z,.5,.1,8.1,dark,Enum.Material.Metal) end
        end
        lamp(p,s*93,3,copper,15)
        trim(p,"KeepBanner",s*22,19,-58,7,14,.3,RGB(161,72,54),Enum.Material.Fabric)
        trim(p,"BannerEmblem",s*22,20,-57.8,2.5,5,.2,copper,Enum.Material.Metal)
    end
    rail(p,"GatehouseFrontRail",V(-45,8,-35),V(45,8,-35),stone)
    rail(p,"GatehouseBackRail",V(-45,8,-59),V(45,8,-59),stone)
    for _,x in ipairs({-37,37}) do box(p,"GalleryButtress",x,3.6,-47,4,7.2,18,stone,Enum.Material.Brick) end
    -- Tall rear keep stays behind the accessible gallery and its two exits.
    facade(p,"GreatHall",0,-80,112,22,35,RGB(133,113,96),copper)
    for x=-48,48,12 do box(p,"GreatHallMerlon",x,37,-80,6,4,5,dark,Enum.Material.Slate,false) end
    for _,x in ipairs({-13,13}) do
        cylinder(p,"BrazierFoot",x,1,60,7,2,dark,Enum.Material.Slate)
        cylinder(p,"BrazierBowl",x,4,60,6,1.5,copper,Enum.Material.Metal,false)
        ball(p,"EmberGlow",x,5.3,60,3,RGB(241,150,62),Enum.Material.Neon)
    end
    boundaries(model,entry,stone)
end

-- Keep the established V6 display names; the server still offers three random choices.
for _, definition in ipairs({
    {"neon","Neon District",180,160,RGB(77,206,208),"Boulevards, cafes and a metro skywalk"},
    {"cavern","Crystal Cavern",184,164,RGB(106,192,231),"Mineral galleries and basalt formations"},
    {"foundry","Clockwork Foundry",228,186,RGB(243,166,63),"Furnace halls, boilers and a crossing gantry"},
    {"bazaar","Sunstone Bazaar",190,172,RGB(232,183,77),"Market stalls and a shaded sandstone arcade"},
    {"emerald","Emerald Ruins",204,184,RGB(108,213,154),"Overgrown cloisters and a sanctuary bridge"},
    {"pirate","Pirate Cove",226,184,RGB(74,158,169),"A ship deck, gangways and harbor shops"},
    {"carnival","Stardust Carnival",214,202,RGB(213,105,169),"A colorful midway and ticket promenade"},
    {"ember","Ember Keep",218,204,RGB(211,141,82),"Twin battlements and a gatehouse gallery"},
    {"orbital","Orbital Station",246,192,RGB(106,208,231),"Research pods and an observation circuit"},
}) do
    table.insert(catalog,{Id=definition[1],Name=definition[2],Width=definition[3],Depth=definition[4],Accent=definition[5],Subtitle=definition[6],Description=definition[6]})
end
local builders={valley=valley,depot=depot,frost=frost,neon=neon,cavern=cavern,foundry=foundry,bazaar=sunstoneBazaar,emerald=emerald,pirate=pirateCove,carnival=stardustCarnival,ember=ember,orbital=orbital}
local groundColors={cavern=RGB(64,74,86),bazaar=RGB(193,161,111),pirate=RGB(184,173,139),carnival=RGB(122,130,125)}
-- Conservative spawn selection: keep a four-stud radius clear of every solid,
-- including elevated geometry. The gameplay service casts down from 25 studs up.
local function safeSpawns(model,entry)
    local old=model:FindFirstChild("Spawns")
    if old then old:Destroy() end
    entry.Geometry.Spawns={}
    local blocked={}
    for _,obj in ipairs(model:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name~="Floor" and obj.CanCollide then
            local half=obj.Size/2
            local cf=obj.CFrame
            local extent=V(
                math.abs(cf.RightVector.X)*half.X+math.abs(cf.UpVector.X)*half.Y+math.abs(cf.LookVector.X)*half.Z,
                math.abs(cf.RightVector.Y)*half.X+math.abs(cf.UpVector.Y)*half.Y+math.abs(cf.LookVector.Y)*half.Z,
                math.abs(cf.RightVector.Z)*half.X+math.abs(cf.UpVector.Z)*half.Y+math.abs(cf.LookVector.Z)*half.Z)
            if obj.Position.Y+extent.Y>.3 then
                table.insert(blocked,{X=obj.Position.X,Z=obj.Position.Z,HalfX=extent.X+4,HalfZ=extent.Z+4})
            end
        end
    end
    local candidates={}
    for x=-entry.Width/2+12,entry.Width/2-12,6 do
        for z=-entry.Depth/2+12,entry.Depth/2-12,6 do
            local clear=true
            for _,b in ipairs(blocked) do
                if math.abs(x-b.X)<b.HalfX and math.abs(z-b.Z)<b.HalfZ then clear=false;break end
            end
            if clear and x*x+z*z>1 then table.insert(candidates,{x,z}) end
        end
    end
    assert(#candidates>=16,"Insufficient spawn clearance: "..entry.Name)
    local selected={}
    for i=1,16 do
        local best,bestScore=1,-1
        for j,p in ipairs(candidates) do
            local score=#selected==0 and p[1]*p[1]+p[2]*p[2] or math.huge
            for _,q in ipairs(selected) do score=math.min(score,(p[1]-q[1])^2+(p[2]-q[2])^2) end
            if score>bestScore then best,bestScore=j,score end
        end
        table.insert(selected,table.remove(candidates,best))
    end
    spawns(model,entry,selected)
end
function MapBuilder.BuildInto(parent)
    assert(parent,"BuildInto requires a destination")
    local result={}
    for _,entry in ipairs(catalog) do
        surfaceLayer=0
        entry.Layout={}
        entry.Geometry={Version=VERSION,Id=entry.Id,Name=entry.Name,Width=entry.Width,Depth=entry.Depth,Ramps={},Decks={},Routes={},Spawns={},Obstacles={}}
        local model=group(parent,entry.Name,"Model")
        model:SetAttribute("BombTagGenerated",VERSION)
        model:SetAttribute("MapWidth",entry.Width)
        model:SetAttribute("MapDepth",entry.Depth)
        model:SetAttribute("MapId",entry.Id)
        model:SetAttribute("DisplayName",entry.Name)
        model:SetAttribute("MovementDesign","Run / sprint / dodge. Raised routes use ramps.")
        if groundColors[entry.Id] then ground(model,entry,groundColors[entry.Id],Enum.Material.Slate) end
        builders[entry.Id](model,entry)
        if entry.Id=="pirate" then
            local quarter=group(model,"HarborQuarter")
            facade(quarter,"HarborTavern",-68,44,34,18,20,RGB(162,136,99),RGB(166,189,169),Enum.Material.WoodPlanks)
            themedStall(quarter,-15,-62,RGB(136,104,70),RGB(46,118,129),"COVE SUPPLIES",18)
            themedStall(quarter,10,66,RGB(136,104,70),RGB(182,112,74),"SAILMAKER",18)
            for _,x in ipairs({-26,24}) do
                themedCrate(quarter,x,12,9,10,RGB(169,132,85))
                lamp(quarter,x,-19,RGB(244,204,139),13)
            end
        end
        if groundColors[entry.Id] then boundaries(model,entry,groundColors[entry.Id]:Lerp(WHITE,.1)) end
        safeSpawns(model,entry)
        entry.Model=model
        table.insert(result,model)
    end
    return result
end
function MapBuilder.GetGeometry()
    local result={}
    for _,entry in ipairs(catalog) do table.insert(result,entry.Geometry) end
    return result
end
function MapBuilder.GetCatalog()
    local result={}
    for _,e in ipairs(catalog) do table.insert(result,{Id=e.Id,Name=e.Name,Width=e.Width,Depth=e.Depth,Description=e.Description}) end
    return result
end
function MapBuilder.BuildLobby(parent)
    surfaceLayer=0
    local model=group(parent,"Lobby","Model")
    local e={Name="Lobby",Width=148,Depth=118,Layout={},Geometry={Ramps={},Decks={},Obstacles={}}}
    local floor=ground(model,e,RGB(125,147,106),Enum.Material.Grass)
    local p=group(model,"GardenReception")
    paving(p,"ReceptionSquare",0,10,108,80,RGB(183,182,157),Enum.Material.Cobblestone)
    tiles(p,0,10,104,78,8,RGB(146,149,131))
    deck(p,e,"ViewingTerrace",0,-37,100,24,5,false)
    for _,s in ipairs({-1,1}) do
        ramp(p,e,"ReceptionRamp",s*39,-5,s*39,-25,5,16,Enum.Material.Concrete,STONE)
        planter(p,nil,"WelcomeGarden",s*52,26,16,18,false,true)
        planter(p,nil,"CornerGarden",s*59,-38,13,20,false,true)
        bench(p,s*31,35,0)
        lamp(p,s*29,22,RGB(245,224,174),12)
        kiosk(p,s*42,45,s<0 and "HOW TO PLAY" or "READY TO RUN")
    end
    rail(p,"TerraceFrontRail",V(-28,5,-25),V(28,5,-25),INK)
    rail(p,"TerraceBackRail",V(-50,5,-49),V(50,5,-49),INK)
    local board=box(p,"WelcomeBoard",0,13,-43,44,8,1,INK,Enum.Material.Metal,false)
    sign(board,"HUSS A BOMB","RUN / SPRINT / DODGE",SAGE)
    for _,x in ipairs({-21,21}) do box(p,"WelcomePost",x,8.5,-43,.9,7,.9,INK,Enum.Material.Metal,false) end
    boundaries(model,e,RGB(144,155,130))
    local spawn=part(model,"LobbySpawn",V(6,1,6),V(0,0.5,25),WHITE,nil,false,nil,"SpawnLocation")
    spawn.Transparency,spawn.Neutral,spawn.Duration=1,true,0
    model:SetAttribute("BombTagGenerated",VERSION)
    return model
end
return MapBuilder
