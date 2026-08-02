local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

local MAP_NAME = "PrototypeMap"
local CLOSED_GATE_CFRAME = CFrame.new(0, 7.5, 5)
local OPEN_GATE_CFRAME = CFrame.new(0, 21.5, 5)

local ROOM_WIDTH = 68
local ROOM_LENGTH = 150
local ROOM_CENTER_Z = 7

local function createPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addCornerLight(parent, position, color)
	local fixture =
		createPart(parent, "WallLight", Vector3.new(0.5, 4, 0.5), CFrame.new(position), color, Enum.Material.Neon)
	fixture.CanCollide = false

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 2
	light.Range = 19
	light.Parent = fixture
end

local function configureLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 3.2
	Lighting.Ambient = Color3.fromRGB(92, 105, 139)
	Lighting.OutdoorAmbient = Color3.fromRGB(67, 80, 110)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.ExposureCompensation = 0.22

	for _, effectName in ipairs({ "RealityAtmosphere", "RealityBloom", "RealityColor" }) do
		local previousEffect = Lighting:FindFirstChild(effectName)
		if previousEffect then
			previousEffect:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "RealityAtmosphere"
	atmosphere.Color = Color3.fromRGB(183, 208, 235)
	atmosphere.Decay = Color3.fromRGB(86, 96, 132)
	atmosphere.Density = 0.1
	atmosphere.Glare = 0.05
	atmosphere.Haze = 0.55
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "RealityBloom"
	bloom.Intensity = 0.55
	bloom.Size = 28
	bloom.Threshold = 1.1
	bloom.Parent = Lighting

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "RealityColor"
	colorCorrection.Brightness = 0.08
	colorCorrection.Contrast = 0.08
	colorCorrection.Saturation = 0.08
	colorCorrection.TintColor = Color3.fromRGB(239, 246, 255)
	colorCorrection.Parent = Lighting
end

local function addSurfaceText(part, text, face)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "Label"
	surfaceGui.Face = face or Enum.NormalId.Front
	surfaceGui.AlwaysOnTop = false
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 35
	surfaceGui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(235, 240, 255)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = surfaceGui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.07, 0)
	padding.PaddingRight = UDim.new(0.07, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label

	return label
end

local function buildRoomShell(map)
	local floor = createPart(
		map,
		"Floor",
		Vector3.new(ROOM_WIDTH, 1, ROOM_LENGTH),
		CFrame.new(0, 0, ROOM_CENTER_Z),
		Color3.fromRGB(55, 65, 86),
		Enum.Material.Slate
	)
	floor.Locked = true
	floor:SetAttribute("GeometryRole", "Support")

	createPart(
		map,
		"LeftWall",
		Vector3.new(1, 18, ROOM_LENGTH),
		CFrame.new(-34.5, 9, ROOM_CENTER_Z),
		Color3.fromRGB(48, 58, 79),
		Enum.Material.Metal
	)
	createPart(
		map,
		"RightWall",
		Vector3.new(1, 18, ROOM_LENGTH),
		CFrame.new(34.5, 9, ROOM_CENTER_Z),
		Color3.fromRGB(48, 58, 79),
		Enum.Material.Metal
	)
	createPart(
		map,
		"BackWall",
		Vector3.new(ROOM_WIDTH, 18, 1),
		CFrame.new(0, 9, -68.5),
		Color3.fromRGB(48, 58, 79),
		Enum.Material.Metal
	)
	createPart(
		map,
		"FrontWall",
		Vector3.new(ROOM_WIDTH, 18, 1),
		CFrame.new(0, 9, 82.5),
		Color3.fromRGB(48, 58, 79),
		Enum.Material.Metal
	)
	createPart(
		map,
		"Ceiling",
		Vector3.new(ROOM_WIDTH, 1, ROOM_LENGTH),
		CFrame.new(0, 18, ROOM_CENTER_Z),
		Color3.fromRGB(34, 43, 62),
		Enum.Material.Metal
	)

	for _, position in ipairs({
		Vector3.new(-33.7, 8, -58),
		Vector3.new(33.7, 8, -58),
		Vector3.new(-33.7, 8, -30),
		Vector3.new(33.7, 8, -30),
		Vector3.new(-33.7, 8, 0),
		Vector3.new(33.7, 8, 0),
		Vector3.new(-33.7, 8, 30),
		Vector3.new(33.7, 8, 30),
		Vector3.new(-33.7, 8, 60),
		Vector3.new(33.7, 8, 60),
		Vector3.new(-33.7, 8, 76),
		Vector3.new(33.7, 8, 76),
	}) do
		addCornerLight(map, position, Color3.fromRGB(91, 120, 255))
	end
end

local function buildLaboratoryDetails(map)
	local cyan = Color3.fromRGB(70, 225, 218)
	local violet = Color3.fromRGB(153, 92, 255)

	for index, zPosition in ipairs({ -60, -42, -24, -6, 12, 30, 48, 66, 78 }) do
		local beam = createPart(
			map,
			"CeilingBeam_" .. tostring(index),
			Vector3.new(67, 0.8, 1.2),
			CFrame.new(0, 17.25, zPosition),
			Color3.fromRGB(52, 58, 82),
			Enum.Material.Metal
		)
		beam.CanCollide = false

		for _, xPosition in ipairs({ -25, 0, 25 }) do
			local ceilingLight = createPart(
				map,
				"CeilingStrip",
				Vector3.new(8, 0.2, 0.7),
				CFrame.new(xPosition, 16.78, zPosition),
				if index % 2 == 0 then violet else cyan,
				Enum.Material.Neon
			)
			ceilingLight.CanCollide = false

			local surfaceLight = Instance.new("SurfaceLight")
			surfaceLight.Face = Enum.NormalId.Bottom
			surfaceLight.Angle = 80
			surfaceLight.Brightness = 2.2
			surfaceLight.Range = 24
			surfaceLight.Color = ceilingLight.Color
			surfaceLight.Parent = ceilingLight
		end
	end

	for index, zPosition in ipairs({ -56, -34, -12, 10, 32, 54, 74 }) do
		for _, side in ipairs({ -1, 1 }) do
			local panel = createPart(
				map,
				"WallPanel_" .. tostring(index) .. "_" .. tostring(side),
				Vector3.new(0.35, 9, 10),
				CFrame.new(side * 33.9, 8, zPosition),
				Color3.fromRGB(62, 73, 96),
				Enum.Material.DiamondPlate
			)
			panel.CanCollide = false

			local accent = createPart(
				map,
				"WallAccent",
				Vector3.new(0.18, 0.45, 8),
				CFrame.new(side * 33.68, 10.5, zPosition),
				if index % 2 == 0 then cyan else violet,
				Enum.Material.Neon
			)
			accent.CanCollide = false
		end
	end

	for _, side in ipairs({ -1, 1 }) do
		for pipeIndex, yPosition in ipairs({ 3.2, 5.1 }) do
			local pipe = createPart(
				map,
				"UtilityPipe_" .. tostring(side) .. "_" .. tostring(pipeIndex),
				Vector3.new(0.7, 0.7, 140),
				CFrame.new(side * 32.9, yPosition, 7),
				if pipeIndex == 1 then Color3.fromRGB(73, 85, 115) else Color3.fromRGB(73, 54, 101),
				Enum.Material.Metal
			)
			pipe.CanCollide = false
		end
	end

	for roomIndex, centerZ in ipairs({ -45, -4, 37 }) do
		local deck = createPart(
			map,
			"ChamberDeck_" .. tostring(roomIndex),
			Vector3.new(61, 0.16, 36),
			CFrame.new(0, 0.59, centerZ),
			Color3.fromRGB(62, 72, 94),
			Enum.Material.DiamondPlate
		)
		deck.CanCollide = false

		for _, xPosition in ipairs({ -26, 26 }) do
			local lane = createPart(
				map,
				"FloorLane",
				Vector3.new(0.38, 0.08, 33),
				CFrame.new(xPosition, 0.72, centerZ),
				if roomIndex % 2 == 0 then violet else cyan,
				Enum.Material.Neon
			)
			lane.CanCollide = false
		end

		for _, side in ipairs({ -1, 1 }) do
			local window = createPart(
				map,
				"ObservationWindow",
				Vector3.new(0.2, 5.5, 8),
				CFrame.new(side * 33.35, 9, centerZ),
				Color3.fromRGB(86, 116, 167),
				Enum.Material.Glass
			)
			window.Transparency = 0.5
			window.CanCollide = false
		end
	end

	for _, zPosition in ipairs({ -62, -24, 17, 58, 72 }) do
		for _, xPosition in ipairs({ -30.5, 30.5 }) do
			createPart(
				map,
				"ChamberArch",
				Vector3.new(3.5, 17, 2),
				CFrame.new(xPosition, 8.5, zPosition),
				Color3.fromRGB(50, 58, 81),
				Enum.Material.Metal
			)
		end
		local archLight = createPart(
			map,
			"ArchLight",
			Vector3.new(58, 0.35, 0.45),
			CFrame.new(0, 16.2, zPosition),
			if zPosition % 2 == 0 then violet else cyan,
			Enum.Material.Neon
		)
		archLight.CanCollide = false
	end
end

local function buildInstructionBoard(map)
	local board = createPart(
		map,
		"InstructionBoard",
		Vector3.new(18, 8, 0.5),
		CFrame.new(0, 7, -67.8),
		Color3.fromRGB(42, 48, 70),
		Enum.Material.SmoothPlastic
	)
	board.CanCollide = false
	addSurfaceText(
		board,
		"EVERY EXPEDITION CHANGES.\n\nSEER: reveal hidden clues\nOPERATOR: interact and advance\nSOLO: scan, memorize, act",
		Enum.NormalId.Back
	)
end

local function _buildConsoles(map, signals)
	local buttons = {}
	local xPositions = { -10, 0, 10 }

	for index, signal in ipairs(signals) do
		local base = createPart(
			map,
			"ConsoleBase_" .. signal.Id,
			Vector3.new(7, 2, 7),
			CFrame.new(xPositions[index], 1.25, -10),
			Color3.fromRGB(55, 61, 82),
			Enum.Material.Metal
		)

		local button = createPart(
			map,
			"Console_" .. signal.Id,
			Vector3.new(5, 1, 5),
			CFrame.new(xPositions[index], 2.7, -10),
			signal.Color,
			Enum.Material.Neon
		)
		button:SetAttribute("SignalId", signal.Id)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ActivatePrompt"
		prompt.ActionText = "ACTIVATE"
		prompt.ObjectText = signal.DisplayName .. " CONSOLE"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("VisibleToRole", "Operator")
		prompt.Parent = button

		addSurfaceText(base, signal.DisplayName, Enum.NormalId.Front)
		table.insert(buttons, button)
	end

	return buttons
end

function MapBuilder.Build(_signals)
	configureLighting()

	local previousMap = workspace:FindFirstChild(MAP_NAME)
	if previousMap then
		previousMap:Destroy()
	end

	local map = Instance.new("Folder")
	map.Name = MAP_NAME
	map.Parent = workspace

	buildRoomShell(map)
	buildLaboratoryDetails(map)
	buildInstructionBoard(map)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "RoundSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 1, -63)
	spawn.Color = Color3.fromRGB(88, 224, 196)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.35
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Enabled = false
	spawn.Duration = 0
	spawn:SetAttribute("GeometryRole", "Spawn")
	spawn.Parent = map

	return {
		Root = map,
		Spawn = spawn,
	}
end

function MapBuilder.SetGateOpen(map, isOpen, instant)
	map.Gate.CanCollide = not isOpen
	local targetCFrame = if isOpen then OPEN_GATE_CFRAME else CLOSED_GATE_CFRAME
	local targetTransparency = if isOpen then 0.55 else 0.08

	if instant then
		map.Gate.CFrame = targetCFrame
		map.Gate.Transparency = targetTransparency
		return
	end

	local tween = TweenService:Create(map.Gate, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = targetCFrame,
		Transparency = targetTransparency,
	})
	tween:Play()
end

return MapBuilder
