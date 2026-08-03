local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local QAService = {}
QAService.__index = QAService

local ATTRIBUTE_NAMES = {
	Enabled = "QAEnabled",
	Seed = "QASeed",
	Difficulty = "QADifficulty",
	Preset = "QAPreset",
	Role = "QARole",
	PlayerCount = "QAPlayerCount",
	StartRoom = "QAStartRoom",
}

local function getAttributeOrDefault(name, defaultValue)
	-- DataModel attributes set in edit mode are not copied reliably into Studio's
	-- Play clone. Workspace is serialized in the place and survives the transition.
	local value = Workspace:GetAttribute(name)
	if value == nil then
		-- Keep compatibility with places that already configured the DataModel.
		value = game:GetAttribute(name)
	end
	if value == nil then
		return defaultValue
	end
	return value
end

local function contains(array, target)
	for _, value in ipairs(array) do
		if value == target then
			return true
		end
	end
	return false
end

function QAService.new(config, seedUtil)
	local defaults = config.QA or {}
	local self = setmetatable({}, QAService)
	self._config = config
	self._seedUtil = seedUtil
	self.Enabled = RunService:IsStudio()
		and getAttributeOrDefault(ATTRIBUTE_NAMES.Enabled, defaults.Enabled == true) == true
	self.PlayerCount = math.clamp(
		math.floor(tonumber(getAttributeOrDefault(ATTRIBUTE_NAMES.PlayerCount, defaults.PlayerCount)) or 1),
		1,
		6
	)
	self.StartRoom = math.clamp(
		math.floor(tonumber(getAttributeOrDefault(ATTRIBUTE_NAMES.StartRoom, defaults.StartRoom)) or 1),
		1,
		config.Round.RoomCount or 3
	)
	local difficultyLevels = (config.Difficulty and config.Difficulty.Levels) or { "Easy", "Normal", "Hard" }
	local defaultDifficulty = (config.Difficulty and config.Difficulty.Default) or "Normal"
	local requestedDifficulty =
		tostring(getAttributeOrDefault(ATTRIBUTE_NAMES.Difficulty, defaults.Difficulty or defaultDifficulty) or "")
	self.Difficulty = if contains(difficultyLevels, requestedDifficulty) then requestedDifficulty else defaultDifficulty

	local requestedSeed = getAttributeOrDefault(ATTRIBUTE_NAMES.Seed, defaults.Seed)
	self.Seed = if requestedSeed ~= nil then seedUtil.Normalize(requestedSeed) else nil

	local requestedPreset = tostring(getAttributeOrDefault(ATTRIBUTE_NAMES.Preset, defaults.Preset) or "")
	self.Preset = if contains(config.PuzzleOrder, requestedPreset) then requestedPreset else nil

	local requestedRole = tostring(getAttributeOrDefault(ATTRIBUTE_NAMES.Role, defaults.Role) or "")
	if
		requestedRole == config.Roles.Seer
		or requestedRole == config.Roles.Operator
		or requestedRole == config.Roles.Hybrid
	then
		self.Role = requestedRole
	else
		self.Role = nil
	end

	if self.Enabled then
		print(
			string.format(
				"[QA][Server] enabled | seed=%s | preset=%s | difficulty=%s | role=%s | players=%d | startRoom=%d",
				self.Seed and seedUtil.Identifier(self.Seed) or "automatic",
				self.Preset or "random",
				self.Difficulty,
				self.Role or "automatic",
				self.PlayerCount,
				self.StartRoom
			)
		)
	end
	return self
end

function QAService:GetReadyPlayers()
	if not self.Enabled then
		return nil
	end

	local ready = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("PlayerState") ~= "Playing" then
			table.insert(ready, player)
		end
	end
	table.sort(ready, function(a, b)
		return a.UserId < b.UserId
	end)
	if #ready < self.PlayerCount then
		return nil
	end

	local selected = {}
	for index = 1, self.PlayerCount do
		table.insert(selected, ready[index])
	end
	return selected
end

function QAService:ApplyRole(playerIndex, playerCount, assignedRole)
	if not self.Enabled or not self.Role then
		return assignedRole
	end
	if playerCount == 1 then
		return self.Role
	end
	if playerIndex == 1 then
		return self.Role
	elseif playerIndex == 2 then
		return if self.Role == self._config.Roles.Seer then self._config.Roles.Operator else self._config.Roles.Seer
	end
	return assignedRole
end

function QAService:GetGenerationOptions()
	if not self.Enabled then
		return nil
	end
	return {
		ForcedPreset = self.Preset,
		StartRoomIndex = self.StartRoom,
		Difficulty = self.Difficulty,
	}
end

return QAService
