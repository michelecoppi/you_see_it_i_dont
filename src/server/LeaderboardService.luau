local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

local REFRESH_INTERVAL = 45
local ENTRY_LIMIT = 8

local BOARD_CONFIG = {
	Success = {
		StatName = "ExpeditionsCompleted",
		StoreSuffix = "SuccessfulEscapes_v1",
		ValueLabel = "ESCAPES",
		EmptyText = "No successful escapes yet.\nBe the first explorer on this board!",
	},
	Failure = {
		StatName = "ExpeditionsFailed",
		StoreSuffix = "FailedEscapes_v1",
		ValueLabel = "FAILS",
		EmptyText = "Nobody has failed spectacularly yet.\nSuspiciously perfect...",
	},
}

function LeaderboardService.new(config, playerData, labels)
	local self = setmetatable({}, LeaderboardService)
	self._playerData = playerData
	self._labels = labels
	self._running = true
	self._nameCache = {}
	self._refreshScheduled = false
	self._persistenceEnabled = not RunService:IsStudio() or config.Economy.EnableStudioPersistence == true
	self._stores = {}

	if self._persistenceEnabled then
		for boardName, boardConfig in pairs(BOARD_CONFIG) do
			self._stores[boardName] =
				DataStoreService:GetOrderedDataStore(config.Economy.DataStoreName .. "_" .. boardConfig.StoreSuffix)
		end
	end

	task.spawn(function()
		while self._running do
			self:Refresh()
			task.wait(REFRESH_INTERVAL)
		end
	end)

	return self
end

function LeaderboardService:_resolveName(userId)
	local currentPlayer = Players:GetPlayerByUserId(userId)
	if currentPlayer then
		self._nameCache[userId] = currentPlayer.DisplayName
		return currentPlayer.DisplayName
	end

	if self._nameCache[userId] then
		return self._nameCache[userId]
	end

	local success, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if success and typeof(name) == "string" then
		self._nameCache[userId] = name
		return name
	end
	return "Explorer " .. tostring(userId)
end

function LeaderboardService:_localEntries(boardName)
	local boardConfig = BOARD_CONFIG[boardName]
	local entries = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = self._playerData:GetClientProfile(player)
		local value = profile and profile.Stats and profile.Stats[boardConfig.StatName]
		if typeof(value) == "number" and value > 0 then
			table.insert(entries, {
				UserId = player.UserId,
				Name = player.DisplayName,
				Value = math.floor(value),
			})
		end
	end
	table.sort(entries, function(a, b)
		if a.Value == b.Value then
			return string.lower(a.Name) < string.lower(b.Name)
		end
		return a.Value > b.Value
	end)
	while #entries > ENTRY_LIMIT do
		table.remove(entries)
	end
	return entries
end

function LeaderboardService:_globalEntries(boardName)
	local store = self._stores[boardName]
	if not store then
		return nil
	end

	local success, pages = pcall(function()
		return store:GetSortedAsync(false, ENTRY_LIMIT, 1)
	end)
	if not success then
		warn("Leaderboard read failed for " .. boardName .. ": " .. tostring(pages))
		return nil
	end

	local entries = {}
	for _, entry in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(entries, {
				UserId = userId,
				Name = self:_resolveName(userId),
				Value = math.floor(entry.value),
			})
		end
	end
	return entries
end

function LeaderboardService:_formatEntries(boardName, entries)
	local boardConfig = BOARD_CONFIG[boardName]
	if #entries == 0 then
		return boardConfig.EmptyText
	end

	local rows = {}
	for rank, entry in ipairs(entries) do
		table.insert(rows, string.format("%d.  %s     %d %s", rank, entry.Name, entry.Value, boardConfig.ValueLabel))
	end
	return table.concat(rows, "\n")
end

function LeaderboardService:_refreshBoard(boardName)
	local label = self._labels[boardName]
	if not label or not label.Parent then
		return
	end

	local entries = if self._persistenceEnabled then self:_globalEntries(boardName) else nil
	if not entries then
		entries = self:_localEntries(boardName)
	end
	label.Text = self:_formatEntries(boardName, entries)
end

function LeaderboardService:Refresh()
	for boardName in pairs(BOARD_CONFIG) do
		task.spawn(function()
			self:_refreshBoard(boardName)
		end)
	end
end

function LeaderboardService:_scheduleRefresh()
	if self._refreshScheduled then
		return
	end
	self._refreshScheduled = true
	task.delay(1.5, function()
		self._refreshScheduled = false
		if self._running then
			self:Refresh()
		end
	end)
end

function LeaderboardService:UpdatePlayer(player)
	local profile = self._playerData:GetClientProfile(player)
	if not profile or not profile.Stats then
		return
	end

	if self._persistenceEnabled then
		for boardName, boardConfig in pairs(BOARD_CONFIG) do
			local value = math.max(0, math.floor(profile.Stats[boardConfig.StatName] or 0))
			local store = self._stores[boardName]
			task.spawn(function()
				local success, errorMessage = pcall(function()
					store:SetAsync(tostring(player.UserId), value)
				end)
				if not success then
					warn(
						"Leaderboard update failed for "
							.. player.Name
							.. " / "
							.. boardName
							.. ": "
							.. tostring(errorMessage)
					)
				end
			end)
		end
	end

	self:_scheduleRefresh()
end

function LeaderboardService:Destroy()
	self._running = false
end

return LeaderboardService
