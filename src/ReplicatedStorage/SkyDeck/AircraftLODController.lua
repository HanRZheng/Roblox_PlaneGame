--!nocheck

-- Local distance LOD for fine procedural details. Major silhouette, controls,
-- landing gear, and collision proxies are never hidden.

local AircraftLODController = {}
local cacheByModel = setmetatable({}, { __mode = "k" })

local highOnlyNames = { "Fastener", "Wiper", "StaticPort", "StaticWick", "DrainMast", "ServicePanel", "GuideVane", "BrakeCaliper", "PanelRing", "Mullion", "Brow" }
local mediumOnlyNames = { "CabinWindow", "DoorFrame", "PackInlet", "PylonFillet", "NacelleChevron", "Tread", "Hub" }

local function containsAny(name, patterns)
	for _, pattern in ipairs(patterns) do
		if string.find(name, pattern, 1, true) then return true end
	end
	return false
end

local function buildCache(model)
	local cache = { High = {}, Medium = {} }
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute("CollisionProxy") ~= true then
			local explicit = item:GetAttribute("LODDetail")
			if explicit == "HIGH" or containsAny(item.Name, highOnlyNames) then
				table.insert(cache.High, item)
			elseif explicit == "MEDIUM" or containsAny(item.Name, mediumOnlyNames) then
				table.insert(cache.Medium, item)
			end
		end
	end
	cacheByModel[model] = cache
	return cache
end

local function setHidden(parts, hidden)
	for _, part in ipairs(parts) do
		if part.Parent then part.LocalTransparencyModifier = hidden and 1 or 0 end
	end
end

function AircraftLODController.Apply(model, distance)
	if not model or not model.Parent then return end
	local cache = cacheByModel[model] or buildCache(model)
	local level = distance > 1750 and 2 or (distance > 760 and 1 or 0)
	setHidden(cache.High, level >= 1)
	setHidden(cache.Medium, level >= 2)
	model:SetAttribute("LocalLODLevel", level)
end

return AircraftLODController
