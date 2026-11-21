--!strict

local list = {
	{ Name = "Airbus A220-300", Code = "A223", Maker = "Airbus", Class = "Regional", Scale = 0.78, Engines = 2, StallSpeed = 112, CruiseSpeed = 447, Response = 1.24, Color = Color3.fromRGB(44, 199, 255) },
	{ Name = "Airbus A319neo", Code = "A19N", Maker = "Airbus", Class = "Narrow-body", Scale = 0.84, Engines = 2, StallSpeed = 118, CruiseSpeed = 447, Response = 1.16, Color = Color3.fromRGB(38, 224, 189) },
	{ Name = "Airbus A320neo", Code = "A20N", Maker = "Airbus", Class = "Narrow-body", Scale = 0.90, Engines = 2, StallSpeed = 121, CruiseSpeed = 447, Response = 1.10, Color = Color3.fromRGB(36, 184, 255) },
	{ Name = "Airbus A321neo", Code = "A21N", Maker = "Airbus", Class = "Narrow-body", Scale = 0.98, Engines = 2, StallSpeed = 126, CruiseSpeed = 447, Response = 1.02, Color = Color3.fromRGB(124, 140, 255) },
	{ Name = "Airbus A330-900", Code = "A339", Maker = "Airbus", Class = "Wide-body", Scale = 1.25, Engines = 2, StallSpeed = 135, CruiseSpeed = 470, Response = 0.82, Color = Color3.fromRGB(155, 115, 255) },
	{ Name = "Airbus A350-900", Code = "A359", Maker = "Airbus", Class = "Long-haul", Scale = 1.33, Engines = 2, StallSpeed = 138, CruiseSpeed = 488, Response = 0.78, Color = Color3.fromRGB(213, 103, 244) },
	{ Name = "Airbus A350-1000", Code = "A35K", Maker = "Airbus", Class = "Long-haul", Scale = 1.45, Engines = 2, StallSpeed = 142, CruiseSpeed = 488, Response = 0.70, Color = Color3.fromRGB(237, 103, 190) },
	{ Name = "Airbus A380-800", Code = "A388", Maker = "Airbus", Class = "Superjumbo", Scale = 1.74, Engines = 4, StallSpeed = 151, CruiseSpeed = 488, Response = 0.56, Color = Color3.fromRGB(255, 111, 145) },
	{ Name = "Boeing 737 MAX 8", Code = "B38M", Maker = "Boeing", Class = "Narrow-body", Scale = 0.92, Engines = 2, StallSpeed = 124, CruiseSpeed = 453, Response = 1.12, Color = Color3.fromRGB(29, 201, 255) },
	{ Name = "Boeing 737 MAX 9", Code = "B39M", Maker = "Boeing", Class = "Narrow-body", Scale = 1.00, Engines = 2, StallSpeed = 128, CruiseSpeed = 453, Response = 1.04, Color = Color3.fromRGB(36, 220, 178) },
	{ Name = "Boeing 747-8", Code = "B748", Maker = "Boeing", Class = "Jumbo", Scale = 1.62, Engines = 4, StallSpeed = 148, CruiseSpeed = 493, Response = 0.62, Color = Color3.fromRGB(255, 181, 44) },
	{ Name = "Boeing 757-200", Code = "B752", Maker = "Boeing", Class = "Mid-size", Scale = 1.03, Engines = 2, StallSpeed = 128, CruiseSpeed = 459, Response = 0.98, Color = Color3.fromRGB(255, 220, 77) },
	{ Name = "Boeing 767-300ER", Code = "B763", Maker = "Boeing", Class = "Wide-body", Scale = 1.16, Engines = 2, StallSpeed = 133, CruiseSpeed = 459, Response = 0.88, Color = Color3.fromRGB(180, 220, 75) },
	{ Name = "Boeing 777-300ER", Code = "B77W", Maker = "Boeing", Class = "Long-haul", Scale = 1.48, Engines = 2, StallSpeed = 144, CruiseSpeed = 490, Response = 0.68, Color = Color3.fromRGB(73, 217, 145) },
	{ Name = "Boeing 777-9", Code = "B779", Maker = "Boeing", Class = "Long-haul", Scale = 1.58, Engines = 2, StallSpeed = 146, CruiseSpeed = 490, Response = 0.64, Color = Color3.fromRGB(57, 199, 121) },
	{ Name = "Boeing 787-8", Code = "B788", Maker = "Boeing", Class = "Long-haul", Scale = 1.23, Engines = 2, StallSpeed = 135, CruiseSpeed = 488, Response = 0.82, Color = Color3.fromRGB(69, 169, 255) },
	{ Name = "Boeing 787-9", Code = "B789", Maker = "Boeing", Class = "Long-haul", Scale = 1.34, Engines = 2, StallSpeed = 139, CruiseSpeed = 488, Response = 0.76, Color = Color3.fromRGB(98, 125, 255) },
	{ Name = "Embraer E190-E2", Code = "E290", Maker = "Embraer", Class = "Regional", Scale = 0.68, Engines = 2, StallSpeed = 108, CruiseSpeed = 447, Response = 1.36, Color = Color3.fromRGB(163, 103, 255) },
	{ Name = "Embraer E195-E2", Code = "E295", Maker = "Embraer", Class = "Regional", Scale = 0.74, Engines = 2, StallSpeed = 113, CruiseSpeed = 447, Response = 1.29, Color = Color3.fromRGB(223, 110, 233) },
	{ Name = "Bombardier CRJ-900", Code = "CRJ9", Maker = "Bombardier", Class = "Regional", Scale = 0.60, Engines = 2, StallSpeed = 104, CruiseSpeed = 447, Response = 1.48, Color = Color3.fromRGB(255, 109, 141) },
}

-- Approximate full-scale exterior dimensions in metres. The procedural model
-- generator uses these values so every aircraft has its own recognizable
-- proportions instead of being the same tube scaled up or down.
local geometryByCode = {
	A223 = { LengthM = 38.70, SpanM = 35.10, HeightM = 11.50, WidthM = 3.28, Sweep = 25, EngineDiameterM = 2.10, EngineArchitecture = "GEARED_NARROW", Winglet = true, MainGearAxles = 1, ExpectedWheelCount = 6, NoseProfile = "A220" },
	A19N = { LengthM = 33.84, SpanM = 35.80, HeightM = 11.76, WidthM = 3.95, Sweep = 25, EngineDiameterM = 2.05, EngineArchitecture = "NARROW_HIGH_BYPASS", Winglet = true, MainGearAxles = 1, ExpectedWheelCount = 6, NoseProfile = "A320" },
	A20N = { LengthM = 37.57, SpanM = 35.80, HeightM = 11.76, WidthM = 3.95, Sweep = 25, EngineDiameterM = 2.05, EngineArchitecture = "NARROW_HIGH_BYPASS", Winglet = true, MainGearAxles = 1, ExpectedWheelCount = 6, NoseProfile = "A320" },
	A21N = { LengthM = 44.51, SpanM = 35.80, HeightM = 11.76, WidthM = 3.95, Sweep = 25, EngineDiameterM = 2.05, EngineArchitecture = "NARROW_HIGH_BYPASS", Winglet = true, MainGearAxles = 1, ExpectedWheelCount = 6, NoseProfile = "A320" },
	A339 = { LengthM = 63.69, SpanM = 64.00, HeightM = 16.79, WidthM = 5.64, Sweep = 30, EngineDiameterM = 3.40, EngineArchitecture = "WIDE_TRENT", Winglet = true, MainGearAxles = 2, ExpectedWheelCount = 10, NoseProfile = "A330" },
	A359 = { LengthM = 66.80, SpanM = 64.75, HeightM = 17.05, WidthM = 5.96, Sweep = 31, EngineDiameterM = 3.30, EngineArchitecture = "WIDE_TRENT", Winglet = true, MainGearAxles = 2, ExpectedWheelCount = 10, NoseProfile = "A350" },
	A35K = { LengthM = 73.79, SpanM = 64.75, HeightM = 17.08, WidthM = 5.96, Sweep = 31, EngineDiameterM = 3.30, EngineArchitecture = "WIDE_TRENT", Winglet = true, MainGearAxles = 3, ExpectedWheelCount = 14, NoseProfile = "A350" },
	A388 = { LengthM = 72.72, SpanM = 79.75, HeightM = 24.09, WidthM = 7.14, Sweep = 33, EngineDiameterM = 3.20, EngineArchitecture = "WIDE_TRENT", Winglet = true, WingtipFence = true, Decks = 2, MainGearAxles = 2, BodyGearAxles = 3, ExpectedWheelCount = 22, NoseProfile = "A380" },
	B38M = { LengthM = 39.52, SpanM = 35.92, HeightM = 12.30, WidthM = 3.76, Sweep = 25, EngineDiameterM = 2.10, EngineArchitecture = "NARROW_HIGH_BYPASS", Winglet = true, SplitWinglet = true, MainGearAxles = 1, ExpectedWheelCount = 6, NoseProfile = "B737" },
	B39M = { LengthM = 42.16, SpanM = 35.92, HeightM = 12.30, WidthM = 3.76, Sweep = 25, EngineDiameterM = 2.10, EngineArchitecture = "NARROW_HIGH_BYPASS", Winglet = true, SplitWinglet = true, MainGearAxles = 1, ExpectedWheelCount = 6, NoseProfile = "B737" },
	B748 = { LengthM = 76.30, SpanM = 68.40, HeightM = 19.40, WidthM = 6.50, Sweep = 37, EngineDiameterM = 3.25, EngineArchitecture = "WIDE_CHEVRON", Winglet = false, UpperDeck = true, MainGearAxles = 2, BodyGearAxles = 2, ExpectedWheelCount = 18, ChevronNacelle = true, NoseProfile = "B747" },
	B752 = { LengthM = 47.32, SpanM = 38.05, HeightM = 13.56, WidthM = 3.76, Sweep = 25, EngineDiameterM = 2.20, EngineArchitecture = "WIDE_CLASSIC", Winglet = true, WingletStyle = "BLENDED_TALL", MainGearAxles = 2, ExpectedWheelCount = 10, NoseProfile = "B757" },
	B763 = { LengthM = 54.94, SpanM = 47.57, HeightM = 15.85, WidthM = 5.03, Sweep = 31, EngineDiameterM = 2.65, EngineArchitecture = "WIDE_CLASSIC", Winglet = true, WingletStyle = "BLENDED_TALL", MainGearAxles = 2, ExpectedWheelCount = 10, NoseProfile = "B767" },
	B77W = { LengthM = 73.86, SpanM = 64.80, HeightM = 18.50, WidthM = 6.19, Sweep = 32, EngineDiameterM = 3.55, EngineArchitecture = "WIDE_GE", Winglet = false, MainGearAxles = 3, ExpectedWheelCount = 14, NoseProfile = "B777" },
	B779 = { LengthM = 76.70, SpanM = 71.80, HeightM = 19.70, WidthM = 6.20, Sweep = 33, EngineDiameterM = 3.65, EngineArchitecture = "WIDE_GE", Winglet = false, FoldingTips = true, MainGearAxles = 3, ExpectedWheelCount = 14, NoseProfile = "B777" },
	B788 = { LengthM = 56.72, SpanM = 60.12, HeightM = 16.92, WidthM = 5.77, Sweep = 32, EngineDiameterM = 3.25, EngineArchitecture = "WIDE_CHEVRON", Winglet = false, ChevronNacelle = true, MainGearAxles = 2, ExpectedWheelCount = 10, NoseProfile = "B787" },
	B789 = { LengthM = 62.81, SpanM = 60.12, HeightM = 17.02, WidthM = 5.77, Sweep = 32, EngineDiameterM = 3.25, EngineArchitecture = "WIDE_CHEVRON", Winglet = false, ChevronNacelle = true, MainGearAxles = 2, ExpectedWheelCount = 10, NoseProfile = "B787" },
	E290 = { LengthM = 36.24, SpanM = 33.72, HeightM = 10.72, WidthM = 3.01, Sweep = 25, EngineDiameterM = 1.85, EngineArchitecture = "GEARED_REGIONAL", Winglet = true, MainGearAxles = 1, ExpectedWheelCount = 6, NoseProfile = "E2" },
	E295 = { LengthM = 41.50, SpanM = 35.12, HeightM = 10.90, WidthM = 3.01, Sweep = 25, EngineDiameterM = 1.85, EngineArchitecture = "GEARED_REGIONAL", Winglet = true, MainGearAxles = 1, ExpectedWheelCount = 6, NoseProfile = "E2" },
	CRJ9 = { LengthM = 36.20, SpanM = 24.90, HeightM = 7.50, WidthM = 2.69, Sweep = 25, EngineDiameterM = 1.45, EngineArchitecture = "REGIONAL_REAR", Winglet = true, RearEngines = true, TTail = true, MainGearAxles = 1, ExpectedWheelCount = 6, NoseProfile = "CRJ" },
}

local byCode = {}
for _, aircraft in ipairs(list) do
	local geometry = geometryByCode[aircraft.Code]
	if geometry then
		for key, value in pairs(geometry) do
			aircraft[key] = value
		end
	end
	byCode[aircraft.Code] = aircraft
end

return {
	List = list,
	ByCode = byCode,
}
