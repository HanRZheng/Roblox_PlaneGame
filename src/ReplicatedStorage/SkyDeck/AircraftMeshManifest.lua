--!strict

-- V27 import contract for future Blender-built aircraft. This module is data
-- only: requiring it does not create, move, or modify any aircraft instances.

local variants = {
	A223 = { Name = "Airbus A220-300", LengthStuds = 138.21, SpanStuds = 125.36, HeightStuds = 41.07, Engines = 2, Wheels = 6, Nose = "A220", MainTire = nil, NoseTire = nil, TireStatus = "VERIFY_A220_AMM" },
	A19N = { Name = "Airbus A319neo", LengthStuds = 120.86, SpanStuds = 127.86, HeightStuds = 42.00, Engines = 2, Wheels = 6, Nose = "A320", MainTire = { DiameterStuds = 4.17, WidthStuds = 1.54, Marking = "46x17.0R20" }, NoseTire = { DiameterStuds = 2.72, WidthStuds = 0.80, Marking = "30x8.8R15" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
	A20N = { Name = "Airbus A320neo", LengthStuds = 134.18, SpanStuds = 127.86, HeightStuds = 42.00, Engines = 2, Wheels = 6, Nose = "A320", MainTire = { DiameterStuds = 4.17, WidthStuds = 1.54, Marking = "46x17.0R20" }, NoseTire = { DiameterStuds = 2.72, WidthStuds = 0.80, Marking = "30x8.8R15" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
	A21N = { Name = "Airbus A321neo", LengthStuds = 158.96, SpanStuds = 127.86, HeightStuds = 42.00, Engines = 2, Wheels = 6, Nose = "A320", MainTire = { DiameterStuds = 4.54, WidthStuds = 1.63, Marking = "1270x455R22" }, NoseTire = { DiameterStuds = 2.72, WidthStuds = 0.80, Marking = "30x8.8R15" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
	A339 = { Name = "Airbus A330-900", LengthStuds = 227.46, SpanStuds = 228.57, HeightStuds = 59.96, Engines = 2, Wheels = 10, Nose = "A330", MainTire = { DiameterStuds = 5.00, WidthStuds = 1.89, Marking = "1400x530R23" }, NoseTire = { DiameterStuds = 3.75, WidthStuds = 1.41, Marking = "1050x395R16" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
	A359 = { Name = "Airbus A350-900", LengthStuds = 238.57, SpanStuds = 231.25, HeightStuds = 60.89, Engines = 2, Wheels = 10, Nose = "A350", MainTire = { DiameterStuds = 5.00, WidthStuds = 1.89, Marking = "1400x530R23" }, NoseTire = { DiameterStuds = 3.75, WidthStuds = 1.41, Marking = "1050x395R16" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
	A35K = { Name = "Airbus A350-1000", LengthStuds = 263.54, SpanStuds = 231.25, HeightStuds = 61.00, Engines = 2, Wheels = 14, Nose = "A350", MainTire = { DiameterStuds = 4.54, WidthStuds = 1.81, Marking = "50x20.0R22" }, NoseTire = { DiameterStuds = 3.75, WidthStuds = 1.41, Marking = "1050x395R16" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
	A388 = { Name = "Airbus A380-800", LengthStuds = 259.71, SpanStuds = 284.82, HeightStuds = 86.04, Engines = 4, Wheels = 22, Nose = "A380", MainTire = { DiameterStuds = 5.00, WidthStuds = 1.89, Marking = "1400x530R23" }, NoseTire = { DiameterStuds = 4.54, WidthStuds = 1.63, Marking = "1270x455R22" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
	B38M = { Name = "Boeing 737 MAX 8", LengthStuds = 141.14, SpanStuds = 128.29, HeightStuds = 43.93, Engines = 2, Wheels = 6, Nose = "B737", MainTire = { DiameterStuds = 4.04, WidthStuds = 1.50, Marking = "H44.5x16.5R21" }, NoseTire = { DiameterStuds = 2.45, WidthStuds = 0.70, Marking = "27x7.75R15" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
	B39M = { Name = "Boeing 737 MAX 9", LengthStuds = 150.57, SpanStuds = 128.29, HeightStuds = 43.93, Engines = 2, Wheels = 6, Nose = "B737", MainTire = { DiameterStuds = 4.04, WidthStuds = 1.50, Marking = "H44.5x16.5R21" }, NoseTire = { DiameterStuds = 2.45, WidthStuds = 0.70, Marking = "27x7.75R15" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
	B748 = { Name = "Boeing 747-8", LengthStuds = 272.50, SpanStuds = 244.29, HeightStuds = 69.29, Engines = 4, Wheels = 18, Nose = "B747", MainTire = { DiameterStuds = 4.72, WidthStuds = 1.91, Marking = "52x21.0R22" }, NoseTire = { DiameterStuds = 4.54, WidthStuds = 1.81, Marking = "50x20.0R22" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
	B752 = { Name = "Boeing 757-200", LengthStuds = 169.00, SpanStuds = 135.89, HeightStuds = 48.43, Engines = 2, Wheels = 10, Nose = "B757", MainTire = { DiameterStuds = 3.63, WidthStuds = 1.32, Marking = "H40x14.5-19" }, NoseTire = { DiameterStuds = 2.81, WidthStuds = 1.18, Marking = "H31x13.0-12" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
	B763 = { Name = "Boeing 767-300ER", LengthStuds = 196.21, SpanStuds = 169.89, HeightStuds = 56.61, Engines = 2, Wheels = 10, Nose = "B767", MainTire = { DiameterStuds = 4.17, WidthStuds = 1.63, Marking = "H46x18.0-20" }, NoseTire = { DiameterStuds = 3.36, WidthStuds = 1.27, Marking = "H37x14.0-15" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
	B77W = { Name = "Boeing 777-300ER", LengthStuds = 263.79, SpanStuds = 231.43, HeightStuds = 66.07, Engines = 2, Wheels = 14, Nose = "B777", MainTire = { DiameterStuds = 4.72, WidthStuds = 1.91, Marking = "52x21.0R22" }, NoseTire = { DiameterStuds = 3.90, WidthStuds = 1.59, Marking = "43x17.5R17" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
	B779 = { Name = "Boeing 777-9", LengthStuds = 273.93, SpanStuds = 256.43, HeightStuds = 70.36, Engines = 2, Wheels = 14, Nose = "B777", MainTire = nil, NoseTire = nil, TireStatus = "VERIFY_7779_AMM" },
	B788 = { Name = "Boeing 787-8", LengthStuds = 202.57, SpanStuds = 214.71, HeightStuds = 60.43, Engines = 2, Wheels = 10, Nose = "B787", MainTire = { DiameterStuds = 4.54, WidthStuds = 1.81, Marking = "50x20.0R22" }, NoseTire = { DiameterStuds = 3.63, WidthStuds = 1.45, Marking = "40x16.0R16" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
	B789 = { Name = "Boeing 787-9", LengthStuds = 224.32, SpanStuds = 214.71, HeightStuds = 60.79, Engines = 2, Wheels = 10, Nose = "B787", MainTire = { DiameterStuds = 4.90, WidthStuds = 1.91, Marking = "54x21.0R23" }, NoseTire = { DiameterStuds = 3.63, WidthStuds = 1.45, Marking = "40x16.0R16" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
	E290 = { Name = "Embraer E190-E2", LengthStuds = 129.43, SpanStuds = 120.43, HeightStuds = 38.29, Engines = 2, Wheels = 6, Nose = "E2", MainTire = { DiameterStuds = 3.72, WidthStuds = 1.45, Marking = "H41x16.0R20" }, NoseTire = { DiameterStuds = 2.18, WidthStuds = 0.70, Marking = "24x7.7R10" }, TireStatus = "FAMILY_REFERENCE_VERIFY_E2_AMM" },
	E295 = { Name = "Embraer E195-E2", LengthStuds = 148.21, SpanStuds = 125.43, HeightStuds = 38.93, Engines = 2, Wheels = 6, Nose = "E2", MainTire = { DiameterStuds = 3.72, WidthStuds = 1.45, Marking = "H41x16.0R20" }, NoseTire = { DiameterStuds = 2.18, WidthStuds = 0.70, Marking = "24x7.7R10" }, TireStatus = "FAMILY_REFERENCE_VERIFY_E2_AMM" },
	CRJ9 = { Name = "Bombardier CRJ-900", LengthStuds = 129.29, SpanStuds = 88.93, HeightStuds = 26.79, Engines = 2, Wheels = 6, Nose = "CRJ", MainTire = { DiameterStuds = 3.27, WidthStuds = 1.09, Marking = "H36x12.0-18" }, NoseTire = { DiameterStuds = 1.86, WidthStuds = 0.61, Marking = "20.5x6.75-10" }, TireStatus = "VERIFIED_APPLICATION_CHART" },
}

local Manifest = {
	Version = 27,
	StudsPerMetre = 1 / 0.28,
	Variants = variants,
	RequiredAttachments = {
		"ATT_Root", "ATT_CameraCockpit", "ATT_CameraBelly", "ATT_Nav_L", "ATT_Nav_R",
		"ATT_StrobeTail", "ATT_BeaconTop", "ATT_BeaconBottom", "ATT_Landing_L",
		"ATT_Landing_R", "ATT_GearContact_Nose", "ATT_GearContact_Main_L", "ATT_GearContact_Main_R",
	},
}

local function add(list, value)
	table.insert(list, value)
end

function Manifest.GetRequiredObjectNames(code: string): { string }
	local variant = variants[code]
	if not variant then return {} end
	local prefix = "ATW_" .. code .. "_"
	local control = "CTRL_" .. code .. "_"
	local gear = "GEAR_" .. code .. "_"
	local names = {
		prefix .. "Fuselage", prefix .. "Nose", prefix .. "TailCone", prefix .. "Wing_L", prefix .. "Wing_R",
		prefix .. "Fin", prefix .. "HStab_L", prefix .. "HStab_R", prefix .. "CockpitGlass", prefix .. "CabinGlass",
		control .. "Aileron_L", control .. "Aileron_R", control .. "Elevator_L", control .. "Elevator_R",
		control .. "Rudder", control .. "Flap_L_01", control .. "Flap_R_01", control .. "Slat_L_01",
		control .. "Slat_R_01", control .. "Spoiler_L_01", control .. "Spoiler_R_01",
		gear .. "NoseStrut", gear .. "MainStrut_L", gear .. "MainStrut_R",
	}
	for engineIndex = 1, variant.Engines do
		local suffix = string.format("%02d", engineIndex)
		add(names, prefix .. "Nacelle_" .. suffix)
		add(names, prefix .. "Pylon_" .. suffix)
		add(names, control .. "Fan_" .. suffix)
	end
	for wheelIndex = 1, variant.Wheels do
		add(names, gear .. string.format("Wheel_%02d", wheelIndex))
	end
	return names
end

function Manifest.GetMovingObjectNames(code: string): { string }
	local variant = variants[code]
	if not variant then return {} end
	local names = {}
	for _, name in ipairs(Manifest.GetRequiredObjectNames(code)) do
		if string.sub(name, 1, 5) == "CTRL_" or string.sub(name, 1, 5) == "GEAR_" then
			add(names, name)
		end
	end
	return names
end

return Manifest
