local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VisualTheme"))
local QALog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QALog"))
local roundStateRemote = ReplicatedStorage:WaitForChild("GameRemotes"):WaitForChild("RoundState")
local lobbyEvent = ReplicatedStorage:WaitForChild("GameRemotes"):WaitForChild("LobbyEvent")
local LobbyController = require(script:WaitForChild("LobbyController"))
local SeerClueRenderer = require(script:WaitForChild("SeerClueRenderer"))
local TutorialController = require(script:WaitForChild("TutorialController"))
local playerGui = player:WaitForChild("PlayerGui")

local currentRole = Config.Roles.Hybrid
local currentPhase = "Waiting"
local roleVisibilityConnections = {}
local visionActive = false
local visionReadyAt = 0
local visionEndsAt = 0
local hudDetailsVisible = false
local qaLoggingEnabled = false

local function updateLocalRoleOutline()
	local character = player.Character
	if not character then
		return
	end
	local outline = character:FindFirstChild("LocalRoleOutline")
	if currentPhase ~= "Playing" then
		if outline then
			outline:Destroy()
		end
		return
	end
	if not outline then
		outline = Instance.new("Highlight")
		outline.Name = "LocalRoleOutline"
		outline.FillTransparency = 1
		outline.OutlineTransparency = 0.5
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = character
	end
	outline.OutlineColor = Config.RoleColors[currentRole] or Theme.Colors.Cyan
end

player.CharacterAdded:Connect(function()
	task.defer(updateLocalRoleOutline)
end)

local function getServerTime()
	return workspace:GetServerTimeNow()
end

local function addCorner(guiObject, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.UI.CornerRadius)
	corner.Parent = guiObject
	return corner
end

local function addStroke(guiObject, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or Theme.UI.StrokeThickness
	stroke.Transparency = transparency or 0
	stroke.Parent = guiObject
	return stroke
end

local function createLabel(parent, name, size, position, text, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Theme.Colors.White
	label.TextSize = textSize
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RealityHUD"
screenGui.IgnoreGuiInset = false
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = false
screenGui.Parent = playerGui

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.fromScale(0.5, 0.025)
topBar.Size = UDim2.new(0.92, 0, 0, 74)
topBar.BackgroundColor3 = Theme.Colors.Panel
topBar.BackgroundTransparency = 0.08
topBar.Visible = false
topBar.Parent = screenGui
addCorner(topBar, 16)
addStroke(topBar, Color3.fromRGB(91, 120, 255), 2, 0.25)

local titleLabel =
	createLabel(topBar, "Title", UDim2.new(0.48, 0, 1, 0), UDim2.fromScale(0.03, 0), Config.GameTitle, 23)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

local phaseLabel =
	createLabel(topBar, "Phase", UDim2.new(0.25, 0, 0.48, 0), UDim2.fromScale(0.53, 0.08), "CONNECTING", 17)
phaseLabel.TextColor3 = Color3.fromRGB(169, 181, 220)

local timerLabel = createLabel(topBar, "Timer", UDim2.new(0.17, 0, 0.7, 0), UDim2.fromScale(0.8, 0.15), "--", 34)
timerLabel.TextXAlignment = Enum.TextXAlignment.Right

local compactHud = Instance.new("Frame")
compactHud.Name = "CompactHud"
compactHud.AnchorPoint = Vector2.new(1, 0)
compactHud.Position = UDim2.fromScale(0.97, 0.025)
compactHud.Size = UDim2.fromOffset(230, 52)
compactHud.BackgroundColor3 = Theme.Colors.Panel
compactHud.BackgroundTransparency = 0.12
compactHud.Parent = screenGui
addCorner(compactHud, 14)
addStroke(compactHud, Theme.Colors.Cyan, 2, 0.3)

local compactPhaseLabel =
	createLabel(compactHud, "Phase", UDim2.new(0.7, 0, 1, 0), UDim2.fromScale(0.05, 0), "CONNECTING", 14)
compactPhaseLabel.TextXAlignment = Enum.TextXAlignment.Left
compactPhaseLabel.TextColor3 = Color3.fromRGB(188, 198, 230)

local compactTimerLabel = createLabel(compactHud, "Timer", UDim2.new(0.22, 0, 1, 0), UDim2.fromScale(0.74, 0), "--", 25)
compactTimerLabel.TextXAlignment = Enum.TextXAlignment.Right

local qaPanel = Instance.new("Frame")
qaPanel.Name = "QADebugPanel"
qaPanel.Position = UDim2.fromScale(0.025, 0.025)
qaPanel.Size = UDim2.fromOffset(460, 72)
qaPanel.BackgroundColor3 = Color3.fromRGB(12, 15, 24)
qaPanel.BackgroundTransparency = 0.08
qaPanel.Visible = false
qaPanel.Parent = screenGui
addCorner(qaPanel, 12)
addStroke(qaPanel, Color3.fromRGB(255, 177, 66), 2, 0.2)

local qaLabel = createLabel(qaPanel, "Details", UDim2.new(1, -20, 1, -12), UDim2.fromOffset(10, 6), "QA", 13)
qaLabel.Font = Enum.Font.Code
qaLabel.TextColor3 = Color3.fromRGB(255, 222, 166)
qaLabel.TextXAlignment = Enum.TextXAlignment.Left
qaLabel.TextYAlignment = Enum.TextYAlignment.Top

local roleCard = Instance.new("Frame")
roleCard.Name = "RoleCard"
roleCard.Position = UDim2.new(0.04, 0, 0.15, 0)
roleCard.Size = UDim2.new(0, 320, 0, 132)
roleCard.BackgroundColor3 = Theme.Colors.Panel
roleCard.BackgroundTransparency = 0.06
roleCard.Visible = false
roleCard.Parent = screenGui
addCorner(roleCard, 16)
local roleStroke = addStroke(roleCard, Config.RoleColors[Config.Roles.Hybrid], 3, 0.05)

local roleCaption =
	createLabel(roleCard, "Caption", UDim2.new(0.9, 0, 0, 26), UDim2.fromScale(0.05, 0.08), "YOUR REALITY", 13)
roleCaption.TextColor3 = Color3.fromRGB(151, 160, 190)
roleCaption.TextXAlignment = Enum.TextXAlignment.Left

local roleLabel = createLabel(roleCard, "Role", UDim2.new(0.9, 0, 0, 38), UDim2.fromScale(0.05, 0.25), "SOLO", 28)
roleLabel.TextXAlignment = Enum.TextXAlignment.Left

local instructionLabel = createLabel(
	roleCard,
	"Instructions",
	UDim2.new(0.9, 0, 0, 54),
	UDim2.fromScale(0.05, 0.55),
	"Waiting for instructions...",
	14
)
instructionLabel.Font = Enum.Font.GothamMedium
instructionLabel.TextColor3 = Color3.fromRGB(205, 211, 232)
instructionLabel.TextXAlignment = Enum.TextXAlignment.Left
instructionLabel.TextYAlignment = Enum.TextYAlignment.Top

local statusCard = Instance.new("Frame")
statusCard.Name = "StatusCard"
statusCard.AnchorPoint = Vector2.new(0.5, 1)
statusCard.Position = UDim2.fromScale(0.5, 0.96)
statusCard.Size = UDim2.new(0.82, 0, 0, 68)
statusCard.BackgroundColor3 = Theme.Colors.Panel
statusCard.BackgroundTransparency = 0.06
statusCard.Visible = false
statusCard.Parent = screenGui
addCorner(statusCard, 16)
addStroke(statusCard, Theme.Colors.Cyan, 2, 0.3)

local statusLabel = createLabel(
	statusCard,
	"Status",
	UDim2.new(0.94, 0, 1, 0),
	UDim2.fromScale(0.03, 0),
	"Connecting to this reality...",
	18
)

local hudRevealButton = Instance.new("TextButton")
hudRevealButton.Name = "HoldForDetails"
hudRevealButton.AnchorPoint = Vector2.new(0, 1)
hudRevealButton.Position = UDim2.fromScale(0.025, 0.96)
hudRevealButton.Size = UDim2.fromOffset(164, 42)
hudRevealButton.AutoButtonColor = false
hudRevealButton.BackgroundColor3 = Color3.fromRGB(24, 29, 45)
hudRevealButton.BackgroundTransparency = 0.12
hudRevealButton.Font = Enum.Font.GothamBold
hudRevealButton.Text = if UserInputService.TouchEnabled then "HOLD  INFO" else "H / L1  -  HOLD INFO"
hudRevealButton.TextColor3 = Color3.fromRGB(213, 221, 247)
hudRevealButton.TextSize = 13
hudRevealButton.Parent = screenGui
addCorner(hudRevealButton, 12)
addStroke(hudRevealButton, Color3.fromRGB(91, 120, 255), 2, 0.35)

local visionCard = Instance.new("Frame")
visionCard.Name = "VisionCard"
visionCard.AnchorPoint = Vector2.new(1, 1)
visionCard.Position = UDim2.fromScale(0.97, 0.94)
visionCard.Size = UDim2.fromOffset(210, 62)
visionCard.BackgroundColor3 = Theme.Colors.Panel
visionCard.BackgroundTransparency = 0.04
visionCard.Visible = false
visionCard.Parent = screenGui
addCorner(visionCard, 16)
local visionStroke = addStroke(visionCard, Config.RoleColors[Config.Roles.Seer], 2, 0.1)

local visionSizeConstraint = Instance.new("UISizeConstraint")
visionSizeConstraint.MinSize = Vector2.new(170, 62)
visionSizeConstraint.MaxSize = Vector2.new(210, 62)
visionSizeConstraint.Parent = visionCard

local visionButton = Instance.new("TextButton")
visionButton.Name = "ActivateVision"
visionButton.Size = UDim2.new(1, -12, 1, -12)
visionButton.Position = UDim2.fromOffset(6, 6)
visionButton.AutoButtonColor = false
visionButton.BackgroundColor3 = Color3.fromRGB(78, 49, 126)
visionButton.Font = Enum.Font.GothamBold
visionButton.Text = "Q / TAP - ALT VISION\nREADY"
visionButton.TextColor3 = Color3.fromRGB(248, 243, 255)
visionButton.TextSize = 13
visionButton.TextWrapped = true
visionButton.Parent = visionCard
addCorner(visionButton, 11)

local visionOverlay = Instance.new("Frame")
visionOverlay.Name = "VisionOverlay"
visionOverlay.Size = UDim2.fromScale(1, 1)
visionOverlay.BackgroundColor3 = Color3.fromRGB(93, 39, 150)
visionOverlay.BackgroundTransparency = 1
visionOverlay.BorderSizePixel = 0
visionOverlay.Active = false
visionOverlay.ZIndex = 0
visionOverlay.Parent = screenGui

local overlayGradient = Instance.new("UIGradient")
overlayGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(58, 20, 104)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(157, 75, 224)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 15, 82)),
})
overlayGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.35),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(1, 0.35),
})
overlayGradient.Parent = visionOverlay

local lobbyController = LobbyController.new(Config, lobbyEvent, playerGui)
local seerClueRenderer = SeerClueRenderer.new("PrototypeMap")
local tutorialController = TutorialController.new(playerGui)

ScriptContext.Error:Connect(function(message, stackTrace, sourceScript)
	if qaLoggingEnabled then
		warn(QALog.FormatClientError(sourceScript and sourceScript:GetFullName() or "unknown", message, stackTrace))
	end
end)

local function setHudDetailsVisible(visible)
	hudDetailsVisible = visible and screenGui.Enabled
	topBar.Visible = hudDetailsVisible
	roleCard.Visible = hudDetailsVisible
	statusCard.Visible = hudDetailsVisible
	hudRevealButton.BackgroundColor3 = if hudDetailsVisible
		then Color3.fromRGB(55, 69, 112)
		else Color3.fromRGB(24, 29, 45)
end

local function isPointerInput(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

hudRevealButton.InputBegan:Connect(function(input)
	if isPointerInput(input) then
		setHudDetailsVisible(true)
	end
end)

hudRevealButton.InputEnded:Connect(function(input)
	if isPointerInput(input) then
		setHudDetailsVisible(false)
	end
end)

local function refreshVisionCosmetic()
	local primary = player:GetAttribute("VisionPrimaryColor") or Color3.fromRGB(93, 39, 150)
	local accent = player:GetAttribute("VisionAccentColor") or Color3.fromRGB(177, 110, 255)
	visionOverlay.BackgroundColor3 = primary
	overlayGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, primary),
		ColorSequenceKeypoint.new(0.5, accent),
		ColorSequenceKeypoint.new(1, primary),
	})
	visionStroke.Color = accent
end

player:GetAttributeChangedSignal("VisionPrimaryColor"):Connect(refreshVisionCosmetic)
player:GetAttributeChangedSignal("VisionAccentColor"):Connect(refreshVisionCosmetic)
refreshVisionCosmetic()

local applyRoleVisibility

local function roleCanSee(instance, restriction)
	if currentRole == Config.Roles.Hybrid then
		if restriction == Config.Roles.Seer then
			return visionActive
		end

		if instance:IsA("ProximityPrompt") and restriction == Config.Roles.Operator then
			return not visionActive
		end

		return true
	end

	return restriction == currentRole
end

local function applyVisibilityToInstance(instance)
	local restriction = instance:GetAttribute("VisibleToRole")
	local requiresRoomActive = instance:GetAttribute("RequiresRoomActive")
	if not restriction and not requiresRoomActive then
		return
	end

	local visible = if restriction then roleCanSee(instance, restriction) else true
	if requiresRoomActive and not instance:GetAttribute("RoomActive") then
		visible = false
	end
	if instance:IsA("BasePart") then
		instance.LocalTransparencyModifier = if visible then 0 else 1
	elseif
		instance:IsA("BillboardGui")
		or instance:IsA("SurfaceGui")
		or instance:IsA("Light")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Trail")
		or instance:IsA("Beam")
		or instance:IsA("ProximityPrompt")
	then
		instance.Enabled = visible
	end
end

local function setVisionVisuals(active)
	local overlayTransparency = if active then 0.86 else 1
	TweenService:Create(
		visionOverlay,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = overlayTransparency }
	):Play()

	local accent = player:GetAttribute("VisionAccentColor") or Config.RoleColors[Config.Roles.Seer]
	visionStroke.Color = if active then accent:Lerp(Color3.new(1, 1, 1), 0.35) else accent
end

local function activateVision()
	if currentRole ~= Config.Roles.Hybrid or currentPhase ~= "Playing" then
		return
	end

	local now = getServerTime()
	if visionActive or now < visionReadyAt then
		return
	end

	lobbyEvent:FireServer({ action = "RequestVision" })
end

applyRoleVisibility = function()
	local map = workspace:FindFirstChild("PrototypeMap")
	if not map then
		return
	end

	for _, instance in ipairs(map:GetDescendants()) do
		applyVisibilityToInstance(instance)
	end
end

local function watchMap()
	for _, connection in ipairs(roleVisibilityConnections) do
		connection:Disconnect()
	end
	table.clear(roleVisibilityConnections)

	local map = workspace:WaitForChild("PrototypeMap")
	applyRoleVisibility()
	table.insert(
		roleVisibilityConnections,
		map.DescendantAdded:Connect(function(instance)
			task.defer(applyVisibilityToInstance, instance)
		end)
	)
end

task.spawn(watchMap)
workspace.ChildAdded:Connect(function(child)
	if child.Name == "PrototypeMap" then
		task.spawn(watchMap)
	end
end)

local function pulseStatus(color)
	statusCard.BackgroundColor3 = color
	local tween = TweenService:Create(
		statusCard,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundColor3 = Color3.fromRGB(14, 17, 28) }
	)
	tween:Play()
end

local function updateVisionHud()
	local isSolo = currentRole == Config.Roles.Hybrid and currentPhase ~= "Lobby"
	visionCard.Visible = isSolo
	if not isSolo then
		return
	end

	local now = getServerTime()
	if currentPhase ~= "Playing" then
		visionButton.Active = false
		visionButton.Selectable = false
		visionButton.BackgroundColor3 = Color3.fromRGB(46, 45, 58)
		visionButton.TextColor3 = Color3.fromRGB(174, 173, 188)
		visionButton.Text = "ALT VISION\nAVAILABLE IN THE ROUND"
	elseif visionActive then
		visionButton.Active = false
		visionButton.Selectable = false
		visionButton.BackgroundColor3 = Color3.fromRGB(139, 73, 196)
		visionButton.TextColor3 = Color3.fromRGB(255, 247, 255)
		visionButton.Text = string.format("ALT REALITY  %.1fs\nCONSOLES LOCKED", math.max(0, visionEndsAt - now))
	elseif now < visionReadyAt then
		visionButton.Active = false
		visionButton.Selectable = false
		visionButton.BackgroundColor3 = Color3.fromRGB(49, 42, 65)
		visionButton.TextColor3 = Color3.fromRGB(196, 183, 214)
		visionButton.Text = string.format("VISION RECHARGING\n%.1fs", math.max(0, visionReadyAt - now))
	else
		visionButton.Active = true
		visionButton.Selectable = true
		visionButton.BackgroundColor3 = Color3.fromRGB(78, 49, 126)
		visionButton.TextColor3 = Color3.fromRGB(248, 243, 255)
		visionButton.Text = "Q / TAP - ALT VISION\nREADY"
	end
end

visionButton.Activated:Connect(activateVision)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.Q then
		activateVision()
	elseif input.KeyCode == Enum.KeyCode.H or input.KeyCode == Enum.KeyCode.ButtonL1 then
		setHudDetailsVisible(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.H or input.KeyCode == Enum.KeyCode.ButtonL1 then
		setHudDetailsVisible(false)
	end
end)

local visionHudAccumulator = 0
RunService.Heartbeat:Connect(function(deltaTime)
	if visionActive and getServerTime() >= visionEndsAt then
		visionActive = false
		visionEndsAt = 0
		setVisionVisuals(false)
		applyRoleVisibility()
	end

	visionHudAccumulator += deltaTime
	if visionHudAccumulator < 0.1 then
		return
	end

	visionHudAccumulator = 0
	updateVisionHud()
end)

roundStateRemote.OnClientEvent:Connect(function(state)
	local nextRole = state.role or Config.Roles.Hybrid
	local nextPhase = state.phase or "Waiting"

	currentRole = nextRole
	currentPhase = nextPhase
	tutorialController:SetContext(nextPhase, nextRole)
	updateLocalRoleOutline()
	visionEndsAt = if typeof(state.visionEndsAt) == "number" then state.visionEndsAt else 0
	visionReadyAt = if typeof(state.visionReadyAt) == "number" then state.visionReadyAt else 0
	local nextVisionActive = currentRole == Config.Roles.Hybrid
		and currentPhase == "Playing"
		and visionEndsAt > getServerTime()
	if nextVisionActive ~= visionActive then
		visionActive = nextVisionActive
		setVisionVisuals(visionActive)
	end
	seerClueRenderer:Sync(
		state.seerClues,
		table.concat({ tostring(state.seedId or "none"), tostring(state.roundNumber or 0), tostring(nextRole) }, ":"),
		state.roomIndex,
		nextPhase == "Playing"
	)
	qaLoggingEnabled = state.qaEnabled == true
	qaPanel.Visible = qaLoggingEnabled and nextPhase ~= "Lobby"
	if qaPanel.Visible then
		qaLabel.Text = string.format(
			"QA CLIENT | %s | %s\n%s | room %s (start %s) | %s | %s",
			tostring(state.buildVersion or "unknown build"),
			tostring(state.environment or "unknown environment"),
			tostring(state.seedId or "no seed"),
			tostring(state.qaRoom or "-"),
			tostring(state.qaStartRoom or "-"),
			tostring(state.qaPreset or "generating"),
			tostring(state.qaDifficulty or state.difficulty or "Normal")
		)
	end
	local inLobby = currentPhase == "Lobby"
	screenGui.Enabled = not inLobby
	lobbyController:SetVisible(inLobby)
	if inLobby then
		setHudDetailsVisible(false)
	end
	local roleColor = state.roleColor or Config.RoleColors[currentRole] or Color3.fromRGB(255, 255, 255)

	roleLabel.Text = string.upper(currentRole)
	roleLabel.TextColor3 = roleColor
	roleStroke.Color = roleColor
	instructionLabel.Text = if currentRole == Config.Roles.Hybrid
		then string.format(
			"Press Q or tap ALT VISION: clues appear for %d seconds, but consoles lock.",
			(Config.AlternateVision and Config.AlternateVision.Duration) or 4
		)
		else state.instructions or ""
	local difficultyLabel = string.upper(tostring(state.difficulty or Config.Round.Difficulty or "Normal"))
	phaseLabel.Text = string.upper(state.phase or "WAITING")
		.. "  |  "
		.. difficultyLabel
		.. "  |  R"
		.. tostring(state.roundNumber or 0)
	timerLabel.Text = tostring(state.timeLeft or 0)
	compactPhaseLabel.Text = string.upper(state.phase or "WAITING") .. "  |  " .. difficultyLabel
	compactTimerLabel.Text = tostring(state.timeLeft or 0)
	statusLabel.Text = state.status or ""

	if state.phase == "Success" then
		pulseStatus(Color3.fromRGB(28, 112, 86))
	elseif state.phase == "Failed" then
		pulseStatus(Color3.fromRGB(130, 40, 56))
	elseif state.gateOpen then
		pulseStatus(Color3.fromRGB(56, 86, 145))
	end

	applyRoleVisibility()
	updateVisionHud()
end)
