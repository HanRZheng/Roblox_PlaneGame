--!nocheck

-- V31 safe, data-driven aircraft livery application. No asset IDs are bundled:
-- a livery is applied only after the owner supplies valid IDs, a target, and a
-- verified UV layout. That prevents mirrored text and accidental whole-aircraft
-- texture assignment.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local AircraftLiveryConfig = {}

AircraftLiveryConfig.Liveries = {
	-- Add owner-uploaded liveries here. Example schema (keep IDs empty until upload):
	-- MyLivery = {
	--     TargetAircraftCode = "B763",
	--     VerifiedUniqueSideUVs = true,
	--     MeshNames = { "FuselageExterior", "LeftEngineNacelle", "RightEngineNacelle" },
	--     MaterialClasses = { PaintedFuselage = true, EngineNacelles = true, Wings = true },
	--     Maps = { ColorMap = "", NormalMap = "", RoughnessMap = "", MetalnessMap = "", EmissiveMap = "" },
	--     MeshOverrides = {},
	-- },
}

AircraftLiveryConfig.RequiredFields = {
	"TargetAircraftCode",
	"VerifiedUniqueSideUVs",
	"MeshNames",
	"Maps.ColorMap",
}

local STANDARD_MAPS = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }
local ALL_MAPS = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap", "EmissiveMap" }
local EXCLUDED_CONTAINERS = { Controls = true, Collision = true, Effects = true, Interior = true }

local function validAssetId(value)
	if type(value) ~= "string" or value == "" then return false end
	if string.find(value, "[", 1, true) or string.find(value, "]", 1, true) then return false end
	return string.match(value, "^rbxassetid://%d+$") ~= nil or string.match(value, "^https://www%.roblox%.com/asset/%?id=%d+$") ~= nil
end

local function descendantsPath(instance, ancestor)
	local names = {}
	local current = instance
	while current and current ~= ancestor do
		table.insert(names, 1, current.Name)
		current = current.Parent
	end
	return table.concat(names, ".")
end

local function existingSurface(mesh)
	local preferred
	local first
	local count = 0
	for _, child in ipairs(mesh:GetChildren()) do
		if child:IsA("SurfaceAppearance") then
			count += 1
			first = first or child
			if child:GetAttribute("ManagedByAircraftLiveryConfig") == true then preferred = child end
		end
	end
	return preferred or first, count
end

local function nameSet(list)
	local result = {}
	for _, value in ipairs(list or {}) do
		if type(value) == "string" and value ~= "" then result[value] = true end
	end
	return result
end

local function inExcludedContainer(item, model)
	local current = item.Parent
	while current and current ~= model do
		if EXCLUDED_CONTAINERS[current.Name] then return true end
		current = current.Parent
	end
	return false
end

local function eligibleMeshes(model, livery)
	local requestedNames = nameSet(livery.MeshNames)
	local hasRequestedNames = next(requestedNames) ~= nil
	local classes = livery.MaterialClasses or {}
	local result = {}
	for _, item in ipairs(model:GetDescendants()) do
		if not item:IsA("MeshPart") or inExcludedContainer(item, model) then continue end
		local named = hasRequestedNames and requestedNames[item.Name] == true
		local classed = classes[item:GetAttribute("PBRMaterialClass")] == true
		if named or (not hasRequestedNames and classed) then table.insert(result, item) end
	end
	return result
end

local function resolvedMaps(livery, mesh)
	local result = {}
	local override = livery.MeshOverrides and livery.MeshOverrides[mesh.Name]
	for _, mapName in ipairs(ALL_MAPS) do
		local value = override and override[mapName] or nil
		if value == nil then value = livery.Maps and livery.Maps[mapName] or "" end
		result[mapName] = value
	end
	return result
end

function AircraftLiveryConfig.Inspect(model)
	local report = {
		AircraftPath = model:GetFullName(),
		AircraftCode = model:GetAttribute("AircraftCode"),
		MeshPartCount = 0,
		SurfaceAppearanceCount = 0,
		MeshParts = {},
		ReflectanceWarnings = {},
		UVVerification = model:GetAttribute("UVSideLayout") or "UNKNOWN",
	}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("MeshPart") then
			report.MeshPartCount += 1
			local _, surfaceCount = existingSurface(item)
			report.SurfaceAppearanceCount += surfaceCount
			table.insert(report.MeshParts, {
				Path = descendantsPath(item, model),
				TextureID = item.TextureID,
				MaterialClass = item:GetAttribute("PBRMaterialClass"),
				SurfaceAppearanceCount = surfaceCount,
			})
			if item.Reflectance > 0.18 then
				table.insert(report.ReflectanceWarnings, {
					Path = descendantsPath(item, model),
					Reflectance = item.Reflectance,
				})
			end
		end
	end
	return report
end

function AircraftLiveryConfig.Validate(model, liveryName)
	local livery = AircraftLiveryConfig.Liveries[liveryName]
	local issues = {}
	if not livery then
		table.insert(issues, "No livery named '" .. tostring(liveryName) .. "' is configured.")
		return false, issues, {}
	end
	if type(livery.TargetAircraftCode) ~= "string" or livery.TargetAircraftCode == "" then
		table.insert(issues, "TargetAircraftCode is missing.")
	elseif model:GetAttribute("AircraftCode") ~= livery.TargetAircraftCode then
		table.insert(issues, "TargetAircraftCode does not match this model.")
	end
	if livery.VerifiedUniqueSideUVs ~= true then
		table.insert(issues, "Unique left/right UV space has not been verified; branded text could be mirrored.")
	end
	if not livery.Maps or not validAssetId(livery.Maps.ColorMap) then
		table.insert(issues, "A valid owner-uploaded ColorMap asset ID is required.")
	end
	for _, mapName in ipairs(ALL_MAPS) do
		local value = livery.Maps and livery.Maps[mapName] or ""
		if value ~= "" and not validAssetId(value) then
			table.insert(issues, mapName .. " is not a valid Roblox asset ID.")
		end
	end
	local meshes = eligibleMeshes(model, livery)
	if #meshes == 0 then
		table.insert(issues, "No intended visual MeshParts matched MeshNames or MaterialClasses.")
	end
	return #issues == 0, issues, meshes
end

local function createBackup(model, liveryName)
	if not RunService:IsServer() then return nil, "Backups can only be created by the server." end
	local backups = ServerStorage:FindFirstChild("AroundTheWorldAircraftBackups") or Instance.new("Folder")
	backups.Name = "AroundTheWorldAircraftBackups"
	backups.Parent = ServerStorage
	local backup = model:Clone()
	backup.Name = model.Name .. "_BeforeLivery_" .. liveryName .. "_" .. tostring(os.time())
	backup:SetAttribute("NonRunningBackup", true)
	backup:SetAttribute("SourceAircraftPath", model:GetFullName())
	for _, item in ipairs(backup:GetDescendants()) do
		if item:IsA("Script") or item:IsA("LocalScript") then item.Disabled = true end
		if item:IsA("ProximityPrompt") then item.Enabled = false end
	end
	backup.Parent = backups
	return backup
end

-- Idempotent application: one existing/managed SurfaceAppearance is reused for
-- each intended mesh. Validation runs before backup or mutation, and every old
-- ID is captured in the returned report and protected by the ServerStorage copy.
function AircraftLiveryConfig.Apply(model, liveryName, options)
	options = options or {}
	local valid, issues, meshes = AircraftLiveryConfig.Validate(model, liveryName)
	local report = {
		Applied = false,
		LiveryName = liveryName,
		Inspection = AircraftLiveryConfig.Inspect(model),
		Issues = issues,
		ChangedInstances = {},
		MissingOptionalMaps = {},
	}
	if not valid then return report end
	local livery = AircraftLiveryConfig.Liveries[liveryName]
	for _, mapName in ipairs({ "NormalMap", "RoughnessMap", "MetalnessMap", "EmissiveMap" }) do
		if not livery.Maps[mapName] or livery.Maps[mapName] == "" then table.insert(report.MissingOptionalMaps, mapName) end
	end
	if options.DryRun == true then
		report.DryRun = true
		report.EligibleMeshCount = #meshes
		return report
	end
	local backup, backupError = createBackup(model, liveryName)
	if not backup then
		table.insert(report.Issues, backupError)
		return report
	end
	report.BackupPath = backup:GetFullName()
	for _, mesh in ipairs(meshes) do
		local surface = existingSurface(mesh)
		local created = false
		if not surface then
			surface = Instance.new("SurfaceAppearance")
			surface.Name = "AircraftLiverySurface"
			surface:SetAttribute("ManagedByAircraftLiveryConfig", true)
			surface.Parent = mesh
			created = true
		end
		local maps = resolvedMaps(livery, mesh)
		local before = {}
		for _, mapName in ipairs(STANDARD_MAPS) do
			before[mapName] = surface[mapName]
			if maps[mapName] ~= "" then surface[mapName] = maps[mapName] end
		end
		before.EmissiveMap = surface:GetAttribute("PBREmissiveMap") or ""
		if maps.EmissiveMap ~= "" then surface:SetAttribute("PBREmissiveMap", maps.EmissiveMap) end
		mesh:SetAttribute("ActiveLivery", liveryName)
		table.insert(report.ChangedInstances, {
			Path = descendantsPath(mesh, model),
			SurfacePath = descendantsPath(surface, model),
			CreatedSurfaceAppearance = created,
			PreviousMaps = before,
			AppliedMaps = maps,
		})
	end
	model:SetAttribute("ActiveLivery", liveryName)
	model:SetAttribute("LiverySystemRevision", 31)
	model:SetAttribute("LiveryUVVerified", true)
	report.Applied = true
	return report
end

return AircraftLiveryConfig
