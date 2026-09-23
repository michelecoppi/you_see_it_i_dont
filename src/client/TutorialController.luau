local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VisualTheme"))

local TutorialController = {}
TutorialController.__index = TutorialController

local PAGES = {
	{
		title = "WELCOME, EXPLORER",
		body = "Work through three unstable rooms and reach the exit before the expedition timer runs out.",
	},
	{
		title = "CHOOSE YOUR EXPEDITION",
		body = "Solo is a self guided run. In Group, Seers read hidden clues while Operators use consoles. Share what you see over voice or chat.",
	},
	{
		title = "YOUR CONTROLS",
		body = "Move with your device's normal controls. Use prompts to operate consoles. In Solo, tap ALT VISION or press Q to reveal clues; consoles pause while it is active.",
	},
}

local function round(guiObject, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = guiObject
end

local function stroke(guiObject, color)
	local border = Instance.new("UIStroke")
	border.Color = color
	border.Thickness = 2
	border.Transparency = 0.25
	border.Parent = guiObject
end

function TutorialController.new(playerGui)
	local self = setmetatable({}, TutorialController)
	self._shownThisSession = false
	self._page = 1
	self._phase = "Waiting"
	self._role = "Hybrid"

	local screen = Instance.new("ScreenGui")
	screen.Name = "FirstRunTutorial"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 0
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui
	self._screen = screen

	local help = Instance.new("TextButton")
	help.Name = "HelpButton"
	help.AnchorPoint = Vector2.new(1, 0)
	help.Position = UDim2.new(1, -18, 0, 142)
	help.Size = UDim2.fromOffset(132, 38)
	help.BackgroundColor3 = Color3.fromRGB(25, 42, 59)
	help.Font = Enum.Font.GothamBold
	help.Text = "HOW TO PLAY"
	help.TextColor3 = Theme.Colors.White
	help.TextSize = 13
	help.AutoButtonColor = true
	help.Selectable = true
	help.Parent = screen
	round(help, 10)
	stroke(help, Theme.Colors.Cyan)
	self._help = help

	local card = Instance.new("Frame")
	card.Name = "TutorialCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.new(0.86, 0, 0, 264)
	card.BackgroundColor3 = Theme.Colors.Panel
	card.BackgroundTransparency = 0.02
	card.Visible = false
	card.Parent = screen
	round(card, 18)
	stroke(card, Theme.Colors.Cyan)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(280, 264)
	sizeLimit.MaxSize = Vector2.new(480, 264)
	sizeLimit.Parent = card
	self._card = card

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.new(0.07, 0, 0.1, 0)
	title.Size = UDim2.new(0.86, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Theme.Colors.Cyan
	title.TextSize = 19
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card
	self._title = title

	local body = Instance.new("TextLabel")
	body.Name = "Instructions"
	body.Position = UDim2.new(0.07, 0, 0.25, 0)
	body.Size = UDim2.new(0.86, 0, 0, 126)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamMedium
	body.TextColor3 = Theme.Colors.White
	body.TextSize = 16
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Parent = card
	self._body = body

	local progress = Instance.new("TextLabel")
	progress.Name = "Progress"
	progress.Position = UDim2.new(0.07, 0, 0.82, 0)
	progress.Size = UDim2.new(0.42, 0, 0, 28)
	progress.BackgroundTransparency = 1
	progress.Font = Enum.Font.GothamMedium
	progress.TextColor3 = Theme.Colors.Muted
	progress.TextSize = 13
	progress.TextXAlignment = Enum.TextXAlignment.Left
	progress.Parent = card
	self._progress = progress

	local action = Instance.new("TextButton")
	action.Name = "Next"
	action.AnchorPoint = Vector2.new(1, 1)
	action.Position = UDim2.new(0.93, 0, 0.93, 0)
	action.Size = UDim2.new(0.43, 0, 0, 44)
	action.BackgroundColor3 = Theme.Colors.Blue
	action.Font = Enum.Font.GothamBold
	action.Text = "NEXT"
	action.TextColor3 = Theme.Colors.White
	action.TextSize = 15
	action.AutoButtonColor = true
	action.Selectable = true
	action.Parent = card
	round(action, 12)
	self._action = action

	local function renderPage()
		local page = PAGES[self._page]
		self._title.Text = page.title
		local deviceHint = if UserInputService.GamepadEnabled
			then " Select buttons and press A; prompts show the action."
			else if UserInputService.TouchEnabled
				then " Tap on-screen buttons; tap prompts to interact."
				else " Use the on-screen prompts to interact."
		self._body.Text = if self._page == 3 then page.body .. deviceHint else page.body
		self._progress.Text = string.format("%d / %d", self._page, #PAGES)
		self._action.Text = if self._page == #PAGES then "GOT IT" else "NEXT"
	end
	self._renderPage = renderPage

	local function open()
		if self._phase ~= "Lobby" then
			return
		end
		self._page = 1
		renderPage()
		card.Visible = true
		help.Visible = false
		screen.DisplayOrder = 10
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = action
		end
	end

	help.Activated:Connect(open)
	action.Activated:Connect(function()
		if self._page < #PAGES then
			self._page += 1
			renderPage()
			if UserInputService.GamepadEnabled then
				GuiService.SelectedObject = action
			end
		else
			card.Visible = false
			help.Visible = self._phase == "Lobby"
			screen.DisplayOrder = 0
		end
	end)

	return self
end

function TutorialController:SetContext(phase, role)
	self._phase = phase or "Waiting"
	self._role = role or "Hybrid"
	local inLobby = self._phase == "Lobby"
	if not inLobby then
		self._card.Visible = false
		self._screen.DisplayOrder = 0
	end
	self._help.Visible = inLobby and not self._card.Visible
	if inLobby and not self._shownThisSession then
		self._shownThisSession = true
		self._page = 1
		self._renderPage()
		self._card.Visible = true
		self._help.Visible = false
		self._screen.DisplayOrder = 10
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = self._action
		end
	end
end

return TutorialController
