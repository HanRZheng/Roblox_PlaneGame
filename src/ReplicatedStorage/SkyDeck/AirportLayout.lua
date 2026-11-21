--!strict

-- V31 airport geometry shared by the live server, edit-mode builder, terminal
-- generator, and aircraft spawner. Keeping these values in one module prevents
-- the taxiway, terminal, apron, and gate positions from drifting apart.

local Layout = {
	WorldVersion = 31,
	GeometryRevision = 12,
	RunwayLayoutRevision = 30,
	TerminalShapeRevision = 31,
	WorldRadius = 50000,
	OceanExtent = 52000,
	CloudExtent = 46000,

	-- The A380 is the widest selectable aircraft at roughly 285 studs.
	MaxAircraftSpan = 79.75 / 0.28,
	MaxAircraftHalfSpan = (79.75 / 0.28) / 2,
	AircraftClearance = 60,

	RunwayWidth = 220,
	AdditionalRunwaySpacing = 760,
	AdditionalRunwayStagger = 260,
	StopwayLength = 240,
	RunwayThresholdInset = 92,
	TaxiwayX = 360,
	TaxiwayWidth = 190,
	ConnectorWidth = 140,
	TaxiwayFilletRadius = 135,
	ApronFilletRadius = 150,
	TaxiwayCurveSegments = 16,
	HoldShortOffset = 55,
	TaxiwayObstacleClearance = (79.75 / 0.28) / 2 + 70,

	FirstGateX = 760,
	GateSpacing = 380,
	GateStandWidth = 350,
	GateStandLength = 520,
	GateStandCenterZ = -90,

	-- Sixty studs of taxiway overlap plus a recessed continuity underlay makes
	-- the apron a single sealed pavement surface, even at curved entry fillets.
	ApronStartX = 395,
	ApronEndPadding = 280,
	ApronLength = 1040,
	ApronCenterZ = -220,
	ApronTaxiLaneWidth = 230,
	ApronTileSize = 115,
	ApronUnderlayOverlap = 72,

	TerminalStartX = 560,
	TerminalEndPadding = 120,
	SceneryShoreMargin = 1750,
	SceneryNegativeClearX = -250,
	SceneryPositiveClearX = 700,
	FacilityZMin = -1400,
	FacilityZMax = 1400,
	RoadRadiusScale = 0.32,
	GroundReserveSideBuffer = 900,
	GroundReserveEndBuffer = 900,
	TerrainMaximumHeight = 46,
	TerrainRunwayCorridorHalfWidth = 900,
	TerrainFacilityMargin = 520,
	-- Island floor uses 1,200-stud tiles; this allowance keeps a plane on the
	-- visible outer half-tile from being treated as if it had already hit water.
	IslandSurfaceAllowance = 900,
}

function Layout.GateX(gateNumber: number): number
	return Layout.FirstGateX + (gateNumber - 1) * Layout.GateSpacing
end

function Layout.LastGateX(airport): number
	return Layout.GateX(airport.Gates or 3)
end

function Layout.TerminalBounds(airport): (number, number)
	return Layout.TerminalStartX, Layout.LastGateX(airport) + Layout.TerminalEndPadding
end

function Layout.ApronBounds(airport): (number, number)
	return Layout.ApronStartX, Layout.LastGateX(airport) + Layout.ApronEndPadding
end

function Layout.FacilityEndX(airport): number
	local _, apronEnd = Layout.ApronBounds(airport)
	return apronEnd + Layout.AircraftClearance
end

function Layout.GateClearance(): number
	return Layout.GateSpacing - Layout.MaxAircraftSpan
end

function Layout.IslandBoundaryScale(airport, angle: number): number
	local lobeA = airport.IslandLobeA or 0
	local lobeB = airport.IslandLobeB or 0
	local phase = airport.IslandPhase or 0
	local lobeCount = airport.IslandShape == "MultiLobed" and 5 or (airport.IslandShape == "BayLobed" and 4 or 3)
	local boundary = 1
		+ lobeA * math.sin(lobeCount * angle + phase)
		+ lobeB * math.sin((lobeCount + 2) * angle - phase * 0.7)

	if airport.IslandShape == "Teardrop" then
		boundary += 0.13 * math.cos(angle) - 0.055 * math.cos(2 * angle)
	elseif airport.IslandShape == "Ridge" then
		boundary += 0.045 * math.sin(2 * angle + phase)
	elseif airport.IslandShape == "BayLobed" then
		boundary -= 0.055 * math.max(0, math.cos(angle - 0.55)) ^ 2
	end

	-- Radial waves add area, so normalize their average squared radius. Together
	-- with the near-reciprocal aspects this keeps the V31 land area near V27.
	local areaNormalization = 1 / math.sqrt(1 + (lobeA * lobeA + lobeB * lobeB) * 0.5 + 0.004)
	return boundary * areaNormalization
end

function Layout.IslandBoundaryLocalPoint(airport, angle: number, radiusScale: number?): Vector2
	local radius = airport.IslandRadius * Layout.IslandBoundaryScale(airport, angle) * (radiusScale or 1)
	local rotatedX = math.cos(angle) * radius * (airport.IslandAspectX or 1)
	local rotatedZ = math.sin(angle) * radius * (airport.IslandAspectZ or 1)
	local rotation = math.rad(airport.IslandRotation or 0)
	local cosine = math.cos(rotation)
	local sine = math.sin(rotation)
	return Vector2.new(rotatedX * cosine + rotatedZ * sine, -rotatedX * sine + rotatedZ * cosine)
end

function Layout.IsInsideIsland(airport, localX: number, localZ: number, padding: number?): boolean
	local safeRadius = airport.IslandRadius - (padding or 0)
	if safeRadius <= 0 then
		return false
	end

	local rotation = math.rad(airport.IslandRotation or 0)
	local cosine = math.cos(rotation)
	local sine = math.sin(rotation)
	local rotatedX = localX * cosine - localZ * sine
	local rotatedZ = localX * sine + localZ * cosine
	local aspectX = airport.IslandAspectX or 1
	local aspectZ = airport.IslandAspectZ or 1
	local normalizedX = rotatedX / (safeRadius * aspectX)
	local normalizedZ = rotatedZ / (safeRadius * aspectZ)
	local angle = math.atan2(normalizedZ, normalizedX)
	local boundary = Layout.IslandBoundaryScale(airport, angle)
	return normalizedX * normalizedX + normalizedZ * normalizedZ <= boundary * boundary
end

function Layout.TileTouchesIsland(airport, localX: number, localZ: number, tileSize: number): boolean
	local half = tileSize / 2
	for _, offset in ipairs({
		Vector2.new(0, 0),
		Vector2.new(-half, -half), Vector2.new(half, -half),
		Vector2.new(-half, half), Vector2.new(half, half),
		Vector2.new(-half, 0), Vector2.new(half, 0),
		Vector2.new(0, -half), Vector2.new(0, half),
	}) do
		if Layout.IsInsideIsland(airport, localX + offset.X, localZ + offset.Y) then
			return true
		end
	end
	return false
end

function Layout.FindContainingIsland(airports, worldPosition: Vector3)
	for _, airport in ipairs(airports) do
		if not airport.ParentIslandCode then
			local airportCF = CFrame.new(airport.Position) * CFrame.Angles(0, math.rad(-airport.Heading), 0)
			local localPosition = airportCF:PointToObjectSpace(worldPosition)
			if Layout.IsInsideIsland(airport, localPosition.X, localPosition.Z, -Layout.IslandSurfaceAllowance) then
				return airport
			end
		end
	end
	return nil
end

function Layout.GroundReserveBounds(airport): (number, number, number)
	local minimumX = math.huge
	local maximumX = -math.huge
	local maximumAbsZ = 0
	local protectedHalfWidth = Layout.RunwayWidth / 2 + Layout.GroundReserveSideBuffer
	local protectedHalfLength = airport.RunwayLength / 2 + Layout.StopwayLength + Layout.GroundReserveEndBuffer
	for _, placement in ipairs(Layout.RunwayPlacements(airport)) do
		local angle = math.rad(placement.HeadingDelta or 0)
		local extentX = protectedHalfWidth * math.abs(math.cos(angle)) + protectedHalfLength * math.abs(math.sin(angle))
		local extentZ = protectedHalfWidth * math.abs(math.sin(angle)) + protectedHalfLength * math.abs(math.cos(angle))
		minimumX = math.min(minimumX, placement.X - extentX)
		maximumX = math.max(maximumX, placement.X + extentX)
		maximumAbsZ = math.max(maximumAbsZ, math.abs(placement.Z) + extentZ)
	end
	local startX = minimumX
	local endX = math.max(maximumX, Layout.FacilityEndX(airport) + Layout.GroundReserveSideBuffer)
	local apronHalf = math.max(
		math.abs(Layout.ApronCenterZ - Layout.ApronLength / 2),
		math.abs(Layout.ApronCenterZ + Layout.ApronLength / 2)
	) + 420
	return startX, endX, math.max(maximumAbsZ, apronHalf)
end

function Layout.RunwayPlacements(airport)
	local placements = {}
	for index = 1, airport.RunwayCount or 1 do
		if index == 2 and airport.RunwayLayout == "CROSSING_SECONDARY" then
			placements[index] = {
				X = -math.max(Layout.AdditionalRunwaySpacing * 1.55, airport.RunwayLength * 0.28),
				Z = Layout.AdditionalRunwayStagger * 0.25,
				HeadingDelta = airport.RunwayCrossAngle or 42,
			}
		else
			local spacingIndex = index - 1
			if airport.RunwayLayout == "CROSSING_SECONDARY" and index > 2 then spacingIndex += 1 end
			local longitudinalOffset = index > 1 and (index % 2 == 0 and 1 or -1) * Layout.AdditionalRunwayStagger or 0
			placements[index] = {
				X = -spacingIndex * Layout.AdditionalRunwaySpacing,
				Z = longitudinalOffset,
				HeadingDelta = 0,
			}
		end
	end
	return placements
end

function Layout.RunwayLocalCFrame(placement): CFrame
	return CFrame.new(placement.X, 0, placement.Z) * CFrame.Angles(0, math.rad(-(placement.HeadingDelta or 0)), 0)
end

function Layout.RunwayHeading(airport, placement): number
	return (airport.Heading + (placement.HeadingDelta or 0)) % 360
end

function Layout.RunwayOffsets(airport): { number }
	local offsets = {}
	for index, placement in ipairs(Layout.RunwayPlacements(airport)) do
		offsets[index] = placement.X
	end
	return offsets
end

function Layout.IsMovementZone(airport, localX: number, localZ: number, margin: number?): boolean
	local padding = margin or 0
	local localPosition = Vector3.new(localX, 0, localZ)
	for _, placement in ipairs(Layout.RunwayPlacements(airport)) do
		local runwayPosition = Layout.RunwayLocalCFrame(placement):PointToObjectSpace(localPosition)
		if math.abs(runwayPosition.X) <= Layout.RunwayWidth / 2 + Layout.TaxiwayWidth + padding then
			return true
		end
	end
	return false
end

return Layout
