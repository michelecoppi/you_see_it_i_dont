local LobbyBuilder = {}

local LOBBY_NAME = "RealityLobby"
local ORIGIN = Vector3.new(100, 0, 0)
local LOBBY_WIDTH = 108
local LOBBY_LENGTH = 94

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

local function addSurfaceLabel(part, text, face, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 35
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(240, 245, 255)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.06, 0)
	padding.PaddingBottom = UDim.new(0.06, 0)
	padding.Parent = label
	return label
end

local function addPortal(parent, name, center, color, title, subtitle, actionText)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	createPart(
		model,
		"LeftPillar",
		Vector3.new(2, 12, 2),
		CFrame.new(center + Vector3.new(-6, 6, 0)),
		Color3.fromRGB(74, 86, 112),
		Enum.Material.Metal
	)
	createPart(
		model,
		"RightPillar",
		Vector3.new(2, 12, 2),
		CFrame.new(center + Vector3.new(6, 6, 0)),
		Color3.fromRGB(74, 86, 112),
		Enum.Material.Metal
	)
	createPart(
		model,
		"TopBeam",
		Vector3.new(14, 2, 2),
		CFrame.new(center + Vector3.new(0, 11, 0)),
		Color3.fromRGB(74, 86, 112),
		Enum.Material.Metal
	)
	local innerLeft = createPart(
		model,
		"InnerGlowLeft",
		Vector3.new(0.35, 9.5, 0.35),
		CFrame.new(center + Vector3.new(-4.9, 5.5, -0.45)),
		color,
		Enum.Material.Neon
	)
	local innerRight = createPart(
		model,
		"InnerGlowRight",
		Vector3.new(0.35, 9.5, 0.35),
		CFrame.new(center + Vector3.new(4.9, 5.5, -0.45)),
		color,
		Enum.Material.Neon
	)
	local innerTop = createPart(
		model,
		"InnerGlowTop",
		Vector3.new(10.2, 0.35, 0.35),
		CFrame.new(center + Vector3.new(0, 10.2, -0.45)),
		color,
		Enum.Material.Neon
	)
	innerLeft.CanCollide = false
	innerRight.CanCollide = false
	innerTop.CanCollide = false

	local portal = createPart(
		model,
		"Portal",
		Vector3.new(10, 9, 0.6),
		CFrame.new(center + Vector3.new(0, 5.5, 0)),
		color,
		Enum.Material.ForceField
	)
	portal.Transparency = 0.28
	portal.CanCollide = false

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 2
	light.Range = 18
	light.Parent = portal

	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(color)
	particles.LightEmission = 1
	particles.Lifetime = NumberRange.new(0.8, 1.5)
	particles.Rate = 10
	particles.Speed = NumberRange.new(0.4, 1.2)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Size = NumberSequence.new(0.16)
	particles.Parent = portal

	local sign = createPart(
		model,
		"Sign",
		Vector3.new(12, 3.8, 0.4),
		CFrame.new(center + Vector3.new(0, 14, 0)),
		Color3.fromRGB(17, 21, 34),
		Enum.Material.SmoothPlastic
	)
	addSurfaceLabel(sign, title .. "\n" .. subtitle, Enum.NormalId.Back, color)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LobbyPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = title
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 13
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal

	local pad = createPart(
		model,
		"PortalPad",
		Vector3.new(13, 0.5, 8),
		CFrame.new(center + Vector3.new(0, 0.5, 3)),
		color,
		Enum.Material.Neon
	)
	pad.Transparency = 0.35
	local step = createPart(
		model,
		"PortalStep",
		Vector3.new(15, 0.35, 3),
		CFrame.new(center + Vector3.new(0, 0.38, 7.5)),
		Color3.fromRGB(47, 54, 75),
		Enum.Material.DiamondPlate
	)
	step.CanCollide = true
	return prompt, portal
end

local function addLobbyArchitecture(root)
	local cyan = Color3.fromRGB(88, 224, 196)
	local blue = Color3.fromRGB(91, 120, 255)
	local violet = Color3.fromRGB(177, 110, 255)

	createPart(
		root,
		"LobbyCeiling",
		Vector3.new(LOBBY_WIDTH, 1, LOBBY_LENGTH),
		CFrame.new(ORIGIN + Vector3.new(0, 17.5, 0)),
		Color3.fromRGB(37, 47, 67),
		Enum.Material.Metal
	)
	createPart(
		root,
		"FrontWallLeft",
		Vector3.new(42, 17, 1),
		CFrame.new(ORIGIN + Vector3.new(-33, 8.5, 47)),
		Color3.fromRGB(51, 62, 84),
		Enum.Material.Metal
	)
	createPart(
		root,
		"FrontWallRight",
		Vector3.new(42, 17, 1),
		CFrame.new(ORIGIN + Vector3.new(33, 8.5, 47)),
		Color3.fromRGB(51, 62, 84),
		Enum.Material.Metal
	)
	createPart(
		root,
		"FrontWallCenter",
		Vector3.new(24, 17, 1),
		CFrame.new(ORIGIN + Vector3.new(0, 8.5, 47)),
		Color3.fromRGB(45, 56, 78),
		Enum.Material.Metal
	)

	local centralPlatform = createPart(
		root,
		"CentralPlatform",
		Vector3.new(32, 0.35, 68),
		CFrame.new(ORIGIN + Vector3.new(0, 0.68, 5)),
		Color3.fromRGB(71, 83, 108),
		Enum.Material.DiamondPlate
	)
	centralPlatform.CanCollide = true

	for _, xOffset in ipairs({ -38, 0, 38 }) do
		local strip = createPart(
			root,
			"CeilingLightStrip",
			Vector3.new(10, 0.22, 74),
			CFrame.new(ORIGIN + Vector3.new(xOffset, 16.88, 2)),
			if xOffset == 0 then cyan else blue,
			Enum.Material.Neon
		)
		strip.CanCollide = false
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Color = strip.Color
		light.Brightness = 2.1
		light.Range = 25
		light.Angle = 95
		light.Parent = strip
	end

	for _, side in ipairs({ -1, 1 }) do
		for index, zOffset in ipairs({ -35, -12, 12, 35 }) do
			local panel = createPart(
				root,
				"LobbyWallPanel",
				Vector3.new(0.3, 10, 16),
				CFrame.new(ORIGIN + Vector3.new(side * 53.35, 8, zOffset)),
				Color3.fromRGB(50, 60, 82),
				Enum.Material.DiamondPlate
			)
			panel.CanCollide = false
			local accent = createPart(
				root,
				"LobbyWallAccent",
				Vector3.new(0.16, 0.45, 13),
				CFrame.new(ORIGIN + Vector3.new(side * 53.14, 10.8, zOffset)),
				if index % 2 == 0 then violet else cyan,
				Enum.Material.Neon
			)
			accent.CanCollide = false
		end
	end

	for _, xOffset in ipairs({ -47, 47 }) do
		for _, zOffset in ipairs({ -40, 40 }) do
			local column = createPart(
				root,
				"SupportColumn",
				Vector3.new(3, 17, 3),
				CFrame.new(ORIGIN + Vector3.new(xOffset, 8.5, zOffset)),
				Color3.fromRGB(43, 50, 70),
				Enum.Material.Metal
			)
			local columnGlow = createPart(
				root,
				"ColumnGlow",
				Vector3.new(3.15, 0.35, 3.15),
				CFrame.new(ORIGIN + Vector3.new(xOffset, 11.8, zOffset)),
				violet,
				Enum.Material.Neon
			)
			columnGlow.CanCollide = false
			column.CanCollide = true
		end
	end

	local hubCore = createPart(
		root,
		"HubCore",
		Vector3.new(0.5, 9, 9),
		CFrame.new(ORIGIN + Vector3.new(0, 1.12, 18)),
		Color3.fromRGB(43, 51, 73),
		Enum.Material.Metal
	)
	hubCore.Shape = Enum.PartType.Cylinder
	hubCore.Orientation = Vector3.new(0, 0, 90)
	local coreGlow = createPart(
		root,
		"HubCoreGlow",
		Vector3.new(0.25, 6.5, 6.5),
		CFrame.new(ORIGIN + Vector3.new(0, 1.5, 18)),
		cyan,
		Enum.Material.Neon
	)
	coreGlow.Shape = Enum.PartType.Cylinder
	coreGlow.Orientation = Vector3.new(0, 0, 90)
	coreGlow.CanCollide = false
	addSurfaceLabel(coreGlow, "R", Enum.NormalId.Top, Color3.fromRGB(235, 255, 252))

	local launchParticles = Instance.new("ParticleEmitter")
	launchParticles.Name = "LaunchBurst"
	launchParticles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	launchParticles.Color = ColorSequence.new(cyan, violet)
	launchParticles.LightEmission = 1
	launchParticles.Lifetime = NumberRange.new(0.5, 1)
	launchParticles.Speed = NumberRange.new(8, 15)
	launchParticles.SpreadAngle = Vector2.new(35, 180)
	launchParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.28),
		NumberSequenceKeypoint.new(1, 0),
	})
	launchParticles.Rate = 0
	launchParticles.Parent = coreGlow
	return coreGlow
end

local function addQueueSpots(root, centerX)
	local spots = {}
	centerX = centerX or 0
	for row = 1, 3 do
		for column = 1, 2 do
			local xOffset = if column == 1 then -3.1 else 3.1
			local zOffset = -10.5 - (row - 1) * 5.4
			local spot = createPart(
				root,
				"QueueSpot_" .. tostring(#spots + 1),
				Vector3.new(4.8, 0.18, 4),
				CFrame.new(ORIGIN + Vector3.new(centerX + xOffset, 0.84, zOffset)),
				Color3.fromRGB(91, 120, 255),
				Enum.Material.Neon
			)
			spot.Transparency = 0.5
			spot.CanCollide = false
			addSurfaceLabel(spot, tostring(#spots + 1), Enum.NormalId.Top, Color3.fromRGB(226, 234, 255))
			table.insert(spots, spot)
		end
	end
	return spots
end

local function addLeaderboardBoard(root, name, position, rotationY, color, title)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = root

	local boardCFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotationY), 0)
	createPart(
		model,
		"BoardFrame",
		Vector3.new(44, 15.5, 1.2),
		boardCFrame,
		Color3.fromRGB(32, 39, 57),
		Enum.Material.Metal
	)
	local screen = createPart(
		model,
		"BoardScreen",
		Vector3.new(41.5, 13.2, 0.45),
		boardCFrame * CFrame.new(0, 0, 0.72),
		Color3.fromRGB(15, 20, 33),
		Enum.Material.SmoothPlastic
	)
	screen.CanCollide = false

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 35
	gui.Parent = screen

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0.94, 0, 0.2, 0)
	titleLabel.Position = UDim2.fromScale(0.03, 0.03)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = title
	titleLabel.TextColor3 = color
	titleLabel.TextScaled = true
	titleLabel.Parent = gui

	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(0.9, 0, 0, 4)
	divider.Position = UDim2.fromScale(0.05, 0.25)
	divider.BorderSizePixel = 0
	divider.BackgroundColor3 = color
	divider.Parent = gui

	local rows = Instance.new("TextLabel")
	rows.Name = "LeaderboardRows"
	rows.Size = UDim2.new(0.9, 0, 0.66, 0)
	rows.Position = UDim2.fromScale(0.05, 0.3)
	rows.BackgroundTransparency = 1
	rows.Font = Enum.Font.GothamBold
	rows.Text = "Loading leaderboard..."
	rows.TextColor3 = Color3.fromRGB(231, 237, 255)
	rows.TextSize = 27
	rows.TextWrapped = false
	rows.TextXAlignment = Enum.TextXAlignment.Left
	rows.TextYAlignment = Enum.TextYAlignment.Top
	rows.Parent = gui
	return rows
end

local function addDailyReactor(root)
	local model = Instance.new("Model")
	model.Name = "DailyReactor"
	model.Parent = root
	local position = ORIGIN + Vector3.new(-42, 0, 24)
	createPart(
		model,
		"ReactorBase",
		Vector3.new(9, 1.2, 7),
		CFrame.new(position + Vector3.new(0, 0.9, 0)),
		Color3.fromRGB(76, 88, 113),
		Enum.Material.DiamondPlate
	)
	local chamber = createPart(
		model,
		"ReactorChamber",
		Vector3.new(6, 4.5, 4.5),
		CFrame.new(position + Vector3.new(0, 4.1, -0.7)),
		Color3.fromRGB(255, 196, 92),
		Enum.Material.Glass
	)
	chamber.Shape = Enum.PartType.Cylinder
	chamber.Orientation = Vector3.new(0, 0, 90)
	chamber.Transparency = 0.32
	local core = createPart(
		model,
		"RewardCore",
		Vector3.new(2.7, 2.7, 2.7),
		CFrame.new(position + Vector3.new(0, 4.1, -0.7)),
		Color3.fromRGB(255, 177, 66),
		Enum.Material.Neon
	)
	core.Shape = Enum.PartType.Ball
	core.CanCollide = false
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "RewardBurst"
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 239, 170), Color3.fromRGB(255, 156, 72))
	particles.LightEmission = 1
	particles.Lifetime = NumberRange.new(0.6, 1.2)
	particles.Speed = NumberRange.new(3, 8)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0) })
	particles.Rate = 3
	particles.Parent = core
	local sign = createPart(
		model,
		"DailySign",
		Vector3.new(9, 3.3, 0.5),
		CFrame.new(position + Vector3.new(0, 8.2, -0.5)),
		Color3.fromRGB(48, 57, 78),
		Enum.Material.SmoothPlastic
	)
	addSurfaceLabel(sign, "DAILY REACTOR\n+50 SHARDS", Enum.NormalId.Back, Color3.fromRGB(255, 219, 143))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "CLAIM REWARD"
	prompt.ObjectText = "DAILY REACTOR"
	prompt.HoldDuration = 0.45
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = core
	return prompt, core
end

local function addRealityMixer(root)
	local model = Instance.new("Model")
	model.Name = "RealityMixer"
	model.Parent = root
	local position = ORIGIN + Vector3.new(-42, 0, 2)
	createPart(
		model,
		"MixerConsole",
		Vector3.new(13, 3, 7),
		CFrame.new(position + Vector3.new(0, 2, 0)),
		Color3.fromRGB(73, 86, 112),
		Enum.Material.DiamondPlate
	)
	local screen = createPart(
		model,
		"MixerScreen",
		Vector3.new(12, 3.2, 0.45),
		CFrame.new(position + Vector3.new(0, 6, -2.2)),
		Color3.fromRGB(66, 79, 105),
		Enum.Material.SmoothPlastic
	)
	local label = addSurfaceLabel(
		screen,
		"REALITY MIXER\nCHOOSE THE LOBBY ENERGY",
		Enum.NormalId.Back,
		Color3.fromRGB(230, 240, 255)
	)

	local choices = {
		{ Id = "Aqua", Color = Color3.fromRGB(70, 225, 218) },
		{ Id = "Violet", Color = Color3.fromRGB(177, 110, 255) },
		{ Id = "Sunrise", Color = Color3.fromRGB(255, 177, 66) },
	}
	local buttons = {}
	for index, choice in ipairs(choices) do
		local xOffset = (index - 2) * 4
		local button = createPart(
			model,
			"MixerButton_" .. choice.Id,
			Vector3.new(3.2, 0.8, 3.2),
			CFrame.new(position + Vector3.new(xOffset, 3.85, 1)),
			choice.Color,
			Enum.Material.Neon
		)
		button:SetAttribute("MixerId", choice.Id)
		button:SetAttribute("MixerColor", choice.Color)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "ACTIVATE"
		prompt.ObjectText = string.upper(choice.Id) .. " REALITY"
		prompt.HoldDuration = 0.15
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = button
		table.insert(buttons, { Prompt = prompt, Id = choice.Id, Color = choice.Color })
	end
	return buttons, label
end

local function addBriefingTerminal(root)
	local model = Instance.new("Model")
	model.Name = "BriefingTerminal"
	model.Parent = root
	local position = ORIGIN + Vector3.new(42, 0, 2)
	createPart(
		model,
		"BriefingBase",
		Vector3.new(11, 3, 7),
		CFrame.new(position + Vector3.new(0, 2, 0)),
		Color3.fromRGB(73, 86, 112),
		Enum.Material.DiamondPlate
	)
	local screen = createPart(
		model,
		"BriefingScreen",
		Vector3.new(10, 5, 0.5),
		CFrame.new(position + Vector3.new(0, 6, -2)),
		Color3.fromRGB(91, 120, 255),
		Enum.Material.Neon
	)
	screen.Transparency = 0.18
	local label = addSurfaceLabel(
		screen,
		"FIELD BRIEFING\nPRESS TO DECODE A TIP",
		Enum.NormalId.Back,
		Color3.fromRGB(235, 242, 255)
	)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "DECODE BRIEFING"
	prompt.ObjectText = "FIELD TERMINAL"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = screen
	return prompt, label
end

function LobbyBuilder.Build()
	local previous = workspace:FindFirstChild(LOBBY_NAME)
	if previous then
		previous:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = LOBBY_NAME
	root.Parent = workspace

	createPart(
		root,
		"LobbyFloor",
		Vector3.new(LOBBY_WIDTH, 1, LOBBY_LENGTH),
		CFrame.new(ORIGIN),
		Color3.fromRGB(61, 72, 94),
		Enum.Material.Slate
	)
	createPart(
		root,
		"BackWall",
		Vector3.new(LOBBY_WIDTH, 17, 1),
		CFrame.new(ORIGIN + Vector3.new(0, 8.5, -47)),
		Color3.fromRGB(51, 62, 84),
		Enum.Material.Metal
	)
	createPart(
		root,
		"LeftWall",
		Vector3.new(1, 17, LOBBY_LENGTH),
		CFrame.new(ORIGIN + Vector3.new(-54, 8.5, 0)),
		Color3.fromRGB(51, 62, 84),
		Enum.Material.Metal
	)
	createPart(
		root,
		"RightWall",
		Vector3.new(1, 17, LOBBY_LENGTH),
		CFrame.new(ORIGIN + Vector3.new(54, 8.5, 0)),
		Color3.fromRGB(51, 62, 84),
		Enum.Material.Metal
	)
	local launchPad = addLobbyArchitecture(root)

	local header = createPart(
		root,
		"LobbyHeader",
		Vector3.new(48, 7, 0.6),
		CFrame.new(ORIGIN + Vector3.new(0, 11.5, 46.4)),
		Color3.fromRGB(38, 48, 67),
		Enum.Material.SmoothPlastic
	)
	addSurfaceLabel(
		header,
		"REALITY EXPEDITION HUB\nCHOOSE YOUR NEXT RUN",
		Enum.NormalId.Front,
		Color3.fromRGB(88, 224, 196)
	)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(ORIGIN + Vector3.new(0, 1, 38))
	spawn.Color = Color3.fromRGB(88, 224, 196)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.4
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = root

	local soloPrompt, soloPortal = addPortal(
		root,
		"SoloPortal",
		ORIGIN + Vector3.new(-17, 0, -31),
		Color3.fromRGB(88, 224, 196),
		"SOLO RUN",
		"ENTER IMMEDIATELY",
		"START SOLO"
	)
	local groupPrompt, groupPortal = addPortal(
		root,
		"GroupPortal",
		ORIGIN + Vector3.new(17, 0, -31),
		Color3.fromRGB(91, 120, 255),
		"GROUP RUN",
		"2-6 EXPLORERS",
		"JOIN QUEUE"
	)

	local queueBoard = createPart(
		root,
		"GroupQueueBoard",
		Vector3.new(17, 5, 0.5),
		CFrame.new(ORIGIN + Vector3.new(17, 7.5, -18)),
		Color3.fromRGB(17, 21, 34),
		Enum.Material.SmoothPlastic
	)
	queueBoard.CanCollide = false
	local queueBoardLabel = addSurfaceLabel(
		queueBoard,
		"GROUP QUEUE\n0 / 6  •  WAITING",
		Enum.NormalId.Back,
		Color3.fromRGB(115, 151, 255)
	)
	local queueSpots = addQueueSpots(root, 17)
	local successBoardLabel = addLeaderboardBoard(
		root,
		"SuccessfulEscapesBoard",
		ORIGIN + Vector3.new(-53.8, 8.7, -19),
		90,
		Color3.fromRGB(70, 225, 218),
		"TOP SUCCESSFUL ESCAPES"
	)
	local failureBoardLabel = addLeaderboardBoard(
		root,
		"FailedEscapesBoard",
		ORIGIN + Vector3.new(53.8, 8.7, -19),
		-90,
		Color3.fromRGB(255, 112, 129),
		"HALL OF GLORIOUS FAILURES"
	)
	local dailyPrompt, dailyCore = addDailyReactor(root)
	local mixerButtons, mixerLabel = addRealityMixer(root)
	local briefingPrompt, briefingLabel = addBriefingTerminal(root)

	for index, zOffset in ipairs({ -20, 8, 34 }) do
		local strip = createPart(
			root,
			"FloorGuide_" .. tostring(index),
			Vector3.new(96, 0.12, 0.8),
			CFrame.new(ORIGIN + Vector3.new(0, 0.58, zOffset)),
			if index % 2 == 0 then Color3.fromRGB(91, 120, 255) else Color3.fromRGB(88, 224, 196),
			Enum.Material.Neon
		)
		strip.CanCollide = false
	end

	return {
		Root = root,
		Spawn = spawn,
		SoloPrompt = soloPrompt,
		GroupPrompt = groupPrompt,
		SoloPortal = soloPortal,
		GroupPortal = groupPortal,
		QueueBoardLabel = queueBoardLabel,
		QueueSpots = queueSpots,
		DailyPrompt = dailyPrompt,
		DailyCore = dailyCore,
		MixerButtons = mixerButtons,
		MixerLabel = mixerLabel,
		BriefingPrompt = briefingPrompt,
		BriefingLabel = briefingLabel,
		LaunchPad = launchPad,
		SuccessBoardLabel = successBoardLabel,
		FailureBoardLabel = failureBoardLabel,
	}
end

return LobbyBuilder
