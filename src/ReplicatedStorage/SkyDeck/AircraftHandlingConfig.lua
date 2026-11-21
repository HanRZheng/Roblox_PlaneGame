--!strict

-- V25 handling profiles. These preserve the approachable control scheme while
-- giving each weight class different inertia, bank authority, flap drag,
-- acceleration, rotation, braking, and landing-gear damping.

local AircraftHandlingConfig = {}

local profiles = {
	Regional = { BankMax = 30, PitchResponse = 1.08, RollResponse = 1.08, Acceleration = 1.10, RotationRate = 1.06, FlapDrag = 3.2, BrakeEffectiveness = 1.04, LandingDamping = 1.04 },
	["Narrow-body"] = { BankMax = 28, PitchResponse = 1.00, RollResponse = 0.98, Acceleration = 1.00, RotationRate = 1.00, FlapDrag = 3.6, BrakeEffectiveness = 1.00, LandingDamping = 1.00 },
	["Mid-size"] = { BankMax = 27, PitchResponse = 0.94, RollResponse = 0.91, Acceleration = 0.94, RotationRate = 0.94, FlapDrag = 4.0, BrakeEffectiveness = 0.97, LandingDamping = 0.97 },
	["Wide-body"] = { BankMax = 25, PitchResponse = 0.86, RollResponse = 0.82, Acceleration = 0.86, RotationRate = 0.86, FlapDrag = 4.5, BrakeEffectiveness = 0.92, LandingDamping = 0.92 },
	["Long-haul"] = { BankMax = 23, PitchResponse = 0.78, RollResponse = 0.74, Acceleration = 0.78, RotationRate = 0.78, FlapDrag = 5.0, BrakeEffectiveness = 0.88, LandingDamping = 0.88 },
	Jumbo = { BankMax = 22, PitchResponse = 0.73, RollResponse = 0.70, Acceleration = 0.72, RotationRate = 0.74, FlapDrag = 5.4, BrakeEffectiveness = 0.85, LandingDamping = 0.86 },
	Superjumbo = { BankMax = 20, PitchResponse = 0.66, RollResponse = 0.62, Acceleration = 0.66, RotationRate = 0.68, FlapDrag = 5.8, BrakeEffectiveness = 0.82, LandingDamping = 0.82 },
}

function AircraftHandlingConfig.Get(spec)
	local source = profiles[spec.Class] or profiles["Narrow-body"]
	local result = table.clone(source)
	result.Profile = spec.Class or "Narrow-body"
	return result
end

return AircraftHandlingConfig
