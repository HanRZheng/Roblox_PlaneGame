--!nocheck

-- V29 attachment-driven client effects. The controller reads the aircraft's
-- existing replicated electrical, engine, configuration, weather, and landing
-- state; it never creates a competing flight or controls system.

local AircraftEffectsConfig = require(script.Parent:WaitForChild("AircraftEffectsConfig"))

local AircraftEffectsController = {}
local cacheByModel = setmetatable({}, { __mode = "k" })
local cachedWorld = nil
local cachedQuality = 7
local lastQualityRead = -math.huge

local function getQualityLevel()
	if os.clock() - lastQualityRead < 2 then return cachedQuality end
	lastQualityRead = os.clock()
	pcall(function()
		local settings = UserSettings():GetService("UserGameSettings")
		local saved = settings.SavedQualityLevel
		if saved == Enum.SavedQualitySetting.Automatic then
			cachedQuality = 7
		else
			cachedQuality = tonumber(string.match(saved.Name, "%d+")) or saved.Value or 7
		end
	end)
	return math.clamp(cachedQuality, 1, 10)
end

local function getWorld()
	if cachedWorld and cachedWorld.Parent then return cachedWorld end
	cachedWorld = workspace:FindFirstChild("SkyDeckWorld")
	return cachedWorld
end

local function flashWindow(clock, pattern)
	local phase = clock % pattern.Period
	for _, window in ipairs(pattern.Windows) do
		if phase >= window[1] and phase <= window[2] then return true end
	end
	return false
end

local function effectAllowed(config, effectName, distance, quality)
	local maximumDistance = config.Distances[effectName] or 0
	local minimumQuality = config.MinimumQuality[effectName] or 1
	return distance <= maximumDistance and quality >= minimumQuality
end

local function applyConfiguredAttachmentOffset(attachment, config)
	local role = attachment:GetAttribute("AircraftLightRole")
	if not role then return end
	local basePosition = attachment:GetAttribute("BaseAttachmentPosition")
	if typeof(basePosition) ~= "Vector3" then
		basePosition = attachment.Position
		attachment:SetAttribute("BaseAttachmentPosition", basePosition)
	end
	attachment.Position = basePosition + (config.LightOffsets[role] or Vector3.zero)
end

local function buildCache(model)
	local config = AircraftEffectsConfig.Get(model:GetAttribute("AircraftCode"))
	local cache = {
		Config = config,
		Lights = {},
		Emitters = {},
		FanBlurParts = {},
		Connections = {},
		LastLandingPhase = model:GetAttribute("LandingPhase") or "NONE",
		LastSmokeClock = -math.huge,
		SmokeEmitterCount = 0,
	}

	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("Attachment") and item:GetAttribute("AircraftLightType") then
			applyConfiguredAttachmentOffset(item, config)
			local lights = {}
			for _, child in ipairs(item:GetChildren()) do
				if child:IsA("Light") then table.insert(lights, child) end
			end
			table.insert(cache.Lights, {
				Attachment = item,
				Part = item.Parent:IsA("BasePart") and item.Parent or item:FindFirstAncestorWhichIsA("BasePart"),
				Type = item:GetAttribute("AircraftLightType"),
				Role = item:GetAttribute("AircraftLightRole"),
				Lights = lights,
			})
		elseif item:IsA("ParticleEmitter") and item:GetAttribute("AircraftEffectType") then
			table.insert(cache.Emitters, item)
			if item:GetAttribute("AircraftEffectType") == "TIRE_SMOKE" then cache.SmokeEmitterCount += 1 end
		elseif item:IsA("BasePart") and item:GetAttribute("AircraftEffectType") == "FAN_BLUR" then
			table.insert(cache.FanBlurParts, item)
		end
	end

	table.insert(cache.Connections, model.Destroying:Connect(function()
		AircraftEffectsController.Clear(model)
	end))
	cacheByModel[model] = cache
	return cache
end

local function disableCache(cache)
	for _, rig in ipairs(cache.Lights) do
		for _, light in ipairs(rig.Lights) do light.Enabled = false end
	end
	for _, emitter in ipairs(cache.Emitters) do emitter.Enabled = false end
	for _, blur in ipairs(cache.FanBlurParts) do blur.Transparency = 1 end
end

function AircraftEffectsController.Apply(model, dt, cameraDistance)
	if not model then return end
	if not model.Parent then
		AircraftEffectsController.Clear(model)
		return
	end
	local cache = cacheByModel[model] or buildCache(model)
	local config = cache.Config
	local distance = cameraDistance or math.huge
	local quality = getQualityLevel()
	local clock = workspace.DistributedGameTime
	local electrical = model:GetAttribute("ExternalLights") ~= false
	local engine = model:GetAttribute("Engine") == true
	local onGround = model:GetAttribute("OnGround") == true
	local gear = (model:GetAttribute("GearProgress") or 0) > 0.76
	local altitude = model:GetAttribute("Altitude") or 0
	local speed = math.abs(model:GetAttribute("Speed") or 0)
	local flaps = model:GetAttribute("FlapPosition") or 0
	local enginePower = model:GetAttribute("EnginePower") or 0
	local touchdownLoad = model:GetAttribute("TouchdownLoad") or 0
	local world = getWorld()
	local humidity = world and world:GetAttribute("Humidity") or 0
	local rain = world and world:GetAttribute("RainIntensity") or 0
	local wetness = world and world:GetAttribute("WeatherWetness") or 0
	local lightsAllowed = electrical and effectAllowed(config, "Lights", distance, quality)

	for _, rig in ipairs(cache.Lights) do
		local enabled = false
		if rig.Type == "NAVIGATION" or rig.Type == "TAIL_NAVIGATION" then
			enabled = lightsAllowed
		elseif rig.Type == "BEACON" then
			enabled = lightsAllowed and engine and flashWindow(clock, config.FlashPatterns.Beacon)
		elseif rig.Type == "STROBE" then
			enabled = lightsAllowed and engine and flashWindow(clock, config.FlashPatterns.Strobe)
		elseif rig.Type == "LANDING" then
			enabled = lightsAllowed and engine and gear and (onGround or altitude < config.Thresholds.LandingLightAltitude)
		elseif rig.Type == "TAXI" then
			enabled = lightsAllowed and engine and onGround and speed < config.Thresholds.TaxiLightMaxSpeed
		elseif rig.Type == "TURNOFF" then
			enabled = lightsAllowed and engine and gear and (onGround or altitude < config.Thresholds.TurnoffLightAltitude)
		elseif rig.Type == "INSPECTION" or rig.Type == "LOGO" then
			enabled = lightsAllowed and engine
		end
		for _, light in ipairs(rig.Lights) do light.Enabled = enabled end
		if rig.Part then
			local steadyNavigation = rig.Type == "NAVIGATION" or rig.Type == "TAIL_NAVIGATION"
			rig.Part.Transparency = enabled and (steadyNavigation and 0.08 or 0) or 0.72
		end
	end

	local landingPhase = model:GetAttribute("LandingPhase") or "NONE"
	local touchdown = landingPhase == "MAIN_GEAR" and cache.LastLandingPhase ~= "MAIN_GEAR"
	local hardTouchdown = touchdown
		and touchdownLoad >= config.Thresholds.TireSmokeMinLoad
		and speed >= config.Thresholds.TireSmokeMinSpeed
		and clock - cache.LastSmokeClock >= config.Thresholds.TireSmokeCooldown
	local smokeBurst = 0
	if hardTouchdown then
		local normalizedLoad = math.clamp((touchdownLoad - config.Thresholds.TireSmokeMinLoad) / 0.30, 0, 1)
		local totalBurst = math.floor(5 + normalizedLoad * (config.Rates.TireSmokeMaximumBurst - 5))
		smokeBurst = math.max(1, math.floor(totalBurst / math.max(1, cache.SmokeEmitterCount)))
		cache.LastSmokeClock = clock
	end

	for _, emitter in ipairs(cache.Emitters) do
		local effectType = emitter:GetAttribute("AircraftEffectType")
		if effectType == "VORTEX" then
			local allowed = effectAllowed(config, "Vortex", distance, quality)
			emitter.Enabled = allowed and humidity >= config.Thresholds.VortexHumidity and not onGround
				and flaps >= config.Thresholds.VortexMinFlaps and speed >= config.Thresholds.VortexMinSpeed
				and altitude <= config.Thresholds.VortexMaxAltitude
			emitter.Rate = config.Rates.Vortex
		elseif effectType == "CONTRAIL" then
			local allowed = effectAllowed(config, "Contrail", distance, quality)
			emitter.Enabled = allowed and engine and enginePower >= config.Thresholds.ContrailMinPower
				and altitude >= config.Thresholds.ContrailMinAltitude and speed >= config.Thresholds.ContrailMinSpeed
			emitter.Rate = config.Rates.Contrail
		elseif effectType == "ENGINE_EXHAUST" or effectType == "HEAT_HAZE" then
			local allowed = effectAllowed(config, "Exhaust", distance, quality)
			emitter.Enabled = allowed and engine and enginePower >= config.Thresholds.ExhaustMinPower
			emitter.Rate = math.clamp(config.Rates.ExhaustBase + enginePower * config.Rates.ExhaustPowerScale, 0, 13)
		elseif effectType == "SPRAY" then
			local allowed = effectAllowed(config, "Spray", distance, quality)
			emitter.Enabled = allowed and onGround and wetness >= config.Thresholds.SprayMinWetness and speed >= config.Thresholds.SprayMinSpeed
			emitter.Rate = math.clamp((speed - config.Thresholds.SprayMinSpeed) * wetness * 0.52, 0, config.Rates.SprayMaximum)
		elseif effectType == "RAIN" then
			local allowed = effectAllowed(config, "Rain", distance, quality)
			emitter.Enabled = allowed and rain > 0.06
			emitter.Rate = math.floor(config.Rates.RainBase + rain * config.Rates.RainScale)
		elseif effectType == "TIRE_SMOKE" then
			emitter.Enabled = false
			if smokeBurst > 0 and effectAllowed(config, "TireSmoke", distance, quality) then emitter:Emit(smokeBurst) end
		end
	end

	local blurAllowed = effectAllowed(config, "FanBlur", distance, quality) and engine and enginePower > 18
	local blurTarget = blurAllowed and math.clamp(0.96 - enginePower * 0.0024, 0.72, 0.94) or 1
	local blurAlpha = 1 - math.exp(-math.max(0, dt or 0) * 8)
	for _, blur in ipairs(cache.FanBlurParts) do blur.Transparency += (blurTarget - blur.Transparency) * blurAlpha end

	cache.LastLandingPhase = landingPhase
end

function AircraftEffectsController.Clear(model)
	local cache = cacheByModel[model]
	if not cache then return end
	disableCache(cache)
	for _, connection in ipairs(cache.Connections) do connection:Disconnect() end
	table.clear(cache.Connections)
	cacheByModel[model] = nil
end

return AircraftEffectsController
