local Players = game:GetService("Players")

local FloorPuzzle = {}
FloorPuzzle.__index = FloorPuzzle

local DEFAULTS = {
	Rows = 5,
	Columns = 5,
	TileSize = Vector3.new(4, 0.3, 3.2),
	Gap = 0.35,
	Origin = CFrame.new(0, 0.66, 20),
	FailureCooldown = 1.25,
	BaseColor = Color3.fromRGB(40, 47, 66),
}

local function readOption(options, name)
	local value = options and options[name]
	if value == nil then
		return DEFAULTS[name]
	end
	return value
end

local function positiveInteger(value, fallback)
	if typeof(value) ~= "number" then
		return fallback
	end
	return math.max(1, math.floor(value))
end

local function normalizedTileSize(value)
	if typeof(value) == "number" then
		local width = math.max(1, value)
		return Vector3.new(width, DEFAULTS.TileSize.Y, width)
	end
	if typeof(value) == "Vector3" then
		return Vector3.new(math.max(1, value.X), math.max(0.1, value.Y), math.max(1, value.Z))
	end
	return DEFAULTS.TileSize
end

local function normalizedOrigin(value)
	if typeof(value) == "Vector3" then
		return CFrame.new(value)
	end
	if typeof(value) == "CFrame" then
		return value
	end
	return DEFAULTS.Origin
end

local function createTile(parent, name, size, cframe, color)
	local tile = Instance.new("Part")
	tile.Name = name
	tile.Size = size
	tile.CFrame = cframe
	tile.Color = color
	tile.Material = Enum.Material.Metal
	tile.Anchored = true
	tile.CanCollide = true
	tile.CanTouch = true
	tile.CanQuery = true
	tile.TopSurface = Enum.SurfaceType.Smooth
	tile.BottomSurface = Enum.SurfaceType.Smooth
	tile:SetAttribute("FloorPuzzleTile", true)
	tile.Parent = parent
	return tile
end

local function findCharacterFromHit(hit)
	if not hit or not hit:IsA("BasePart") then
		return nil, nil
	end

	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end

	return character, humanoid
end

function FloorPuzzle.new(mapRoot, spawnPart, options)
	assert(typeof(mapRoot) == "Instance", "FloorPuzzle.new expects a map root Instance")
	assert(spawnPart == nil or spawnPart:IsA("BasePart"), "spawnPart must be a BasePart or nil")

	local self = setmetatable({}, FloorPuzzle)
	self._mapRoot = mapRoot
	self._spawnPart = spawnPart
	self._rows = positiveInteger(readOption(options, "Rows"), DEFAULTS.Rows)
	self._columns = positiveInteger(readOption(options, "Columns"), DEFAULTS.Columns)
	self._tileSize = normalizedTileSize(readOption(options, "TileSize"))
	self._gap = math.max(0, readOption(options, "Gap"))
	self._origin = normalizedOrigin(readOption(options, "Origin"))
	self._failureCooldown = math.max(0, readOption(options, "FailureCooldown"))
	self._baseColor = readOption(options, "BaseColor")
	self._random = options and options.Random or Random.new()
	self._failureCallback = options and options.FailureCallback or nil
	self._active = false
	self._destroyed = false
	self._safeByTile = {}
	self._touchDebounces = {}
	self._connections = {}
	self._tiles = {}

	local previous = mapRoot:FindFirstChild("FloorPuzzle")
	if previous then
		previous:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "FloorPuzzle"
	folder.Parent = mapRoot
	self._folder = folder

	local xStep = self._tileSize.X + self._gap
	local zStep = self._tileSize.Z + self._gap
	local xCenter = (self._columns + 1) / 2
	local zCenter = (self._rows + 1) / 2

	for row = 1, self._rows do
		self._tiles[row] = {}
		for column = 1, self._columns do
			local offset = Vector3.new((column - xCenter) * xStep, 0, (row - zCenter) * zStep)
			local tileCFrame = self._origin * CFrame.new(offset)
			local tile = createTile(
				folder,
				string.format("Tile_%02d_%02d", row, column),
				self._tileSize,
				tileCFrame,
				self._baseColor
			)
			tile:SetAttribute("FloorPuzzleRow", row)
			tile:SetAttribute("FloorPuzzleColumn", column)
			self._tiles[row][column] = tile

			table.insert(
				self._connections,
				tile.Touched:Connect(function(hit)
					self:_onTileTouched(tile, hit)
				end)
			)
		end
	end

	self:Reset()
	return self
end

function FloorPuzzle:_generateSafePath()
	local safeByTile = {}
	local column = math.ceil(self._columns / 2)

	for row = 1, self._rows do
		if row > 1 then
			local minimumShift = if column <= 1 then 0 else -1
			local maximumShift = if column >= self._columns then 0 else 1
			column += self._random:NextInteger(minimumShift, maximumShift)
		end

		local tile = self._tiles[row][column]
		safeByTile[tile] = true
	end

	return safeByTile
end

function FloorPuzzle:_failPlayer(player, character, humanoid, tile)
	if self._failureCallback then
		local ok, errorMessage = pcall(self._failureCallback, player, tile, humanoid)
		if not ok then
			warn("FloorPuzzle failure callback errored: " .. tostring(errorMessage))
		end
		return
	end

	if self._spawnPart and self._spawnPart.Parent and character.Parent then
		character:PivotTo(self._spawnPart.CFrame + Vector3.new(0, 4, 0))
	end
end

function FloorPuzzle:_onTileTouched(tile, hit)
	if not self._active or self._destroyed or self._safeByTile[tile] then
		return
	end

	local character, humanoid = findCharacterFromHit(hit)
	if not character then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player or self._touchDebounces[player] then
		return
	end

	self._touchDebounces[player] = true
	self:_failPlayer(player, character, humanoid, tile)

	task.delay(self._failureCooldown, function()
		if not self._destroyed then
			self._touchDebounces[player] = nil
		end
	end)
end

function FloorPuzzle:Reset()
	if self._destroyed then
		return
	end

	table.clear(self._touchDebounces)
	self._safeByTile = self:_generateSafePath()
end

function FloorPuzzle:SetActive(isActive)
	if self._destroyed then
		return
	end
	self._active = isActive == true
	if not self._active then
		table.clear(self._touchDebounces)
	end
end

function FloorPuzzle:SetFailureCallback(callback)
	assert(callback == nil or typeof(callback) == "function", "callback must be a function or nil")
	self._failureCallback = callback
end

function FloorPuzzle:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._active = false
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._touchDebounces)
	table.clear(self._safeByTile)

	if self._folder then
		self._folder:Destroy()
		self._folder = nil
	end
end

return FloorPuzzle
