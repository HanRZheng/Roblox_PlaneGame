--!nocheck

-- V20 shared airport architecture. Used by both the live server generator and
-- the edit-mode Studio builder so terminal details remain identical.

local AirportInteriors = {}
local Layout = require(script.Parent:WaitForChild("AirportLayout"))

local WHITE = Color3.fromRGB(226, 232, 232)
local DARK = Color3.fromRGB(42, 51, 56)
local GLASS = Color3.fromRGB(53, 111, 137)
local FLOOR = Color3.fromRGB(186, 191, 190)
local WOOD = Color3.fromRGB(137, 101, 68)
local GREEN = Color3.fromRGB(61, 135, 75)
local YELLOW = Color3.fromRGB(247, 196, 58)
local FIRST_GATE_X = Layout.FirstGateX
local GATE_SPACING = Layout.GateSpacing

local function gateLayout(airport)
	local gateCount = airport.Gates or 3
	local lastGateX = Layout.GateX(gateCount)
	local terminalStartX, terminalEndX = Layout.TerminalBounds(airport)
	return gateCount, lastGateX, terminalStartX, terminalEndX
end

local function addSign(part, text, accent)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignDisplay"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(500, 170)
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(18, 30, 38)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = accent or Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Parent = gui
end

local function makeSeat(parent, makePart, baseCF, name, color)
	local seat = Instance.new("Seat")
	seat.Name = name .. "Seat"
	seat.Size = Vector3.new(4.2, 0.8, 4.2)
	seat.CFrame = baseCF * CFrame.new(0, 2.3, 0)
	seat.Color = color
	seat.Material = Enum.Material.Fabric
	seat.Anchored = true
	seat.CanCollide = true
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat:SetAttribute("TerminalSeat", true)
	seat.Parent = parent
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SitPrompt"
	prompt.ActionText = "Sit"
	prompt.ObjectText = "Airport Seat"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat
	makePart(parent, name .. "Back", Vector3.new(4.2, 4.4, 0.8), baseCF * CFrame.new(0, 4.2, 1.7), color, Enum.Material.Fabric)
	makePart(parent, name .. "Leg", Vector3.new(0.8, 2.2, 0.8), baseCF * CFrame.new(0, 1.1, 0), DARK, Enum.Material.Metal)
end

local function makePlant(parent, makePart, baseCF, name)
	local pot = makePart(parent, name .. "Pot", Vector3.new(4.2, 4.2, 4.2), baseCF * CFrame.new(0, 2.1, 0), Color3.fromRGB(149, 91, 62), Enum.Material.SmoothPlastic)
	pot.Shape = Enum.PartType.Cylinder
	makePart(parent, name .. "Stem", Vector3.new(0.8, 6, 0.8), baseCF * CFrame.new(0, 7, 0), Color3.fromRGB(76, 103, 60), Enum.Material.Wood)
	for leaf = 1, 5 do
		local angle = (leaf - 1) * math.pi * 0.4
		local foliage = makePart(parent, name .. "Leaf" .. leaf, Vector3.new(5.5, 3.2, 7), baseCF * CFrame.new(math.cos(angle) * 2.3, 10 + (leaf % 2), math.sin(angle) * 2.3) * CFrame.Angles(0, angle, 0), GREEN, Enum.Material.Grass, 0, false)
		foliage.Shape = Enum.PartType.Ball
	end
end

local function makeTableSet(parent, makePart, baseCF, name, seats)
	makePart(parent, name .. "Table", Vector3.new(9, 1, 9), baseCF * CFrame.new(0, 4, 0), WOOD, Enum.Material.Wood)
	makePart(parent, name .. "TableLeg", Vector3.new(1.2, 4, 1.2), baseCF * CFrame.new(0, 2, 0), DARK, Enum.Material.Metal)
	for index = 1, seats do
		local angle = (index - 1) * math.pi * 2 / seats
		makeSeat(parent, makePart, baseCF * CFrame.new(math.cos(angle) * 8, 0, math.sin(angle) * 8) * CFrame.Angles(0, -angle, 0), name .. "Chair" .. index, Color3.fromRGB(77, 105, 120))
	end
end

local function makeCounter(parent, makePart, baseCF, name, width, accent)
	makePart(parent, name .. "Base", Vector3.new(width, 5, 4), baseCF * CFrame.new(0, 2.5, 0), WHITE, Enum.Material.SmoothPlastic)
	makePart(parent, name .. "Top", Vector3.new(width + 1, 0.7, 5), baseCF * CFrame.new(0, 5.35, 0), DARK, Enum.Material.Metal)
	local screen = makePart(parent, name .. "Screen", Vector3.new(4, 3.2, 0.5), baseCF * CFrame.new(0, 7.4, 0.3), Color3.fromRGB(19, 52, 70), Enum.Material.Glass, 0.03, false)
	addSign(screen, name, accent)
end

local function makeJetbridgeV11(parent, makePart, airportCF, gateNumber, gateX)
	-- Reference-inspired bridge: hollow pivot room, overlapping telescoping
	-- corridors, an aircraft-end cab, support column, and wheel bogie. Every
	-- end remains open, so there is no invisible or solid wall in the walkway.
	local bridgeX = gateX + 15
	local floorY = 10
	local rotundaZ = 157
	makePart(parent, "JetBridgeRotundaFloor" .. gateNumber, Vector3.new(21, 1, 24), airportCF * CFrame.new(bridgeX, floorY, rotundaZ), Color3.fromRGB(131, 140, 143), Enum.Material.Metal)
	makePart(parent, "JetBridgeRotundaRoof" .. gateNumber, Vector3.new(21, 1, 24), airportCF * CFrame.new(bridgeX, floorY + 13, rotundaZ), WHITE, Enum.Material.SmoothPlastic)
	for side = -1, 1, 2 do
		makePart(parent, "JetBridgeRotundaFrame" .. gateNumber, Vector3.new(1, 13, 24), airportCF * CFrame.new(bridgeX + side * 10, floorY + 6.5, rotundaZ), Color3.fromRGB(169, 179, 182), Enum.Material.Metal)
		makePart(parent, "JetBridgeRotundaWindow" .. gateNumber, Vector3.new(0.35, 8, 19), airportCF * CFrame.new(bridgeX + side * 10.2, floorY + 7, rotundaZ), GLASS, Enum.Material.Glass, 0.14, true)
	end
	local pivot = makePart(parent, "JetBridgePivot" .. gateNumber, Vector3.new(5, 5, 5), airportCF * CFrame.new(bridgeX, 4.5, rotundaZ), Color3.fromRGB(112, 122, 126), Enum.Material.Metal)
	pivot.Shape = Enum.PartType.Cylinder

	local function tunnelSection(sectionName, width, length, centerZ, shade)
		makePart(parent, sectionName .. "Floor" .. gateNumber, Vector3.new(width, 1, length), airportCF * CFrame.new(bridgeX, floorY, centerZ), Color3.fromRGB(129, 138, 141), Enum.Material.Metal)
		makePart(parent, sectionName .. "RoofCenter" .. gateNumber, Vector3.new(width * 0.48, 1, length), airportCF * CFrame.new(bridgeX, floorY + 12.5, centerZ), WHITE, Enum.Material.SmoothPlastic)
		for side = -1, 1, 2 do
			makePart(parent, sectionName .. "RoofEdge" .. gateNumber, Vector3.new(width * 0.34, 1, length), airportCF * CFrame.new(bridgeX + side * width * 0.36, floorY + 12, centerZ) * CFrame.Angles(0, 0, side * math.rad(12)), WHITE, Enum.Material.SmoothPlastic)
			makePart(parent, sectionName .. "LowerPanel" .. gateNumber, Vector3.new(0.55, 4, length), airportCF * CFrame.new(bridgeX + side * (width / 2 - 0.25), floorY + 2.5, centerZ), shade, Enum.Material.Metal)
			makePart(parent, sectionName .. "WindowBand" .. gateNumber, Vector3.new(0.35, 6.5, length - 4), airportCF * CFrame.new(bridgeX + side * width / 2, floorY + 7.6, centerZ), GLASS, Enum.Material.Glass, 0.12, true)
		end
		for rib = 1, math.max(2, math.floor(length / 13)) do
			local z = centerZ - length / 2 + rib * length / (math.max(2, math.floor(length / 13)) + 1)
			for side = -1, 1, 2 do
				makePart(parent, sectionName .. "Rib" .. gateNumber, Vector3.new(0.8, 12, 0.8), airportCF * CFrame.new(bridgeX + side * (width / 2 - 0.4), floorY + 6.5, z), Color3.fromRGB(174, 183, 185), Enum.Material.Metal)
			end
		end
	end

	tunnelSection("JetBridgeFixedSection", 13, 54, 126, Color3.fromRGB(207, 213, 214))
	tunnelSection("JetBridgeTelescopingSection", 11, 58, 72, Color3.fromRGB(190, 198, 200))

	local cabZ = 39
	makePart(parent, "JetBridgeCabFloor" .. gateNumber, Vector3.new(19, 1, 18), airportCF * CFrame.new(bridgeX, floorY, cabZ), Color3.fromRGB(122, 132, 135), Enum.Material.Metal)
	makePart(parent, "JetBridgeCabRoof" .. gateNumber, Vector3.new(19, 1, 18), airportCF * CFrame.new(bridgeX, floorY + 13, cabZ), WHITE, Enum.Material.SmoothPlastic)
	for side = -1, 1, 2 do
		if side > 0 then
			makePart(parent, "JetBridgeCabWindow" .. gateNumber, Vector3.new(0.4, 9, 17), airportCF * CFrame.new(bridgeX + side * 9.2, floorY + 7, cabZ), GLASS, Enum.Material.Glass, 0.10, true)
		else
			-- Split the aircraft-facing wall around a real doorway. The parked
			-- plane's forward-left door meets this opening.
			makePart(parent, "JetBridgeCabWindowForward" .. gateNumber, Vector3.new(0.4, 9, 3.5), airportCF * CFrame.new(bridgeX - 9.2, floorY + 7, cabZ - 7), GLASS, Enum.Material.Glass, 0.10, true)
			makePart(parent, "JetBridgeCabWindowRear" .. gateNumber, Vector3.new(0.4, 9, 3.5), airportCF * CFrame.new(bridgeX - 9.2, floorY + 7, cabZ + 7), GLASS, Enum.Material.Glass, 0.10, true)
			makePart(parent, "JetBridgeAircraftDoorFrontFrame" .. gateNumber, Vector3.new(1, 13, 1), airportCF * CFrame.new(bridgeX - 9.2, floorY + 6.5, cabZ - 5), WHITE, Enum.Material.Metal)
			makePart(parent, "JetBridgeAircraftDoorRearFrame" .. gateNumber, Vector3.new(1, 13, 1), airportCF * CFrame.new(bridgeX - 9.2, floorY + 6.5, cabZ + 5), WHITE, Enum.Material.Metal)
			makePart(parent, "JetBridgeAircraftDoorTopFrame" .. gateNumber, Vector3.new(1, 1, 11), airportCF * CFrame.new(bridgeX - 9.2, floorY + 13, cabZ), WHITE, Enum.Material.Metal)
		end
	end
	-- The cab turntable is a visible mechanism below the passenger floor. It is
	-- non-colliding so it cannot become the "random wall" inside the bridge.
	local turntable = makePart(parent, "JetBridgeCabTurntable" .. gateNumber, Vector3.new(2.2, 20, 20), airportCF * CFrame.new(bridgeX, 4.2, cabZ) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(128, 137, 140), Enum.Material.Metal, 0, false)
	turntable.Shape = Enum.PartType.Cylinder
	makePart(parent, "JetBridgeSupportColumn" .. gateNumber, Vector3.new(3, 8, 3), airportCF * CFrame.new(bridgeX, 5.5, 78), Color3.fromRGB(116, 125, 129), Enum.Material.Metal)
	makePart(parent, "JetBridgeWheelAxle" .. gateNumber, Vector3.new(18, 2, 2), airportCF * CFrame.new(bridgeX, 2.8, 78), DARK, Enum.Material.Metal)
	for side = -1, 1, 2 do
		local wheel = makePart(parent, "JetBridgeWheel" .. gateNumber, Vector3.new(4.5, 4.5, 2), airportCF * CFrame.new(bridgeX + side * 7.5, 2.8, 78), DARK, Enum.Material.Rubber)
		wheel.Shape = Enum.PartType.Cylinder
	end
	makePart(parent, "JetBridgeDoorBumper" .. gateNumber, Vector3.new(1, 2, 11), airportCF * CFrame.new(bridgeX - 9.6, floorY + 1, cabZ), Color3.fromRGB(58, 65, 68), Enum.Material.Rubber, 0, false)
end

local function makeJetbridge(parent, makePart, airportCF, gateNumber, gateX)
	-- V24 overhead layout: terminal tunnel -> round rotunda -> 90-degree
	-- elbow -> aircraft cab -> flexible aircraft-door canopy. The telescoping
	-- sections overlap each adjoining section so there is no daylight gap.
	local aircraftCabX = gateX + 18
	local rotundaX = gateX + 70
	local elbowZ = 70
	local floorY = 10
	local rotundaDiameter = 28

	local rotundaFloor = makePart(parent, "V12RotundaFloor" .. gateNumber, Vector3.new(1, rotundaDiameter, rotundaDiameter), airportCF * CFrame.new(rotundaX, floorY, elbowZ) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(128, 138, 142), Enum.Material.Metal)
	rotundaFloor.Shape = Enum.PartType.Cylinder
	local rotundaRoof = makePart(parent, "V12RotundaRoof" .. gateNumber, Vector3.new(1, rotundaDiameter, rotundaDiameter), airportCF * CFrame.new(rotundaX, floorY + 13, elbowZ) * CFrame.Angles(0, 0, math.rad(90)), WHITE, Enum.Material.SmoothPlastic)
	rotundaRoof.Shape = Enum.PartType.Cylinder

	local function angleDistance(a, b)
		local delta = (a - b + math.pi) % (math.pi * 2) - math.pi
		return math.abs(delta)
	end
	for segment = 1, 16 do
		local angle = (segment - 1) * math.pi * 2 / 16
		local terminalOpening = angleDistance(angle, math.pi / 2) < math.rad(31)
		local elbowOpening = angleDistance(angle, math.pi) < math.rad(31)
		if not terminalOpening and not elbowOpening then
			local panelX = rotundaX + math.cos(angle) * (rotundaDiameter / 2 - 0.5)
			local panelZ = elbowZ + math.sin(angle) * (rotundaDiameter / 2 - 0.5)
			local tangentCF = airportCF * CFrame.new(panelX, floorY + 2.5, panelZ) * CFrame.Angles(0, math.pi / 2 - angle, 0)
			makePart(parent, "V12RotundaLowerPanel" .. gateNumber .. "_" .. segment, Vector3.new(5.5, 4, 0.55), tangentCF, Color3.fromRGB(186, 196, 199), Enum.Material.Metal)
			makePart(parent, "V12RotundaGlass" .. gateNumber .. "_" .. segment, Vector3.new(5.5, 7.2, 0.35), tangentCF * CFrame.new(0, 5.4, 0), GLASS, Enum.Material.Glass, 0.12, true)
		end
	end
	local pivot = makePart(parent, "V12RotundaPivot" .. gateNumber, Vector3.new(5, 10, 10), airportCF * CFrame.new(rotundaX, 4.5, elbowZ) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(105, 116, 121), Enum.Material.Metal)
	pivot.Shape = Enum.PartType.Cylinder

	local function longitudinalTunnel(name, width, length, centerZ, shade)
		makePart(parent, name .. "Floor" .. gateNumber, Vector3.new(width, 1, length), airportCF * CFrame.new(rotundaX, floorY, centerZ), Color3.fromRGB(129, 138, 141), Enum.Material.Metal)
		makePart(parent, name .. "RoofCenter" .. gateNumber, Vector3.new(width * 0.48, 1, length), airportCF * CFrame.new(rotundaX, floorY + 12.5, centerZ), WHITE, Enum.Material.SmoothPlastic)
		for side = -1, 1, 2 do
			makePart(parent, name .. "RoofEdge" .. gateNumber .. "_" .. side, Vector3.new(width * 0.34, 1, length), airportCF * CFrame.new(rotundaX + side * width * 0.36, floorY + 12, centerZ) * CFrame.Angles(0, 0, side * math.rad(12)), WHITE, Enum.Material.SmoothPlastic)
			makePart(parent, name .. "LowerPanel" .. gateNumber .. "_" .. side, Vector3.new(0.55, 4, length), airportCF * CFrame.new(rotundaX + side * (width / 2 - 0.25), floorY + 2.5, centerZ), shade, Enum.Material.Metal)
			makePart(parent, name .. "Window" .. gateNumber .. "_" .. side, Vector3.new(0.35, 6.5, length - 4), airportCF * CFrame.new(rotundaX + side * width / 2, floorY + 7.6, centerZ), GLASS, Enum.Material.Glass, 0.12, true)
		end
		local ribCount = math.max(2, math.floor(length / 13))
		for rib = 1, ribCount do
			local z = centerZ - length / 2 + rib * length / (ribCount + 1)
			for side = -1, 1, 2 do
				makePart(parent, name .. "Rib" .. gateNumber .. "_" .. side .. "_" .. rib, Vector3.new(0.8, 12, 0.8), airportCF * CFrame.new(rotundaX + side * (width / 2 - 0.4), floorY + 6.5, z), Color3.fromRGB(174, 183, 185), Enum.Material.Metal)
			end
		end
	end

	local function lateralTunnel(name, width, length, centerX, shade)
		makePart(parent, name .. "Floor" .. gateNumber, Vector3.new(length, 1, width), airportCF * CFrame.new(centerX, floorY, elbowZ), Color3.fromRGB(129, 138, 141), Enum.Material.Metal)
		makePart(parent, name .. "RoofCenter" .. gateNumber, Vector3.new(length, 1, width * 0.48), airportCF * CFrame.new(centerX, floorY + 12.5, elbowZ), WHITE, Enum.Material.SmoothPlastic)
		for side = -1, 1, 2 do
			makePart(parent, name .. "RoofEdge" .. gateNumber .. "_" .. side, Vector3.new(length, 1, width * 0.34), airportCF * CFrame.new(centerX, floorY + 12, elbowZ + side * width * 0.36) * CFrame.Angles(side * math.rad(12), 0, 0), WHITE, Enum.Material.SmoothPlastic)
			makePart(parent, name .. "LowerPanel" .. gateNumber .. "_" .. side, Vector3.new(length, 4, 0.55), airportCF * CFrame.new(centerX, floorY + 2.5, elbowZ + side * (width / 2 - 0.25)), shade, Enum.Material.Metal)
			makePart(parent, name .. "Window" .. gateNumber .. "_" .. side, Vector3.new(length - 4, 6.5, 0.35), airportCF * CFrame.new(centerX, floorY + 7.6, elbowZ + side * width / 2), GLASS, Enum.Material.Glass, 0.12, true)
		end
		local ribCount = math.max(2, math.floor(length / 12))
		for rib = 1, ribCount do
			local x = centerX - length / 2 + rib * length / (ribCount + 1)
			for side = -1, 1, 2 do
				makePart(parent, name .. "Rib" .. gateNumber .. "_" .. side .. "_" .. rib, Vector3.new(0.8, 12, 0.8), airportCF * CFrame.new(x, floorY + 6.5, elbowZ + side * (width / 2 - 0.4)), Color3.fromRGB(174, 183, 185), Enum.Material.Metal)
			end
		end
	end

	longitudinalTunnel("V12FixedTunnel", 16, 48, 141, Color3.fromRGB(207, 213, 214))
	longitudinalTunnel("V12TelescopingTunnel", 14, 58, 103, Color3.fromRGB(188, 197, 200))
	lateralTunnel("V12ElbowTunnel", 14, rotundaX - aircraftCabX, (rotundaX + aircraftCabX) / 2, Color3.fromRGB(181, 191, 194))

	makePart(parent, "V12CabFloor" .. gateNumber, Vector3.new(20, 1, 20), airportCF * CFrame.new(aircraftCabX, floorY, elbowZ), Color3.fromRGB(122, 132, 135), Enum.Material.Metal)
	makePart(parent, "V12CabRoof" .. gateNumber, Vector3.new(20, 1, 20), airportCF * CFrame.new(aircraftCabX, floorY + 13, elbowZ), WHITE, Enum.Material.SmoothPlastic)
	for side = -1, 1, 2 do
		makePart(parent, "V12CabLowerWall" .. gateNumber .. "_" .. side, Vector3.new(19, 4, 0.55), airportCF * CFrame.new(aircraftCabX, floorY + 2.5, elbowZ + side * 9.7), Color3.fromRGB(181, 191, 194), Enum.Material.Metal)
		makePart(parent, "V12CabGlass" .. gateNumber .. "_" .. side, Vector3.new(19, 7.2, 0.35), airportCF * CFrame.new(aircraftCabX, floorY + 7.7, elbowZ + side * 9.85), GLASS, Enum.Material.Glass, 0.10, true)
	end
	for side = -1, 1, 2 do
		local prefix = side < 0 and "V12AircraftDoor" or "V12ElbowDoor"
		local doorX = aircraftCabX + side * 9.7
		makePart(parent, prefix .. "FrontFrame" .. gateNumber, Vector3.new(1, 13, 1), airportCF * CFrame.new(doorX, floorY + 6.5, elbowZ - 6), WHITE, Enum.Material.Metal)
		makePart(parent, prefix .. "RearFrame" .. gateNumber, Vector3.new(1, 13, 1), airportCF * CFrame.new(doorX, floorY + 6.5, elbowZ + 6), WHITE, Enum.Material.Metal)
		makePart(parent, prefix .. "TopFrame" .. gateNumber, Vector3.new(1, 1, 13), airportCF * CFrame.new(doorX, floorY + 13, elbowZ), WHITE, Enum.Material.Metal)
	end

	-- A real passenger boarding bridge finishes in a flexible, covered hood that
	-- seals around the aircraft doorway. The hood overlaps the cab roof and side
	-- frames, closing the overly large visual gap from the rotunda/tunnel assembly.
	local canopyOuterX = aircraftCabX - 14
	local canopyInnerX = aircraftCabX - 7.5
	local canopyLength = canopyInnerX - canopyOuterX
	local canopyCenterX = (canopyOuterX + canopyInnerX) / 2
	local canopyWidth = 15
	makePart(parent, "V24JetBridgeCanopyRoof" .. gateNumber, Vector3.new(canopyLength, 1.2, canopyWidth), airportCF * CFrame.new(canopyCenterX, floorY + 12.5, elbowZ), Color3.fromRGB(52, 58, 61), Enum.Material.Rubber)
	makePart(parent, "V24JetBridgeCanopyFloor" .. gateNumber, Vector3.new(canopyLength, 0.8, canopyWidth - 1.2), airportCF * CFrame.new(canopyCenterX, floorY, elbowZ), Color3.fromRGB(73, 80, 83), Enum.Material.Metal)
	for side = -1, 1, 2 do
		makePart(parent, "V24JetBridgeCanopySide" .. gateNumber .. "_" .. side, Vector3.new(canopyLength, 11.5, 0.8), airportCF * CFrame.new(canopyCenterX, floorY + 6.3, elbowZ + side * canopyWidth / 2), Color3.fromRGB(46, 51, 54), Enum.Material.Rubber)
	end
	for fold = 0, 7 do
		local x = canopyOuterX + fold * canopyLength / 7
		makePart(parent, "V24JetBridgeCanopyTopFold" .. gateNumber .. "_" .. fold, Vector3.new(0.55, 1.7, canopyWidth + 0.6), airportCF * CFrame.new(x, floorY + 12.6, elbowZ), Color3.fromRGB(29, 34, 36), Enum.Material.Rubber)
		for side = -1, 1, 2 do
			makePart(parent, "V24JetBridgeCanopySideFold" .. gateNumber .. "_" .. side .. "_" .. fold, Vector3.new(0.55, 11.8, 1.15), airportCF * CFrame.new(x, floorY + 6.2, elbowZ + side * canopyWidth / 2), Color3.fromRGB(29, 34, 36), Enum.Material.Rubber)
		end
	end
	makePart(parent, "V24JetBridgeCanopyBumperTop" .. gateNumber, Vector3.new(1.4, 1.4, canopyWidth + 1.4), airportCF * CFrame.new(canopyOuterX - 0.5, floorY + 12.2, elbowZ), Color3.fromRGB(25, 29, 31), Enum.Material.Rubber, 0.05, false)
	for side = -1, 1, 2 do
		makePart(parent, "V24JetBridgeCanopyBumperSide" .. gateNumber .. "_" .. side, Vector3.new(1.4, 11.6, 1.4), airportCF * CFrame.new(canopyOuterX - 0.5, floorY + 6.1, elbowZ + side * (canopyWidth + 0.7) / 2), Color3.fromRGB(25, 29, 31), Enum.Material.Rubber, 0.05, false)
	end

	makePart(parent, "V12BridgeSupport" .. gateNumber, Vector3.new(3, 8, 3), airportCF * CFrame.new(rotundaX, 5.5, 106), Color3.fromRGB(116, 125, 129), Enum.Material.Metal)
	makePart(parent, "V12WheelAxle" .. gateNumber, Vector3.new(19, 2, 2), airportCF * CFrame.new(rotundaX, 2.8, 106), DARK, Enum.Material.Metal)
	for side = -1, 1, 2 do
		local wheel = makePart(parent, "V12BridgeWheel" .. gateNumber .. "_" .. side, Vector3.new(4.5, 4.5, 2), airportCF * CFrame.new(rotundaX + side * 8, 2.8, 106), DARK, Enum.Material.Rubber)
		wheel.Shape = Enum.PartType.Cylinder
	end
	makePart(parent, "V12DoorBumper" .. gateNumber, Vector3.new(1, 2, 13), airportCF * CFrame.new(aircraftCabX - 10.1, floorY + 1, elbowZ), Color3.fromRGB(58, 65, 68), Enum.Material.Rubber, 0, false)
end

local function makeTerminalShell(parent, makePart, airportCF, airport)
	local terminal = Instance.new("Model")
	terminal.Name = "EnterableTerminal"
	terminal:SetAttribute("AirportCode", airport.Code)
	terminal.Parent = parent
	local gateCount, _, terminalStartX, terminalEndX = gateLayout(airport)
	local terminalWidth = terminalEndX - terminalStartX
	local terminalCenterX = (terminalStartX + terminalEndX) / 2
	local terminalStyle = airport.TerminalStyle or "LINEAR"
	terminal:SetAttribute("TerminalWidth", terminalWidth)
	terminal:SetAttribute("TerminalStyle", terminalStyle)
	terminal:SetAttribute("TerminalShapeRevision", 31)

	-- The foundation overlaps the island and supports the entire shell, so no
	-- terminal slab or raised gate area can appear suspended in the air.
	makePart(terminal, "TerminalFoundation", Vector3.new(terminalWidth, 1.2, 190), airportCF * CFrame.new(terminalCenterX, -0.2, 260), Color3.fromRGB(151, 158, 158), Enum.Material.Concrete)
	makePart(terminal, "TerminalFloor", Vector3.new(terminalWidth, 2, 190), airportCF * CFrame.new(terminalCenterX, 1, 260), FLOOR, Enum.Material.Marble)
	makePart(terminal, "TerminalRoof", Vector3.new(terminalWidth, 2, 190), airportCF * CFrame.new(terminalCenterX, 51, 260), WHITE, Enum.Material.Metal)
	makePart(terminal, "TerminalLeftWall", Vector3.new(2, 50, 190), airportCF * CFrame.new(terminalStartX, 26, 260), WHITE, Enum.Material.Concrete)
	makePart(terminal, "TerminalRightWall", Vector3.new(2, 50, 190), airportCF * CFrame.new(terminalEndX, 26, 260), WHITE, Enum.Material.Concrete)

	-- Keep the gate-facing concourse and every jetbridge position fixed, while
	-- giving each airport a distinct roofline and bird's-eye terminal silhouette.
	-- All additions stay over the existing foundation, clear of the apron and
	-- landside access road, so variation cannot introduce new pavement gaps.
	local function roofBlock(name, size, localCF, color, material, transparency)
		return makePart(terminal, "V31" .. name, size, airportCF * localCF, color or WHITE, material or Enum.Material.Metal, transparency or 0, false)
	end
	if terminalStyle == "DUAL_PIER" then
		for pier, ratio in ipairs({ 0.30, 0.70 }) do
			local x = terminalStartX + terminalWidth * ratio
			roofBlock("RaisedPier" .. pier, Vector3.new(math.min(120, terminalWidth * 0.12), 9, 176), CFrame.new(x, 55.5, 260), airport.Accent)
			roofBlock("PierSkylight" .. pier, Vector3.new(math.min(82, terminalWidth * 0.08), 2, 142), CFrame.new(x, 61, 260), GLASS, Enum.Material.Glass, 0.18)
		end
	elseif terminalStyle == "ROTUNDA" then
		local rotundaDiameter = math.min(164, terminalWidth * 0.72)
		local rotunda = roofBlock("CentralRotunda", Vector3.new(8, rotundaDiameter, rotundaDiameter), CFrame.new(terminalCenterX, 56, 260) * CFrame.Angles(0, 0, math.rad(90)), airport.Accent)
		rotunda.Shape = Enum.PartType.Cylinder
		local skylight = roofBlock("RotundaSkylight", Vector3.new(3, rotundaDiameter * 0.62, rotundaDiameter * 0.62), CFrame.new(terminalCenterX, 62, 260) * CFrame.Angles(0, 0, math.rad(90)), GLASS, Enum.Material.Glass, 0.18)
		skylight.Shape = Enum.PartType.Cylinder
	elseif terminalStyle == "CRESCENT" then
		local sectionWidth = terminalWidth * 0.36
		roofBlock("CrescentLeft", Vector3.new(sectionWidth, 7, 154), CFrame.new(terminalCenterX - terminalWidth * 0.24, 55, 260) * CFrame.Angles(0, math.rad(-7), 0), airport.Accent)
		roofBlock("CrescentCenter", Vector3.new(terminalWidth * 0.34, 11, 174), CFrame.new(terminalCenterX, 57, 252), WHITE)
		roofBlock("CrescentRight", Vector3.new(sectionWidth, 7, 154), CFrame.new(terminalCenterX + terminalWidth * 0.24, 55, 260) * CFrame.Angles(0, math.rad(7), 0), airport.Accent)
	elseif terminalStyle == "RIDGE" then
		roofBlock("MountainRidge", Vector3.new(terminalWidth * 0.78, 14, 48), CFrame.new(terminalCenterX, 58, 260), airport.Accent)
		roofBlock("RidgeSkylight", Vector3.new(terminalWidth * 0.62, 2, 22), CFrame.new(terminalCenterX, 66, 260), GLASS, Enum.Material.Glass, 0.18)
	elseif terminalStyle == "T_PIER" then
		roofBlock("TPierSpine", Vector3.new(math.min(130, terminalWidth * 0.16), 9, 176), CFrame.new(terminalCenterX, 55.5, 260), airport.Accent)
		roofBlock("TPierCrossbar", Vector3.new(terminalWidth * 0.62, 8, 54), CFrame.new(terminalCenterX, 55, 290), WHITE)
	elseif terminalStyle == "STEPPED" then
		for section = 1, 3 do
			local sectionWidth = terminalWidth / 3
			local x = terminalStartX + (section - 0.5) * sectionWidth
			local depth = ({ 138, 176, 150 })[section]
			local height = ({ 6, 13, 9 })[section]
			roofBlock("SteppedRoof" .. section, Vector3.new(sectionWidth - 8, height, depth), CFrame.new(x, 51 + height / 2, 260 + (section - 2) * 8), section == 2 and airport.Accent or WHITE)
		end
	elseif terminalStyle == "COMPACT" then
		roofBlock("CompactHall", Vector3.new(terminalWidth * 0.68, 10, 142), CFrame.new(terminalCenterX, 56, 266), airport.Accent)
		roofBlock("CompactSkylight", Vector3.new(terminalWidth * 0.42, 2, 92), CFrame.new(terminalCenterX, 62, 266), GLASS, Enum.Material.Glass, 0.18)
	end

	-- Landside wall segments leave real doorway gaps. The translucent door
	-- panels are intentionally non-colliding; every other glass wall is solid.
	local rearCursor = terminalStartX
	local entranceIndex = 0
	for entranceX = terminalStartX + 150, terminalEndX - 45, 380 do
		entranceIndex += 1
		local openingStart = entranceX - 28
		if openingStart > rearCursor then
			makePart(terminal, "LandsideWall" .. entranceIndex, Vector3.new(openingStart - rearCursor, 50, 2), airportCF * CFrame.new((rearCursor + openingStart) / 2, 26, 355), WHITE, Enum.Material.Concrete)
		end
		makePart(terminal, "AutomaticEntrance" .. entranceIndex, Vector3.new(54, 24, 1), airportCF * CFrame.new(entranceX, 13, 355), GLASS, Enum.Material.Glass, 0.32, false)
		local sign = makePart(terminal, "EntranceSign" .. entranceIndex, Vector3.new(38, 7, 1), airportCF * CFrame.new(entranceX, 35, 354), DARK, Enum.Material.SmoothPlastic, 0, false)
		addSign(sign, "DEPARTURES  •  ARRIVALS", airport.Accent)
		rearCursor = entranceX + 28
	end
	if rearCursor < terminalEndX then
		makePart(terminal, "LandsideWallEnd", Vector3.new(terminalEndX - rearCursor, 50, 2), airportCF * CFrame.new((rearCursor + terminalEndX) / 2, 26, 355), WHITE, Enum.Material.Concrete)
	end

	-- Raised airside concourse matches the jetbridge floor. Broad steps connect
	-- it to the main terminal floor without blocking the gate corridor.
	makePart(terminal, "GateConcourseFoundation", Vector3.new(terminalWidth, 8, 76), airportCF * CFrame.new(terminalCenterX, 4, 202), Color3.fromRGB(167, 174, 175), Enum.Material.Concrete)
	makePart(terminal, "RaisedGateConcourse", Vector3.new(terminalWidth, 2, 76), airportCF * CFrame.new(terminalCenterX, 9, 202), FLOOR, Enum.Material.Marble)
	for stairway, stairX in ipairs({ terminalStartX + 160, math.min(terminalEndX - 90, terminalStartX + 650) }) do
		if stairway == 1 or stairX > 600 then
			for step = 1, 8 do
				makePart(terminal, "ConcourseStep" .. stairway .. "_" .. step, Vector3.new(42, step, 4), airportCF * CFrame.new(stairX, 2 + step / 2, 265 - step * 4), FLOOR, Enum.Material.Marble)
			end
		end
	end

	-- Solid apron-facing curtain wall with an actual opening at every bridge.
	local glassCursor = terminalStartX
	for gate = 1, gateCount do
		local bridgeX = FIRST_GATE_X + (gate - 1) * GATE_SPACING + 70
		local openingStart = bridgeX - 12
		if openingStart > glassCursor then
			makePart(terminal, "SolidAirsideGlass" .. gate, Vector3.new(openingStart - glassCursor, 34, 1), airportCF * CFrame.new((glassCursor + openingStart) / 2, 25, 165), GLASS, Enum.Material.Glass, 0.20, true)
		end
		makePart(terminal, "GateDoorLeftFrame" .. gate, Vector3.new(1, 15, 2), airportCF * CFrame.new(openingStart, 17, 165), WHITE, Enum.Material.Metal)
		makePart(terminal, "GateDoorRightFrame" .. gate, Vector3.new(1, 15, 2), airportCF * CFrame.new(bridgeX + 12, 17, 165), WHITE, Enum.Material.Metal)
		makePart(terminal, "GateDoorTopFrame" .. gate, Vector3.new(25, 2, 2), airportCF * CFrame.new(bridgeX, 24, 165), WHITE, Enum.Material.Metal)
		glassCursor = bridgeX + 12
	end
	if glassCursor < terminalEndX then
		makePart(terminal, "SolidAirsideGlassEnd", Vector3.new(terminalEndX - glassCursor, 34, 1), airportCF * CFrame.new((glassCursor + terminalEndX) / 2, 25, 165), GLASS, Enum.Material.Glass, 0.20, true)
	end
	makePart(terminal, "TerminalFascia", Vector3.new(terminalWidth + 5, 8, 5), airportCF * CFrame.new(terminalCenterX, 46, 165), airport.Accent, Enum.Material.SmoothPlastic)
	makePart(terminal, "LandsideRoofFascia", Vector3.new(terminalWidth + 5, 7, 5), airportCF * CFrame.new(terminalCenterX, 47, 355), airport.Accent, Enum.Material.SmoothPlastic)
	-- Slender exterior columns make the long terminal read as a supported real
	-- building while remaining outside the passenger walkway and door openings.
	for columnX = terminalStartX + 55, terminalEndX - 40, 120 do
		makePart(terminal, "TerminalStructureColumn", Vector3.new(4, 49, 4), airportCF * CFrame.new(columnX, 25.5, 359), Color3.fromRGB(204, 211, 212), Enum.Material.Concrete)
	end
	return terminal
end

local function furnishTerminal(terminal, makePart, airportCF, airport)
	local gateCount, _, terminalStartX, terminalEndX = gateLayout(airport)
	local interiorShift = terminalStartX - 150
	local interiorCF = airportCF * CFrame.new(interiorShift, 0, 0)
	local interiorEndX = terminalEndX - interiorShift

	-- Check-in hall and staffed service positions.
	for desk = 1, 7 do
		makeCounter(terminal, makePart, interiorCF * CFrame.new(205 + desk * 28, 2, 325), "CheckIn" .. desk, 20, airport.Accent)
	end
	makeCounter(terminal, makePart, interiorCF * CFrame.new(640, 2, 325), "ServiceDesk", 48, airport.Accent)

	-- Full security lanes with queue rails, conveyor belts, scanners, and arches.
	for lane = 1, 3 do
		local x = 285 + lane * 70
		makePart(terminal, "SecurityConveyor" .. lane, Vector3.new(42, 4, 8), interiorCF * CFrame.new(x, 4, 289), DARK, Enum.Material.Metal)
		makePart(terminal, "XRayScanner" .. lane, Vector3.new(14, 12, 12), interiorCF * CFrame.new(x + 9, 9, 289), Color3.fromRGB(92, 110, 119), Enum.Material.Metal)
		makePart(terminal, "MetalDetectorLeft" .. lane, Vector3.new(2, 13, 2), interiorCF * CFrame.new(x - 21, 8, 284), WHITE, Enum.Material.Metal)
		makePart(terminal, "MetalDetectorRight" .. lane, Vector3.new(2, 13, 2), interiorCF * CFrame.new(x - 21, 8, 294), WHITE, Enum.Material.Metal)
		makePart(terminal, "MetalDetectorTop" .. lane, Vector3.new(2, 2, 12), interiorCF * CFrame.new(x - 21, 14.5, 289), WHITE, Enum.Material.Metal)
		for rail = -1, 1, 2 do
			makePart(terminal, "SecurityQueueRail" .. lane, Vector3.new(1, 4, 40), interiorCF * CFrame.new(x + rail * 25, 4, 290), Color3.fromRGB(95, 108, 114), Enum.Material.Metal)
		end
	end

	-- Airport-specific numbered gates, departure screens, seats, and bridges.
	for gate = 1, gateCount do
		local gateX = Layout.GateX(gate)
		local terminalDoorX = gateX + 70
		-- A dedicated concrete stand guarantees that every parked aircraft starts
		-- on paved apron, even when its real-world fuselage length is very large.
		-- The continuous apron is the visible pavement. This recessed stand base
		-- guarantees support without creating raised islands or grass seams.
		makePart(terminal, "V20GateStandBase" .. gate, Vector3.new(Layout.GateStandWidth, 0.46, Layout.GateStandLength), airportCF * CFrame.new(gateX, 0.75, Layout.GateStandCenterZ), Color3.fromRGB(108, 116, 118), Enum.Material.Concrete)
		makePart(terminal, "GateLeadIn" .. gate, Vector3.new(1.4, 0.16, 245), airportCF * CFrame.new(gateX, 1.08, -5), YELLOW, Enum.Material.Neon, 0, false)
		local gateSign = makePart(terminal, "NumberedGate" .. gate, Vector3.new(34, 11, 1), airportCF * CFrame.new(terminalDoorX, 31, 168), DARK, Enum.Material.SmoothPlastic, 0, false)
		addSign(gateSign, airport.Code .. "  GATE " .. gate, airport.Accent)
		local seatsPerGate = 4
		for seat = 1, seatsPerGate do
			makeSeat(terminal, makePart, airportCF * CFrame.new(terminalDoorX + (seat - (seatsPerGate + 1) / 2) * 10, 10, 202), "Gate" .. gate .. "Seat" .. seat, Color3.fromRGB(60, 105, 126))
		end
		if gate == 1 or gate == gateCount or gate % 4 == 0 then
			makePlant(terminal, makePart, airportCF * CFrame.new(gateX + 90, 10, 218), "GatePlant" .. gate)
		end
		makeJetbridge(terminal, makePart, airportCF, gate, gateX)
	end

	-- Lounge, cafe, restaurant, and duty-free retail areas.
	makePart(terminal, "LoungeDivider", Vector3.new(2, 18, 62), interiorCF * CFrame.new(675, 11, 245), GLASS, Enum.Material.Glass, 0.2, true)
	local loungeSign = makePart(terminal, "LoungeSign", Vector3.new(32, 8, 1), interiorCF * CFrame.new(680, 25, 214), DARK, Enum.Material.SmoothPlastic, 0, false)
	addSign(loungeSign, "AIRPORT LOUNGE", airport.Accent)
	for set = 1, 3 do makeTableSet(terminal, makePart, interiorCF * CFrame.new(640 + (set % 2) * 38, 2, 225 + set * 18), "LoungeSet" .. set, 2) end

	makeCounter(terminal, makePart, interiorCF * CFrame.new(184, 2, 250), "Cafe", 46, Color3.fromRGB(255, 203, 104))
	for set = 1, 3 do makeTableSet(terminal, makePart, interiorCF * CFrame.new(190, 2, 190 + set * 18), "CafeTable" .. set, 2) end
	makeCounter(terminal, makePart, interiorCF * CFrame.new(190, 2, 300), "Restaurant", 55, Color3.fromRGB(255, 143, 103))
	for set = 1, 3 do makeTableSet(terminal, makePart, interiorCF * CFrame.new(240 + set * 22, 2, 255), "RestaurantTable" .. set, 2) end

	local shopSign = makePart(terminal, "DutyFreeSign", Vector3.new(42, 9, 1), interiorCF * CFrame.new(585, 25, 260), DARK, Enum.Material.SmoothPlastic, 0, false)
	addSign(shopSign, "DUTY FREE", Color3.fromRGB(255, 221, 110))
	for shelf = 1, 4 do
		makePart(terminal, "DutyFreeShelf" .. shelf, Vector3.new(9, 8, 28), interiorCF * CFrame.new(535 + shelf * 24, 6, 260), WOOD, Enum.Material.Wood)
		for tier = 1, 3 do makePart(terminal, "DutyFreeDisplay" .. shelf, Vector3.new(10, 0.4, 28), interiorCF * CFrame.new(535 + shelf * 24, 2 + tier * 2.2, 260), Color3.fromRGB(235, 215, 171), Enum.Material.Wood, 0, false) end
	end

	-- Arrivals: baggage claim carousels beside the service desk.
	for belt = 1, 2 do
		local x = 280 + belt * 100
		makePart(terminal, "BaggageClaimBelt" .. belt, Vector3.new(72, 3.5, 18), interiorCF * CFrame.new(x, 4, 340), DARK, Enum.Material.Metal)
		makePart(terminal, "BaggageClaimCenter" .. belt, Vector3.new(54, 4, 8), interiorCF * CFrame.new(x, 5, 340), Color3.fromRGB(118, 131, 136), Enum.Material.Metal)
	end

	-- Two accessible restroom zones with partitions, sinks, and clear entrances.
	for room, x in ipairs({ 165, 695 }) do
		makePart(terminal, "BathroomWall" .. room, Vector3.new(48, 16, 2), interiorCF * CFrame.new(x, 10, 310), WHITE, Enum.Material.Concrete)
		for stall = 1, 3 do
			makePart(terminal, "BathroomStall" .. room, Vector3.new(1, 10, 12), interiorCF * CFrame.new(x - 20 + stall * 10, 7, 320), Color3.fromRGB(177, 190, 193), Enum.Material.SmoothPlastic)
			makePart(terminal, "BathroomFixture" .. room, Vector3.new(5, 2.5, 6), interiorCF * CFrame.new(x - 20 + stall * 10, 3.2, 326), Color3.fromRGB(235, 239, 239), Enum.Material.SmoothPlastic)
		end
		makeCounter(terminal, makePart, interiorCF * CFrame.new(x, 2, 300), "BathroomSink", 30, airport.Accent)
	end

	-- Bright ceiling fixtures throughout the public hall.
	for x = 180, interiorEndX - 30, 75 do
		for z = 185, 335, 50 do
			local lightPart = makePart(terminal, "TerminalLighting", Vector3.new(18, 0.5, 5), interiorCF * CFrame.new(x, 41.5, z), Color3.fromRGB(255, 246, 205), Enum.Material.Neon, 0, false)
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Brightness = 1.2
			light.Range = 35
			light.Angle = 120
			light.Parent = lightPart
		end
	end
end

local function buildApronTiles(parent, makePart, airportCF, airport)
	local apronStartX, apronEndX = Layout.ApronBounds(airport)
	local apronWidth = apronEndX - apronStartX
	local apronCenterX = (apronStartX + apronEndX) / 2
	local halfLength = Layout.ApronLength / 2
	local tileSize = Layout.ApronTileSize
	local seamColor = Color3.fromRGB(58, 65, 67)
	-- Large concrete slabs with moderately visible joints. V20 keeps the pattern
	-- readable while the continuous underlay prevents grass from showing through.
	for x = apronStartX + tileSize, apronEndX - 1, tileSize do
		makePart(parent, "ApronTileJointX", Vector3.new(0.72, 0.055, Layout.ApronLength - 8), airportCF * CFrame.new(x, 1.03, Layout.ApronCenterZ), seamColor, Enum.Material.SmoothPlastic, 0.42, false)
	end
	for z = Layout.ApronCenterZ - halfLength + tileSize, Layout.ApronCenterZ + halfLength - 1, tileSize do
		makePart(parent, "ApronTileJointZ", Vector3.new(apronWidth - 8, 0.055, 0.72), airportCF * CFrame.new(apronCenterX, 1.031, z), seamColor, Enum.Material.SmoothPlastic, 0.42, false)
	end
end

local function buildRoadsAndParking(parent, makePart, airportCF, airport)
	local _, _, terminalStartX, terminalEndX = gateLayout(airport)
	local roadRadius = math.min(airport.IslandRadius * Layout.RoadRadiusScale, airport.IslandRadius - Layout.SceneryShoreMargin - 100)
	local points = {}
	-- Roads remain on the landside half of each island. This avoids runway,
	-- taxiway, apron, and ocean intersections at every airport size.
	for index = 1, 7 do
		local angle = math.rad(12 + (index - 1) * 26)
		points[index] = Vector3.new(math.cos(angle) * roadRadius, 0, math.sin(angle) * roadRadius)
	end
	for index = 1, #points - 1 do
		local a = points[index]
		local b = points[index + 1]
		local center = (a + b) / 2
		local length = (b - a).Magnitude
		makePart(parent, "LandsidePerimeterRoad" .. index, Vector3.new(26, 0.8, length + 3), airportCF * CFrame.lookAt(center, b), Color3.fromRGB(54, 57, 59), Enum.Material.Asphalt)
	end
	local accessCenterX = (terminalStartX + terminalEndX) / 2
	local accessWidth = terminalEndX - terminalStartX + 140
	makePart(parent, "TerminalAccessRoad", Vector3.new(accessWidth, 0.8, 28), airportCF * CFrame.new(accessCenterX, -0.6, 405), Color3.fromRGB(54, 57, 59), Enum.Material.Asphalt)
	local connectorX = terminalStartX + 80
	local connectorEndZ = math.sqrt(math.max(0, roadRadius * roadRadius - connectorX * connectorX))
	local connectorLength = math.max(100, connectorEndZ - 405)
	makePart(parent, "AirportConnectorRoad", Vector3.new(28, 0.8, connectorLength), airportCF * CFrame.new(connectorX, -0.6, 405 + connectorLength / 2), Color3.fromRGB(54, 57, 59), Enum.Material.Asphalt)

	-- A compact landside neighborhood grid adds road density while remaining
	-- entirely beyond the protected negative-X side of the runway corridor.
	local districtCenterX = -math.min(airport.IslandRadius * 0.38, 3600)
	local districtHalfZ = math.min(roadRadius * 0.68, 2050)
	for avenue = -1, 1 do
		makePart(parent, "LandsideDistrictAvenue" .. avenue, Vector3.new(24, 0.8, districtHalfZ * 2), airportCF * CFrame.new(districtCenterX + avenue * 360, -0.58, 0), Color3.fromRGB(57, 60, 62), Enum.Material.Asphalt)
	end
	for street = -2, 2 do
		makePart(parent, "LandsideDistrictStreet" .. street, Vector3.new(1100, 0.8, 22), airportCF * CFrame.new(districtCenterX, -0.57, street * districtHalfZ / 2), Color3.fromRGB(57, 60, 62), Enum.Material.Asphalt)
	end

	local parkingX = terminalStartX + 300
	local parkingZ = 500
	makePart(parent, "AirportParkingLot", Vector3.new(560, 0.9, 130), airportCF * CFrame.new(parkingX, -0.45, parkingZ), Color3.fromRGB(66, 70, 72), Enum.Material.Asphalt)
	for row = -1, 1, 2 do
		for space = 1, 20 do
			local x = parkingX - 255 + space * 25
			makePart(parent, "ParkingSpaceLine", Vector3.new(0.5, 0.12, 19), airportCF * CFrame.new(x, 0.08, parkingZ + row * 38), Color3.fromRGB(235, 235, 224), Enum.Material.Neon, 0, false)
		end
	end
	for car = 1, 12 do
		local row = car % 2 == 0 and -1 or 1
		local x = parkingX - 235 + car * 38
		makePart(parent, "ParkedCar" .. car, Vector3.new(9, 4, 16), airportCF * CFrame.new(x, 2.5, parkingZ + row * 38), Color3.fromHSV((car * 0.11) % 1, 0.58, 0.82), Enum.Material.Metal)
		makePart(parent, "ParkedCarGlass" .. car, Vector3.new(7.5, 2.4, 7), airportCF * CFrame.new(x, 5.2, parkingZ + row * 38), GLASS, Enum.Material.Glass, 0.15, false)
	end
end

local function buildSkylineDistrict(parent, makePart, airportCF, airport)
	if airport.Code ~= "SKY" then return end

	local city = Instance.new("Model")
	city.Name = "V25 Skyline District"
	city:SetAttribute("BuildingCount", 99)
	city.Parent = parent
	local random = Random.new(20200820)
	local roadColor = Color3.fromRGB(45, 49, 54)
	local sidewalkColor = Color3.fromRGB(128, 134, 139)

	-- A regular street grid makes the high-rise cluster read as a dense city
	-- from the air while keeping every tower well clear of the runway complex.
	for column = 0, 9 do
		local x = -8500 + column * 560
		makePart(city, "CityAvenue" .. column, Vector3.new(52, 0.9, 7900), airportCF * CFrame.new(x, -0.55, 0), roadColor, Enum.Material.Asphalt)
		makePart(city, "AvenueMedian" .. column, Vector3.new(3, 0.14, 7900), airportCF * CFrame.new(x, -0.02, 0), Color3.fromRGB(238, 196, 68), Enum.Material.Neon, 0, false)
	end
	for row = 0, 11 do
		local z = -3850 + row * 700
		makePart(city, "CityStreet" .. row, Vector3.new(5200, 0.9, 48), airportCF * CFrame.new(-5980, -0.54, z), roadColor, Enum.Material.Asphalt)
	end
	makePart(city, "SkylineBoulevard", Vector3.new(84, 1.0, 8000), airportCF * CFrame.new(-5980, -0.50, 0), Color3.fromRGB(38, 43, 48), Enum.Material.Asphalt)

	local facadeColors = {
		Color3.fromRGB(73, 103, 121),
		Color3.fromRGB(86, 112, 131),
		Color3.fromRGB(104, 111, 121),
		Color3.fromRGB(62, 91, 111),
		Color3.fromRGB(119, 126, 132),
	}
	for column = 1, 9 do
		for row = 1, 11 do
			local x = -8220 + (column - 1) * 560
			local z = -3500 + (row - 1) * 700
			local centerFactor = 1 - math.clamp(Vector2.new((x + 5980) / 2700, z / 4000).Magnitude, 0, 1)
			local height = 105 + centerFactor * 320 + random:NextNumber(-18, 72)
			if (column + row * 2) % 11 == 0 then height += 115 end
			local width = random:NextNumber(205, 310)
			local depth = random:NextNumber(190, 300)
			local baseCF = airportCF * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(random:NextInteger(-4, 4)), 0)
			local facade = facadeColors[(column + row - 2) % #facadeColors + 1]

			makePart(city, "TowerPodium" .. column .. "_" .. row, Vector3.new(width + 54, 18, depth + 54), baseCF * CFrame.new(0, 8.6, 0), sidewalkColor, Enum.Material.Concrete)
			local tower = makePart(city, "SkylineTower" .. column .. "_" .. row, Vector3.new(width, height, depth), baseCF * CFrame.new(0, 18 + height / 2, 0), facade, Enum.Material.Metal)
			tower:SetAttribute("SkylineHighRise", true)
			local glassColor = Color3.fromRGB(45, 113, 151)
			makePart(city, "TowerGlassFront" .. column .. "_" .. row, Vector3.new(width * 0.86, height * 0.88, 1.2), tower.CFrame * CFrame.new(0, 0, -depth / 2 - 0.65), glassColor, Enum.Material.Glass, 0.16, false)
			makePart(city, "TowerGlassBack" .. column .. "_" .. row, Vector3.new(width * 0.86, height * 0.88, 1.2), tower.CFrame * CFrame.new(0, 0, depth / 2 + 0.65), glassColor, Enum.Material.Glass, 0.16, false)
			makePart(city, "TowerGlassLeft" .. column .. "_" .. row, Vector3.new(1.2, height * 0.88, depth * 0.82), tower.CFrame * CFrame.new(-width / 2 - 0.65, 0, 0), glassColor, Enum.Material.Glass, 0.16, false)
			makePart(city, "TowerGlassRight" .. column .. "_" .. row, Vector3.new(1.2, height * 0.88, depth * 0.82), tower.CFrame * CFrame.new(width / 2 + 0.65, 0, 0), glassColor, Enum.Material.Glass, 0.16, false)
			makePart(city, "TowerRoof" .. column .. "_" .. row, Vector3.new(width * 0.78, 8, depth * 0.78), tower.CFrame * CFrame.new(0, height / 2 + 4, 0), Color3.fromRGB(62, 68, 72), Enum.Material.Metal)

			if height > 430 then
				local mast = makePart(city, "TowerBeaconMast" .. column .. "_" .. row, Vector3.new(3, 68, 3), tower.CFrame * CFrame.new(0, height / 2 + 38, 0), Color3.fromRGB(178, 186, 190), Enum.Material.Metal)
				local beacon = makePart(city, "TowerBeacon" .. column .. "_" .. row, Vector3.new(6, 6, 6), mast.CFrame * CFrame.new(0, 37, 0), Color3.fromRGB(255, 65, 74), Enum.Material.Neon, 0, false)
				beacon.Shape = Enum.PartType.Ball
			end
		end
	end
end

function AirportInteriors.Build(parent, airportCF, airport, makePart)
	local details = Instance.new("Model")
	details.Name = "V31 Airport Facilities"
	details.Parent = parent
	buildApronTiles(details, makePart, airportCF, airport)
	local terminal = makeTerminalShell(details, makePart, airportCF, airport)
	furnishTerminal(terminal, makePart, airportCF, airport)
	buildRoadsAndParking(details, makePart, airportCF, airport)
	buildSkylineDistrict(details, makePart, airportCF, airport)
	return details
end

return AirportInteriors
