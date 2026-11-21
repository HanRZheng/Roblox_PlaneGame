--!nocheck

-- Keeps aircraft presentation separate from the server-authoritative flight model.
-- Parts opt into channels through attributes, so additional aircraft details can be
-- animated without adding name-based logic to the flight script.

local AircraftAnimationConfig = require(script.Parent:WaitForChild("AircraftAnimationConfig"))

local AircraftVisualController = {}

local TAU = math.pi * 2
local motorByPart = setmetatable({}, { __mode = "k" })

local function expApproach(current, target, rate, dt)
	return current + (target - current) * (1 - math.exp(-math.max(0, rate) * math.max(0, dt)))
end

local function smootherStep(value)
	local t = math.clamp(value, 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function getConfig(state)
	if state.AnimationConfig then return state.AnimationConfig end
	state.AnimationConfig = AircraftAnimationConfig.Get(state.Model:GetAttribute("AircraftCode"))
	return state.AnimationConfig
end

local function getOrCreateFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then return existing end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function isEffectAnchor(part)
	if part.Name == "LabelAnchor" or part:GetAttribute("AircraftEffectType") ~= nil then return true end
	for _, child in ipairs(part:GetDescendants()) do
		if child:IsA("Light")
			or child:IsA("ParticleEmitter")
			or child:IsA("Trail")
			or child:IsA("Beam")
			or child:IsA("Sound")
			or child:IsA("BillboardGui") then
			return true
		end
	end
	return false
end

local function isFlightSurface(part)
	return part:GetAttribute("ControlSurfaceType") ~= nil
		or part:GetAttribute("FlapPart") == true
		or part:GetAttribute("SlatPart") == true
		or part:GetAttribute("SpoilerPart") == true
		or part:GetAttribute("ReverserPart") == true
		or part:GetAttribute("WingFlexPart") == true
		or part:GetAttribute("FoldingWingtipPart") == true
end

local function isLandingGear(part)
	return part:GetAttribute("GearPart") == true
		or part:GetAttribute("GearDoorPart") == true
end

local function configureCosmeticPart(part)
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	if part:GetAttribute("CollisionProxy") ~= true and not part:IsA("Seat") and not part:IsA("VehicleSeat") then
		part.CanQuery = false
	end
end

local function weldStaticPart(part, root, weldName)
	configureCosmeticPart(part)
	local weld = part:FindFirstChild(weldName)
	if not weld or not weld:IsA("WeldConstraint") then
		weld = Instance.new("WeldConstraint")
		weld.Name = weldName
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	part.Anchored = false
end

local function motorizeVisualPart(part, root)
	configureCosmeticPart(part)
	part.Anchored = false
	local motor = part:FindFirstChild("VisualMotor")
	if not motor or not motor:IsA("Motor6D") then
		motor = Instance.new("Motor6D")
		motor.Name = "VisualMotor"
		motor.Part0 = root
		motor.Part1 = part
		motor.C0 = root.CFrame:ToObjectSpace(part.CFrame)
		motor.C1 = CFrame.identity
		motor.Parent = part
	end
	part:SetAttribute("VisualMotorBaseC0", motor.C0)
	motorByPart[part] = motor
	return motor
end

function AircraftVisualController.Organize(model, root)
	local visual = getOrCreateFolder(model, "Visual")
	local controls = getOrCreateFolder(model, "Controls")
	local collision = getOrCreateFolder(model, "Collision")
	local effects = getOrCreateFolder(model, "Effects")
	local interior = getOrCreateFolder(model, "Interior")
	local flightSurfaces = getOrCreateFolder(controls, "FlightSurfaces")
	local engineFans = getOrCreateFolder(controls, "EngineFans")
	local systems = getOrCreateFolder(controls, "Systems")

	local landingGear = model:FindFirstChild("LandingGear")
	if not landingGear or not landingGear:IsA("Folder") then
		landingGear = getOrCreateFolder(controls, "LandingGear")
	else
		landingGear.Parent = controls
	end

	local parts = {}
	local animatedMotorCount = 0
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then table.insert(parts, item) end
	end

	for _, part in ipairs(parts) do
		if part == root then
			continue
		elseif part:GetAttribute("CollisionProxy") == true then
			part.Parent = collision
			part.Transparency = 1
			part.CastShadow = false
			weldStaticPart(part, root, "CollisionProxyWeld")
		elseif isLandingGear(part) then
			part.Parent = landingGear
			motorizeVisualPart(part, root)
			animatedMotorCount += 1
		elseif isFlightSurface(part) then
			part.Parent = flightSurfaces
			motorizeVisualPart(part, root)
			animatedMotorCount += 1
		elseif part:GetAttribute("FanBladePart") == true then
			part.Parent = engineFans
			motorizeVisualPart(part, root)
			animatedMotorCount += 1
		elseif part:IsA("Seat") or part:IsA("VehicleSeat") or part:GetAttribute("AircraftEntryAnchor") == true then
			part.Parent = interior
			weldStaticPart(part, root, "StaticInteriorWeld")
		elseif isEffectAnchor(part) then
			part.Parent = effects
			weldStaticPart(part, root, "StaticEffectWeld")
		else
			part.Parent = visual
			weldStaticPart(part, root, "StaticVisualWeld")
		end
	end

	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	model.PrimaryPart = root
	model:SetAttribute("AircraftHierarchyVersion", 3)
	model:SetAttribute("VisualArchitectureRevision", 31)
	model:SetAttribute("ClientVisualAuthorityRevision", 31)
	model:SetAttribute("GearAnimationRevision", 31)
	model:SetAttribute("AnimatedMotorCount", animatedMotorCount)
	model:SetAttribute("CollisionMode", "ScriptedQueries")

	return {
		Root = root,
		Visual = visual,
		Controls = controls,
		Collision = collision,
		Effects = effects,
		Interior = interior,
		FlightSurfaces = flightSurfaces,
		LandingGear = landingGear,
		EngineFans = engineFans,
		Systems = systems,
	}
end

function AircraftVisualController.BuildCache(model)
	local cache = {
		GearParts = {},
		GearDoors = {},
		Flaps = {},
		Slats = {},
		Spoilers = {},
		Rudder = {},
		Elevators = {},
		Ailerons = {},
		Wheels = {},
		EngineFans = {},
		Reversers = {},
		WingFlex = {},
		EngineSounds = {},
	}

	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("Sound") then
			table.insert(cache.EngineSounds, item)
			continue
		end
		if not item:IsA("BasePart") then continue end
		local motor = item:FindFirstChild("VisualMotor")
		if motor and motor:IsA("Motor6D") then motorByPart[item] = motor end
		if item:GetAttribute("GearPart") == true then table.insert(cache.GearParts, item) end
		if item:GetAttribute("GearDoorPart") == true then table.insert(cache.GearDoors, item) end
		if item:GetAttribute("WheelPart") == true then table.insert(cache.Wheels, item) end
		if item:GetAttribute("FlapPart") == true then table.insert(cache.Flaps, item) end
		if item:GetAttribute("SlatPart") == true then table.insert(cache.Slats, item) end
		if item:GetAttribute("SpoilerPart") == true then table.insert(cache.Spoilers, item) end
		if item:GetAttribute("FanBladePart") == true then table.insert(cache.EngineFans, item) end
		if item:GetAttribute("ReverserPart") == true then table.insert(cache.Reversers, item) end
		if item:GetAttribute("WingFlexPart") == true or item:GetAttribute("FoldingWingtipPart") == true then
			table.insert(cache.WingFlex, item)
		end

		local surfaceType = item:GetAttribute("ControlSurfaceType")
		if surfaceType == "RUDDER" then
			table.insert(cache.Rudder, item)
		elseif surfaceType == "ELEVATOR" then
			table.insert(cache.Elevators, item)
		elseif surfaceType == "AILERON" then
			table.insert(cache.Ailerons, item)
		end
	end

	return cache
end

local function setLocalPose(state, item, localPose)
	local motor = motorByPart[item]
	local baseC0 = item:GetAttribute("VisualMotorBaseC0")
	if motor and motor.Parent and typeof(baseC0) == "CFrame" then
		motor.Transform = baseC0:ToObjectSpace(localPose)
	else
		item.CFrame = state.Model:GetPivot() * localPose
	end
end

local function wingFlexiblePose(state, item, baseLocalCF)
	local config = getConfig(state)
	local flexProgress = state.WingFlexProgress or 0
	local foldProgress = state.WingtipFoldProgress or 0
	local maxHeight = math.max(0.5, (state.Model:GetAttribute("FuselageDiameter") or 12) * 0.42)
	local factor = item:GetAttribute("WingFlexFactor") or 0
	local direction = item:GetAttribute("WingFlexDirection") or 1
	local localPose = baseLocalCF
		* CFrame.new(0, maxHeight * factor * flexProgress, 0)
		* CFrame.Angles(0, 0, direction * math.rad(config.Angles.WingFlex * factor * flexProgress))
	if item:GetAttribute("FoldingWingtipPart") == true then
		local foldPivotCF = item:GetAttribute("FoldPivotCF")
		local foldDirection = item:GetAttribute("FoldDirection") or direction
		if typeof(foldPivotCF) == "CFrame" then
			localPose = foldPivotCF
				* CFrame.Angles(0, 0, -foldDirection * math.rad(config.Angles.WingtipFold * foldProgress))
				* foldPivotCF:ToObjectSpace(localPose)
		end
	end
	return localPose
end

local function rotateAroundHinge(localPose, item, rotation)
	local hingeOffset = item:GetAttribute("HingeOffset")
	if typeof(hingeOffset) ~= "Vector3" then return localPose * rotation end
	return localPose * CFrame.new(hingeOffset) * rotation * CFrame.new(-hingeOffset)
end

local function applyWingFlex(state)
	for _, item in ipairs(state.AnimationParts.WingFlex) do
		local baseLocalCF = item:GetAttribute("BaseLocalCF")
		if typeof(baseLocalCF) ~= "CFrame" then continue end
		setLocalPose(state, item, wingFlexiblePose(state, item, baseLocalCF))
	end
end

local function applyEngineAudio(state)
	local engineOn = state.Engine == true
	local power = math.clamp((state.EnginePower or 0) / 100, 0, 1)
	for _, sound in ipairs(state.AnimationParts.EngineSounds) do
		local slot = sound:GetAttribute("EngineSoundSlot")
		local configured = sound.SoundId ~= ""
		local targetVolume = 0
		if slot == "IDLE" then
			targetVolume = engineOn and (0.16 + (1 - power) * 0.22) or 0
			sound.PlaybackSpeed = 0.82 + power * 0.22
		elseif slot == "POWER" then
			targetVolume = engineOn and power * 0.48 or 0
			sound.PlaybackSpeed = 0.74 + power * 0.48
		elseif slot == "TAKEOFF" then
			targetVolume = engineOn and math.clamp((power - 0.68) / 0.32, 0, 1) * 0.66 or 0
			sound.PlaybackSpeed = 0.90 + power * 0.18
		elseif slot == "REVERSE" then
			local rollout = state.OnGround
				and (state.LandingPhase == "MAIN_GEAR" or state.LandingPhase == "NOSE_GEAR" or state.LandingPhase == "ROLLOUT")
			local reverseActive = engineOn and rollout and math.abs(state.Speed or 0) > 25 and (state.Throttle or 0) < 40
			targetVolume = reverseActive and 0.56 or 0
			sound.PlaybackSpeed = 0.86 + power * 0.24
		elseif slot == "SHUTDOWN" and state.LastEngineAudioState == true and not engineOn and configured then
			sound.Volume = 0.52
			sound:Play()
		end
		sound.Volume += (targetVolume - sound.Volume) * 0.12
		if configured and sound.Looped and targetVolume > 0.005 and not sound.IsPlaying then
			sound:Play()
		elseif sound.Looped and targetVolume <= 0.002 and sound.IsPlaying then
			sound:Stop()
		end
	end
	state.LastEngineAudioState = engineOn
end

function AircraftVisualController.ApplyGear(state)
	local config = getConfig(state)
	-- The state value remains linear and authoritative. Only the rendered travel
	-- is eased so the struts accelerate away from the bay and settle into their
	-- uplocks/downlocks without the old sudden drop or snap.
	local deploymentProgress = smootherStep(state.GearProgress)
	for _, item in ipairs(state.AnimationParts.GearParts) do
		local baseLocalCF = item:GetAttribute("BaseLocalCF")
		local retractedLocalCF = item:GetAttribute("RetractedLocalCF")
		if typeof(baseLocalCF) == "CFrame" and typeof(retractedLocalCF) == "CFrame" then
			local localPose = retractedLocalCF:Lerp(baseLocalCF, deploymentProgress)
			local truckPivotBaseCF = item:GetAttribute("TruckPivotBaseCF")
			local truckPivotRetractedCF = item:GetAttribute("TruckPivotRetractedCF")
			if typeof(truckPivotBaseCF) == "CFrame" and typeof(truckPivotRetractedCF) == "CFrame" then
				local truckPivot = truckPivotRetractedCF:Lerp(truckPivotBaseCF, deploymentProgress)
				local maxTilt = item:GetAttribute("TruckMaxTiltDegrees") or 0
				local tiltDirection = item:GetAttribute("TruckTiltDirection") or 1
				local tiltProgress = (state.TruckTiltProgress or 0) * state.GearProgress
				local truckTilt = CFrame.Angles(math.rad(maxTilt * tiltDirection * tiltProgress), 0, 0)
				localPose = truckPivot * truckTilt * truckPivot:ToObjectSpace(localPose)
			end
			local compressionGroup = item:GetAttribute("GearCompressionGroup")
			if compressionGroup then
				local compression = compressionGroup == "NOSE"
					and (state.NoseGearCompression or 0) or (state.GearCompression or 0)
				local compressionFactor = item:GetAttribute("GearCompressionFactor") or 1
				localPose *= CFrame.new(0, compression * compressionFactor * state.GearProgress, 0)
			end
			if item:GetAttribute("NoseSteerPart") == true then
				local steeringAngle = math.rad(math.clamp(state.GroundSteer or 0, -1, 1) * config.Angles.NoseSteer * state.GearProgress)
				localPose *= CFrame.Angles(0, steeringAngle, 0)
			end
			if item:GetAttribute("WheelPart") == true then
				local direction = item:GetAttribute("WheelDirection") or 1
				localPose *= CFrame.Angles((state.WheelRotation or 0) * direction, 0, 0)
			end
			setLocalPose(state, item, localPose)
			local extendedTransparency = item:GetAttribute("ExtendedTransparency") or 0
			item.Transparency = state.GearProgress <= 0.015 and 1 or extendedTransparency
		end
	end

	for _, item in ipairs(state.AnimationParts.GearDoors) do
		local closedLocalCF = item:GetAttribute("ClosedLocalCF")
		local openLocalCF = item:GetAttribute("OpenLocalCF")
		if typeof(closedLocalCF) == "CFrame" and typeof(openLocalCF) == "CFrame" then
			local doorProgress = state.GearDoorProgress
			if doorProgress == nil then
				local offset = item:GetAttribute("DoorSequenceOffset") or 0
				local doorPhase = math.clamp((state.GearProgress - offset) / math.max(0.05, 1 - offset), 0, 1)
				doorProgress = math.sin(math.pi * doorPhase) ^ 0.78
			end
			setLocalPose(state, item, closedLocalCF:Lerp(openLocalCF, doorProgress))
		end
	end
end

function AircraftVisualController.SetGear(state, visible, immediate)
	state.Gear = visible
	if immediate then state.GearProgress = visible and 1 or 0 end
	state.GearMoving = math.abs(state.GearProgress - (visible and 1 or 0)) > 0.001
	AircraftVisualController.ApplyGear(state)
end

function AircraftVisualController.ApplyFlaps(state)
	local config = getConfig(state)
	local ratio = math.clamp(state.FlapPosition / 3, 0, 1)
	for _, item in ipairs(state.AnimationParts.Flaps) do
		local baseLocalCF = item:GetAttribute("BaseLocalCF")
		local travel = item:GetAttribute("FlapTravel")
		local maxAngle = config.Angles.Flaps or item:GetAttribute("FlapMaxAngle") or 18
		if typeof(baseLocalCF) == "CFrame" and typeof(travel) == "Vector3" then
			local amount = ratio * config.Inversion.Flaps
			local localPose = wingFlexiblePose(state, item, baseLocalCF) * CFrame.new(travel * amount * config.TravelScale.Flaps)
			setLocalPose(state, item, rotateAroundHinge(localPose, item, CFrame.Angles(math.rad(maxAngle * amount), 0, 0)))
		end
	end

	for _, item in ipairs(state.AnimationParts.Slats) do
		local baseLocalCF = item:GetAttribute("BaseLocalCF")
		local travel = item:GetAttribute("SlatTravel")
		if typeof(baseLocalCF) == "CFrame" and typeof(travel) == "Vector3" then
			local amount = ratio * config.Inversion.Slats * config.TravelScale.Slats
			setLocalPose(state, item, wingFlexiblePose(state, item, baseLocalCF) * CFrame.new(travel * amount))
		end
	end
end

function AircraftVisualController.SetFlaps(state, level, immediate)
	state.Flaps = level
	if immediate then state.FlapPosition = level end
	state.FlapsMoving = math.abs(state.FlapPosition - level) > 0.001
	AircraftVisualController.ApplyFlaps(state)
end

local function applyControlSurfaceList(state, parts, control, onGround, groundSteer)
	local config = getConfig(state)
	for _, item in ipairs(parts) do
		local baseLocalCF = item:GetAttribute("BaseLocalCF")
		if typeof(baseLocalCF) ~= "CFrame" then continue end
		local surfaceType = item:GetAttribute("ControlSurfaceType")
		local direction = item:GetAttribute("ControlDirection") or 1
		local configKey = surfaceType == "RUDDER" and "Rudder" or (surfaceType == "ELEVATOR" and "Elevator" or "Aileron")
		local maxAngle = config.Angles[configKey] or item:GetAttribute("ControlMaxAngle") or 15
		local inversion = config.Inversion[configKey] or 1
		local amount = control
		if surfaceType == "RUDDER" then
			amount = onGround and groundSteer or control * 0.22
			setLocalPose(state, item, rotateAroundHinge(baseLocalCF, item, CFrame.Angles(0, math.rad(amount * maxAngle * direction * inversion), 0)))
		else
			local localPose = wingFlexiblePose(state, item, baseLocalCF)
			setLocalPose(state, item, rotateAroundHinge(localPose, item, CFrame.Angles(math.rad(amount * maxAngle * direction * inversion), 0, 0)))
		end
	end
end

local function applyVisualGeometry(state, includeAudio)
	local config = getConfig(state)
	AircraftVisualController.ApplyGear(state)
	AircraftVisualController.ApplyFlaps(state)
	applyWingFlex(state)
	if includeAudio then applyEngineAudio(state) end
	applyControlSurfaceList(state, state.AnimationParts.Ailerons, state.Controls.Roll, state.OnGround, state.GroundSteer)
	applyControlSurfaceList(state, state.AnimationParts.Elevators, state.Controls.Pitch, state.OnGround, state.GroundSteer)
	applyControlSurfaceList(state, state.AnimationParts.Rudder, state.Controls.Roll, state.OnGround, state.GroundSteer)

	for _, item in ipairs(state.AnimationParts.Spoilers) do
		local baseLocalCF = item:GetAttribute("BaseLocalCF")
		if typeof(baseLocalCF) == "CFrame" then
			local direction = item:GetAttribute("SpoilerDirection") or 1
			local rollSpoiler = not state.OnGround and math.max(0, (state.Controls.Roll or 0) * direction) * 0.48 or 0
			local amount = math.clamp(math.max(state.SpoilerProgress or 0, state.SpeedBrakeProgress or 0, rollSpoiler), 0, 1)
			local localPose = wingFlexiblePose(state, item, baseLocalCF)
			local maxAngle = config.Angles.Spoilers or item:GetAttribute("SpoilerMaxAngle") or 40
			setLocalPose(state, item, rotateAroundHinge(localPose, item, CFrame.Angles(math.rad(-maxAngle * amount * config.Inversion.Spoilers), 0, 0)))
		end
	end
	for _, item in ipairs(state.AnimationParts.Reversers) do
		local baseLocalCF = item:GetAttribute("BaseLocalCF")
		local travel = item:GetAttribute("ReverserTravel") or 0
		if typeof(baseLocalCF) == "CFrame" then
			local amount = (state.ReverserProgress or 0) * config.Inversion.Reversers * config.TravelScale.Reversers
			setLocalPose(state, item, baseLocalCF * CFrame.new(0, 0, travel * amount))
		end
	end
	for _, item in ipairs(state.AnimationParts.EngineFans) do
		local baseLocalCF = item:GetAttribute("BaseLocalCF")
		if typeof(baseLocalCF) == "CFrame" then
			setLocalPose(state, item, baseLocalCF * CFrame.Angles(0, 0, state.FanRotation * config.Inversion.Fans))
		end
	end
end

function AircraftVisualController.Apply(state, dt, renderGeometry)
	local config = getConfig(state)
	local spoilerTarget = state.OnGround
		and state.Speed > 18
		and (state.LandingPhase == "MAIN_GEAR" or state.LandingPhase == "NOSE_GEAR" or state.LandingPhase == "ROLLOUT")
		and 1 or 0
	local spoilerRate = spoilerTarget > state.SpoilerProgress and config.Rates.SpoilerDeploy or config.Rates.SpoilerRetract
	state.SpoilerProgress += (spoilerTarget - state.SpoilerProgress) * math.clamp(dt * spoilerRate, 0, 1)
	local speedBrakeTarget = state.SpeedBrake and 1 or 0
	state.SpeedBrakeProgress = (state.SpeedBrakeProgress or 0)
		+ (speedBrakeTarget - (state.SpeedBrakeProgress or 0)) * math.clamp(dt * (speedBrakeTarget > (state.SpeedBrakeProgress or 0) and config.Rates.SpeedBrakeDeploy or config.Rates.SpeedBrakeRetract), 0, 1)
	local reverserTarget = state.Engine
		and state.OnGround
		and math.abs(state.Speed or 0) > 25
		and (state.Throttle or 0) < 40
		and (state.LandingPhase == "MAIN_GEAR" or state.LandingPhase == "NOSE_GEAR" or state.LandingPhase == "ROLLOUT")
		and 1 or 0
	state.ReverserProgress = (state.ReverserProgress or 0)
		+ (reverserTarget - (state.ReverserProgress or 0)) * math.clamp(dt * (reverserTarget > (state.ReverserProgress or 0) and config.Rates.ReverserDeploy or config.Rates.ReverserStow), 0, 1)

	local fanTarget = state.EnginePower > 0.5 and (2.2 + state.EnginePower * 0.31) or 0
	state.FanAngularVelocity += (fanTarget - state.FanAngularVelocity) * math.clamp(dt * (fanTarget > state.FanAngularVelocity and config.Rates.FanSpinUp or config.Rates.FanSpinDown), 0, 1)
	state.FanRotation = (state.FanRotation + state.FanAngularVelocity * dt) % TAU

	local wheelRadius = math.max(0.5, state.Model:GetAttribute("WheelRadius") or 1.5)
	local wheelTarget = state.OnGround and math.abs(state.Speed) * 0.72 / wheelRadius or 0
	local wheelRate = wheelTarget > state.WheelAngularVelocity and config.Rates.WheelSpinUp or config.Rates.WheelSpinDown
	state.WheelAngularVelocity += (wheelTarget - state.WheelAngularVelocity) * math.clamp(dt * wheelRate, 0, 1)
	state.WheelRotation = (state.WheelRotation + state.WheelAngularVelocity * dt * (state.Speed < 0 and -1 or 1)) % TAU

	local stallSpeed = state.Spec.StallSpeed or 120
	local cruiseSpeed = state.Spec.CruiseSpeed or 450
	local flexTarget = state.OnGround and math.clamp(state.Speed / math.max(1, stallSpeed) * 0.08, 0, 0.08)
		or math.clamp(0.18 + state.Speed / math.max(1, cruiseSpeed) * 0.52 + math.abs(state.VerticalVelocity or 0) * 0.018, 0, 1)
	state.WingFlexProgress = (state.WingFlexProgress or 0)
		+ (flexTarget - (state.WingFlexProgress or 0)) * math.clamp(dt * config.Rates.WingFlex, 0, 1)
	local foldTarget = state.Model:GetAttribute("FoldingTips") == true
		and state.OnGround and not state.Engine and math.abs(state.Speed) < 2 and 1 or 0
	state.WingtipFoldProgress = (state.WingtipFoldProgress or 0)
		+ (foldTarget - (state.WingtipFoldProgress or 0)) * math.clamp(dt * config.Rates.WingtipFold, 0, 1)

	-- Multi-axle bogies hang at their catalog-driven tilt in flight, then rotate
	-- smoothly onto all axles as the main gear accepts the aircraft's weight.
	local truckTiltTarget = not state.OnGround and state.GearProgress > 0.20 and 1 or 0
	local truckTiltRate = truckTiltTarget > (state.TruckTiltProgress or 0) and 1.45 or 2.2
	state.TruckTiltProgress = (state.TruckTiltProgress or 0)
		+ (truckTiltTarget - (state.TruckTiltProgress or 0)) * math.clamp(dt * truckTiltRate, 0, 1)
	local noseCompressionTarget = 0
	if state.LandingPhase == "NOSE_GEAR" then
		local settle = math.clamp((state.LandingTimer or 0) / 1.65, 0, 1)
		local smoothSettle = settle * settle * (3 - 2 * settle)
		noseCompressionTarget = (1 - smoothSettle) * 0.42
	end
	state.NoseGearCompression = (state.NoseGearCompression or 0)
		+ (noseCompressionTarget - (state.NoseGearCompression or 0)) * math.clamp(dt * 4.2, 0, 1)

	-- V31 gives the render-step controller sole ownership of cosmetic Motor6Ds.
	-- The server still advances authoritative state and audio, but no longer
	-- fights every client by replicating different C0 values on Heartbeat.
	if renderGeometry == false then
		applyEngineAudio(state)
	else
		applyVisualGeometry(state, true)
	end
end

local ClientController = {}
ClientController.__index = ClientController

local function numberAttribute(model, name, fallback)
	local value = model:GetAttribute(name)
	return if type(value) == "number" then value else fallback
end

function AircraftVisualController.CreateClient(model)
	assert(model and model:IsA("Model"), "CreateClient expects an aircraft Model")
	local config = AircraftAnimationConfig.Get(model:GetAttribute("AircraftCode"))
	local gearTarget = model:GetAttribute("Gear") ~= false
	local gearProgress = numberAttribute(model, "GearProgress", gearTarget and 1 or 0)
	local state = {
		Model = model,
		AnimationParts = AircraftVisualController.BuildCache(model),
		AnimationConfig = config,
		Spec = {
			StallSpeed = numberAttribute(model, "StallSpeed", 120),
			CruiseSpeed = numberAttribute(model, "CruiseSpeed", 450),
		},
		Controls = { Pitch = 0, Roll = 0 },
		Gear = gearTarget,
		GearProgress = gearProgress,
		GearDoorProgress = 0,
		GroundSteer = 0,
		GearCompression = 0,
		NoseGearCompression = 0,
		TruckTiltProgress = numberAttribute(model, "TruckTiltProgress", 0),
		FlapPosition = numberAttribute(model, "FlapPosition", 0),
		SpoilerProgress = 0,
		SpeedBrakeProgress = numberAttribute(model, "SpeedBrakeProgress", 0),
		ReverserProgress = 0,
		FanRotation = 0,
		FanAngularVelocity = 0,
		WheelRotation = 0,
		WheelAngularVelocity = 0,
		WingFlexProgress = 0,
		WingtipFoldProgress = model:GetAttribute("FoldingTips") == true and 1 or 0,
		OnGround = model:GetAttribute("OnGround") ~= false,
		LandingPhase = model:GetAttribute("LandingPhase") or "NONE",
		Speed = numberAttribute(model, "Speed", 0),
		Throttle = numberAttribute(model, "Throttle", 0),
		EnginePower = numberAttribute(model, "EnginePower", 0),
		Engine = model:GetAttribute("Engine") == true,
		VerticalVelocity = numberAttribute(model, "VerticalVelocity", 0),
	}

	local self = setmetatable({
		Model = model,
		State = state,
		Config = config,
		GearTarget = gearTarget,
		GearStart = gearProgress,
		GearSequenceProgress = 1,
		GearTransitioning = false,
		GearDoorStart = 0,
		Connections = {},
		Destroyed = false,
	}, ClientController)

	table.insert(self.Connections, model.Destroying:Connect(function()
		self:Destroy()
	end))
	table.insert(self.Connections, model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then self:Destroy() end
	end))
	return self
end

function ClientController:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	for _, connection in ipairs(self.Connections) do connection:Disconnect() end
	table.clear(self.Connections)
	table.clear(self.State.AnimationParts)
	self.Model = nil
end

function ClientController:Step(deltaTime)
	if self.Destroyed or not self.Model or not self.Model.Parent or not self.Model.PrimaryPart then return false end
	local dt = math.clamp(deltaTime, 0, 0.10)
	local model = self.Model
	local state = self.State
	local config = self.Config

	state.Speed = numberAttribute(model, "Speed", state.Speed)
	state.Throttle = numberAttribute(model, "Throttle", state.Throttle)
	state.EnginePower = numberAttribute(model, "EnginePower", state.EnginePower)
	state.VerticalVelocity = numberAttribute(model, "VerticalVelocity", state.VerticalVelocity)
	state.Engine = model:GetAttribute("Engine") == true
	local onGroundAttribute = model:GetAttribute("OnGround")
	if type(onGroundAttribute) == "boolean" then state.OnGround = onGroundAttribute end
	state.LandingPhase = model:GetAttribute("LandingPhase") or "NONE"
	state.Controls.Pitch = expApproach(state.Controls.Pitch, numberAttribute(model, "ControlPitch", 0), config.Rates.Control, dt)
	state.Controls.Roll = expApproach(state.Controls.Roll, numberAttribute(model, "ControlRoll", 0), config.Rates.Control, dt)
	state.GroundSteer = expApproach(state.GroundSteer, numberAttribute(model, "GroundSteer", 0), config.Rates.Control, dt)

	local flapTarget = numberAttribute(model, "FlapPosition", numberAttribute(model, "Flaps", 0))
	local flapRate = flapTarget > state.FlapPosition and config.Rates.Flaps or config.Rates.Slats
	state.FlapPosition = expApproach(state.FlapPosition, flapTarget, flapRate, dt)

	local gearTarget = model:GetAttribute("Gear") ~= false
	if gearTarget ~= self.GearTarget then
		self.GearTarget = gearTarget
		self.GearStart = state.GearProgress
		self.GearDoorStart = state.GearDoorProgress or 0
		self.GearSequenceProgress = 0
		self.GearTransitioning = true
	end
	if self.GearTransitioning then
		self.GearSequenceProgress = math.min(1, self.GearSequenceProgress + dt * config.Rates.GearSequence)
		local sequence = config.GearSequence
		local moveRatio = smootherStep((self.GearSequenceProgress - sequence.GearMoveStart) / math.max(0.01, sequence.GearMoveEnd - sequence.GearMoveStart))
		state.GearProgress = self.GearStart + ((self.GearTarget and 1 or 0) - self.GearStart) * moveRatio
		if self.GearSequenceProgress < sequence.DoorOpenEnd then
			local openRatio = smootherStep(self.GearSequenceProgress / sequence.DoorOpenEnd)
			state.GearDoorProgress = self.GearDoorStart + (1 - self.GearDoorStart) * openRatio
		elseif self.GearSequenceProgress < sequence.DoorCloseStart then
			state.GearDoorProgress = 1
		else
			state.GearDoorProgress = 1 - smootherStep((self.GearSequenceProgress - sequence.DoorCloseStart) / math.max(0.01, 1 - sequence.DoorCloseStart))
		end
		if self.GearSequenceProgress >= 1 then
			self.GearTransitioning = false
			state.GearProgress = self.GearTarget and 1 or 0
			state.GearDoorProgress = 0
		end
	else
		state.GearProgress = expApproach(state.GearProgress, numberAttribute(model, "GearProgress", gearTarget and 1 or 0), config.Rates.GearSequence * 4, dt)
		state.GearDoorProgress = 0
	end
	state.Gear = gearTarget

	local rollout = state.OnGround and state.Speed > 18
		and (state.LandingPhase == "MAIN_GEAR" or state.LandingPhase == "NOSE_GEAR" or state.LandingPhase == "ROLLOUT")
	local spoilerTarget = rollout and 1 or 0
	state.SpoilerProgress = expApproach(state.SpoilerProgress, spoilerTarget, spoilerTarget > state.SpoilerProgress and config.Rates.SpoilerDeploy or config.Rates.SpoilerRetract, dt)
	local speedBrakeTarget = model:GetAttribute("SpeedBrake") == true and 1 or 0
	state.SpeedBrakeProgress = expApproach(state.SpeedBrakeProgress, speedBrakeTarget, speedBrakeTarget > state.SpeedBrakeProgress and config.Rates.SpeedBrakeDeploy or config.Rates.SpeedBrakeRetract, dt)

	local reverseTarget = state.Engine and state.OnGround and math.abs(state.Speed) > 25 and state.Throttle < 40 and rollout and 1 or 0
	state.ReverserProgress = expApproach(state.ReverserProgress, reverseTarget, reverseTarget > state.ReverserProgress and config.Rates.ReverserDeploy or config.Rates.ReverserStow, dt)
	local fanTarget = state.EnginePower > 0.5 and (2.2 + state.EnginePower * 0.31) or 0
	state.FanAngularVelocity = expApproach(state.FanAngularVelocity, fanTarget, fanTarget > state.FanAngularVelocity and config.Rates.FanSpinUp or config.Rates.FanSpinDown, dt)
	state.FanRotation = (state.FanRotation + state.FanAngularVelocity * dt) % TAU

	local wheelRadius = math.max(0.5, model:GetAttribute("WheelRadius") or 1.5)
	local wheelTarget = state.OnGround and math.abs(state.Speed) * 0.72 / wheelRadius or 0
	state.WheelAngularVelocity = expApproach(state.WheelAngularVelocity, wheelTarget, wheelTarget > state.WheelAngularVelocity and config.Rates.WheelSpinUp or config.Rates.WheelSpinDown, dt)
	state.WheelRotation = (state.WheelRotation + state.WheelAngularVelocity * dt * (state.Speed < 0 and -1 or 1) * config.Inversion.Wheels) % TAU

	local flexTarget = state.OnGround and math.clamp(state.Speed / math.max(1, state.Spec.StallSpeed) * 0.08, 0, 0.08)
		or math.clamp(0.18 + state.Speed / math.max(1, state.Spec.CruiseSpeed) * 0.52 + math.abs(state.VerticalVelocity) * 0.018, 0, 1)
	state.WingFlexProgress = expApproach(state.WingFlexProgress, flexTarget, config.Rates.WingFlex, dt)
	local foldTarget = model:GetAttribute("FoldingTips") == true and state.OnGround and not state.Engine and math.abs(state.Speed) < 2 and 1 or 0
	state.WingtipFoldProgress = expApproach(state.WingtipFoldProgress, foldTarget, config.Rates.WingtipFold, dt)
	state.TruckTiltProgress = expApproach(state.TruckTiltProgress, numberAttribute(model, "TruckTiltProgress", state.OnGround and 0 or 1), config.Rates.Control, dt)
	state.GearCompression = expApproach(state.GearCompression, numberAttribute(model, "GearCompression", 0), config.Rates.Compression, dt)
	state.NoseGearCompression = expApproach(state.NoseGearCompression, numberAttribute(model, "NoseGearCompression", 0), config.Rates.Compression, dt)

	applyVisualGeometry(state, false)
	return true
end

return AircraftVisualController
