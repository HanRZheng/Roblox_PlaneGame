--!nocheck

-- V30 shared runway, taxiway, and apron generator. Both the live server and
-- Studio edit-mode builder call this module so airport geometry cannot drift.

local Layout = require(script.Parent:WaitForChild("AirportLayout"))

local AirportSurfaces = {}

local RUNWAY = Color3.fromRGB(48, 53, 56)
local STOPWAY = Color3.fromRGB(57, 61, 63)
local TAXIWAY = Color3.fromRGB(73, 77, 78)
local APRON = Color3.fromRGB(108, 114, 115)
local WHITE = Color3.fromRGB(244, 244, 231)
local YELLOW = Color3.fromRGB(244, 190, 48)
local BLACK = Color3.fromRGB(25, 28, 29)
local BLUE = Color3.fromRGB(75, 154, 255)
local AMBER = Color3.fromRGB(255, 174, 40)

local function localPoint(x, y, z)
	return Vector3.new(x, y, z)
end

local function makeSegment(parent, makePart, airportCF, name, a, b, width, height, y, color, material, transparency, canCollide)
	local flatA = localPoint(a.X, y, a.Z)
	local flatB = localPoint(b.X, y, b.Z)
	local distance = (flatB - flatA).Magnitude
	if distance < 0.05 then return nil end
	local center = (flatA + flatB) / 2
	return makePart(
		parent,
		name,
		Vector3.new(width, height, distance + 1.8),
		airportCF * CFrame.lookAt(center, flatB),
		color,
		material,
		transparency or 0,
		canCollide
	)
end

local function quadraticPoint(a, control, b, t)
	local u = 1 - t
	return a * (u * u) + control * (2 * u * t) + b * (t * t)
end

local function makeQuadraticRibbon(parent, makePart, airportCF, name, a, control, b, width, height, y, color, material, segments, transparency, canCollide)
	local previous = a
	for index = 1, segments do
		local point = quadraticPoint(a, control, b, index / segments)
		makeSegment(parent, makePart, airportCF, name .. index, previous, point, width, height, y, color, material, transparency, canCollide)
		previous = point
	end
end

local function addTopText(part, text, rotation, color)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "PaintedSurfaceText"
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(300, 420)
	gui.LightInfluence = 0.15
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Rotation = rotation or 0
	label.Parent = gui
end

local function addTwoSidedSign(part, text, background, foreground)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "TaxiwaySignDisplay"
		gui.Face = face
		gui.CanvasSize = Vector2.new(500, 170)
		gui.LightInfluence = 0
		gui.Parent = part

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = background
		label.BorderColor3 = foreground
		label.BorderSizePixel = 8
		label.Font = Enum.Font.GothamBlack
		label.Text = text
		label.TextColor3 = foreground
		label.TextScaled = true
		label.Parent = gui
	end
end

local function runwayNumber(heading)
	local number = math.floor(((heading % 360) + 5) / 10) % 36
	if number == 0 then number = 36 end
	return string.format("%02d", number)
end

local function makeStopway(parent, makePart, airportCF, airport, endSign)
	local runwayHalf = airport.RunwayLength / 2
	local stopwayCenterZ = endSign * (runwayHalf + Layout.StopwayLength / 2)
	makePart(parent, "Stopway" .. endSign, Vector3.new(Layout.RunwayWidth, 1.6, Layout.StopwayLength), airportCF * CFrame.new(0, 0.20, stopwayCenterZ), STOPWAY, Enum.Material.Asphalt)

	-- Yellow chevrons identify pavement that is not part of the landing surface.
	for chevron = 1, 3 do
		local inward = 30 + (chevron - 1) * ((Layout.StopwayLength - 50) / 3)
		local z = endSign * (runwayHalf + inward)
		for side = -1, 1, 2 do
			local x = side * Layout.RunwayWidth * 0.20
			makePart(parent, "StopwayChevron" .. endSign .. "_" .. chevron .. "_" .. side, Vector3.new(4.2, 0.16, Layout.RunwayWidth * 0.42), airportCF * CFrame.new(x, 1.08, z) * CFrame.Angles(0, side * endSign * math.rad(43), 0), YELLOW, Enum.Material.SmoothPlastic, 0, false)
		end
	end
end

local function makeRunwayMarkings(parent, makePart, airportCF, airport, headingOverride)
	local runwayHalf = airport.RunwayLength / 2
	local thresholdInset = Layout.RunwayThresholdInset
	local thresholdZ = runwayHalf - thresholdInset

	-- Continuous edge lines and dashed centerline remain inside both thresholds.
	for side = -1, 1, 2 do
		makePart(parent, "RunwayEdgeLine" .. side, Vector3.new(3.0, 0.16, airport.RunwayLength - thresholdInset * 1.25), airportCF * CFrame.new(side * (Layout.RunwayWidth / 2 - 4), 1.09, 0), WHITE, Enum.Material.SmoothPlastic, 0, false)
	end
	for z = -thresholdZ + 125, thresholdZ - 90, 88 do
		makePart(parent, "RunwayCenterline", Vector3.new(4, 0.18, 38), airportCF * CFrame.new(0, 1.10, z), WHITE, Enum.Material.SmoothPlastic, 0, false)
	end

	for _, endSign in ipairs({ -1, 1 }) do
		local runwayHeading = headingOverride or airport.Heading
		local endHeading = endSign < 0 and runwayHeading or (runwayHeading + 180) % 360
		local designation = runwayNumber(endHeading)

		-- Eight paired longitudinal threshold stripes, inset from the pavement edge.
		for stripe = 1, 8 do
			local x = 9 + (stripe - 1) * 9.0
			for side = -1, 1, 2 do
				makePart(parent, "RunwayThresholdStripe" .. endSign .. "_" .. stripe .. "_" .. side, Vector3.new(5.2, 0.19, 66), airportCF * CFrame.new(side * x, 1.105, endSign * thresholdZ), WHITE, Enum.Material.SmoothPlastic, 0, false)
			end
		end

		local numberPart = makePart(parent, "RunwayDesignation" .. endSign, Vector3.new(58, 0.10, 72), airportCF * CFrame.new(0, 1.115, endSign * (runwayHalf - 155)), WHITE, Enum.Material.SmoothPlastic, 1, false)
		addTopText(numberPart, designation, endSign > 0 and 180 or 0, WHITE)

		-- Aiming-point blocks and coded touchdown-zone groups give distance cues.
		local aimingZ = endSign * (runwayHalf - airport.RunwayLength * 0.215)
		for side = -1, 1, 2 do
			makePart(parent, "RunwayAimingPoint" .. endSign .. "_" .. side, Vector3.new(12, 0.19, 76), airportCF * CFrame.new(side * 34, 1.11, aimingZ), WHITE, Enum.Material.SmoothPlastic, 0, false)
		end
		for group = 1, 3 do
			local bars = 4 - group
			local distance = airport.RunwayLength * (0.115 + group * 0.072)
			local z = endSign * (runwayHalf - distance)
			for bar = 1, bars do
				local x = 22 + (bar - 1) * 13
				for side = -1, 1, 2 do
					makePart(parent, "TouchdownZoneMarking" .. endSign .. "_" .. group .. "_" .. bar .. "_" .. side, Vector3.new(6.5, 0.18, 42), airportCF * CFrame.new(side * x, 1.105, z), WHITE, Enum.Material.SmoothPlastic, 0, false)
				end
			end
		end
	end
end

local function makeRunwaySafetyLighting(parent, makePart, airportCF, airport)
	local runwayHalf = airport.RunwayLength / 2
	for _, endSign in ipairs({ -1, 1 }) do
		-- Centerline approach lights extend beyond each stopway, with two wider
		-- crossbars that make runway alignment easier from the new world map.
		for lightIndex = 1, 9 do
			local z = endSign * (runwayHalf + Layout.StopwayLength + 30 + lightIndex * 34)
			local center = makePart(parent, "ApproachCenterLight" .. endSign .. "_" .. lightIndex, Vector3.new(1.4, 1.4, 1.4), airportCF * CFrame.new(0, 1.3, z), WHITE, Enum.Material.Neon, 0, false)
			center.Shape = Enum.PartType.Ball
			if lightIndex == 4 or lightIndex == 8 then
				for side = -3, 3 do
					if side ~= 0 then
						local bar = makePart(parent, "ApproachCrossbarLight" .. endSign .. "_" .. lightIndex .. "_" .. side, Vector3.new(1.3, 1.3, 1.3), airportCF * CFrame.new(side * 18, 1.3, z), WHITE, Enum.Material.Neon, 0, false)
						bar.Shape = Enum.PartType.Ball
					end
				end
			end
		end

		local papiX = -endSign * (Layout.RunwayWidth / 2 + 24)
		local papiZ = endSign * (runwayHalf - 330)
		for lamp = 1, 4 do
			local color = lamp <= 2 and Color3.fromRGB(255, 245, 218) or Color3.fromRGB(255, 67, 67)
			local light = makePart(parent, "PAPI" .. endSign .. "_" .. lamp, Vector3.new(3.0, 1.5, 3.0), airportCF * CFrame.new(papiX + (lamp - 2.5) * 8, 1.55, papiZ), color, Enum.Material.Neon, 0, false)
			light.Shape = Enum.PartType.Ball
		end
	end
end

local function makeHoldingPosition(parent, makePart, airportCF, connectorIndex, holdX, connectorZ, connectorWidth)
	-- Pattern A: two solid bars on the holding side and two dashed bars toward
	-- the runway. Black underlays improve contrast on the light taxi pavement.
	makePart(parent, "HoldingPositionBackdrop" .. connectorIndex, Vector3.new(18, 0.12, connectorWidth * 0.88), airportCF * CFrame.new(holdX, 1.075, connectorZ), BLACK, Enum.Material.SmoothPlastic, 0, false)
	for bar = 1, 2 do
		makePart(parent, "HoldingPositionSolid" .. connectorIndex .. "_" .. bar, Vector3.new(2.3, 0.18, connectorWidth * 0.82), airportCF * CFrame.new(holdX + 3 + (bar - 1) * 4.2, 1.105, connectorZ), YELLOW, Enum.Material.SmoothPlastic, 0, false)
	end
	for bar = 1, 2 do
		local x = holdX - 3 - (bar - 1) * 4.2
		for dash = -4, 4 do
			makePart(parent, "HoldingPositionDash" .. connectorIndex .. "_" .. bar .. "_" .. dash, Vector3.new(2.3, 0.18, 7.2), airportCF * CFrame.new(x, 1.105, connectorZ + dash * 12), YELLOW, Enum.Material.SmoothPlastic, 0, false)
		end
	end
	for side = -1, 1, 2 do
		local guard = makePart(parent, "RunwayGuardLight" .. connectorIndex .. "_" .. side, Vector3.new(1.8, 1.8, 1.8), airportCF * CFrame.new(holdX + 1, 2.15, connectorZ + side * connectorWidth * 0.47), AMBER, Enum.Material.Neon, 0, false)
		guard.Shape = Enum.PartType.Ball
	end
end

local function makeEnhancedCenterline(parent, makePart, airportCF, connectorIndex, fromX, toX, z)
	local length = math.max(10, toX - fromX)
	local count = math.max(3, math.floor(length / 24))
	for index = 1, count do
		local x = fromX + (index - 0.5) * length / count
		for side = -1, 1, 2 do
			makePart(parent, "EnhancedTaxiCenterline" .. connectorIndex .. "_" .. index .. "_" .. side, Vector3.new(math.max(7, length / count * 0.62), 0.16, 1.1), airportCF * CFrame.new(x, 1.105, z + side * 4.0), YELLOW, Enum.Material.SmoothPlastic, 0, false)
		end
	end
end

local function makeTaxiwaySign(parent, makePart, airportCF, name, text, x, z, mandatory)
	local sign = makePart(parent, name, Vector3.new(1.0, 5.5, 16), airportCF * CFrame.new(x, 3.2, z), mandatory and Color3.fromRGB(146, 31, 31) or BLACK, Enum.Material.Metal, 0, false)
	addTwoSidedSign(sign, text, mandatory and Color3.fromRGB(157, 34, 34) or BLACK, mandatory and WHITE or YELLOW)
	makePart(parent, name .. "Post", Vector3.new(0.8, 3, 0.8), airportCF * CFrame.new(x, 1.5, z), Color3.fromRGB(100, 104, 104), Enum.Material.Metal, 0, false)
end

local function makeTaxiways(parent, makePart, airportCF, airport, apronStartX, apronEndX)
	local taxiHalf = Layout.TaxiwayWidth / 2
	local taxiLength = airport.RunwayLength + Layout.StopwayLength * 0.45
	local taxiY = 0.375
	makePart(parent, "ParallelTaxiway", Vector3.new(Layout.TaxiwayWidth, 1.25, taxiLength), airportCF * CFrame.new(Layout.TaxiwayX, taxiY, 0), TAXIWAY, Enum.Material.Concrete)
	makePart(parent, "TaxiwayCenterline", Vector3.new(1.7, 0.18, taxiLength - 12), airportCF * CFrame.new(Layout.TaxiwayX, 1.105, 0), YELLOW, Enum.Material.SmoothPlastic, 0, false)
	for side = -1, 1, 2 do
		makePart(parent, "TaxiwayEdgeLine" .. side, Vector3.new(1.25, 0.16, taxiLength - 8), airportCF * CFrame.new(Layout.TaxiwayX + side * (taxiHalf - 4), 1.095, 0), YELLOW, Enum.Material.SmoothPlastic, 0, false)
		for z = -taxiLength / 2 + 25, taxiLength / 2 - 25, 82 do
			local light = makePart(parent, "TaxiwayEdgeLight" .. side, Vector3.new(1.25, 1.25, 1.25), airportCF * CFrame.new(Layout.TaxiwayX + side * (taxiHalf + 3), 1.75, z), BLUE, Enum.Material.Neon, 0, false)
			light.Shape = Enum.PartType.Ball
		end
	end

	local runwayRightEdge = Layout.RunwayWidth / 2
	local turnRadius = Layout.TaxiwayFilletRadius
	local connectorEndX = Layout.TaxiwayX - turnRadius + 8
	local connectorStartX = runwayRightEdge - 10
	local connectorLength = connectorEndX - connectorStartX
	local connectorCenterX = (connectorStartX + connectorEndX) / 2
	local runwayLabels = runwayNumber(airport.Heading) .. "-" .. runwayNumber((airport.Heading + 180) % 360)
	local connectorFractions = { -0.38, -0.19, 0, 0.19, 0.38 }

	for connectorIndex, fraction in ipairs(connectorFractions) do
		local connectorZ = airport.RunwayLength * fraction
		makePart(parent, "TaxiwayConnector" .. connectorIndex, Vector3.new(connectorLength + 2, 1.25, Layout.ConnectorWidth), airportCF * CFrame.new(connectorCenterX, taxiY, connectorZ), TAXIWAY, Enum.Material.Concrete)

		-- Two compact fillets replace the V15 circular pads. Their centerlines merge
		-- tangentially into the parallel taxiway, matching the supplied reference.
		for direction = -1, 1, 2 do
			local a = localPoint(Layout.TaxiwayX, taxiY, connectorZ + direction * turnRadius)
			local control = localPoint(Layout.TaxiwayX, taxiY, connectorZ)
			local b = localPoint(connectorEndX - 2, taxiY, connectorZ)
			makeQuadraticRibbon(parent, makePart, airportCF, "TaxiwayFilletSurface" .. connectorIndex .. "_" .. direction .. "_", a, control, b, Layout.ConnectorWidth, 1.25, taxiY, TAXIWAY, Enum.Material.Concrete, Layout.TaxiwayCurveSegments, 0, true)
			makeQuadraticRibbon(parent, makePart, airportCF, "TaxiwayFilletCenterline" .. connectorIndex .. "_" .. direction .. "_", a, control, b, 1.7, 0.18, 1.105, YELLOW, Enum.Material.SmoothPlastic, Layout.TaxiwayCurveSegments, 0, false)
		end

		local holdX = runwayRightEdge + Layout.HoldShortOffset
		makeSegment(parent, makePart, airportCF, "ConnectorCenterline" .. connectorIndex, localPoint(holdX + 12, 0, connectorZ), localPoint(connectorEndX, 0, connectorZ), 1.7, 0.18, 1.105, YELLOW, Enum.Material.SmoothPlastic, 0, false)
		makeSegment(parent, makePart, airportCF, "ConnectorRunwaySideCenterline" .. connectorIndex, localPoint(runwayRightEdge - 4, 0, connectorZ), localPoint(holdX - 12, 0, connectorZ), 1.7, 0.18, 1.105, YELLOW, Enum.Material.SmoothPlastic, 0, false)
		makeHoldingPosition(parent, makePart, airportCF, connectorIndex, holdX, connectorZ, Layout.ConnectorWidth)
		makeEnhancedCenterline(parent, makePart, airportCF, connectorIndex, holdX + 14, math.min(connectorEndX - 8, holdX + 105), connectorZ)

		makeTaxiwaySign(parent, makePart, airportCF, "RunwayHoldingSign" .. connectorIndex, runwayLabels, holdX + 8, connectorZ + Layout.ConnectorWidth * 0.60, true)
		makeTaxiwaySign(parent, makePart, airportCF, "TaxiwayLocationSign" .. connectorIndex, "A  •  A" .. connectorIndex, connectorEndX + 8, connectorZ - Layout.ConnectorWidth * 0.60, false)
	end

	-- A slightly recessed oversized underlay guarantees that no grass can show
	-- through along apron edges or between overlapping pavement pieces.
	local apronWidth = apronEndX - apronStartX
	local apronCenterX = (apronStartX + apronEndX) / 2
	local apronUnderlayOverlap = Layout.ApronUnderlayOverlap
	makePart(
		parent,
		"ApronContinuityUnderlay",
		Vector3.new(apronWidth + apronUnderlayOverlap * 2, 1.22, Layout.ApronLength + apronUnderlayOverlap * 2),
		airportCF * CFrame.new(apronCenterX, 0.34, Layout.ApronCenterZ),
		APRON,
		Enum.Material.Concrete
	)
	local apron = makePart(parent, "Apron", Vector3.new(apronWidth, 1.30, Layout.ApronLength), airportCF * CFrame.new(apronCenterX, 0.35, Layout.ApronCenterZ), APRON, Enum.Material.Concrete)
	apron:SetAttribute("AirportCode", airport.Code)

	local apronAccessZ = -math.min(560, airport.RunwayLength * 0.22)
	local apronTurnRadius = Layout.ApronFilletRadius
	local apronLaneStartX = apronStartX + apronTurnRadius
	local bridgeStartX = Layout.TaxiwayX - taxiHalf - 18
	local bridgeEndX = apronLaneStartX + 30
	makePart(
		parent,
		"ApronTaxiwayBridge",
		Vector3.new(bridgeEndX - bridgeStartX, 1.30, Layout.ApronTaxiLaneWidth),
		airportCF * CFrame.new((bridgeStartX + bridgeEndX) / 2, 0.35, apronAccessZ),
		TAXIWAY,
		Enum.Material.Concrete
	)
	for direction = -1, 1, 2 do
		local a = localPoint(Layout.TaxiwayX, taxiY, apronAccessZ + direction * apronTurnRadius)
		local control = localPoint(Layout.TaxiwayX, taxiY, apronAccessZ)
		local b = localPoint(apronLaneStartX, taxiY, apronAccessZ)
		makeQuadraticRibbon(parent, makePart, airportCF, "ApronEntryFilletSurface" .. direction .. "_", a, control, b, Layout.ApronTaxiLaneWidth, 1.25, taxiY, TAXIWAY, Enum.Material.Concrete, Layout.TaxiwayCurveSegments, 0, true)
		makeQuadraticRibbon(parent, makePart, airportCF, "ApronEntryCenterline" .. direction .. "_", a, control, b, 1.7, 0.18, 1.105, YELLOW, Enum.Material.SmoothPlastic, Layout.TaxiwayCurveSegments, 0, false)
	end
	makeSegment(parent, makePart, airportCF, "ApronTaxiLaneCenterline", localPoint(apronLaneStartX - 2, 0, apronAccessZ), localPoint(apronEndX - 28, 0, apronAccessZ), 1.7, 0.18, 1.105, YELLOW, Enum.Material.SmoothPlastic, 0, false)
	makeTaxiwaySign(parent, makePart, airportCF, "ApronDirectionSign", "A  •  GATES", Layout.TaxiwayX + taxiHalf + 12, apronAccessZ + apronTurnRadius * 0.72, false)

	return apron
end

local function makeAdditionalRunway(parent, makePart, airportCF, airport, runwayIndex, placement, previousPlacement)
	local offsetX = placement.X
	local offsetZ = placement.Z
	local group = Instance.new("Model")
	group.Name = "AdditionalRunway" .. runwayIndex
	group:SetAttribute("AirportCode", airport.Code)
	group:SetAttribute("RunwayIndex", runwayIndex)
	group:SetAttribute("LateralOffset", offsetX)
	group:SetAttribute("LongitudinalOffset", offsetZ)
	group:SetAttribute("HeadingDelta", placement.HeadingDelta or 0)
	group:SetAttribute("RunwayHeading", Layout.RunwayHeading(airport, placement))
	group.Parent = parent
	local placementCF = Layout.RunwayLocalCFrame(placement)
	local previousCF = Layout.RunwayLocalCFrame(previousPlacement)
	-- A hairline vertical separation prevents coplanar z-fighting where an
	-- angled runway crosses another runway; 0.025 studs is not a physical step.
	local runwayCF = airportCF * placementCF * CFrame.new(0, 0.025, 0)
	group:SetAttribute("IntersectionSurfaceLift", 0.025)
	local runway = makePart(group, "Runway" .. runwayIndex, Vector3.new(Layout.RunwayWidth, 2, airport.RunwayLength), runwayCF, RUNWAY, Enum.Material.Asphalt)
	runway:SetAttribute("AirportCode", airport.Code)
	runway:SetAttribute("RunwayIndex", runwayIndex)
	runway:SetAttribute("RunwayHeading", Layout.RunwayHeading(airport, placement))
	for side = -1, 1, 2 do
		makePart(group, "RunwayShoulder" .. side, Vector3.new(22, 1.35, airport.RunwayLength), runwayCF * CFrame.new(side * (Layout.RunwayWidth / 2 + 11), -0.25, 0), STOPWAY, Enum.Material.Asphalt)
	end
	makeStopway(group, makePart, runwayCF, airport, -1)
	makeStopway(group, makePart, runwayCF, airport, 1)
	makeRunwayMarkings(group, makePart, runwayCF, airport, Layout.RunwayHeading(airport, placement))
	makeRunwaySafetyLighting(group, makePart, runwayCF, airport)
	for z = -airport.RunwayLength / 2, airport.RunwayLength / 2, 72 do
		for _, x in ipairs({ -(Layout.RunwayWidth / 2 + 8), Layout.RunwayWidth / 2 + 8 }) do
			local light = makePart(group, "RunwayEdgeLight", Vector3.new(1.5, 1.5, 1.5), runwayCF * CFrame.new(x, 2, z), WHITE, Enum.Material.Neon, 0, false)
			light.Shape = Enum.PartType.Ball
		end
	end

	-- Every new runway gets its own full-length parallel taxiway, plus three
	-- cross-taxiways that connect it to the rest of the movement area.
	local taxiwayX = Layout.AdditionalRunwaySpacing * 0.46
	local taxiLength = airport.RunwayLength + Layout.StopwayLength * 0.45
	makePart(group, "ParallelTaxiway" .. runwayIndex, Vector3.new(Layout.TaxiwayWidth, 1.25, taxiLength), runwayCF * CFrame.new(taxiwayX, 0.375, 0), TAXIWAY, Enum.Material.Concrete)
	makePart(group, "TaxiwayCenterline" .. runwayIndex, Vector3.new(1.7, 0.18, taxiLength - 12), runwayCF * CFrame.new(taxiwayX, 1.105, 0), YELLOW, Enum.Material.SmoothPlastic, 0, false)
	for connectorIndex, fraction in ipairs({ -0.38, 0, 0.38 }) do
		local runwayZ = airport.RunwayLength * fraction
		local startPoint = placementCF:PointToWorldSpace(localPoint(Layout.RunwayWidth / 2 - 8, 0, runwayZ))
		local endPoint = previousCF:PointToWorldSpace(localPoint(-Layout.RunwayWidth / 2 + 8, 0, runwayZ))
		makeSegment(group, makePart, airportCF, "InterRunwayTaxiway" .. connectorIndex, startPoint, endPoint, Layout.ConnectorWidth, 1.25, 0.375, TAXIWAY, Enum.Material.Concrete, 0, true)
		makeSegment(group, makePart, airportCF, "InterRunwayCenterline" .. connectorIndex, startPoint, endPoint, 1.7, 0.18, 1.105, YELLOW, Enum.Material.SmoothPlastic, 0, false)
	end
	return runway
end

function AirportSurfaces.Build(parent, airportCF, airport, makePart)
	local placements = Layout.RunwayPlacements(airport)
	local primaryPlacement = placements[1]
	local primaryRunwayCF = airportCF * Layout.RunwayLocalCFrame(primaryPlacement)
	local runway = makePart(parent, "Runway", Vector3.new(Layout.RunwayWidth, 2, airport.RunwayLength), primaryRunwayCF, RUNWAY, Enum.Material.Asphalt)
	runway:SetAttribute("AirportCode", airport.Code)
	runway:SetAttribute("RunwayIndex", 1)
	runway:SetAttribute("RunwayHeading", Layout.RunwayHeading(airport, primaryPlacement))
	for side = -1, 1, 2 do
		makePart(parent, "RunwayShoulder" .. side, Vector3.new(22, 1.35, airport.RunwayLength), primaryRunwayCF * CFrame.new(side * (Layout.RunwayWidth / 2 + 11), -0.25, 0), STOPWAY, Enum.Material.Asphalt)
	end

	makeStopway(parent, makePart, primaryRunwayCF, airport, -1)
	makeStopway(parent, makePart, primaryRunwayCF, airport, 1)
	makeRunwayMarkings(parent, makePart, primaryRunwayCF, airport, Layout.RunwayHeading(airport, primaryPlacement))
	makeRunwaySafetyLighting(parent, makePart, primaryRunwayCF, airport)

	for z = -airport.RunwayLength / 2, airport.RunwayLength / 2, 55 do
		for _, x in ipairs({ -(Layout.RunwayWidth / 2 + 8), Layout.RunwayWidth / 2 + 8 }) do
			local light = makePart(parent, "RunwayEdgeLight", Vector3.new(1.5, 1.5, 1.5), primaryRunwayCF * CFrame.new(x, 2, z), WHITE, Enum.Material.Neon, 0, false)
			light.Shape = Enum.PartType.Ball
		end
	end

	local apronStartX, apronEndX = Layout.ApronBounds(airport)
	makeTaxiways(parent, makePart, primaryRunwayCF, airport, apronStartX, apronEndX)
	for runwayIndex = 2, #placements do
		makeAdditionalRunway(parent, makePart, airportCF, airport, runwayIndex, placements[runwayIndex], placements[runwayIndex - 1])
	end
	return runway
end

return AirportSurfaces
