--!strict

-- V31 aircraft-specific visual animation tuning. These values move presentation
-- geometry only; they are never read by the authoritative flight-physics code.

local AircraftAnimationConfig = {}

local base = {
	Angles = {
		Aileron = 17,
		Elevator = 16,
		Rudder = 24,
		Flaps = 22,
		Spoilers = 38,
		NoseSteer = 31,
		WingFlex = 2.8,
		WingtipFold = 72,
	},
	Rates = {
		Control = 9.0,
		Flaps = 1.7,
		Slats = 1.55,
		SpoilerDeploy = 7.0,
		SpoilerRetract = 3.2,
		SpeedBrakeDeploy = 3.8,
		SpeedBrakeRetract = 4.8,
		GearSequence = 0.294,
		WheelSpinUp = 5.0,
		WheelSpinDown = 1.25,
		FanSpinUp = 2.3,
		FanSpinDown = 1.15,
		ReverserDeploy = 3.0,
		ReverserStow = 4.2,
		WingFlex = 2.4,
		WingtipFold = 0.72,
		Compression = 5.2,
	},
	Inversion = {
		Aileron = 1,
		Elevator = 1,
		Rudder = 1,
		Flaps = 1,
		Slats = 1,
		Spoilers = 1,
		Wheels = 1,
		Fans = 1,
		Reversers = 1,
	},
	TravelScale = {
		Flaps = 1,
		Slats = 1,
		Reversers = 1,
	},
	GearSequence = {
		DoorOpenEnd = 0.22,
		GearMoveStart = 0.20,
		GearMoveEnd = 0.80,
		DoorCloseStart = 0.78,
	},
}

local profileOverrides = {
	Regional = {
		Angles = { Aileron = 19, Elevator = 18, Rudder = 26, Flaps = 24, Spoilers = 40, NoseSteer = 34 },
		Rates = { Control = 10.5, Flaps = 2.0, Slats = 1.85, GearSequence = 0.294 },
	},
	["Narrow-body"] = {
		Angles = { Aileron = 18, Elevator = 17, Rudder = 25, Flaps = 23, Spoilers = 39, NoseSteer = 33 },
		Rates = { Control = 9.6, Flaps = 1.85, Slats = 1.70, GearSequence = 0.294 },
	},
	["Mid-size"] = {
		Angles = { Aileron = 17, Elevator = 16, Rudder = 24, Flaps = 22, Spoilers = 38, NoseSteer = 31 },
		Rates = { Control = 8.7, Flaps = 1.65, Slats = 1.55, GearSequence = 0.294 },
	},
	["Wide-body"] = {
		Angles = { Aileron = 16, Elevator = 15, Rudder = 23, Flaps = 21, Spoilers = 37, NoseSteer = 29 },
		Rates = { Control = 7.8, Flaps = 1.45, Slats = 1.35, GearSequence = 0.28 },
	},
	["Long-haul"] = {
		Angles = { Aileron = 15, Elevator = 14, Rudder = 22, Flaps = 20, Spoilers = 36, NoseSteer = 28 },
		Rates = { Control = 7.2, Flaps = 1.30, Slats = 1.24, GearSequence = 0.26 },
	},
	Jumbo = {
		Angles = { Aileron = 14, Elevator = 13, Rudder = 21, Flaps = 19, Spoilers = 35, NoseSteer = 27 },
		Rates = { Control = 6.5, Flaps = 1.18, Slats = 1.12, GearSequence = 0.24 },
	},
	Superjumbo = {
		Angles = { Aileron = 13, Elevator = 12, Rudder = 20, Flaps = 18, Spoilers = 34, NoseSteer = 25 },
		Rates = { Control = 5.9, Flaps = 1.08, Slats = 1.02, GearSequence = 0.22 },
	},
}

local profileByCode = {
	A223 = "Regional", E290 = "Regional", E295 = "Regional", CRJ9 = "Regional",
	A19N = "Narrow-body", A20N = "Narrow-body", A21N = "Narrow-body", B38M = "Narrow-body", B39M = "Narrow-body",
	B752 = "Mid-size",
	A339 = "Wide-body", B763 = "Wide-body",
	A359 = "Long-haul", A35K = "Long-haul", B77W = "Long-haul", B779 = "Long-haul", B788 = "Long-haul", B789 = "Long-haul",
	B748 = "Jumbo",
	A388 = "Superjumbo",
}

local function deepCopy(source: { [any]: any }): { [any]: any }
	local result = {}
	for key, value in pairs(source) do
		result[key] = if type(value) == "table" then deepCopy(value) else value
	end
	return result
end

local function merge(target: { [any]: any }, source: { [any]: any })
	for key, value in pairs(source) do
		if type(value) == "table" and type(target[key]) == "table" then
			merge(target[key], value)
		else
			target[key] = value
		end
	end
end

function AircraftAnimationConfig.Get(aircraftCode: string?)
	local result = deepCopy(base)
	local profileName = profileByCode[aircraftCode or ""] or "Mid-size"
	local override = profileOverrides[profileName]
	if override then merge(result, override) end
	result.Profile = profileName
	result.AircraftCode = aircraftCode or "UNKNOWN"
	result.Revision = 28
	return result
end

return AircraftAnimationConfig
