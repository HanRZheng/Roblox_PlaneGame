--!strict

local skylinePosition = Vector3.new(-30000, 0, -30000)
local skylineHeading = 58
local skylineCF = CFrame.new(skylinePosition) * CFrame.Angles(0, math.rad(-skylineHeading), 0)
local skylineRegionalPosition = skylineCF:PointToWorldSpace(Vector3.new(7400, 0, 5200))
local emberPosition = Vector3.new(23000, 0, -21000)
local emberHeading = 132
local emberCF = CFrame.new(emberPosition) * CFrame.Angles(0, math.rad(-emberHeading), 0)
-- The complete SPK runway/terminal reserve fits inside Ember's reshaped coast
-- here, with a 1,300+ stud landside gap from Ember International's reserve.
local sparkPosition = emberCF:PointToWorldSpace(Vector3.new(-5500, 0, 2500))
-- Green Grass sits southwest (negative X, positive Z) of Alpine Ridge with a
-- wide water channel between the two island coastlines.
local greenGrassPosition = Vector3.new(-38000, 0, 34000)

-- Aspect products remain close to one so these silhouettes retain nearly the
-- same land area as their V25 circular counterparts. Small radial lobes produce
-- varied coastlines without cutting into each airport's protected center.
local list = {
	{ Code = "SPT", Name = "Sunport International", Region = "Aurora Island", Position = Vector3.new(0, 0, 0), Heading = 0, RunwayLength = 4600, RunwayCount = 3, RunwayLayout = "CROSSING_SECONDARY", RunwayCrossAngle = 37, IslandRadius = 12000, IslandShape = "BroadLobed", IslandAspectX = 1.16, IslandAspectZ = 0.86, IslandRotation = 40, IslandLobeA = 0.10, IslandLobeB = 0.05, IslandPhase = 0.35, Gates = 13, TerminalStyle = "DUAL_PIER", Terrain = "Green", Accent = Color3.fromRGB(79, 215, 128) },
	{ Code = "NPT", Name = "Northpoint Regional", Region = "Mistral Island", Position = Vector3.new(-18000, 0, -12500), Heading = 42, RunwayLength = 3400, IslandRadius = 6500, IslandShape = "Teardrop", IslandAspectX = 0.80, IslandAspectZ = 1.25, IslandRotation = -20, IslandLobeA = 0.07, IslandLobeB = 0.035, IslandPhase = 1.15, Gates = 3, TerminalStyle = "ROTUNDA", Terrain = "Green", Accent = Color3.fromRGB(114, 200, 255) },
	{ Code = "CBY", Name = "Coral Bay Airport", Region = "Solara Keys", Position = Vector3.new(19000, 0, 12000), Heading = 90, RunwayLength = 4200, RunwayCount = 2, RunwayLayout = "CROSSING_SECONDARY", RunwayCrossAngle = -44, IslandRadius = 9000, IslandShape = "BayLobed", IslandAspectX = 1.10, IslandAspectZ = 0.91, IslandRotation = -80, IslandLobeA = 0.12, IslandLobeB = 0.05, IslandPhase = 2.10, Gates = 7, TerminalStyle = "CRESCENT", Terrain = "Tropical", Accent = Color3.fromRGB(68, 224, 208) },
	{ Code = "ALP", Name = "Alpine Ridge", Region = "Highland Reach", Position = Vector3.new(-19000, 0, 17000), Heading = 148, RunwayLength = 3300, IslandRadius = 7500, IslandShape = "Ridge", IslandAspectX = 0.76, IslandAspectZ = 1.32, IslandRotation = 11, IslandLobeA = 0.075, IslandLobeB = 0.035, IslandPhase = 0.80, Gates = 5, TerminalStyle = "RIDGE", Terrain = "Alpine", Accent = Color3.fromRGB(200, 227, 255) },
	{ Code = "GGA", Name = "Green Grass Airport", Region = "Greenhaven Island", Position = greenGrassPosition, Heading = 122, RunwayLength = 3900, RunwayCount = 2, RunwayLayout = "CROSSING_SECONDARY", RunwayCrossAngle = 52, IslandRadius = 8800, IslandShape = "MultiLobed", IslandAspectX = 0.94, IslandAspectZ = 1.06, IslandRotation = -18, IslandLobeA = 0.095, IslandLobeB = 0.045, IslandPhase = 1.32, Gates = 7, TerminalStyle = "T_PIER", Terrain = "Green", BuildingCount = 32, TreeCount = 72, Accent = Color3.fromRGB(92, 218, 113) },
	{ Code = "EMB", Name = "Ember International", Region = "Redstone Desert", Position = emberPosition, Heading = emberHeading, RunwayLength = 4700, RunwayCount = 2, IslandRadius = 12500, IslandShape = "BroadLobed", IslandAspectX = 1.20, IslandAspectZ = 0.84, IslandRotation = -70, IslandLobeA = 0.105, IslandLobeB = 0.045, IslandPhase = 1.75, Gates = 15, TerminalStyle = "STEPPED", Terrain = "Desert", Accent = Color3.fromRGB(255, 189, 98) },
	{ Code = "SPK", Name = "Spark Airport", Region = "Redstone Desert", Position = sparkPosition, Heading = emberHeading, RunwayLength = 2800, RunwayCount = 1, IslandRadius = 3200, ParentIslandCode = "EMB", Gates = 2, TerminalStyle = "COMPACT", Terrain = "Desert", SkipTerrain = true, BuildingCount = 12, TreeCount = 8, Accent = Color3.fromRGB(255, 126, 63) },
	{ Code = "IHP", Name = "Island Hop Airfield", Region = "Pelican Cay", Position = Vector3.new(4000, 0, 26000), Heading = 18, RunwayLength = 3000, IslandRadius = 6000, IslandShape = "Teardrop", IslandAspectX = 0.82, IslandAspectZ = 1.22, IslandRotation = 31, IslandLobeA = 0.065, IslandLobeB = 0.035, IslandPhase = 2.65, Gates = 2, TerminalStyle = "ROTUNDA", Terrain = "Tropical", Accent = Color3.fromRGB(248, 225, 109) },
	{ Code = "SKY", Name = "Skyline International", Region = "Metropolis Island", Position = skylinePosition, Heading = skylineHeading, RunwayLength = 5200, RunwayCount = 3, IslandRadius = 15000, IslandShape = "MultiLobed", IslandAspectX = 1.08, IslandAspectZ = 0.93, IslandRotation = 90, IslandLobeA = 0.115, IslandLobeB = 0.055, IslandPhase = 2.35, Gates = 14, TerminalStyle = "DUAL_PIER", Terrain = "Urban", Accent = Color3.fromRGB(122, 178, 255) },
	{ Code = "SKR", Name = "Skyline Regional", Region = "Metropolis Island", Position = skylineRegionalPosition, Heading = skylineHeading, RunwayLength = 2900, RunwayCount = 1, IslandRadius = 3500, ParentIslandCode = "SKY", Gates = 3, TerminalStyle = "COMPACT", Terrain = "Urban", SkipTerrain = true, BuildingCount = 18, TreeCount = 12, Accent = Color3.fromRGB(255, 198, 91) },
}

local byCode = {}
for _, airport in ipairs(list) do
	byCode[airport.Code] = airport
end

return {
	List = list,
	ByCode = byCode,
}
