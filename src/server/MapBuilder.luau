local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Theme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("VisualTheme"))
local MapLayoutBuilder = require(script.Parent:WaitForChild("MapLayoutBuilder"))
local ExpeditionLayout = require(script.Parent:WaitForChild("MapLayouts"):WaitForChild("ExpeditionLayout"))

local MapBuilder = {}

local MAP_NAME = "PrototypeMap"
local CLOSED_GATE_CFRAME = CFrame.new(0, 7.5, 5)
local OPEN_GATE_CFRAME = CFrame.new(0, 21.5, 5)

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
	part.CastShadow = material ~= Enum.Material.Neon
	part.Parent = parent
	return part
end

local function configureLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = Theme.Lighting.Brightness
	Lighting.Ambient = Theme.Lighting.Ambient
	Lighting.OutdoorAmbient = Theme.Lighting.OutdoorAmbient
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.ExposureCompensation = Theme.Lighting.Exposure

	for _, effectName in ipairs({ "RealityAtmosphere", "RealityBloom", "RealityColor" }) do
		local previousEffect = Lighting:FindFirstChild(effectName)
		if previousEffect then
			previousEffect:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "RealityAtmosphere"
	atmosphere.Color = Color3.fromRGB(154, 185, 207)
	atmosphere.Decay = Theme.Colors.Steel
	atmosphere.Density = 0.08
	atmosphere.Glare = 0.05
	atmosphere.Haze = 0.55
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "RealityBloom"
	bloom.Intensity = Theme.Lighting.BloomIntensity
	bloom.Size = 28
	bloom.Threshold = Theme.Lighting.BloomThreshold
	bloom.Parent = Lighting

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "RealityColor"
	colorCorrection.Brightness = 0.02
	colorCorrection.Contrast = 0.08
	colorCorrection.Saturation = 0.02
	colorCorrection.TintColor = Theme.Colors.White
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

-- Chamber decks are functional: RoomGenerator reads ChamberDeck_N to place floor overlays and
-- validates it, so they stay in code. Architecture and decoration come from the Blender layout.
local function buildChamberDecks(map)
	local cyan = Theme.Colors.Cyan
	local violet = Theme.Colors.Violet

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
			lane.CanTouch = false
			lane.CanQuery = false
		end
		-- Short edge dashes make each chamber readable without implying a puzzle solution.
		for _, side in ipairs({ -1, 1 }) do
			for _, zOffset in ipairs({ -14, -7, 0, 7, 14 }) do
				local dash = createPart(
					map,
					"ChamberRouteDash",
					Vector3.new(1.4, 0.06, 0.24),
					CFrame.new(side * 29, 0.72, centerZ + zOffset),
					Theme.Colors.Cyan,
					Enum.Material.Neon
				)
				dash.CanCollide = false
				dash.CanTouch = false
				dash.CanQuery = false
			end
		end
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

	MapLayoutBuilder.Build(map, ExpeditionLayout)
	buildChamberDecks(map)
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
