local RemoteGuard = {}
RemoteGuard.__index = RemoteGuard

local DEFAULT_POLICIES = {
	Global = { Capacity = 30, RefillPerSecond = 15 },
	Lobby = { Capacity = 8, RefillPerSecond = 4 },
	Vision = { Capacity = 2, RefillPerSecond = 0.5 },
	Economy = { Capacity = 3, RefillPerSecond = 0.5 },
	Puzzle = { Capacity = 8, RefillPerSecond = 8 },
}

local ACTIONS = {
	RequestState = { Category = "Lobby" },
	Solo = { Category = "Lobby" },
	Group = { Category = "Lobby" },
	CancelQueue = { Category = "Lobby" },
	OpenShop = { Category = "Lobby" },
	OpenStats = { Category = "Lobby" },
	OpenWardrobe = { Category = "Lobby" },
	RequestVision = { Category = "Vision" },
	BuySoft = {
		Category = "Economy",
		Fields = { itemId = { Type = "string", MaxLength = 64 } },
	},
	Equip = {
		Category = "Economy",
		Fields = { itemId = { Type = "string", MaxLength = 64 } },
	},
	BuyPremium = {
		Category = "Economy",
		Fields = { itemId = { Type = "string", MaxLength = 64 } },
	},
	BuyShards = {
		Category = "Economy",
		Fields = { productKey = { Type = "string", MaxLength = 64 } },
	},
}

local function normalizedPolicy(policy, fallback)
	policy = policy or fallback
	return {
		Capacity = math.max(1, tonumber(policy.Capacity) or fallback.Capacity),
		RefillPerSecond = math.max(0, tonumber(policy.RefillPerSecond) or fallback.RefillPerSecond),
	}
end

local function safeAction(payload)
	if typeof(payload) ~= "table" or typeof(payload.action) ~= "string" then
		return "Unknown"
	end
	local action = string.gsub(payload.action, "[%c|]", " ")
	return string.sub(action, 1, 40)
end

function RemoteGuard.new(config, callbacks)
	config = config or {}
	callbacks = callbacks or {}

	local self = setmetatable({}, RemoteGuard)
	self._clock = callbacks.Clock or os.clock
	self._onReject = callbacks.OnReject
	self._logInterval = math.max(0, tonumber(config.RejectionLogInterval) or 5)
	self._policies = {}
	self._buckets = {}
	self._rejections = {}

	for category, fallback in pairs(DEFAULT_POLICIES) do
		local configured = config.Categories and config.Categories[category]
		self._policies[category] = normalizedPolicy(configured, fallback)
	end

	return self
end

function RemoteGuard:_reject(player, reason, action)
	local now = self._clock()
	local playerRejections = self._rejections[player]
	if not playerRejections then
		playerRejections = {}
		self._rejections[player] = playerRejections
	end

	local rejection = playerRejections[reason]
	if not rejection then
		rejection = { Count = 0, LastLoggedAt = nil }
		playerRejections[reason] = rejection
	end
	rejection.Count += 1

	if self._onReject and (rejection.LastLoggedAt == nil or now - rejection.LastLoggedAt >= self._logInterval) then
		self._onReject(player, reason, action or "Unknown", rejection.Count)
		rejection.Count = 0
		rejection.LastLoggedAt = now
	end

	return false, reason
end

function RemoteGuard:_consume(player, category)
	local policy = self._policies[category]
	if not policy then
		return false
	end

	local now = self._clock()
	local playerBuckets = self._buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		self._buckets[player] = playerBuckets
	end

	local bucket = playerBuckets[category]
	if not bucket then
		bucket = { Tokens = policy.Capacity, UpdatedAt = now }
		playerBuckets[category] = bucket
	end

	local elapsed = math.max(0, now - bucket.UpdatedAt)
	bucket.Tokens = math.min(policy.Capacity, bucket.Tokens + elapsed * policy.RefillPerSecond)
	bucket.UpdatedAt = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

function RemoteGuard:Allow(player, category, action)
	if not self:_consume(player, category) then
		return self:_reject(player, string.lower(category) .. "_rate_limited", action)
	end
	return true
end

function RemoteGuard:Reject(player, reason, action)
	return self:_reject(player, reason, safeAction({ action = action }))
end

function RemoteGuard:Validate(player, payload)
	local actionForLog = safeAction(payload)
	if not self:_consume(player, "Global") then
		return self:_reject(player, "global_rate_limited", actionForLog)
	end
	if typeof(payload) ~= "table" then
		return self:_reject(player, "invalid_payload", actionForLog)
	end
	if typeof(payload.action) ~= "string" or #payload.action == 0 or #payload.action > 40 then
		return self:_reject(player, "invalid_action", actionForLog)
	end

	local action = payload.action
	local contract = ACTIONS[action]
	if not contract then
		return self:_reject(player, "unknown_action", actionForLog)
	end

	local fields = contract.Fields or {}
	for key in pairs(payload) do
		if typeof(key) ~= "string" or (key ~= "action" and fields[key] == nil) then
			return self:_reject(player, "unknown_field", action)
		end
	end
	for fieldName, fieldContract in pairs(fields) do
		local value = payload[fieldName]
		if typeof(value) ~= fieldContract.Type then
			return self:_reject(player, "invalid_field", action)
		end
		if fieldContract.Type == "string" and (#value == 0 or #value > fieldContract.MaxLength) then
			return self:_reject(player, "invalid_field", action)
		end
	end

	if not self:_consume(player, contract.Category) then
		return self:_reject(player, string.lower(contract.Category) .. "_rate_limited", action)
	end
	return true, action
end

function RemoteGuard:RemovePlayer(player)
	self._buckets[player] = nil
	self._rejections[player] = nil
end

return RemoteGuard
