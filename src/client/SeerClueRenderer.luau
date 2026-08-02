local SeerClueRenderer = {}
SeerClueRenderer.__index = SeerClueRenderer

local function markClue(instance, active)
	instance:SetAttribute("VisibleToRole", "Seer")
	instance:SetAttribute("RequiresRoomActive", true)
	instance:SetAttribute("RoomActive", active)
end

local function addBillboard(anchor, clue, active)
	local gui = Instance.new("BillboardGui")
	gui.Name = "LocalSeerClue_" .. clue.Id
	gui.Size = clue.Size
	gui.StudsOffset = clue.Offset
	gui.AlwaysOnTop = true
	markClue(gui, active)
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(34, 43, 61)
	label.BackgroundTransparency = 0.08
	label.Font = Enum.Font.GothamBlack
	label.Text = clue.Text
	label.TextColor3 = clue.Color
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = clue.Color
	stroke.Thickness = 3
	stroke.Parent = label
	return gui
end

function SeerClueRenderer.new(mapName)
	local self = setmetatable({}, SeerClueRenderer)
	self._mapName = mapName
	self._instances = {}
	self._renderKey = nil
	self._renderGeneration = 0
	self._activeRoomIndex = 0
	self._roundActive = false
	return self
end

function SeerClueRenderer:_clear()
	for _, instance in ipairs(self._instances) do
		if instance.Parent then
			instance:Destroy()
		end
	end
	table.clear(self._instances)
	self._renderKey = nil
end

function SeerClueRenderer:_setActiveState()
	for _, instance in ipairs(self._instances) do
		local active = self._roundActive and instance:GetAttribute("RoomIndex") == self._activeRoomIndex
		instance:SetAttribute("RoomActive", active)
	end
end

function SeerClueRenderer:_tryRender(clues, renderKey)
	local map = workspace:FindFirstChild(self._mapName)
	local generated = map and map:FindFirstChild("GeneratedRooms")
	if not generated then
		return false
	end

	self:_clear()
	local localParts = {}
	for _, clue in ipairs(clues) do
		if clue.Kind == "Part" then
			local part = Instance.new("Part")
			part.Name = clue.Name
			part.Size = clue.Size
			part.CFrame = clue.CFrame
			part.Color = clue.Color
			part.Material = if clue.Material then Enum.Material[clue.Material] else Enum.Material.SmoothPlastic
			part.Shape = if clue.Shape then Enum.PartType[clue.Shape] else Enum.PartType.Block
			part.Transparency = clue.Transparency
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part:SetAttribute("RoomIndex", clue.RoomIndex)
			markClue(part, false)
			part.Parent = generated
			localParts[tostring(clue.RoomIndex) .. ":" .. clue.Name] = part
			table.insert(self._instances, part)
		end
	end

	for _, clue in ipairs(clues) do
		if clue.Kind == "Billboard" then
			local roomPrefix = string.format("Room_%02d_", clue.RoomIndex)
			local roomModel
			for _, child in ipairs(generated:GetChildren()) do
				if child:IsA("Model") and string.sub(child.Name, 1, #roomPrefix) == roomPrefix then
					roomModel = child
					break
				end
			end
			local anchor = localParts[tostring(clue.RoomIndex) .. ":" .. clue.AnchorName]
				or (roomModel and roomModel:FindFirstChild(clue.AnchorName, true))
			if not anchor then
				self:_clear()
				return false
			end
			local gui = addBillboard(anchor, clue, false)
			gui:SetAttribute("RoomIndex", clue.RoomIndex)
			table.insert(self._instances, gui)
		end
	end

	self._renderKey = renderKey
	self:_setActiveState()
	return true
end

function SeerClueRenderer:Sync(clues, renderKey, activeRoomIndex, roundActive)
	self._activeRoomIndex = activeRoomIndex or 0
	self._roundActive = roundActive == true

	if typeof(clues) ~= "table" or #clues == 0 then
		self._renderGeneration += 1
		self:_clear()
		return
	end
	local instancesAreLive = #self._instances > 0
	for _, instance in ipairs(self._instances) do
		if not instance.Parent then
			instancesAreLive = false
			break
		end
	end
	if self._renderKey == renderKey and instancesAreLive then
		self:_setActiveState()
		return
	end

	self._renderGeneration += 1
	local generation = self._renderGeneration
	if self:_tryRender(clues, renderKey) then
		return
	end
	task.spawn(function()
		for _ = 1, 20 do
			task.wait(0.1)
			if generation ~= self._renderGeneration then
				return
			end
			if self:_tryRender(clues, renderKey) then
				return
			end
		end
	end)
end

function SeerClueRenderer:Destroy()
	self._renderGeneration += 1
	self:_clear()
end

return SeerClueRenderer
