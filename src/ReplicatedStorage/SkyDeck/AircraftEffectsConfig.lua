--!strict

-- V29 presentation-only effects tuning. Aircraft positions and electrical/
-- engine state remain authoritative elsewhere; this module only controls how
-- existing Attachments, Lights, emitters, and fan-blur discs are presented.

local AircraftEffectsConfig = {}

local base = {
	Profile = "Narrow-body",
	EngineCount = 2,
	Distances = {
		Lights = 2800,
		FanBlur = 760,
		Exhaust = 820,
		Vortex = 1150,
		Contrail = 1950,
		TireSmoke = 1050,
		Spray = 850,
		Rain = 450,
	},
	MinimumQuality = {
		Lights = 1,
		FanBlur = 3,
		Exhaust = 4,
		Vortex = 6,
		Contrail = 5,
		TireSmoke = 4,
		Spray = 5,
		Rain = 5,
	},
	Thresholds = {
		LandingLightAltitude = 620,
		TurnoffLightAltitude = 120,
		TaxiLightMaxSpeed = 95,
		VortexHumidity = 0.62,
		VortexMinSpeed = 112,
		VortexMaxAltitude = 360,
		VortexMinFlaps = 1,
		ContrailMinAltitude = 720,
		ContrailMinSpeed = 245,
		ContrailMinPower = 64,
		ExhaustMinPower = 14,
		TireSmokeMinLoad = 0.12,
		TireSmokeMinSpeed = 92,
		TireSmokeCooldown = 1.4,
		SprayMinWetness = 0.30,
		SprayMinSpeed = 28,
	},
	Rates = {
		ExhaustBase = 2,
		ExhaustPowerScale = 0.085,
		Vortex = 10,
		Contrail = 14,
		SprayMaximum = 38,
		RainBase = 55,
		RainScale = 260,
		TireSmokeMaximumBurst = 15,
	},
	FlashPatterns = {
		Beacon = { Period = 1.12, Windows = { { 0.00, 0.11 }, { 0.20, 0.27 } } },
		Strobe = { Period = 1.24, Windows = { { 0.00, 0.055 }, { 0.15, 0.205 } } },
	},
	LightOffsets = {
		LEFT_NAVIGATION = Vector3.zero,
		RIGHT_NAVIGATION = Vector3.zero,
		TAIL_NAVIGATION = Vector3.zero,
		LEFT_STROBE = Vector3.zero,
		RIGHT_STROBE = Vector3.zero,
		UPPER_BEACON = Vector3.zero,
		LOWER_BEACON = Vector3.zero,
		LANDING = Vector3.zero,
		TAXI = Vector3.zero,
	},
}

local profiles = {
	Regional = {
		Distances = { FanBlur = 650, Exhaust = 700, Vortex = 980, Contrail = 1700 },
		Thresholds = { VortexMinSpeed = 100, ContrailMinAltitude = 680, TireSmokeMinSpeed = 82 },
		Rates = { ExhaustPowerScale = 0.072, TireSmokeMaximumBurst = 11 },
		LightOffsets = { TAIL_NAVIGATION = Vector3.new(0, 0.02, -0.04), TAXI = Vector3.new(0, -0.03, 0) },
	},
	["Narrow-body"] = {},
	["Mid-size"] = {
		Distances = { FanBlur = 820, Exhaust = 880, Vortex = 1200 },
		Thresholds = { ContrailMinAltitude = 760, TireSmokeMinLoad = 0.13 },
		LightOffsets = { LEFT_STROBE = Vector3.new(0.04, 0, 0), RIGHT_STROBE = Vector3.new(-0.04, 0, 0) },
	},
	["Wide-body"] = {
		Distances = { Lights = 3100, FanBlur = 920, Exhaust = 1000, Vortex = 1350, Contrail = 2200 },
		Thresholds = { ContrailMinAltitude = 790, TireSmokeMinLoad = 0.14, TireSmokeMinSpeed = 100 },
		Rates = { ExhaustPowerScale = 0.095, TireSmokeMaximumBurst = 16 },
		LightOffsets = { LEFT_NAVIGATION = Vector3.new(-0.06, 0, 0), RIGHT_NAVIGATION = Vector3.new(0.06, 0, 0) },
	},
	["Long-haul"] = {
		Distances = { Lights = 3300, FanBlur = 980, Exhaust = 1080, Vortex = 1450, Contrail = 2350 },
		Thresholds = { ContrailMinAltitude = 820, ContrailMinPower = 67, TireSmokeMinLoad = 0.15, TireSmokeMinSpeed = 104 },
		Rates = { ExhaustPowerScale = 0.10, TireSmokeMaximumBurst = 17 },
		LightOffsets = { LEFT_NAVIGATION = Vector3.new(-0.08, 0, 0), RIGHT_NAVIGATION = Vector3.new(0.08, 0, 0) },
	},
	Jumbo = {
		Distances = { Lights = 3500, FanBlur = 1050, Exhaust = 1150, Vortex = 1500, Contrail = 2500 },
		Thresholds = { ContrailMinAltitude = 850, TireSmokeMinLoad = 0.16, TireSmokeMinSpeed = 108 },
		Rates = { ExhaustPowerScale = 0.105, TireSmokeMaximumBurst = 18 },
		LightOffsets = { TAIL_NAVIGATION = Vector3.new(0, 0.08, 0.02) },
	},
	Superjumbo = {
		Distances = { Lights = 3700, FanBlur = 1120, Exhaust = 1220, Vortex = 1600, Contrail = 2650 },
		Thresholds = { ContrailMinAltitude = 880, TireSmokeMinLoad = 0.17, TireSmokeMinSpeed = 112 },
		Rates = { ExhaustPowerScale = 0.11, TireSmokeMaximumBurst = 20 },
		LightOffsets = { TAIL_NAVIGATION = Vector3.new(0, 0.10, 0.03), TAXI = Vector3.new(0, -0.06, -0.03) },
	},
}

local aircraft = {
	A223 = { Profile = "Regional", EngineCount = 2 }, E290 = { Profile = "Regional", EngineCount = 2 },
	E295 = { Profile = "Regional", EngineCount = 2 }, CRJ9 = { Profile = "Regional", EngineCount = 2 },
	A19N = { Profile = "Narrow-body", EngineCount = 2 }, A20N = { Profile = "Narrow-body", EngineCount = 2 },
	A21N = { Profile = "Narrow-body", EngineCount = 2 }, B38M = { Profile = "Narrow-body", EngineCount = 2 },
	B39M = { Profile = "Narrow-body", EngineCount = 2 }, B752 = { Profile = "Mid-size", EngineCount = 2 },
	A339 = { Profile = "Wide-body", EngineCount = 2 }, B763 = { Profile = "Wide-body", EngineCount = 2 },
	A359 = { Profile = "Long-haul", EngineCount = 2 }, A35K = { Profile = "Long-haul", EngineCount = 2 },
	B77W = { Profile = "Long-haul", EngineCount = 2 }, B779 = { Profile = "Long-haul", EngineCount = 2 },
	B788 = { Profile = "Long-haul", EngineCount = 2 }, B789 = { Profile = "Long-haul", EngineCount = 2 },
	B748 = { Profile = "Jumbo", EngineCount = 4 }, A388 = { Profile = "Superjumbo", EngineCount = 4 },
}

local function deepCopy(source: { [any]: any }): { [any]: any }
	local result = {}
	for key, value in pairs(source) do result[key] = if type(value) == "table" then deepCopy(value) else value end
	return result
end

local function merge(target: { [any]: any }, source: { [any]: any })
	for key, value in pairs(source) do
		if type(value) == "table" and type(target[key]) == "table" then merge(target[key], value) else target[key] = value end
	end
end

function AircraftEffectsConfig.Get(aircraftCode: string?)
	local result = deepCopy(base)
	local aircraftConfig = aircraft[aircraftCode or ""] or { Profile = "Narrow-body", EngineCount = 2 }
	local profile = profiles[aircraftConfig.Profile]
	if profile then merge(result, profile) end
	merge(result, aircraftConfig)
	result.AircraftCode = aircraftCode or "UNKNOWN"
	result.Revision = 29
	return result
end

return AircraftEffectsConfig
