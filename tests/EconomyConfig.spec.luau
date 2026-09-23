local Spec = {}

local VALID_SLOTS = { Drone = true, Trail = true, Vision = true, Title = true }

function Spec.run(config)
	local seen = {}
	local shardItems = 0
	local cheapestPrice = math.huge
	local mostExpensivePrice = 0

	for _, itemId in ipairs(config.CosmeticOrder) do
		assert(not seen[itemId], "Duplicate cosmetic order entry: " .. itemId)
		seen[itemId] = true
		local item = config.Cosmetics[itemId]
		assert(item, "Missing cosmetic definition: " .. itemId)
		assert(VALID_SLOTS[item.Slot], "Invalid cosmetic slot: " .. itemId)
		assert(typeof(item.Name) == "string" and #item.Name > 0, "Missing cosmetic name: " .. itemId)
		assert(typeof(item.PrimaryColor) == "Color3", "Missing primary color: " .. itemId)
		if item.Currency == "Shards" then
			assert(
				typeof(item.Price) == "number" and item.Price > 0 and item.Price % 1 == 0,
				"Invalid price: " .. itemId
			)
			shardItems += 1
			cheapestPrice = math.min(cheapestPrice, item.Price)
			mostExpensivePrice = math.max(mostExpensivePrice, item.Price)
		elseif item.Currency == "Pass" then
			assert(typeof(item.PassId) == "number" and item.PassId >= 0, "Invalid pass ID: " .. itemId)
		else
			assert(item.Currency == "Starter", "Invalid currency: " .. itemId)
		end
	end

	for itemId in pairs(config.Cosmetics) do
		assert(seen[itemId], "Cosmetic omitted from order: " .. itemId)
	end

	assert(config.Cosmetics.drone_default.Currency == "Starter", "Starter drone is required")
	assert(config.Economy.StartingShards < cheapestPrice, "First purchase should require play or a daily claim")
	assert(config.Economy.Rewards.Escape > 0, "An escape must grant shards")
	assert(config.Economy.Rewards.GroupBonus >= 0, "Group bonus cannot be negative")
	assert(config.Lobby.DailyReward >= 0, "Daily reward cannot be negative")
	assert(shardItems >= 10, "Expected an expanded Shards catalog")
	assert(mostExpensivePrice >= 1000, "Expected a longer term cosmetic goal")
end

return Spec
