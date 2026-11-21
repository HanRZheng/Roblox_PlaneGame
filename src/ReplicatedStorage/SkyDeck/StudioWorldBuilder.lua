--!nocheck

-- Around the World: edit-mode map builder.
-- From Roblox Studio's Command Bar (while NOT playing), run:
-- require(game.ReplicatedStorage.SkyDeck.StudioWorldBuilder).Build()

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local AirportCatalog = require(script.Parent:WaitForChild("AirportCatalog"))
local AirportInteriors = require(script.Parent:WaitForChild("AirportInteriors"))
local Layout = require(script.Parent:WaitForChild("AirportLayout"))
local AirportSurfaces = require(script.Parent:WaitForChild("AirportSurfaces"))
local AirportTerrain = require(script.Parent:WaitForChild("AirportTerrain"))

local Builder = {}

local MAX_PART_AXIS = 2000

local function makePart(parent, name, size, cframe, color, material, transparency, canCollide)
	-- Roblox clamps oversized BaseParts. Split long runways, aprons, terminals,
	-- roads, and ground reserves into perfectly adjoining local-space tiles.
	local xCount = math.max(1, math.ceil(size.X / MAX_PART_AXIS))
	local yCount = math.max(1, math.ceil(size.Y / MAX_PART_AXIS))
	local zCount = math.max(1, math.ceil(size.Z / MAX_PART_AXIS))
	local tileSize = Vector3.new(size.X / xCount, size.Y / yCount, size.Z / zCount)
	local firstPart = nil
	for xIndex = 1, xCount do
		for yIndex = 1, yCount do
			for zIndex = 1, zCount do
				local offset = Vector3.new(
					(xIndex - (xCount + 1) / 2) * tileSize.X,
					(yIndex - (yCount + 1) / 2) * tileSize.Y,
					(zIndex - (zCount + 1) / 2) * tileSize.Z
				)
				local part = Instance.new("Part")
				part.Name = name
				part.Size = tileSize
				part.CFrame = cframe * CFrame.new(offset)
				part.Color = color
				part.Material = material or Enum.Material.SmoothPlastic
				part.Transparency = transparency or 0
				part.Anchored = true
				part.CanCollide = canCollide ~= false
				part.CastShadow = transparency ~= 1
				part.TopSurface = Enum.SurfaceType.Smooth
				part.BottomSurface = Enum.SurfaceType.Smooth
				part.Parent = parent
				firstPart = firstPart or part
			end
		end
	end
	return firstPart
end

local function addBillboard(parent, text, accent, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WorldLabel"
	billboard.Size = UDim2.fromOffset(190, 40)
	billboard.StudsOffsetWorldSpace = offset or Vector3.new(0, 70, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 1400
	billboard.Parent = parent

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(8, 20, 31)
	background.BackgroundTransparency = 0.32
	background.BorderSizePixel = 0
	background.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = background

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 1
	stroke.Transparency = 0.12
	stroke.Parent = background

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -14, 1, 0)
	label.Position = UDim2.fromOffset(7, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = background
end

local function terrainColor(kind)
	if kind == "Desert" then return Color3.fromRGB(183, 128, 72) end
	if kind == "Alpine" then return Color3.fromRGB(94, 133, 107) end
	if kind == "Tropical" then return Color3.fromRGB(72, 159, 96) end
	if kind == "Urban" then return Color3.fromRGB(82, 132, 91) end
	return Color3.fromRGB(71, 140, 86)
end

local function makeWedge(parent, name, size, cframe, color, material, transparency, canCollide)
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = canCollide ~= false
	part.CastShadow = transparency ~= 1
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createConnectedOcean(parent)
	local existing = parent:FindFirstChild("ConnectedOcean")
	if existing then return existing end
	local ocean = Instance.new("Folder")
	ocean.Name = "ConnectedOcean"
	ocean.Parent = parent
	local tileSize = 2000
	for x = -Layout.OceanExtent, Layout.OceanExtent, tileSize do
		for z = -Layout.OceanExtent, Layout.OceanExtent, tileSize do
			local shade = ((x + z) / tileSize) % 2 == 0 and Color3.fromRGB(24, 119, 167) or Color3.fromRGB(27, 128, 176)
			local tile = makePart(ocean, "WaterTile", Vector3.new(tileSize, 2, tileSize), CFrame.new(x, -1, z), shade, Enum.Material.Glass, 0.18, false)
			tile.Reflectance = 0.12
			tile.CanTouch = false
			tile.CanQuery = false
			tile.CastShadow = false
		end
	end
	return ocean
end

local function createTree(parent, position, terrain, random, index)
	local tree = Instance.new("Model")
	tree.Name = terrain .. "Tree" .. index
	tree.Parent = parent
	local height = random:NextNumber(24, 43)
	local trunkColor = Color3.fromRGB(91, 66, 43)
	local green = terrain == "Alpine" and Color3.fromRGB(43, 91, 66) or Color3.fromRGB(55, 120, 65)
	local trunk = makePart(tree, "TaperedTrunk", Vector3.new(height, 2.7, 2.7), CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), trunkColor, Enum.Material.Wood)
	trunk.Shape = Enum.PartType.Cylinder

	if terrain == "Tropical" then
		for frond = 1, 8 do
			local angle = (frond - 1) * math.pi / 4 + random:NextNumber(-0.15, 0.15)
			local length = random:NextNumber(13, 19)
			local direction = Vector3.new(math.cos(angle), -0.22, math.sin(angle))
			local center = position + Vector3.new(0, height, 0) + direction * length * 0.42
			makePart(tree, "PalmFrond" .. frond, Vector3.new(1.15, 0.38, length), CFrame.lookAt(center, center + direction) * CFrame.Angles(0, 0, math.rad(random:NextNumber(-8, 8))), Color3.fromRGB(49, 132, 65), Enum.Material.Grass, 0, false)
		end
	elseif terrain == "Alpine" then
		for tier = 1, 4 do
			local tierY = height * (0.48 + tier * 0.12)
			local width = height * (0.46 - tier * 0.055)
			for side = 0, 3 do
				makeWedge(tree, "PineBranch" .. tier .. "_" .. side, Vector3.new(width, 4.2, width * 0.58), CFrame.new(position + Vector3.new(0, tierY, 0)) * CFrame.Angles(0, math.rad(side * 90), 0), green, Enum.Material.Grass, 0, false)
			end
		end
	else
		for cluster = 1, 7 do
			local angle = cluster * 2.399
			local distance = random:NextNumber(3.5, 8.5)
			local offset = Vector3.new(math.cos(angle) * distance, height * random:NextNumber(0.72, 1.02), math.sin(angle) * distance)
			makeWedge(tree, "LeafCluster" .. cluster, Vector3.new(random:NextNumber(7, 12), random:NextNumber(6, 10), random:NextNumber(8, 14)), CFrame.new(position + offset) * CFrame.Angles(random:NextNumber(-0.25, 0.25), angle, random:NextNumber(-0.25, 0.25)), green:Lerp(Color3.fromRGB(82, 145, 70), cluster / 12), Enum.Material.Grass, 0, false)
		end
	end
end

local function createTiledIsland(model, airport)
	local tileSize = 1200
	local maximumAspect = math.max(airport.IslandAspectX or 1, airport.IslandAspectZ or 1)
	local tileCount = math.ceil(airport.IslandRadius * maximumAspect * 1.18 / tileSize)
	local grassColor = terrainColor(airport.Terrain)
	local islandCF = CFrame.new(airport.Position) * CFrame.Angles(0, math.rad(-airport.Heading), 0)
	for xIndex = -tileCount, tileCount do
		for zIndex = -tileCount, tileCount do
			local localX = xIndex * tileSize
			local localZ = zIndex * tileSize
			if Layout.TileTouchesIsland(airport, localX, localZ, tileSize) then
				makePart(model, "IslandShore", Vector3.new(tileSize + 120, 8, tileSize + 120), islandCF * CFrame.new(localX, -2.2, localZ), Color3.fromRGB(211, 187, 128), Enum.Material.Sand)
				makePart(model, "Island", Vector3.new(tileSize + 4, 42, tileSize + 4), islandCF * CFrame.new(localX, -19, localZ), grassColor, Enum.Material.Grass)
			end
		end
	end
end

local function clearOfChildAirports(parentAirport, worldPosition, margin)
	for _, childAirport in ipairs(AirportCatalog.List) do
		if childAirport.ParentIslandCode == parentAirport.Code then
			local childCF = CFrame.new(childAirport.Position) * CFrame.Angles(0, math.rad(-childAirport.Heading), 0)
			local localPosition = childCF:PointToObjectSpace(worldPosition)
			local startX, endX, halfZ = Layout.GroundReserveBounds(childAirport)
			if localPosition.X > startX - margin and localPosition.X < endX + margin and math.abs(localPosition.Z) < halfZ + margin then
				return false
			end
		end
	end
	return true
end

local function createAirport(airportsFolder, airport)
	local model = Instance.new("Model")
	model.Name = airport.Code .. " - " .. airport.Name
	model:SetAttribute("Code", airport.Code)
	model:SetAttribute("Heading", airport.Heading)
	model:SetAttribute("RunwayLength", airport.RunwayLength)
	model:SetAttribute("RunwayCount", airport.RunwayCount or 1)
	model:SetAttribute("RunwayLayout", airport.RunwayLayout or "PARALLEL_STAGGERED")
	model:SetAttribute("Gates", airport.Gates or 0)
	model.Parent = airportsFolder

	if not airport.ParentIslandCode then
		createTiledIsland(model, airport)
	end

	local airportCF = CFrame.new(airport.Position + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, math.rad(-airport.Heading), 0)
	local groundStartX, groundEndX, groundHalfZ = Layout.GroundReserveBounds(airport)
	local groundCenterX = (groundStartX + groundEndX) / 2
	makePart(model, "AirportLandReserve", Vector3.new(groundEndX - groundStartX, 1.10, groundHalfZ * 2), airportCF * CFrame.new(groundCenterX, -0.93, 0), terrainColor(airport.Terrain), Enum.Material.Grass)
	AirportSurfaces.Build(model, airportCF, airport, makePart)
	AirportInteriors.Build(model, airportCF, airport, makePart)
	AirportTerrain.Build(model, airportCF, airport, makePart)

	local terminalStartX = Layout.TerminalBounds(airport)
	local tower = makePart(model, "Tower", Vector3.new(13, 73, 13), airportCF * CFrame.new(terminalStartX + 80, 36, 700), Color3.fromRGB(220, 225, 223), Enum.Material.Concrete)
	local cab = makePart(model, "TowerCab", Vector3.new(35, 15, 35), tower.CFrame * CFrame.new(0, 42, 0), Color3.fromRGB(28, 69, 88), Enum.Material.Glass, 0.05, false)
	cab.Shape = Enum.PartType.Ball

	local random = Random.new(string.byte(airport.Code, 1) * 100 + string.byte(airport.Code, 2))
	local buildingColors = {
		Color3.fromRGB(215, 201, 179),
		Color3.fromRGB(199, 213, 221),
		Color3.fromRGB(211, 216, 199),
		Color3.fromRGB(188, 199, 196),
	}
	for index = 1, (airport.BuildingCount or 46) do
		local position
		local angle = 0
		for _ = 1, 30 do
			angle = random:NextNumber(0, math.pi * 2)
			local inlandLimit = math.min(airport.IslandRadius * 0.60, airport.IslandRadius - Layout.SceneryShoreMargin)
			local distance = random:NextNumber(math.min(850, inlandLimit * 0.55), inlandLimit)
			local candidate = airport.Position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			local runwayLocal = airportCF:PointToObjectSpace(candidate)
			local facilityEndX = Layout.FacilityEndX(airport)
			local clearOfMovement = not Layout.IsMovementZone(airport, runwayLocal.X, runwayLocal.Z, 180)
			local clearOfAirport = not (runwayLocal.X > Layout.SceneryPositiveClearX and runwayLocal.X < facilityEndX and runwayLocal.Z > Layout.FacilityZMin and runwayLocal.Z < Layout.FacilityZMax)
			local safelyInland = Layout.IsInsideIsland(airport, runwayLocal.X, runwayLocal.Z, Layout.SceneryShoreMargin + 80)
			if safelyInland and clearOfMovement and clearOfAirport and clearOfChildAirports(airport, candidate, 180) then
				position = candidate
				break
			end
		end
		if not position then
			local fallbackZ = ((index - 1) % 9 - 4) * 80
			local fallback = airportCF:PointToWorldSpace(Vector3.new(-airport.IslandRadius * 0.52, 0, fallbackZ))
			if clearOfChildAirports(airport, fallback, 180) then position = fallback end
		end
		if not position then continue end
		local width = random:NextNumber(28, 64)
		local height = random:NextNumber(18, 105)
		local raisedPosition = Vector3.new(position.X, height / 2, position.Z)
		local buildingCF = CFrame.new(raisedPosition) * CFrame.Angles(0, angle, 0)
		local building = makePart(model, "CityBuilding", Vector3.new(width, height, width), buildingCF, buildingColors[(index - 1) % #buildingColors + 1], Enum.Material.Concrete)
		for band = -1, 1, 2 do
			local windowY = band * height * 0.20
			makePart(model, "BuildingWindows", Vector3.new(width * 0.72, math.max(2.5, height * 0.15), 0.35), building.CFrame * CFrame.new(0, windowY, -width / 2 - 0.19), Color3.fromRGB(48, 101, 127), Enum.Material.Glass, 0.12, false)
			makePart(model, "BuildingWindows", Vector3.new(0.35, math.max(2.5, height * 0.15), width * 0.72), building.CFrame * CFrame.new(width / 2 + 0.19, windowY, 0), Color3.fromRGB(48, 101, 127), Enum.Material.Glass, 0.12, false)
		end
	end

	local vegetation = Instance.new("Folder")
	vegetation.Name = "Vegetation"
	vegetation.Parent = model
	local treeCount = airport.TreeCount or (airport.Terrain == "Desert" and 4 or 18)
	for treeIndex = 1, treeCount do
		local treePosition
		for _ = 1, 35 do
			local treeAngle = random:NextNumber(0, math.pi * 2)
			local inlandLimit = math.min(airport.IslandRadius * 0.62, airport.IslandRadius - Layout.SceneryShoreMargin)
			local treeDistance = random:NextNumber(math.min(900, inlandLimit * 0.55), inlandLimit)
			local candidate = airport.Position + Vector3.new(math.cos(treeAngle) * treeDistance, 1.5, math.sin(treeAngle) * treeDistance)
			local runwayLocal = airportCF:PointToObjectSpace(candidate)
			local facilityEndX = Layout.FacilityEndX(airport)
			local clearOfMovement = not Layout.IsMovementZone(airport, runwayLocal.X, runwayLocal.Z, 180)
			local clearOfApron = not (runwayLocal.X > Layout.SceneryPositiveClearX and runwayLocal.X < facilityEndX and runwayLocal.Z > Layout.FacilityZMin and runwayLocal.Z < Layout.FacilityZMax)
			local safelyInland = Layout.IsInsideIsland(airport, runwayLocal.X, runwayLocal.Z, Layout.SceneryShoreMargin + 90)
			if safelyInland and clearOfMovement and clearOfApron and clearOfChildAirports(airport, candidate, 120) then
				treePosition = candidate
				break
			end
		end
		if treePosition then
			createTree(vegetation, treePosition, airport.Terrain == "Desert" and "Tropical" or airport.Terrain, random, treeIndex)
		end
	end

	if airport.Terrain == "Alpine" then
		for index = 1, 8 do
			local height = 30 + index * 2
			local scenicPosition = airportCF:PointToWorldSpace(Vector3.new(-airport.IslandRadius * 0.48, height * 0.30, -620 + index * 150))
			local mountain = makePart(model, "LowAlpineRidge", Vector3.new(210 + index * 15, height, 190 + index * 12), CFrame.new(scenicPosition), Color3.fromRGB(105, 127, 116), Enum.Material.Slate)
			mountain.Shape = Enum.PartType.Ball
			mountain.CanTouch = false
		end
	elseif airport.Terrain == "Desert" then
		for index = 1, 7 do
			local height = 20 + index * 2
			local scenicPosition = airportCF:PointToWorldSpace(Vector3.new(-airport.IslandRadius * 0.50, height * 0.30, -560 + index * 160))
			local mesa = makePart(model, "LowDesertMesa", Vector3.new(180 + index * 14, height, 160 + index * 12), CFrame.new(scenicPosition), Color3.fromRGB(150, 88, 54), Enum.Material.Sandstone)
			mesa.Shape = Enum.PartType.Ball
			mesa.CanTouch = false
		end
	end

	local marker = makePart(model, "AirportMarker", Vector3.new(4, 4, 4), CFrame.new(airport.Position), airport.Accent, Enum.Material.Neon, 1, false)
	addBillboard(marker, airport.Code .. "  •  " .. airport.Name, airport.Accent, Vector3.new(0, 115, 0))

	local spawn = makePart(model, "AircraftSpawn", Vector3.new(6, 1, 6), airportCF * CFrame.new(Layout.FirstGateX, 5, 25) * CFrame.Angles(0, math.rad(180), 0), airport.Accent, Enum.Material.Neon, 1, false)
	spawn:SetAttribute("AirportCode", airport.Code)
end

function Builder.Build(rebuild)
	if RunService:IsRunning() then
		error("Stop Play/Test mode before building the editable world.")
	end

	local existing = workspace:FindFirstChild("SkyDeckWorld")
	if existing
		and not rebuild
		and existing:GetAttribute("EditableWorldVersion") == Layout.WorldVersion
		and existing:GetAttribute("GeometryRevision") == Layout.GeometryRevision then
		warn("Around the World already exists in Edit mode. Existing edits were preserved.")
		return existing
	end
	if existing and not rebuild then
		local backups = ServerStorage:FindFirstChild("AroundTheWorldBackups") or Instance.new("Folder")
		backups.Name = "AroundTheWorldBackups"
		backups.Parent = ServerStorage
		existing.Name = "SkyDeckWorld_PreV31_" .. tostring(os.time())
		existing.Parent = backups
		warn("The older editable map was backed up in ServerStorage/AroundTheWorldBackups before V31 was built.")
	elseif existing then
		existing:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "SkyDeckWorld"
	world:SetAttribute("EditorBuilt", true)
	world:SetAttribute("EditableWorldVersion", Layout.WorldVersion)
	world:SetAttribute("WorldVersion", Layout.WorldVersion)
	world:SetAttribute("GeometryRevision", Layout.GeometryRevision)
	world:SetAttribute("RunwayLayoutRevision", Layout.RunwayLayoutRevision)
	world:SetAttribute("TerminalShapeRevision", Layout.TerminalShapeRevision)
	world:SetAttribute("Humidity", 0.76)
	world:SetAttribute("RainIntensity", 0.12)
	world:SetAttribute("WeatherWetness", 0.42)
	world.Parent = workspace

	local airportsFolder = Instance.new("Folder")
	airportsFolder.Name = "Airports"
	airportsFolder.Parent = world

	local planesFolder = Instance.new("Folder")
	planesFolder.Name = "Aircraft"
	planesFolder.Parent = world

	local trafficFolder = Instance.new("Folder")
	trafficFolder.Name = "AI Traffic"
	trafficFolder.Parent = world

	Lighting.Brightness = 2.3
	Lighting.ClockTime = 13.5
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(95, 116, 128)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 146, 151)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(199, 229, 240)
	atmosphere.Decay = Color3.fromRGB(106, 144, 168)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.3
	atmosphere.Parent = Lighting

	createConnectedOcean(world)

	local lobbySpawn = Instance.new("SpawnLocation")
	lobbySpawn.Name = "SafeIslandSpawn"
	lobbySpawn.Size = Vector3.new(16, 1, 16)
	lobbySpawn.CFrame = CFrame.new(AirportCatalog.List[1].Position + Vector3.new(Layout.TerminalStartX + 80, 4, 500))
	lobbySpawn.Anchored = true
	lobbySpawn.CanCollide = true
	lobbySpawn.Transparency = 1
	lobbySpawn.Neutral = true
	lobbySpawn.Duration = 0
	lobbySpawn.Parent = world

	for _, airport in ipairs(AirportCatalog.List) do
		createAirport(airportsFolder, airport)
	end

	local clouds = Instance.new("Folder")
	clouds.Name = "Clouds"
	clouds.Parent = world
	local randomCloud = Random.new(8342)
	for cloudIndex = 1, 38 do
		local group = Instance.new("Model")
		group.Name = "LayeredCloud" .. cloudIndex
		group.Parent = clouds
		local basePosition = Vector3.new(randomCloud:NextNumber(-Layout.CloudExtent, Layout.CloudExtent), randomCloud:NextNumber(450, 1100), randomCloud:NextNumber(-Layout.CloudExtent, Layout.CloudExtent))
		local cloudScale = randomCloud:NextNumber(0.8, 1.45)
		for layer = 1, 9 do
			local angle = randomCloud:NextNumber(-0.35, 0.35)
			local offset = Vector3.new((layer - 5) * randomCloud:NextNumber(28, 43), randomCloud:NextNumber(-7, 26), randomCloud:NextNumber(-48, 48))
			local size = Vector3.new(randomCloud:NextNumber(85, 155), randomCloud:NextNumber(16, 34), randomCloud:NextNumber(65, 125)) * cloudScale
			local color = layer <= 3 and Color3.fromRGB(210, 219, 225) or Color3.fromRGB(244, 248, 250)
			local piece = makeWedge(group, "CloudLayer" .. layer, size, CFrame.new(basePosition + offset) * CFrame.Angles(0, angle, layer % 2 == 0 and math.rad(3) or math.rad(-3)), color, Enum.Material.SmoothPlastic, layer <= 3 and 0.25 or 0.16, false)
			piece.CanTouch = false
			piece.CanQuery = false
			piece.CastShadow = false
		end
	end

	print("[Around the World] V31 editable map created. Save the place before testing.")
	return world
end

return Builder
