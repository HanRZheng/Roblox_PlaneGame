--!nocheck

-- Around the World
-- Around the World client: mouse flight control, simple keys, UI, free cameras, and mobile controls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera
local Shared = ReplicatedStorage:WaitForChild("SkyDeck")
local AircraftCatalog = require(Shared:WaitForChild("AircraftCatalog"))
local AirportCatalog = require(Shared:WaitForChild("AirportCatalog"))
local Layout = require(Shared:WaitForChild("AirportLayout"))
local AircraftVisualController = require(Shared:WaitForChild("AircraftVisualController"))
local AircraftEffectsController = require(Shared:WaitForChild("AircraftEffectsController"))
local AircraftLODController = require(Shared:WaitForChild("AircraftLODController"))
local Remotes = Shared:WaitForChild("Remotes")
local SpawnPlane = Remotes:WaitForChild("SpawnPlane")
local PlaneControl = Remotes:WaitForChild("PlaneControl")
local PlaneAction = Remotes:WaitForChild("PlaneAction")
local SystemMessage = Remotes:WaitForChild("SystemMessage")
local ReturnToMenu = Remotes:WaitForChild("ReturnToMenu")
local RunMode = Remotes:WaitForChild("RunMode")

local colors = {
	ink = Color3.fromRGB(244, 249, 250),
	muted = Color3.fromRGB(151, 172, 180),
	dark = Color3.fromRGB(7, 16, 24),
	panel = Color3.fromRGB(13, 27, 38),
	panel2 = Color3.fromRGB(19, 38, 52),
	cyan = Color3.fromRGB(54, 220, 245),
	lime = Color3.fromRGB(179, 255, 93),
	green = Color3.fromRGB(78, 229, 146),
	amber = Color3.fromRGB(255, 190, 80),
	red = Color3.fromRGB(255, 102, 126),
}

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(103, 138, 151)
	stroke.Transparency = transparency or 0.55
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

local function makeLabel(parent, name, text, position, size, textSize, font, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.Gotham
	label.TextColor3 = color or colors.ink
	label.TextSize = textSize or 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text, position, size, background)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Position = position
	button.Size = size
	button.AutoButtonColor = false
	button.BackgroundColor3 = background or colors.panel2
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = colors.ink
	button.TextSize = 13
	button.Parent = parent
	addCorner(button, 10)
	addStroke(button)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = button.BackgroundColor3:Lerp(Color3.new(1, 1, 1), 0.08) }):Play()
	end)
	button.MouseLeave:Connect(function()
		if button:GetAttribute("BaseColor") then
			button.BackgroundColor3 = button:GetAttribute("BaseColor")
		end
	end)
	button:SetAttribute("BaseColor", button.BackgroundColor3)
	return button
end

local oldGui = playerGui:FindFirstChild("SkyDeckUI")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "SkyDeckUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local shade = Instance.new("Frame")
shade.Name = "MenuShade"
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = colors.dark
shade.BackgroundTransparency = 0.6
shade.BorderSizePixel = 0
shade.Parent = gui

local shadeGradient = Instance.new("UIGradient")
shadeGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 13, 21)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(8, 22, 31)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 48, 61)),
})
shadeGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.02),
	NumberSequenceKeypoint.new(0.62, 0.55),
	NumberSequenceKeypoint.new(1, 0.9),
})
shadeGradient.Rotation = 0
shadeGradient.Parent = shade

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 78)
header.BackgroundColor3 = colors.dark
header.BackgroundTransparency = 0.14
header.BorderSizePixel = 0
header.Parent = gui
addStroke(header, Color3.fromRGB(114, 153, 164), 0.68)

local logoMark = Instance.new("Frame")
logoMark.Size = UDim2.fromOffset(42, 42)
logoMark.Position = UDim2.fromOffset(25, 18)
logoMark.BackgroundColor3 = colors.lime
logoMark.BorderSizePixel = 0
logoMark.Rotation = 45
logoMark.Parent = header
addCorner(logoMark, 11)
local logoInner = Instance.new("Frame")
logoInner.Size = UDim2.fromOffset(18, 18)
logoInner.AnchorPoint = Vector2.new(0.5, 0.5)
logoInner.Position = UDim2.fromScale(0.5, 0.5)
logoInner.BackgroundColor3 = colors.dark
logoInner.BorderSizePixel = 0
logoInner.Parent = logoMark
addCorner(logoInner, 5)

makeLabel(header, "Brand", "AROUND THE", UDim2.fromOffset(82, 15), UDim2.fromOffset(180, 26), 19, Enum.Font.GothamBlack)
local brandSub = makeLabel(header, "BrandSub", "WORLD", UDim2.fromOffset(83, 42), UDim2.fromOffset(180, 18), 11, Enum.Font.GothamBold, colors.muted)
brandSub.TextTransparency = 0.05

local pilotChip = Instance.new("Frame")
pilotChip.AnchorPoint = Vector2.new(1, 0.5)
pilotChip.Position = UDim2.new(1, -22, 0.5, 0)
pilotChip.Size = UDim2.fromOffset(210, 48)
pilotChip.BackgroundColor3 = colors.panel
pilotChip.BackgroundTransparency = 0.12
pilotChip.BorderSizePixel = 0
pilotChip.Parent = header
addCorner(pilotChip, 12)
addStroke(pilotChip)
local avatar = makeLabel(pilotChip, "Avatar", string.upper(string.sub(player.DisplayName, 1, 2)), UDim2.fromOffset(7, 7), UDim2.fromOffset(34, 34), 12, Enum.Font.GothamBold, colors.dark)
avatar.BackgroundTransparency = 0
avatar.BackgroundColor3 = colors.lime
avatar.TextXAlignment = Enum.TextXAlignment.Center
addCorner(avatar, 10)
makeLabel(pilotChip, "Pilot", player.DisplayName, UDim2.fromOffset(51, 6), UDim2.fromOffset(150, 20), 12, Enum.Font.GothamBold)
makeLabel(pilotChip, "Level", "PILOT LEVEL 1  •  0 XP", UDim2.fromOffset(51, 25), UDim2.fromOffset(150, 15), 9, Enum.Font.Gotham, colors.muted)

local menu = Instance.new("Frame")
menu.Name = "LaunchMenu"
menu.Position = UDim2.fromOffset(28, 96)
menu.Size = UDim2.new(0, 610, 1, -118)
menu.BackgroundTransparency = 1
menu.Parent = gui
local menuScale = Instance.new("UIScale")
menuScale.Scale = 1
menuScale.Parent = menu

local modeChip = makeLabel(menu, "Mode", "●  FREE FLIGHT", UDim2.fromOffset(2, 0), UDim2.fromOffset(180, 30), 11, Enum.Font.GothamBold, colors.lime)
modeChip.TextXAlignment = Enum.TextXAlignment.Left
local title = makeLabel(menu, "Title", "Choose it. Spawn it. Fly it.", UDim2.fromOffset(0, 34), UDim2.new(1, 0, 0, 52), 34, Enum.Font.GothamBlack)
title.TextWrapped = true
makeLabel(menu, "SubTitle", "A complete island flight world with 20 airliners and eight airports across seven islands.", UDim2.fromOffset(2, 88), UDim2.new(1, -20, 0, 42), 14, Enum.Font.Gotham, colors.muted).TextWrapped = true

local aircraftPanel = Instance.new("Frame")
aircraftPanel.Name = "AircraftPanel"
aircraftPanel.Position = UDim2.fromOffset(0, 145)
aircraftPanel.Size = UDim2.new(1, 0, 0, 248)
aircraftPanel.BackgroundColor3 = colors.panel
aircraftPanel.BackgroundTransparency = 0.07
aircraftPanel.BorderSizePixel = 0
aircraftPanel.Parent = menu
addCorner(aircraftPanel, 16)
addStroke(aircraftPanel)
makeLabel(aircraftPanel, "Heading", "01  •  SELECT AIRCRAFT", UDim2.fromOffset(18, 10), UDim2.new(1, -36, 0, 22), 10, Enum.Font.GothamBold, colors.cyan)

local selectedPlaneName = makeLabel(aircraftPanel, "SelectedName", "Airbus A320neo", UDim2.fromOffset(18, 35), UDim2.new(1, -170, 0, 30), 21, Enum.Font.GothamBold)
local selectedPlaneMeta = makeLabel(aircraftPanel, "SelectedMeta", "A20N  •  NARROW-BODY  •  2 ENGINES", UDim2.fromOffset(19, 65), UDim2.new(1, -170, 0, 18), 9, Enum.Font.GothamBold, colors.muted)
local selectedSpeed = makeLabel(aircraftPanel, "Speed", "447 KT", UDim2.new(1, -145, 0, 36), UDim2.fromOffset(126, 28), 19, Enum.Font.GothamBlack, colors.lime)
selectedSpeed.TextXAlignment = Enum.TextXAlignment.Right

local aircraftScroll = Instance.new("ScrollingFrame")
aircraftScroll.Name = "AircraftRoster"
aircraftScroll.Position = UDim2.fromOffset(14, 96)
aircraftScroll.Size = UDim2.new(1, -28, 0, 136)
aircraftScroll.BackgroundTransparency = 1
aircraftScroll.BorderSizePixel = 0
aircraftScroll.ScrollBarThickness = 5
aircraftScroll.ScrollBarImageColor3 = colors.cyan
aircraftScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
aircraftScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
aircraftScroll.Parent = aircraftPanel
local aircraftGrid = Instance.new("UIGridLayout")
aircraftGrid.CellSize = UDim2.fromOffset(134, 58)
aircraftGrid.CellPadding = UDim2.fromOffset(7, 7)
aircraftGrid.FillDirectionMaxCells = 4
aircraftGrid.SortOrder = Enum.SortOrder.LayoutOrder
aircraftGrid.Parent = aircraftScroll

local airportPanel = Instance.new("Frame")
airportPanel.Name = "AirportPanel"
airportPanel.Position = UDim2.fromOffset(0, 407)
airportPanel.Size = UDim2.new(1, 0, 0, 154)
airportPanel.BackgroundColor3 = colors.panel
airportPanel.BackgroundTransparency = 0.07
airportPanel.BorderSizePixel = 0
airportPanel.Parent = menu
addCorner(airportPanel, 16)
addStroke(airportPanel)
makeLabel(airportPanel, "Heading", "02  •  SELECT AIRPORT", UDim2.fromOffset(18, 10), UDim2.new(1, -36, 0, 22), 10, Enum.Font.GothamBold, colors.cyan)

local airportScroll = Instance.new("ScrollingFrame")
airportScroll.Name = "AirportRoster"
airportScroll.Position = UDim2.fromOffset(14, 39)
airportScroll.Size = UDim2.new(1, -28, 0, 101)
airportScroll.BackgroundTransparency = 1
airportScroll.BorderSizePixel = 0
airportScroll.ScrollBarThickness = 4
airportScroll.ScrollBarImageColor3 = colors.lime
airportScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
airportScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
airportScroll.ScrollingDirection = Enum.ScrollingDirection.X
airportScroll.Parent = airportPanel
local airportLayout = Instance.new("UIListLayout")
airportLayout.FillDirection = Enum.FillDirection.Horizontal
airportLayout.Padding = UDim.new(0, 8)
airportLayout.SortOrder = Enum.SortOrder.LayoutOrder
airportLayout.Parent = airportScroll

local spawnButton = makeButton(menu, "Spawn", "SPAWN AIRCRAFT   →", UDim2.new(0, 0, 1, -63), UDim2.new(1, 0, 0, 58), colors.lime)
spawnButton.TextColor3 = colors.dark
spawnButton.TextSize = 15
spawnButton:SetAttribute("BaseColor", colors.lime)

local selectedAircraftIndex = 3
local selectedAirportIndex = 1
local aircraftButtons = {}
local airportButtons = {}

local function updateAircraftSelection()
	local selected = AircraftCatalog.List[selectedAircraftIndex]
	selectedPlaneName.Text = selected.Name
	selectedPlaneMeta.Text = string.upper(selected.Code .. "  •  " .. selected.Class .. "  •  " .. selected.Engines .. " ENGINES")
	selectedSpeed.Text = selected.CruiseSpeed .. " KT"
	for index, button in ipairs(aircraftButtons) do
		local isSelected = index == selectedAircraftIndex
		button.BackgroundColor3 = isSelected and selected.Color or colors.panel2
		button.TextColor3 = isSelected and colors.dark or colors.ink
		button:FindFirstChildOfClass("UIStroke").Color = isSelected and selected.Color or Color3.fromRGB(103, 138, 151)
		button:SetAttribute("BaseColor", button.BackgroundColor3)
	end
end

for index, aircraft in ipairs(AircraftCatalog.List) do
	local button = makeButton(aircraftScroll, aircraft.Code, aircraft.Code .. "\n" .. string.gsub(aircraft.Name, aircraft.Maker .. " ", ""), UDim2.new(), UDim2.fromOffset(134, 58), colors.panel2)
	button.LayoutOrder = index
	button.TextSize = 10
	button.TextWrapped = true
	button.MouseButton1Click:Connect(function()
		selectedAircraftIndex = index
		updateAircraftSelection()
	end)
	table.insert(aircraftButtons, button)
end

local function updateAirportSelection()
	for index, button in ipairs(airportButtons) do
		local airport = AirportCatalog.List[index]
		local isSelected = index == selectedAirportIndex
		button.BackgroundColor3 = isSelected and airport.Accent or colors.panel2
		button.TextColor3 = isSelected and colors.dark or colors.ink
		button:FindFirstChildOfClass("UIStroke").Color = isSelected and airport.Accent or Color3.fromRGB(103, 138, 151)
		button:SetAttribute("BaseColor", button.BackgroundColor3)
	end
end

for index, airport in ipairs(AirportCatalog.List) do
	local button = makeButton(airportScroll, airport.Code, airport.Code .. "\n" .. airport.Name, UDim2.new(), UDim2.fromOffset(172, 91), colors.panel2)
	button.LayoutOrder = index
	button.TextSize = 11
	button.TextWrapped = true
	button.MouseButton1Click:Connect(function()
		selectedAirportIndex = index
		updateAirportSelection()
	end)
	table.insert(airportButtons, button)
end
updateAircraftSelection()
updateAirportSelection()

local hud = Instance.new("Frame")
hud.Name = "FlightHUD"
hud.Size = UDim2.fromScale(1, 1)
hud.BackgroundTransparency = 1
hud.Visible = false
hud.Parent = gui

local hudTop = Instance.new("Frame")
hudTop.Size = UDim2.new(1, -32, 0, 52)
hudTop.Position = UDim2.fromOffset(16, 90)
hudTop.BackgroundColor3 = colors.dark
hudTop.BackgroundTransparency = 0.18
hudTop.BorderSizePixel = 0
hudTop.Parent = hud
addCorner(hudTop, 12)
addStroke(hudTop)
local backButton = makeButton(hudTop, "Menu", "‹  MENU", UDim2.fromOffset(7, 7), UDim2.fromOffset(83, 38), colors.panel2)
local statusLabel = makeLabel(hudTop, "Status", "PARKED", UDim2.fromOffset(108, 7), UDim2.fromOffset(310, 38), 11, Enum.Font.GothamBold, colors.lime)
local nearestLabel = makeLabel(hudTop, "Nearest", "SPT AIRSPACE", UDim2.new(1, -455, 0, 7), UDim2.fromOffset(190, 38), 10, Enum.Font.GothamBold, colors.muted)
nearestLabel.TextXAlignment = Enum.TextXAlignment.Right
local cameraButton = makeButton(hudTop, "Camera", "C  •  CHASE", UDim2.new(1, -250, 0, 7), UDim2.fromOffset(114, 38), colors.panel2)
local helpButton = makeButton(hudTop, "Help", "?  HELP", UDim2.new(1, -128, 0, 7), UDim2.fromOffset(121, 38), colors.panel2)

local speedTape = Instance.new("Frame")
speedTape.Name = "SpeedTape"
speedTape.Position = UDim2.new(0, 24, 0.5, -92)
speedTape.Size = UDim2.fromOffset(104, 132)
speedTape.BackgroundColor3 = colors.dark
speedTape.BackgroundTransparency = 0.3
speedTape.BorderSizePixel = 0
speedTape.Parent = hud
addCorner(speedTape, 12)
addStroke(speedTape)
makeLabel(speedTape, "Title", "AIRSPEED", UDim2.fromOffset(10, 8), UDim2.new(1, -20, 0, 22), 9, Enum.Font.GothamBold, colors.muted)
local speedValue = makeLabel(speedTape, "Value", "0", UDim2.fromOffset(9, 35), UDim2.new(1, -18, 0, 54), 34, Enum.Font.GothamBlack, colors.ink)
speedValue.TextXAlignment = Enum.TextXAlignment.Center
local speedUnit = makeLabel(speedTape, "Unit", "KNOTS", UDim2.fromOffset(10, 93), UDim2.new(1, -20, 0, 22), 9, Enum.Font.GothamBold, colors.cyan)
speedUnit.TextXAlignment = Enum.TextXAlignment.Center

local altitudeTape = speedTape:Clone()
altitudeTape.Name = "AltitudeTape"
altitudeTape.AnchorPoint = Vector2.new(1, 0)
altitudeTape.Position = UDim2.new(1, -24, 0.5, -92)
altitudeTape.Parent = hud
altitudeTape.Title.Text = "ALTITUDE"
altitudeTape.Unit.Text = "FEET"
altitudeTape.Unit.TextColor3 = colors.lime
local altitudeValue = altitudeTape.Value

local flightCenter = Instance.new("Frame")
flightCenter.Name = "MouseControl"
flightCenter.AnchorPoint = Vector2.new(0.5, 0.5)
flightCenter.Position = UDim2.fromScale(0.5, 0.48)
flightCenter.Size = UDim2.fromOffset(220, 150)
flightCenter.BackgroundTransparency = 1
flightCenter.Parent = hud
local centerLine = makeLabel(flightCenter, "Aircraft", "—  ◆  —", UDim2.new(0.5, -65, 0.5, -18), UDim2.fromOffset(130, 36), 20, Enum.Font.GothamBold, colors.lime)
centerLine.TextXAlignment = Enum.TextXAlignment.Center
local controlHint = makeLabel(flightCenter, "Hint", "MOUSE TO FLY • RIGHT-DRAG CAMERA • SCROLL ZOOM", UDim2.new(-0.35, 0, 1, -22), UDim2.fromScale(1.7, 0), 9, Enum.Font.GothamBold, colors.muted)
controlHint.TextXAlignment = Enum.TextXAlignment.Center

local mouseReticle = Instance.new("Frame")
mouseReticle.Name = "MouseReticle"
mouseReticle.AnchorPoint = Vector2.new(0.5, 0.5)
mouseReticle.Size = UDim2.fromOffset(30, 30)
mouseReticle.BackgroundTransparency = 1
mouseReticle.Parent = hud
local ring = Instance.new("Frame")
ring.Size = UDim2.fromScale(1, 1)
ring.BackgroundTransparency = 1
ring.BorderSizePixel = 0
ring.Parent = mouseReticle
addCorner(ring, 15)
addStroke(ring, colors.cyan, 0.1, 2)
makeLabel(mouseReticle, "Dot", "•", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 22, Enum.Font.GothamBold, colors.cyan).TextXAlignment = Enum.TextXAlignment.Center

local flightData = Instance.new("Frame")
flightData.AnchorPoint = Vector2.new(0.5, 0)
flightData.Position = UDim2.new(0.5, 0, 0, 155)
flightData.Size = UDim2.fromOffset(312, 58)
flightData.BackgroundColor3 = colors.dark
flightData.BackgroundTransparency = 0.28
flightData.BorderSizePixel = 0
flightData.Parent = hud
addCorner(flightData, 12)
addStroke(flightData)
local headingValue = makeLabel(flightData, "Heading", "HDG 000°", UDim2.fromOffset(10, 0), UDim2.fromOffset(92, 58), 12, Enum.Font.GothamBold)
headingValue.TextXAlignment = Enum.TextXAlignment.Center
local vsValue = makeLabel(flightData, "VS", "V/S 0", UDim2.fromOffset(110, 0), UDim2.fromOffset(92, 58), 12, Enum.Font.GothamBold)
vsValue.TextXAlignment = Enum.TextXAlignment.Center
local throttleValue = makeLabel(flightData, "Throttle", "THR 0%", UDim2.fromOffset(210, 0), UDim2.fromOffset(92, 58), 12, Enum.Font.GothamBold, colors.lime)
throttleValue.TextXAlignment = Enum.TextXAlignment.Center

local miniMap = Instance.new("Frame")
miniMap.Name = "MiniMap"
miniMap.Position = UDim2.new(0, 22, 1, -310)
miniMap.Size = UDim2.fromOffset(250, 274)
miniMap.BackgroundColor3 = Color3.fromRGB(8, 25, 35)
miniMap.BackgroundTransparency = 0.08
miniMap.BorderSizePixel = 0
miniMap.Parent = hud
addCorner(miniMap, 16)
addStroke(miniMap, colors.cyan, 0.25, 2)
local mapTitle = makeLabel(miniMap, "Title", "WORLD MAP  •  NORTH UP", UDim2.fromOffset(12, 6), UDim2.fromOffset(145, 26), 9, Enum.Font.GothamBold, colors.cyan)
local mapHeadingValue = makeLabel(miniMap, "MapHeading", "000°  N", UDim2.new(1, -88, 0, 6), UDim2.fromOffset(76, 26), 10, Enum.Font.GothamBlack, colors.lime)
mapHeadingValue.TextXAlignment = Enum.TextXAlignment.Right

local mapViewport = Instance.new("Frame")
mapViewport.Name = "BirdsEyeWorld"
mapViewport.Position = UDim2.fromOffset(12, 36)
mapViewport.Size = UDim2.fromOffset(226, 226)
mapViewport.BackgroundColor3 = Color3.fromRGB(8, 61, 94)
mapViewport.BorderSizePixel = 0
mapViewport.ClipsDescendants = true
mapViewport:SetAttribute("MapStyleRevision", 30)
mapViewport:SetAttribute("RunwayLayoutRevision", Layout.RunwayLayoutRevision)
mapViewport:SetAttribute("ApproachAlignmentGuides", true)
mapViewport:SetAttribute("PlayerMarkerType", "TOP_DOWN_AIRCRAFT")
mapViewport.Parent = miniMap
addCorner(mapViewport, 11)
addStroke(mapViewport, Color3.fromRGB(116, 211, 238), 0.55, 1)
local oceanGradient = Instance.new("UIGradient")
oceanGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(7, 53, 85)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(11, 78, 111)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 48, 80)),
})
oceanGradient.Rotation = 35
oceanGradient.Parent = mapViewport

local MAP_RADIUS = Layout.WorldRadius
local MAP_PIXELS = 226
local MAP_PADDING = 8
local MAP_USABLE = MAP_PIXELS - MAP_PADDING * 2
-- Geographic island radii are almost edge-to-edge in a few parts of the world.
-- Render them slightly smaller than geographic scale so the sand rims never join
-- into an apparent land bridge on this compact overview.
local MAP_ISLAND_SCALE = 0.90
local MAP_WORLD_TO_PIXELS = MAP_USABLE / (MAP_RADIUS * 2)
local function mapPixelPosition(x, z)
	local xRatio = math.clamp((x + MAP_RADIUS) / (MAP_RADIUS * 2), 0, 1)
	local zRatio = math.clamp((z + MAP_RADIUS) / (MAP_RADIUS * 2), 0, 1)
	return Vector2.new(MAP_PADDING + xRatio * MAP_USABLE, MAP_PADDING + zRatio * MAP_USABLE)
end
local function mapPosition(x, z)
	local pixel = mapPixelPosition(x, z)
	return UDim2.fromOffset(pixel.X, pixel.Y)
end

local function mapLine(name, pointA, pointB, width, color, transparency, zIndex)
	local delta = pointB - pointA
	local line = Instance.new("Frame")
	line.Name = name
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromOffset((pointA.X + pointB.X) * 0.5, (pointA.Y + pointB.Y) * 0.5)
	line.Size = UDim2.fromOffset(math.max(0.5, delta.Magnitude), width)
	line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	line.BackgroundColor3 = color
	line.BackgroundTransparency = transparency or 0
	line.BorderSizePixel = 0
	line.ZIndex = zIndex or 2
	line.Parent = mapViewport
	addCorner(line, width)
	return line
end

local function mapDot(name, point, diameter, color, transparency, zIndex)
	local dot = Instance.new("Frame")
	dot.Name = name
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromOffset(point.X, point.Y)
	dot.Size = UDim2.fromOffset(diameter, diameter)
	dot.BackgroundColor3 = color
	dot.BackgroundTransparency = transparency or 0
	dot.BorderSizePixel = 0
	dot.ZIndex = zIndex or 3
	dot.Parent = mapViewport
	addCorner(dot, diameter)
	return dot
end

for grid = 1, 5 do
	local offset = MAP_PADDING + grid * MAP_USABLE / 6
	local vertical = Instance.new("Frame")
	vertical.Name = "LongitudeGrid"
	vertical.Position = UDim2.fromOffset(offset, MAP_PADDING)
	vertical.Size = UDim2.fromOffset(1, MAP_USABLE)
	vertical.BackgroundColor3 = Color3.fromRGB(3, 35, 62)
	vertical.BackgroundTransparency = 0.28
	vertical.BorderSizePixel = 0
	vertical.ZIndex = 1
	vertical.Parent = mapViewport
	local horizontal = vertical:Clone()
	horizontal.Name = "LatitudeGrid"
	horizontal.Position = UDim2.fromOffset(MAP_PADDING, offset)
	horizontal.Size = UDim2.fromOffset(MAP_USABLE, 1)
	horizontal.Parent = mapViewport
end

local terrainMapColors = {
	Green = Color3.fromRGB(79, 151, 94),
	Tropical = Color3.fromRGB(78, 178, 117),
	Alpine = Color3.fromRGB(117, 149, 128),
	Desert = Color3.fromRGB(192, 145, 87),
	Urban = Color3.fromRGB(94, 140, 105),
}
local terrainDetailColors = {
	Green = Color3.fromRGB(49, 113, 68),
	Tropical = Color3.fromRGB(35, 137, 84),
	Alpine = Color3.fromRGB(81, 112, 97),
	Desert = Color3.fromRGB(154, 107, 62),
	Urban = Color3.fromRGB(75, 102, 84),
}

local function islandMapPoint(airport, airportCF, angle, scale)
	local localPoint = Layout.IslandBoundaryLocalPoint(airport, angle, scale)
	local worldPoint = airportCF:PointToWorldSpace(Vector3.new(localPoint.X, 0, localPoint.Y))
	return mapPixelPosition(worldPoint.X, worldPoint.Z)
end

local function renderDetailedIsland(airport)
	local airportCF = CFrame.new(airport.Position) * CFrame.Angles(0, math.rad(-airport.Heading), 0)
	local center = mapPixelPosition(airport.Position.X, airport.Position.Z)
	local landColor = terrainMapColors[airport.Terrain] or terrainMapColors.Green
	local detailColor = terrainDetailColors[airport.Terrain] or terrainDetailColors.Green
	local shoreColor = Color3.fromRGB(221, 194, 126)
	local boundary = {}
	local innerBoundary = {}
	local contourBoundary = {}
	local samples = 24

	for index = 1, samples do
		local angle = (index - 1) / samples * math.pi * 2
		boundary[index] = islandMapPoint(airport, airportCF, angle, MAP_ISLAND_SCALE)
		innerBoundary[index] = islandMapPoint(airport, airportCF, angle, MAP_ISLAND_SCALE * 0.965)
		contourBoundary[index] = islandMapPoint(airport, airportCF, angle, MAP_ISLAND_SCALE * 0.62)
	end

	-- Dense rounded radial fills and matching sampled coast segments reproduce the
	-- actual generated coastline, including lobes, bays, ridges, and teardrops.
	for index = 1, samples do
		local nextIndex = index % samples + 1
		local arcWidth = math.max(5.4, (boundary[nextIndex] - boundary[index]).Magnitude * 1.18)
		mapLine(airport.Code .. "ShoreFill" .. index, center, boundary[index], arcWidth + 2.8, shoreColor, 0.02, 2)
		mapLine(airport.Code .. "LandFill" .. index, center, innerBoundary[index], arcWidth, landColor, 0, 3)
		mapLine(airport.Code .. "Shoreline" .. index, boundary[index], boundary[nextIndex], 4.0, shoreColor, 0, 2)
		mapLine(airport.Code .. "Coast" .. index, innerBoundary[index], innerBoundary[nextIndex], 2.6, landColor, 0, 3)
		mapLine(airport.Code .. "Contour" .. index, contourBoundary[index], contourBoundary[nextIndex], 0.65, detailColor, 0.36, 4)
	end

	local seed = string.byte(airport.Code, 1) * 31 + string.byte(airport.Code, 2) * 17 + string.byte(airport.Code, 3)
	for detail = 1, 18 do
		local angle = (detail * 2.399 + seed * 0.013) % (math.pi * 2)
		local ratio = 0.18 + ((detail * 37 + seed) % 61) / 100
		local point = islandMapPoint(airport, airportCF, angle, MAP_ISLAND_SCALE * ratio)
		local diameter = 1.5 + ((detail * 7 + seed) % 4) * 0.45
		local color = detail % 5 == 0 and Color3.fromRGB(176, 166, 123) or detailColor
		if airport.Terrain == "Urban" and detail % 3 == 0 then color = Color3.fromRGB(126, 135, 132) end
		mapDot(airport.Code .. "TerrainDetail" .. detail, point, diameter, color, 0.12, 4)
	end
end

for _, airport in ipairs(AirportCatalog.List) do
	if not airport.ParentIslandCode then renderDetailedIsland(airport) end

	local airportCF = CFrame.new(airport.Position) * CFrame.Angles(0, math.rad(-airport.Heading), 0)
	for runwayIndex, placement in ipairs(Layout.RunwayPlacements(airport)) do
		local runwayCF = airportCF * Layout.RunwayLocalCFrame(placement)
		local runwayHalf = airport.RunwayLength / 2
		local startWorld = runwayCF:PointToWorldSpace(Vector3.new(0, 0, -runwayHalf))
		local endWorld = runwayCF:PointToWorldSpace(Vector3.new(0, 0, runwayHalf))
		local startPoint = mapPixelPosition(startWorld.X, startWorld.Z)
		local endPoint = mapPixelPosition(endWorld.X, endWorld.Z)
		local runwayWidth = math.max(2.2, Layout.RunwayWidth * MAP_WORLD_TO_PIXELS)
		mapLine(airport.Code .. "RunwayOutline" .. runwayIndex, startPoint, endPoint, runwayWidth + 1.8, Color3.fromRGB(235, 225, 184), 0, 6)
		mapLine(airport.Code .. "Runway" .. runwayIndex, startPoint, endPoint, runwayWidth, Color3.fromRGB(39, 43, 46), 0, 7)
		mapLine(airport.Code .. "RunwayCenterline" .. runwayIndex, startPoint, endPoint, 0.55, Color3.fromRGB(247, 248, 234), 0.06, 8)

		-- Magenta dashed localizer-style guides continue the runway centerline into
		-- both approaches, making lineup readable before the runway itself is clear.
		for _, endSign in ipairs({ -1, 1 }) do
			for dash = 0, 5 do
				local innerDistance = runwayHalf + 300 + dash * 820
				local outerDistance = innerDistance + 500
				local guideStartWorld = runwayCF:PointToWorldSpace(Vector3.new(0, 0, endSign * innerDistance))
				local guideEndWorld = runwayCF:PointToWorldSpace(Vector3.new(0, 0, endSign * outerDistance))
				local guideStart = mapPixelPosition(guideStartWorld.X, guideStartWorld.Z)
				local guideEnd = mapPixelPosition(guideEndWorld.X, guideEndWorld.Z)
				mapLine(airport.Code .. "ApproachGuideShadow" .. runwayIndex .. "_" .. endSign .. "_" .. dash, guideStart, guideEnd, 2.7, Color3.fromRGB(27, 14, 39), 0.14, 5)
				mapLine(airport.Code .. "ApproachGuide" .. runwayIndex .. "_" .. endSign .. "_" .. dash, guideStart, guideEnd, 1.15, Color3.fromRGB(255, 78, 211), 0.02, 6)
			end
		end
	end

	local point = Instance.new("Frame")
	point.Name = airport.Code
	point.AnchorPoint = Vector2.new(0.5, 0.5)
	point.Size = UDim2.fromOffset(4, 4)
	point.Position = mapPosition(airport.Position.X, airport.Position.Z)
	point.BackgroundColor3 = airport.Accent
	point.BorderSizePixel = 0
	point.ZIndex = 8
	point.Parent = mapViewport
	addCorner(point, 3)
	local code = makeLabel(mapViewport, airport.Code .. "Label", airport.Code, mapPosition(airport.Position.X, airport.Position.Z), UDim2.fromOffset(34, 12), 8, Enum.Font.GothamBlack, Color3.fromRGB(242, 249, 250))
	if airport.ParentIslandCode then
		code.AnchorPoint = Vector2.new(0, 0.5)
		code.Position += UDim2.fromOffset(6, airport.Code == "SPK" and -5 or 5)
	else
		code.AnchorPoint = Vector2.new(0.5, 1)
		code.Position += UDim2.fromOffset(0, -5)
	end
	code.TextXAlignment = Enum.TextXAlignment.Center
	code.TextStrokeColor3 = Color3.fromRGB(6, 18, 24)
	code.TextStrokeTransparency = 0.15
	code.ZIndex = 9
end

makeLabel(mapViewport, "North", "N", UDim2.new(0.5, -8, 0, 1), UDim2.fromOffset(16, 16), 9, Enum.Font.GothamBlack, colors.ink).TextXAlignment = Enum.TextXAlignment.Center
makeLabel(mapViewport, "West", "W", UDim2.fromOffset(2, 104), UDim2.fromOffset(16, 16), 9, Enum.Font.GothamBlack, colors.ink).TextXAlignment = Enum.TextXAlignment.Center
makeLabel(mapViewport, "East", "E", UDim2.new(1, -18, 0, 104), UDim2.fromOffset(16, 16), 9, Enum.Font.GothamBlack, colors.ink).TextXAlignment = Enum.TextXAlignment.Center

local mapPlane = Instance.new("Frame")
mapPlane.Name = "PlayerHeadingMarker"
mapPlane.AnchorPoint = Vector2.new(0.5, 0.5)
mapPlane.Position = mapPosition(0, 0)
mapPlane.Size = UDim2.fromOffset(24, 24)
mapPlane.BackgroundTransparency = 1
mapPlane.ZIndex = 12
mapPlane.Parent = mapViewport

local planeIcon = Instance.new("Frame")
planeIcon.Name = "YellowAircraftIcon"
planeIcon.Size = UDim2.fromScale(1, 1)
planeIcon.BackgroundTransparency = 1
planeIcon.ZIndex = 13
planeIcon.Parent = mapPlane

local function planeIconPart(name, center, size, rotation, color, zIndex)
	local part = Instance.new("Frame")
	part.Name = name
	part.AnchorPoint = Vector2.new(0.5, 0.5)
	part.Position = UDim2.fromOffset(center.X, center.Y)
	part.Size = UDim2.fromOffset(size.X, size.Y)
	part.Rotation = rotation or 0
	part.BackgroundColor3 = color
	part.BorderSizePixel = 0
	part.ZIndex = zIndex
	part.Parent = planeIcon
	addCorner(part, math.min(size.X, size.Y))
	return part
end

local function makeAircraftIconLayer(prefix, inflation, color, zIndex)
	planeIconPart(prefix .. "LeftWing", Vector2.new(7.6, 11.0), Vector2.new(11.2 + inflation, 3.3 + inflation), -19, color, zIndex)
	planeIconPart(prefix .. "RightWing", Vector2.new(16.4, 11.0), Vector2.new(11.2 + inflation, 3.3 + inflation), 19, color, zIndex)
	planeIconPart(prefix .. "LeftTailplane", Vector2.new(9.4, 18.5), Vector2.new(6.2 + inflation, 2.1 + inflation), -24, color, zIndex)
	planeIconPart(prefix .. "RightTailplane", Vector2.new(14.6, 18.5), Vector2.new(6.2 + inflation, 2.1 + inflation), 24, color, zIndex)
	planeIconPart(prefix .. "Fuselage", Vector2.new(12, 11.8), Vector2.new(4.2 + inflation, 21.6 + inflation), 0, color, zIndex + 1)
end

-- Original top-down airliner silhouette based on the supplied yellow plane
-- reference. It has a fuselage, swept main wings, and a separate tailplane—no
-- arrow, Unicode character, external image, or copied game asset.
makeAircraftIconLayer("Outline", 1.7, Color3.fromRGB(8, 25, 35), 13)
makeAircraftIconLayer("Aircraft", 0, Color3.fromRGB(255, 224, 45), 15)

local compassNames = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
local function compassDirection(heading)
	return compassNames[math.floor(((heading % 360) + 22.5) / 45) % 8 + 1]
end

local actionDock = Instance.new("Frame")
actionDock.Name = "ActionDock"
actionDock.AnchorPoint = Vector2.new(0.5, 1)
actionDock.Position = UDim2.new(0.5, 0, 1, -18)
actionDock.Size = UDim2.fromOffset(920, 68)
actionDock.BackgroundColor3 = colors.dark
actionDock.BackgroundTransparency = 0.18
actionDock.BorderSizePixel = 0
actionDock.Parent = hud
actionDock.Visible = not UserInputService.TouchEnabled
addCorner(actionDock, 14)
addStroke(actionDock)
local dockLayout = Instance.new("UIListLayout")
dockLayout.FillDirection = Enum.FillDirection.Horizontal
dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
dockLayout.Padding = UDim.new(0, 6)
dockLayout.Parent = actionDock

local actionButtons = {}
local function addAction(key, label, action)
	local button = makeButton(actionDock, action, key .. "\n" .. label, UDim2.new(), UDim2.fromOffset(82, 52), colors.panel2)
	button.TextSize = 10
	button.TextWrapped = true
	button.MouseButton1Click:Connect(function()
		if action == "Camera" then
			-- handled below
		else
			PlaneAction:FireServer(action)
		end
	end)
	actionButtons[action] = button
	return button
end
addAction("E", "ENGINE", "Engine")
addAction("P", "BRAKE", "Brake")
addAction("B", "PUSHBACK", "Pushback")
addAction("G", "GEAR", "Gear")
addAction("F", "FLAPS", "Flaps")
addAction("A", "ALT HOLD", "AltitudeHold")
addAction("X", "SPEED BRAKE", "SpeedBrake")
addAction("L", "LIGHTS", "Lights")
addAction("C", "CAMERA", "Camera")
addAction("R", "RESET", "Reset")

local helpModal = Instance.new("Frame")
helpModal.Name = "HelpModal"
helpModal.AnchorPoint = Vector2.new(0.5, 0.5)
helpModal.Position = UDim2.fromScale(0.5, 0.52)
helpModal.Size = UDim2.fromOffset(470, 430)
helpModal.BackgroundColor3 = colors.dark
helpModal.BackgroundTransparency = 0.04
helpModal.BorderSizePixel = 0
helpModal.Visible = false
helpModal.Parent = gui
addCorner(helpModal, 18)
addStroke(helpModal, colors.cyan, 0.25, 2)
makeLabel(helpModal, "Kicker", "QUICK START", UDim2.fromOffset(24, 19), UDim2.new(1, -48, 0, 22), 10, Enum.Font.GothamBold, colors.cyan)
makeLabel(helpModal, "Title", "Simple controls, just fly.", UDim2.fromOffset(24, 43), UDim2.new(1, -48, 0, 40), 25, Enum.Font.GothamBlack)
local instructions = makeLabel(helpModal, "Steps", "1   Press B for slow pushback from the gate.\n\n2   Press E to start engines and P to release the brake.\n\n3   Hold W to raise throttle.\n\n4   Move the mouse gently to steer and pitch.\n\n5   Press A in safe flight to capture altitude.\n\n6   Use G for gear, F for flaps, X for speed brakes, L for lights, and C for cameras—including BELLY.", UDim2.fromOffset(25, 102), UDim2.new(1, -50, 0, 230), 14, Enum.Font.Gotham, colors.ink)
instructions.TextWrapped = true
instructions.TextYAlignment = Enum.TextYAlignment.Top
local helpNote = makeLabel(helpModal, "Note", "Accessible arcade controls • not real-world flight training", UDim2.fromOffset(25, 318), UDim2.new(1, -50, 0, 30), 10, Enum.Font.Gotham, colors.muted)
helpNote.TextWrapped = true
local closeHelp = makeButton(helpModal, "Close", "GOT IT — LET'S FLY", UDim2.fromOffset(24, 365), UDim2.new(1, -48, 0, 45), colors.lime)
closeHelp.TextColor3 = colors.dark
closeHelp:SetAttribute("BaseColor", colors.lime)

local toast = Instance.new("Frame")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, -100)
toast.Size = UDim2.fromOffset(430, 76)
toast.BackgroundColor3 = colors.dark
toast.BackgroundTransparency = 0.05
toast.BorderSizePixel = 0
toast.Parent = gui
addCorner(toast, 14)
addStroke(toast, colors.lime, 0.25, 2)
local toastTitle = makeLabel(toast, "Title", "AIRCRAFT READY", UDim2.fromOffset(18, 10), UDim2.new(1, -36, 0, 25), 12, Enum.Font.GothamBold, colors.lime)
local toastBody = makeLabel(toast, "Body", "", UDim2.fromOffset(18, 34), UDim2.new(1, -36, 0, 30), 10, Enum.Font.Gotham, colors.muted)
toastBody.TextWrapped = true
local walkMenuButton = makeButton(gui, "WalkMenu", "M  •  FLIGHT MENU", UDim2.new(1, -170, 0, 22), UDim2.fromOffset(145, 42), colors.panel2)
walkMenuButton.Visible = false
local walkRunButton = makeButton(gui, "WalkRun", UserInputService.TouchEnabled and "RUN" or "SHIFT  •  RUN", UDim2.new(1, -310, 0, 22), UDim2.fromOffset(128, 42), colors.panel2)
walkRunButton.Visible = false

local mobileControls = Instance.new("Frame")
mobileControls.Name = "MobileControls"
mobileControls.Size = UDim2.fromScale(1, 1)
mobileControls.BackgroundTransparency = 1
mobileControls.Visible = UserInputService.TouchEnabled
mobileControls.Parent = hud

local mobileStick = Instance.new("Frame")
mobileStick.Position = UDim2.new(0, 22, 1, -225)
mobileStick.Size = UDim2.fromOffset(150, 150)
mobileStick.BackgroundColor3 = colors.dark
mobileStick.BackgroundTransparency = 0.45
mobileStick.BorderSizePixel = 0
mobileStick.Parent = mobileControls
addCorner(mobileStick, 75)
addStroke(mobileStick, colors.cyan, 0.35, 2)
local stickKnob = Instance.new("Frame")
stickKnob.AnchorPoint = Vector2.new(0.5, 0.5)
stickKnob.Position = UDim2.fromScale(0.5, 0.5)
stickKnob.Size = UDim2.fromOffset(58, 58)
stickKnob.BackgroundColor3 = colors.cyan
stickKnob.BackgroundTransparency = 0.12
stickKnob.BorderSizePixel = 0
stickKnob.Parent = mobileStick
addCorner(stickKnob, 29)

local mobileThrottle = Instance.new("Frame")
mobileThrottle.AnchorPoint = Vector2.new(1, 1)
mobileThrottle.Position = UDim2.new(1, -24, 1, -102)
mobileThrottle.Size = UDim2.fromOffset(104, 132)
mobileThrottle.BackgroundTransparency = 1
mobileThrottle.Parent = mobileControls
local throttleUp = makeButton(mobileThrottle, "ThrottleUp", "THR +", UDim2.fromOffset(0, 0), UDim2.fromOffset(104, 59), colors.lime)
throttleUp.TextColor3 = colors.dark
local throttleDown = makeButton(mobileThrottle, "ThrottleDown", "THR −", UDim2.fromOffset(0, 72), UDim2.fromOffset(104, 59), colors.panel2)
local mobilePushback = makeButton(mobileControls, "Pushback", "PUSHBACK", UDim2.new(1, -138, 1, -306), UDim2.fromOffset(112, 52), colors.panel2)
mobilePushback.AnchorPoint = Vector2.new(0, 1)
mobilePushback.MouseButton1Click:Connect(function()
	PlaneAction:FireServer("Pushback")
end)
local mobileAltitudeHold = makeButton(mobileControls, "AltitudeHold", "ALT HOLD", UDim2.new(1, -138, 1, -368), UDim2.fromOffset(112, 52), colors.panel2)
mobileAltitudeHold.AnchorPoint = Vector2.new(0, 1)
mobileAltitudeHold.MouseButton1Click:Connect(function()
	PlaneAction:FireServer("AltitudeHold")
end)

local activePlane = nil
local playing = false
local throttleUpHeld = false
local throttleDownHeld = false
local mobilePitch = 0
local mobileRoll = 0
local cameraModes = { "CHASE", "COCKPIT", "WING", "BELLY" }
local cameraModeIndex = 1
local orbitYaw = 0
local orbitPitch = math.rad(-12)
local cameraZoom = 1
local cameraDragging = false
local cameraTouches = {}
local lastPinchDistance = nil
local sendAccumulator = 0
local menuAngle = 0
local lastPlaneSearch = 0
local smoothedPitchInput = 0
local smoothedRollInput = 0
local smoothedCameraLook = nil
local characterView = false
local hadPilotSeat = false
local runningOnFoot = false

local function setRunning(value)
	runningOnFoot = value == true and characterView
	RunMode:FireServer(runningOnFoot)
	walkRunButton.Text = runningOnFoot and "RUNNING" or (UserInputService.TouchEnabled and "RUN" or "SHIFT  •  RUN")
	walkRunButton.BackgroundColor3 = runningOnFoot and colors.lime or colors.panel2
	walkRunButton.TextColor3 = runningOnFoot and colors.dark or colors.ink
	walkRunButton:SetAttribute("BaseColor", walkRunButton.BackgroundColor3)
end

local function showToast(titleText, bodyText)
	toastTitle.Text = titleText
	toastBody.Text = bodyText
	TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { Position = UDim2.new(0.5, 0, 0, 92) }):Play()
	task.delay(4, function()
		TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { Position = UDim2.new(0.5, 0, 0, -100) }):Play()
	end)
end

local function findActivePlane()
	local worldFolder = workspace:FindFirstChild("SkyDeckWorld")
	local folder = worldFolder and worldFolder:FindFirstChild("Aircraft")
	if not folder then return nil end
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("OwnerUserId") == player.UserId then
			return model
		end
	end
	return nil
end

local function setPlaying(value)
	characterView = false
	setRunning(false)
	hadPilotSeat = false
	playing = value
	menu.Visible = not value
	shade.Visible = not value
	hud.Visible = value
	header.Visible = not value
	helpModal.Visible = value
	walkMenuButton.Visible = false
	walkRunButton.Visible = false
	UserInputService.MouseIconEnabled = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	cameraDragging = false
	cameraTouches = {}
	lastPinchDistance = nil
	smoothedPitchInput = 0
	smoothedRollInput = 0
	smoothedCameraLook = nil
	if not value then
		activePlane = nil
		camera.CameraType = Enum.CameraType.Scriptable
	end
end

local function releaseToCharacterView()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	characterView = true
	playing = true
	activePlane = nil
	menu.Visible = false
	shade.Visible = false
	hud.Visible = false
	header.Visible = false
	helpModal.Visible = false
	walkMenuButton.Visible = true
	walkRunButton.Visible = true
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then camera.CameraSubject = humanoid end
	showToast("EXPLORE ON FOOT", "The aircraft will continue without pilot input. Walk into the terminal, or press M for the flight menu.")
end

local function resumeFlightFromWalk(aircraft)
	characterView = false
	setRunning(false)
	playing = true
	activePlane = aircraft
	hadPilotSeat = true
	menu.Visible = false
	shade.Visible = false
	hud.Visible = true
	header.Visible = false
	helpModal.Visible = false
	walkMenuButton.Visible = false
	walkRunButton.Visible = false
	camera.CameraType = Enum.CameraType.Scriptable
	smoothedCameraLook = nil
	showToast("BACK IN THE COCKPIT", "Aircraft controls and the flight camera are active again.")
end

local function cycleCamera()
	cameraModeIndex = cameraModeIndex % #cameraModes + 1
	local mode = cameraModes[cameraModeIndex]
	cameraButton.Text = "C  •  " .. mode
	actionButtons.Camera.Text = "C\n" .. mode
	smoothedCameraLook = nil
end

actionButtons.Camera.MouseButton1Click:Connect(cycleCamera)
cameraButton.MouseButton1Click:Connect(cycleCamera)

local function toggleHelp()
	helpModal.Visible = not helpModal.Visible
end
helpButton.MouseButton1Click:Connect(toggleHelp)
closeHelp.MouseButton1Click:Connect(toggleHelp)

spawnButton.MouseButton1Click:Connect(function()
	local aircraft = AircraftCatalog.List[selectedAircraftIndex]
	local airport = AirportCatalog.List[selectedAirportIndex]
	SpawnPlane:FireServer(aircraft.Code, airport.Code)
	setPlaying(true)
	showToast("SPAWNING " .. aircraft.Code, "Preparing runway at " .. airport.Name .. ".")
	task.delay(0.2, function()
		for _ = 1, 30 do
			activePlane = findActivePlane()
			if activePlane then break end
			task.wait(0.1)
		end
	end)
end)

backButton.MouseButton1Click:Connect(function()
	setPlaying(false)
end)
walkMenuButton.MouseButton1Click:Connect(function()
	setPlaying(false)
end)
walkRunButton.MouseButton1Click:Connect(function()
	setRunning(not runningOnFoot)
end)

SystemMessage.OnClientEvent:Connect(function(titleText, bodyText)
	showToast(tostring(titleText), tostring(bodyText))
end)

ReturnToMenu.OnClientEvent:Connect(function()
	setPlaying(false)
	showToast("RETURNED TO MENU", "Your aircraft is fully submerged. Choose another flight when ready.")
end)

local function actionFromKey(keyCode)
	if keyCode == Enum.KeyCode.E then return "Engine" end
	if keyCode == Enum.KeyCode.P then return "Brake" end
	if keyCode == Enum.KeyCode.B then return "Pushback" end
	if keyCode == Enum.KeyCode.G then return "Gear" end
	if keyCode == Enum.KeyCode.F then return "Flaps" end
	if keyCode == Enum.KeyCode.A then return "AltitudeHold" end
	if keyCode == Enum.KeyCode.X then return "SpeedBrake" end
	if keyCode == Enum.KeyCode.L then return "Lights" end
	if keyCode == Enum.KeyCode.R then return "Reset" end
	return nil
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not playing then return end
	if characterView then
		if input.KeyCode == Enum.KeyCode.M then setPlaying(false) end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then setRunning(true) end
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		cameraDragging = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
		orbitYaw = 0
		orbitPitch = math.rad(-12)
		cameraZoom = 1
		smoothedCameraLook = nil
	elseif input.UserInputType == Enum.UserInputType.Touch and input.Position.X > camera.ViewportSize.X * 0.32 then
		cameraTouches[input] = Vector2.new(input.Position.X, input.Position.Y)
		local positions = {}
		for _, position in pairs(cameraTouches) do table.insert(positions, position) end
		if #positions >= 2 then lastPinchDistance = (positions[1] - positions[2]).Magnitude end
	end
	if input.KeyCode == Enum.KeyCode.W then throttleUpHeld = true end
	if input.KeyCode == Enum.KeyCode.S then throttleDownHeld = true end
	if input.KeyCode == Enum.KeyCode.C then cycleCamera() end
	if input.KeyCode == Enum.KeyCode.H then toggleHelp() end
	local action = actionFromKey(input.KeyCode)
	if action then PlaneAction:FireServer(action) end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then setRunning(false) end
	if input.KeyCode == Enum.KeyCode.W then throttleUpHeld = false end
	if input.KeyCode == Enum.KeyCode.S then throttleDownHeld = false end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		cameraDragging = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	elseif input.UserInputType == Enum.UserInputType.Touch and cameraTouches[input] then
		cameraTouches[input] = nil
		lastPinchDistance = nil
	end
end)

local function bindHoldButton(button, setHeld)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then setHeld(true) end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then setHeld(false) end
	end)
end
bindHoldButton(throttleUp, function(value) throttleUpHeld = value end)
bindHoldButton(throttleDown, function(value) throttleDownHeld = value end)

local stickTouch = nil
mobileStick.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then stickTouch = input end
end)
UserInputService.InputChanged:Connect(function(input)
	if input == stickTouch then
		local center = mobileStick.AbsolutePosition + mobileStick.AbsoluteSize / 2
		local offset = Vector2.new(input.Position.X, input.Position.Y) - center
		local radius = mobileStick.AbsoluteSize.X * 0.38
		if offset.Magnitude > radius then offset = offset.Unit * radius end
		mobileRoll = math.clamp(offset.X / radius, -1, 1)
		mobilePitch = math.clamp(-offset.Y / radius, -1, 1)
		stickKnob.Position = UDim2.fromOffset(mobileStick.AbsoluteSize.X / 2 + offset.X, mobileStick.AbsoluteSize.Y / 2 + offset.Y)
	end
	if not playing then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement and cameraDragging then
		orbitYaw -= input.Delta.X * 0.006
		orbitPitch = math.clamp(orbitPitch - input.Delta.Y * 0.0045, math.rad(-85), math.rad(70))
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		cameraZoom = math.clamp(cameraZoom - input.Position.Z * 0.11, 0.22, 3.5)
	elseif input.UserInputType == Enum.UserInputType.Touch and cameraTouches[input] then
		local newPosition = Vector2.new(input.Position.X, input.Position.Y)
		local oldPosition = cameraTouches[input]
		cameraTouches[input] = newPosition
		local positions = {}
		for _, position in pairs(cameraTouches) do table.insert(positions, position) end
		if #positions >= 2 then
			local distance = math.max(12, (positions[1] - positions[2]).Magnitude)
			if lastPinchDistance then
				cameraZoom = math.clamp(cameraZoom * (lastPinchDistance / distance), 0.22, 3.5)
			end
			lastPinchDistance = distance
		else
			local delta = newPosition - oldPosition
			orbitYaw -= delta.X * 0.008
			orbitPitch = math.clamp(orbitPitch - delta.Y * 0.006, math.rad(-85), math.rad(70))
			lastPinchDistance = nil
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input == stickTouch then
		stickTouch = nil
		mobileRoll = 0
		mobilePitch = 0
		TweenService:Create(stickKnob, TweenInfo.new(0.15), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	end
end)

local function updateActionButtons(model)
	local engine = model:GetAttribute("Engine") == true
	local brake = model:GetAttribute("Brake") == true
	local pushback = model:GetAttribute("Pushback") == true
	local pushbackCoasting = model:GetAttribute("PushbackCoasting") == true
	local gear = model:GetAttribute("Gear") ~= false
	local gearMoving = model:GetAttribute("GearMoving") == true
	local gearProgress = model:GetAttribute("GearProgress") or (gear and 1 or 0)
	local flaps = model:GetAttribute("Flaps") or 0
	local flapsMoving = model:GetAttribute("FlapsMoving") == true
	local flapPosition = model:GetAttribute("FlapPosition") or flaps
	local speedBrake = model:GetAttribute("SpeedBrake") == true
	local externalLights = model:GetAttribute("ExternalLights") ~= false
	local altitudeHold = model:GetAttribute("AltitudeHold") == true
	local altitudeHoldTarget = model:GetAttribute("AltitudeHoldTarget") or 0
	local gearText = gearMoving and (gear and "EXTENDING" or "RETRACTING") or (gear and "DOWN" or "UP")
	local flapText = flapsMoving and string.format("%.1f→%d", flapPosition, flaps) or tostring(flaps)
	local states = {
		Engine = { active = engine, text = "E\nENGINE " .. (engine and "ON" or "OFF"), color = colors.green },
		Brake = { active = brake, text = "P\nBRAKE " .. (brake and "SET" or "FREE"), color = colors.amber },
		Pushback = { active = pushback or pushbackCoasting, text = "B\nPUSH " .. (pushback and "ON" or (pushbackCoasting and "STOP" or "OFF")), color = colors.amber },
		Gear = { active = gearProgress > 0.02, text = "G\nGEAR " .. gearText, color = colors.cyan },
		Flaps = { active = flapPosition > 0.02, text = "F\nFLAPS " .. flapText, color = colors.cyan },
		AltitudeHold = { active = altitudeHold, text = altitudeHold and string.format("A\nALT %d", math.floor(altitudeHoldTarget + 0.5)) or "A\nALT HOLD", color = colors.green },
		SpeedBrake = { active = speedBrake, text = "X\nSPEED BRAKE " .. (speedBrake and "ON" or "OFF"), color = colors.amber },
		Lights = { active = externalLights, text = "L\nLIGHTS " .. (externalLights and "ON" or "OFF"), color = colors.cyan },
	}
	mobilePushback.Text = pushback and "PUSHBACK ON" or (pushbackCoasting and "SLOWING..." or "PUSHBACK")
	mobilePushback.BackgroundColor3 = (pushback or pushbackCoasting) and colors.amber or colors.panel2
	mobilePushback.TextColor3 = (pushback or pushbackCoasting) and colors.dark or colors.ink
	mobilePushback:SetAttribute("BaseColor", mobilePushback.BackgroundColor3)
	mobileAltitudeHold.Text = altitudeHold and string.format("ALT %d", math.floor(altitudeHoldTarget + 0.5)) or "ALT HOLD"
	mobileAltitudeHold.BackgroundColor3 = altitudeHold and colors.green or colors.panel2
	mobileAltitudeHold.TextColor3 = altitudeHold and colors.dark or colors.ink
	mobileAltitudeHold:SetAttribute("BaseColor", mobileAltitudeHold.BackgroundColor3)
	for name, state in pairs(states) do
		local button = actionButtons[name]
		button.Text = state.text
		button.BackgroundColor3 = state.active and state.color or colors.panel2
		button.TextColor3 = state.active and colors.dark or colors.ink
		button:SetAttribute("BaseColor", button.BackgroundColor3)
	end
end

-- Aircraft state remains server-authoritative. This client layer caches each
-- aircraft once, then interpolates only its presentation geometry at the render
-- frame rate. No object searches or Tweens are created inside Step().
local visualControllers = {}
local visualFolderConnections = {}
local pendingVisualConnections = {}

local function attachVisualController(model)
	if not model:IsA("Model") or visualControllers[model] then return end
	if not model.PrimaryPart or model:GetAttribute("VisualArchitectureRevision") == nil then
		if not pendingVisualConnections[model] then
			pendingVisualConnections[model] = model:GetAttributeChangedSignal("VisualArchitectureRevision"):Connect(function()
				local connection = pendingVisualConnections[model]
				if connection then connection:Disconnect() end
				pendingVisualConnections[model] = nil
				attachVisualController(model)
			end)
		end
		return
	end
	visualControllers[model] = AircraftVisualController.CreateClient(model)
end

local function watchAircraftFolder(folder)
	if not folder or not folder:IsA("Folder") then return end
	for _, model in ipairs(folder:GetChildren()) do attachVisualController(model) end
	table.insert(visualFolderConnections, folder.ChildAdded:Connect(attachVisualController))
	table.insert(visualFolderConnections, folder.ChildRemoved:Connect(function(model)
		local pending = pendingVisualConnections[model]
		if pending then
			pending:Disconnect()
			pendingVisualConnections[model] = nil
		end
		local controller = visualControllers[model]
		if controller then
			controller:Destroy()
			visualControllers[model] = nil
		end
	end))
end

local function watchWorld(worldFolder)
	if not worldFolder or worldFolder.Name ~= "SkyDeckWorld" then return end
	for _, connection in ipairs(visualFolderConnections) do connection:Disconnect() end
	table.clear(visualFolderConnections)
	watchAircraftFolder(worldFolder:FindFirstChild("Aircraft"))
	watchAircraftFolder(worldFolder:FindFirstChild("AI Traffic"))
	table.insert(visualFolderConnections, worldFolder.ChildAdded:Connect(function(child)
		if child.Name == "Aircraft" or child.Name == "AI Traffic" then watchAircraftFolder(child) end
	end))
end

watchWorld(workspace:FindFirstChild("SkyDeckWorld"))
workspace.ChildAdded:Connect(watchWorld)

RunService.RenderStepped:Connect(function(deltaTime)
	for model, controller in pairs(visualControllers) do
		if not controller:Step(deltaTime) then
			controller:Destroy()
			visualControllers[model] = nil
		end
	end
end)

RunService:BindToRenderStep("SkyDeckClient", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
	local viewport = camera.ViewportSize
	if characterView then
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
			local seatPart = humanoid.SeatPart
			local aircraft = seatPart and seatPart:FindFirstAncestorWhichIsA("Model")
			if seatPart and seatPart:IsA("VehicleSeat") and seatPart:GetAttribute("AircraftPilotSeat") == true and aircraft and aircraft:GetAttribute("OwnerUserId") == player.UserId then
				resumeFlightFromWalk(aircraft)
			end
		end
		return
	end
	if not playing then
		local menuScale = menu:FindFirstChildOfClass("UIScale")
		if menuScale then
			menuScale.Scale = math.clamp(math.min((viewport.X - 28) / 610, (viewport.Y - 104) / 650), 0.58, 1)
		end
		menuAngle += deltaTime * 0.11
		local focus = Vector3.new(0, 20, 0)
		local cameraPosition = focus + Vector3.new(math.cos(menuAngle) * 800, 330, math.sin(menuAngle) * 800)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(cameraPosition, focus)
		return
	end

	if not activePlane or not activePlane.Parent then
		if os.clock() - lastPlaneSearch > 0.2 then
			activePlane = findActivePlane()
			lastPlaneSearch = os.clock()
		end
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local pilotSeat = activePlane:FindFirstChild("PilotSeat", true)
	local seatedInPlane = humanoid ~= nil and pilotSeat ~= nil and humanoid.SeatPart == pilotSeat
	if seatedInPlane then
		hadPilotSeat = true
	elseif hadPilotSeat then
		releaseToCharacterView()
		return
	end

	local pivot = activePlane:GetPivot()
	local length = activePlane:GetAttribute("Length") or 52
	local span = activePlane:GetAttribute("Span") or 48
	local diameter = activePlane:GetAttribute("FuselageDiameter") or 12
	local mode = cameraModes[cameraModeIndex]
	local desired
	local target
	if mode == "COCKPIT" then
		desired = pivot:PointToWorldSpace(Vector3.new(0, 3.1, -length * 0.34))
		target = pivot:PointToWorldSpace(Vector3.new(0, 2.5, -length * 2.4))
	elseif mode == "WING" then
		desired = pivot:PointToWorldSpace(Vector3.new(span * 0.43, 5, 2))
		target = pivot:PointToWorldSpace(Vector3.new(0, 1.5, -length * 1.2))
	elseif mode == "BELLY" then
		-- Camera sits aft of the wing and looks forward below the fuselage, keeping
		-- both rear main-gear trucks and the runway framed like the reference view.
		desired = pivot:PointToWorldSpace(Vector3.new(0, -diameter * 0.64, length * 0.32))
		target = pivot:PointToWorldSpace(Vector3.new(0, -diameter * 0.80, -length * 0.58))
	else
		target = pivot:PointToWorldSpace(Vector3.new(0, 2, -length * 0.08))
		local distance = math.clamp((60 + length * 0.55) * cameraZoom, 10, 390)
		local orbitRotation = CFrame.Angles(0, orbitYaw, 0) * CFrame.Angles(orbitPitch, 0, 0)
		local localOffset = orbitRotation:VectorToWorldSpace(Vector3.new(0, 0, distance))
		desired = target + pivot:VectorToWorldSpace(localOffset)
	end
	local desiredLook = (target - desired).Unit
	if not smoothedCameraLook then smoothedCameraLook = desiredLook end
	local cameraResponse = mode == "COCKPIT" and 16 or (mode == "BELLY" and 13 or 10)
	local cameraLookAlpha = 1 - math.exp(-deltaTime * cameraResponse)
	smoothedCameraLook = smoothedCameraLook:Lerp(desiredLook, cameraLookAlpha).Unit
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = mode == "BELLY" and 78 or 70
	-- Follow translation exactly so replication updates cannot make the aircraft shake in frame.
	-- Smooth only the viewing direction so turns remain comfortable and stable.
	camera.CFrame = CFrame.lookAt(desired, desired + smoothedCameraLook)

	local pitch
	local roll
	if UserInputService.TouchEnabled then
		pitch = mobilePitch
		roll = mobileRoll
	elseif cameraDragging then
		pitch = 0
		roll = 0
	else
		local mouse = UserInputService:GetMouseLocation()
		local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.48)
		roll = math.clamp((mouse.X - center.X) / (viewport.X * 0.32), -1, 1)
		pitch = math.clamp((center.Y - mouse.Y) / (viewport.Y * 0.31), -1, 1)
		mouseReticle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	end

	-- Damping only changes how quickly the player's command reaches the aircraft;
	-- it never creates a pitch command or performs rotation/flare automatically.
	local pitchInputAlpha = 1 - math.exp(-deltaTime * 3.8)
	local rollInputAlpha = 1 - math.exp(-deltaTime * 3.4)
	local pitchTarget = math.abs(pitch) < 0.025 and 0 or pitch
	local rollTarget = math.abs(roll) < 0.025 and 0 or roll
	smoothedPitchInput += (pitchTarget - smoothedPitchInput) * pitchInputAlpha
	smoothedRollInput += (rollTarget - smoothedRollInput) * rollInputAlpha
	local throttleAxis = (throttleUpHeld and 1 or 0) - (throttleDownHeld and 1 or 0)
	sendAccumulator += deltaTime
	if sendAccumulator >= 0.05 then
		PlaneControl:FireServer({ Pitch = smoothedPitchInput, Roll = smoothedRollInput, Throttle = throttleAxis })
		sendAccumulator = 0
	end

	local speed = activePlane:GetAttribute("Speed") or 0
	local altitude = activePlane:GetAttribute("Altitude") or 0
	local heading = activePlane:GetAttribute("Heading") or 0
	local verticalSpeed = activePlane:GetAttribute("VerticalSpeed") or 0
	local throttle = activePlane:GetAttribute("Throttle") or 0
	local status = activePlane:GetAttribute("Status") or "PARKED"
	local nearest = activePlane:GetAttribute("NearestAirport") or "---"
	speedValue.Text = tostring(math.floor(speed + 0.5))
	altitudeValue.Text = tostring(math.floor(altitude + 0.5))
	headingValue.Text = string.format("HDG %03d°", math.floor(heading + 0.5) % 360)
	vsValue.Text = string.format("V/S %d", math.floor(verticalSpeed / 10 + 0.5) * 10)
	throttleValue.Text = string.format("THR %d%%", math.floor(throttle + 0.5))
	statusLabel.Text = "●  " .. status
	statusLabel.TextColor3 = string.find(status, "STALL") and colors.red or colors.lime
	nearestLabel.Text = nearest .. " AIRSPACE"
	updateActionButtons(activePlane)

	local position = pivot.Position
	mapPlane.Position = mapPosition(position.X, position.Z)
	-- The aircraft icon points north at zero rotation and follows true heading.
	mapPlane.Rotation = heading
	mapHeadingValue.Text = string.format("%03d°  %s", math.floor(heading + 0.5) % 360, compassDirection(heading))
end)

local cosmeticAccumulator = 0
local lodAccumulator = 0
local effectsWorldFolder = nil
local effectsAircraftFolder = nil
local effectsTrafficFolder = nil

local function getAircraftEffectFolders()
	if not effectsWorldFolder or not effectsWorldFolder.Parent then
		effectsWorldFolder = workspace:FindFirstChild("SkyDeckWorld")
		effectsAircraftFolder = nil
		effectsTrafficFolder = nil
	end
	if effectsWorldFolder and (not effectsAircraftFolder or effectsAircraftFolder.Parent ~= effectsWorldFolder) then
		effectsAircraftFolder = effectsWorldFolder:FindFirstChild("Aircraft")
		effectsTrafficFolder = effectsWorldFolder:FindFirstChild("AI Traffic")
	end
	return effectsAircraftFolder, effectsTrafficFolder
end

RunService.RenderStepped:Connect(function(deltaTime)
	cosmeticAccumulator += deltaTime
	lodAccumulator += deltaTime
	if cosmeticAccumulator < 0.06 then return end
	local aircraftFolder, trafficFolder = getAircraftEffectFolders()
	if not aircraftFolder then return end
	local cameraPosition = camera.CFrame.Position
	local function updateFolder(folder)
		if not folder then return end
		for _, model in ipairs(folder:GetChildren()) do
			if model:IsA("Model") and model.PrimaryPart then
				local distance = (model:GetPivot().Position - cameraPosition).Magnitude
				AircraftEffectsController.Apply(model, cosmeticAccumulator, distance)
				if lodAccumulator >= 0.28 then AircraftLODController.Apply(model, distance) end
			end
		end
	end
	updateFolder(aircraftFolder)
	updateFolder(trafficFolder)
	cosmeticAccumulator = 0
	if lodAccumulator >= 0.28 then lodAccumulator = 0 end
end)

setPlaying(false)

print("[Around the World] V31 client ready. Controls: B pushback, E engine, P brake, W/S throttle, mouse flight, G animated gear, F flaps, A altitude hold, X speed brake, L lights, C camera.")
