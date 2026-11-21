--!strict

-- V25 procedural silhouette profiles. Real exterior length, span, height, and
-- fuselage width still come from AircraftCatalog. These ratios refine the visual
-- planform and moving-surface layout by family; they do not alter flight physics.
-- Values that are not manufacturer-published dimensions are reference-view
-- estimates and are deliberately kept separate from the catalog's hard data.

local AircraftSilhouetteConfig = {}

local defaults = {
	FuselageVerticalRatio = 1.00,
	WingRootZRatio = -0.055,
	WingRootChordRatio = 0.270,
	WingTipChordRatio = 0.065,
	WingDihedralDegrees = 2.0,
	TailSpanRatio = 0.34,
	TailRootChordRatio = 0.120,
	TailTipChordRatio = 0.045,
	FinRootChordRatio = 0.125,
	FinTipChordRatio = 0.040,
	FinSweepRatio = 0.42,
	FlapSections = 2,
	FlapMaxAngle = 26,
	SlatSections = 7,
	SpoilerSections = 4,
}

local byProfile = {
	A220 = { FuselageVerticalRatio = 1.04, WingRootChordRatio = 0.258, WingTipChordRatio = 0.058, WingDihedralDegrees = 3.2, TailSpanRatio = 0.32, SlatSections = 7 },
	A320 = { FuselageVerticalRatio = 1.02, WingRootChordRatio = 0.250, WingTipChordRatio = 0.060, WingDihedralDegrees = 3.0, TailSpanRatio = 0.32, SlatSections = 8 },
	A330 = { FuselageVerticalRatio = 1.01, WingRootChordRatio = 0.255, WingTipChordRatio = 0.055, WingDihedralDegrees = 3.0, TailSpanRatio = 0.32, FlapSections = 3, FlapMaxAngle = 30, SlatSections = 10, SpoilerSections = 5 },
	A350 = { FuselageVerticalRatio = 1.03, WingRootChordRatio = 0.248, WingTipChordRatio = 0.050, WingDihedralDegrees = 4.2, TailSpanRatio = 0.31, FlapSections = 3, FlapMaxAngle = 30, SlatSections = 10, SpoilerSections = 6 },
	A380 = { FuselageVerticalRatio = 1.08, WingRootChordRatio = 0.270, WingTipChordRatio = 0.060, WingDihedralDegrees = 3.2, TailSpanRatio = 0.31, FlapSections = 3, FlapMaxAngle = 30, SlatSections = 12, SpoilerSections = 6 },
	B737 = { FuselageVerticalRatio = 0.98, WingRootChordRatio = 0.248, WingTipChordRatio = 0.058, WingDihedralDegrees = 3.0, TailSpanRatio = 0.32, FinRootChordRatio = 0.112, FinTipChordRatio = 0.034, FinSweepRatio = 0.46, SlatSections = 8 },
	B747 = { FuselageVerticalRatio = 1.02, WingRootChordRatio = 0.250, WingTipChordRatio = 0.052, WingDihedralDegrees = 3.0, TailSpanRatio = 0.30, FlapSections = 3, FlapMaxAngle = 30, SlatSections = 12, SpoilerSections = 6 },
	B757 = { FuselageVerticalRatio = 0.98, WingRootChordRatio = 0.262, WingTipChordRatio = 0.058, WingDihedralDegrees = 3.0, TailSpanRatio = 0.31, FinRootChordRatio = 0.116, FinTipChordRatio = 0.034, FinSweepRatio = 0.45, SlatSections = 8 },
	B767 = { FuselageVerticalRatio = 0.99, WingRootChordRatio = 0.255, WingTipChordRatio = 0.055, WingDihedralDegrees = 3.2, TailSpanRatio = 0.31, FinRootChordRatio = 0.118, FinTipChordRatio = 0.036, FinSweepRatio = 0.43, FlapSections = 3, FlapMaxAngle = 30, SlatSections = 9, SpoilerSections = 5 },
	B777 = { FuselageVerticalRatio = 1.01, WingRootChordRatio = 0.258, WingTipChordRatio = 0.050, WingDihedralDegrees = 4.0, TailSpanRatio = 0.31, FlapSections = 3, FlapMaxAngle = 30, SlatSections = 10, SpoilerSections = 6 },
	B787 = { FuselageVerticalRatio = 1.02, WingRootChordRatio = 0.245, WingTipChordRatio = 0.045, WingDihedralDegrees = 5.0, TailSpanRatio = 0.31, FlapSections = 3, FlapMaxAngle = 30, SlatSections = 10, SpoilerSections = 6 },
	E2 = { FuselageVerticalRatio = 1.03, WingRootChordRatio = 0.248, WingTipChordRatio = 0.050, WingDihedralDegrees = 4.0, TailSpanRatio = 0.31, SlatSections = 7 },
	CRJ = { FuselageVerticalRatio = 0.96, WingRootChordRatio = 0.245, WingTipChordRatio = 0.055, WingDihedralDegrees = 2.8, TailSpanRatio = 0.30, FlapMaxAngle = 28, SlatSections = 6, SpoilerSections = 3 },
}

function AircraftSilhouetteConfig.Get(spec)
	local result = table.clone(defaults)
	local profile = byProfile[spec.NoseProfile or ""]
	if profile then
		for key, value in pairs(profile) do result[key] = value end
	end
	return result
end

return AircraftSilhouetteConfig
