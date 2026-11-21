--!nocheck

-- V27 data-driven aircraft material layer. Map fields are intentionally empty
-- until original Around the World texture assets are uploaded. Existing
-- MeshPart TextureIDs and SurfaceAppearance maps are never overwritten by the
-- default Apply() path.

local AircraftMaterialConfig = {}

local EMPTY_MAPS = {
	ColorMap = "",
	NormalMap = "",
	RoughnessMap = "",
	MetalnessMap = "",
	EmissiveMap = "",
}

local function maps()
	return table.clone(EMPTY_MAPS)
end

AircraftMaterialConfig.Definitions = {
	PaintedFuselage = {
		Maps = maps(), Material = Enum.Material.SmoothPlastic, Reflectance = 0.025,
		ApplicableMaps = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
	},
	BareMetal = {
		Maps = maps(), Material = Enum.Material.Metal, Reflectance = 0.12,
		ApplicableMaps = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
	},
	Wings = {
		Maps = maps(), Material = Enum.Material.SmoothPlastic, Reflectance = 0.035,
		ApplicableMaps = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
	},
	EngineNacelles = {
		Maps = maps(), Material = Enum.Material.SmoothPlastic, Reflectance = 0.045,
		ApplicableMaps = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
	},
	RubberTires = {
		Maps = maps(), Material = Enum.Material.Rubber, Reflectance = 0,
		ApplicableMaps = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
	},
	CockpitWindows = {
		Maps = maps(), Material = Enum.Material.Glass, Reflectance = 0.11,
		Color = Color3.fromRGB(17, 38, 52),
		ApplicableMaps = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
	},
	PassengerWindows = {
		Maps = maps(), Material = Enum.Material.Glass, Reflectance = 0.07,
		Color = Color3.fromRGB(24, 49, 62),
		ApplicableMaps = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
	},
	InteriorPanels = {
		Maps = maps(), Material = Enum.Material.SmoothPlastic, Reflectance = 0.015,
		ApplicableMaps = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
	},
	InstrumentScreens = {
		Maps = maps(), Material = Enum.Material.Neon, Reflectance = 0.02,
		Color = Color3.fromRGB(10, 28, 32),
		ApplicableMaps = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap", "EmissiveMap" },
	},
}

-- Public compatibility view for existing project customizations.
AircraftMaterialConfig.PBRMaps = {}
for className, definition in pairs(AircraftMaterialConfig.Definitions) do
	AircraftMaterialConfig.PBRMaps[className] = definition.Maps
end

AircraftMaterialConfig.MapDescriptions = {
	ColorMap = "Base color and livery detail without baked lighting or reflections.",
	NormalMap = "Small surface relief such as panel seams, fasteners, tire tread, and interior grain.",
	RoughnessMap = "Grayscale response: white is rough and black is smooth; paint, rubber, glass, and metal need different values.",
	MetalnessMap = "Grayscale mask: bare metal is white while paint, rubber, glass, and interior plastic remain black.",
	EmissiveMap = "Self-lit pixel mask for instrument screens. SurfaceAppearance has no native emissive slot, so V27 preserves it in PBREmissiveMap for the screen/effects workflow.",
}

local CLASS_ALIASES = {
	PaintedAirframe = "PaintedFuselage", CockpitGlass = "CockpitWindows",
	PassengerGlass = "PassengerWindows", TireRubber = "RubberTires", EngineInterior = "BareMetal",
}

local function contains(name, pattern)
	return string.find(string.lower(name), string.lower(pattern), 1, true) ~= nil
end

local function validClass(value)
	if type(value) ~= "string" then return nil end
	if CLASS_ALIASES[value] then return CLASS_ALIASES[value] end
	if AircraftMaterialConfig.Definitions[value] then return value end
	return nil
end

local function classify(part)
	local attributed = validClass(part:GetAttribute("PBRMaterialClass"))
	if attributed then return attributed end
	local name = part.Name
	if contains(name, "instrument") or contains(name, "screen") or contains(name, "display") then return "InstrumentScreens" end
	if contains(name, "cockpitfrontpane") or contains(name, "cockpitsidepane") or contains(name, "windshieldpane") or contains(name, "cockpitglass") then return "CockpitWindows" end
	if contains(name, "cabinwindow") or contains(name, "upperwindow") or contains(name, "passengerglass") then return "PassengerWindows" end
	if contains(name, "hub") or contains(name, "brake") or contains(name, "caliper") then return "BareMetal" end
	if contains(name, "wheel") or contains(name, "tire") or contains(name, "bumper") or contains(name, "tread") then return "RubberTires" end
	if contains(name, "wing") or contains(name, "aileron") or contains(name, "flap") or contains(name, "slat") or contains(name, "spoiler") then return "Wings" end
	if contains(name, "nacelle") or contains(name, "cowling") or contains(name, "pylon") then return "EngineNacelles" end
	if contains(name, "interior") or contains(name, "cockpitpanel") or contains(name, "cabinpanel") or contains(name, "seat") then return "InteriorPanels" end
	if contains(name, "fan") or contains(name, "exhaust") or contains(name, "turbine") or contains(name, "intake") or part.Material == Enum.Material.Metal then return "BareMetal" end
	return "PaintedFuselage"
end

local function hasConfiguredStandardMap(definition)
	for _, propertyName in ipairs({ "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }) do
		if definition.Maps[propertyName] ~= "" then return true end
	end
	return false
end

local function existingSurface(part)
	local first = nil
	local count = 0
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("SurfaceAppearance") then
			count += 1
			first = first or child
		end
	end
	return first, count
end

local function applyFallback(part, definition)
	part.Material = definition.Material
	part.Reflectance = definition.Reflectance
	if definition.Color then part.Color = definition.Color end
end

function AircraftMaterialConfig.Inspect(model)
	local report = {
		MeshPartCount = 0, SurfaceAppearanceCount = 0, DuplicateSurfaceAppearanceCount = 0,
		TextureIDs = {}, SurfaceMaps = {}, MaterialAssignments = {},
	}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			local materialName = item.Material.Name
			report.MaterialAssignments[materialName] = (report.MaterialAssignments[materialName] or 0) + 1
		end
		if item:IsA("MeshPart") then
			report.MeshPartCount += 1
			if item.TextureID ~= "" then
				table.insert(report.TextureIDs, { Path = item:GetFullName(), TextureID = item.TextureID })
			end
			local _, surfaceCount = existingSurface(item)
			if surfaceCount > 1 then report.DuplicateSurfaceAppearanceCount += surfaceCount - 1 end
			for _, child in ipairs(item:GetChildren()) do
				if child:IsA("SurfaceAppearance") then
					report.SurfaceAppearanceCount += 1
					table.insert(report.SurfaceMaps, {
						Path = child:GetFullName(), ColorMap = child.ColorMap, NormalMap = child.NormalMap,
						RoughnessMap = child.RoughnessMap, MetalnessMap = child.MetalnessMap,
						EmissiveMap = child:GetAttribute("PBREmissiveMap") or item:GetAttribute("PBREmissiveMap") or "",
					})
				end
			end
		end
	end
	return report
end

function AircraftMaterialConfig.GetMissingMaps(model)
	local usedClasses = {}
	if model then
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("BasePart") then usedClasses[classify(item)] = true end
		end
	else
		for className in pairs(AircraftMaterialConfig.Definitions) do usedClasses[className] = true end
	end
	local missing = {}
	for className in pairs(usedClasses) do
		local definition = AircraftMaterialConfig.Definitions[className]
		if definition then
			for _, mapName in ipairs(definition.ApplicableMaps) do
				if definition.Maps[mapName] == "" then
					table.insert(missing, { MaterialClass = className, Map = mapName, ShouldContain = AircraftMaterialConfig.MapDescriptions[mapName] })
				end
			end
		end
	end
	table.sort(missing, function(a, b) return (a.MaterialClass .. a.Map) < (b.MaterialClass .. b.Map) end)
	return missing
end

-- Safe and idempotent: existing SurfaceAppearance objects are reused, no
-- existing TextureID/map ID is replaced, and repeated calls create at most one
-- managed SurfaceAppearance per MeshPart.
function AircraftMaterialConfig.Apply(model)
	local before = AircraftMaterialConfig.Inspect(model)
	local report = {
		Before = before, MeshPartCount = before.MeshPartCount,
		CreatedSurfaceAppearanceCount = 0, ReusedSurfaceAppearanceCount = 0,
		PreservedAssetIDCount = #before.TextureIDs + #before.SurfaceMaps,
	}
	for _, item in ipairs(model:GetDescendants()) do
		if not item:IsA("BasePart") then continue end
		local materialClass = classify(item)
		local definition = AircraftMaterialConfig.Definitions[materialClass]
		item:SetAttribute("PBRMaterialClass", materialClass)
		applyFallback(item, definition)
		if not item:IsA("MeshPart") then continue end
		local surface = existingSurface(item)
		if surface then
			report.ReusedSurfaceAppearanceCount += 1
		elseif hasConfiguredStandardMap(definition) then
			surface = Instance.new("SurfaceAppearance")
			surface.Name = "AircraftPBRSurface"
			surface:SetAttribute("ManagedByAircraftMaterialConfig", true)
			surface.Parent = item
			report.CreatedSurfaceAppearanceCount += 1
		end
		if surface then
			for _, propertyName in ipairs({ "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }) do
				local configured = definition.Maps[propertyName]
				if configured ~= "" and surface[propertyName] == "" then surface[propertyName] = configured end
			end
			local emissive = definition.Maps.EmissiveMap
			if emissive ~= "" and (surface:GetAttribute("PBREmissiveMap") or "") == "" then
				surface:SetAttribute("PBREmissiveMap", emissive)
			end
		end
	end
	report.MissingMaps = AircraftMaterialConfig.GetMissingMaps(model)
	model:SetAttribute("MaterialSystemRevision", 27)
	model:SetAttribute("PBRMeshPartCount", report.MeshPartCount)
	model:SetAttribute("PBRSurfaceCount", before.SurfaceAppearanceCount + report.CreatedSurfaceAppearanceCount)
	model:SetAttribute("PBRMapsAwaitingUpload", #report.MissingMaps > 0)
	model:SetAttribute("PBRExistingAssetIDsPreserved", true)
	return report
end

return AircraftMaterialConfig
