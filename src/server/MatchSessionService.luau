-- Runs each expedition in its own reserved server ("session").
--   Lobby role: reserves a server and teleports the selected crew there with signed-off teleport data.
--   Match role: collects the arriving crew, and after the expedition teleports everyone back to a hub.
-- The teleport contract (data format, validation, role rules) lives in Shared/MatchSession.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local MatchSession = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MatchSession"))

local MatchSessionService = {}
MatchSessionService.__index = MatchSessionService
MatchSessionService.Roles = MatchSession.Roles

local function withRetries(attempts, delaySeconds, callback)
	local lastError
	for attempt = 1, math.max(1, attempts) do
		local success, result = pcall(callback)
		if success then
			return true, result
		end
		lastError = result
		if attempt < attempts then
			task.wait(delaySeconds * attempt)
		end
	end
	return false, lastError
end

local function alivePlayers(players)
	local alive = {}
	for _, player in ipairs(players) do
		if player.Parent == Players then
			table.insert(alive, player)
		end
	end
	return alive
end

function MatchSessionService.new(config, callbacks)
	local self = setmetatable({}, MatchSessionService)
	self._config = config.Sessions or {}
	self._callbacks = callbacks or {}
	self._pending = {}
	self._arrived = {}
	self._isStudio = RunService:IsStudio()
	self.Session = nil
	self.Role = MatchSession.ResolveRole({
		Enabled = self._config.Enabled == true,
		IsStudio = self._isStudio,
		StudioOverride = if self._isStudio
			then Workspace:GetAttribute(self._config.StudioRoleOverrideAttribute or "ServerRoleOverride")
			else nil,
		PlaceId = game.PlaceId,
		MatchPlaceId = self._config.MatchPlaceId,
		PrivateServerId = game.PrivateServerId,
		PrivateServerOwnerId = game.PrivateServerOwnerId,
	})

	if self.Role ~= MatchSession.Roles.Standalone then
		TeleportService.TeleportInitFailed:Connect(function(player, result, message)
			self:_onTeleportFailed(player, result, message)
		end)
		Players.PlayerRemoving:Connect(function(player)
			self._pending[player] = nil
		end)
	end
	return self
end

function MatchSessionService:IsLobby()
	return self.Role == MatchSession.Roles.Lobby
end

function MatchSessionService:IsMatch()
	return self.Role == MatchSession.Roles.Match
end

function MatchSessionService:GetMatchPlaceId()
	local placeId = self._config.MatchPlaceId
	return if type(placeId) == "number" and placeId > 0 then placeId else game.PlaceId
end

function MatchSessionService:GetLobbyPlaceId()
	local placeId = self._config.LobbyPlaceId
	if type(placeId) == "number" and placeId > 0 then
		return placeId
	end
	if self.Session and self.Session.LobbyPlaceId then
		return self.Session.LobbyPlaceId
	end
	return game.PlaceId
end

function MatchSessionService:_teleport(players, placeId, options, kind)
	for _, player in ipairs(players) do
		self._pending[player] = { PlaceId = placeId, Options = options, Attempts = 1, Kind = kind }
	end
	local success, result = withRetries(
		self._config.TeleportAttempts or 3,
		self._config.RetryDelaySeconds or 2,
		function()
			return TeleportService:TeleportAsync(placeId, alivePlayers(players), options)
		end
	)
	if not success then
		for _, player in ipairs(players) do
			self._pending[player] = nil
		end
	end
	return success, result
end

function MatchSessionService:_onTeleportFailed(player, result, message)
	local pending = self._pending[player]
	if not pending or result == Enum.TeleportResult.IsTeleporting then
		return
	end
	warn(
		string.format(
			"[Sessions] %s teleport failed for userId=%d (attempt %d): %s %s",
			pending.Kind,
			player.UserId,
			pending.Attempts,
			tostring(result),
			tostring(message)
		)
	)
	if pending.Attempts < (self._config.TeleportAttempts or 3) then
		pending.Attempts += 1
		task.delay((self._config.RetryDelaySeconds or 2) * pending.Attempts, function()
			if self._pending[player] ~= pending or player.Parent ~= Players then
				return
			end
			local success, errorMessage = pcall(function()
				return TeleportService:TeleportAsync(pending.PlaceId, { player }, pending.Options)
			end)
			if not success then
				self:_onTeleportFailed(player, Enum.TeleportResult.Failure, errorMessage)
			end
		end)
		return
	end
	self._pending[player] = nil
	if self._callbacks.OnTeleportFailed then
		self._callbacks.OnTeleportFailed(player, pending.Kind, message)
	end
end

-- Lobby role: reserve a fresh server and send the crew there. Yields. Returns ok, sessionId|reason.
function MatchSessionService:LaunchExpedition(players, mode, difficulty)
	players = alivePlayers(players)
	if #players == 0 then
		return false, "no_players"
	end
	local placeId = self:GetMatchPlaceId()
	local reserved, accessCode = withRetries(
		self._config.ReserveAttempts or 3,
		self._config.RetryDelaySeconds or 2,
		function()
			return TeleportService:ReserveServer(placeId)
		end
	)
	if not reserved then
		return false, "reserve_failed: " .. tostring(accessCode)
	end

	local crew = {}
	for _, player in ipairs(players) do
		table.insert(crew, player.UserId)
	end
	local data = MatchSession.BuildTeleportData({
		SessionId = HttpService:GenerateGUID(false),
		Mode = mode,
		Crew = crew,
		Difficulty = difficulty,
		LobbyPlaceId = game.PlaceId,
		CreatedAt = os.time(),
	})
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData(data)

	local success, result = self:_teleport(players, placeId, options, "Expedition")
	if not success then
		return false, "teleport_failed: " .. tostring(result)
	end
	return true, data.SessionId
end

-- Match role: validates a joining player against the session's crew. Returns accepted, reason.
function MatchSessionService:RegisterArrival(player)
	if table.find(self._arrived, player.UserId) then
		return true
	end
	if self._isStudio then
		-- Studio "Match" override: there is no teleport data, every tester joins the crew.
		self.Session = self.Session
			or {
				SessionId = "studio-" .. HttpService:GenerateGUID(false),
				Mode = "Solo",
				Crew = {},
				Difficulty = nil,
			}
		table.insert(self.Session.Crew, player.UserId)
		self.Session.Mode = if #self.Session.Crew > 1 then "Group" else "Solo"
		table.insert(self._arrived, player.UserId)
		return true
	end

	local joinData = player:GetJoinData()
	if joinData.SourceGameId ~= nil and joinData.SourceGameId ~= game.GameId then
		return false, "foreign_source"
	end
	local session, reason = MatchSession.ParseTeleportData(joinData.TeleportData)
	if not session then
		return false, reason
	end
	if not self.Session then
		self.Session = session
	elseif session.SessionId ~= self.Session.SessionId then
		return false, "session_mismatch"
	end
	if not table.find(self.Session.Crew, player.UserId) then
		return false, "not_in_crew"
	end
	table.insert(self._arrived, player.UserId)
	return true
end

-- Match role: yields until the expected crew has arrived and `isReady(player)` holds for each of
-- them, or until the wait expires with at least one ready player.
function MatchSessionService:WaitForCrew(isReady, onTick)
	local firstReadyAt
	while true do
		local readyIds = {}
		local readyPlayers = {}
		for _, userId in ipairs(self._arrived) do
			local player = Players:GetPlayerByUserId(userId)
			if player and isReady(player) then
				table.insert(readyIds, userId)
				table.insert(readyPlayers, player)
			end
		end
		if #readyIds > 0 and not firstReadyAt then
			firstReadyAt = os.clock()
		end
		local elapsed = if firstReadyAt then os.clock() - firstReadyAt else 0
		if self._isStudio then
			if firstReadyAt and elapsed >= (self._config.StudioCrewWaitSeconds or 3) then
				return readyPlayers
			end
		else
			local expected = if self.Session then self.Session.Crew else readyIds
			if MatchSession.IsCrewReady(expected, readyIds, elapsed, self._config.CrewWaitSeconds or 25) then
				return readyPlayers
			end
		end
		if onTick then
			onTick(#readyIds, if self.Session then #self.Session.Crew else #readyIds)
		end
		task.wait(0.25)
	end
end

-- Match role: sends players back to a public hub server. Yields. Returns true when the teleport started.
function MatchSessionService:ReturnToLobby(players, outcome)
	players = alivePlayers(players)
	if #players == 0 then
		return true
	end
	if self._isStudio then
		-- TeleportService is unavailable in Studio: keep the testers here for another expedition.
		print("[Sessions] Studio: skipping the return teleport (" .. tostring(outcome) .. ")")
		return false
	end
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(MatchSession.BuildReturnData(self.Session and self.Session.SessionId, outcome))
	local success, result = self:_teleport(players, self:GetLobbyPlaceId(), options, "Return")
	if not success then
		warn("[Sessions] Return teleport failed: " .. tostring(result))
		for _, player in ipairs(alivePlayers(players)) do
			player:Kick("The expedition is over but the hub could not be reached. Rejoin to return to the lobby.")
		end
	end
	return success
end

-- Lobby role: returns the return payload when a player comes back from an expedition server.
function MatchSessionService:GetReturnData(player)
	if self._isStudio then
		return nil
	end
	local success, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if success and MatchSession.IsReturnData(joinData.TeleportData) then
		return joinData.TeleportData
	end
	return nil
end

return MatchSessionService
