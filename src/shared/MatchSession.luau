-- Pure helpers for the lobby -> expedition server hand-off. No Roblox services are used here so the
-- teleport contract can be unit tested; MatchSessionService does the actual TeleportService calls.
local Difficulty = require(script.Parent.Difficulty)

local MatchSession = {}

MatchSession.Version = 1
MatchSession.Kind = "RealityExpedition"
MatchSession.ReturnKind = "RealityExpeditionReturn"
MatchSession.MaxCrewSize = 6

MatchSession.Roles = table.freeze({
	-- Lobby and expeditions share one server (Studio, or sessions disabled).
	Standalone = "Standalone",
	-- Public hub server: queues players and teleports each expedition to a reserved server.
	Lobby = "Lobby",
	-- Reserved server that runs exactly one expedition, then sends the crew back to a hub.
	Match = "Match",
})

local validModes = { Solo = true, Group = true }

local function isPositiveInteger(value)
	return type(value) == "number" and value == value and value >= 1 and value % 1 == 0 and value < 2 ^ 53
end

-- Decides what this server does. `context` is a plain table so the rule can be tested:
--   Enabled, IsStudio, StudioOverride, PlaceId, MatchPlaceId, PrivateServerId, PrivateServerOwnerId
function MatchSession.ResolveRole(context)
	if context.IsStudio then
		local override = context.StudioOverride
		if override == MatchSession.Roles.Match or override == MatchSession.Roles.Lobby then
			return override
		end
		return MatchSession.Roles.Standalone
	end
	if not context.Enabled then
		return MatchSession.Roles.Standalone
	end
	if isPositiveInteger(context.MatchPlaceId) and context.PlaceId == context.MatchPlaceId then
		return MatchSession.Roles.Match
	end
	-- Reserved servers have a private server id but no owner (VIP servers have an owner).
	if
		context.PrivateServerId ~= nil
		and context.PrivateServerId ~= ""
		and (context.PrivateServerOwnerId or 0) == 0
	then
		return MatchSession.Roles.Match
	end
	return MatchSession.Roles.Lobby
end

function MatchSession.BuildTeleportData(options)
	local crew = {}
	for _, userId in ipairs(options.Crew) do
		if isPositiveInteger(userId) and #crew < MatchSession.MaxCrewSize and not table.find(crew, userId) then
			table.insert(crew, userId)
		end
	end
	return {
		Kind = MatchSession.Kind,
		Version = MatchSession.Version,
		SessionId = tostring(options.SessionId),
		Mode = if validModes[options.Mode] then options.Mode else (if #crew > 1 then "Group" else "Solo"),
		Crew = crew,
		Difficulty = if Difficulty.IsValid(options.Difficulty) then options.Difficulty else Difficulty.Default,
		LobbyPlaceId = if isPositiveInteger(options.LobbyPlaceId) then options.LobbyPlaceId else nil,
		CreatedAt = if type(options.CreatedAt) == "number" then options.CreatedAt else 0,
	}
end

-- Validates teleport data read from Player:GetJoinData(). Returns the sanitized session or nil, reason.
-- Only servers can teleport into a reserved server (they need its access code), but the payload is
-- still treated as untrusted input and every field is re-validated.
function MatchSession.ParseTeleportData(data)
	if type(data) ~= "table" then
		return nil, "missing_data"
	end
	if data.Kind ~= MatchSession.Kind then
		return nil, "wrong_kind"
	end
	if data.Version ~= MatchSession.Version then
		return nil, "wrong_version"
	end
	if type(data.SessionId) ~= "string" or #data.SessionId == 0 or #data.SessionId > 64 then
		return nil, "invalid_session"
	end
	if type(data.Crew) ~= "table" or #data.Crew == 0 or #data.Crew > MatchSession.MaxCrewSize then
		return nil, "invalid_crew"
	end
	local crew = {}
	for _, userId in ipairs(data.Crew) do
		if not isPositiveInteger(userId) or table.find(crew, userId) then
			return nil, "invalid_crew"
		end
		table.insert(crew, userId)
	end
	if not validModes[data.Mode] then
		return nil, "invalid_mode"
	end
	return {
		SessionId = data.SessionId,
		Mode = data.Mode,
		Crew = crew,
		Difficulty = if Difficulty.IsValid(data.Difficulty) then data.Difficulty else Difficulty.Default,
		LobbyPlaceId = if isPositiveInteger(data.LobbyPlaceId) then data.LobbyPlaceId else nil,
	}
end

function MatchSession.BuildReturnData(sessionId, outcome)
	return {
		Kind = MatchSession.ReturnKind,
		Version = MatchSession.Version,
		SessionId = tostring(sessionId or ""),
		Outcome = if type(outcome) == "string" then string.sub(outcome, 1, 32) else "Unknown",
	}
end

function MatchSession.IsReturnData(data)
	return type(data) == "table" and data.Kind == MatchSession.ReturnKind and data.Version == MatchSession.Version
end

-- True once every expected crew member has arrived, or once the wait expired with at least one arrival.
function MatchSession.IsCrewReady(expectedUserIds, arrivedUserIds, elapsedSeconds, timeoutSeconds)
	if #arrivedUserIds == 0 then
		return false
	end
	for _, userId in ipairs(expectedUserIds) do
		if not table.find(arrivedUserIds, userId) then
			return elapsedSeconds >= timeoutSeconds
		end
	end
	return true
end

return table.freeze(MatchSession)
