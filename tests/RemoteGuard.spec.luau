local Spec = {}

local function expect(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function expectAccepted(guard, player, payload, expectedAction)
	local accepted, action = guard:Validate(player, payload)
	expect(accepted == true, string.format("expected %s to be accepted, got %s", expectedAction, tostring(action)))
	expect(action == expectedAction, string.format("expected action %s, got %s", expectedAction, tostring(action)))
end

local function expectRejected(guard, player, payload, expectedReason)
	local accepted, reason = guard:Validate(player, payload)
	expect(accepted == false, string.format("expected rejection %s", expectedReason))
	expect(reason == expectedReason, string.format("expected %s, got %s", expectedReason, tostring(reason)))
end

local function testContracts(RemoteGuard)
	local player = { UserId = 101 }
	local guard = RemoteGuard.new({
		Categories = {
			Global = { Capacity = 100, RefillPerSecond = 0 },
			Lobby = { Capacity = 100, RefillPerSecond = 0 },
			Vision = { Capacity = 100, RefillPerSecond = 0 },
			Economy = { Capacity = 100, RefillPerSecond = 0 },
			Puzzle = { Capacity = 100, RefillPerSecond = 0 },
		},
	})

	for _, action in ipairs({
		"RequestState",
		"Solo",
		"Group",
		"CancelQueue",
		"OpenShop",
		"OpenStats",
		"OpenWardrobe",
		"RequestVision",
	}) do
		expectAccepted(guard, player, { action = action }, action)
	end
	expectAccepted(guard, player, { action = "BuySoft", itemId = "drone_mint" }, "BuySoft")
	expectAccepted(guard, player, { action = "Equip", itemId = "trail_cyan" }, "Equip")
	expectAccepted(guard, player, { action = "BuyPremium", itemId = "drone_void" }, "BuyPremium")
	expectAccepted(guard, player, { action = "BuyShards", productKey = "small" }, "BuyShards")

	expectRejected(guard, player, nil, "invalid_payload")
	expectRejected(guard, player, true, "invalid_payload")
	expectRejected(guard, player, "RequestState", "invalid_payload")
	expectRejected(guard, player, {}, "invalid_action")
	expectRejected(guard, player, { action = 123 }, "invalid_action")
	expectRejected(guard, player, { action = "" }, "invalid_action")
	expectRejected(guard, player, { action = string.rep("A", 41) }, "invalid_action")
	expectRejected(guard, player, { action = "AdminGiveShards" }, "unknown_action")
	expectRejected(guard, player, { action = "RequestVision", duration = 9999 }, "unknown_field")
	expectRejected(guard, player, { action = "BuySoft" }, "invalid_field")
	expectRejected(guard, player, { action = "BuySoft", itemId = {} }, "invalid_field")
	expectRejected(guard, player, { action = "BuySoft", itemId = "" }, "invalid_field")
	expectRejected(guard, player, { action = "BuySoft", itemId = string.rep("x", 4096) }, "invalid_field")
	expectRejected(guard, player, { [1] = "unexpected", action = "RequestState" }, "unknown_field")
end

local function testGlobalFloodLimit(RemoteGuard)
	local player = { UserId = 151 }
	local guard = RemoteGuard.new({
		Categories = {
			Global = { Capacity = 3, RefillPerSecond = 0 },
			Lobby = { Capacity = 100, RefillPerSecond = 0 },
			Vision = { Capacity = 100, RefillPerSecond = 0 },
			Economy = { Capacity = 100, RefillPerSecond = 0 },
			Puzzle = { Capacity = 100, RefillPerSecond = 0 },
		},
	})

	for _ = 1, 3 do
		expectRejected(guard, player, { action = "UnknownFloodAction" }, "unknown_action")
	end
	expectRejected(guard, player, { action = "UnknownFloodAction" }, "global_rate_limited")
end

local function testIndependentRateLimits(RemoteGuard)
	local now = 50
	local player = { UserId = 202 }
	local guard = RemoteGuard.new({
		Categories = {
			Global = { Capacity = 100, RefillPerSecond = 0 },
			Lobby = { Capacity = 2, RefillPerSecond = 0 },
			Vision = { Capacity = 1, RefillPerSecond = 0 },
			Economy = { Capacity = 1, RefillPerSecond = 0 },
			Puzzle = { Capacity = 2, RefillPerSecond = 0 },
		},
	}, {
		Clock = function()
			return now
		end,
	})

	expectAccepted(guard, player, { action = "RequestState" }, "RequestState")
	expectAccepted(guard, player, { action = "Solo" }, "Solo")
	expectRejected(guard, player, { action = "Group" }, "lobby_rate_limited")

	expectAccepted(guard, player, { action = "RequestVision" }, "RequestVision")
	expectRejected(guard, player, { action = "RequestVision" }, "vision_rate_limited")

	expectAccepted(guard, player, { action = "Equip", itemId = "drone_default" }, "Equip")
	expectRejected(guard, player, { action = "BuySoft", itemId = "drone_mint" }, "economy_rate_limited")

	local puzzleAllowed = guard:Allow(player, "Puzzle", "SignalButton")
	expect(puzzleAllowed == true, "first puzzle action should be allowed")
	puzzleAllowed = guard:Allow(player, "Puzzle", "SignalButton")
	expect(puzzleAllowed == true, "second puzzle action should be allowed")
	local _, puzzleReason = guard:Allow(player, "Puzzle", "SignalButton")
	expect(puzzleReason == "puzzle_rate_limited", "puzzle actions should use their own bucket")

	guard:RemovePlayer(player)
	expectAccepted(guard, player, { action = "RequestVision" }, "RequestVision")
end

local function testRefill(RemoteGuard)
	local now = 100
	local player = { UserId = 303 }
	local guard = RemoteGuard.new({
		Categories = {
			Global = { Capacity = 100, RefillPerSecond = 0 },
			Lobby = { Capacity = 1, RefillPerSecond = 1 },
			Vision = { Capacity = 10, RefillPerSecond = 0 },
			Economy = { Capacity = 10, RefillPerSecond = 0 },
			Puzzle = { Capacity = 10, RefillPerSecond = 0 },
		},
	}, {
		Clock = function()
			return now
		end,
	})

	expectAccepted(guard, player, { action = "RequestState" }, "RequestState")
	expectRejected(guard, player, { action = "RequestState" }, "lobby_rate_limited")
	now += 1
	expectAccepted(guard, player, { action = "RequestState" }, "RequestState")
end

local function testSampledLogging(RemoteGuard)
	local now = 200
	local logs = {}
	local player = { UserId = 404 }
	local guard = RemoteGuard.new({
		RejectionLogInterval = 5,
		Categories = {
			Global = { Capacity = 100, RefillPerSecond = 0 },
			Lobby = { Capacity = 10, RefillPerSecond = 0 },
			Vision = { Capacity = 10, RefillPerSecond = 0 },
			Economy = { Capacity = 10, RefillPerSecond = 0 },
			Puzzle = { Capacity = 10, RefillPerSecond = 0 },
		},
	}, {
		Clock = function()
			return now
		end,
		OnReject = function(_player, reason, action, count)
			table.insert(logs, { Reason = reason, Action = action, Count = count })
		end,
	})

	local unsafeAction = "Admin|\nGiveShards"
	expectRejected(guard, player, { action = unsafeAction }, "unknown_action")
	expectRejected(guard, player, { action = unsafeAction }, "unknown_action")
	expect(#logs == 1 and logs[1].Count == 1, "repeated rejections should be sampled")
	expect(not string.find(logs[1].Action, "[|%c]"), "logged actions should be sanitized")

	now += 5
	expectRejected(guard, player, { action = unsafeAction }, "unknown_action")
	expect(#logs == 2 and logs[2].Count == 2, "sampled log should aggregate suppressed rejections")
end

function Spec.run(RemoteGuard)
	testContracts(RemoteGuard)
	testGlobalFloodLimit(RemoteGuard)
	testIndependentRateLimits(RemoteGuard)
	testRefill(RemoteGuard)
	testSampledLogging(RemoteGuard)
end

return Spec
