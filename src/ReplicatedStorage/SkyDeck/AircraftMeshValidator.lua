--!strict

-- Non-running technical-art validator. Call Validate() manually on a newly
-- imported staging Model; this module never changes the supplied instance.

local Manifest = require(script.Parent:WaitForChild("AircraftMeshManifest"))

local Validator = {}

local function pathOf(instance: Instance): string
	local pieces = { instance.Name }
	local cursor = instance.Parent
	while cursor and cursor ~= game do
		table.insert(pieces, 1, cursor.Name)
		cursor = cursor.Parent
	end
	return table.concat(pieces, ".")
end

local function push(list, code, message, instance)
	table.insert(list, {
		Code = code,
		Message = message,
		Path = instance and pathOf(instance) or nil,
	})
end

local function findRecursive(model: Model, name: string): Instance?
	return model:FindFirstChild(name, true)
end

local function closeEnough(actual: number, expected: number, tolerance: number): boolean
	return math.abs(actual - expected) <= expected * tolerance
end

function Validator.CaptureBoundingBox(model: Model)
	local cframe, size = model:GetBoundingBox()
	return {
		CFrame = cframe,
		Size = size,
		SpanStuds = size.X,
		HeightStuds = size.Y,
		LengthStuds = size.Z,
	}
end

function Validator.Validate(model: Model, aircraftCode: string?)
	local errors = {}
	local warnings = {}
	local info = {}
	if not model or not model:IsA("Model") then
		push(errors, "NOT_MODEL", "Target must be a Model.", model)
		return { Passed = false, Errors = errors, Warnings = warnings, Info = info }
	end

	local code = aircraftCode or model:GetAttribute("AircraftCode")
	local variant = code and Manifest.Variants[code]
	if not variant then
		push(errors, "UNKNOWN_VARIANT", "Set AircraftCode to a V27 manifest code before validation.", model)
		return { Passed = false, Errors = errors, Warnings = warnings, Info = info }
	end

	if not model.PrimaryPart then
		push(errors, "MISSING_PRIMARY_PART", "PrimaryPart must be the preserved Root physics Part.", model)
	elseif model.PrimaryPart.Name ~= "Root" then
		push(errors, "WRONG_PRIMARY_PART", "PrimaryPart exists but is not named Root.", model.PrimaryPart)
	end

	for _, requiredName in ipairs(Manifest.GetRequiredObjectNames(code)) do
		if not findRecursive(model, requiredName) then
			push(errors, "MISSING_OBJECT", "Missing required object " .. requiredName .. ".", model)
		end
	end

	for _, attachmentName in ipairs(Manifest.RequiredAttachments) do
		local attachment = findRecursive(model, attachmentName)
		if not attachment or not attachment:IsA("Attachment") then
			push(errors, "MISSING_ATTACHMENT", "Missing required Attachment " .. attachmentName .. ".", model)
		end
	end
	for engineIndex = 1, variant.Engines do
		local attachmentName = string.format("ATT_Engine_%02d", engineIndex)
		local attachment = findRecursive(model, attachmentName)
		if not attachment or not attachment:IsA("Attachment") then
			push(errors, "MISSING_ATTACHMENT", "Missing required Attachment " .. attachmentName .. ".", model)
		end
	end

	local movingNames = {}
	for _, name in ipairs(Manifest.GetMovingObjectNames(code)) do movingNames[name] = true end
	local wheelCount = 0
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			local isRoot = item == model.PrimaryPart
			local isPhysics = item:GetAttribute("PhysicsPart") == true or item:GetAttribute("CollisionProxy") == true
			if item:IsA("MeshPart") and not isPhysics then
				if item.Anchored then push(errors, "ANCHORED_VISUAL", "Imported visual MeshPart must not be anchored.", item) end
				if item.CanCollide then push(errors, "VISUAL_COLLISION", "Cosmetic MeshPart must be non-collidable.", item) end
				if not item.Massless then push(errors, "VISUAL_MASS", "Cosmetic MeshPart must be Massless.", item) end
			end
			if item.Anchored and not isRoot and not isPhysics then
				push(errors, "ACCIDENTAL_ANCHOR", "Only Root or an explicitly tagged physics proxy may be anchored in staging.", item)
			end
			if movingNames[item.Name] then
				local pivot = item:FindFirstChild("PIVOT")
				if not pivot or not pivot:IsA("Attachment") then
					push(errors, "MISSING_PIVOT", "Moving object requires a child Attachment named PIVOT.", item)
				end
			end
			if string.match(item.Name, "^GEAR_" .. code .. "_Wheel_%d%d$") then
				wheelCount += 1
				local tireType = item:GetAttribute("TirePosition")
				local tireTarget = tireType == "NOSE" and variant.NoseTire or variant.MainTire
				if tireTarget and item:IsA("MeshPart") then
					local diameter = math.max(item.Size.Y, item.Size.Z)
					local width = item.Size.X
					if not closeEnough(width, tireTarget.WidthStuds, 0.08) or not closeEnough(diameter, tireTarget.DiameterStuds, 0.08) then
						push(errors, "TIRE_SIZE", string.format("Expected %s near %.2f x %.2f studs (diameter x width).", tireTarget.Marking, tireTarget.DiameterStuds, tireTarget.WidthStuds), item)
					end
				end
			end
		end
	end
	if wheelCount ~= variant.Wheels then
		push(errors, "WHEEL_COUNT", string.format("Expected %d wheel meshes; found %d.", variant.Wheels, wheelCount), model)
	end
	if variant.TireStatus ~= "VERIFIED_APPLICATION_CHART" then
		push(warnings, "TIRE_DATA_REVIEW", "Exact tire dimensions require variant maintenance-data approval: " .. variant.TireStatus .. ".", model)
	end

	local box = Validator.CaptureBoundingBox(model)
	-- Gear position can increase overall height. Span and length are strict; height
	-- receives a wider tolerance and must be checked once in both gear states.
	if not closeEnough(box.SpanStuds, variant.SpanStuds, 0.015) then
		push(errors, "SPAN_SCALE", string.format("Bounding-box span %.2f does not match %.2f studs.", box.SpanStuds, variant.SpanStuds), model)
	end
	if not closeEnough(box.LengthStuds, variant.LengthStuds, 0.015) then
		push(errors, "LENGTH_SCALE", string.format("Bounding-box length %.2f does not match %.2f studs.", box.LengthStuds, variant.LengthStuds), model)
	end
	if not closeEnough(box.HeightStuds, variant.HeightStuds, 0.05) then
		push(warnings, "HEIGHT_SCALE", string.format("Bounding-box height %.2f differs from %.2f studs; verify the measured gear state.", box.HeightStuds, variant.HeightStuds), model)
	end

	push(info, "BOUNDING_BOX", string.format("Measured X/Y/Z: %.2f / %.2f / %.2f studs.", box.Size.X, box.Size.Y, box.Size.Z), model)
	push(info, "TRIANGLE_AUDIT", "Roblox Lua cannot read triangle counts; verify every object remains below 20,000 triangles in the 3D Importer.", model)
	return {
		Passed = #errors == 0,
		AircraftCode = code,
		Errors = errors,
		Warnings = warnings,
		Info = info,
		BoundingBox = box,
	}
end

function Validator.PrintReport(report)
	local function emit(label, items)
		for _, item in ipairs(items) do
			print(string.format("[%s:%s] %s%s", label, item.Code, item.Message, item.Path and (" @ " .. item.Path) or ""))
		end
	end
	emit("ERROR", report.Errors)
	emit("WARNING", report.Warnings)
	emit("INFO", report.Info)
	print(report.Passed and "AircraftMeshValidator: PASS" or "AircraftMeshValidator: FAIL")
end

return Validator
