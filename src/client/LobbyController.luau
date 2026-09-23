local MarketplaceService = game:GetService("MarketplaceService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("VisualTheme"))

local LobbyController = {}
LobbyController.__index = LobbyController

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
	label.TextSize = textSize or 16
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function createButton(parent, name, size, position, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.AutoButtonColor = true
	button.BackgroundColor3 = color
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Theme.Colors.White
	button.TextSize = 17
	button.TextWrapped = true
	button.Parent = parent
	addCorner(button, 12)
	return button
end

local function formatNumber(value)
	local text = tostring(math.floor(value or 0))
	while true do
		local formatted, substitutions = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		text = formatted
		if substitutions == 0 then
			break
		end
	end
	return text
end

local function formatDuration(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remainingSeconds = seconds % 60
	if hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	end
	return string.format("%dm %02ds", minutes, remainingSeconds)
end

local function formatDate(unixTime)
	if not unixTime or unixTime <= 0 then
		return "--"
	end
	return os.date("!%d/%m/%Y", unixTime)
end

local PUZZLE_NAMES = {
	Signal = "Signal Chamber",
	PhaseFloor = "Invisible Floor",
	EchoSequence = "Echo Sequence",
	FrequencyDials = "Frequency Vault",
	PowerGrid = "Power Grid",
}

function LobbyController.new(config, remote, playerGui)
	local self = setmetatable({}, LobbyController)
	self._config = config
	self._remote = remote
	self._state = nil
	self._shopOpen = false
	self._catalogMode = "Shop"
	self._statsOpen = false
	self._noticeGeneration = 0
	self._modalFocus = nil

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LobbyHUD"
	screenGui.IgnoreGuiInset = false
	screenGui.DisplayOrder = 1
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
	self._screenGui = screenGui

	local shardBadge = Instance.new("Frame")
	shardBadge.Name = "ShardBadge"
	shardBadge.AnchorPoint = Vector2.new(1, 0)
	shardBadge.Position = UDim2.fromScale(0.97, 0.025)
	shardBadge.Size = UDim2.fromOffset(230, 56)
	shardBadge.BackgroundColor3 = Theme.Colors.Panel
	shardBadge.BackgroundTransparency = 0.04
	shardBadge.Parent = screenGui
	addCorner(shardBadge, 16)
	addStroke(shardBadge, Theme.Colors.Violet, 2, 0.15)

	local shardLabel =
		createLabel(shardBadge, "Amount", UDim2.new(0.92, 0, 1, 0), UDim2.fromScale(0.04, 0), "-- REALITY SHARDS", 17)
	shardLabel.TextColor3 = Color3.fromRGB(218, 183, 255)
	shardLabel.TextXAlignment = Enum.TextXAlignment.Center
	self._shardLabel = shardLabel

	local actionTray = Instance.new("Frame")
	actionTray.Name = "LobbyActions"
	actionTray.AnchorPoint = Vector2.new(1, 0)
	actionTray.Position = UDim2.fromScale(0.97, 0.105)
	actionTray.Size = UDim2.fromOffset(300, 52)
	actionTray.BackgroundTransparency = 1
	actionTray.Parent = screenGui

	local cosmeticsButton = createButton(
		actionTray,
		"Cosmetics",
		UDim2.fromOffset(144, 48),
		UDim2.fromOffset(0, 2),
		"COSMETICS",
		Color3.fromRGB(105, 61, 151)
	)
	cosmeticsButton.TextSize = 14
	addStroke(cosmeticsButton, Color3.fromRGB(190, 128, 255), 2, 0.2)

	local personalStatsButton = createButton(
		actionTray,
		"PersonalStats",
		UDim2.fromOffset(144, 48),
		UDim2.fromOffset(156, 2),
		"MY STATS",
		Color3.fromRGB(35, 112, 105)
	)
	personalStatsButton.TextSize = 14
	addStroke(personalStatsButton, Color3.fromRGB(88, 224, 196), 2, 0.2)

	self._actionTray = actionTray

	local mainPanel = Instance.new("Frame")
	mainPanel.Name = "QueuePanel"
	mainPanel.AnchorPoint = Vector2.new(0, 1)
	mainPanel.Position = UDim2.new(0.035, 0, 0.96, 0)
	mainPanel.Size = UDim2.new(0.78, 0, 0, 112)
	mainPanel.BackgroundColor3 = Theme.Colors.Panel
	mainPanel.BackgroundTransparency = 0.04
	mainPanel.Visible = false
	mainPanel.Parent = screenGui
	addCorner(mainPanel, 18)
	addStroke(mainPanel, Color3.fromRGB(88, 224, 196), 2, 0.18)

	local panelConstraint = Instance.new("UISizeConstraint")
	panelConstraint.MinSize = Vector2.new(300, 112)
	panelConstraint.MaxSize = Vector2.new(520, 112)
	panelConstraint.Parent = mainPanel

	local title =
		createLabel(mainPanel, "Title", UDim2.new(0.72, 0, 0, 30), UDim2.fromScale(0.05, 0.09), "EXPEDITION QUEUE", 17)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local subtitle = createLabel(
		mainPanel,
		"Subtitle",
		UDim2.new(0.72, 0, 0, 22),
		UDim2.fromScale(0.05, 0.34),
		"Use the portals inside the lobby.",
		12
	)
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextColor3 = Color3.fromRGB(178, 186, 213)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left

	local soloButton = createButton(
		mainPanel,
		"SoloRun",
		UDim2.new(0.9, 0, 0, 68),
		UDim2.fromScale(0.05, 0.28),
		"SOLO RUN\nSTART IMMEDIATELY",
		Color3.fromRGB(31, 118, 105)
	)
	local groupButton = createButton(
		mainPanel,
		"GroupRun",
		UDim2.new(0.9, 0, 0, 68),
		UDim2.fromScale(0.05, 0.47),
		"GROUP RUN\n2-6 EXPLORERS",
		Color3.fromRGB(53, 79, 158)
	)
	local shopButton = createButton(
		mainPanel,
		"Shop",
		UDim2.new(0.58, 0, 0, 56),
		UDim2.fromScale(0.05, 0.69),
		"COSMETIC LAB",
		Color3.fromRGB(105, 61, 151)
	)
	soloButton.Visible = false
	groupButton.Visible = false
	shopButton.Visible = false
	local cancelButton = createButton(
		mainPanel,
		"Cancel",
		UDim2.new(0.23, 0, 0, 46),
		UDim2.new(0.74, 0, 0.29, 0),
		"CANCEL",
		Color3.fromRGB(105, 51, 65)
	)
	cancelButton.Visible = false

	local queueLabel = createLabel(
		mainPanel,
		"QueueStatus",
		UDim2.new(0.65, 0, 0, 44),
		UDim2.fromScale(0.05, 0.55),
		"Profile loading...",
		13
	)
	queueLabel.Font = Enum.Font.GothamMedium
	queueLabel.TextColor3 = Color3.fromRGB(164, 176, 213)
	queueLabel.TextXAlignment = Enum.TextXAlignment.Left
	queueLabel.TextYAlignment = Enum.TextYAlignment.Top

	self._mainPanel = mainPanel
	self._soloButton = soloButton
	self._groupButton = groupButton
	self._shopButton = shopButton
	self._cancelButton = cancelButton
	self._queueLabel = queueLabel

	local notice = createLabel(screenGui, "Notice", UDim2.new(0.62, 0, 0, 54), UDim2.fromScale(0.19, 0.03), "", 16)
	notice.BackgroundColor3 = Color3.fromRGB(21, 26, 42)
	notice.BackgroundTransparency = 0.04
	notice.Visible = false
	notice.ZIndex = 20
	addCorner(notice, 14)
	local noticeStroke = addStroke(notice, Color3.fromRGB(88, 224, 196), 2, 0.15)
	self._notice = notice
	self._noticeStroke = noticeStroke

	local shopModal = Instance.new("Frame")
	shopModal.Name = "ShopModal"
	shopModal.AnchorPoint = Vector2.new(0.5, 0.5)
	shopModal.Position = UDim2.fromScale(0.5, 0.52)
	shopModal.Size = UDim2.new(0.9, 0, 0.84, 0)
	shopModal.BackgroundColor3 = Theme.Colors.Void
	shopModal.BackgroundTransparency = 0.015
	shopModal.Visible = false
	shopModal.ZIndex = 10
	shopModal.Parent = screenGui
	addCorner(shopModal, 20)
	addStroke(shopModal, Theme.Colors.Violet, 2, 0.1)

	local shopConstraint = Instance.new("UISizeConstraint")
	shopConstraint.MinSize = Vector2.new(280, 280)
	shopConstraint.MaxSize = Vector2.new(1080, 720)
	shopConstraint.Parent = shopModal

	local shopTitle =
		createLabel(shopModal, "Title", UDim2.new(0.7, 0, 0, 48), UDim2.fromScale(0.035, 0.025), "COSMETIC LAB", 27)
	shopTitle.TextXAlignment = Enum.TextXAlignment.Left
	shopTitle.ZIndex = 11
	self._shopTitle = shopTitle

	local shopSubtitle = createLabel(
		shopModal,
		"Subtitle",
		UDim2.new(0.72, 0, 0, 36),
		UDim2.fromScale(0.035, 0.09),
		"Cosmetics never change puzzle difficulty.",
		14
	)
	shopSubtitle.Font = Enum.Font.GothamMedium
	shopSubtitle.TextColor3 = Color3.fromRGB(174, 182, 210)
	shopSubtitle.TextXAlignment = Enum.TextXAlignment.Left
	shopSubtitle.ZIndex = 11
	self._shopSubtitle = shopSubtitle

	local closeShop = createButton(
		shopModal,
		"Close",
		UDim2.fromOffset(112, 44),
		UDim2.new(1, -132, 0, 20),
		"CLOSE",
		Color3.fromRGB(83, 48, 66)
	)
	closeShop.ZIndex = 12

	local catalog = Instance.new("ScrollingFrame")
	catalog.Name = "Catalog"
	catalog.Position = UDim2.fromScale(0.03, 0.16)
	catalog.Size = UDim2.new(0.94, 0, 0.8, 0)
	catalog.BackgroundTransparency = 1
	catalog.BorderSizePixel = 0
	catalog.ScrollBarThickness = 7
	catalog.ScrollBarImageColor3 = Color3.fromRGB(177, 110, 255)
	catalog.AutomaticCanvasSize = Enum.AutomaticSize.Y
	catalog.CanvasSize = UDim2.new()
	catalog.ZIndex = 11
	catalog.Parent = shopModal

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.48, -8, 0, 178)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = catalog

	local catalogPadding = Instance.new("UIPadding")
	catalogPadding.PaddingTop = UDim.new(0, 4)
	catalogPadding.PaddingBottom = UDim.new(0, 12)
	catalogPadding.Parent = catalog

	self._shopModal = shopModal
	self._catalog = catalog
	self._shopConstraint = shopConstraint
	self._catalogGrid = grid

	local statsModal = Instance.new("Frame")
	statsModal.Name = "StatsModal"
	statsModal.AnchorPoint = Vector2.new(0.5, 0.5)
	statsModal.Position = UDim2.fromScale(0.5, 0.52)
	statsModal.Size = UDim2.new(0.86, 0, 0.82, 0)
	statsModal.BackgroundColor3 = Theme.Colors.Void
	statsModal.BackgroundTransparency = 0.01
	statsModal.Visible = false
	statsModal.ZIndex = 10
	statsModal.Parent = screenGui
	addCorner(statsModal, 20)
	addStroke(statsModal, Theme.Colors.Cyan, 2, 0.1)

	local statsConstraint = Instance.new("UISizeConstraint")
	statsConstraint.MinSize = Vector2.new(280, 280)
	statsConstraint.MaxSize = Vector2.new(920, 720)
	statsConstraint.Parent = statsModal
	self._statsConstraint = statsConstraint

	local statsTitle = createLabel(
		statsModal,
		"Title",
		UDim2.new(0.72, 0, 0, 48),
		UDim2.fromScale(0.04, 0.025),
		"EXPEDITION ARCHIVE",
		27
	)
	statsTitle.TextXAlignment = Enum.TextXAlignment.Left
	statsTitle.TextColor3 = Color3.fromRGB(163, 255, 237)
	statsTitle.ZIndex = 11
	local statsSubtitle = createLabel(
		statsModal,
		"Subtitle",
		UDim2.new(0.72, 0, 0, 30),
		UDim2.fromScale(0.04, 0.095),
		"Persistent career and puzzle performance",
		13
	)
	statsSubtitle.Font = Enum.Font.GothamMedium
	statsSubtitle.TextColor3 = Color3.fromRGB(164, 186, 205)
	statsSubtitle.TextXAlignment = Enum.TextXAlignment.Left
	statsSubtitle.ZIndex = 11

	local closeStats = createButton(
		statsModal,
		"Close",
		UDim2.fromOffset(112, 44),
		UDim2.new(1, -132, 0, 20),
		"CLOSE",
		Color3.fromRGB(55, 76, 82)
	)
	closeStats.ZIndex = 12

	local statsContent = Instance.new("ScrollingFrame")
	statsContent.Name = "StatsContent"
	statsContent.Position = UDim2.fromScale(0.035, 0.16)
	statsContent.Size = UDim2.new(0.93, 0, 0.79, 0)
	statsContent.BackgroundTransparency = 1
	statsContent.BorderSizePixel = 0
	statsContent.ScrollBarThickness = 7
	statsContent.ScrollBarImageColor3 = Color3.fromRGB(70, 225, 218)
	statsContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
	statsContent.CanvasSize = UDim2.new()
	statsContent.ZIndex = 11
	statsContent.Parent = statsModal

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.Padding = UDim.new(0, 9)
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Parent = statsContent

	local statsPadding = Instance.new("UIPadding")
	statsPadding.PaddingBottom = UDim.new(0, 14)
	statsPadding.PaddingRight = UDim.new(0, 8)
	statsPadding.Parent = statsContent

	self._statsModal = statsModal
	self._statsContent = statsContent
	self._shopClose = closeShop
	self._statsClose = closeStats

	for _, button in ipairs({ soloButton, groupButton, shopButton, cancelButton, closeShop, closeStats }) do
		button.Selectable = true
	end
	local function updateResponsiveLayout()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local compact = viewport.X < 640
		local modalWidth = math.max(260, math.min(viewport.X - 24, 1080))
		local modalHeight = math.max(260, math.min(viewport.Y - 24, 720))
		shopModal.Size = UDim2.fromOffset(modalWidth, modalHeight)
		statsModal.Size = UDim2.fromOffset(math.min(modalWidth, 920), modalHeight)
		shopConstraint.MinSize = Vector2.new(0, 0)
		statsConstraint.MinSize = Vector2.new(0, 0)
		grid.FillDirectionMaxCells = if compact then 1 else 2
		grid.CellSize = if compact then UDim2.new(0.96, -8, 0, 178) else UDim2.new(0.48, -8, 0, 178)
		shopTitle.TextSize = if compact then 20 else 27
		statsTitle.TextSize = if compact then 20 else 27
		shopTitle.Size = UDim2.new(if compact then 0.58 else 0.7, 0, 0, 48)
		statsTitle.Size = UDim2.new(if compact then 0.58 else 0.72, 0, 0, 48)
		closeShop.Size = UDim2.fromOffset(if compact then 84 else 112, 44)
		closeShop.Position = UDim2.new(1, if compact then -96 else -132, 0, 16)
		closeStats.Size = UDim2.fromOffset(if compact then 84 else 112, 44)
		closeStats.Position = UDim2.new(1, if compact then -96 else -132, 0, 16)
		self._mainPanel.Size = UDim2.new(if compact then 0.94 else 0.78, 0, 0, compact and 120 or 112)
		self._mainPanel.Position = UDim2.new(compact and 0.03 or 0.035, 0, 0.96, 0)
		panelConstraint.MinSize = Vector2.new(0, 112)
		self._actionTray.Size = UDim2.fromOffset(compact and 252 or 300, 52)
		self._actionTray.Position = UDim2.new(1, -12, 0.105, 0)
		self._shardLabel.TextSize = if compact then 13 else 17
		self._notice.Size = UDim2.new(if compact then 0.9 else 0.62, 0, 0, 54)
		self._notice.Position = UDim2.new(if compact then 0.05 else 0.19, 0, 0.03, 0)
	end
	local cameraConnection
	local function watchCamera()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
		local camera = workspace.CurrentCamera
		if camera then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
		end
		updateResponsiveLayout()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()

	soloButton.Activated:Connect(function()
		remote:FireServer({ action = "Solo" })
	end)
	groupButton.Activated:Connect(function()
		remote:FireServer({ action = "Group" })
	end)
	shopButton.Activated:Connect(function()
		self:OpenShop()
	end)
	cosmeticsButton.Activated:Connect(function()
		remote:FireServer({ action = "OpenShop" })
	end)
	personalStatsButton.Activated:Connect(function()
		remote:FireServer({ action = "OpenStats" })
	end)
	cancelButton.Activated:Connect(function()
		remote:FireServer({ action = "CancelQueue" })
	end)
	closeShop.Activated:Connect(function()
		self:CloseShop()
	end)
	closeStats.Activated:Connect(function()
		self:CloseStats()
	end)

	remote.OnClientEvent:Connect(function(payload)
		self:_onRemote(payload)
	end)

	remote:FireServer({ action = "RequestState" })
	return self
end

function LobbyController:_showNotice(message, isError)
	self._noticeGeneration += 1
	local generation = self._noticeGeneration
	self._notice.Text = message
	self._notice.TextColor3 = if isError then Color3.fromRGB(255, 180, 190) else Color3.fromRGB(220, 255, 245)
	self._noticeStroke.Color = if isError then Color3.fromRGB(255, 91, 112) else Color3.fromRGB(88, 224, 196)
	self._notice.Visible = true

	task.delay(3.2, function()
		if self._noticeGeneration == generation then
			self._notice.Visible = false
		end
	end)
end

function LobbyController:_focusModal(closeButton)
	self._modalFocus = closeButton
	local lastInput = UserInputService:GetLastInputType()
	if GuiService:IsTenFootInterface() or string.find(lastInput.Name, "Gamepad") then
		GuiService.SelectedObject = closeButton
	end
	ContextActionService:BindAction("LobbyModalBack", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			if self._shopOpen then
				self:CloseShop()
			elseif self._statsOpen then
				self:CloseStats()
			end
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonB, Enum.KeyCode.Escape, Enum.KeyCode.Backspace)
end

function LobbyController:_releaseModalFocus()
	ContextActionService:UnbindAction("LobbyModalBack")
	self._modalFocus = nil
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self._screenGui) then
		GuiService.SelectedObject = nil
	end
end

function LobbyController:_clearCatalog()
	for _, child in ipairs(self._catalog:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function LobbyController:_createCatalogCard(itemId, item, layoutOrder)
	local profile = self._state and self._state.Profile
	local owned = profile and profile.Inventory[itemId] == true
	local equipped = owned and profile.Equipped[item.Slot] == itemId

	local card = Instance.new("Frame")
	card.Name = itemId
	card.BackgroundColor3 = Color3.fromRGB(24, 29, 45)
	card.LayoutOrder = layoutOrder
	card.ZIndex = 11
	card.Parent = self._catalog
	addCorner(card, 14)
	addStroke(card, item.PrimaryColor or Color3.fromRGB(177, 110, 255), 2, 0.2)

	local colorStrip = Instance.new("Frame")
	colorStrip.Size = UDim2.new(1, 0, 0, 9)
	colorStrip.BackgroundColor3 = item.PrimaryColor or Color3.fromRGB(177, 110, 255)
	colorStrip.BorderSizePixel = 0
	colorStrip.ZIndex = 12
	colorStrip.Parent = card
	addCorner(colorStrip, 8)

	local nameLabel = createLabel(card, "Name", UDim2.new(0.9, 0, 0, 30), UDim2.fromScale(0.05, 0.1), item.Name, 17)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 12

	local slotLabel =
		createLabel(card, "Slot", UDim2.new(0.9, 0, 0, 20), UDim2.fromScale(0.05, 0.28), string.upper(item.Slot), 11)
	slotLabel.TextColor3 = Color3.fromRGB(149, 158, 187)
	slotLabel.TextXAlignment = Enum.TextXAlignment.Left
	slotLabel.ZIndex = 12

	local description =
		createLabel(card, "Description", UDim2.new(0.9, 0, 0, 50), UDim2.fromScale(0.05, 0.4), item.Description, 12)
	description.Font = Enum.Font.GothamMedium
	description.TextColor3 = Color3.fromRGB(190, 197, 219)
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.ZIndex = 12

	local actionText
	local actionColor
	local enabled = profile ~= nil
	if equipped then
		actionText = "EQUIPPED"
		actionColor = Color3.fromRGB(43, 99, 89)
		enabled = false
	elseif owned then
		actionText = "EQUIP"
		actionColor = Color3.fromRGB(48, 84, 142)
	elseif item.Currency == "Shards" then
		actionText = "◆ " .. formatNumber(item.Price)
		actionColor = Color3.fromRGB(93, 60, 135)
	elseif item.Currency == "Pass" and item.PassId > 0 then
		actionText = "VIEW ROBUX PRICE"
		actionColor = Color3.fromRGB(128, 72, 49)
	else
		actionText = if item.Currency == "Starter" then "STARTER ITEM" else "PREMIUM • SET ID"
		actionColor = Color3.fromRGB(63, 66, 78)
		enabled = false
	end

	local actionButton =
		createButton(card, "Action", UDim2.new(0.9, 0, 0, 38), UDim2.fromScale(0.05, 0.745), actionText, actionColor)
	actionButton.TextSize = 13
	actionButton.ZIndex = 12
	actionButton.Active = enabled
	actionButton.AutoButtonColor = enabled

	if enabled then
		actionButton.Activated:Connect(function()
			if owned then
				self._remote:FireServer({ action = "Equip", itemId = itemId })
			elseif item.Currency == "Shards" then
				self._remote:FireServer({ action = "BuySoft", itemId = itemId })
			elseif item.Currency == "Pass" then
				self._remote:FireServer({ action = "BuyPremium", itemId = itemId })
			end
		end)
	end

	if item.Currency == "Pass" and item.PassId > 0 and not owned then
		task.spawn(function()
			local success, info = pcall(function()
				return MarketplaceService:GetProductInfo(item.PassId, Enum.InfoType.GamePass)
			end)
			if success and actionButton.Parent then
				actionButton.Text = if info.PriceInRobux then tostring(info.PriceInRobux) .. " ROBUX" else "PREMIUM"
			end
		end)
	end
end

function LobbyController:_createShardPackCard(productKey, product, layoutOrder)
	local card = Instance.new("Frame")
	card.Name = productKey
	card.BackgroundColor3 = Color3.fromRGB(31, 25, 46)
	card.LayoutOrder = layoutOrder
	card.ZIndex = 11
	card.Parent = self._catalog
	addCorner(card, 14)
	addStroke(card, Color3.fromRGB(218, 183, 255), 2, 0.15)

	local title = createLabel(card, "Name", UDim2.new(0.9, 0, 0, 45), UDim2.fromScale(0.05, 0.12), product.Name, 19)
	title.TextColor3 = Color3.fromRGB(229, 204, 255)
	title.ZIndex = 12

	local description = createLabel(
		card,
		"Description",
		UDim2.new(0.88, 0, 0, 45),
		UDim2.fromScale(0.06, 0.4),
		"Developer Product • repeatable purchase",
		12
	)
	description.Font = Enum.Font.GothamMedium
	description.TextColor3 = Color3.fromRGB(183, 175, 204)
	description.ZIndex = 12

	local enabled = product.ProductId > 0
	local button = createButton(
		card,
		"Action",
		UDim2.new(0.9, 0, 0, 40),
		UDim2.fromScale(0.05, 0.72),
		if enabled then "VIEW ROBUX PRICE" else "SHARD PACK • SET ID",
		if enabled then Color3.fromRGB(126, 75, 43) else Color3.fromRGB(63, 66, 78)
	)
	button.TextSize = 13
	button.ZIndex = 12
	button.Active = enabled
	button.AutoButtonColor = enabled

	if enabled then
		button.Activated:Connect(function()
			self._remote:FireServer({ action = "BuyShards", productKey = productKey })
		end)
		task.spawn(function()
			local success, info = pcall(function()
				return MarketplaceService:GetProductInfo(product.ProductId, Enum.InfoType.Product)
			end)
			if success and button.Parent then
				button.Text = if info.PriceInRobux then tostring(info.PriceInRobux) .. " ROBUX" else "BUY SHARDS"
			end
		end)
	end
end

function LobbyController:_renderShop()
	self:_clearCatalog()
	local wardrobeMode = self._catalogMode == "Wardrobe"
	self._shopTitle.Text = if wardrobeMode then "LOADOUT STATION" else "COSMETIC LAB"
	self._shopSubtitle.Text = if wardrobeMode
		then "Equip cosmetics already owned by your explorer."
		else "Cosmetics never change puzzle difficulty."
	local profile = self._state and self._state.Profile
	for index, itemId in ipairs(self._config.CosmeticOrder) do
		local item = self._config.Cosmetics[itemId]
		local owned = profile and profile.Inventory[itemId] == true
		if item and (not wardrobeMode or owned) then
			self:_createCatalogCard(itemId, item, index)
		end
	end

	if not wardrobeMode then
		local offset = #self._config.CosmeticOrder + 100
		for index, productKey in ipairs(self._config.DeveloperProductOrder) do
			local product = self._config.DeveloperProducts[productKey]
			if product then
				self:_createShardPackCard(productKey, product, offset + index)
			end
		end
	end
end

function LobbyController:_clearStats()
	for _, child in ipairs(self._statsContent:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function LobbyController:_renderStats()
	self:_clearStats()
	local profile = self._state and self._state.Profile
	local stats = profile and profile.Stats
	if not stats then
		local loading =
			createLabel(self._statsContent, "Loading", UDim2.new(1, -8, 0, 60), UDim2.new(), "Archive loading...", 18)
		loading.LayoutOrder = 1
		loading.ZIndex = 12
		return
	end

	local order = 0
	local function addSection(title)
		order += 1
		local label = createLabel(self._statsContent, "Section", UDim2.new(1, -8, 0, 32), UDim2.new(), title, 16)
		label.LayoutOrder = order
		label.TextColor3 = Color3.fromRGB(112, 239, 218)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 12
	end

	local function addRow(title, value, detail, accent)
		order += 1
		local row = Instance.new("Frame")
		row.Name = "StatRow"
		row.Size = UDim2.new(1, -8, 0, 62)
		row.BackgroundColor3 = Color3.fromRGB(22, 31, 46)
		row.LayoutOrder = order
		row.ZIndex = 12
		row.Parent = self._statsContent
		addCorner(row, 12)
		addStroke(row, accent or Color3.fromRGB(70, 225, 218), 1, 0.45)

		local titleLabel = createLabel(row, "Label", UDim2.new(0.58, 0, 0, 25), UDim2.fromScale(0.035, 0.12), title, 15)
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.ZIndex = 13
		local valueLabel = createLabel(row, "Value", UDim2.new(0.35, 0, 0, 28), UDim2.fromScale(0.62, 0.1), value, 18)
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.TextColor3 = accent or Color3.fromRGB(163, 255, 237)
		valueLabel.ZIndex = 13
		local detailLabel =
			createLabel(row, "Detail", UDim2.new(0.92, 0, 0, 21), UDim2.fromScale(0.035, 0.56), detail or "", 11)
		detailLabel.Font = Enum.Font.GothamMedium
		detailLabel.TextColor3 = Color3.fromRGB(153, 166, 190)
		detailLabel.TextXAlignment = Enum.TextXAlignment.Left
		detailLabel.ZIndex = 13
	end

	local finished = (stats.ExpeditionsCompleted or 0) + (stats.ExpeditionsFailed or 0)
	local successRate = if (stats.ExpeditionsStarted or 0) > 0
		then math.floor((stats.ExpeditionsCompleted / stats.ExpeditionsStarted) * 100 + 0.5)
		else 0
	local averageRound = if finished > 0 then stats.TotalRoundSeconds / finished else 0

	addSection("CAREER")
	addRow(
		"Expeditions",
		tostring(stats.ExpeditionsCompleted) .. " / " .. tostring(stats.ExpeditionsStarted),
		tostring(successRate) .. "% success rate",
		Color3.fromRGB(88, 224, 196)
	)
	addRow(
		"Failed expeditions",
		formatNumber(stats.ExpeditionsFailed),
		"Includes timeouts, abandoned runs and disconnects",
		Color3.fromRGB(255, 112, 129)
	)
	addRow(
		"Solo / Group wins",
		tostring(stats.SoloWins) .. " / " .. tostring(stats.GroupWins),
		tostring(stats.SoloExpeditions) .. " Solo and " .. tostring(stats.GroupExpeditions) .. " Group runs",
		Color3.fromRGB(91, 120, 255)
	)
	addRow(
		"Expedition time",
		formatDuration(stats.TotalRoundSeconds),
		"Average completed or failed run: " .. formatDuration(averageRound),
		Color3.fromRGB(177, 110, 255)
	)
	addRow(
		"Best successful run",
		if stats.BestRoundSeconds > 0 then formatDuration(stats.BestRoundSeconds) else "--",
		"Best streak: " .. tostring(stats.BestWinStreak) .. " | Current: " .. tostring(stats.CurrentWinStreak),
		Color3.fromRGB(255, 177, 66)
	)
	addRow(
		"Total playtime",
		formatDuration(stats.TotalPlaySeconds),
		tostring(stats.Sessions) .. " sessions | Explorer since " .. formatDate(stats.FirstPlayedUnix),
		Color3.fromRGB(70, 225, 218)
	)

	addSection("GAMEPLAY")
	addRow(
		"Rooms completed",
		formatNumber(stats.RoomsCompleted),
		tostring(stats.TotalMistakes) .. " total mistakes",
		Color3.fromRGB(94, 255, 151)
	)
	addRow("Alternate Vision", formatNumber(stats.VisionUses), "Solo scans activated", Color3.fromRGB(177, 110, 255))
	addRow(
		"Queue activity",
		formatNumber(stats.QueuesJoined),
		tostring(stats.QueuesCancelled) .. " queues cancelled",
		Color3.fromRGB(91, 120, 255)
	)
	addRow(
		"Lobby interactions",
		formatNumber(stats.LobbyInteractions),
		tostring(stats.LaunchPadUses)
			.. " launches | "
			.. tostring(stats.BriefingsRead)
			.. " briefings | "
			.. tostring(stats.MixerUses)
			.. " mixer uses",
		Color3.fromRGB(70, 225, 218)
	)
	addRow(
		"Daily Reactor",
		formatNumber(stats.DailyClaims),
		"Current daily streak: " .. tostring(stats.DailyStreak),
		Color3.fromRGB(255, 177, 66)
	)
	addRow(
		"Terminal visits",
		formatNumber(stats.ShopVisits + stats.StatsVisits + stats.WardrobeVisits),
		tostring(stats.ShopVisits)
			.. " shop | "
			.. tostring(stats.WardrobeVisits)
			.. " loadout | "
			.. tostring(stats.StatsVisits)
			.. " archive",
		Color3.fromRGB(143, 176, 255)
	)

	addSection("ECONOMY & COLLECTION")
	addRow(
		"Reality Shards",
		formatNumber(profile.Shards),
		formatNumber(stats.ShardsEarned) .. " earned | " .. formatNumber(stats.ShardsSpent) .. " spent",
		Color3.fromRGB(218, 183, 255)
	)
	addRow(
		"Cosmetics",
		formatNumber(stats.CosmeticsPurchased),
		formatNumber(stats.CosmeticsEquipped) .. " equip actions",
		Color3.fromRGB(255, 177, 66)
	)
	addRow(
		"Premium purchases",
		formatNumber(stats.RobuxPurchases),
		formatNumber(stats.PurchasedShards) .. " Shards from packs",
		Color3.fromRGB(255, 139, 91)
	)

	addSection("PUZZLE PERFORMANCE")
	for _, preset in ipairs(self._config.PuzzleOrder or {}) do
		local puzzle = stats.Puzzles and stats.Puzzles[preset]
		if puzzle then
			local average = if puzzle.Completed > 0 then puzzle.TotalSeconds / puzzle.Completed else 0
			local best = if puzzle.BestSeconds > 0
				then string.format("%.1fs best", puzzle.BestSeconds)
				else "no best time"
			local completionRate = if puzzle.Attempts > 0
				then math.floor((puzzle.Completed / puzzle.Attempts) * 100 + 0.5)
				else 0
			addRow(
				PUZZLE_NAMES[preset] or preset,
				tostring(puzzle.Completed) .. " / " .. tostring(puzzle.Attempts),
				string.format(
					"%d selected | %d%% clear | %.1fs avg | %s | %d actions | %d mistakes",
					puzzle.Selected,
					completionRate,
					average,
					best,
					puzzle.Interactions,
					puzzle.Mistakes
				),
				Color3.fromRGB(112, 239, 218)
			)
		end
	end
end

function LobbyController:_renderState()
	self._actionTray.Visible = not self._shopOpen and not self._statsOpen
	local state = self._state
	if not state then
		self._queueLabel.Text = "Profile loading..."
		return
	end

	local profile = state.Profile
	self._shardLabel.Text = if profile then formatNumber(profile.Shards) .. " REALITY SHARDS" else "LOADING SHARDS..."

	local queueType = state.QueueType
	self._mainPanel.Visible = queueType ~= nil and not self._shopOpen and not self._statsOpen
	self._cancelButton.Visible = queueType ~= nil
	if queueType == "Solo" then
		self._soloButton.Text = "SOLO RUN\nQUEUED"
		self._queueLabel.Text = if state.MatchBusy
			then "Current expedition active. Your Solo Run is next."
			else "Preparing your Solo expedition..."
	elseif queueType == "Group" then
		self._groupButton.Text = "GROUP RUN\nIN QUEUE"
		local countdownText = if state.GroupCountdown
			then " | starts in " .. tostring(state.GroupCountdown) .. "s"
			else ""
		self._queueLabel.Text = "Group queue: " .. tostring(state.GroupQueueCount or 0) .. "/6" .. countdownText
	else
		self._soloButton.Text = "SOLO RUN\nSTART IMMEDIATELY"
		self._groupButton.Text = "GROUP RUN\n2-6 EXPLORERS"
		self._queueLabel.Text = if state.MatchBusy
			then "An expedition is active. You can shop or queue for the next one."
			else "Expedition chamber ready."
	end

	if profile and not profile.Persistent then
		self._queueLabel.Text ..= "\nStudio test: inventory is session-only."
	end

	if self._shopOpen then
		self:_renderShop()
	end
	if self._statsOpen then
		self:_renderStats()
	end
end

function LobbyController:_onRemote(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.type == "State" and typeof(payload.state) == "table" then
		self._state = payload.state
		self:_renderState()
	elseif payload.type == "Notice" then
		self:_showNotice(tostring(payload.message or ""), payload.isError)
	elseif payload.type == "OpenShop" then
		self:OpenShop()
	elseif payload.type == "OpenStats" then
		self:OpenStats()
	elseif payload.type == "OpenWardrobe" then
		self:OpenWardrobe()
	end
end

function LobbyController:OpenShop()
	self._catalogMode = "Shop"
	self._shopOpen = true
	self._statsOpen = false
	self._statsModal.Visible = false
	self._shopModal.Visible = true
	self._mainPanel.Visible = false
	self._actionTray.Visible = false
	self:_focusModal(self._shopClose)
	self:_renderShop()
end

function LobbyController:OpenWardrobe()
	self._catalogMode = "Wardrobe"
	self._shopOpen = true
	self._statsOpen = false
	self._statsModal.Visible = false
	self._shopModal.Visible = true
	self._mainPanel.Visible = false
	self._actionTray.Visible = false
	self:_focusModal(self._shopClose)
	self:_renderShop()
end

function LobbyController:OpenStats()
	self._statsOpen = true
	self._shopOpen = false
	self._shopModal.Visible = false
	self._statsModal.Visible = true
	self._mainPanel.Visible = false
	self._actionTray.Visible = false
	self:_focusModal(self._statsClose)
	self:_renderStats()
end

function LobbyController:CloseStats()
	self._statsOpen = false
	self._statsModal.Visible = false
	if not self._shopOpen then
		self:_releaseModalFocus()
	end
	self:_renderState()
end

function LobbyController:CloseShop()
	self._shopOpen = false
	self._shopModal.Visible = false
	if not self._statsOpen then
		self:_releaseModalFocus()
	end
	self:_renderState()
end

function LobbyController:SetVisible(visible)
	self._screenGui.Enabled = visible
	if not visible then
		self:CloseShop()
		self:CloseStats()
	end
end

return LobbyController
