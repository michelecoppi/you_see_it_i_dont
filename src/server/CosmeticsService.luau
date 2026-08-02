local CosmeticsService = {}

local DEFAULT_DRONE_PRIMARY = Color3.fromRGB(55, 77, 98)
local DEFAULT_DRONE_ACCENT = Color3.fromRGB(74, 255, 222)
local DEFAULT_VISION_PRIMARY = Color3.fromRGB(93, 39, 150)
local DEFAULT_VISION_ACCENT = Color3.fromRGB(177, 110, 255)

local function clearCharacterCosmetics(character)
	local previous = character:FindFirstChild("EquippedCosmetics")
	if previous then
		previous:Destroy()
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, attachmentName in ipairs({ "CosmeticTrailTop", "CosmeticTrailBottom" }) do
			local attachment = root:FindFirstChild(attachmentName)
			if attachment then
				attachment:Destroy()
			end
		end
	end
end

local function applyTrail(container, character, item)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local top = Instance.new("Attachment")
	top.Name = "CosmeticTrailTop"
	top.Position = Vector3.new(0, 1.2, 0.45)
	top.Parent = root

	local bottom = Instance.new("Attachment")
	bottom.Name = "CosmeticTrailBottom"
	bottom.Position = Vector3.new(0, -1.2, 0.45)
	bottom.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "AvatarPhaseTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(item.PrimaryColor, item.AccentColor or item.PrimaryColor)
	trail.LightEmission = 0.9
	trail.Lifetime = 0.35
	trail.MinLength = 0.1
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = container
end

local function applyTitle(container, character, item)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CosmeticTitle"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(160, 30)
	billboard.StudsOffset = Vector3.new(0, 2.7, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 55
	billboard.Parent = container

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = item.Name
	label.TextColor3 = item.PrimaryColor
	label.TextScaled = true
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(12, 15, 25)
	stroke.Thickness = 2
	stroke.Parent = label
end

function CosmeticsService.Apply(config, player, profile)
	if not player or not profile then
		return
	end

	local droneItem = config.Cosmetics[profile.Equipped.Drone]
	player:SetAttribute("DronePrimaryColor", if droneItem then droneItem.PrimaryColor else DEFAULT_DRONE_PRIMARY)
	player:SetAttribute("DroneAccentColor", if droneItem then droneItem.AccentColor else DEFAULT_DRONE_ACCENT)

	local visionItem = config.Cosmetics[profile.Equipped.Vision]
	player:SetAttribute("VisionPrimaryColor", if visionItem then visionItem.PrimaryColor else DEFAULT_VISION_PRIMARY)
	player:SetAttribute("VisionAccentColor", if visionItem then visionItem.AccentColor else DEFAULT_VISION_ACCENT)

	local character = player.Character
	if not character then
		return
	end

	clearCharacterCosmetics(character)
	local container = Instance.new("Folder")
	container.Name = "EquippedCosmetics"
	container.Parent = character

	local trailItem = config.Cosmetics[profile.Equipped.Trail]
	if trailItem then
		applyTrail(container, character, trailItem)
	end

	local titleItem = config.Cosmetics[profile.Equipped.Title]
	if titleItem then
		applyTitle(container, character, titleItem)
	end
end

function CosmeticsService.Clear(character)
	if character then
		clearCharacterCosmetics(character)
	end
end

return CosmeticsService
