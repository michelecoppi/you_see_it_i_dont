local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Puzzles = Shared:WaitForChild("Puzzles")
local Difficulty = require(Shared:WaitForChild("Difficulty"))
local PresetOrder = require(Shared:WaitForChild("PresetOrder"))
local SignalPuzzle = require(Puzzles:WaitForChild("Signal"))
local PhaseFloorPuzzle = require(Puzzles:WaitForChild("PhaseFloor"))
local EchoSequencePuzzle = require(Puzzles:WaitForChild("EchoSequence"))
local FrequencyDialsPuzzle = require(Puzzles:WaitForChild("FrequencyDials"))
local MirrorRelayPuzzle = require(Puzzles:WaitForChild("MirrorRelay"))
local PowerGridPuzzle = require(Puzzles:WaitForChild("PowerGrid"))
local RuneCircuitPuzzle = require(Puzzles:WaitForChild("RuneCircuit"))
local InteractionValidator = require(script.Parent:WaitForChild("InteractionValidator"))

local RoomGenerator = {}
RoomGenerator.__index = RoomGenerator

local ROOM_CENTERS = { -45, -4, 37 }
local ROOM_ENDS = { -24, 17, 58 }
local PRESETS = { "Signal", "PhaseFloor", "EchoSequence", "FrequencyDials", "PowerGrid", "MirrorRelay", "RuneCircuit" }
local FLOOR_SURFACE_CLEARANCE = 0.01
local ROOM_THRESHOLD_HEIGHT = 0.1
local PHASE_CHASM_HEIGHT = 0.06
local GEOMETRY_CLEARANCE = 0.02

local GEOMETRY_ROLES = {
	Blocker = "Blocker",
	Console = "Console",
	Gate = "Gate",
	Path = "Path",
	Spawn = "Spawn",
	Support = "Support",
}

local VALIDATED_GEOMETRY_ROLES = {
	[GEOMETRY_ROLES.Console] = true,
	[GEOMETRY_ROLES.Gate] = true,
	[GEOMETRY_ROLES.Path] = true,
	[GEOMETRY_ROLES.Spawn] = true,
}

local FLOOR_OVERLAY_NAMES = {
	RoomThreshold = true,
	RoomFloorTrim = true,
	PhaseChasm = true,
}

local COLORS = {
	Metal = Color3.fromRGB(76, 88, 116),
	Dark = Color3.fromRGB(34, 43, 61),
	Cyan = Color3.fromRGB(70, 225, 218),
	Violet = Color3.fromRGB(177, 110, 255),
	Blue = Color3.fromRGB(91, 120, 255),
}

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

local function markGeometry(part, role, group)
	part:SetAttribute("GeometryRole", role)
	if group then
		part:SetAttribute("GeometryGroup", group)
	end
	return part
end

local function addSurfaceText(part, text, face, color)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "RoomLabel"
	gui.Face = face or Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 36
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(239, 243, 255)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui
	return label, gui
end

local function addBillboard(part, text, color, size, offset)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HiddenClue"
	gui.Size = size or UDim2.fromOffset(300, 80)
	gui.StudsOffset = offset or Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = COLORS.Dark
	label.BackgroundTransparency = 0.08
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = label
	return gui
end

local function markForRole(instance, role)
	instance:SetAttribute("VisibleToRole", role)
	instance:SetAttribute("RequiresRoomActive", true)
	instance:SetAttribute("RoomActive", false)
end

local function markRoomActive(instance)
	instance:SetAttribute("RequiresRoomActive", true)
	instance:SetAttribute("RoomActive", false)
end

local function makePrompt(part, actionText, objectText, role, interactionAction)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RoomPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	markForRole(prompt, role)
	prompt:SetAttribute("InteractionAction", interactionAction)
	prompt.Parent = part
	return prompt
end

local function playerFromHit(hit)
	local character = hit and hit:FindFirstAncestorOfClass("Model")
	return if character then Players:GetPlayerFromCharacter(character) else nil
end

local function getPresetColor(preset)
	if preset == "Signal" then
		return COLORS.Cyan
	elseif preset == "PhaseFloor" then
		return COLORS.Violet
	elseif preset == "EchoSequence" then
		return COLORS.Blue
	elseif preset == "FrequencyDials" then
		return Color3.fromRGB(255, 177, 66)
	elseif preset == "MirrorRelay" then
		return Color3.fromRGB(92, 225, 255)
	elseif preset == "RuneCircuit" then
		return Color3.fromRGB(255, 126, 210)
	end
	return Color3.fromRGB(94, 255, 151)
end

local function signalLabel(signal)
	return tostring(signal.Symbol or signal.DisplayName) .. " " .. tostring(signal.DisplayName)
end

local function geometryRole(part, spawnPart)
	if part == spawnPart then
		return GEOMETRY_ROLES.Spawn
	end

	local role = part:GetAttribute("GeometryRole")
	if role == GEOMETRY_ROLES.Support or part.Name == "Floor" or string.match(part.Name, "^ChamberDeck_") then
		return nil
	end
	if role then
		return role
	end
	return if part.CanCollide then GEOMETRY_ROLES.Blocker else nil
end

local function geometryPath(part, root)
	local names = {}
	local cursor = part
	while cursor and cursor ~= root do
		table.insert(names, 1, cursor.Name)
		cursor = cursor.Parent
	end
	return table.concat(names, "/")
end

function RoomGenerator.new(mapRoot, spawnPart, config, callbacks)
	local self = setmetatable({}, RoomGenerator)
	self._mapRoot = mapRoot
	self._spawnPart = spawnPart
	self._config = config
	self._callbacks = callbacks or {}
	self._rooms = {}
	self._connections = {}
	self._folder = nil
	self._active = false
	self._currentRoomIndex = 0
	self._goalUnlocked = false
	self._lastConsoleInteraction = {}
	self._lastGoalTouch = {}
	return self
end

function RoomGenerator:_addSeerClue(room, clue)
	room.SeerClues = room.SeerClues or {}
	clue.RoomIndex = room.Index
	table.insert(room.SeerClues, clue)
end

function RoomGenerator:_addSeerBillboard(room, anchor, id, text, color, size, offset)
	self:_addSeerClue(room, {
		Id = id,
		Kind = "Billboard",
		AnchorName = anchor.Name,
		Text = text,
		Color = color,
		Size = size or UDim2.fromOffset(300, 80),
		Offset = offset or Vector3.new(0, 4, 0),
	})
end

function RoomGenerator:_addSeerPart(room, id, name, size, cframe, color, material, shape, transparency)
	self:_addSeerClue(room, {
		Id = id,
		Kind = "Part",
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = (material or Enum.Material.SmoothPlastic).Name,
		Shape = shape and shape.Name or nil,
		Transparency = transparency or 0,
	})
end

function RoomGenerator:_connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(self._connections, connection)
	return connection
end

function RoomGenerator:_isParticipant(player)
	return player and self._callbacks.IsParticipant and self._callbacks.IsParticipant(player)
end

function RoomGenerator:_floorOverlayY(room, height)
	local deck = self._mapRoot:FindFirstChild("ChamberDeck_" .. tostring(room.Index))
	local deckTop = 0.5
	if deck and deck:IsA("BasePart") then
		deckTop = deck.Position.Y + deck.Size.Y * 0.5
	end
	return deckTop + FLOOR_SURFACE_CLEARANCE + height * 0.5
end

function RoomGenerator:_canOperate(player)
	local role = player:GetAttribute("Role")
	return role == self._config.Roles.Operator or role == self._config.Roles.Hybrid
end

function RoomGenerator:_canUseConsole(player, room, prompt, action)
	if not self:_isParticipant(player) or not self:_canOperate(player) then
		return false
	end
	if self._callbacks.IsVisionActive and self._callbacks.IsVisionActive(player) then
		return false
	end

	local interactionConfig = self._config.Interactions or {}
	local valid = InteractionValidator.ValidateConsole(player, room, prompt, {
		GeneratorActive = self._active,
		ActiveRoomIndex = self._currentRoomIndex,
		DistanceTolerance = interactionConfig.ConsoleDistanceTolerance,
		RoomContainer = self._folder,
		OperatorRole = self._config.Roles.Operator,
		Action = action,
	})
	if not valid then
		return false
	end
	if self._callbacks.AllowPuzzleAction and not self._callbacks.AllowPuzzleAction(player, action) then
		return false
	end

	local cooldowns = interactionConfig.ConsoleCooldowns or {}
	local cooldown = cooldowns[action] or interactionConfig.DefaultConsoleCooldown or 0.25
	local playerCooldowns = self._lastConsoleInteraction[player]
	if not playerCooldowns then
		playerCooldowns = {}
		self._lastConsoleInteraction[player] = playerCooldowns
	end
	local now = os.clock()
	local lastInteractionAt = playerCooldowns[action]
	if lastInteractionAt and now - lastInteractionAt < math.max(0, cooldown) then
		return false
	end
	playerCooldowns[action] = now
	return true
end

function RoomGenerator:_status(message)
	if self._callbacks.OnStatus then
		self._callbacks.OnStatus(message)
	end
end

function RoomGenerator:_interaction(player, room, action)
	room.Interactions = room.Interactions or {}
	room.Interactions[player] = (room.Interactions[player] or 0) + 1
	if self._callbacks.OnPuzzleInteraction then
		self._callbacks.OnPuzzleInteraction(player, room.Preset, action)
	end
end

function RoomGenerator:_mistake(player, message, room)
	if self._callbacks.OnMistake then
		self._callbacks.OnMistake(player, self._config.Round.WrongAnswerPenalty, message, room and room.Preset)
	end
end

function RoomGenerator:_buildGate(parent, index, endZ)
	markGeometry(
		createPart(
			parent,
			"GateWallLeft",
			Vector3.new(25, 18, 1.2),
			CFrame.new(-21.5, 9, endZ),
			COLORS.Metal,
			Enum.Material.Metal
		),
		GEOMETRY_ROLES.Blocker
	)
	markGeometry(
		createPart(
			parent,
			"GateWallRight",
			Vector3.new(25, 18, 1.2),
			CFrame.new(21.5, 9, endZ),
			COLORS.Metal,
			Enum.Material.Metal
		),
		GEOMETRY_ROLES.Blocker
	)

	local gate = createPart(
		parent,
		"RoomGate_" .. tostring(index),
		Vector3.new(18, 11, 1.1),
		CFrame.new(0, 5.9, endZ),
		if index % 2 == 0 then COLORS.Blue else COLORS.Violet,
		Enum.Material.ForceField
	)
	gate.Transparency = 0.12
	markGeometry(gate, GEOMETRY_ROLES.Gate, "Gate_" .. tostring(index))
	return gate
end

function RoomGenerator:_openGate(room)
	room.Gate.CanCollide = false
	TweenService:Create(room.Gate, TweenInfo.new(0.75, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = room.GateClosedCFrame + Vector3.new(0, 13, 0),
		Transparency = 0.58,
	}):Play()
end

function RoomGenerator:_setRoomActive(room, active)
	room.Active = active
	if active then
		room.StartedAt = os.clock()
		if not room.StartReported then
			room.StartReported = true
			if self._callbacks.OnRoomStarted then
				self._callbacks.OnRoomStarted(room.Index, room.Preset, room.DisplayName)
			end
		end
	end
	for _, instance in ipairs(room.Model:GetDescendants()) do
		if instance:GetAttribute("RequiresRoomActive") then
			instance:SetAttribute("RoomActive", active)
			if instance:IsA("ProximityPrompt") then
				instance.Enabled = active
			end
		end
	end
end

function RoomGenerator:_completeRoom(room, player)
	if not self._active or not room.Active or room.Index ~= self._currentRoomIndex then
		return
	end

	self:_setRoomActive(room, false)
	self:_openGate(room)
	local elapsed = math.max(0, os.clock() - (room.StartedAt or os.clock()))
	if self._callbacks.OnRoomCompleted then
		self._callbacks.OnRoomCompleted(
			player,
			room.Index,
			room.Preset,
			room.DisplayName,
			elapsed,
			room.Interactions or {}
		)
	end
	self._currentRoomIndex += 1

	local nextRoom = self._rooms[self._currentRoomIndex]
	if nextRoom then
		self:_setRoomActive(nextRoom, true)
		self:_status(
			player.DisplayName .. " completed " .. room.DisplayName .. ". Next: " .. nextRoom.DisplayName .. "!"
		)
	else
		self._goalUnlocked = true
		self:_status("All mini-rooms stabilized. Reach the extraction pad!")
	end
end

function RoomGenerator:_buildMirrorRelayRoom(room, randomGenerator, difficulty)
	room.DisplayName = "Mirror Relay"
	self:_addRoomHeader(
		room,
		"MIRROR RELAY",
		"ALIGN EVERY REFLECTOR WITH THE HIDDEN ROUTE",
		Color3.fromRGB(92, 225, 255)
	)

	local orientationNames = { "NE", "SE", "SW", "NW" }
	local solution = MirrorRelayPuzzle.GenerateSolution(randomGenerator, difficulty)
	local state = MirrorRelayPuzzle.BuildInitialState(solution)
	local targetNames = table.create(#solution.Targets)
	for index, target in ipairs(solution.Targets) do
		targetNames[index] = orientationNames[target]
	end

	local routeDisplay = createPart(
		room.Model,
		"MirrorRouteDisplay",
		Vector3.new(22, 5.5, 0.7),
		CFrame.new(0, 6, room.CenterZ - 9),
		COLORS.Dark,
		Enum.Material.Metal
	)
	routeDisplay.CanCollide = false
	markRoomActive(routeDisplay)
	self:_addSeerBillboard(
		room,
		routeDisplay,
		"MirrorRoute",
		"ALIGN  " .. table.concat(targetNames, "  >  "),
		Color3.fromRGB(170, 244, 255),
		UDim2.fromOffset(520, 86),
		Vector3.new(0, 0, 0)
	)

	for index, initialOrientation in ipairs(state.Orientations) do
		local x = (index - (#state.Orientations + 1) / 2) * 10
		local base = createPart(
			room.Model,
			"MirrorBase_" .. tostring(index),
			Vector3.new(7, 2, 6),
			CFrame.new(x, 1.4, room.CenterZ + 8),
			COLORS.Metal,
			Enum.Material.DiamondPlate
		)
		local mirror = createPart(
			room.Model,
			"RelayMirror_" .. tostring(index),
			Vector3.new(0.6, 5, 4.5),
			CFrame.new(x, 4.6, room.CenterZ + 8) * CFrame.Angles(0, math.rad((initialOrientation - 1) * 45), 0),
			Color3.fromRGB(170, 244, 255),
			Enum.Material.Glass
		)
		mirror.Reflectance = 0.35
		local geometryGroup = string.format("Console_%d_%d", room.Index, index)
		markGeometry(base, GEOMETRY_ROLES.Console, geometryGroup)
		markGeometry(mirror, GEOMETRY_ROLES.Console, geometryGroup)
		local readout = addBillboard(
			mirror,
			orientationNames[initialOrientation],
			Color3.fromRGB(170, 244, 255),
			UDim2.fromOffset(86, 56),
			Vector3.new(0, 3.6, 0)
		)
		local readoutLabel = readout:FindFirstChildOfClass("TextLabel")
		local prompt =
			makePrompt(mirror, "ROTATE +45", "MIRROR " .. tostring(index), self._config.Roles.Operator, "MirrorRotate")

		self:_connect(prompt.Triggered, function(player)
			if not self:_canUseConsole(player, room, prompt, "MirrorRotate") then
				return
			end
			self:_interaction(player, room, "MirrorRotate")
			local solved = MirrorRelayPuzzle.Rotate(solution, state, index)
			local orientation = state.Orientations[index]
			mirror.CFrame = CFrame.new(mirror.Position) * CFrame.Angles(0, math.rad((orientation - 1) * 45), 0)
			readoutLabel.Text = orientationNames[orientation]
			if solved then
				self:_completeRoom(room, player)
			else
				self:_status("Mirror " .. tostring(index) .. " aligned " .. orientationNames[orientation] .. ".")
			end
		end)
	end
end

function RoomGenerator:_buildRuneCircuitRoom(room, randomGenerator, difficulty)
	room.DisplayName = "Rune Circuit"
	self:_addRoomHeader(
		room,
		"RUNE CIRCUIT",
		"SEER DECODES THE ORDER - OPERATOR LINKS IT",
		Color3.fromRGB(255, 126, 210)
	)

	local runes = {
		{ Name = "SUN", Color = Color3.fromRGB(255, 194, 92) },
		{ Name = "MOON", Color = Color3.fromRGB(150, 176, 255) },
		{ Name = "STAR", Color = Color3.fromRGB(255, 245, 155) },
		{ Name = "WAVE", Color = Color3.fromRGB(92, 225, 255) },
		{ Name = "EYE", Color = Color3.fromRGB(255, 126, 210) },
	}
	local solution = RuneCircuitPuzzle.GenerateSolution(randomGenerator, difficulty)
	local state = RuneCircuitPuzzle.BuildInitialState(solution)
	local targetNames = table.create(#solution.SequenceIndices)
	for index, runeIndex in ipairs(solution.SequenceIndices) do
		targetNames[index] = runes[runeIndex].Name
	end

	local circuitDisplay = createPart(
		room.Model,
		"RuneCircuitDisplay",
		Vector3.new(22, 5.5, 0.7),
		CFrame.new(0, 6, room.CenterZ - 9),
		COLORS.Dark,
		Enum.Material.Metal
	)
	circuitDisplay.CanCollide = false
	markRoomActive(circuitDisplay)
	self:_addSeerBillboard(
		room,
		circuitDisplay,
		"RuneOrder",
		table.concat(targetNames, "  >  "),
		Color3.fromRGB(255, 190, 230),
		UDim2.fromOffset(520, 86),
		Vector3.new(0, 0, 0)
	)
	local progressLabel, progressGui = addSurfaceText(
		circuitDisplay,
		"LINK 0 / " .. tostring(#solution.SequenceIndices),
		Enum.NormalId.Front,
		Color3.fromRGB(255, 190, 230)
	)
	markRoomActive(progressGui)

	for index, rune in ipairs(runes) do
		local x = (3 - index) * 12
		local base = createPart(
			room.Model,
			"RuneBase_" .. tostring(index),
			Vector3.new(7, 2, 7),
			CFrame.new(x, 1.4, room.CenterZ + 8),
			COLORS.Metal,
			Enum.Material.DiamondPlate
		)
		local button = createPart(
			room.Model,
			"RuneButton_" .. tostring(index),
			Vector3.new(5, 1, 4.6),
			CFrame.new(x, 2.8, room.CenterZ + 8),
			rune.Color,
			Enum.Material.Neon
		)
		local geometryGroup = string.format("Console_%d_%d", room.Index, index)
		markGeometry(base, GEOMETRY_ROLES.Console, geometryGroup)
		markGeometry(button, GEOMETRY_ROLES.Console, geometryGroup)
		addSurfaceText(base, rune.Name, Enum.NormalId.Front, rune.Color)
		local prompt = makePrompt(button, "LINK", rune.Name .. " RUNE", self._config.Roles.Operator, "RuneButton")

		self:_connect(prompt.Triggered, function(player)
			if room.Busy or not self:_canUseConsole(player, room, prompt, "RuneButton") then
				return
			end
			self:_interaction(player, room, "RuneButton")
			room.Busy = true
			local solved, advanceReason = RuneCircuitPuzzle.Advance(solution, state, index)
			if advanceReason == "wrong" then
				progressLabel.Text = "LINK 0 / " .. tostring(#solution.SequenceIndices)
				self:_mistake(player, "Wrong rune. The circuit reset!", room)
			else
				progressLabel.Text = "LINK "
					.. tostring(state.Progress - 1)
					.. " / "
					.. tostring(#solution.SequenceIndices)
				if solved then
					self:_completeRoom(room, player)
				else
					self:_status(
						"Rune accepted: "
							.. tostring(state.Progress - 1)
							.. " / "
							.. tostring(#solution.SequenceIndices)
					)
				end
			end
			task.delay(0.45, function()
				room.Busy = false
			end)
		end)
	end
end

function RoomGenerator:_buildFrequencyRoom(room, randomGenerator, difficulty)
	room.DisplayName = "Frequency Vault"
	self:_addRoomHeader(room, "FREQUENCY VAULT", "MATCH THE THREE HIDDEN CHANNELS", Color3.fromRGB(255, 177, 66))

	local solution = FrequencyDialsPuzzle.GenerateSolution(randomGenerator, difficulty)
	local state = FrequencyDialsPuzzle.BuildInitialState(solution)
	local targets = solution.Targets
	local values = state.Values

	local receiver = createPart(
		room.Model,
		"FrequencyReceiver",
		Vector3.new(17, 6, 0.7),
		CFrame.new(0, 6, room.CenterZ - 9),
		COLORS.Dark,
		Enum.Material.Metal
	)
	receiver.CanCollide = false
	markRoomActive(receiver)
	self:_addSeerBillboard(
		room,
		receiver,
		"FrequencyTarget",
		"TARGET  " .. tostring(targets[1]) .. "  |  " .. tostring(targets[2]) .. "  |  " .. tostring(targets[3]),
		Color3.fromRGB(255, 196, 92),
		UDim2.fromOffset(390, 82),
		Vector3.new(0, 0, 0)
	)

	local function isSolved()
		return FrequencyDialsPuzzle.Validate(solution, state)
	end

	for index = 1, 3 do
		local x = (2 - index) * 12
		local pedestal = createPart(
			room.Model,
			"DialPedestal_" .. tostring(index),
			Vector3.new(7, 2.2, 7),
			CFrame.new(x, 1.5, room.CenterZ + 8),
			COLORS.Metal,
			Enum.Material.DiamondPlate
		)
		local dial = createPart(
			room.Model,
			"FrequencyDial_" .. tostring(index),
			Vector3.new(1, 4.8, 4.8),
			CFrame.new(x, 3.1, room.CenterZ + 8),
			Color3.fromRGB(255, 177, 66),
			Enum.Material.Neon
		)
		dial.Shape = Enum.PartType.Cylinder
		dial.Orientation = Vector3.new(0, 0, 90)
		local geometryGroup = string.format("Console_%d_%d", room.Index, index)
		markGeometry(pedestal, GEOMETRY_ROLES.Console, geometryGroup)
		markGeometry(dial, GEOMETRY_ROLES.Console, geometryGroup)
		local readout = addBillboard(
			dial,
			tostring(values[index]),
			Color3.fromRGB(255, 221, 156),
			UDim2.fromOffset(90, 70),
			Vector3.new(0, 3, 0)
		)
		local readoutLabel = readout:FindFirstChildOfClass("TextLabel")
		local prompt =
			makePrompt(dial, "TUNE +1", "CHANNEL " .. tostring(index), self._config.Roles.Operator, "FrequencyDial")
		pedestal.CanCollide = true

		self:_connect(prompt.Triggered, function(player)
			if not self:_canUseConsole(player, room, prompt, "FrequencyDial") then
				return
			end
			self:_interaction(player, room, "FrequencyDial")
			values[index] = (values[index] % 4) + 1
			readoutLabel.Text = tostring(values[index])
			if isSolved() then
				self:_completeRoom(room, player)
			else
				self:_status("Frequency channel " .. tostring(index) .. " tuned to " .. tostring(values[index]) .. ".")
			end
		end)
	end
end

function RoomGenerator:_buildPowerGridRoom(room, randomGenerator, difficulty)
	room.DisplayName = "Power Grid"
	self:_addRoomHeader(room, "POWER GRID", "SWITCHES ALSO TOGGLE THEIR NEIGHBORS", Color3.fromRGB(94, 255, 151))

	local nodeCount = 5
	local solution = PowerGridPuzzle.GenerateSolution(randomGenerator, difficulty)
	local state = PowerGridPuzzle.BuildInitialState(solution)
	local target = solution.Target
	local current = state.Current
	local targetWords = {}
	for index = 1, nodeCount do
		targetWords[index] = if target[index] then "ON" else "OFF"
	end
	local gridDisplay = createPart(
		room.Model,
		"GridTargetDisplay",
		Vector3.new(20, 5.5, 0.7),
		CFrame.new(0, 6, room.CenterZ - 9),
		COLORS.Dark,
		Enum.Material.Metal
	)
	gridDisplay.CanCollide = false
	markRoomActive(gridDisplay)
	self:_addSeerBillboard(
		room,
		gridDisplay,
		"PowerGridTarget",
		table.concat(targetWords, "  "),
		Color3.fromRGB(94, 255, 151),
		UDim2.fromOffset(470, 82),
		Vector3.new(0, 0, 0)
	)

	local indicators = {}
	local function refreshIndicators()
		for index, indicator in ipairs(indicators) do
			indicator.Color = if current[index] then Color3.fromRGB(94, 255, 151) else Color3.fromRGB(64, 72, 91)
			indicator.Material = if current[index] then Enum.Material.Neon else Enum.Material.Metal
		end
	end
	local function isSolved()
		return PowerGridPuzzle.Validate(solution, state)
	end

	for index = 1, nodeCount do
		local x = (3 - index) * 6
		local base = createPart(
			room.Model,
			"GridNodeBase_" .. tostring(index),
			Vector3.new(4.6, 2, 5.5),
			CFrame.new(x, 1.4, room.CenterZ + 8),
			COLORS.Metal,
			Enum.Material.DiamondPlate
		)
		local indicator = createPart(
			room.Model,
			"GridNode_" .. tostring(index),
			Vector3.new(3.2, 1, 3.2),
			CFrame.new(x, 2.9, room.CenterZ + 8),
			Color3.fromRGB(64, 72, 91),
			Enum.Material.Metal
		)
		local geometryGroup = string.format("Console_%d_%d", room.Index, index)
		markGeometry(base, GEOMETRY_ROLES.Console, geometryGroup)
		markGeometry(indicator, GEOMETRY_ROLES.Console, geometryGroup)
		table.insert(indicators, indicator)
		local prompt =
			makePrompt(indicator, "TOGGLE", "GRID NODE " .. tostring(index), self._config.Roles.Operator, "GridNode")
		base.CanCollide = true

		self:_connect(prompt.Triggered, function(player)
			if not self:_canUseConsole(player, room, prompt, "GridNode") then
				return
			end
			self:_interaction(player, room, "GridNode")
			for affected = math.max(1, index - 1), math.min(nodeCount, index + 1) do
				current[affected] = not current[affected]
			end
			refreshIndicators()
			if isSolved() then
				self:_completeRoom(room, player)
			else
				self:_status("Power grid changed. Remember: adjacent nodes toggle too.")
			end
		end)
	end
	refreshIndicators()
end

function RoomGenerator:_addRoomHeader(room, title, subtitle, color)
	local sign = createPart(
		room.Model,
		"RoomHeader",
		Vector3.new(0.35, 5.4, 18),
		CFrame.new(-33.82, 10.2, room.CenterZ - 8),
		COLORS.Dark,
		Enum.Material.SmoothPlastic
	)
	sign.CanCollide = false
	local headerText = string.format("ROOM %02d  |  %s\n%s", room.Index, title, subtitle)
	local _, headerGui = addSurfaceText(sign, headerText, Enum.NormalId.Right, color)
	markRoomActive(sign)
	markRoomActive(headerGui)

	local threshold = createPart(
		room.Model,
		"RoomThreshold",
		Vector3.new(21, ROOM_THRESHOLD_HEIGHT, 0.8),
		CFrame.new(0, self:_floorOverlayY(room, ROOM_THRESHOLD_HEIGHT), room.CenterZ - 17),
		color,
		Enum.Material.Neon
	)
	threshold.CanCollide = false
end

function RoomGenerator:_decorateRoom(room)
	local color = getPresetColor(room.Preset)
	for _, side in ipairs({ -1, 1 }) do
		for _, zOffset in ipairs({ -14, 14 }) do
			local pylon = createPart(
				room.Model,
				"RoomPylon",
				Vector3.new(2.2, 9, 2.2),
				CFrame.new(side * 30.5, 4.8, room.CenterZ + zOffset),
				COLORS.Metal,
				Enum.Material.DiamondPlate
			)
			local glow = createPart(
				room.Model,
				"PylonGlow",
				Vector3.new(2.35, 0.35, 2.35),
				CFrame.new(side * 30.5, 8.2, room.CenterZ + zOffset),
				color,
				Enum.Material.Neon
			)
			glow.CanCollide = false
			pylon.CanCollide = true
			markGeometry(pylon, GEOMETRY_ROLES.Blocker)
		end

		local sideConsole = createPart(
			room.Model,
			"AmbientConsole",
			Vector3.new(1.2, 4.5, 9),
			CFrame.new(side * 32.5, 4.2, room.CenterZ),
			Color3.fromRGB(55, 67, 91),
			Enum.Material.Metal
		)
		sideConsole.CanCollide = false
		local display = createPart(
			room.Model,
			"AmbientDisplay",
			Vector3.new(0.3, 2.8, 7.2),
			CFrame.new(side * 31.82, 5, room.CenterZ),
			color,
			Enum.Material.Neon
		)
		display.Transparency = 0.28
		display.CanCollide = false
	end

	for _, zOffset in ipairs({ -16, 16 }) do
		local floorTrim = createPart(
			room.Model,
			"RoomFloorTrim",
			Vector3.new(58, 0.12, 0.45),
			CFrame.new(0, 0.76, room.CenterZ + zOffset),
			color,
			Enum.Material.Neon
		)
		floorTrim.CanCollide = false
	end

	local projector = createPart(
		room.Model,
		"CeilingProjector",
		Vector3.new(5, 0.8, 5),
		CFrame.new(0, 16.5, room.CenterZ),
		COLORS.Metal,
		Enum.Material.Metal
	)
	projector.CanCollide = false
	local projectorGlow = createPart(
		room.Model,
		"ProjectorGlow",
		Vector3.new(3.2, 0.18, 3.2),
		CFrame.new(0, 16.02, room.CenterZ),
		color,
		Enum.Material.Neon
	)
	projectorGlow.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 2.1
	light.Range = 22
	light.Parent = projectorGlow
end

function RoomGenerator:_buildSignalRoom(room, randomGenerator, difficulty)
	room.DisplayName = "Signal Chamber"
	self:_addRoomHeader(room, "SIGNAL CHAMBER", "SEER READS • OPERATOR ACTIVATES", COLORS.Cyan)

	local solution = SignalPuzzle.GenerateSolution(randomGenerator, difficulty)
	local state = SignalPuzzle.BuildInitialState(solution)
	local sequenceNames = table.create(#solution.SequenceIndices)
	for position, signalIndex in ipairs(solution.SequenceIndices) do
		sequenceNames[position] = signalLabel(self._config.Signals[signalIndex])
	end
	local firstSignal = self._config.Signals[solution.SequenceIndices[1]]
	local beaconBase = createPart(
		room.Model,
		"SignalBase",
		Vector3.new(5, 1, 5),
		CFrame.new(0, 1, room.CenterZ - 8),
		COLORS.Metal,
		Enum.Material.Metal
	)
	self:_addSeerPart(
		room,
		"SignalBeacon",
		"SignalBeacon",
		Vector3.new(3, 3, 3),
		CFrame.new(0, 3.1, room.CenterZ - 8),
		firstSignal.Color,
		Enum.Material.Neon,
		firstSignal.Shape or Enum.PartType.Ball
	)
	self:_addSeerClue(room, {
		Id = "SignalReadout",
		Kind = "Billboard",
		AnchorName = "SignalBeacon",
		Text = "SIGNAL: " .. table.concat(sequenceNames, "  >  "),
		Color = firstSignal.Color,
		Size = UDim2.fromOffset(300, 80),
		Offset = Vector3.new(0, 4, 0),
	})
	beaconBase.CanCollide = true

	for index, signal in ipairs(self._config.Signals) do
		local x = (2 - index) * 12
		local base = createPart(
			room.Model,
			"ConsoleBase_" .. signal.Id,
			Vector3.new(7, 2, 7),
			CFrame.new(x, 1.4, room.CenterZ + 8),
			COLORS.Metal,
			Enum.Material.Metal
		)
		local button = createPart(
			room.Model,
			"SignalButton_" .. signal.Id,
			Vector3.new(5, 1, 4.6),
			CFrame.new(x, 2.8, room.CenterZ + 8),
			signal.Color,
			Enum.Material.Neon
		)
		local geometryGroup = string.format("Console_%d_%d", room.Index, index)
		markGeometry(base, GEOMETRY_ROLES.Console, geometryGroup)
		markGeometry(button, GEOMETRY_ROLES.Console, geometryGroup)
		local marker = createPart(
			room.Model,
			"SignalMarker_" .. signal.Id,
			Vector3.new(1.8, 1.8, 1.8),
			CFrame.new(x, 4.15, room.CenterZ + 8),
			signal.Color,
			Enum.Material.Neon
		)
		marker.Shape = signal.Shape or Enum.PartType.Block
		marker.CanCollide = false
		markGeometry(marker, GEOMETRY_ROLES.Console, geometryGroup)
		addSurfaceText(base, signalLabel(signal), Enum.NormalId.Front, signal.Color)
		local prompt = makePrompt(
			button,
			"ACTIVATE",
			signalLabel(signal) .. " CONSOLE",
			self._config.Roles.Operator,
			"SignalButton"
		)

		self:_connect(prompt.Triggered, function(player)
			if room.Busy or not self:_canUseConsole(player, room, prompt, "SignalButton") then
				return
			end
			self:_interaction(player, room, "SignalButton")
			room.Busy = true
			local expectedIndex = solution.SequenceIndices[state.Progress]
			if index == expectedIndex then
				state.Progress += 1
				if SignalPuzzle.Validate(solution, state) then
					self:_completeRoom(room, player)
				else
					self:_status(
						"Signal accepted: "
							.. tostring(state.Progress - 1)
							.. " / "
							.. tostring(#solution.SequenceIndices)
					)
				end
			else
				state.Progress = 1
				self:_mistake(player, "Wrong signal in the Signal Chamber!", room)
			end
			task.delay(0.55, function()
				room.Busy = false
			end)
		end)
	end
end

function RoomGenerator:_buildPhaseFloorRoom(room, randomGenerator, difficulty)
	room.DisplayName = "Invisible Floor"
	self:_addRoomHeader(room, "INVISIBLE FLOOR", "THE SEER SEES THE SAFE PATH", COLORS.Violet)

	for _, side in ipairs({ -1, 1 }) do
		local rail = createPart(
			room.Model,
			"PhaseContainmentWall",
			Vector3.new(1.2, 14, 36),
			CFrame.new(side * 14.6, 7.4, room.CenterZ),
			Color3.fromRGB(63, 47, 91),
			Enum.Material.ForceField
		)
		rail.Transparency = 0.3
		rail.CanCollide = true
		markGeometry(rail, GEOMETRY_ROLES.Blocker)

		local entryWing = createPart(
			room.Model,
			"PhaseEntryBarrier",
			Vector3.new(19.4, 14, 1.2),
			CFrame.new(side * 24.3, 7.4, room.CenterZ - 18),
			Color3.fromRGB(63, 47, 91),
			Enum.Material.ForceField
		)
		entryWing.Transparency = 0.3
		entryWing.CanCollide = true
		markGeometry(entryWing, GEOMETRY_ROLES.Blocker)
	end

	local chasm = createPart(
		room.Model,
		"PhaseChasm",
		Vector3.new(28, PHASE_CHASM_HEIGHT, 31),
		CFrame.new(0, self:_floorOverlayY(room, PHASE_CHASM_HEIGHT), room.CenterZ),
		Color3.fromRGB(4, 6, 13),
		Enum.Material.SmoothPlastic
	)
	chasm.CanCollide = false

	local columns = 5
	local rows = 5
	local solution = PhaseFloorPuzzle.GenerateSolution(randomGenerator, difficulty)
	local safeColumns = solution.SafeColumns

	local touchDebounce = {}
	local progressByPlayer = {}
	local function getProgress(player)
		local state = progressByPlayer[player]
		if not state then
			state = PhaseFloorPuzzle.BuildInitialState(solution)
			progressByPlayer[player] = state
		end
		return state
	end
	local function resetProgress(player)
		progressByPlayer[player] = PhaseFloorPuzzle.BuildInitialState(solution)
	end
	local function rejectPath(player, message)
		if touchDebounce[player] then
			return
		end
		touchDebounce[player] = true
		resetProgress(player)
		self:_mistake(player, message, room)
		local character = player.Character
		if character then
			character:PivotTo(room.StartCFrame)
		end
		task.delay(1, function()
			touchDebounce[player] = nil
		end)
	end
	for row = 1, rows do
		for column = 1, columns do
			local x = (column - 3) * 5
			local z = room.CenterZ - 10 + (row - 1) * 5
			local isSafe = column == safeColumns[row]
			local tile = createPart(
				room.Model,
				"PhaseTile_" .. row .. "_" .. column,
				Vector3.new(4.5, 0.35, 4.5),
				CFrame.new(x, 0.92, z),
				Color3.fromRGB(55, 63, 88),
				Enum.Material.Glass
			)
			tile.Transparency = 0.72
			markGeometry(tile, GEOMETRY_ROLES.Path, string.format("Path_%d_%d_%d", room.Index, row, column))

			if isSafe then
				self:_addSeerPart(
					room,
					"SafePathHint_" .. row,
					"SafePathHint",
					Vector3.new(3.2, 0.08, 3.2),
					CFrame.new(x, 1.14, z),
					COLORS.Cyan,
					Enum.Material.Neon
				)
				self:_addSeerBillboard(
					room,
					tile,
					"SafePathRow_" .. tostring(row),
					"ROW " .. tostring(row),
					Color3.fromRGB(245, 250, 255),
					UDim2.fromOffset(110, 48),
					Vector3.new(0, 2, 0)
				)

				self:_connect(tile.Touched, function(hit)
					local player = playerFromHit(hit)
					if
						not room.Active
						or not self:_isParticipant(player)
						or not self:_canOperate(player)
						or touchDebounce[player]
					then
						return
					end
					local state = getProgress(player)
					local completed, advanceReason = PhaseFloorPuzzle.Advance(solution, state, row, column)
					if advanceReason == "repeated" then
						return
					end
					if advanceReason == "skipped" then
						rejectPath(player, player.DisplayName .. " skipped a row on the invisible path!")
						return
					end
					if completed then
						self:_completeRoom(room, player)
					else
						self:_status("Invisible path progress: row " .. tostring(row) .. " / " .. tostring(rows))
					end
				end)
			else
				self:_connect(tile.Touched, function(hit)
					local player = playerFromHit(hit)
					if
						not room.Active
						or not self:_isParticipant(player)
						or not self:_canOperate(player)
						or touchDebounce[player]
					then
						return
					end
					rejectPath(player, player.DisplayName .. " stepped outside the invisible path!")
				end)
			end
		end
	end
end

function RoomGenerator:_buildEchoSequenceRoom(room, randomGenerator, difficulty)
	room.DisplayName = "Echo Sequence"
	self:_addRoomHeader(room, "ECHO SEQUENCE", "MEMORIZE AND REPEAT THE ORDER", COLORS.Blue)

	local solution = EchoSequencePuzzle.GenerateSolution(randomGenerator, difficulty)
	local state = EchoSequencePuzzle.BuildInitialState(solution)
	local sequence = table.create(#solution.SequenceIndices)
	for index, signalIndex in ipairs(solution.SequenceIndices) do
		sequence[index] = self._config.Signals[signalIndex]
	end

	local display = createPart(
		room.Model,
		"EchoDisplay",
		Vector3.new(17, 6, 0.6),
		CFrame.new(0, 6, room.CenterZ - 9),
		COLORS.Dark,
		Enum.Material.SmoothPlastic
	)
	display.CanCollide = false
	markRoomActive(display)
	local sequenceNames = table.create(#sequence)
	for index, signal in ipairs(sequence) do
		sequenceNames[index] = signalLabel(signal)
	end
	local sequenceText = table.concat(sequenceNames, "  >  ")
	self:_addSeerBillboard(
		room,
		display,
		"EchoSequence",
		sequenceText,
		COLORS.Cyan,
		UDim2.fromOffset(430, 88),
		Vector3.new(0, 0, 0)
	)
	local progressLabel, progressGui =
		addSurfaceText(display, "STEP 0 / " .. tostring(#sequence), Enum.NormalId.Front, Color3.fromRGB(190, 210, 255))
	markRoomActive(progressGui)

	room.SequenceProgress = state.Progress
	for index, signal in ipairs(self._config.Signals) do
		local x = (2 - index) * 12
		local base = createPart(
			room.Model,
			"EchoConsole_" .. signal.Id,
			Vector3.new(7, 2, 7),
			CFrame.new(x, 1.4, room.CenterZ + 8),
			COLORS.Metal,
			Enum.Material.Metal
		)
		local button = createPart(
			room.Model,
			"EchoButton_" .. signal.Id,
			Vector3.new(5, 1, 4.6),
			CFrame.new(x, 2.8, room.CenterZ + 8),
			signal.Color,
			Enum.Material.Neon
		)
		local geometryGroup = string.format("Console_%d_%d", room.Index, index)
		markGeometry(base, GEOMETRY_ROLES.Console, geometryGroup)
		markGeometry(button, GEOMETRY_ROLES.Console, geometryGroup)
		local marker = createPart(
			room.Model,
			"EchoMarker_" .. signal.Id,
			Vector3.new(1.8, 1.8, 1.8),
			CFrame.new(x, 4.15, room.CenterZ + 8),
			signal.Color,
			Enum.Material.Neon
		)
		marker.Shape = signal.Shape or Enum.PartType.Block
		marker.CanCollide = false
		markGeometry(marker, GEOMETRY_ROLES.Console, geometryGroup)
		addSurfaceText(base, signalLabel(signal), Enum.NormalId.Front, signal.Color)
		local prompt =
			makePrompt(button, "REPEAT", signalLabel(signal) .. " ECHO", self._config.Roles.Operator, "EchoButton")

		self:_connect(prompt.Triggered, function(player)
			if room.Busy or not self:_canUseConsole(player, room, prompt, "EchoButton") then
				return
			end
			self:_interaction(player, room, "EchoButton")
			room.Busy = true
			local expected = sequence[state.Progress]
			if signal.Id == expected.Id then
				state.Progress += 1
				room.SequenceProgress = state.Progress
				progressLabel.Text = "STEP " .. tostring(state.Progress - 1) .. " / " .. tostring(#sequence)
				if EchoSequencePuzzle.Validate(solution, state) then
					self:_completeRoom(room, player)
				else
					self:_status("Echo accepted: " .. tostring(state.Progress - 1) .. " / " .. tostring(#sequence))
				end
			else
				state.Progress = 1
				room.SequenceProgress = state.Progress
				progressLabel.Text = "STEP 0 / " .. tostring(#sequence)
				self:_mistake(player, "Wrong echo. The sequence reset!", room)
			end
			task.delay(0.45, function()
				room.Busy = false
			end)
		end)
	end
end

function RoomGenerator:_buildGoal(parent)
	local goal = createPart(
		parent,
		"ExtractionPad",
		Vector3.new(14, 1, 12),
		CFrame.new(0, 1, 71),
		COLORS.Cyan,
		Enum.Material.Neon
	)
	addSurfaceText(goal, "EXTRACTION", Enum.NormalId.Top, Color3.fromRGB(235, 255, 252))
	self:_connect(goal.Touched, function(hit)
		if not self._active or not self._goalUnlocked then
			return
		end
		local player = playerFromHit(hit)
		if not self:_isParticipant(player) or not self._callbacks.OnFinished then
			return
		end
		local now = os.clock()
		if now - (self._lastGoalTouch[player] or 0) < 0.5 then
			return
		end
		self._lastGoalTouch[player] = now
		self._callbacks.OnFinished(player)
	end)
	return goal
end

function RoomGenerator:Generate(randomGenerator, roomCount, options)
	self:DestroyGenerated()
	randomGenerator = randomGenerator or Random.new()
	options = options or {}
	roomCount = math.clamp(roomCount or 3, 1, #ROOM_CENTERS)
	local difficulty = Difficulty.Normalize(options.Difficulty or self._config.Round.Difficulty)

	local folder = Instance.new("Folder")
	folder.Name = "GeneratedRooms"
	folder.Parent = self._mapRoot
	self._folder = folder

	local order = PresetOrder.Build(
		self._config.PuzzleOrder or PRESETS,
		randomGenerator,
		roomCount,
		options.ForcedPreset,
		options.StartRoomIndex
	)

	for index = 1, roomCount do
		local model = Instance.new("Model")
		model.Name = string.format("Room_%02d_%s", index, order[index])
		model.Parent = folder

		local room = {
			Index = index,
			Preset = order[index],
			Model = model,
			CenterZ = ROOM_CENTERS[index],
			StartCFrame = CFrame.new(0, 4, ROOM_CENTERS[index] - 16),
			Active = false,
			Busy = false,
			Difficulty = difficulty,
		}
		model:SetAttribute("Difficulty", difficulty)
		room.Gate = self:_buildGate(model, index, ROOM_ENDS[index])
		room.GateClosedCFrame = room.Gate.CFrame
		table.insert(self._rooms, room)

		if room.Preset == "Signal" then
			self:_buildSignalRoom(room, randomGenerator, difficulty)
		elseif room.Preset == "PhaseFloor" then
			self:_buildPhaseFloorRoom(room, randomGenerator, difficulty)
		elseif room.Preset == "EchoSequence" then
			self:_buildEchoSequenceRoom(room, randomGenerator, difficulty)
		elseif room.Preset == "FrequencyDials" then
			self:_buildFrequencyRoom(room, randomGenerator, difficulty)
		elseif room.Preset == "PowerGrid" then
			self:_buildPowerGridRoom(room, randomGenerator, difficulty)
		elseif room.Preset == "MirrorRelay" then
			self:_buildMirrorRelayRoom(room, randomGenerator, difficulty)
		else
			self:_buildRuneCircuitRoom(room, randomGenerator, difficulty)
		end
		self:_decorateRoom(room)
	end

	self._goal = self:_buildGoal(folder)
	folder:SetAttribute("Seed", options.Seed)
	folder:SetAttribute("SeedId", options.SeedId)
	folder:SetAttribute("BuildVersion", options.BuildVersion)
	folder:SetAttribute("Environment", options.Environment)
	folder:SetAttribute("Difficulty", difficulty)
	self._currentRoomIndex = 0
	self._goalUnlocked = false
	self._active = false
	return table.clone(order)
end

function RoomGenerator:Validate()
	local issues = {}
	if not self._folder or self._folder.Parent ~= self._mapRoot then
		table.insert(issues, "generated folder is missing")
	end
	if not self._goal or self._goal.Parent ~= self._folder then
		table.insert(issues, "extraction pad is missing")
	end
	local generatedDifficulty = self._folder and self._folder:GetAttribute("Difficulty")
	if not Difficulty.IsValid(generatedDifficulty) then
		table.insert(issues, "generated difficulty is missing or invalid")
	end

	local seenPresets = {}
	for index, room in ipairs(self._rooms) do
		if room.Index ~= index then
			table.insert(issues, "room index mismatch at " .. tostring(index))
		end
		if not room.Model or room.Model.Parent ~= self._folder then
			table.insert(issues, "room model missing at " .. tostring(index))
		end
		if not room.Gate or room.Gate.Parent ~= room.Model then
			table.insert(issues, "gate missing at " .. tostring(index))
		end
		if room.Difficulty ~= generatedDifficulty or room.Model:GetAttribute("Difficulty") ~= generatedDifficulty then
			table.insert(issues, "difficulty mismatch at " .. tostring(index))
		end
		local deck = self._mapRoot:FindFirstChild("ChamberDeck_" .. tostring(index))
		if not deck or not deck:IsA("BasePart") then
			table.insert(issues, "chamber deck missing at " .. tostring(index))
		else
			local deckTop = deck.Position.Y + deck.Size.Y * 0.5
			for _, instance in ipairs(room.Model:GetDescendants()) do
				if instance:IsA("BasePart") and FLOOR_OVERLAY_NAMES[instance.Name] then
					local overlayBottom = instance.Position.Y - instance.Size.Y * 0.5
					if overlayBottom < deckTop - 0.001 then
						table.insert(
							issues,
							string.format("%s intersects chamber deck at room %d", instance.Name, index)
						)
					end
				end
			end
		end
		if seenPresets[room.Preset] then
			table.insert(issues, "duplicate preset " .. tostring(room.Preset))
		end
		seenPresets[room.Preset] = true
		if not table.find(self._config.PuzzleOrder or PRESETS, room.Preset) then
			table.insert(issues, "unknown preset " .. tostring(room.Preset))
		end
	end

	local geometryParts = {}
	if self._mapRoot and self._mapRoot.Parent then
		for _, instance in ipairs(self._mapRoot:GetDescendants()) do
			if instance:IsA("BasePart") and geometryRole(instance, self._spawnPart) then
				table.insert(geometryParts, instance)
			end
		end
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { self._mapRoot }
	local overlapIssues = {}
	for _, part in ipairs(geometryParts) do
		local role = geometryRole(part, self._spawnPart)
		if VALIDATED_GEOMETRY_ROLES[role] then
			local querySize = Vector3.new(
				math.max(0.001, part.Size.X - GEOMETRY_CLEARANCE),
				math.max(0.001, part.Size.Y - GEOMETRY_CLEARANCE),
				math.max(0.001, part.Size.Z - GEOMETRY_CLEARANCE)
			)
			for _, other in ipairs(workspace:GetPartBoundsInBox(part.CFrame, querySize, overlapParams)) do
				local otherRole = geometryRole(other, self._spawnPart)
				local otherIsValidated = VALIDATED_GEOMETRY_ROLES[otherRole] == true
				local isRelevantPair = otherRole == GEOMETRY_ROLES.Blocker or otherIsValidated
				local sameGroup = part:GetAttribute("GeometryGroup") ~= nil
					and part:GetAttribute("GeometryGroup") == other:GetAttribute("GeometryGroup")
				if other ~= part and isRelevantPair and not sameGroup then
					local firstPath = geometryPath(part, self._mapRoot)
					local secondPath = geometryPath(other, self._mapRoot)
					local firstRole = role
					local secondRole = otherRole
					if secondPath < firstPath then
						firstPath, secondPath = secondPath, firstPath
						firstRole, secondRole = secondRole, firstRole
					end
					local key = firstPath .. "|" .. secondPath
					overlapIssues[key] = string.format(
						"geometry overlap: %s (%s) intersects %s (%s)",
						firstPath,
						firstRole,
						secondPath,
						secondRole
					)
				end
			end
		end
	end
	local overlapKeys = {}
	for key in pairs(overlapIssues) do
		table.insert(overlapKeys, key)
	end
	table.sort(overlapKeys)
	for _, key in ipairs(overlapKeys) do
		table.insert(issues, overlapIssues[key])
	end
	return #issues == 0, issues
end

function RoomGenerator:GetSeerClues()
	local clues = {}
	if not self._folder or self._folder.Parent ~= self._mapRoot then
		return clues
	end

	for _, room in ipairs(self._rooms) do
		for _, clue in ipairs(room.SeerClues or {}) do
			table.insert(clues, table.clone(clue))
		end
	end
	return clues
end

function RoomGenerator:GetStartCFrame(roomIndex)
	local room = self._rooms[math.clamp(roomIndex or 1, 1, math.max(1, #self._rooms))]
	return if room then room.StartCFrame else self._spawnPart.CFrame
end

function RoomGenerator:GetExtractionState()
	return {
		Active = self._active,
		GoalUnlocked = self._goalUnlocked,
		GoalPosition = if self._goal then self._goal.Position else nil,
		RoomCount = #self._rooms,
		CurrentRoomIndex = self._currentRoomIndex,
	}
end

function RoomGenerator:Start(startRoomIndex)
	if #self._rooms == 0 then
		return
	end
	self._active = true
	self._goalUnlocked = false
	table.clear(self._lastGoalTouch)
	self._currentRoomIndex = math.clamp(startRoomIndex or 1, 1, #self._rooms)
	for _, room in ipairs(self._rooms) do
		if room.Index < self._currentRoomIndex then
			room.Gate.CanCollide = false
			room.Gate.CFrame = room.GateClosedCFrame + Vector3.new(0, 13, 0)
			room.Gate.Transparency = 0.58
			self:_setRoomActive(room, false)
		else
			self:_setRoomActive(room, room.Index == self._currentRoomIndex)
		end
	end
	local currentRoom = self._rooms[self._currentRoomIndex]
	self:_status(
		"Mini-room "
			.. tostring(self._currentRoomIndex)
			.. " / "
			.. tostring(#self._rooms)
			.. ": "
			.. currentRoom.DisplayName
	)
end

function RoomGenerator:SetActive(active)
	self._active = active
	if not active then
		for _, room in ipairs(self._rooms) do
			self:_setRoomActive(room, false)
		end
	end
end

function RoomGenerator:DestroyGenerated()
	self._active = false
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._rooms)
	table.clear(self._lastConsoleInteraction)
	table.clear(self._lastGoalTouch)
	if self._folder then
		self._folder:Destroy()
		self._folder = nil
	end
	self._goal = nil
	self._currentRoomIndex = 0
	self._goalUnlocked = false
end

function RoomGenerator:Destroy()
	self:DestroyGenerated()
end

return RoomGenerator
