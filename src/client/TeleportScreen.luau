-- Full-screen transition shown while the server moves the player between the hub and an
-- expedition server. The same ScreenGui is handed to TeleportService so it stays visible during
-- the teleport; ReplicatedFirst/TeleportArrival fades it out on the other side.
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local Theme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("VisualTheme"))

local TeleportScreen = {}
TeleportScreen.__index = TeleportScreen

local function createLabel(parent, name, text, textSize, position, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = UDim2.new(0.9, 0, 0, textSize + 12)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextWrapped = true
	label.Parent = parent
	return label
end

-- Builds the transition gui. Also used by ReplicatedFirst when no teleport gui arrives.
function TeleportScreen.CreateGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ExpeditionTransition"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Enabled = false

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Theme.Colors.Void
	background.BorderSizePixel = 0
	background.Parent = gui

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Theme.Colors.Panel, Theme.Colors.Void)
	gradient.Parent = background

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.4)
	ring.Size = UDim2.fromOffset(120, 120)
	ring.BackgroundTransparency = 1
	ring.Parent = background
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Cyan
	stroke.Thickness = 4
	stroke.Parent = ring
	local strokeGradient = Instance.new("UIGradient")
	strokeGradient.Color = ColorSequence.new(Theme.Colors.Cyan, Theme.Colors.Violet)
	strokeGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	strokeGradient.Parent = stroke

	createLabel(background, "Title", "ENTERING EXPEDITION", 34, UDim2.fromScale(0.5, 0.58), Theme.Colors.White)
	createLabel(
		background,
		"Subtitle",
		"Opening a private reality for your crew...",
		18,
		UDim2.fromScale(0.5, 0.65),
		Theme.Colors.Muted
	)
	return gui
end

-- Spins the ring while the gui is enabled. Safe to call on a gui received from TeleportService.
function TeleportScreen.Animate(gui)
	local background = gui:FindFirstChild("Background")
	local ring = background and background:FindFirstChild("Ring")
	if not ring then
		return
	end
	task.spawn(function()
		while gui.Parent do
			ring.Rotation = (ring.Rotation + 4) % 360
			task.wait(1 / 30)
		end
	end)
end

function TeleportScreen.FadeOut(gui, duration)
	local background = gui:FindFirstChild("Background")
	if not background then
		gui:Destroy()
		return
	end
	local info = TweenInfo.new(duration or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(background, info, { BackgroundTransparency = 1 }):Play()
	for _, descendant in ipairs(background:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			TweenService:Create(descendant, info, { TextTransparency = 1 }):Play()
		elseif descendant:IsA("UIStroke") then
			TweenService:Create(descendant, info, { Transparency = 1 }):Play()
		end
	end
	task.delay(duration or 0.6, function()
		gui:Destroy()
	end)
end

function TeleportScreen.new(playerGui)
	local self = setmetatable({}, TeleportScreen)
	self._gui = TeleportScreen.CreateGui()
	self._gui.Parent = playerGui
	TeleportScreen.Animate(self._gui)
	return self
end

function TeleportScreen:Show(title, subtitle)
	local background = self._gui.Background
	background.Title.Text = title
	background.Subtitle.Text = subtitle
	self._gui.Enabled = true
	-- Keeps the same screen on display during the teleport loading phase.
	pcall(function()
		TeleportService:SetTeleportGui(self._gui)
	end)
end

function TeleportScreen:Hide()
	self._gui.Enabled = false
end

return TeleportScreen
