--!strict

-- Low-profile island terrain shared by the live server and Studio builder.
-- Every complete hill footprint must remain outside the protected runway path,
-- airport facilities, and shoreline margin before it can be created.

local Layout = require(script.Parent:WaitForChild("AirportLayout"))

local AirportTerrain = {}

local terrainStyles = {
	Green = { MinHeight = 14, MaxHeight = 30, Color = Color3.fromRGB(67, 132, 82), Material = Enum.Material.Grass },
	Tropical = { MinHeight = 16, MaxHeight = 32, Color = Color3.fromRGB(67, 151, 90), Material = Enum.Material.Grass },
	Alpine = { MinHeight = 22, MaxHeight = 46, Color = Color3.fromRGB(96, 126, 108), Material = Enum.Material.Slate },
	Desert = { MinHeight = 18, MaxHeight = 34, Color = Color3.fromRGB(170, 112, 66), Material = Enum.Material.Sandstone },
	Urban = { MinHeight = 14, MaxHeight = 26, Color = Color3.fromRGB(76, 125, 85), Material = Enum.Material.Grass },
}

local function overlapsFacility(airport, localX, localZ, halfX, halfZ)
	local facilityStart = Layout.SceneryNegativeClearX - Layout.TerrainFacilityMargin
	local facilityEnd = Layout.FacilityEndX(airport) + Layout.TerrainFacilityMargin
	local facilityHalfZ = math.max(math.abs(Layout.FacilityZMin), math.abs(Layout.FacilityZMax)) + Layout.TerrainFacilityMargin
	return localX + halfX > facilityStart
		and localX - halfX < facilityEnd
		and math.abs(localZ) - halfZ < facilityHalfZ
end

local function clearsRunwayPath(airport, localX, localZ, halfX, halfZ)
	-- Protect every parallel or crossing runway and its extended approach path.
	-- A radial footprint bound is intentionally conservative for rotated hills.
	local footprintRadius = math.sqrt(halfX * halfX + halfZ * halfZ)
	local center = Vector3.new(localX, 0, localZ)
	for _, placement in ipairs(Layout.RunwayPlacements(airport)) do
		local runwayPosition = Layout.RunwayLocalCFrame(placement):PointToObjectSpace(center)
		if math.abs(runwayPosition.X) - footprintRadius < Layout.TerrainRunwayCorridorHalfWidth then
			return false
		end
	end
	return true
end

function AirportTerrain.Build(parent, airportCF, airport, makePart)
	if airport.SkipTerrain then
		return nil
	end

	local existing = parent:FindFirstChild("V31 Low Terrain")
	if existing then return existing end

	local folder = Instance.new("Folder")
	folder.Name = "V31 Low Terrain"
	folder:SetAttribute("MaximumHeight", Layout.TerrainMaximumHeight)
	folder:SetAttribute("RunwayCorridorHalfWidth", Layout.TerrainRunwayCorridorHalfWidth)
	folder:SetAttribute("ApproachPathProtected", true)
	folder.Parent = parent

	local style = terrainStyles[airport.Terrain] or terrainStyles.Green
	local seed = string.byte(airport.Code, 1) * 10000
		+ string.byte(airport.Code, 2) * 100
		+ string.byte(airport.Code, 3)
	local random = Random.new(seed + 2200)
	local desiredCount = airport.Terrain == "Urban" and 9 or 12
	local created = 0
	local attempts = 0

	while created < desiredCount and attempts < desiredCount * 60 do
		attempts += 1
		local width = random:NextNumber(620, 1280)
		local depth = random:NextNumber(540, 1120)
		local height = math.min(Layout.TerrainMaximumHeight, random:NextNumber(style.MinHeight, style.MaxHeight))
		local halfX = width * 0.5
		local halfZ = depth * 0.5
		local localX = random:NextNumber(-airport.IslandRadius * 0.60, airport.IslandRadius * 0.60)
		local localZ = random:NextNumber(-airport.IslandRadius * 0.60, airport.IslandRadius * 0.60)
		local footprintPadding = math.sqrt(halfX * halfX + halfZ * halfZ) + Layout.SceneryShoreMargin
		local safelyInland = Layout.IsInsideIsland(airport, localX, localZ, footprintPadding)
		if safelyInland
			and clearsRunwayPath(airport, localX, localZ, halfX, halfZ)
			and not overlapsFacility(airport, localX, localZ, halfX, halfZ) then
			created += 1
			local yaw = math.rad(random:NextNumber(-28, 28))
			local colorVariation = random:NextNumber(-0.06, 0.06)
			local colorTarget = colorVariation >= 0 and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
			local color = style.Color:Lerp(colorTarget, math.abs(colorVariation))
			local hill = makePart(
				folder,
				"RollingHill" .. created,
				Vector3.new(width, height, depth),
				airportCF * CFrame.new(localX, height * 0.32 - 2, localZ) * CFrame.Angles(0, yaw, 0),
				color,
				style.Material,
				0,
				true
			)
			hill.Shape = Enum.PartType.Ball
			hill.CanTouch = false
			hill.CanQuery = true
			hill:SetAttribute("TerrainHeight", height)
			hill:SetAttribute("RunwayLateralClearance", math.abs(localX) - halfX)
		end
	end

	folder:SetAttribute("GeneratedHillCount", created)
	return folder
end

return AirportTerrain
