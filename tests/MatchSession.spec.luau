local Spec = {}

local function expectEqual(actual, expected, message)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local function expect(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function context(overrides)
	local base = {
		Enabled = true,
		IsStudio = false,
		StudioOverride = nil,
		PlaceId = 100,
		MatchPlaceId = 0,
		PrivateServerId = "",
		PrivateServerOwnerId = 0,
	}
	for key, value in pairs(overrides) do
		base[key] = value
	end
	return base
end

function Spec.run(MatchSession)
	local Roles = MatchSession.Roles

	-- Server roles
	expectEqual(MatchSession.ResolveRole(context({})), Roles.Lobby, "public server is a lobby")
	expectEqual(
		MatchSession.ResolveRole(context({ PrivateServerId = "abc" })),
		Roles.Match,
		"reserved server runs an expedition"
	)
	expectEqual(
		MatchSession.ResolveRole(context({ PrivateServerId = "abc", PrivateServerOwnerId = 42 })),
		Roles.Lobby,
		"VIP servers stay lobbies"
	)
	expectEqual(
		MatchSession.ResolveRole(context({ PlaceId = 200, MatchPlaceId = 200 })),
		Roles.Match,
		"dedicated expedition place is a match server"
	)
	expectEqual(
		MatchSession.ResolveRole(context({ Enabled = false, PrivateServerId = "abc" })),
		Roles.Standalone,
		"disabled sessions keep everything in one server"
	)
	expectEqual(MatchSession.ResolveRole(context({ IsStudio = true })), Roles.Standalone, "Studio is standalone")
	expectEqual(
		MatchSession.ResolveRole(context({ IsStudio = true, StudioOverride = "Match" })),
		Roles.Match,
		"Studio can exercise the match role"
	)
	expectEqual(
		MatchSession.ResolveRole(context({ IsStudio = true, StudioOverride = "Bogus" })),
		Roles.Standalone,
		"unknown Studio overrides are ignored"
	)

	-- Teleport data round trip
	local data = MatchSession.BuildTeleportData({
		SessionId = "session-1",
		Mode = "Group",
		Crew = { 11, 22, 22, 33, -1, 1.5 },
		Difficulty = "Hard",
		LobbyPlaceId = 100,
		CreatedAt = 5,
	})
	expectEqual(#data.Crew, 3, "crew drops duplicates and invalid ids")
	local session, reason = MatchSession.ParseTeleportData(data)
	expect(session ~= nil, "valid data parses: " .. tostring(reason))
	expectEqual(session.SessionId, "session-1", "keeps the session id")
	expectEqual(session.Mode, "Group", "keeps the mode")
	expectEqual(session.Difficulty, "Hard", "keeps the difficulty")
	expectEqual(session.LobbyPlaceId, 100, "keeps the lobby place")

	local solo = MatchSession.BuildTeleportData({ SessionId = "s", Mode = "Bogus", Crew = { 7 } })
	expectEqual(solo.Mode, "Solo", "infers Solo for one player")
	expectEqual(solo.Difficulty, "Normal", "falls back to the default difficulty")

	local tooMany = MatchSession.BuildTeleportData({ SessionId = "s", Crew = { 1, 2, 3, 4, 5, 6, 7, 8 } })
	expectEqual(#tooMany.Crew, MatchSession.MaxCrewSize, "caps the crew size")

	-- Rejections
	expectEqual(select(2, MatchSession.ParseTeleportData(nil)), "missing_data", "rejects missing data")
	expectEqual(select(2, MatchSession.ParseTeleportData({ Kind = "Other" })), "wrong_kind", "rejects foreign data")
	local tampered = table.clone(data)
	tampered.Crew = { 11, 11 }
	expectEqual(select(2, MatchSession.ParseTeleportData(tampered)), "invalid_crew", "rejects duplicate crew")
	tampered = table.clone(data)
	tampered.Crew = {}
	expectEqual(select(2, MatchSession.ParseTeleportData(tampered)), "invalid_crew", "rejects an empty crew")
	tampered = table.clone(data)
	tampered.Mode = "Raid"
	expectEqual(select(2, MatchSession.ParseTeleportData(tampered)), "invalid_mode", "rejects unknown modes")
	tampered = table.clone(data)
	tampered.Version = 99
	expectEqual(select(2, MatchSession.ParseTeleportData(tampered)), "wrong_version", "rejects other versions")
	tampered = table.clone(data)
	tampered.Difficulty = "Impossible"
	expectEqual(MatchSession.ParseTeleportData(tampered).Difficulty, "Normal", "sanitizes the difficulty")

	-- Return data
	local returnData = MatchSession.BuildReturnData("session-1", "Success")
	expect(MatchSession.IsReturnData(returnData), "return data is recognized")
	expect(not MatchSession.IsReturnData(data), "expedition data is not return data")

	-- Crew readiness
	expect(not MatchSession.IsCrewReady({ 1, 2 }, {}, 100, 25), "never starts with nobody")
	expect(not MatchSession.IsCrewReady({ 1, 2 }, { 1 }, 5, 25), "waits for the rest of the crew")
	expect(MatchSession.IsCrewReady({ 1, 2 }, { 1 }, 25, 25), "starts with whoever arrived after the timeout")
	expect(MatchSession.IsCrewReady({ 1, 2 }, { 2, 1 }, 0, 25), "starts as soon as everyone arrived")
end

return Spec
