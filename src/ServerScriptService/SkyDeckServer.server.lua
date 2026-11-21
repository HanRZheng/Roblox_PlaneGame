--!nocheck

-- Around the World
-- Server-authoritative world generation, aircraft spawning, and arcade flight physics.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("SkyDeck")
local AircraftCatalog = require(Shared:WaitForChild("AircraftCatalog"))
local AirportCatalog = require(Shared:WaitForChild("AirportCatalog"))
local AirportInteriors = require(Shared:WaitForChild("AirportInteriors"))
local Layout = require(Shared:WaitForChild("AirportLayout"))
local AirportSurfaces = require(Shared:WaitForChild("AirportSurfaces"))
local AirportTerrain = require(Shared:WaitForChild("AirportTerrain"))
local AircraftAnimationConfig = require(Shared:WaitForChild("AircraftAnimationConfig"))
local AircraftVisualController = require(Shared:WaitForChild("AircraftVisualController"))
local AircraftSilhouetteConfig = require(Shared:WaitForChild("AircraftSilhouetteConfig"))
local AircraftMaterialConfig = require(Shared:WaitForChild("AircraftMaterialConfig"))
local AircraftMeshManifest = require(Shared:WaitForChild("AircraftMeshManifest"))
local AircraftHandlingConfig = require(Shared:WaitForChild("AircraftHandlingConfig"))
local EngineAudioConfig = require(Shared:WaitForChild("EngineAudioConfig"))

local Remotes = Shared:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = Shared

local function remote(name)
	local item = Remotes:FindFirstChild(name) or Instance.new("RemoteEvent")
	item.Name = name
	item.Parent = Remotes
	return item
end

local SpawnPlane = remote("SpawnPlane")
local PlaneControl = remote("PlaneControl")
local PlaneAction = remote("PlaneAction")
local SystemMessage = remote("SystemMessage")
local ReturnToMenu = remote("ReturnToMenu")
local RunMode = remote("RunMode")

local WALK_SPEED = 16
local RUN_SPEED = 28
local PARKING_BRAKE_FORCE = 26

local function configureWalkingCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	humanoid.WalkSpeed = WALK_SPEED
	humanoid.Seated:Connect(function(isSeated)
		if isSeated then humanoid.WalkSpeed = WALK_SPEED end
	end)
end

local function configurePlayer(player)
	player:SetAttribute("SkyDeckReady", true)
	player.CharacterAdded:Connect(configureWalkingCharacter)
	if player.Character then task.spawn(configureWalkingCharacter, player.Character) end
end

RunMode.OnServerEvent:Connect(function(player, wantsToRun)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local isOnFoot = humanoid.Health > 0 and humanoid.SeatPart == nil
	humanoid.WalkSpeed = wantsToRun == true and isOnFoot and RUN_SPEED or WALK_SPEED
end)

local function aircraftAncestor(instance)
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") and current:GetAttribute("AircraftCode") ~= nil then return current end
		current = current.Parent
	end
	return nil
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	local promptParent = prompt and prompt.Parent
	local seat = promptParent
	if prompt and prompt:GetAttribute("AircraftEntryPrompt") == true and promptParent then
		local seatReference = promptParent:FindFirstChild("PilotSeatReference")
		seat = seatReference and seatReference:IsA("ObjectValue") and seatReference.Value or nil
	end
	if not seat then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if seat:IsA("VehicleSeat") and seat:GetAttribute("AircraftPilotSeat") == true then
		local aircraft = aircraftAncestor(seat)
		if aircraft and aircraft:IsA("Model") and aircraft:GetAttribute("OwnerUserId") == player.UserId and seat.Occupant == nil then
			seat:Sit(humanoid)
		else
			SystemMessage:FireClient(player, "COCKPIT UNAVAILABLE", "You can only re-enter your own unoccupied aircraft.")
		end
		return
	end
	if seat:IsA("Seat") and seat:GetAttribute("TerminalSeat") == true then seat:Sit(humanoid) end
end)

local oldWorld = workspace:FindFirstChild("SkyDeckWorld")
local editorWorldIsCurrent = oldWorld
	and oldWorld:GetAttribute("EditorBuilt") == true
	and oldWorld:GetAttribute("EditableWorldVersion") == Layout.WorldVersion
	and oldWorld:GetAttribute("GeometryRevision") == Layout.GeometryRevision
local buildStaticWorld = not editorWorldIsCurrent
if oldWorld and buildStaticWorld then oldWorld:Destroy() end

local world = if buildStaticWorld then Instance.new("Folder") else oldWorld
world.Name = "SkyDeckWorld"
world.Parent = workspace
world:SetAttribute("WorldVersion", Layout.WorldVersion)
world:SetAttribute("GeometryRevision", Layout.GeometryRevision)
world:SetAttribute("RunwayLayoutRevision", Layout.RunwayLayoutRevision)
world:SetAttribute("TerminalShapeRevision", Layout.TerminalShapeRevision)
world:SetAttribute("Humidity", 0.76)
world:SetAttribute("RainIntensity", 0.12)
world:SetAttribute("WeatherWetness", 0.42)

local function worldFolder(name)
	local folder = world:FindFirstChild(name) or Instance.new("Folder")
	folder.Name = name
	folder.Parent = world
	return folder
end

local airportsFolder = worldFolder("Airports")
local planesFolder = worldFolder("Aircraft")
local trafficFolder = worldFolder("AI Traffic")

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
	return billboard
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

local function createAirport(airport)
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
			-- Keep a wide, continuous safety corridor beside and beyond the runway.
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

-- Tiled water stays within Roblox part/terrain limits and cannot drown characters.
createConnectedOcean(world)

local lobbySpawn = world:FindFirstChild("SafeIslandSpawn")
if not lobbySpawn then
	lobbySpawn = Instance.new("SpawnLocation")
	lobbySpawn.Name = "SafeIslandSpawn"
	lobbySpawn.Size = Vector3.new(16, 1, 16)
	lobbySpawn.CFrame = CFrame.new(AirportCatalog.List[1].Position + Vector3.new(Layout.TerminalStartX + 80, 4, 500))
	lobbySpawn.Anchored = true
	lobbySpawn.CanCollide = true
	lobbySpawn.Transparency = 1
	lobbySpawn.Neutral = true
	lobbySpawn.Duration = 0
	lobbySpawn.Parent = world
end

if buildStaticWorld then
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

for _, airport in ipairs(AirportCatalog.List) do
	createAirport(airport)
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
end

local function makeAircraftPart(model, rootCF, name, size, localCF, color, shape, material, transparency)
	local part = makePart(model, name, size, rootCF * localCF, color, material or Enum.Material.SmoothPlastic, transparency or 0, false)
	if shape then part.Shape = shape end
	return part
end

local function makeAircraftWedge(model, rootCF, name, size, localCF, color, material, transparency)
	return makeWedge(model, name, size, rootCF * localCF, color, material or Enum.Material.Metal, transparency or 0, false)
end

local function makeSmoothEllipsoid(model, rootCF, name, size, localCF, color, material, transparency)
	local part = makeAircraftPart(model, rootCF, name, size, localCF, color, nil, material or Enum.Material.SmoothPlastic, transparency or 0)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1, 1)
	mesh.Parent = part
	return part
end

-- Roblox's standard physical scale is 1 stud = 0.28 metres.
local STUDS_PER_METRE = 1 / 0.28
local AIRFRAME_WHITE = Color3.fromRGB(238, 243, 244)
local AIRFRAME_GREY = Color3.fromRGB(202, 211, 214)
local PANEL_GREY = Color3.fromRGB(126, 142, 150)
local WINDOW_GLASS = Color3.fromRGB(21, 47, 63)
local COCKPIT_MASK = Color3.fromRGB(18, 29, 36)

-- Each aircraft family keeps its real-world nose character instead of sharing
-- one generic taper. Values are normalized to fuselage length and radius so
-- variants in the same family retain the correct shape at full scale.
local NOSE_PROFILES = {
	A220 = { Start = 0.384, Span = 0.116, Taper = 0.86, Power = 1.72, Vertical = 0.070, Droop = 0.100, DroopPower = 1.80, FrontZ = 0.439, SideZ = 0.409, FrontX = 0.33, FrontY = 0.54, SideX = 0.870, SideY = 0.38, FrontWidth = 0.48, FrontHeight = 0.30, SideHeight = 0.31, SideDepth = 0.36, SideOffset = 0.20, FrontYaw = 24, SideYaw = 8 },
	A320 = { Start = 0.386, Span = 0.114, Taper = 0.90, Power = 1.40, Vertical = 0.030, Droop = 0.045, DroopPower = 1.62, FrontZ = 0.442, SideZ = 0.414, FrontX = 0.34, FrontY = 0.53, SideX = 0.875, SideY = 0.36, FrontWidth = 0.44, FrontHeight = 0.28, SideHeight = 0.29, SideDepth = 0.32, SideOffset = 0.20, FrontYaw = 21, SideYaw = 7 },
	A330 = { Start = 0.384, Span = 0.116, Taper = 0.87, Power = 1.55, Vertical = 0.045, Droop = 0.070, DroopPower = 1.72, FrontZ = 0.440, SideZ = 0.411, FrontX = 0.34, FrontY = 0.55, SideX = 0.870, SideY = 0.38, FrontWidth = 0.47, FrontHeight = 0.29, SideHeight = 0.30, SideDepth = 0.35, SideOffset = 0.21, FrontYaw = 23, SideYaw = 8 },
	A350 = { Start = 0.386, Span = 0.114, Taper = 0.84, Power = 1.78, Vertical = 0.085, Droop = 0.125, DroopPower = 1.85, FrontZ = 0.441, SideZ = 0.412, FrontX = 0.34, FrontY = 0.54, SideX = 0.875, SideY = 0.38, FrontWidth = 0.46, FrontHeight = 0.29, SideHeight = 0.30, SideDepth = 0.34, SideOffset = 0.21, FrontYaw = 23, SideYaw = 8, HasMask = true, MaskScale = 1.28 },
	A380 = { Start = 0.380, Span = 0.120, Taper = 0.82, Power = 1.62, Vertical = 0.020, Droop = 0.028, DroopPower = 1.55, FrontZ = 0.435, SideZ = 0.402, FrontX = 0.31, FrontY = 0.42, SideX = 0.860, SideY = 0.31, FrontWidth = 0.44, FrontHeight = 0.27, SideHeight = 0.28, SideDepth = 0.36, SideOffset = 0.21, FrontYaw = 21, SideYaw = 6 },
	B737 = { Start = 0.378, Span = 0.122, Taper = 0.975, Power = 1.55, Vertical = 0.035, Droop = 0.055, DroopPower = 1.60, FrontZ = 0.443, SideZ = 0.410, FrontX = 0.32, FrontY = 0.48, SideX = 0.880, SideY = 0.34, FrontWidth = 0.42, FrontHeight = 0.27, SideHeight = 0.27, SideDepth = 0.30, SideOffset = 0.19, FrontYaw = 19, SideYaw = 6 },
	B747 = { Start = 0.382, Span = 0.118, Taper = 0.83, Power = 1.38, Vertical = 0.015, Droop = 0.020, DroopPower = 1.42, FrontZ = 0.436, SideZ = 0.401, FrontX = 0.31, FrontY = 0.60, SideX = 0.850, SideY = 0.49, FrontWidth = 0.43, FrontHeight = 0.27, SideHeight = 0.28, SideDepth = 0.34, SideOffset = 0.21, FrontYaw = 20, SideYaw = 6 },
	B757 = { Start = 0.380, Span = 0.120, Taper = 0.975, Power = 1.52, Vertical = 0.040, Droop = 0.048, DroopPower = 1.58, FrontZ = 0.445, SideZ = 0.411, FrontX = 0.32, FrontY = 0.49, SideX = 0.885, SideY = 0.34, FrontWidth = 0.41, FrontHeight = 0.26, SideHeight = 0.27, SideDepth = 0.30, SideOffset = 0.19, FrontYaw = 19, SideYaw = 6 },
	B767 = { Start = 0.379, Span = 0.121, Taper = 0.970, Power = 1.62, Vertical = 0.050, Droop = 0.060, DroopPower = 1.66, FrontZ = 0.443, SideZ = 0.409, FrontX = 0.33, FrontY = 0.51, SideX = 0.880, SideY = 0.36, FrontWidth = 0.44, FrontHeight = 0.28, SideHeight = 0.29, SideDepth = 0.32, SideOffset = 0.20, FrontYaw = 20, SideYaw = 7 },
	B777 = { Start = 0.384, Span = 0.116, Taper = 0.87, Power = 1.52, Vertical = 0.050, Droop = 0.060, DroopPower = 1.68, FrontZ = 0.442, SideZ = 0.413, FrontX = 0.33, FrontY = 0.52, SideX = 0.875, SideY = 0.37, FrontWidth = 0.46, FrontHeight = 0.29, SideHeight = 0.30, SideDepth = 0.34, SideOffset = 0.21, FrontYaw = 22, SideYaw = 7 },
	B787 = { Start = 0.382, Span = 0.118, Taper = 0.84, Power = 1.82, Vertical = 0.080, Droop = 0.110, DroopPower = 1.82, FrontZ = 0.440, SideZ = 0.410, FrontX = 0.33, FrontY = 0.53, SideX = 0.870, SideY = 0.38, FrontWidth = 0.47, FrontHeight = 0.29, SideHeight = 0.30, SideDepth = 0.36, SideOffset = 0.21, FrontYaw = 23, SideYaw = 8 },
	E2 = { Start = 0.384, Span = 0.116, Taper = 0.86, Power = 1.75, Vertical = 0.075, Droop = 0.105, DroopPower = 1.82, FrontZ = 0.441, SideZ = 0.410, FrontX = 0.33, FrontY = 0.52, SideX = 0.875, SideY = 0.36, FrontWidth = 0.45, FrontHeight = 0.29, SideHeight = 0.29, SideDepth = 0.34, SideOffset = 0.20, FrontYaw = 23, SideYaw = 8 },
	CRJ = { Start = 0.390, Span = 0.110, Taper = 0.94, Power = 1.18, Vertical = 0.020, Droop = 0.020, DroopPower = 1.35, FrontZ = 0.451, SideZ = 0.421, FrontX = 0.31, FrontY = 0.47, SideX = 0.890, SideY = 0.33, FrontWidth = 0.39, FrontHeight = 0.25, SideHeight = 0.26, SideDepth = 0.28, SideOffset = 0.18, FrontYaw = 18, SideYaw = 5 },
}

local COCKPIT_ANGLES = {
	A220 = { FrontPitch = -7, FrontRoll = 4, SidePitch = -4, SideRoll = 4 },
	A320 = { FrontPitch = -4, FrontRoll = 3, SidePitch = -2, SideRoll = 2 },
	A330 = { FrontPitch = -5, FrontRoll = 3, SidePitch = -3, SideRoll = 3 },
	A350 = { FrontPitch = -6, FrontRoll = 4, SidePitch = -3, SideRoll = 4 },
	A380 = { FrontPitch = -2, FrontRoll = 2, SidePitch = -1, SideRoll = 2 },
	B737 = { FrontPitch = -8, FrontRoll = 5, SidePitch = -4, SideRoll = 5 },
	B747 = { FrontPitch = -3, FrontRoll = 2, SidePitch = -2, SideRoll = 2 },
	B757 = { FrontPitch = -7, FrontRoll = 4, SidePitch = -4, SideRoll = 4 },
	B767 = { FrontPitch = -5, FrontRoll = 3, SidePitch = -3, SideRoll = 3 },
	B777 = { FrontPitch = -4, FrontRoll = 3, SidePitch = -2, SideRoll = 3 },
	B787 = { FrontPitch = -6, FrontRoll = 4, SidePitch = -3, SideRoll = 4 },
	E2 = { FrontPitch = -7, FrontRoll = 4, SidePitch = -4, SideRoll = 4 },
	CRJ = { FrontPitch = -8, FrontRoll = 5, SidePitch = -5, SideRoll = 5 },
}

-- Small family-specific surface adjustments used by the V27 windshield,
-- crown/chin blend, radome, and sensor-detail pass. These are visual only.
local NOSE_DETAIL_PROFILES = {
	A220 = { WindowInset = 0.012, CrownFullness = 1.04, ChinFullness = 1.08, SensorScale = 0.92 },
	A320 = { WindowInset = 0.010, CrownFullness = 0.96, ChinFullness = 0.92, SensorScale = 0.90 },
	A330 = { WindowInset = 0.010, CrownFullness = 1.00, ChinFullness = 1.02, SensorScale = 1.00 },
	A350 = { WindowInset = 0.014, CrownFullness = 1.07, ChinFullness = 1.12, SensorScale = 1.00 },
	A380 = { WindowInset = 0.009, CrownFullness = 1.10, ChinFullness = 1.00, SensorScale = 1.10 },
	B737 = { WindowInset = 0.008, CrownFullness = 0.91, ChinFullness = 0.90, SensorScale = 0.88 },
	B747 = { WindowInset = 0.009, CrownFullness = 1.08, ChinFullness = 0.98, SensorScale = 1.08 },
	B757 = { WindowInset = 0.009, CrownFullness = 0.94, ChinFullness = 0.94, SensorScale = 0.92 },
	B767 = { WindowInset = 0.010, CrownFullness = 0.98, ChinFullness = 1.00, SensorScale = 0.98 },
	B777 = { WindowInset = 0.011, CrownFullness = 1.03, ChinFullness = 1.04, SensorScale = 1.04 },
	B787 = { WindowInset = 0.014, CrownFullness = 1.08, ChinFullness = 1.12, SensorScale = 1.00 },
	E2 = { WindowInset = 0.013, CrownFullness = 1.04, ChinFullness = 1.10, SensorScale = 0.88 },
	CRJ = { WindowInset = 0.008, CrownFullness = 0.88, ChinFullness = 0.86, SensorScale = 0.72 },
}

local function createSweptSurface(model, rootCF, name, halfSpan, rootChord, tipChord, rootZ, height, thickness, sweepDegrees, color, segments, flexible, foldingTips, dihedralDegrees)
	local segmentSpan = halfSpan / segments
	local sweepRadians = math.rad(sweepDegrees)
	local dihedralRadians = math.rad(dihedralDegrees or 2)
	local dihedralSlope = dihedralDegrees and math.tan(dihedralRadians) or 0.035
	for _, side in ipairs({ -1, 1 }) do
		for index = 1, segments do
			local distance = (index - 0.5) * segmentSpan
			local ratio = distance / halfSpan
			local chord = rootChord + (tipChord - rootChord) * ratio
			local z = rootZ + distance * math.tan(sweepRadians)
			local sectionThickness = math.max(0.14, thickness * (1 - ratio * 0.58))
			local dihedralY = height + distance * dihedralSlope
			local localCF = CFrame.new(side * distance, dihedralY, z)
				* CFrame.Angles(math.rad(-ratio * 2.35), -side * sweepRadians, -side * math.rad(2))
			local section = makeAircraftPart(
				model,
				rootCF,
				name .. (side < 0 and "L" or "R") .. index,
				Vector3.new(segmentSpan * 1.08, sectionThickness, chord),
				localCF,
				color,
				nil,
				Enum.Material.Metal
			)
			if flexible and ratio >= 0.32 then
				section:SetAttribute("WingFlexPart", true)
				section:SetAttribute("BaseLocalCF", localCF)
				section:SetAttribute("WingFlexFactor", ratio ^ 1.72)
				section:SetAttribute("WingFlexDirection", side)
				section:SetAttribute("ConnectedVisualParent", "WingRootFairing")
				section:SetAttribute("ConnectionVerifiedRevision", 28)
				if foldingTips and ratio >= 0.93 then
					local hingeDistance = halfSpan * 0.93
					section:SetAttribute("FoldingWingtipPart", true)
					section:SetAttribute("FoldPivotCF", CFrame.new(
						side * hingeDistance,
						height + hingeDistance * dihedralSlope,
						rootZ + hingeDistance * math.tan(sweepRadians)
					))
					section:SetAttribute("FoldDirection", side)
				end
			end
		end
	end
end

local function addAircraftLight(model, rootCF, name, position, color, range, lightType, directional, lightRole)
	local lightPart = makeAircraftPart(model, rootCF, name, Vector3.new(0.62, 0.62, 0.62), CFrame.new(position), color, Enum.PartType.Ball, Enum.Material.Neon)
	lightPart:SetAttribute("AircraftLightType", lightType or "NAVIGATION")
	local attachment = Instance.new("Attachment")
	attachment.Name = name .. "Attachment"
	attachment:SetAttribute("AircraftEffectAnchor", true)
	attachment:SetAttribute("AircraftLightType", lightType or "NAVIGATION")
	attachment:SetAttribute("AircraftLightRole", lightRole or string.upper(name))
	attachment:SetAttribute("BaseAttachmentPosition", Vector3.zero)
	attachment.Parent = lightPart
	local light = directional and Instance.new("SpotLight") or Instance.new("PointLight")
	light.Color = color
	light.Brightness = directional and 4.8 or 1.8
	light.Range = range or 18
	light.Shadows = directional == true
	light.Enabled = false
	if light:IsA("SpotLight") then
		light.Face = Enum.NormalId.Front
		light.Angle = lightType == "TAXI" and 62 or 42
	end
	light.Parent = attachment
	return lightPart
end

local function addAircraftEmitter(part, name, effectType, color, lifetime, speed, rate, attachmentPosition)
	local attachment = Instance.new("Attachment")
	attachment.Name = name .. "Attachment"
	attachment.Position = attachmentPosition or Vector3.zero
	attachment:SetAttribute("AircraftEffectAnchor", true)
	attachment:SetAttribute("AircraftEffectType", effectType)
	attachment:SetAttribute("BaseAttachmentPosition", attachment.Position)
	attachment.Parent = part
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter:SetAttribute("AircraftEffectType", effectType)
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(lifetime * 0.78, lifetime * 1.18)
	emitter.Speed = NumberRange.new(speed * 0.72, speed * 1.15)
	emitter.Rate = rate or 0
	emitter.Enabled = false
	emitter.LightEmission = effectType == "CONTRAIL" and 0.18 or 0
	emitter.Drag = effectType == "TIRE_SMOKE" and 1.8 or 0.5
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.EmissionDirection = effectType == "RAIN" and Enum.NormalId.Bottom or Enum.NormalId.Back
	local startSize = effectType == "RAIN" and 0.12 or (effectType == "ENGINE_EXHAUST" and 0.20 or 0.45)
	local endSize = effectType == "RAIN" and 0.05 or (effectType == "ENGINE_EXHAUST" and 1.15 or 2.6)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, startSize),
		NumberSequenceKeypoint.new(1, endSize),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, effectType == "RAIN" and 0.42 or (effectType == "ENGINE_EXHAUST" and 0.62 or 0.30)),
		NumberSequenceKeypoint.new(0.72, effectType == "RAIN" and 0.52 or 0.62),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment
	return emitter
end

local function preserveBeforeVisualUpgradeBackup(model, spec)
	local backupName = spec.Name .. " BeforeVisualUpgrade"
	local existing = ServerStorage:FindFirstChild(backupName)
	if existing then return existing end

	local backup = model:Clone()
	backup.Name = backupName
	backup:SetAttribute("OwnerUserId", 0)
	backup:SetAttribute("NonRunningBackup", true)
	backup:SetAttribute("BackupSourceAircraftCode", spec.Code)
	backup:SetAttribute("BackupPurpose", "BeforeVisualUpgrade")
	for _, item in ipairs(backup:GetDescendants()) do
		if item:IsA("BaseScript") then item.Disabled = true end
		if item:IsA("ProximityPrompt") then item.Enabled = false end
		if item:IsA("BasePart") then item.Anchored = true end
	end
	backup.Parent = ServerStorage
	return backup
end

local function createAirliner(spec, spawnCF, ownerUserId, decorative)
	local model = Instance.new("Model")
	model.Name = (decorative and "AI " or "") .. spec.Code
	model:SetAttribute("AircraftCode", spec.Code)
	model:SetAttribute("AircraftName", spec.Name)
	model:SetAttribute("OwnerUserId", ownerUserId or 0)
	model:SetAttribute("Decorative", decorative == true)
	model.Parent = decorative and trafficFolder or planesFolder

	local scale = spec.Scale
	local length = (spec.LengthM or (52 * scale / STUDS_PER_METRE)) * STUDS_PER_METRE
	local span = (spec.SpanM or (48 * scale / STUDS_PER_METRE)) * STUDS_PER_METRE
	local fullHeight = (spec.HeightM or (10 * scale / STUDS_PER_METRE)) * STUDS_PER_METRE
	local diameter = (spec.WidthM or (5.2 * math.sqrt(scale) / STUDS_PER_METRE)) * STUDS_PER_METRE
	local radius = diameter / 2
	local sweep = spec.Sweep or 28
	local noseProfileName = spec.NoseProfile or "A320"
	local noseProfile = NOSE_PROFILES[noseProfileName] or NOSE_PROFILES.A320
	local cockpitAngles = COCKPIT_ANGLES[noseProfileName] or COCKPIT_ANGLES.A320
	local noseDetails = NOSE_DETAIL_PROFILES[noseProfileName] or NOSE_DETAIL_PROFILES.A320
	local silhouette = AircraftSilhouetteConfig.Get(spec)
	local clearanceWheelDiameter = math.max(1.05, radius * 0.50)
	local tailSkidClearance = radius + clearanceWheelDiameter * 0.88 - radius * 0.70
	local tailSkidArm = length * (0.43 - 0.12)
	local tailStrikeLimit = math.clamp(math.deg(math.atan(tailSkidClearance / math.max(1, tailSkidArm))) - 0.45, 4.8, 7.0)
	local noseStations = decorative and 22 or 48
	local tailStations = decorative and 20 or 42
	local wingSegments = decorative and 28 or 54
	local stabilizerSegments = decorative and 16 or 30
	model:SetAttribute("Length", length)
	model:SetAttribute("Span", span)
	model:SetAttribute("FuselageDiameter", diameter)
	model:SetAttribute("StallSpeed", spec.StallSpeed or 120)
	model:SetAttribute("CruiseSpeed", spec.CruiseSpeed or 450)
	model:SetAttribute("TailStrikeLimit", tailStrikeLimit)
	model:SetAttribute("RealLengthM", spec.LengthM or 0)
	model:SetAttribute("RealSpanM", spec.SpanM or 0)
	model:SetAttribute("RealHeightM", spec.HeightM or 0)
	model:SetAttribute("NoseProfile", noseProfileName)
	model:SetAttribute("VisualDetailRevision", 28)
	model:SetAttribute("NoseDetailRevision", 27)
	model:SetAttribute("DoorBlendRevision", 28)
	model:SetAttribute("AnimationConfigRevision", 28)
	model:SetAttribute("EffectsConfigRevision", 29)
	model:SetAttribute("ConfiguredEngineCount", spec.Engines or 2)
	model:SetAttribute("SilhouetteProfile", noseProfileName)
	model:SetAttribute("SilhouetteProfileSource", "REAL_DIMENSIONS_PLUS_REFERENCE_ESTIMATES")
	model:SetAttribute("FoldingTips", spec.FoldingTips == true)
	model:SetAttribute("EngineArchitecture", spec.EngineArchitecture or "NARROW_HIGH_BYPASS")
	model:SetAttribute("HandlingProfile", spec.Class or "Narrow-body")

	local root = makeAircraftPart(model, CFrame.new(), "Root", Vector3.new(1, 1, 1), CFrame.new(), Color3.new(), nil, Enum.Material.SmoothPlastic, 1)
	model.PrimaryPart = root

	local function configureControlSurface(part, surfaceType, baseLocalCF, direction, maxAngle)
		part:SetAttribute("ControlSurfaceType", surfaceType)
		part:SetAttribute("VisualChannel", surfaceType)
		part:SetAttribute("BaseLocalCF", baseLocalCF)
		part:SetAttribute("ControlDirection", direction or 1)
		part:SetAttribute("ControlMaxAngle", maxAngle)
		part:SetAttribute("HingeOffset", Vector3.new(0, 0, -part.Size.Z / 2))
		part:SetAttribute("ConnectedVisualParent", surfaceType == "RUDDER" and "SculptedVerticalStabilizer" or (surfaceType == "ELEVATOR" and "HorizontalStabilizer" or "MainWing"))
		part:SetAttribute("ConnectionVerifiedRevision", 28)
	end

	local function configureWingFlex(part, baseLocalCF, factor, direction, isStatic)
		part:SetAttribute("BaseLocalCF", baseLocalCF)
		part:SetAttribute("WingFlexFactor", math.clamp(factor, 0, 1.18))
		part:SetAttribute("WingFlexDirection", direction)
		part:SetAttribute("ConnectedVisualParent", string.find(part.Name, "MainWing", 1, true) and "WingRootFairing" or "MainWing")
		part:SetAttribute("ConnectionVerifiedRevision", 28)
		if isStatic then part:SetAttribute("WingFlexPart", true) end
	end

	local function noseCrossSection(stationZ)
		local ratio = math.clamp(((-stationZ / length) - noseProfile.Start) / noseProfile.Span, 0, 1)
		local sectionDiameter = diameter * (1 - noseProfile.Taper * ratio ^ noseProfile.Power)
		local sectionVertical = sectionDiameter * (1 - noseProfile.Vertical * ratio ^ 1.4) * silhouette.FuselageVerticalRatio
		local sectionY = -radius * (0.010 + noseProfile.Droop * ratio ^ noseProfile.DroopPower)
		return sectionDiameter / 2, sectionVertical / 2, sectionY
	end

	local function noseSurfaceX(stationZ, surfaceY)
		local halfWidth, halfHeight, centerY = noseCrossSection(stationZ)
		local normalizedY = math.clamp((surfaceY - centerY) / math.max(0.05, halfHeight), -0.96, 0.96)
		return halfWidth * math.sqrt(math.max(0.02, 1 - normalizedY * normalizedY))
	end

	-- Multi-section fuselage with closely overlapping ellipsoids creates a smooth
	-- taper while the selected family profile controls bluntness, droop, and crown.
	local cabinLength = length * 0.78
	local body = makeAircraftPart(model, root.CFrame, "Fuselage", Vector3.new(cabinLength, diameter * silhouette.FuselageVerticalRatio, diameter), CFrame.Angles(0, math.rad(90), 0), AIRFRAME_WHITE, Enum.PartType.Cylinder, Enum.Material.SmoothPlastic)
	body:SetAttribute("AircraftBody", true)
	for ringIndex, ringRatio in ipairs({ -0.31, -0.20, -0.08, 0.06, 0.19, 0.31 }) do
		makeAircraftPart(model, root.CFrame, "FuselagePanelRing" .. ringIndex, Vector3.new(0.07, diameter * 1.006, diameter * 1.006), CFrame.new(0, 0, length * ringRatio) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(151, 165, 170), Enum.PartType.Cylinder, Enum.Material.Metal, 0.76)
	end
	for index = 1, noseStations do
		local ratio = index / noseStations
		local stationZ = -length * (noseProfile.Start + ratio * noseProfile.Span)
		local stationDiameter = diameter * (1 - noseProfile.Taper * ratio ^ noseProfile.Power)
		local verticalDiameter = stationDiameter * (1 - noseProfile.Vertical * ratio ^ 1.4) * silhouette.FuselageVerticalRatio
		local stationDepth = length * (decorative and 0.010 or 0.0068)
		local noseY = -radius * (0.010 + noseProfile.Droop * ratio ^ noseProfile.DroopPower)
		makeSmoothEllipsoid(model, root.CFrame, "SmoothNoseStation" .. index, Vector3.new(stationDiameter, verticalDiameter, stationDepth), CFrame.new(0, noseY, stationZ), AIRFRAME_WHITE, Enum.Material.SmoothPlastic)
	end
	-- Thin crown and chin transition ellipsoids soften the profile around the
	-- windshield/radome junction without changing the aircraft collision shape.
	for blendIndex, blendRatio in ipairs({ 0.20, 0.38, 0.56 }) do
		local blendZ = -length * (noseProfile.Start + noseProfile.Span * blendRatio)
		local halfWidth, halfHeight, centerY = noseCrossSection(blendZ)
		local blendDepth = length * 0.018
		makeSmoothEllipsoid(model, root.CFrame, "NoseCrownBlend" .. blendIndex, Vector3.new(halfWidth * 1.48, radius * 0.11 * noseDetails.CrownFullness, blendDepth), CFrame.new(0, centerY + halfHeight * 0.91, blendZ), AIRFRAME_WHITE, Enum.Material.SmoothPlastic)
		makeSmoothEllipsoid(model, root.CFrame, "NoseChinBlend" .. blendIndex, Vector3.new(halfWidth * 1.34, radius * 0.12 * noseDetails.ChinFullness, blendDepth), CFrame.new(0, centerY - halfHeight * 0.91, blendZ), AIRFRAME_WHITE, Enum.Material.SmoothPlastic)
	end
	for index = 1, tailStations do
		local ratio = index / tailStations
		local stationZ = length * (0.388 + ratio * 0.108)
		local stationDiameter = diameter * (1 - 0.82 * ratio ^ 1.25)
		local stationDepth = length * (decorative and 0.011 or 0.0075)
		makeSmoothEllipsoid(model, root.CFrame, "SmoothTailStation" .. index, Vector3.new(stationDiameter, stationDiameter, stationDepth), CFrame.new(0, radius * (0.025 + ratio * 0.09), stationZ), AIRFRAME_WHITE, Enum.Material.SmoothPlastic)
	end

	-- Original SkyDeck livery bands sit on the sides rather than passing through the cabin.
	for _, side in ipairs({ -1, 1 }) do
		makeAircraftPart(model, root.CFrame, "LiveryStripe" .. side, Vector3.new(0.14, math.max(0.26, radius * 0.12), length * 0.70), CFrame.new(side * radius * 0.995, -radius * 0.03, 0), spec.Color, nil, Enum.Material.SmoothPlastic)
		local titlePanel = makeAircraftPart(model, root.CFrame, "AroundWorldTitle" .. side, Vector3.new(0.10, radius * 0.46, length * 0.16), CFrame.new(side * radius * 1.006, radius * 0.05, -length * 0.18), AIRFRAME_WHITE, nil, Enum.Material.SmoothPlastic, 1)
		local titleGui = Instance.new("SurfaceGui")
		titleGui.Name = "OriginalLiveryMark"
		titleGui.Face = side > 0 and Enum.NormalId.Right or Enum.NormalId.Left
		titleGui.CanvasSize = Vector2.new(600, 160)
		titleGui.LightInfluence = 0.18
		titleGui.Parent = titlePanel
		local titleText = Instance.new("TextLabel")
		titleText.Size = UDim2.fromScale(1, 1)
		titleText.BackgroundTransparency = 1
		titleText.Font = Enum.Font.GothamBold
		titleText.Text = "AROUND THE WORLD"
		titleText.TextColor3 = spec.Color
		titleText.TextScaled = true
		titleText.Parent = titleGui
	end

	-- A380 full double deck and 747 forward upper-deck hump.
	if spec.UpperDeck then
		makeAircraftPart(model, root.CFrame, "UpperDeckHump", Vector3.new(length * 0.34, diameter * 0.72, diameter * 0.72), CFrame.new(0, radius * 0.58, -length * 0.18) * CFrame.Angles(0, math.rad(90), 0), AIRFRAME_WHITE, Enum.PartType.Cylinder, Enum.Material.SmoothPlastic)
	elseif spec.Decks == 2 then
		makeAircraftPart(model, root.CFrame, "UpperDeckCrown", Vector3.new(cabinLength * 0.94, diameter * 0.72, diameter * 0.72), CFrame.new(0, radius * 0.43, 0) * CFrame.Angles(0, math.rad(90), 0), AIRFRAME_WHITE, Enum.PartType.Cylinder, Enum.Material.SmoothPlastic)
	end

	-- Cockpit glazing uses the same family profile as the radome, keeping narrow,
	-- wide-body, double-deck, and modern wraparound layouts visually distinct.
	local frontWindowZ = -length * noseProfile.FrontZ
	local sideWindowZ = -length * noseProfile.SideZ
	local frontWindowY = radius * noseProfile.FrontY
	local sideWindowY = radius * noseProfile.SideY
	local frontPaneX = math.min(noseSurfaceX(frontWindowZ, frontWindowY) * 0.70, radius * noseProfile.FrontX * 1.10)
	local sidePaneX = noseSurfaceX(sideWindowZ, sideWindowY) + 0.04
	local recessedFrontWindowZ = frontWindowZ + radius * noseDetails.WindowInset
	local recessedSidePaneX = sidePaneX - radius * noseDetails.WindowInset
	if noseProfile.HasMask then
		local maskScale = noseProfile.MaskScale or 1.12
		for _, side in ipairs({ -1, 1 }) do
			makeAircraftPart(model, root.CFrame, noseProfileName .. "FrontWindowMask" .. side, Vector3.new(radius * noseProfile.FrontWidth * maskScale, radius * noseProfile.FrontHeight * maskScale, 0.20), CFrame.new(side * frontPaneX, frontWindowY, frontWindowZ) * CFrame.Angles(math.rad(cockpitAngles.FrontPitch), -side * math.rad(noseProfile.FrontYaw), side * math.rad(cockpitAngles.FrontRoll)), COCKPIT_MASK, nil, Enum.Material.SmoothPlastic)
			local maskDepth = radius * (noseProfile.SideDepth + noseProfile.SideOffset * 2) * maskScale
			makeAircraftPart(model, root.CFrame, noseProfileName .. "SideWindowMask" .. side, Vector3.new(0.20, radius * noseProfile.SideHeight * maskScale, maskDepth), CFrame.new(side * sidePaneX, sideWindowY, sideWindowZ) * CFrame.Angles(math.rad(cockpitAngles.SidePitch), side * math.rad(noseProfile.SideYaw), 0), COCKPIT_MASK, nil, Enum.Material.SmoothPlastic)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		makeAircraftPart(model, root.CFrame, "CockpitFrontPane" .. side, Vector3.new(radius * noseProfile.FrontWidth, radius * noseProfile.FrontHeight, 0.22), CFrame.new(side * frontPaneX, frontWindowY, recessedFrontWindowZ) * CFrame.Angles(math.rad(cockpitAngles.FrontPitch), -side * math.rad(noseProfile.FrontYaw), side * math.rad(cockpitAngles.FrontRoll)), WINDOW_GLASS, nil, Enum.Material.Glass, 0.02)
		for paneIndex, paneDirection in ipairs({ -1, 1 }) do
			local paneOffset = paneDirection * noseProfile.SideOffset
			makeAircraftPart(model, root.CFrame, "CockpitSidePane" .. side .. "_" .. paneIndex, Vector3.new(0.22, radius * noseProfile.SideHeight, radius * noseProfile.SideDepth), CFrame.new(side * recessedSidePaneX, sideWindowY, sideWindowZ + paneOffset * radius) * CFrame.Angles(math.rad(cockpitAngles.SidePitch), side * math.rad(noseProfile.SideYaw), side * paneDirection * math.rad(cockpitAngles.SideRoll)), WINDOW_GLASS, nil, Enum.Material.Glass, 0.02)
		end
		local frameDepth = radius * (noseProfile.SideDepth + noseProfile.SideOffset * 1.5)
		makeAircraftPart(model, root.CFrame, "CockpitWindowLowerFrame" .. side, Vector3.new(0.11, radius * 0.055, frameDepth), CFrame.new(side * (sidePaneX - 0.025), radius * (noseProfile.SideY - noseProfile.SideHeight * 0.55), sideWindowZ), PANEL_GREY, nil, Enum.Material.Metal)
		makeAircraftPart(model, root.CFrame, "CockpitSideMullion" .. side, Vector3.new(0.12, radius * noseProfile.SideHeight * 1.05, 0.10), CFrame.new(side * (sidePaneX + 0.025), sideWindowY, sideWindowZ), PANEL_GREY, nil, Enum.Material.Metal)
		makeAircraftPart(model, root.CFrame, "PitotProbe" .. side, Vector3.new(0.10, 0.10, math.max(0.8, radius * 0.42)), CFrame.new(side * (sidePaneX + 0.08), radius * 0.04, -length * (noseProfile.SideZ + 0.012)), PANEL_GREY, nil, Enum.Material.Metal)
		makeAircraftPart(model, root.CFrame, "NoseStaticPort" .. side, Vector3.new(0.28, 0.28, 0.28), CFrame.new(side * sidePaneX, -radius * 0.03, -length * (noseProfile.SideZ + 0.011)), Color3.fromRGB(71, 82, 87), Enum.PartType.Ball, Enum.Material.Metal)
	end
	makeAircraftPart(model, root.CFrame, "CockpitCenterPost", Vector3.new(radius * 0.055, radius * noseProfile.FrontHeight * 1.28, 0.22), CFrame.new(0, radius * (noseProfile.FrontY - 0.02), -length * (noseProfile.FrontZ + 0.003)) * CFrame.Angles(math.rad(cockpitAngles.FrontPitch), 0, 0), noseProfile.HasMask and COCKPIT_MASK or PANEL_GREY, nil, Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		makeAircraftPart(model, root.CFrame, "CockpitWindowBrow" .. side, Vector3.new(radius * noseProfile.FrontWidth * 1.02, radius * 0.045, 0.24), CFrame.new(side * frontPaneX, radius * (noseProfile.FrontY + noseProfile.FrontHeight * 0.56), frontWindowZ + 0.01) * CFrame.Angles(math.rad(cockpitAngles.FrontPitch), -side * math.rad(noseProfile.FrontYaw), side * math.rad(cockpitAngles.FrontRoll)), noseProfile.HasMask and COCKPIT_MASK or PANEL_GREY, nil, Enum.Material.Metal)
		makeAircraftPart(model, root.CFrame, "CockpitWiper" .. side, Vector3.new(0.08, radius * noseProfile.FrontHeight * 0.82, 0.09), CFrame.new(side * frontPaneX, frontWindowY - radius * noseProfile.FrontHeight * 0.12, frontWindowZ - 0.16) * CFrame.Angles(math.rad(cockpitAngles.FrontPitch), -side * math.rad(noseProfile.FrontYaw), side * math.rad(18)), Color3.fromRGB(35, 42, 45), nil, Enum.Material.Metal)
	end
	local radomeRatio = 0.66
	local radomeDiameter = diameter * (1 - noseProfile.Taper * radomeRatio ^ noseProfile.Power)
	local radomeVertical = radomeDiameter * (1 - noseProfile.Vertical * radomeRatio ^ 1.4)
	local radomeY = -radius * (0.010 + noseProfile.Droop * radomeRatio ^ noseProfile.DroopPower)
	local radomeZ = -length * (noseProfile.Start + noseProfile.Span * radomeRatio)
	makeAircraftPart(model, root.CFrame, "RadomeSeam", Vector3.new(0.08, radomeVertical * 0.98, radomeDiameter * 0.98), CFrame.new(0, radomeY, radomeZ) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(170, 183, 187), Enum.PartType.Cylinder, Enum.Material.Metal, 0.82)
	local tipRatio = 0.985
	local tipDiameter = math.max(radius * 0.16, diameter * (1 - noseProfile.Taper * tipRatio ^ noseProfile.Power))
	local tipY = -radius * (0.010 + noseProfile.Droop * tipRatio ^ noseProfile.DroopPower)
	local tipZ = -length * (noseProfile.Start + noseProfile.Span * tipRatio)
	makeSmoothEllipsoid(model, root.CFrame, "SculptedRadomeTip", Vector3.new(tipDiameter * 1.04, tipDiameter * (1 - noseProfile.Vertical * 0.82), math.max(0.52, length * 0.010)), CFrame.new(0, tipY, tipZ), AIRFRAME_WHITE, Enum.Material.SmoothPlastic)
	makeSmoothEllipsoid(model, root.CFrame, "NoseChinFairing", Vector3.new(radius * 0.58 * noseDetails.ChinFullness, radius * 0.15, length * 0.034), CFrame.new(0, -radius * (0.55 + noseProfile.Droop * 0.30), -length * (noseProfile.Start + noseProfile.Span * 0.43)), AIRFRAME_WHITE, Enum.Material.SmoothPlastic)
	local diverterCenterZ = (radomeZ + tipZ) * 0.5
	local diverterLength = math.max(0.48, math.abs(tipZ - radomeZ) * 0.78)
	for _, strip in ipairs({
		{ "Top", 0, radomeY + radomeVertical * 0.34 },
		{ "Bottom", 0, radomeY - radomeVertical * 0.34 },
		{ "Left", -radomeDiameter * 0.34, radomeY },
		{ "Right", radomeDiameter * 0.34, radomeY },
	}) do
		makeAircraftPart(model, root.CFrame, "RadomeLightningDiverter" .. strip[1], Vector3.new(0.045, 0.045, diverterLength), CFrame.new(strip[2], strip[3], diverterCenterZ), Color3.fromRGB(139, 150, 153), nil, Enum.Material.Metal, 0.18)
	end
	for _, side in ipairs({ -1, 1 }) do
		local sensorX = side * (noseSurfaceX(-length * (noseProfile.SideZ + 0.004), radius * 0.01) + 0.06)
		makeAircraftPart(model, root.CFrame, "AngleOfAttackVane" .. side, Vector3.new(0.07, math.max(0.28, radius * 0.075 * noseDetails.SensorScale), math.max(0.46, radius * 0.12 * noseDetails.SensorScale)), CFrame.new(sensorX, radius * 0.02, -length * (noseProfile.SideZ + 0.004)) * CFrame.Angles(math.rad(-6), 0, side * math.rad(8)), Color3.fromRGB(102, 113, 117), nil, Enum.Material.Metal)
		makeAircraftPart(model, root.CFrame, "NoseAvionicsAccessPanel" .. side, Vector3.new(0.055, radius * 0.30, length * 0.030), CFrame.new(side * (noseSurfaceX(-length * (noseProfile.SideZ - 0.018), -radius * 0.16) + 0.025), -radius * 0.16, -length * (noseProfile.SideZ - 0.018)), Color3.fromRGB(178, 190, 193), nil, Enum.Material.Metal, 0.78)
	end
	makeAircraftPart(model, root.CFrame, "IceDetectorProbe", Vector3.new(0.07, 0.07, math.max(0.42, radius * 0.12 * noseDetails.SensorScale)), CFrame.new(-(noseSurfaceX(-length * (noseProfile.SideZ - 0.004), -radius * 0.11) + 0.08), -radius * 0.11, -length * (noseProfile.SideZ - 0.004)), Color3.fromRGB(113, 125, 129), nil, Enum.Material.Metal)
	for fastener = 1, 8 do
		local angle = (fastener - 1) * math.pi / 4
		makeAircraftPart(model, root.CFrame, "RadomeFastener" .. fastener, Vector3.new(0.16, 0.16, 0.16), CFrame.new(math.cos(angle) * radomeDiameter * 0.46, radomeY + math.sin(angle) * radomeVertical * 0.46, radomeZ - 0.08), Color3.fromRGB(128, 140, 144), Enum.PartType.Ball, Enum.Material.Metal)
	end

	local function createWindowRow(rowName, startZ, endZ, y)
		local spacing = math.clamp(length / 30, 1.45, 2.65)
		local index = 0
		for z = startZ, endZ, spacing do
			index += 1
			if not decorative or index % 2 == 0 then
				local x = math.sqrt(math.max(0.1, radius * radius - y * y)) + 0.05
				for _, side in ipairs({ -1, 1 }) do
					makeAircraftPart(model, root.CFrame, rowName .. side .. "_" .. index, Vector3.new(0.13, math.max(0.34, radius * 0.14), math.max(0.55, spacing * 0.44)), CFrame.new(side * x, y, z), WINDOW_GLASS, nil, Enum.Material.Glass, 0.02)
				end
			end
		end
	end
	createWindowRow("CabinWindow", -length * 0.33, length * 0.33, radius * 0.24)
	if spec.Decks == 2 then
		createWindowRow("UpperWindow", -length * 0.30, length * 0.27, radius * 0.60)
	elseif spec.UpperDeck then
		createWindowRow("UpperWindow", -length * 0.31, -length * 0.06, radius * 0.62)
	end

	local passengerDoorRatios = { -0.335, 0.305 }
	if (spec.LengthM or 0) >= 55 then
		passengerDoorRatios = { -0.335, -0.12, 0.11, 0.305 }
	elseif (spec.LengthM or 0) >= 42 then
		passengerDoorRatios = { -0.335, -0.015, 0.305 }
	end
	for doorIndex, doorRatio in ipairs(passengerDoorRatios) do
		local doorZ = length * doorRatio
		for _, side in ipairs({ -1, 1 }) do
			local doorHeight = radius * 0.82
			local doorWidth = radius * 0.50
			local doorName = "PassengerDoor" .. doorIndex .. "_" .. side
			local door = makeAircraftPart(model, root.CFrame, doorName, Vector3.new(0.11, doorHeight, doorWidth), CFrame.new(side * radius * 1.01, radius * 0.02, doorZ), AIRFRAME_WHITE, nil, Enum.Material.SmoothPlastic)
			door:SetAttribute("PaintBlendedDoor", true)
			for edge = -1, 1, 2 do
				makeAircraftPart(model, root.CFrame, doorName .. "VerticalSeam" .. edge, Vector3.new(0.055, doorHeight, 0.045), CFrame.new(side * radius * 1.022, radius * 0.02, doorZ + edge * doorWidth / 2), Color3.fromRGB(121, 137, 143), nil, Enum.Material.Metal, 0.42)
				makeAircraftPart(model, root.CFrame, doorName .. "HorizontalSeam" .. edge, Vector3.new(0.055, 0.045, doorWidth), CFrame.new(side * radius * 1.022, radius * 0.02 + edge * doorHeight / 2, doorZ), Color3.fromRGB(121, 137, 143), nil, Enum.Material.Metal, 0.42)
			end
			makeAircraftPart(model, root.CFrame, doorName .. "Handle", Vector3.new(0.055, 0.075, math.max(0.26, doorWidth * 0.20)), CFrame.new(side * radius * 1.035, radius * 0.05, doorZ - doorWidth * 0.18), Color3.fromRGB(96, 108, 112), nil, Enum.Material.Metal, 0.12)
			makeAircraftPart(model, root.CFrame, doorName .. "LiveryContinuation", Vector3.new(0.045, math.max(0.22, radius * 0.105), doorWidth * 0.96), CFrame.new(side * radius * 1.041, -radius * 0.03, doorZ), spec.Color, nil, Enum.Material.SmoothPlastic)
		end
	end
	if spec.Class == "Narrow-body" or spec.Class == "Regional" then
		local exitCount = (spec.LengthM or 0) > 40 and 2 or 1
		for exitIndex = 1, exitCount do
			local exitZ = length * ((exitIndex - (exitCount + 1) / 2) * 0.075)
			for _, side in ipairs({ -1, 1 }) do
				local exitName = "OverwingExit" .. exitIndex .. "_" .. side
				local exitDoor = makeAircraftPart(model, root.CFrame, exitName, Vector3.new(0.10, radius * 0.58, radius * 0.36), CFrame.new(side * radius * 1.012, radius * 0.08, exitZ), AIRFRAME_WHITE, nil, Enum.Material.SmoothPlastic)
				exitDoor:SetAttribute("PaintBlendedDoor", true)
				makeAircraftPart(model, root.CFrame, exitName .. "Outline", Vector3.new(0.055, radius * 0.62, 0.045), CFrame.new(side * radius * 1.025, radius * 0.08, exitZ), Color3.fromRGB(121, 137, 143), nil, Enum.Material.Metal, 0.48)
				makeAircraftPart(model, root.CFrame, exitName .. "LiveryContinuation", Vector3.new(0.045, math.max(0.22, radius * 0.105), radius * 0.34), CFrame.new(side * radius * 1.041, -radius * 0.03, exitZ), spec.Color, nil, Enum.Material.SmoothPlastic)
			end
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		for cargoIndex, cargoZ in ipairs({ -length * 0.16, length * 0.16 }) do
			local cargoName = "CargoDoor" .. cargoIndex .. "_" .. side
			local cargoHeight = radius * 0.44
			local cargoWidth = length * 0.065
			local cargoDoor = makeAircraftPart(model, root.CFrame, cargoName, Vector3.new(0.10, cargoHeight, cargoWidth), CFrame.new(side * radius * 1.015, -radius * 0.34, cargoZ), AIRFRAME_WHITE, nil, Enum.Material.SmoothPlastic)
			cargoDoor:SetAttribute("PaintBlendedDoor", true)
			for edge = -1, 1, 2 do
				makeAircraftPart(model, root.CFrame, cargoName .. "VerticalSeam" .. edge, Vector3.new(0.05, cargoHeight, 0.045), CFrame.new(side * radius * 1.027, -radius * 0.34, cargoZ + edge * cargoWidth / 2), Color3.fromRGB(121, 137, 143), nil, Enum.Material.Metal, 0.46)
				makeAircraftPart(model, root.CFrame, cargoName .. "HorizontalSeam" .. edge, Vector3.new(0.05, 0.045, cargoWidth), CFrame.new(side * radius * 1.027, -radius * 0.34 + edge * cargoHeight / 2, cargoZ), Color3.fromRGB(121, 137, 143), nil, Enum.Material.Metal, 0.46)
			end
			makeAircraftPart(model, root.CFrame, "CargoDoorHandle" .. cargoIndex .. "_" .. side, Vector3.new(0.055, 0.075, length * 0.012), CFrame.new(side * radius * 1.035, -radius * 0.30, cargoZ), Color3.fromRGB(96, 108, 112), nil, Enum.Material.Metal, 0.12)
		end
	end

	-- Segmented tapered wings form a swept planform while staying asset-free.
	local wingRootZ = length * silhouette.WingRootZRatio
	local wingRootChord = length * silhouette.WingRootChordRatio
	local wingTipChord = length * silhouette.WingTipChordRatio
	local exposedHalfSpan = math.max(span / 2 - radius * 0.72, radius * 2)
	local wingY = -radius * 0.08
	local wingBaseThickness = math.max(0.30, radius * 0.12)
	createSweptSurface(model, root.CFrame, "MainWing", exposedHalfSpan, wingRootChord, wingTipChord, wingRootZ, wingY, wingBaseThickness, sweep, AIRFRAME_GREY, wingSegments, true, spec.FoldingTips, silhouette.WingDihedralDegrees)
	local wingDihedralSlope = math.tan(math.rad(silhouette.WingDihedralDegrees))
	local function wingMetrics(distance)
		local ratio = math.clamp(distance / exposedHalfSpan, 0, 1)
		local chord = wingRootChord + (wingTipChord - wingRootChord) * ratio
		local centerY = wingY + distance * wingDihedralSlope
		local thickness = math.max(0.14, wingBaseThickness * (1 - ratio * 0.58))
		local centerZ = wingRootZ + distance * math.tan(math.rad(sweep))
		return ratio, chord, centerY, thickness, centerZ
	end
	local slatSections = silhouette.SlatSections
	for _, side in ipairs({ -1, 1 }) do
		for section = 1, slatSections do
			local distance = exposedHalfSpan * (section - 0.5) / slatSections
			local ratio, chord, centerY, _, centerZ = wingMetrics(distance)
			local z = centerZ - chord * 0.475
			local slatCF = CFrame.new(side * distance, centerY, z) * CFrame.Angles(0, -side * math.rad(sweep), -side * math.rad(2))
			local slat = makeAircraftPart(model, root.CFrame, "WingLeadingEdge" .. side .. "_" .. section, Vector3.new(exposedHalfSpan / slatSections * 1.06, math.max(0.12, radius * 0.035), math.max(0.24, chord * 0.035)), slatCF, Color3.fromRGB(184, 194, 198), nil, Enum.Material.Metal)
			slat:SetAttribute("SlatPart", true)
			slat:SetAttribute("VisualChannel", "SLATS")
			slat:SetAttribute("BaseLocalCF", slatCF)
			slat:SetAttribute("SlatTravel", Vector3.new(0, -radius * 0.018, -math.max(0.12, chord * 0.018)))
			configureWingFlex(slat, slatCF, ratio ^ 1.72, side, false)
		end
	end
	local tipExtension = math.clamp(wingTipChord * 0.82, 2.4, exposedHalfSpan * 0.082)
	local outerTipDistance = exposedHalfSpan + tipExtension * 0.82
	for _, side in ipairs({ -1, 1 }) do
		for segment = 1, 4 do
			local t = (segment - 0.5) / 4
			local tipCenterDistance = exposedHalfSpan + tipExtension * t
			local tipZ = wingRootZ + tipCenterDistance * math.tan(math.rad(sweep)) + wingTipChord * 0.05 * t
			local tipY = wingY + tipCenterDistance * wingDihedralSlope
			local tipCF = CFrame.new(side * tipCenterDistance, tipY, tipZ) * CFrame.Angles(math.rad(-2.35), -side * math.rad(sweep + t * 5), -side * math.rad(2))
			local tip = makeSmoothEllipsoid(model, root.CFrame, "SmoothRakedWingTip" .. side .. "_" .. segment, Vector3.new(tipExtension / 4 * 1.35, math.max(0.15, radius * 0.040 * (1 - t * 0.35)), wingTipChord * (0.96 - t * 0.48)), tipCF, AIRFRAME_GREY, Enum.Material.Metal)
			configureWingFlex(tip, tipCF, 1.02 + t * 0.08, side, true)
			if spec.FoldingTips then
				local hingeDistance = exposedHalfSpan * 0.93
				local hingeZ = wingRootZ + hingeDistance * math.tan(math.rad(sweep))
				local hingeY = wingY + hingeDistance * wingDihedralSlope
				tip:SetAttribute("FoldingWingtipPart", true)
				tip:SetAttribute("FoldPivotCF", CFrame.new(side * hingeDistance, hingeY, hingeZ))
				tip:SetAttribute("FoldDirection", side)
			end
		end
	end

	-- Trailing-edge flap panels and upper wing markings.
	local flapSections = silhouette.FlapSections
	local spoilerSections = silhouette.SpoilerSections
	model:SetAttribute("FlapPanelSectionsPerWing", flapSections)
	model:SetAttribute("SlatPanelSectionsPerWing", slatSections)
	model:SetAttribute("SpoilerPanelSectionsPerWing", spoilerSections)
	for _, side in ipairs({ -1, 1 }) do
		for flapSection = 1, flapSections do
			local flapSpanRatio = 0.50 / flapSections
			local flapRatio = 0.18 + (flapSection - 0.5) * flapSpanRatio
			local flapDistance = exposedHalfSpan * flapRatio
			local _, localChord, wingCenterY, _, wingCenterZ = wingMetrics(flapDistance)
			local flapX = side * flapDistance
			local flapZ = wingCenterZ + localChord * 0.385
			local flapLocalCF = CFrame.new(flapX, wingCenterY, flapZ) * CFrame.Angles(0, -side * math.rad(sweep), 0)
			local flap = makeAircraftPart(model, root.CFrame, "FlapPanel" .. side .. "_" .. flapSection, Vector3.new(exposedHalfSpan * flapSpanRatio * 0.94, 0.12, localChord * 0.18), flapLocalCF, PANEL_GREY, nil, Enum.Material.Metal)
			flap:SetAttribute("FlapPart", true)
			flap:SetAttribute("VisualChannel", "FLAPS")
			flap:SetAttribute("BaseLocalCF", flapLocalCF)
			flap:SetAttribute("HingeOffset", Vector3.new(0, 0, -flap.Size.Z / 2))
			flap:SetAttribute("FlapMaxAngle", silhouette.FlapMaxAngle)
			flap:SetAttribute("FlapTravel", Vector3.new(0, -radius * 0.10, localChord * 0.075))
			configureWingFlex(flap, flapLocalCF, flapRatio ^ 1.72, side, false)
		end
		for track = 1, 2 do
			local trackX = side * exposedHalfSpan * (0.30 + track * 0.17)
			local trackDistance = math.abs(trackX)
			local _, trackChord, trackCenterY, trackThickness, trackCenterZ = wingMetrics(trackDistance)
			local fairingHeight = math.max(0.24, radius * 0.08)
			local trackZ = trackCenterZ + trackChord * 0.30
			local fairingCF = CFrame.new(trackX, trackCenterY - trackThickness * 0.46 - fairingHeight * 0.28, trackZ)
			local fairing = makeSmoothEllipsoid(model, root.CFrame, "FlapTrackFairing" .. side .. "_" .. track, Vector3.new(math.max(0.28, radius * 0.10), fairingHeight, trackChord * 0.28), fairingCF, AIRFRAME_GREY, Enum.Material.Metal)
			configureWingFlex(fairing, fairingCF, (0.30 + track * 0.17) ^ 1.72, side, true)
		end

		local aileronX = side * exposedHalfSpan * 0.79
		local _, aileronChord, aileronCenterY, _, aileronCenterZ = wingMetrics(math.abs(aileronX))
		local aileronZ = aileronCenterZ + aileronChord * 0.40
		local aileronCF = CFrame.new(aileronX, aileronCenterY, aileronZ) * CFrame.Angles(0, -side * math.rad(sweep), 0)
		local aileron = makeAircraftPart(model, root.CFrame, "Aileron" .. side, Vector3.new(exposedHalfSpan * 0.25, 0.13, math.max(0.38, aileronChord * 0.20)), aileronCF, Color3.fromRGB(163, 174, 179), nil, Enum.Material.Metal)
		configureControlSurface(aileron, "AILERON", aileronCF, -side, 16)
		configureWingFlex(aileron, aileronCF, 0.79 ^ 1.72, side, false)

		for panelIndex = 1, spoilerSections do
			local spoilerRatio = 0.18 + panelIndex * (0.42 / (spoilerSections + 1))
			local panelX = side * exposedHalfSpan * spoilerRatio
			local _, panelChord, panelCenterY, panelThickness, panelCenterZ = wingMetrics(math.abs(panelX))
			local panelZ = panelCenterZ + panelChord * 0.05
			local panelSpan = exposedHalfSpan * 0.36 / spoilerSections * 0.92
			-- Three tapered strips form one trapezoidal panel. They articulate as a
			-- single surface but avoid the square slabs used by the previous model.
			for strip = 1, 3 do
				local stripT = (strip - 0.5) / 3
				local stripX = panelX + side * (stripT - 0.5) * panelSpan
				local stripChord = panelChord * (0.205 - stripT * 0.055)
				local stripZ = panelZ + panelChord * 0.018 * stripT
				local spoilerHeight = 0.07
				local spoilerCF = CFrame.new(stripX, panelCenterY + panelThickness * 0.50 + spoilerHeight * 0.34, stripZ) * CFrame.Angles(0, -side * math.rad(sweep), 0)
				local spoiler = makeAircraftPart(model, root.CFrame, "TaperedSpoilerPanel" .. side .. "_" .. panelIndex .. "_" .. strip, Vector3.new(panelSpan / 3 * 1.08, spoilerHeight, stripChord), spoilerCF, Color3.fromRGB(177, 187, 191), nil, Enum.Material.Metal)
				spoiler:SetAttribute("SpoilerPart", true)
				spoiler:SetAttribute("VisualChannel", "SPOILERS")
				spoiler:SetAttribute("BaseLocalCF", spoilerCF)
				spoiler:SetAttribute("HingeOffset", Vector3.new(0, 0, -spoiler.Size.Z / 2))
				spoiler:SetAttribute("SpoilerDirection", side)
				spoiler:SetAttribute("SpoilerMaxAngle", 40)
				configureWingFlex(spoiler, spoilerCF, spoilerRatio ^ 1.72, side, false)
			end
		end
	end

	local tailSpan = span * (spec.TTail and 0.30 or silhouette.TailSpanRatio)
	local tailHeight = math.max(radius * 2.25, (fullHeight - diameter) * 0.62)
	local tailTopY = radius + tailHeight
	local tailPlaneY = spec.TTail and tailTopY - tailHeight * 0.12 or radius * 0.18
	local tailHalfSpan = tailSpan / 2
	local tailRootChord = length * silhouette.TailRootChordRatio
	local tailTipChord = length * silhouette.TailTipChordRatio
	local tailSweep = math.min(38, sweep + 5)
	local tailRootZ = length * 0.36
	createSweptSurface(model, root.CFrame, "HorizontalStabilizer", tailHalfSpan, tailRootChord, tailTipChord, tailRootZ, tailPlaneY, math.max(0.22, radius * 0.08), tailSweep, AIRFRAME_GREY, stabilizerSegments)
	for _, side in ipairs({ -1, 1 }) do
		local elevatorDistance = tailSpan * 0.25
		local elevatorRatio = elevatorDistance / tailHalfSpan
		local elevatorChord = tailRootChord + (tailTipChord - tailRootChord) * elevatorRatio
		local elevatorCenterZ = tailRootZ + elevatorDistance * math.tan(math.rad(tailSweep))
		local elevatorCF = CFrame.new(side * elevatorDistance, tailPlaneY, elevatorCenterZ + elevatorChord * 0.40) * CFrame.Angles(0, -side * math.rad(tailSweep), 0)
		local elevator = makeAircraftPart(model, root.CFrame, "Elevator" .. side, Vector3.new(tailSpan * 0.38, 0.11, math.max(0.34, elevatorChord * 0.20)), elevatorCF, Color3.fromRGB(158, 170, 176), nil, Enum.Material.Metal)
		configureControlSurface(elevator, "ELEVATOR", elevatorCF, 1, 15)
	end

	-- Build the vertical tail from smoothly overlapping tapered sections. The
	-- leading edge sweeps aft while both chord and thickness reduce toward the
	-- cap, replacing the oversized triangular slab visible in V24.
	local finRootZ = length * 0.345
	local finRootChord = length * silhouette.FinRootChordRatio
	local finTipChord = length * silhouette.FinTipChordRatio
	local finSegments = decorative and 10 or 18
	local finSegmentHeight = tailHeight / finSegments
	for segment = 1, finSegments do
		local t = (segment - 0.5) / finSegments
		local chord = finRootChord + (finTipChord - finRootChord) * (t ^ 0.92)
		local leadingZ = finRootZ + tailHeight * silhouette.FinSweepRatio * t
		local centerZ = leadingZ + chord / 2
		local sectionCF = CFrame.new(0, radius + tailHeight * t, centerZ)
		makeSmoothEllipsoid(model, root.CFrame, "SculptedVerticalStabilizer" .. segment, Vector3.new(math.max(0.24, radius * (0.12 - t * 0.055)), finSegmentHeight * 1.34, chord), sectionCF, spec.Color, Enum.Material.SmoothPlastic)
	end
	makeSmoothEllipsoid(model, root.CFrame, "DorsalFinRootBlend", Vector3.new(math.max(0.26, radius * 0.14), tailHeight * 0.28, finRootChord * 0.70), CFrame.new(0, radius + tailHeight * 0.10, finRootZ + finRootChord * 0.32), spec.Color, Enum.Material.SmoothPlastic)
	for rudderSection = 1, 5 do
		local t = (rudderSection - 0.5) / 5
		local finChord = finRootChord + (finTipChord - finRootChord) * (t ^ 0.92)
		local leadingZ = finRootZ + tailHeight * silhouette.FinSweepRatio * t
		local rudderChord = math.max(radius * 0.24, finChord * 0.24)
		local rudderCF = CFrame.new(0, radius + tailHeight * t, leadingZ + finChord - rudderChord / 2)
		local rudder = makeAircraftPart(model, root.CFrame, "TaperedRudder" .. rudderSection, Vector3.new(math.max(0.24, radius * 0.095), tailHeight / 5 * 1.08, rudderChord), rudderCF, Color3.fromRGB(154, 166, 171), nil, Enum.Material.Metal)
		configureControlSurface(rudder, "RUDDER", rudderCF, 1, 18)
	end

	-- Small dorsal antennae and belly fairing add silhouette detail at close camera ranges.
	for _, antennaZ in ipairs({ -length * 0.10, length * 0.15 }) do
		makeAircraftPart(model, root.CFrame, "DorsalAntenna", Vector3.new(0.12, math.max(0.38, radius * 0.18), 0.42), CFrame.new(0, radius * 1.06, antennaZ), AIRFRAME_GREY, nil, Enum.Material.Metal)
	end
	makeAircraftPart(model, root.CFrame, "BellyFairing", Vector3.new(radius * 1.25, radius * 0.38, length * 0.18), CFrame.new(0, -radius * 0.78, length * 0.02), AIRFRAME_GREY, Enum.PartType.Ball, Enum.Material.SmoothPlastic)
	makeSmoothEllipsoid(model, root.CFrame, "WingRootFairing", Vector3.new(radius * 2.15, radius * 0.70, length * 0.28), CFrame.new(0, -radius * 0.48, wingRootZ + length * 0.03), AIRFRAME_GREY, Enum.Material.SmoothPlastic)
	makeAircraftPart(model, root.CFrame, "APUExhaust", Vector3.new(math.max(0.35, radius * 0.14), math.max(0.65, radius * 0.28), math.max(0.65, radius * 0.28)), CFrame.new(0, radius * 0.08, length * 0.492) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(52, 59, 62), Enum.PartType.Cylinder, Enum.Material.Metal)
	makeSmoothEllipsoid(model, root.CFrame, "TailSkidHousing", Vector3.new(radius * 0.22, radius * 0.20, length * 0.035), CFrame.new(0, -radius * 0.66, length * 0.425), AIRFRAME_GREY, Enum.Material.Metal)
	makeAircraftPart(model, root.CFrame, "TailSkidPad", Vector3.new(radius * 0.18, 0.16, length * 0.018), CFrame.new(0, -radius * 0.70, length * 0.43), Color3.fromRGB(92, 98, 100), nil, Enum.Material.Metal)
	for drain = 1, 3 do
		makeAircraftPart(model, root.CFrame, "BellyDrainMast" .. drain, Vector3.new(0.08, math.max(0.28, radius * 0.10), 0.10), CFrame.new(0, -radius * 1.01, length * (-0.08 + drain * 0.07)), PANEL_GREY, nil, Enum.Material.Metal)
	end
	-- Realistic underside service details stay visible in the belly landing view.
	for _, side in ipairs({ -1, 1 }) do
		makeSmoothEllipsoid(model, root.CFrame, "PackInlet" .. side, Vector3.new(radius * 0.30, radius * 0.10, length * 0.045), CFrame.new(side * radius * 0.34, -radius * 0.97, length * 0.075), Color3.fromRGB(102, 114, 118), Enum.Material.Metal)
		makeAircraftPart(model, root.CFrame, "BellyServicePanel" .. side, Vector3.new(radius * 0.34, 0.08, length * 0.050), CFrame.new(side * radius * 0.42, -radius * 1.005, -length * 0.09), Color3.fromRGB(174, 186, 190), nil, Enum.Material.Metal)
	end
	makeSmoothEllipsoid(model, root.CFrame, "RamAirOutlet", Vector3.new(radius * 0.46, radius * 0.11, length * 0.050), CFrame.new(0, -radius * 0.985, length * 0.16), Color3.fromRGB(88, 101, 106), Enum.Material.Metal)

	if spec.Winglet then
		local tipZ = wingRootZ + outerTipDistance * math.tan(math.rad(sweep))
		for _, side in ipairs({ -1, 1 }) do
			local isReferenceBlended = spec.WingletStyle == "BLENDED_TALL"
			local wingletHeight = isReferenceBlended and math.max(8.5, radius * 1.38)
				or math.max(1.2, radius * (spec.FoldingTips and 0.70 or 0.58))
			local tipY = wingY + outerTipDistance * wingDihedralSlope
			local segmentCount = isReferenceBlended and 7 or 5
			for segment = 1, segmentCount do
				local t = (segment - 0.5) / segmentCount
				local curvedT = t * t * (3 - 2 * t)
				local outward = side * wingletHeight * 0.13 * math.sin(t * math.pi / 2)
				local aft = wingTipChord * (0.04 + 0.20 * curvedT)
				local chord = math.max(0.65, wingTipChord * ((isReferenceBlended and 0.86 or 0.68) - curvedT * 0.48))
				local wingletCF = CFrame.new(side * outerTipDistance + outward, tipY + wingletHeight * t, tipZ + aft)
					* CFrame.Angles(math.rad(-5 - curvedT * 4), -side * math.rad(sweep + curvedT * 8), -side * math.rad(7 + curvedT * 4))
				local winglet = makeSmoothEllipsoid(model, root.CFrame, "BlendedWinglet" .. side .. "_" .. segment, Vector3.new(math.max(0.20, radius * (0.075 - curvedT * 0.025)), wingletHeight / segmentCount * 1.34, chord), wingletCF, spec.Color, Enum.Material.SmoothPlastic)
				winglet:SetAttribute("WingletStyle", spec.WingletStyle or "STANDARD_BLEND")
				configureWingFlex(winglet, wingletCF, 1.08, side, true)
			end
		end
	end
	if spec.SplitWinglet or spec.WingtipFence then
		local tipZ = wingRootZ + outerTipDistance * math.tan(math.rad(sweep))
		for _, side in ipairs({ -1, 1 }) do
			local tipY = wingY + outerTipDistance * wingDihedralSlope
			local lowerHeight = math.max(0.85, radius * (spec.WingtipFence and 0.30 or 0.38))
			local fenceCF = CFrame.new(side * outerTipDistance, tipY - lowerHeight / 2, tipZ) * CFrame.Angles(math.rad(5), -side * math.rad(sweep), side * math.rad(6))
			local fence = makeAircraftPart(model, root.CFrame, "LowerWingtipFence" .. side, Vector3.new(math.max(0.20, radius * 0.07), lowerHeight, math.max(0.65, wingTipChord * 0.46)), fenceCF, spec.Color, nil, Enum.Material.SmoothPlastic)
			configureWingFlex(fence, fenceCF, 1.08, side, true)
		end
	end
	if spec.FoldingTips then
		for _, side in ipairs({ -1, 1 }) do
			local hingeDistance = exposedHalfSpan * 0.93
			local hingeZ = wingRootZ + hingeDistance * math.tan(math.rad(sweep))
			local hingeY = wingY + hingeDistance * wingDihedralSlope
			local hingeCF = CFrame.new(side * hingeDistance, hingeY, hingeZ) * CFrame.Angles(0, -side * math.rad(sweep), -side * math.rad(2))
			local hinge = makeAircraftPart(model, root.CFrame, "FoldingWingtipHinge" .. side, Vector3.new(math.max(0.20, radius * 0.08), math.max(0.16, radius * 0.045), wingTipChord * 0.98), hingeCF, PANEL_GREY, nil, Enum.Material.Metal)
			configureWingFlex(hinge, hingeCF, 0.90 ^ 1.72, side, true)
		end
	end
	-- Thin static-discharge wicks along the trailing edges improve the wing and
	-- tail silhouette without affecting any control-surface or flight behavior.
	for _, side in ipairs({ -1, 1 }) do
		for wick = 1, 4 do
			local distance = exposedHalfSpan * (0.52 + wick * 0.105)
			local ratio = distance / exposedHalfSpan
			local chord = wingRootChord + (wingTipChord - wingRootChord) * ratio
			local z = wingRootZ + distance * math.tan(math.rad(sweep)) + chord * 0.50
			local y = wingY + distance * wingDihedralSlope
			local wickCF = CFrame.new(side * distance, y, z)
			local wingWick = makeAircraftPart(model, root.CFrame, "WingStaticWick" .. side .. "_" .. wick, Vector3.new(0.07, 0.07, math.max(0.85, radius * 0.32)), wickCF, Color3.fromRGB(66, 75, 79), nil, Enum.Material.Metal)
			configureWingFlex(wingWick, wickCF, ratio ^ 1.72, side, true)
			if spec.FoldingTips and ratio >= 0.93 then
				local hingeDistance = exposedHalfSpan * 0.93
				wingWick:SetAttribute("FoldingWingtipPart", true)
				wingWick:SetAttribute("FoldPivotCF", CFrame.new(side * hingeDistance, wingY + hingeDistance * wingDihedralSlope, wingRootZ + hingeDistance * math.tan(math.rad(sweep))))
				wingWick:SetAttribute("FoldDirection", side)
			end
		end
		makeAircraftPart(model, root.CFrame, "TailStaticWick" .. side, Vector3.new(0.07, 0.07, math.max(0.75, radius * 0.28)), CFrame.new(side * tailSpan * 0.38, tailPlaneY, length * 0.458), Color3.fromRGB(66, 75, 79), nil, Enum.Material.Metal)
	end

	local engineXs
	local engineProfileName = spec.EngineArchitecture or "NARROW_HIGH_BYPASS"
	local engineProfile = EngineAudioConfig.GetProfile(engineProfileName)
	local engineSoundIds = engineProfile.SoundIds or {}
	local audioConfigured = false
	for _, soundId in pairs(engineSoundIds) do
		if soundId ~= "" then audioConfigured = true break end
	end
	model:SetAttribute("EngineAudioUploadRequired", not audioConfigured)
	if spec.RearEngines then
		engineXs = { -(radius + (spec.EngineDiameterM or 1.5) * STUDS_PER_METRE * 0.42), radius + (spec.EngineDiameterM or 1.5) * STUDS_PER_METRE * 0.42 }
	elseif spec.Engines == 4 then
		engineXs = { -span * 0.34, -span * 0.20, span * 0.20, span * 0.34 }
	else
		engineXs = { -span * 0.245, span * 0.245 }
	end
	for index, x in ipairs(engineXs) do
		local engineDiameter = (spec.EngineDiameterM or 2.1) * STUDS_PER_METRE
		local engineLength = engineDiameter * (spec.RearEngines and 2.65 or 2.25)
		local engineY = spec.RearEngines and 0 or wingY - engineDiameter * 0.58
		local engineZ = spec.RearEngines and length * 0.28 or wingRootZ + math.abs(x) * math.tan(math.rad(sweep)) - wingRootChord * 0.16
		makeAircraftPart(model, root.CFrame, "EngineNacelle" .. index, Vector3.new(engineLength, engineDiameter, engineDiameter), CFrame.new(x, engineY, engineZ) * CFrame.Angles(0, math.rad(90), 0), AIRFRAME_WHITE, Enum.PartType.Cylinder, Enum.Material.Metal)
		makeSmoothEllipsoid(model, root.CFrame, "EngineForwardCowling" .. index, Vector3.new(engineDiameter * 1.035, engineDiameter * 1.035, engineLength * 0.22), CFrame.new(x, engineY, engineZ - engineLength * 0.39), AIRFRAME_WHITE, Enum.Material.Metal)
		local reverserBaseCF = CFrame.new(x, engineY, engineZ + engineLength * 0.37)
		local aftCowling = makeSmoothEllipsoid(model, root.CFrame, "EngineAftCowling" .. index, Vector3.new(engineDiameter * 0.91, engineDiameter * 0.91, engineLength * 0.32), reverserBaseCF, AIRFRAME_WHITE, Enum.Material.Metal)
		aftCowling:SetAttribute("ReverserPart", true)
		aftCowling:SetAttribute("VisualChannel", "THRUST_REVERSERS")
		aftCowling:SetAttribute("BaseLocalCF", reverserBaseCF)
		aftCowling:SetAttribute("ReverserTravel", math.max(0.65, engineLength * 0.12))
		makeAircraftPart(model, root.CFrame, "EngineTailCone" .. index, Vector3.new(engineLength * 0.23, engineDiameter * 0.44, engineDiameter * 0.44), CFrame.new(x, engineY, engineZ + engineLength * 0.48) * CFrame.Angles(0, math.rad(90), 0), PANEL_GREY, Enum.PartType.Cylinder, Enum.Material.Metal)
		makeAircraftPart(model, root.CFrame, "IntakeLip" .. index, Vector3.new(0.34, engineDiameter * 1.03, engineDiameter * 1.03), CFrame.new(x, engineY, engineZ - engineLength / 2 + 0.12) * CFrame.Angles(0, math.rad(90), 0), spec.Color, Enum.PartType.Cylinder, Enum.Material.Metal)
		makeAircraftPart(model, root.CFrame, "FanDisk" .. index, Vector3.new(0.16, engineDiameter * 0.82, engineDiameter * 0.82), CFrame.new(x, engineY, engineZ - engineLength / 2 - 0.08) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(37, 46, 50), Enum.PartType.Cylinder, Enum.Material.Metal)
		local fanBlur = makeAircraftPart(model, root.CFrame, "FanBlurDisc" .. index, Vector3.new(0.12, engineDiameter * 0.72, engineDiameter * 0.72), CFrame.new(x, engineY, engineZ - engineLength / 2 - 0.22) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(106, 117, 121), Enum.PartType.Cylinder, Enum.Material.Glass, 1)
		fanBlur:SetAttribute("AircraftEffectType", "FAN_BLUR")
		fanBlur:SetAttribute("EngineIndex", index)
		makeAircraftPart(model, root.CFrame, "Exhaust" .. index, Vector3.new(0.22, engineDiameter * 0.58, engineDiameter * 0.58), CFrame.new(x, engineY, engineZ + engineLength / 2 + 0.02) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(54, 61, 64), Enum.PartType.Cylinder, Enum.Material.Metal)
		local fanHubCF = CFrame.new(x, engineY, engineZ - engineLength / 2 - 0.19)
		local fanHub = makeAircraftPart(model, root.CFrame, "FanHub" .. index, Vector3.new(engineDiameter * 0.20, engineDiameter * 0.20, 0.22), fanHubCF, PANEL_GREY, Enum.PartType.Ball, Enum.Material.Metal)
		fanHub:SetAttribute("FanBladePart", true)
		fanHub:SetAttribute("BaseLocalCF", fanHubCF)
		local spinnerCF = CFrame.new(x, engineY, engineZ - engineLength / 2 - 0.31)
		local spinner = makeSmoothEllipsoid(model, root.CFrame, "EngineSpinner" .. index, Vector3.new(engineDiameter * 0.24, engineDiameter * 0.24, engineDiameter * 0.34), spinnerCF, Color3.fromRGB(182, 193, 197), Enum.Material.Metal)
		spinner:SetAttribute("FanBladePart", true)
		spinner:SetAttribute("BaseLocalCF", spinnerCF)
		makeAircraftPart(model, root.CFrame, "IntakeAcousticLiner" .. index, Vector3.new(0.10, engineDiameter * 0.86, engineDiameter * 0.86), CFrame.new(x, engineY, engineZ - engineLength / 2 + 0.33) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(66, 74, 78), Enum.PartType.Cylinder, Enum.Material.Metal)
		makeAircraftPart(model, root.CFrame, "InnerIntakeLip" .. index, Vector3.new(0.09, engineDiameter * 0.92, engineDiameter * 0.92), CFrame.new(x, engineY, engineZ - engineLength / 2 + 0.24) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(142, 152, 156), Enum.PartType.Cylinder, Enum.Material.Metal, 0.14)
		makeAircraftPart(model, root.CFrame, "FanShroud" .. index, Vector3.new(0.08, engineDiameter * 0.88, engineDiameter * 0.88), CFrame.new(x, engineY, engineZ - engineLength / 2 + 0.48) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(47, 56, 60), Enum.PartType.Cylinder, Enum.Material.Metal)
		makeSmoothEllipsoid(model, root.CFrame, "CoreExhaustCone" .. index, Vector3.new(engineDiameter * 0.24, engineDiameter * 0.24, engineLength * 0.24), CFrame.new(x, engineY, engineZ + engineLength * 0.54), Color3.fromRGB(86, 91, 93), Enum.Material.Metal)
		makeAircraftPart(model, root.CFrame, "RearTurbineDisk" .. index, Vector3.new(0.08, engineDiameter * 0.42, engineDiameter * 0.42), CFrame.new(x, engineY, engineZ + engineLength * 0.50) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(70, 75, 77), Enum.PartType.Cylinder, Enum.Material.Metal)
		for panel = 1, 3 do
			local panelAngle = math.rad(-55 + panel * 55)
			makeAircraftPart(model, root.CFrame, "NacelleAccessPanel" .. index .. "_" .. panel, Vector3.new(engineDiameter * 0.24, engineDiameter * 0.035, engineLength * 0.25), CFrame.new(x + math.cos(panelAngle) * engineDiameter * 0.49, engineY + math.sin(panelAngle) * engineDiameter * 0.49, engineZ + engineLength * 0.04) * CFrame.Angles(0, 0, panelAngle - math.pi / 2), Color3.fromRGB(178, 188, 191), nil, Enum.Material.Metal)
		end
		makeAircraftPart(model, root.CFrame, "EngineDrainMast" .. index, Vector3.new(0.08, math.max(0.28, engineDiameter * 0.08), 0.10), CFrame.new(x, engineY - engineDiameter * 0.53, engineZ + engineLength * 0.17), Color3.fromRGB(91, 101, 104), nil, Enum.Material.Metal)
		for seamIndex, seamRatio in ipairs({ -0.12, 0.16, 0.31 }) do
			makeAircraftPart(model, root.CFrame, "NacellePanelSeam" .. index .. "_" .. seamIndex, Vector3.new(0.07, engineDiameter * 0.995, engineDiameter * 0.995), CFrame.new(x, engineY, engineZ + engineLength * seamRatio) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(131, 145, 150), Enum.PartType.Cylinder, Enum.Material.Metal, 0.68)
		end
		if spec.ChevronNacelle then
			for chevron = 1, 10 do
				local angle = (chevron - 1) * math.pi * 2 / 10
				local chevronX = x + math.cos(angle) * engineDiameter * 0.43
				local chevronY = engineY + math.sin(angle) * engineDiameter * 0.43
				makeAircraftWedge(model, root.CFrame, "NacelleChevron" .. index .. "_" .. chevron, Vector3.new(math.max(0.16, engineDiameter * 0.035), math.max(0.18, engineDiameter * 0.065), engineLength * 0.095), CFrame.new(chevronX, chevronY, engineZ + engineLength * 0.49) * CFrame.Angles(0, 0, angle), AIRFRAME_WHITE, Enum.Material.Metal)
			end
		end
		local fanBladeCount = decorative and 10 or (engineProfile.FanBladeCount or 24)
		for blade = 1, fanBladeCount do
			local fanBladeCF = CFrame.new(x, engineY, engineZ - engineLength / 2 - 0.18) * CFrame.Angles(0, 0, math.rad((blade - 1) * (360 / fanBladeCount)))
			local fanBlade = makeAircraftWedge(model, root.CFrame, "FanBlade" .. index .. "_" .. blade, Vector3.new(engineDiameter * 0.075, engineDiameter * 0.64, 0.10), fanBladeCF * CFrame.Angles(0, 0, math.rad(7)), PANEL_GREY, Enum.Material.Metal)
			fanBlade:SetAttribute("FanBladePart", true)
			fanBlade:SetAttribute("VisualChannel", "ENGINE_FANS")
			fanBlade:SetAttribute("BaseLocalCF", fanBladeCF * CFrame.Angles(0, 0, math.rad(7)))
		end
		local statorCount = decorative and 6 or 14
		for vane = 1, statorCount do
			local statorCF = CFrame.new(x, engineY, engineZ - engineLength / 2 + 0.08) * CFrame.Angles(0, 0, math.rad((vane - 1) * (360 / statorCount) + 7))
			makeAircraftPart(model, root.CFrame, "FanOutletGuideVane" .. index .. "_" .. vane, Vector3.new(engineDiameter * 0.035, engineDiameter * 0.56, 0.07), statorCF, Color3.fromRGB(91, 103, 108), nil, Enum.Material.Metal)
		end
		if not spec.RearEngines then
			local mountTopY = wingY + math.max(0.25, radius * 0.05)
			local mountBottomY = engineY + engineDiameter * 0.34
			local mountHeight = math.max(1.1, mountTopY - mountBottomY)
			makeAircraftPart(model, root.CFrame, "EngineMountStrut" .. index, Vector3.new(math.max(0.55, engineDiameter * 0.16), mountHeight, engineLength * 0.32), CFrame.new(x, mountBottomY + mountHeight / 2, engineZ + engineLength * 0.06), AIRFRAME_GREY, nil, Enum.Material.Metal)
			makeAircraftWedge(model, root.CFrame, "EnginePylonFairing" .. index, Vector3.new(math.max(0.42, engineDiameter * 0.13), mountHeight * 1.10, engineLength * 0.38), CFrame.new(x, mountBottomY + mountHeight * 0.52, engineZ + engineLength * 0.10), AIRFRAME_GREY, Enum.Material.Metal)
			makeSmoothEllipsoid(model, root.CFrame, "EnginePylonFillet" .. index, Vector3.new(engineDiameter * 0.24, math.max(1.1, mountHeight * 0.55), engineLength * 0.24), CFrame.new(x, mountTopY - mountHeight * 0.12, engineZ + engineLength * 0.04), AIRFRAME_GREY, Enum.Material.Metal)
			makeAircraftWedge(model, root.CFrame, "PylonTrailingFairing" .. index, Vector3.new(math.max(0.30, engineDiameter * 0.10), mountHeight * 0.68, engineLength * 0.22), CFrame.new(x, mountBottomY + mountHeight * 0.62, engineZ + engineLength * 0.29), AIRFRAME_GREY, Enum.Material.Metal)
		end

		local audioAnchor = makeAircraftPart(model, root.CFrame, "EngineAudioAnchor" .. index, Vector3.new(0.20, 0.20, 0.20), CFrame.new(x, engineY, engineZ), Color3.new(), nil, Enum.Material.SmoothPlastic, 1)
		audioAnchor:SetAttribute("EngineAudioProfile", engineProfileName)
		for _, slot in ipairs({ "IDLE", "POWER", "TAKEOFF", "REVERSE", "SHUTDOWN" }) do
			local sound = Instance.new("Sound")
			sound.Name = "Engine" .. slot .. index
			sound.SoundId = engineSoundIds[slot] or ""
			sound.Looped = slot ~= "SHUTDOWN"
			sound.Volume = 0
			sound.RollOffMinDistance = 28
			sound.RollOffMaxDistance = slot == "TAKEOFF" and 1700 or 1050
			sound.EmitterSize = engineDiameter * 2.2
			sound:SetAttribute("EngineSoundSlot", slot)
			sound:SetAttribute("OriginalAudioFile", "V23_Engine_" .. string.sub(slot, 1, 1) .. string.lower(string.sub(slot, 2)) .. ".wav")
			sound.Parent = audioAnchor
		end
		local exhaustOffset = Vector3.new(0, 0, engineLength * 0.52)
		addAircraftEmitter(audioAnchor, "EngineHeatHaze" .. index, "HEAT_HAZE", Color3.fromRGB(184, 194, 199), 0.72, 5.5, 12, exhaustOffset)
		addAircraftEmitter(audioAnchor, "EngineExhaust" .. index, "ENGINE_EXHAUST", Color3.fromRGB(151, 160, 164), 0.58, 6.5, 8, exhaustOffset)
		addAircraftEmitter(audioAnchor, "HighAltitudeContrail" .. index, "CONTRAIL", Color3.fromRGB(238, 246, 250), 2.8, 10, 18, exhaustOffset)
	end

	-- Flush belly-door outlines make the landing gear installation read as part
	-- of the airframe instead of separate parts floating below it.
	for _, side in ipairs({ -1, 1 }) do
		local noseDoorCF = CFrame.new(side * radius * 0.17, -radius * 0.995, -length * 0.31)
		local noseDoor = makeAircraftPart(model, root.CFrame, "NoseGearDoor" .. side, Vector3.new(radius * 0.26, 0.10, length * 0.065), noseDoorCF, Color3.fromRGB(186, 197, 201), nil, Enum.Material.Metal)
		noseDoor:SetAttribute("GearDoorPart", true)
		noseDoor:SetAttribute("VisualChannel", "LANDING_GEAR_DOORS")
		noseDoor:SetAttribute("ClosedLocalCF", noseDoorCF)
		noseDoor:SetAttribute("OpenLocalCF", noseDoorCF * CFrame.Angles(0, 0, side * math.rad(68)))
		noseDoor:SetAttribute("DoorSequenceOffset", 0)
		local mainDoorCF = CFrame.new(side * radius * 0.62, -radius * 0.91, length * 0.12)
		local mainDoor = makeAircraftPart(model, root.CFrame, "MainGearDoor" .. side, Vector3.new(radius * 0.40, 0.10, length * 0.055), mainDoorCF, Color3.fromRGB(186, 197, 201), nil, Enum.Material.Metal)
		mainDoor:SetAttribute("GearDoorPart", true)
		mainDoor:SetAttribute("VisualChannel", "LANDING_GEAR_DOORS")
		mainDoor:SetAttribute("ClosedLocalCF", mainDoorCF)
		mainDoor:SetAttribute("OpenLocalCF", mainDoorCF * CFrame.Angles(0, 0, side * math.rad(62)))
		mainDoor:SetAttribute("DoorSequenceOffset", 0.08)
	end

	local gear = Instance.new("Folder")
	gear.Name = "LandingGear"
	gear.Parent = model
	local visibleWheelCount = 0
	local function tagGearVisual(part, baseLocalCF, retractedLocalCF, channel)
		part:SetAttribute("GearPart", true)
		part:SetAttribute("VisualChannel", channel or "LANDING_GEAR")
		part:SetAttribute("BaseLocalCF", baseLocalCF)
		part:SetAttribute("RetractedLocalCF", retractedLocalCF or baseLocalCF)
		part:SetAttribute("ExtendedTransparency", part.Transparency)
	end
	local function gearPart(name, size, localCF, retractedLocalCF, color, shape, material, truckRig)
		local part = makeAircraftPart(gear, root.CFrame, name, size, localCF, color, shape, material, decorative and 1 or 0)
		tagGearVisual(part, localCF, retractedLocalCF, "LANDING_GEAR")
		local function tagTruckVisual(truckPart)
			if not truckRig then return end
			truckPart:SetAttribute("GearTruckId", truckRig.Id)
			if truckRig.BasePivotCF then
				truckPart:SetAttribute("TruckPivotBaseCF", truckRig.BasePivotCF)
				truckPart:SetAttribute("TruckPivotRetractedCF", truckRig.RetractedPivotCF)
				truckPart:SetAttribute("TruckMaxTiltDegrees", truckRig.MaxTiltDegrees or 0)
				truckPart:SetAttribute("TruckTiltDirection", truckRig.TiltDirection or 1)
			end
			if truckRig.CompressionGroup then
				truckPart:SetAttribute("GearCompressionGroup", truckRig.CompressionGroup)
				truckPart:SetAttribute("GearCompressionFactor", truckRig.CompressionFactor or 1)
			end
		end
		tagTruckVisual(part)
		local isTire = material == Enum.Material.Rubber and string.find(name, "Wheel", 1, true) ~= nil
		local isWheelAssembly = isTire or string.find(name, "Hub", 1, true) ~= nil
		if isWheelAssembly then
			part:SetAttribute("WheelPart", true)
			part:SetAttribute("WheelDirection", 1)
			part:SetAttribute("WheelRadius", math.max(size.Y, size.Z) * 0.5)
			part:SetAttribute("VisualChannel", "WHEELS")
		end
		if string.sub(name, 1, 4) == "Nose" and name ~= "NoseStrut" then
			part:SetAttribute("NoseSteerPart", true)
		end
		if isTire then
			for tread = -1, 1 do
				local treadCF = localCF * CFrame.new(tread * size.X * 0.25, 0, 0)
				local treadRetractedCF = (retractedLocalCF or localCF) * CFrame.new(tread * size.X * 0.25, 0, 0)
				local band = makeAircraftPart(gear, root.CFrame, name .. "Tread" .. tread, Vector3.new(math.max(0.045, size.X * 0.045), size.Y * 1.018, size.Z * 1.018), treadCF, Color3.fromRGB(10, 13, 14), Enum.PartType.Cylinder, Enum.Material.Rubber, decorative and 1 or 0)
				tagGearVisual(band, treadCF, treadRetractedCF, "WHEELS")
				tagTruckVisual(band)
				band:SetAttribute("WheelPart", true)
				band:SetAttribute("WheelDirection", 1)
				if string.sub(name, 1, 4) == "Nose" then band:SetAttribute("NoseSteerPart", true) end
			end
			if string.find(name, "MainWheel", 1, true) or string.find(name, "BodyGearWheel", 1, true) then
				local disc = makeAircraftPart(gear, root.CFrame, name .. "BrakeDisc", Vector3.new(size.X * 0.62, size.Y * 0.58, size.Z * 0.58), localCF, Color3.fromRGB(103, 94, 86), Enum.PartType.Cylinder, Enum.Material.Metal, decorative and 1 or 0)
				tagGearVisual(disc, localCF, retractedLocalCF, "WHEELS")
				tagTruckVisual(disc)
				disc:SetAttribute("WheelPart", true)
				disc:SetAttribute("WheelDirection", 1)
			end
		end
		if isTire then visibleWheelCount += 1 end
		return part
	end
	local wheelDiameter = math.max(1.05, radius * 0.50)
	local tireVariant = AircraftMeshManifest.Variants[spec.Code]
	local mainTireAspectRatio = 0.38
	local noseTireAspectRatio = 0.34
	if tireVariant and tireVariant.MainTire and tireVariant.MainTire.DiameterStuds > 0 then
		mainTireAspectRatio = math.clamp(tireVariant.MainTire.WidthStuds / tireVariant.MainTire.DiameterStuds, 0.28, 0.46)
	end
	if tireVariant and tireVariant.NoseTire and tireVariant.NoseTire.DiameterStuds > 0 then
		noseTireAspectRatio = math.clamp(tireVariant.NoseTire.WidthStuds / tireVariant.NoseTire.DiameterStuds, 0.26, 0.46)
	end
	local noseWheelDiameter = wheelDiameter * 0.72
	local mainWheelWidth = wheelDiameter * mainTireAspectRatio
	local noseWheelWidth = noseWheelDiameter * noseTireAspectRatio
	model:SetAttribute("WheelRadius", wheelDiameter * 0.5)
	model:SetAttribute("MainTireWidth", mainWheelWidth)
	model:SetAttribute("NoseTireWidth", noseWheelWidth)
	model:SetAttribute("MainTireAspectRatio", mainTireAspectRatio)
	model:SetAttribute("NoseTireAspectRatio", noseTireAspectRatio)
	model:SetAttribute("TireSpecificationStatus", tireVariant and tireVariant.TireStatus or "PROPORTIONAL_FALLBACK")
	model:SetAttribute("TireGeometryRevision", 28)
	local wheelY = -radius - wheelDiameter * 0.38
	local noseZ = -length * 0.31
	local mainZ = length * 0.12
	local mainX = math.max(radius * 1.18, wheelDiameter)
	local strutTopY = -radius * 0.55
	local strutHeight = strutTopY - wheelY
	local noseStrutCF = CFrame.new(0, wheelY + strutHeight / 2, noseZ)
	local noseRetractedCF = CFrame.new(0, -radius * 0.68, noseZ + wheelDiameter * 0.62) * CFrame.Angles(math.rad(76), 0, 0)
	local noseCompressionRig = { Id = "NOSE", CompressionGroup = "NOSE", CompressionFactor = 1 }
	gearPart("NoseStrut", Vector3.new(0.28, strutHeight, 0.28), noseStrutCF, noseRetractedCF, AIRFRAME_GREY, nil, Enum.Material.Metal)
	gearPart("NoseOleoPiston", Vector3.new(0.18, strutHeight * 0.54, 0.18), CFrame.new(0, wheelY + strutHeight * 0.30, noseZ), noseRetractedCF, Color3.fromRGB(225, 231, 232), nil, Enum.Material.Metal, noseCompressionRig)
	gearPart("NoseAxle", Vector3.new(noseWheelWidth * 2.30, 0.24, 0.24), CFrame.new(0, wheelY, noseZ), CFrame.new(0, -radius * 0.70, noseZ + wheelDiameter * 0.66), PANEL_GREY, nil, Enum.Material.Metal, noseCompressionRig)
	gearPart("NoseTorqueLink", Vector3.new(0.18, strutHeight * 0.44, 0.18), CFrame.new(0, wheelY + strutHeight * 0.34, noseZ + wheelDiameter * 0.18) * CFrame.Angles(math.rad(18), 0, 0), CFrame.new(0, -radius * 0.68, noseZ + wheelDiameter * 0.66), PANEL_GREY, nil, Enum.Material.Metal, noseCompressionRig)
	for _, side in ipairs({ -1, 1 }) do
		gearPart("NoseSteeringActuator" .. side, Vector3.new(0.12, strutHeight * 0.36, 0.12), CFrame.new(side * 0.20, wheelY + strutHeight * 0.36, noseZ + wheelDiameter * 0.10) * CFrame.Angles(math.rad(16), 0, side * math.rad(9)), noseRetractedCF, Color3.fromRGB(151, 161, 164), nil, Enum.Material.Metal, noseCompressionRig)
	end
	for _, side in ipairs({ -1, 1 }) do
		local noseWheelCF = CFrame.new(side * noseWheelWidth * 0.58, wheelY, noseZ)
		local noseWheelRetractedCF = CFrame.new(side * noseWheelWidth * 0.58, -radius * 0.70, noseZ + wheelDiameter * 0.66)
		gearPart("NoseWheel" .. side, Vector3.new(noseWheelWidth, noseWheelDiameter, noseWheelDiameter), noseWheelCF, noseWheelRetractedCF, Color3.fromRGB(18, 22, 23), Enum.PartType.Cylinder, Enum.Material.Rubber, noseCompressionRig)
		gearPart("NoseWheelHub" .. side, Vector3.new(noseWheelWidth * 0.68, noseWheelDiameter * 0.34, noseWheelDiameter * 0.34), noseWheelCF, noseWheelRetractedCF, Color3.fromRGB(156, 164, 166), Enum.PartType.Cylinder, Enum.Material.Metal, noseCompressionRig)
	end
	local mainAxleCount = spec.MainGearAxles or 1
	-- Axle rows need a visible longitudinal gap. The old 0.62-diameter spacing
	-- forced neighboring tires through one another on every multi-axle bogie.
	local axleSpacing = wheelDiameter * 1.12
	local mainTruckTiltDegrees = mainAxleCount >= 3 and 11 or (mainAxleCount == 2 and 9 or 0)
	model:SetAttribute("MainGearAxles", mainAxleCount)
	model:SetAttribute("MainGearAxleSpacing", axleSpacing)
	model:SetAttribute("MainGearLongitudinalOffset", mainZ)
	model:SetAttribute("NoseGearLongitudinalOffset", noseZ)
	model:SetAttribute("MainTruckTiltDegrees", mainTruckTiltDegrees)
	for _, side in ipairs({ -1, 1 }) do
		local mainStrutCF = CFrame.new(side * mainX, wheelY + strutHeight / 2, mainZ)
		local mainStrutRetractedCF = CFrame.new(side * radius * 0.52, -radius * 0.64, mainZ) * CFrame.Angles(0, 0, -side * math.rad(72))
		gearPart("MainStrut" .. side, Vector3.new(0.34, strutHeight, 0.34), mainStrutCF, mainStrutRetractedCF, AIRFRAME_GREY, nil, Enum.Material.Metal)
		gearPart("MainSideStay" .. side, Vector3.new(0.22, strutHeight * 0.86, 0.22), CFrame.new(side * (mainX - radius * 0.20), wheelY + strutHeight * 0.58, mainZ) * CFrame.Angles(0, 0, side * math.rad(24)), mainStrutRetractedCF, PANEL_GREY, nil, Enum.Material.Metal)
		local truckLength = math.max(0.40, (mainAxleCount - 1) * axleSpacing + wheelDiameter * 0.24)
		local truckCF = CFrame.new(side * mainX, wheelY + wheelDiameter * 0.08, mainZ)
		local truckRetractedCF = CFrame.new(side * radius * 0.58, -radius * 0.67, mainZ)
		local truckRig = {
			Id = "MAIN_" .. side,
			BasePivotCF = truckCF,
			RetractedPivotCF = truckRetractedCF,
			MaxTiltDegrees = mainTruckTiltDegrees,
			TiltDirection = 1,
			CompressionGroup = "MAIN",
			CompressionFactor = 1,
		}
		local mainCompressionRig = { Id = "MAIN_OLEO_" .. side, CompressionGroup = "MAIN", CompressionFactor = 0.72 }
		gearPart("MainOleoPiston" .. side, Vector3.new(0.20, strutHeight * 0.58, 0.20), CFrame.new(side * mainX, wheelY + strutHeight * 0.31, mainZ), mainStrutRetractedCF, Color3.fromRGB(225, 231, 232), nil, Enum.Material.Metal, mainCompressionRig)
		gearPart("MainTruckBeam" .. side, Vector3.new(mainWheelWidth * 2.35, 0.28, truckLength), truckCF, truckRetractedCF, PANEL_GREY, nil, Enum.Material.Metal, truckRig)
		for axleIndex = 1, mainAxleCount do
			local axleZ = mainZ + (axleIndex - (mainAxleCount + 1) / 2) * axleSpacing
			for _, wheelSide in ipairs({ -1, 1 }) do
				local wheelX = side * mainX + wheelSide * mainWheelWidth * 0.58
				local wheelCF = CFrame.new(wheelX, wheelY, axleZ)
				local wheelRetractedCF = CFrame.new(side * radius * 0.58 + wheelSide * mainWheelWidth * 0.28, -radius * 0.68, mainZ + (axleIndex - (mainAxleCount + 1) / 2) * wheelDiameter * 0.25)
				local wheelName = side .. "_" .. axleIndex .. "_" .. wheelSide
				gearPart("MainWheel" .. wheelName, Vector3.new(mainWheelWidth, wheelDiameter, wheelDiameter), wheelCF, wheelRetractedCF, Color3.fromRGB(18, 22, 23), Enum.PartType.Cylinder, Enum.Material.Rubber, truckRig)
				gearPart("MainWheelHub" .. wheelName, Vector3.new(mainWheelWidth * 0.68, wheelDiameter * 0.32, wheelDiameter * 0.32), wheelCF, wheelRetractedCF, Color3.fromRGB(156, 164, 166), Enum.PartType.Cylinder, Enum.Material.Metal, truckRig)
				gearPart("MainBrakeCaliper" .. wheelName, Vector3.new(math.max(0.16, mainWheelWidth * 0.28), wheelDiameter * 0.20, wheelDiameter * 0.16), wheelCF * CFrame.new(-wheelSide * mainWheelWidth * 0.28, -wheelDiameter * 0.22, 0), wheelRetractedCF, Color3.fromRGB(138, 73, 48), nil, Enum.Material.Metal, truckRig)
			end
		end
	end
	-- Body-mounted bogies are explicit catalog data: three axles per A380 body
	-- truck and two axles per 747-8 body truck.
	local bodyAxles = spec.BodyGearAxles or 0
	model:SetAttribute("BodyGearAxles", bodyAxles)
	if bodyAxles > 0 then
		local bodyX = radius * 0.56
		for _, side in ipairs({ -1, 1 }) do
			local bodyStrutCF = CFrame.new(side * bodyX, wheelY + strutHeight / 2, mainZ + wheelDiameter * 0.16)
			local bodyRetractedCF = CFrame.new(side * radius * 0.32, -radius * 0.66, mainZ) * CFrame.Angles(0, 0, -side * math.rad(68))
			gearPart("BodyGearStrut" .. side, Vector3.new(0.34, strutHeight, 0.34), bodyStrutCF, bodyRetractedCF, AIRFRAME_GREY, nil, Enum.Material.Metal)
			local bodyTruckLength = math.max(0.40, (bodyAxles - 1) * axleSpacing + wheelDiameter * 0.24)
			local bodyTruckCF = CFrame.new(side * bodyX, wheelY + wheelDiameter * 0.08, mainZ + wheelDiameter * 0.16)
			local bodyTruckRig = {
				Id = "BODY_" .. side,
				BasePivotCF = bodyTruckCF,
				RetractedPivotCF = bodyRetractedCF,
				MaxTiltDegrees = bodyAxles >= 3 and 9 or 7,
				TiltDirection = 1,
				CompressionGroup = "MAIN",
				CompressionFactor = 0.92,
			}
			local bodyCompressionRig = { Id = "BODY_OLEO_" .. side, CompressionGroup = "MAIN", CompressionFactor = 0.66 }
			gearPart("BodyGearOleoPiston" .. side, Vector3.new(0.20, strutHeight * 0.56, 0.20), CFrame.new(side * bodyX, wheelY + strutHeight * 0.31, mainZ + wheelDiameter * 0.16), bodyRetractedCF, Color3.fromRGB(225, 231, 232), nil, Enum.Material.Metal, bodyCompressionRig)
			gearPart("BodyGearTruck" .. side, Vector3.new(mainWheelWidth * 2.35, 0.28, bodyTruckLength), bodyTruckCF, bodyRetractedCF, PANEL_GREY, nil, Enum.Material.Metal, bodyTruckRig)
			for axleIndex = 1, bodyAxles do
				local axleZ = mainZ + wheelDiameter * 0.16 + (axleIndex - (bodyAxles + 1) / 2) * axleSpacing
				for _, wheelSide in ipairs({ -1, 1 }) do
					local wheelX = side * bodyX + wheelSide * mainWheelWidth * 0.58
					local wheelCF = CFrame.new(wheelX, wheelY, axleZ)
					gearPart("BodyGearWheel" .. side .. "_" .. axleIndex .. "_" .. wheelSide, Vector3.new(mainWheelWidth, wheelDiameter, wheelDiameter), wheelCF, bodyRetractedCF, Color3.fromRGB(18, 22, 23), Enum.PartType.Cylinder, Enum.Material.Rubber, bodyTruckRig)
					gearPart("BodyGearHub" .. side .. "_" .. axleIndex .. "_" .. wheelSide, Vector3.new(mainWheelWidth * 0.68, wheelDiameter * 0.32, wheelDiameter * 0.32), wheelCF, bodyRetractedCF, Color3.fromRGB(156, 164, 166), Enum.PartType.Cylinder, Enum.Material.Metal, bodyTruckRig)
					gearPart("BodyGearBrakeCaliper" .. side .. "_" .. axleIndex .. "_" .. wheelSide, Vector3.new(math.max(0.16, mainWheelWidth * 0.28), wheelDiameter * 0.20, wheelDiameter * 0.16), wheelCF * CFrame.new(-wheelSide * mainWheelWidth * 0.28, -wheelDiameter * 0.22, 0), bodyRetractedCF, Color3.fromRGB(138, 73, 48), nil, Enum.Material.Metal, bodyTruckRig)
				end
			end
		end
	end
	model:SetAttribute("ExpectedWheelCount", spec.ExpectedWheelCount or visibleWheelCount)
	model:SetAttribute("WheelCount", visibleWheelCount)
	if spec.ExpectedWheelCount and visibleWheelCount ~= spec.ExpectedWheelCount then
		warn(string.format("%s generated %d wheels; catalog expects %d", spec.Code, visibleWheelCount, spec.ExpectedWheelCount))
	end

	-- Typed exterior-light rigs are driven client-side, so flashes and beams are
	-- cosmetic and do not add server heartbeat work.
	local wingTipZ = wingRootZ + outerTipDistance * math.tan(math.rad(sweep))
	local wingTipY = wingY + outerTipDistance * wingDihedralSlope
	local leftNavigationCF = CFrame.new(-outerTipDistance, wingTipY, wingTipZ)
	local rightNavigationCF = CFrame.new(outerTipDistance, wingTipY, wingTipZ)
	local leftNavigation = addAircraftLight(model, root.CFrame, "LeftNavigationLight", leftNavigationCF.Position, Color3.fromRGB(255, 52, 62), 22, "NAVIGATION", false, "LEFT_NAVIGATION")
	local rightNavigation = addAircraftLight(model, root.CFrame, "RightNavigationLight", rightNavigationCF.Position, Color3.fromRGB(53, 255, 118), 22, "NAVIGATION", false, "RIGHT_NAVIGATION")
	local leftStrobeCF = leftNavigationCF * CFrame.new(0.16, 0.05, 0.22)
	local rightStrobeCF = rightNavigationCF * CFrame.new(-0.16, 0.05, 0.22)
	local leftStrobe = addAircraftLight(model, root.CFrame, "LeftWingtipStrobe", leftStrobeCF.Position, Color3.fromRGB(239, 249, 255), 34, "STROBE", false, "LEFT_STROBE")
	local rightStrobe = addAircraftLight(model, root.CFrame, "RightWingtipStrobe", rightStrobeCF.Position, Color3.fromRGB(239, 249, 255), 34, "STROBE", false, "RIGHT_STROBE")
	addAircraftEmitter(leftNavigation, "LeftWingtipVortex", "VORTEX", Color3.fromRGB(225, 241, 248), 1.6, 7, 13)
	addAircraftEmitter(rightNavigation, "RightWingtipVortex", "VORTEX", Color3.fromRGB(225, 241, 248), 1.6, 7, 13)
	configureWingFlex(leftNavigation, leftNavigationCF, 1.08, -1, true)
	configureWingFlex(rightNavigation, rightNavigationCF, 1.08, 1, true)
	configureWingFlex(leftStrobe, leftStrobeCF, 1.08, -1, true)
	configureWingFlex(rightStrobe, rightStrobeCF, 1.08, 1, true)
	if spec.FoldingTips then
		local hingeDistance = exposedHalfSpan * 0.93
		local hingeZ = wingRootZ + hingeDistance * math.tan(math.rad(sweep))
		local hingeY = wingY + hingeDistance * wingDihedralSlope
		for _, lightRig in ipairs({ { leftNavigation, -1 }, { rightNavigation, 1 }, { leftStrobe, -1 }, { rightStrobe, 1 } }) do
			lightRig[1]:SetAttribute("FoldingWingtipPart", true)
			lightRig[1]:SetAttribute("FoldPivotCF", CFrame.new(lightRig[2] * hingeDistance, hingeY, hingeZ))
			lightRig[1]:SetAttribute("FoldDirection", lightRig[2])
		end
	end
	addAircraftLight(model, root.CFrame, "TailNavigationLight", Vector3.new(0, radius * 0.30, length * 0.498), Color3.fromRGB(239, 249, 255), 27, "TAIL_NAVIGATION", false, "TAIL_NAVIGATION")
	addAircraftLight(model, root.CFrame, "TailStrobe", Vector3.new(0, radius * 0.34, length * 0.493), Color3.fromRGB(236, 249, 255), 34, "STROBE", false, "TAIL_STROBE")
	addAircraftLight(model, root.CFrame, "Beacon", Vector3.new(0, radius * 1.02, -length * 0.03), Color3.fromRGB(255, 52, 52), 22, "BEACON", false, "UPPER_BEACON")
	addAircraftLight(model, root.CFrame, "BellyBeacon", Vector3.new(0, -radius * 1.015, length * 0.02), Color3.fromRGB(255, 48, 48), 20, "BEACON", false, "LOWER_BEACON")
	for _, side in ipairs({ -1, 1 }) do
		addAircraftLight(model, root.CFrame, "LandingLight" .. side, Vector3.new(side * radius * 1.25, -radius * 0.18, wingRootZ - wingRootChord * 0.28), Color3.fromRGB(255, 244, 212), 150, "LANDING", true, "LANDING")
		addAircraftLight(model, root.CFrame, "RunwayTurnoffLight" .. side, Vector3.new(side * radius * 1.55, -radius * 0.42, -length * 0.12), Color3.fromRGB(255, 232, 188), 92, "TURNOFF", true, "TURNOFF")
		addAircraftLight(model, root.CFrame, "WingInspectionLight" .. side, Vector3.new(side * radius * 1.03, radius * 0.10, wingRootZ), Color3.fromRGB(225, 239, 255), 45, "INSPECTION", false, "INSPECTION")
	end
	addAircraftLight(model, root.CFrame, "TaxiLight", Vector3.new(0, -radius * 0.62, -length * 0.30), Color3.fromRGB(255, 239, 199), 105, "TAXI", true, "TAXI")
	addAircraftLight(model, root.CFrame, "LogoLight", Vector3.new(0, radius + tailHeight * 0.30, length * 0.39), Color3.fromRGB(230, 241, 255), 38, "LOGO", false, "LOGO")
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item.Material == Enum.Material.Rubber and item:GetAttribute("WheelPart") == true
			and string.find(item.Name, "MainWheel", 1, true) and not string.find(item.Name, "Tread", 1, true) then
			addAircraftEmitter(item, "TouchdownTireSmoke", "TIRE_SMOKE", Color3.fromRGB(196, 201, 201), 1.4, 5, 0)
			addAircraftEmitter(item, "WetRunwaySpray", "SPRAY", Color3.fromRGB(191, 214, 226), 0.82, 9, 20)
		end
	end
	local rainAnchor = makeAircraftPart(model, root.CFrame, "LocalRainEffectAnchor", Vector3.new(180, 1, 180), CFrame.new(0, 38, 0), Color3.new(), nil, Enum.Material.SmoothPlastic, 1)
	local rainEmitter = addAircraftEmitter(rainAnchor, "LocalRain", "RAIN", Color3.fromRGB(182, 218, 235), 0.75, 72, 135)
	rainEmitter.SpreadAngle = Vector2.new(48, 48)
	rainEmitter.Shape = Enum.ParticleEmitterShape.Box
	rainEmitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume

	local seat = Instance.new("VehicleSeat")
	seat.Name = "PilotSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.CFrame = root.CFrame * CFrame.new(0, radius * 0.28, -length * 0.31)
	seat.Anchored = true
	seat.CanCollide = false
	seat.Transparency = decorative and 1 or 0.4
	seat.Color = Color3.fromRGB(24, 33, 39)
	seat:SetAttribute("AircraftPilotSeat", not decorative)
	seat.Parent = model
	if not decorative then
		local entryPrompts = {}
		for _, side in ipairs({ -1, 1 }) do
			-- Put the prompt beside the forward passenger door and low enough to be
			-- reached from the apron. The old seat-centered prompt sat beyond its
			-- activation radius on the A380's especially wide/tall fuselage.
			local entryY = -radius + math.clamp(radius * 0.25, 2.5, 4.0)
			local entryAnchor = makeAircraftPart(
				model,
				root.CFrame,
				side < 0 and "CockpitEntryAnchorLeft" or "CockpitEntryAnchorRight",
				Vector3.new(2, 5, 2),
				CFrame.new(side * radius * 1.16, entryY, -length * 0.335),
				Color3.new(),
				nil,
				Enum.Material.SmoothPlastic,
				1
			)
			entryAnchor:SetAttribute("AircraftEntryAnchor", true)
			entryAnchor:SetAttribute("EntryPromptRevision", 30)
			local seatReference = Instance.new("ObjectValue")
			seatReference.Name = "PilotSeatReference"
			seatReference.Value = seat
			seatReference.Parent = entryAnchor

			local enterPrompt = Instance.new("ProximityPrompt")
			enterPrompt.Name = "EnterCockpitPrompt"
			enterPrompt.ActionText = "Enter cockpit"
			enterPrompt.ObjectText = spec.Name
			enterPrompt.KeyboardKeyCode = Enum.KeyCode.E
			enterPrompt.HoldDuration = 0.25
			enterPrompt.MaxActivationDistance = math.clamp(radius * 1.45, 22, 32)
			enterPrompt.RequiresLineOfSight = false
			enterPrompt:SetAttribute("AircraftEntryPrompt", true)
			enterPrompt.Parent = entryAnchor
			table.insert(entryPrompts, enterPrompt)
		end
		seat:SetAttribute("EntryPromptAnchorCount", #entryPrompts)
		model:SetAttribute("CockpitEntryRevision", 30)
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			for _, enterPrompt in ipairs(entryPrompts) do
				enterPrompt.Enabled = seat.Occupant == nil
			end
		end)
	end

	if not decorative then
		local labelAnchor = makeAircraftPart(model, root.CFrame, "LabelAnchor", Vector3.new(1, 1, 1), CFrame.new(), spec.Color, nil, Enum.Material.Neon, 1)
		local aircraftLabel = addBillboard(labelAnchor, spec.Code .. "  •  " .. spec.Name, spec.Color, Vector3.new(0, fullHeight + 8, 0))
		aircraftLabel.MaxDistance = 300
	end

	-- Preserve the complete pre-architecture aircraft before any container moves,
	-- welding, or collision-proxy creation. Backups remain inert in ServerStorage.
	if not decorative then preserveBeforeVisualUpgradeBackup(model, spec) end
	AircraftMaterialConfig.Apply(model)

	local function makeCollisionProxy(name, size, localCF, role)
		local proxy = makeAircraftPart(model, root.CFrame, name, size, localCF, Color3.new(), nil, Enum.Material.SmoothPlastic, 1)
		proxy:SetAttribute("CollisionProxy", true)
		proxy:SetAttribute("CollisionRole", role)
		proxy.CanCollide = false
		proxy.CanTouch = false
		proxy.CanQuery = true
		proxy.CastShadow = false
		return proxy
	end
	makeCollisionProxy("FuselageCollision", Vector3.new(diameter * 0.88, diameter * 0.82, length * 0.84), CFrame.new(), "FUSELAGE")
	for _, side in ipairs({ -1, 1 }) do
		local distance = exposedHalfSpan * 0.50
		local wingCollisionCF = CFrame.new(
			side * distance,
			wingY + distance * wingDihedralSlope,
			wingRootZ + distance * math.tan(math.rad(sweep))
		) * CFrame.Angles(0, -side * math.rad(sweep), -side * math.rad(2))
		makeCollisionProxy(
			side < 0 and "LeftWingCollision" or "RightWingCollision",
			Vector3.new(exposedHalfSpan * 0.96, math.max(0.5, radius * 0.18), wingRootChord * 0.64),
			wingCollisionCF,
			side < 0 and "LEFT_WING" or "RIGHT_WING"
		)
	end
	makeCollisionProxy("TailCollision", Vector3.new(tailSpan * 0.82, math.max(0.6, radius * 0.28), length * 0.13), CFrame.new(0, tailPlaneY, length * 0.40), "TAIL")
	model:SetAttribute("CollisionProxyCount", 4)

	-- Every movable wing/tail visual names the fixed surface it must meet. This
	-- one-time audit makes a disconnected generator change visible immediately.
	local expectedConnections = {
		MainWing = false,
		WingRootFairing = false,
		HorizontalStabilizer = false,
		SculptedVerticalStabilizer = false,
	}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			for targetName in pairs(expectedConnections) do
				if string.sub(item.Name, 1, #targetName) == targetName then expectedConnections[targetName] = true end
			end
		end
	end
	local disconnectedVisuals = 0
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			local targetName = item:GetAttribute("ConnectedVisualParent")
			if targetName then
				local connected = expectedConnections[targetName] == true
				item:SetAttribute("VisualConnectionVerified", connected)
				if not connected then disconnectedVisuals += 1 end
			end
		end
	end
	model:SetAttribute("DisconnectedVisualCount", disconnectedVisuals)
	model:SetAttribute("VisualConnectionAuditRevision", 28)

	AircraftVisualController.Organize(model, root)
	model:PivotTo(spawnCF)
	return model, seat, gear
end

local active = {}
local lastSpawn = {}

local function spawnCFrameFor(airport, spec)
	local headingCF = CFrame.Angles(0, math.rad(-airport.Heading), 0)
	local fuselageRadius = ((spec and spec.WidthM) or 4.0) * STUDS_PER_METRE / 2
	local aircraftLength = ((spec and spec.LengthM) or 52) * STUDS_PER_METRE
	local wheelDiameter = math.max(1.05, fuselageRadius * 0.50)
	local runwaySurfaceY = airport.Position.Y + 3.4
	local rootY = runwaySurfaceY + fuselageRadius + wheelDiameter * 0.88
	-- Align every differently sized airliner's forward-left door with the cab.
	local gateOffset = headingCF:VectorToWorldSpace(Vector3.new(Layout.FirstGateX, 0, 70 - aircraftLength * 0.335))
	local gatePosition = airport.Position + gateOffset
	local position = Vector3.new(gatePosition.X, rootY, gatePosition.Z)
	-- Park nose-in so the forward passenger door meets the terminal jetbridge.
	return CFrame.new(position) * headingCF * CFrame.Angles(0, math.rad(180), 0)
end

local buildAircraftAnimationCache = AircraftVisualController.BuildCache
local setGearVisible = AircraftVisualController.SetGear
local setFlapsVisual = AircraftVisualController.SetFlaps
local applyAircraftAnimations = AircraftVisualController.Apply

local function destroyPlayerPlane(player)
	local state = active[player]
	if state and state.Model then state.Model:Destroy() end
	active[player] = nil
end

local function seatPlayer(player, seat)
	task.delay(0.25, function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and seat.Parent then seat:Sit(humanoid) end
	end)
end

local function playerIsSeated(state)
	local occupant = state.Seat and state.Seat.Occupant
	local character = state.Player.Character
	return occupant ~= nil and character ~= nil and occupant:IsDescendantOf(character)
end

local function createState(player, spec, airport)
	destroyPlayerPlane(player)
	local spawnCF = spawnCFrameFor(airport, spec)
	local model, seat, gearFolder = createAirliner(spec, spawnCF, player.UserId, false)
	local groundY = spawnCF.Position.Y
	local state = {
		Player = player,
		Model = model,
		Seat = seat,
		GearFolder = gearFolder,
		AnimationParts = buildAircraftAnimationCache(model),
		AnimationConfig = AircraftAnimationConfig.Get(spec.Code),
		Spec = spec,
		Handling = AircraftHandlingConfig.Get(spec),
		SpawnAirport = airport,
		Position = spawnCF.Position,
		Heading = (airport.Heading + 180) % 360,
		Pitch = 0,
		PitchRate = 0,
		Roll = 0,
		Speed = 0,
		Throttle = 0,
		EnginePower = 0,
		VerticalSpeed = 0,
		VerticalVelocity = 0,
		Engine = false,
		ExternalLights = true,
		AltitudeHold = false,
		AltitudeHoldTargetY = groundY,
		Gear = true,
		GearProgress = 1,
		GearMoving = false,
		Flaps = 0,
		FlapPosition = 0,
		FlapsMoving = false,
		Brake = true,
		Pushback = false,
		PushbackCoasting = false,
		GroundSteer = 0,
		OnGround = true,
		GroundY = groundY,
		LandingPhase = "NONE",
		LandingTimer = 0,
		LandingAirport = nil,
		AirborneBlend = 0,
		AirborneTimer = 0,
		LandingArmed = false,
		GearCompression = 0,
		GearCompressionVelocity = 0,
		NoseGearCompression = 0,
		TouchdownLoad = 0,
		TouchdownReferenceY = groundY,
		TouchdownBlend = 0,
		TouchdownPitchStart = 0,
		TouchdownPitchSupport = 0,
		NoseSettleStartPitch = 0,
		NoseGearClearance = 0,
		TruckTiltProgress = 0,
		WingFlexProgress = 0,
		WingtipFoldProgress = spec.FoldingTips and 1 or 0,
		TailClearanceLimited = false,
		SpoilerProgress = 0,
		SpeedBrake = false,
		SpeedBrakeProgress = 0,
		ReverserProgress = 0,
		FanRotation = 0,
		FanAngularVelocity = 0,
		LastEngineAudioState = false,
		WheelRotation = 0,
		WheelAngularVelocity = 0,
		Sinking = false,
		SinkTimer = 0,
		HadPilot = false,
		SpawnPosition = spawnCF.Position,
		LastSafePosition = spawnCF.Position,
		LastSafeHeading = (airport.Heading + 180) % 360,
		CollisionArmed = false,
		LastCollisionMessage = 0,
		Status = "PARKED",
		Controls = { Pitch = 0, Roll = 0, Throttle = 0 },
		LastInput = os.clock(),
	}
	active[player] = state
	player:SetAttribute("ActiveAircraftCode", spec.Code)
	player:SetAttribute("ActiveAirportCode", airport.Code)
	seatPlayer(player, seat)
	SystemMessage:FireClient(player, "AIRCRAFT READY", "Press E to start engines, then P to release the parking brake.")
	return state
end

local function nearestAirport(position)
	local best = AirportCatalog.List[1]
	local bestDistance = math.huge
	for _, airport in ipairs(AirportCatalog.List) do
		local distance = (Vector3.new(position.X, 0, position.Z) - airport.Position).Magnitude
		if distance < bestDistance then
			best = airport
			bestDistance = distance
		end
	end
	return best, bestDistance
end

local function runwayAt(position)
	for _, airport in ipairs(AirportCatalog.List) do
		local airportCF = CFrame.new(airport.Position) * CFrame.Angles(0, math.rad(-airport.Heading), 0)
		for _, placement in ipairs(Layout.RunwayPlacements(airport)) do
			local runwayCF = airportCF * Layout.RunwayLocalCFrame(placement)
			local runwayPosition = runwayCF:PointToObjectSpace(position)
			if math.abs(runwayPosition.X) < Layout.RunwayWidth / 2 + 10 and math.abs(runwayPosition.Z) < airport.RunwayLength / 2 + 35 then
				return airport
			end
		end
	end
	return nil
end

local collisionSurfaceNames = {
	Island = true,
	IslandShore = true,
	Runway = true,
	Apron = true,
	ParallelTaxiway = true,
	ApronAccessTaxiway = true,
	ApronTaxiLane = true,
	TerminalFloor = true,
	RaisedGateConcourse = true,
	AirportParkingLot = true,
	TerminalAccessRoad = true,
	AirportConnectorRoad = true,
	SafeIslandSpawn = true,
}

local function isAircraftObstacle(part)
	if not part:IsA("BasePart") or not part.CanCollide then return false end
	local name = part.Name
	if collisionSurfaceNames[name] then return false end
	if string.find(name, "Centerline", 1, true) or string.find(name, "Threshold", 1, true) then return false end
	if string.find(name, "TaxiwayConnector", 1, true) or string.find(name, "HoldShortBar", 1, true) then return false end
	if string.find(name, "LandsidePerimeterRoad", 1, true) or string.find(name, "ParkingSpaceLine", 1, true) then return false end
	if string.find(name, "GateStandBase", 1, true) then return false end
	if string.find(name, "Runway", 1, true) or string.find(name, "Taxiway", 1, true) then return false end
	if string.find(name, "Apron", 1, true) or string.find(name, "Stopway", 1, true) then return false end
	if string.find(name, "HoldingPosition", 1, true) or string.find(name, "TouchdownZone", 1, true) then return false end
	if string.find(name, "AirportLandReserve", 1, true) then return false end
	if string.find(name, "GateLeadIn", 1, true) or string.find(name, "RunwayLight", 1, true) then return false end
	return true
end

local function obstacleAtAircraft(state, orientation)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.RespectCanCollide = true
	local excluded = { state.Model }
	if state.Player.Character then table.insert(excluded, state.Player.Character) end
	local ocean = world:FindFirstChild("ConnectedOcean")
	if ocean then table.insert(excluded, ocean) end
	overlap.FilterDescendantsInstances = excluded

	local length = state.Model:GetAttribute("Length") or 52
	local span = state.Model:GetAttribute("Span") or 48
	local diameter = (state.Spec.WidthM or 4) * STUDS_PER_METRE
	local fullHeight = (state.Spec.HeightM or 12) * STUDS_PER_METRE
	local probes = {
		{ orientation, Vector3.new(diameter * 0.90, math.max(diameter * 0.72, fullHeight * 0.38), length * 0.90) },
		{ orientation * CFrame.new(0, -diameter * 0.08, -length * 0.055), Vector3.new(span * 0.92, math.max(1.5, diameter * 0.22), length * 0.25) },
	}
	for _, probe in ipairs(probes) do
		for _, part in ipairs(workspace:GetPartBoundsInBox(probe[1], probe[2], overlap)) do
			if isAircraftObstacle(part) then return part end
		end
	end
	return nil
end

local function resetState(state)
	local airport = state.SpawnAirport
	local spawnCF = spawnCFrameFor(airport, state.Spec)
	state.Position = spawnCF.Position
	state.Heading = (airport.Heading + 180) % 360
	state.Pitch = 0
	state.PitchRate = 0
	state.Roll = 0
	state.Speed = 0
	state.Throttle = 0
	state.EnginePower = 0
	state.VerticalSpeed = 0
	state.VerticalVelocity = 0
	state.Engine = false
	state.Flaps = 0
	state.FlapPosition = 0
	state.FlapsMoving = false
	state.Gear = true
	state.GearProgress = 1
	state.GearMoving = false
	state.Brake = true
	state.Pushback = false
	state.PushbackCoasting = false
	state.GroundSteer = 0
	state.OnGround = true
	state.GroundY = spawnCF.Position.Y
	state.LandingPhase = "NONE"
	state.LandingTimer = 0
	state.LandingAirport = nil
	state.AirborneBlend = 0
	state.AirborneTimer = 0
	state.LandingArmed = false
	state.GearCompression = 0
	state.GearCompressionVelocity = 0
	state.NoseGearCompression = 0
	state.TouchdownLoad = 0
	state.TouchdownReferenceY = spawnCF.Position.Y
	state.TouchdownBlend = 0
	state.TouchdownPitchStart = 0
	state.TouchdownPitchSupport = 0
	state.NoseSettleStartPitch = 0
	state.NoseGearClearance = 0
	state.TruckTiltProgress = 0
	state.WingFlexProgress = 0
	state.WingtipFoldProgress = state.Spec.FoldingTips and 1 or 0
	state.LastEngineAudioState = false
	state.TailClearanceLimited = false
	state.SpoilerProgress = 0
	state.SpeedBrake = false
	state.SpeedBrakeProgress = 0
	state.ExternalLights = true
	state.AltitudeHold = false
	state.AltitudeHoldTargetY = spawnCF.Position.Y
	state.ReverserProgress = 0
	state.FanRotation = 0
	state.FanAngularVelocity = 0
	state.WheelRotation = 0
	state.WheelAngularVelocity = 0
	state.Sinking = false
	state.SinkTimer = 0
	state.HadPilot = false
	state.SpawnPosition = spawnCF.Position
	state.LastSafePosition = spawnCF.Position
	state.LastSafeHeading = (airport.Heading + 180) % 360
	state.CollisionArmed = false
	state.LastCollisionMessage = 0
	state.Status = "PARKED"
	state.Model:PivotTo(spawnCF)
	setGearVisible(state, true, true)
	setFlapsVisual(state, 0, true)
	seatPlayer(state.Player, state.Seat)
end

SpawnPlane.OnServerEvent:Connect(function(player, aircraftCode, airportCode)
	if typeof(aircraftCode) ~= "string" or typeof(airportCode) ~= "string" then return end
	local now = os.clock()
	if lastSpawn[player] and now - lastSpawn[player] < 1.5 then return end
	lastSpawn[player] = now
	local spec = AircraftCatalog.ByCode[aircraftCode]
	local airport = AirportCatalog.ByCode[airportCode]
	if not spec or not airport then return end
	createState(player, spec, airport)
end)

PlaneControl.OnServerEvent:Connect(function(player, payload)
	local state = active[player]
	if not state or typeof(payload) ~= "table" then return end
	if not playerIsSeated(state) then
		state.Controls.Pitch = 0
		state.Controls.Roll = 0
		state.Controls.Throttle = 0
		return
	end
	local pitch = tonumber(payload.Pitch) or 0
	local roll = tonumber(payload.Roll) or 0
	local throttle = tonumber(payload.Throttle) or 0
	state.Controls.Pitch = math.clamp(pitch, -1, 1)
	state.Controls.Roll = math.clamp(roll, -1, 1)
	state.Controls.Throttle = math.clamp(throttle, -1, 1)
	state.LastInput = os.clock()
end)

PlaneAction.OnServerEvent:Connect(function(player, action)
	local state = active[player]
	if not state or typeof(action) ~= "string" then return end
	if not playerIsSeated(state) then return end
	if action == "Engine" then
		state.Engine = not state.Engine
		if not state.Engine then state.Throttle = 0 end
		state.Status = state.Engine and "ENGINES RUNNING" or "ENGINES OFF"
	elseif action == "Brake" then
		state.Pushback = false
		state.PushbackCoasting = false
		state.Brake = not state.Brake
		state.Status = state.Brake and "PARKING BRAKE" or "BRAKE RELEASED"
	elseif action == "Pushback" then
		if state.OnGround and state.LandingPhase == "NONE" and math.abs(state.Speed) <= 10.25 then
			if state.Pushback then
				state.Pushback = false
				state.PushbackCoasting = true
				state.Brake = false
				state.Status = "PUSHBACK COASTING • GRADUAL STOP"
			else
				state.Pushback = true
				state.PushbackCoasting = false
				state.Brake = false
				state.Status = "PUSHBACK ACTIVE • STEERING AVAILABLE"
			end
			state.Throttle = 0
		end
	elseif action == "Gear" then
		if not state.OnGround or state.Speed < 4 then
			setGearVisible(state, not state.Gear)
			state.Status = state.Gear and "GEAR EXTENDING" or "GEAR RETRACTING"
		end
	elseif action == "Flaps" then
		local nextFlaps = (state.Flaps + 1) % 4
		setFlapsVisual(state, nextFlaps)
		state.Status = "FLAPS MOVING TO " .. nextFlaps
	elseif action == "SpeedBrake" then
		state.SpeedBrake = not state.SpeedBrake
		if state.SpeedBrake then
			state.Status = state.OnGround and "SPEED BRAKE ARMED" or "SPEED BRAKE DEPLOYED"
		else
			state.Status = "SPEED BRAKE RETRACTING"
		end
	elseif action == "Lights" then
		state.ExternalLights = not state.ExternalLights
		state.Status = state.ExternalLights and "EXTERIOR LIGHTS ON" or "EXTERIOR LIGHTS OFF"
	elseif action == "AltitudeHold" then
		if state.OnGround then
			state.Status = "ALTITUDE HOLD AVAILABLE AFTER TAKEOFF"
		elseif not state.Engine or state.Speed < state.Spec.StallSpeed + 8 then
			state.Status = "ALTITUDE HOLD UNAVAILABLE • BUILD SAFE SPEED"
		else
			state.AltitudeHold = not state.AltitudeHold
			if state.AltitudeHold then
				state.AltitudeHoldTargetY = state.Position.Y
				state.Status = string.format("ALTITUDE HOLD • %d", math.floor(state.Position.Y - state.GroundY + 0.5))
			else
				state.Status = "ALTITUDE HOLD OFF"
			end
		end
	elseif action == "Reset" then
		resetState(state)
	end
end)

local function lerp(current, target, alpha)
	return current + (target - current) * math.clamp(alpha, 0, 1)
end

local function smoothStep(value)
	local t = math.clamp(value, 0, 1)
	return t * t * (3 - 2 * t)
end

local function smoothingAlpha(rate, dt)
	return 1 - math.exp(-math.max(0, rate) * dt)
end

local function dampedSpring(current, velocity, target, response, damping, dt)
	local acceleration = (target - current) * response * response - 2 * damping * response * velocity
	velocity += acceleration * dt
	current += velocity * dt
	return current, velocity
end

local function moveTowards(current, target, amount)
	if current < target then return math.min(target, current + amount) end
	return math.max(target, current - amount)
end

local MIN_MAIN_GEAR_CONTACT_PITCH = 0.55
local MAIN_GEAR_SUPPORT_PITCH = 1.20
local MAIN_GEAR_MIN_DWELL = 0.90

local function mainGearRootHeight(state, pitch)
	local modelLength = state.Model:GetAttribute("Length") or 52
	local mainGearZ = state.Model:GetAttribute("MainGearLongitudinalOffset") or modelLength * 0.12
	local pitchHeight = math.sin(math.rad(math.max(0, pitch))) * mainGearZ
	local axleCount = state.Model:GetAttribute("MainGearAxles") or 1
	local truckDrop = 0
	if axleCount > 1 and state.GearProgress > 0.20 then
		local axleSpacing = state.Model:GetAttribute("MainGearAxleSpacing") or 0
		local maxTilt = state.Model:GetAttribute("MainTruckTiltDegrees") or 0
		local rearAxleOffset = (axleCount - 1) * axleSpacing * 0.5
		local tiltAngle = math.rad(maxTilt * (state.TruckTiltProgress or 0))
		truckDrop = math.sin(tiltAngle) * rearAxleOffset
	end
	return state.GroundY + pitchHeight + truckDrop
end

local function noseGearClearance(state, pitch)
	local modelLength = state.Model:GetAttribute("Length") or 52
	local mainGearZ = state.Model:GetAttribute("MainGearLongitudinalOffset") or modelLength * 0.12
	local noseGearZ = state.Model:GetAttribute("NoseGearLongitudinalOffset") or -modelLength * 0.31
	local mainGearPitchHeight = math.sin(math.rad(math.max(0, pitch))) * mainGearZ
	local truckHeight = mainGearRootHeight(state, pitch) - state.GroundY - mainGearPitchHeight
	return math.max(0, math.sin(math.rad(math.max(0, pitch))) * (mainGearZ - noseGearZ) + truckHeight)
end

local attributeTimer = 0
RunService.Heartbeat:Connect(function(deltaTime)
	local dt = math.clamp(deltaTime, 0, 0.05)
	attributeTimer += dt
	for player, state in pairs(active) do
		if not player.Parent or not state.Model.Parent then
			active[player] = nil
			continue
		end

		if os.clock() - state.LastInput > 1.5 then
			state.Controls.Pitch = 0
			state.Controls.Roll = 0
			state.Controls.Throttle = 0
		end

		if state.Sinking then
			state.SinkTimer += dt
			state.Engine = false
			state.Throttle = 0
			state.EnginePower = lerp(state.EnginePower, 0, dt * 2.2)
			state.Speed = lerp(state.Speed, 0, dt * 0.75)
			state.Pitch = lerp(state.Pitch, -7, dt * 0.55)
			state.Roll = lerp(state.Roll, math.sin(state.SinkTimer * 1.2) * 5, dt * 0.7)
			local headingRadians = math.rad(state.Heading)
			local forward = Vector3.new(math.sin(headingRadians), 0, -math.cos(headingRadians))
			local sinkRate = 1.8 + state.SinkTimer * 0.55
			state.Position += forward * state.Speed * 0.16 * dt + Vector3.new(0, -sinkRate * dt, 0)
			state.VerticalSpeed = -sinkRate * 60
			state.VerticalVelocity = -sinkRate
			state.Status = "WATER CONTACT • SINKING"
			local sinkOrientation = CFrame.new(state.Position)
				* CFrame.Angles(0, math.rad(-state.Heading), 0)
				* CFrame.Angles(math.rad(state.Pitch), 0, math.rad(-state.Roll))
			state.Model:PivotTo(sinkOrientation)
			state.Model:SetAttribute("Speed", state.Speed)
			state.Model:SetAttribute("Altitude", 0)
			state.Model:SetAttribute("VerticalSpeed", state.VerticalSpeed)
			state.Model:SetAttribute("Engine", false)
			state.Model:SetAttribute("OnGround", false)
			state.Model:SetAttribute("Status", state.Status)
			if state.SinkTimer >= 6 or state.Position.Y <= -18 then
				ReturnToMenu:FireClient(player)
				state.Model:Destroy()
				active[player] = nil
			end
			continue
		end

		local pilotSeated = playerIsSeated(state)
		if pilotSeated then
			state.HadPilot = true
		elseif state.HadPilot then
			state.Controls.Pitch = 0
			state.Controls.Roll = 0
			state.Controls.Throttle = 0
		end

		local gearTarget = state.Gear and 1 or 0
		state.GearProgress = moveTowards(state.GearProgress, gearTarget, dt / 3.4)
		state.GearMoving = math.abs(state.GearProgress - gearTarget) > 0.001
		state.FlapPosition = moveTowards(state.FlapPosition, state.Flaps, dt / 1.35)
		state.FlapsMoving = math.abs(state.FlapPosition - state.Flaps) > 0.001

		if state.Pushback or state.PushbackCoasting then
			state.Throttle = 0
		elseif state.Engine then
			state.Throttle = math.clamp(state.Throttle + state.Controls.Throttle * 32 * dt, 0, 100)
		else
			state.Throttle = lerp(state.Throttle, 0, dt * 2.5)
		end
		local targetEnginePower = state.Engine and state.Throttle or 0
		local spoolRate = targetEnginePower > state.EnginePower and 0.42 or 1.15
		state.EnginePower = lerp(state.EnginePower, targetEnginePower, dt * spoolRate)

		local lastY = state.Position.Y
		if state.OnGround then
			state.VerticalVelocity = 0
			local tailStrikeLimit = state.Model:GetAttribute("TailStrikeLimit") or 6
			local steeringTarget = math.abs(state.Speed) > 0.30 and state.Controls.Roll or 0
			local steeringResponse = (state.Pushback or state.PushbackCoasting) and 0.90 or 1.25
			state.GroundSteer = lerp(state.GroundSteer, steeringTarget, dt * steeringResponse)
			if state.Pushback then
				state.Speed = lerp(state.Speed, -10, dt * 0.42)
				state.Brake = false
				state.Status = "PUSHBACK ACTIVE • MAX 10 KT • STEER WITH A/D"
			elseif state.PushbackCoasting then
				state.Speed = lerp(state.Speed, 0, dt * 0.55)
				state.Brake = false
				state.Status = "PUSHBACK COASTING • GRADUAL STOP"
				if math.abs(state.Speed) < 0.12 then
					state.Speed = 0
					state.PushbackCoasting = false
					state.Brake = false
					state.Status = "PUSHBACK COMPLETE • BRAKE OFF"
				end
			else
				local thrust = state.Engine and (state.EnginePower / 100) * (19.2 / math.max(0.62, state.Spec.Scale)) * state.Handling.Acceleration or 0
				local drag = math.abs(state.Speed) * (state.SpeedBrake and 0.082 or 0.055)
				local braking = state.Brake and PARKING_BRAKE_FORCE * state.Handling.BrakeEffectiveness or 0
				state.Speed = math.clamp(state.Speed + (thrust - drag - braking) * dt, 0, state.Spec.CruiseSpeed)
			end
			if state.LandingPhase == "NONE" and math.abs(state.Speed) > 0.35 then
				if state.Pushback or state.PushbackCoasting then
					local reverseSteering = state.Speed < 0 and -1 or 1
					state.Heading = (state.Heading + state.GroundSteer * reverseSteering * 5.5 * dt) % 360
				elseif state.Throttle > 1 and state.Speed > 0.5 then
					state.Heading = (state.Heading + state.GroundSteer * math.clamp(10 - state.Speed * 0.035, 2.2, 10) * dt) % 360
				end
			end
			if state.LandingPhase == "MAIN_GEAR" then
				state.LandingTimer += dt
				state.TouchdownBlend = math.clamp(state.TouchdownBlend + dt / 0.92, 0, 1)
				-- The pilot still controls the nose, but pitch-rate inertia prevents the
				-- fuselage from snapping when the main wheels first take the load.
				local remainingTailClearance = tailStrikeLimit - state.Pitch
				local tailClearanceAuthority = state.Controls.Pitch > 0
					and smoothStep(math.clamp(remainingTailClearance / 1.15, 0, 1)) or 1
				local desiredPitchRate = state.Controls.Pitch * 2.25 * state.Handling.RotationRate * tailClearanceAuthority
				state.PitchRate = lerp(state.PitchRate, desiredPitchRate, smoothingAlpha(1.35, dt))
				state.Pitch = math.clamp(state.Pitch + state.PitchRate * dt, 0, tailStrikeLimit)
				if state.LandingTimer <= MAIN_GEAR_MIN_DWELL then
					local supportBlend = smoothStep(state.LandingTimer / 0.48)
					local supportedPitch = lerp(state.TouchdownPitchStart, state.TouchdownPitchSupport, supportBlend)
					state.Pitch = math.max(state.Pitch, supportedPitch)
				end
				state.Roll = lerp(state.Roll, state.Controls.Roll * 4, smoothingAlpha(0.52, dt))
				local mainGearHeight = mainGearRootHeight(state, state.Pitch)
				state.TouchdownLoad = lerp(state.TouchdownLoad, 0, smoothingAlpha(0.85, dt))
				state.GearCompression, state.GearCompressionVelocity = dampedSpring(
					state.GearCompression,
					state.GearCompressionVelocity,
					state.TouchdownLoad,
					4.35 * state.Handling.LandingDamping,
					1.10,
					dt
				)
				state.GearCompression = math.clamp(state.GearCompression, 0, 1.22)
				local touchdownHeight = mainGearHeight - state.GearCompression
				local blendedTouchdownHeight = lerp(state.TouchdownReferenceY, touchdownHeight, smoothStep(state.TouchdownBlend))
				state.Position = Vector3.new(state.Position.X, blendedTouchdownHeight, state.Position.Z)
				state.NoseGearClearance = noseGearClearance(state, state.Pitch)
				state.Status = "MAIN GEAR CONTACT • MANUALLY LOWER NOSE"
				if state.Pitch <= 0.22 and state.LandingTimer > MAIN_GEAR_MIN_DWELL then
					state.NoseSettleStartPitch = state.Pitch
					state.PitchRate = 0
					state.LandingPhase = "NOSE_GEAR"
					state.LandingTimer = 0
					state.Status = "NOSE GEAR CONTACT • STRUT SETTLING"
				end
			elseif state.LandingPhase == "NOSE_GEAR" then
				state.LandingTimer += dt
				local settleProgress = smoothStep(state.LandingTimer / 1.65)
				state.Pitch = state.NoseSettleStartPitch * (1 - settleProgress)
				state.Roll = lerp(state.Roll, 0, dt * 2.5)
				state.TouchdownLoad = lerp(state.TouchdownLoad, 0, smoothingAlpha(1.75, dt))
				state.GearCompression, state.GearCompressionVelocity = dampedSpring(state.GearCompression, state.GearCompressionVelocity, 0, 5.5, 1.08, dt)
				local settlingHeight = mainGearRootHeight(state, state.Pitch)
				state.Position = Vector3.new(state.Position.X, settlingHeight - math.max(0, state.GearCompression), state.Position.Z)
				state.NoseGearClearance = noseGearClearance(state, state.Pitch)
				state.Status = "NOSE GEAR CONTACT • STRUT SETTLING"
				if state.LandingTimer >= 1.65 then
					state.Pitch = 0
					state.PitchRate = 0
					state.GearCompression = 0
					state.GearCompressionVelocity = 0
					state.Position = Vector3.new(state.Position.X, state.GroundY, state.Position.Z)
					state.NoseGearClearance = 0
					state.LandingPhase = "ROLLOUT"
					state.LandingTimer = 0
					state.Status = "NOSE GEAR DOWN • ROLLOUT"
					local landedAirport = state.LandingAirport
					if landedAirport then
						SystemMessage:FireClient(player, "LANDING COMPLETE", "Main gear and nose gear are down at " .. landedAirport.Name .. ".")
					end
				end
			elseif state.LandingPhase == "ROLLOUT" then
				state.LandingTimer += dt
				state.Pitch = 0
				state.PitchRate = 0
				state.Roll = lerp(state.Roll, 0, dt * 4)
				state.Position = Vector3.new(state.Position.X, state.GroundY, state.Position.Z)
				state.NoseGearClearance = 0
				if state.LandingTimer < 3.0 then
					state.Status = "NOSE GEAR DOWN • ROLLOUT"
				else
					state.LandingPhase = "NONE"
					state.Status = "LANDED AT " .. (state.LandingAirport and state.LandingAirport.Code or "AIRPORT")
				end
			else
				local rotationSpeed = state.Spec.StallSpeed - state.Flaps * 4
				local rotationStart = rotationSpeed * 0.72
				if state.LandingPhase == "NONE" and state.Speed > rotationStart then
					-- Rotation authority builds with airspeed and follows a damped pitch rate.
					-- The player supplies every degree of pitch; no target attitude is scripted.
					local authority = smoothStep((state.Speed - rotationStart) / math.max(1, rotationSpeed - rotationStart))
					local remainingTailClearance = tailStrikeLimit - state.Pitch
					local tailClearanceAuthority = state.Controls.Pitch > 0
						and smoothStep(math.clamp(remainingTailClearance / 1.15, 0, 1)) or 1
					local desiredPitchRate = state.Controls.Pitch * 2.25 * state.Handling.RotationRate * authority * tailClearanceAuthority
					state.PitchRate = lerp(state.PitchRate, desiredPitchRate, smoothingAlpha(1.0 + authority * 0.48, dt))
					state.Pitch = math.clamp(state.Pitch + state.PitchRate * dt, 0, tailStrikeLimit)
					state.TailClearanceLimited = state.Controls.Pitch > 0.08 and state.Pitch >= tailStrikeLimit - 0.10
					local mainGearHeight = mainGearRootHeight(state, state.Pitch)
					state.Position = Vector3.new(state.Position.X, mainGearHeight, state.Position.Z)
				else
					state.PitchRate = lerp(state.PitchRate, 0, dt * 3.2)
					state.Pitch = lerp(state.Pitch, 0, dt * 1.35)
					state.TailClearanceLimited = false
					state.Position = Vector3.new(state.Position.X, state.GroundY, state.Position.Z)
				end
				state.Roll = lerp(state.Roll, 0, dt * 2.0)
			end
			if state.LandingPhase == "NONE" and state.Speed > state.Spec.StallSpeed - state.Flaps * 4 and state.Pitch > 0.95 then
				state.OnGround = false
				state.Brake = false
				state.AirborneBlend = 0
				state.AirborneTimer = 0
				state.LandingArmed = false
				state.VerticalVelocity = math.max(0.012, math.sin(math.rad(state.Pitch)) * state.Speed * 0.045)
				state.LandingPhase = "AIRBORNE"
				state.Status = "MANUAL LIFTOFF • LIFT BUILDING"
			elseif state.LandingPhase == "NONE" and state.Speed > 5 then
				state.Status = state.TailClearanceLimited and "ROTATE • TAIL CLEARANCE LIMIT" or "TAKEOFF ROLL"
			elseif state.LandingPhase == "NONE" and state.Engine and not state.Pushback and not state.PushbackCoasting then
				state.Status = state.Brake and "READY • BRAKE SET" or "READY TO TAXI"
			end
		else
			state.GroundSteer = lerp(state.GroundSteer, 0, dt * 2.0)
			state.AirborneBlend = math.clamp(state.AirborneBlend + dt / 4.6, 0, 1)
			state.AirborneTimer += dt
			local liftBlend = smoothStep(state.AirborneBlend)
			local targetSpeed = state.Engine and (72 + state.EnginePower * 4.55) or 58
			targetSpeed = math.max(48, targetSpeed - state.FlapPosition * state.Handling.FlapDrag)
			if state.SpeedBrake then targetSpeed *= 0.74 end
			state.Speed = lerp(state.Speed, targetSpeed, dt * (0.18 * state.Handling.Acceleration / math.max(0.65, state.Spec.Scale)))
			local runwayBelow = runwayAt(state.Position)
			local heightAboveRunway = state.Position.Y - state.GroundY
			-- A new departure is not a landing. The touchdown detector is armed only
			-- after the aircraft establishes a real climb, or after a short airborne
			-- interval followed by an actual descent. This prevents the main wheels,
			-- which are still within inches of the runway just after rotation, from
			-- immediately being interpreted as a touchdown.
			if not state.LandingArmed and (
				heightAboveRunway >= 24
				or (state.AirborneTimer >= 4 and state.VerticalVelocity < -0.05)
			) then
				state.LandingArmed = true
			end
			local tailStrikeLimit = state.Model:GetAttribute("TailStrikeLimit") or 6
			local targetPitch = state.Controls.Pitch * 18.5
			-- The approach and flare are completely pilot-controlled. This zone only
			-- softens control response; it never holds altitude or raises the nose.
			local gearReady = state.Gear and state.GearProgress >= 0.92
			local approachHeightBlend = runwayBelow and gearReady
				and smoothStep(math.clamp(1 - heightAboveRunway / 80, 0, 1)) or 0
			local approachSpeedBlend = smoothStep(math.clamp(1 - math.max(0, state.Speed - (state.Spec.StallSpeed + 45)) / 40, 0, 1))
			local landingBlend = state.LandingArmed and (approachHeightBlend * approachSpeedBlend) or 0
			local manualLandingZone = landingBlend > 0.02
			if state.AltitudeHold and (
				not state.Engine
				or state.Speed < state.Spec.StallSpeed + 6
				or (state.LandingArmed and heightAboveRunway < 95)
			) then
				state.AltitudeHold = false
				state.Status = "ALTITUDE HOLD DISENGAGED"
			end
			local altitudeHoldError = (state.AltitudeHoldTargetY or state.Position.Y) - state.Position.Y
			if state.AltitudeHold then
				-- A modest cruise attitude and damped error correction keep the
				-- airplane level without snapping to the captured altitude.
				targetPitch = math.clamp(2.15 + altitudeHoldError * 0.018 - state.VerticalVelocity * 0.24, -2.5, 6.5)
			end
			-- Near the runway, progressively restrict only excessive nose-up attitude.
			-- The limit fades away with height and never supplies a flare input.
			local tailClearanceBlend = runwayBelow and gearReady
				and smoothStep(math.clamp(1 - heightAboveRunway / 28, 0, 1)) or 0
			if targetPitch > tailStrikeLimit then
				targetPitch = lerp(targetPitch, tailStrikeLimit, tailClearanceBlend)
			end
			local targetRoll = state.Controls.Roll * state.Handling.BankMax
			local pitchResponse = lerp(lerp(0.38, 1.15 * state.Spec.Response * state.Handling.PitchResponse, liftBlend), 0.55 * state.Handling.PitchResponse, landingBlend)
			local rollResponse = lerp(lerp(0.42, 0.76 * state.Spec.Response * state.Handling.RollResponse, liftBlend), 0.54 * state.Handling.RollResponse, landingBlend)
			state.Pitch = lerp(state.Pitch, targetPitch, smoothingAlpha(pitchResponse, dt))
			state.Roll = lerp(state.Roll, targetRoll, smoothingAlpha(rollResponse, dt))
			local physicalPitchLimit = lerp(18.5, tailStrikeLimit, tailClearanceBlend)
			state.Pitch = math.min(state.Pitch, physicalPitchLimit)
			state.Heading = (state.Heading + state.Roll * dt * (0.11 + state.Speed / 2400)) % 360

			local effectiveStall = state.Spec.StallSpeed - state.Flaps * 5
			local stallSink = state.Speed < effectiveStall and (effectiveStall - state.Speed) * 0.13 or 0
			-- Neutral pitch now produces a gentle natural descent instead of a hover.
			-- The pilot must add a little positive pitch to level off or flare.
			local groundEffect = runwayBelow and smoothStep(math.clamp(1 - heightAboveRunway / 32, 0, 1)) * 0.16 or 0
			local naturalSink = (0.55 + math.max(0, effectiveStall + 18 - state.Speed) * 0.018) * (1 - groundEffect)
			local liftFactor = lerp(0.055, 0.28, liftBlend)
			-- Airliner attitude and flight path are not the same on approach. With
			-- landing flaps selected, the wing can carry the aircraft while the body
			-- remains a few degrees nose-up on a descending glide path. Pulling beyond
			-- that reference attitude still arrests the sink for a pilot-made flare.
			local approachReferencePitch = landingBlend * (1.75 + state.FlapPosition * 0.92)
			local aerodynamicPitch = state.Pitch - approachReferencePitch
			local speedBrakeSink = state.SpeedBrake and (0.55 + state.Speed * 0.0065) or 0
			local desiredVerticalVelocity = math.sin(math.rad(aerodynamicPitch)) * state.Speed * liftFactor - naturalSink - stallSink - speedBrakeSink
			local verticalResponse = lerp(lerp(0.26, 1.18, liftBlend), 0.42, landingBlend)
			if state.AltitudeHold then
				desiredVerticalVelocity = math.clamp(altitudeHoldError * 0.12, -3.8, 3.8)
				verticalResponse = 0.52 * state.Handling.PitchResponse
			end
			state.VerticalVelocity = lerp(state.VerticalVelocity, desiredVerticalVelocity, smoothingAlpha(verticalResponse, dt))
			state.Position += Vector3.new(0, state.VerticalVelocity * dt, 0)
			if state.Speed < effectiveStall + 5 then
				state.Status = "STALL • LOWER NOSE"
			elseif manualLandingZone then
				state.Status = "MANUAL FLARE • MAIN GEAR FIRST"
			elseif state.AltitudeHold then
				state.Status = string.format("ALT HOLD • %d", math.floor((state.AltitudeHoldTargetY - state.GroundY) + 0.5))
			elseif state.Position.Y - state.GroundY < 80 then
				state.Status = "LOW ALTITUDE"
			else
				state.Status = "FREE FLIGHT"
			end

			local mainGearContactY = mainGearRootHeight(state, math.clamp(state.Pitch, 0, tailStrikeLimit))
			if state.Position.Y <= math.max(state.GroundY, mainGearContactY) then
				local runway = runwayBelow or runwayAt(state.Position)
				local nearest, distance = nearestAirport(state.Position)
				local containingIsland = Layout.FindContainingIsland(AirportCatalog.List, state.Position)
				local touchdownEligible = state.LandingArmed
					and state.LandingPhase == "AIRBORNE"
					and state.VerticalVelocity <= 0
					and state.VerticalSpeed <= 60
				if touchdownEligible and runway and gearReady and state.VerticalSpeed > -1050 and math.abs(state.Roll) < 20 then
					state.TouchdownPitchStart = math.max(math.clamp(state.Pitch, 0, tailStrikeLimit), MIN_MAIN_GEAR_CONTACT_PITCH)
					state.TouchdownPitchSupport = math.max(state.TouchdownPitchStart, MAIN_GEAR_SUPPORT_PITCH)
					state.Pitch = state.TouchdownPitchStart
					local touchdownY = mainGearRootHeight(state, state.Pitch)
					local impactVelocity = math.abs(state.VerticalVelocity)
					state.GearCompression = math.clamp(math.max(0, touchdownY - state.Position.Y), 0, 1.10)
					state.GearCompressionVelocity = math.clamp(impactVelocity * 0.062, 0, 1.10)
					state.TouchdownLoad = math.clamp(impactVelocity * 0.042, 0.05, 0.48)
					state.TouchdownReferenceY = state.Position.Y
					state.TouchdownBlend = 0
					state.OnGround = true
					state.VerticalVelocity = 0
					state.PitchRate = 0
					state.Speed *= 0.998
					state.LandingPhase = "MAIN_GEAR"
					state.LandingArmed = false
					state.AltitudeHold = false
					state.LandingTimer = 0
					state.LandingAirport = runway
					state.NoseGearClearance = noseGearClearance(state, state.Pitch)
					state.Status = "MANUAL MAIN GEAR CONTACT"
					SystemMessage:FireClient(player, "MAIN GEAR CONTACT", "Touchdown detected. Keep controlling the pitch and lower the nose gear when ready.")
				elseif touchdownEligible and containingIsland and gearReady and state.Speed < state.Spec.StallSpeed + 40 then
					state.TouchdownPitchStart = math.max(math.clamp(state.Pitch, 0, tailStrikeLimit), MIN_MAIN_GEAR_CONTACT_PITCH)
					state.TouchdownPitchSupport = math.max(state.TouchdownPitchStart, MAIN_GEAR_SUPPORT_PITCH)
					state.Pitch = state.TouchdownPitchStart
					local touchdownY = mainGearRootHeight(state, state.Pitch)
					local impactVelocity = math.abs(state.VerticalVelocity)
					state.GearCompression = math.clamp(math.max(0, touchdownY - state.Position.Y), 0, 1.10)
					state.GearCompressionVelocity = math.clamp(impactVelocity * 0.062, 0, 1.10)
					state.TouchdownLoad = math.clamp(impactVelocity * 0.042, 0.05, 0.48)
					state.TouchdownReferenceY = state.Position.Y
					state.TouchdownBlend = 0
					state.OnGround = true
					state.VerticalVelocity = 0
					state.PitchRate = 0
					state.Speed *= 0.992
					state.LandingPhase = "MAIN_GEAR"
					state.LandingArmed = false
					state.AltitudeHold = false
					state.LandingTimer = 0
					state.LandingAirport = nearest
					state.NoseGearClearance = noseGearClearance(state, state.Pitch)
					state.Status = "OFF-RUNWAY MAIN GEAR CONTACT • MANUAL NOSE"
				elseif state.Position.Y < -3 and containingIsland then
					resetState(state)
					SystemMessage:FireClient(player, "RETURNED TO AIRPORT", "Your aircraft was safely reset at the departure runway.")
				end
			end
		end

		local headingRadians = math.rad(state.Heading)
		local forward = Vector3.new(math.sin(headingRadians), 0, -math.cos(headingRadians))
		local studsPerSecond = state.Speed * 0.72
		state.Position += forward * studsPerSecond * dt
		state.VerticalSpeed = ((state.Position.Y - lastY) / math.max(0.001, dt)) * 60

		local containingSurfaceIsland = Layout.FindContainingIsland(AirportCatalog.List, state.Position)
		if state.OnGround and not containingSurfaceIsland then
			state.OnGround = false
			state.Sinking = true
			state.SinkTimer = 0
			state.Engine = false
			state.Throttle = 0
			state.Controls.Pitch = 0
			state.Controls.Roll = 0
			state.Controls.Throttle = 0
			state.LandingPhase = "SINKING"
			state.Status = "WATER CONTACT • SINKING"
			SystemMessage:FireClient(player, "WATER CONTACT", "The aircraft left the island and is sinking.")
		end

		if not state.OnGround then
			local fuselageRadius = ((state.Spec.WidthM or 4.0) * STUDS_PER_METRE) / 2
			local waterContactY = math.max(1.8, fuselageRadius * 0.82)
			local containingAirborneIsland = Layout.FindContainingIsland(AirportCatalog.List, state.Position)
			if not containingAirborneIsland and state.Position.Y <= waterContactY then
				state.Sinking = true
				state.SinkTimer = 0
				state.Engine = false
				state.Throttle = 0
				state.Controls.Pitch = 0
				state.Controls.Roll = 0
				state.Controls.Throttle = 0
				state.LandingPhase = "SINKING"
				state.Status = "WATER CONTACT • SINKING"
				SystemMessage:FireClient(player, "WATER CONTACT", "The aircraft is sinking. You will return to the menu shortly.")
			end
		end

		if math.abs(state.Position.X) > Layout.WorldRadius or math.abs(state.Position.Z) > Layout.WorldRadius then
			resetState(state)
			SystemMessage:FireClient(player, "WORLD EDGE", "Returned to your departure airport.")
		end

		local orientation = CFrame.new(state.Position)
			* CFrame.Angles(0, math.rad(-state.Heading), 0)
			* CFrame.Angles(math.rad(state.Pitch), 0, math.rad(-state.Roll))
		if not state.Sinking then
			if not state.CollisionArmed and (state.Position - state.SpawnPosition).Magnitude > 55 then
				state.CollisionArmed = true
				state.LastSafePosition = state.Position
				state.LastSafeHeading = state.Heading
			end
			if state.CollisionArmed then
				local obstacle = obstacleAtAircraft(state, orientation)
				if obstacle then
					state.Position = state.LastSafePosition
					state.Heading = state.LastSafeHeading
					state.Speed = 0
					state.Throttle = 0
					state.EnginePower = lerp(state.EnginePower, 0, 0.65)
					state.VerticalVelocity = 0
					state.VerticalSpeed = 0
					state.Pushback = false
					state.PushbackCoasting = false
					state.Brake = true
					state.Controls.Pitch = 0
					state.Controls.Roll = 0
					state.Controls.Throttle = 0
					state.Status = "BLOCKED BY " .. string.upper(obstacle.Name)
					orientation = CFrame.new(state.Position)
						* CFrame.Angles(0, math.rad(-state.Heading), 0)
						* CFrame.Angles(math.rad(state.Pitch), 0, math.rad(-state.Roll))
					if os.clock() - state.LastCollisionMessage > 2 then
						state.LastCollisionMessage = os.clock()
						SystemMessage:FireClient(player, "AIRCRAFT BLOCKED", "A solid " .. obstacle.Name .. " stopped the aircraft.")
					end
				else
					state.LastSafePosition = state.Position
					state.LastSafeHeading = state.Heading
				end
			end
		end
		state.Model:PivotTo(orientation)
		-- Clients own cosmetic Motor6D poses at RenderStepped cadence. The server
		-- continues to advance the authoritative gear/flight state and engine audio
		-- without overwriting the smoother client gear sequence on Heartbeat.
		applyAircraftAnimations(state, dt, false)

		if attributeTimer >= 0.08 then
			local nearest = nearestAirport(state.Position)
			state.Model:SetAttribute("Speed", state.Speed)
			state.Model:SetAttribute("Altitude", math.max(0, state.Position.Y - state.GroundY))
			state.Model:SetAttribute("Heading", state.Heading)
			state.Model:SetAttribute("Pitch", state.Pitch)
			state.Model:SetAttribute("Roll", state.Roll)
			state.Model:SetAttribute("ControlPitch", state.Controls.Pitch)
			state.Model:SetAttribute("ControlRoll", state.Controls.Roll)
			state.Model:SetAttribute("GroundSteer", state.GroundSteer)
			state.Model:SetAttribute("NoseGearClearance", state.NoseGearClearance or 0)
			state.Model:SetAttribute("TruckTiltProgress", state.TruckTiltProgress or 0)
			state.Model:SetAttribute("VerticalSpeed", state.VerticalSpeed)
			state.Model:SetAttribute("VerticalVelocity", state.VerticalVelocity)
			state.Model:SetAttribute("Throttle", state.Throttle)
			state.Model:SetAttribute("EnginePower", state.EnginePower)
			state.Model:SetAttribute("Engine", state.Engine)
			state.Model:SetAttribute("ExternalLights", state.ExternalLights)
			state.Model:SetAttribute("AltitudeHold", state.AltitudeHold)
			state.Model:SetAttribute("AltitudeHoldTarget", math.max(0, (state.AltitudeHoldTargetY or state.GroundY) - state.GroundY))
			state.Model:SetAttribute("Gear", state.Gear)
			state.Model:SetAttribute("GearProgress", state.GearProgress)
			state.Model:SetAttribute("GearMoving", state.GearMoving)
			state.Model:SetAttribute("GearCompression", state.GearCompression or 0)
			state.Model:SetAttribute("NoseGearCompression", state.NoseGearCompression or 0)
			state.Model:SetAttribute("Flaps", state.Flaps)
			state.Model:SetAttribute("FlapPosition", state.FlapPosition)
			state.Model:SetAttribute("FlapsMoving", state.FlapsMoving)
			state.Model:SetAttribute("SpeedBrake", state.SpeedBrake)
			state.Model:SetAttribute("SpeedBrakeProgress", state.SpeedBrakeProgress or 0)
			state.Model:SetAttribute("LandingArmed", state.LandingArmed)
			state.Model:SetAttribute("LandingPhase", state.LandingPhase)
			state.Model:SetAttribute("TouchdownLoad", state.TouchdownLoad or 0)
			state.Model:SetAttribute("Brake", state.Brake)
			state.Model:SetAttribute("Pushback", state.Pushback)
			state.Model:SetAttribute("PushbackCoasting", state.PushbackCoasting)
			state.Model:SetAttribute("OnGround", state.OnGround)
			state.Model:SetAttribute("Status", state.Status)
			state.Model:SetAttribute("NearestAirport", nearest.Code)
		end
	end
	if attributeTimer >= 0.08 then attributeTimer = 0 end
end)

local aiTraffic = {
	{ Spec = AircraftCatalog.ByCode.E290, Radius = 3200, Altitude = 520, Speed = 0.055, Offset = 0 },
	{ Spec = AircraftCatalog.ByCode.B38M, Radius = 6100, Altitude = 780, Speed = -0.032, Offset = 2.1 },
	{ Spec = AircraftCatalog.ByCode.A339, Radius = 9400, Altitude = 1080, Speed = 0.021, Offset = 4.3 },
}

for _, traffic in ipairs(aiTraffic) do
	local model = createAirliner(traffic.Spec, CFrame.new(0, traffic.Altitude, 0), 0, true)
	traffic.Model = model
end

RunService.Heartbeat:Connect(function()
	local now = workspace.DistributedGameTime
	for _, traffic in ipairs(aiTraffic) do
		local angle = now * traffic.Speed + traffic.Offset
		local position = Vector3.new(math.cos(angle) * traffic.Radius, traffic.Altitude, math.sin(angle) * traffic.Radius)
		traffic.Model:PivotTo(CFrame.new(position) * CFrame.Angles(0, -angle - math.pi / 2, math.sin(angle * 2) * 0.11))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	destroyPlayerPlane(player)
	lastSpawn[player] = nil
end)

Players.PlayerAdded:Connect(configurePlayer)
for _, player in ipairs(Players:GetPlayers()) do configurePlayer(player) end

print("[Around the World] V31 server ready: animated gear deployment and varied terminal forms enabled.")
