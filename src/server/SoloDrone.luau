local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SoloDrone = {}
SoloDrone.__index = SoloDrone

local FOLLOW_OFFSET = CFrame.new(2.8, 2.35, -1.3)
local FOLLOW_SPEED = 7

local function configurePart(part, name, size, color, material)
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	return part
end

local function createDrone(player, parent, initialCFrame)
	local primaryColor = player:GetAttribute("DronePrimaryColor") or Color3.fromRGB(55, 77, 98)
	local accentColor = player:GetAttribute("DroneAccentColor") or Color3.fromRGB(74, 255, 222)

	local model = Instance.new("Model")
	model.Name = "SoloDrone_" .. player.Name
	model:SetAttribute("OwnerUserId", player.UserId)

	local body =
		configurePart(Instance.new("Part"), "Body", Vector3.new(1.25, 1.25, 1.25), primaryColor, Enum.Material.Metal)
	body.Shape = Enum.PartType.Ball
	body.Parent = model

	local core =
		configurePart(Instance.new("Part"), "Core", Vector3.new(0.62, 0.62, 0.62), accentColor, Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	core.CFrame = CFrame.new(0, 0, 0.52)
	core.Parent = model

	local ring = configurePart(
		Instance.new("Part"),
		"EnergyRing",
		Vector3.new(0.12, 1.65, 1.65),
		Color3.fromRGB(128, 94, 255),
		Enum.Material.Neon
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.Angles(0, math.rad(90), 0)
	ring.Transparency = 0.68
	ring.Parent = model

	local antenna = configurePart(
		Instance.new("Part"),
		"Antenna",
		Vector3.new(0.12, 0.55, 0.12),
		Color3.fromRGB(74, 255, 222),
		Enum.Material.Neon
	)
	antenna.CFrame = CFrame.new(0, 0.82, 0)
	antenna.Parent = model

	local light = Instance.new("PointLight")
	light.Name = "AssistLight"
	light.Color = core.Color
	light.Brightness = 1.4
	light.Range = 8
	light.Shadows = false
	light.Parent = core

	local upperTrailAttachment = Instance.new("Attachment")
	upperTrailAttachment.Name = "TrailTop"
	upperTrailAttachment.Position = Vector3.new(0, 0.28, 0.5)
	upperTrailAttachment.Parent = body

	local lowerTrailAttachment = Instance.new("Attachment")
	lowerTrailAttachment.Name = "TrailBottom"
	lowerTrailAttachment.Position = Vector3.new(0, -0.28, 0.5)
	lowerTrailAttachment.Parent = body

	local trail = Instance.new("Trail")
	trail.Name = "PhaseTrail"
	trail.Attachment0 = upperTrailAttachment
	trail.Attachment1 = lowerTrailAttachment
	trail.Color = ColorSequence.new(core.Color, ring.Color)
	trail.Lifetime = 0.28
	trail.LightEmission = 0.8
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = body

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Status"
	billboard.Adornee = body
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 45
	billboard.Size = UDim2.fromOffset(120, 28)
	billboard.StudsOffset = Vector3.new(0, 1.25, 0)
	billboard.Parent = body

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundColor3 = Color3.fromRGB(11, 20, 30)
	label.BackgroundTransparency = 0.22
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = "SOLO ASSIST"
	label.TextColor3 = core.Color
	label.TextScaled = true
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = ring.Color
	stroke.Thickness = 1
	stroke.Transparency = 0.25
	stroke.Parent = label

	model.PrimaryPart = body
	model.Parent = parent
	model:PivotTo(initialCFrame)
	return model
end

function SoloDrone.new(parent)
	local self = setmetatable({}, SoloDrone)
	self._parent = parent or workspace
	self._records = {}
	self._destroyed = false
	self._startedAt = os.clock()

	self._container = Instance.new("Folder")
	self._container.Name = "SoloDrones"
	self._container.Parent = self._parent

	self._heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		self:_update(deltaTime)
	end)

	self._playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		self:DestroyPlayer(player)
	end)

	return self
end

function SoloDrone:_destroyModel(record)
	if record.model then
		record.model:Destroy()
		record.model = nil
	end
end

function SoloDrone:_setCharacter(record, character)
	self:_destroyModel(record)
	record.character = character
end

function SoloDrone:_update(deltaTime)
	if self._destroyed then
		return
	end

	local hover = math.sin((os.clock() - self._startedAt) * 2.4) * 0.18
	local blend = 1 - math.exp(-FOLLOW_SPEED * math.min(deltaTime, 0.1))

	for player, record in pairs(self._records) do
		if not player.Parent then
			task.defer(function()
				self:DestroyPlayer(player)
			end)
			continue
		end

		local character = record.character
		local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not rootPart or (humanoid and humanoid.Health <= 0) then
			self:_destroyModel(record)
			continue
		end

		local target = rootPart.CFrame * FOLLOW_OFFSET * CFrame.new(0, hover, 0)
		if not record.model then
			record.model = createDrone(player, self._container, target)
		else
			record.model:PivotTo(record.model:GetPivot():Lerp(target, blend))
		end
	end
end

function SoloDrone:SetEnabledForPlayer(player, enabled)
	if self._destroyed then
		return
	end

	if not enabled then
		self:DestroyPlayer(player)
		return
	end

	if self._records[player] then
		return
	end

	local record = {
		character = player.Character,
		model = nil,
		characterAddedConnection = nil,
		characterRemovingConnection = nil,
	}
	self._records[player] = record

	record.characterAddedConnection = player.CharacterAdded:Connect(function(character)
		if self._records[player] == record then
			self:_setCharacter(record, character)
		end
	end)

	record.characterRemovingConnection = player.CharacterRemoving:Connect(function(character)
		if self._records[player] == record and record.character == character then
			self:_setCharacter(record, nil)
		end
	end)
end

function SoloDrone:DestroyPlayer(player)
	local record = self._records[player]
	if not record then
		return
	end

	self._records[player] = nil
	self:_destroyModel(record)

	if record.characterAddedConnection then
		record.characterAddedConnection:Disconnect()
	end
	if record.characterRemovingConnection then
		record.characterRemovingConnection:Disconnect()
	end
end

function SoloDrone:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
	end
	if self._playerRemovingConnection then
		self._playerRemovingConnection:Disconnect()
	end

	local playersToDestroy = {}
	for player in pairs(self._records) do
		table.insert(playersToDestroy, player)
	end
	for _, player in ipairs(playersToDestroy) do
		self:DestroyPlayer(player)
	end

	if self._container then
		self._container:Destroy()
	end
end

return SoloDrone
