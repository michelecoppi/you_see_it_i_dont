local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReceiptLedger = require(script.Parent:WaitForChild("ReceiptLedger"))

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

local PROFILE_VERSION = 2
local AUTOSAVE_INTERVAL = 60

local function deepCopy(value)
	if typeof(value) ~= "table" then
		return value
	end

	local result = {}
	for key, child in pairs(value) do
		result[deepCopy(key)] = deepCopy(child)
	end
	return result
end

local function createDefaultStats(config)
	local puzzles = {}
	for _, preset in ipairs(config.PuzzleOrder or {}) do
		puzzles[preset] = {
			Selected = 0,
			Attempts = 0,
			Completed = 0,
			Interactions = 0,
			Mistakes = 0,
			TotalSeconds = 0,
			BestSeconds = 0,
		}
	end

	return {
		FirstPlayedUnix = os.time(),
		LastPlayedUnix = os.time(),
		Sessions = 0,
		TotalPlaySeconds = 0,
		ExpeditionsStarted = 0,
		ExpeditionsCompleted = 0,
		ExpeditionsFailed = 0,
		SoloExpeditions = 0,
		GroupExpeditions = 0,
		SoloWins = 0,
		GroupWins = 0,
		RoomsCompleted = 0,
		TotalMistakes = 0,
		VisionUses = 0,
		QueuesJoined = 0,
		QueuesCancelled = 0,
		ShopVisits = 0,
		StatsVisits = 0,
		WardrobeVisits = 0,
		DailyClaims = 0,
		DailyStreak = 0,
		LastDailyClaimDay = 0,
		LobbyInteractions = 0,
		MixerUses = 0,
		BriefingsRead = 0,
		LaunchPadUses = 0,
		CosmeticsPurchased = 0,
		CosmeticsEquipped = 0,
		RobuxPurchases = 0,
		PurchasedShards = 0,
		ShardsEarned = 0,
		ShardsSpent = 0,
		TotalRoundSeconds = 0,
		BestRoundSeconds = 0,
		CurrentWinStreak = 0,
		BestWinStreak = 0,
		Puzzles = puzzles,
	}
end

local function createDefaultProfile(config)
	local startingShards = if RunService:IsStudio() and config.Economy.StudioStartingShards
		then config.Economy.StudioStartingShards
		else config.Economy.StartingShards
	return {
		Version = PROFILE_VERSION,
		Shards = startingShards,
		Inventory = {
			drone_default = true,
		},
		Equipped = {
			Drone = "drone_default",
		},
		ProcessedReceipts = {},
		ReceiptOrder = {},
		Stats = createDefaultStats(config),
	}
end

local function reconcileProfile(config, savedProfile)
	local profile = createDefaultProfile(config)
	if typeof(savedProfile) ~= "table" then
		return profile
	end

	if typeof(savedProfile.Shards) == "number" then
		profile.Shards = math.max(0, math.floor(savedProfile.Shards))
	end

	if typeof(savedProfile.Inventory) == "table" then
		for itemId, isOwned in pairs(savedProfile.Inventory) do
			if isOwned == true and config.Cosmetics[itemId] then
				profile.Inventory[itemId] = true
			end
		end
	end

	if typeof(savedProfile.Equipped) == "table" then
		for slot, itemId in pairs(savedProfile.Equipped) do
			local item = config.Cosmetics[itemId]
			if typeof(slot) == "string" and item and item.Slot == slot and profile.Inventory[itemId] then
				profile.Equipped[slot] = itemId
			end
		end
	end

	if typeof(savedProfile.ProcessedReceipts) == "table" then
		for receiptId, processed in pairs(savedProfile.ProcessedReceipts) do
			if typeof(receiptId) == "string" and processed == true then
				profile.ProcessedReceipts[receiptId] = true
			end
		end
	end

	if typeof(savedProfile.ReceiptOrder) == "table" then
		local orderedReceipts = {}
		for _, receiptId in ipairs(savedProfile.ReceiptOrder) do
			if
				typeof(receiptId) == "string"
				and profile.ProcessedReceipts[receiptId]
				and not orderedReceipts[receiptId]
			then
				table.insert(profile.ReceiptOrder, receiptId)
				orderedReceipts[receiptId] = true
			end
		end
	end

	if typeof(savedProfile.Stats) == "table" then
		for statName, defaultValue in pairs(profile.Stats) do
			if
				statName ~= "Puzzles"
				and typeof(defaultValue) == "number"
				and typeof(savedProfile.Stats[statName]) == "number"
			then
				profile.Stats[statName] = math.max(0, savedProfile.Stats[statName])
			end
		end

		if typeof(savedProfile.Stats.Puzzles) == "table" then
			for preset, puzzleStats in pairs(profile.Stats.Puzzles) do
				local savedPuzzleStats = savedProfile.Stats.Puzzles[preset]
				if typeof(savedPuzzleStats) == "table" then
					for statName, defaultValue in pairs(puzzleStats) do
						if typeof(defaultValue) == "number" and typeof(savedPuzzleStats[statName]) == "number" then
							puzzleStats[statName] = math.max(0, savedPuzzleStats[statName])
						end
					end
				end
			end
		end
	end

	profile.Version = PROFILE_VERSION
	return profile
end

local function findDeveloperProduct(config, productId)
	for productKey, product in pairs(config.DeveloperProducts) do
		if product.ProductId > 0 and product.ProductId == productId then
			return productKey, product
		end
	end
	return nil, nil
end

function PlayerDataService.new(config)
	local self = setmetatable({}, PlayerDataService)
	self._config = config
	self._profiles = {}
	self._loaded = {}
	self._sessionStartedAt = {}
	self._running = true
	self.ProfileChanged = Instance.new("BindableEvent")
	self._persistenceEnabled = not RunService:IsStudio() or config.Economy.EnableStudioPersistence == true
	self._store = if self._persistenceEnabled then DataStoreService:GetDataStore(config.Economy.DataStoreName) else nil

	task.spawn(function()
		while self._running do
			task.wait(AUTOSAVE_INTERVAL)
			if not self._running then
				break
			end
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(function()
					self:SavePlayer(player)
				end)
			end
		end
	end)

	return self
end

function PlayerDataService:_syncLeaderstats(player)
	local profile = self._profiles[player]
	if not profile then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local shards = leaderstats:FindFirstChild("Shards")
	if not shards then
		shards = Instance.new("IntValue")
		shards.Name = "Shards"
		shards.Parent = leaderstats
	end
	shards.Value = profile.Shards

	local escapes = leaderstats:FindFirstChild("Escapes")
	if not escapes then
		escapes = Instance.new("IntValue")
		escapes.Name = "Escapes"
		escapes.Parent = leaderstats
	end
	escapes.Value = profile.Stats.ExpeditionsCompleted
end

function PlayerDataService:_emit(player)
	self:_syncLeaderstats(player)
	self.ProfileChanged:Fire(player, self:GetProfile(player))
end

function PlayerDataService:_emitStats(player)
	self:_syncLeaderstats(player)
end

-- options.CountSession = false skips the Sessions stat (used for lobby <-> expedition server hops).
function PlayerDataService:LoadPlayer(player, options)
	if self._loaded[player] then
		return self._profiles[player]
	end

	local profile = createDefaultProfile(self._config)
	local persistent = false

	if self._persistenceEnabled then
		local success, savedProfile = pcall(function()
			return self._store:GetAsync("Player_" .. tostring(player.UserId))
		end)
		if success then
			profile = reconcileProfile(self._config, savedProfile)
			persistent = true
		else
			warn("Profile load failed for " .. player.Name .. ": " .. tostring(savedProfile))
		end
	end

	if not player.Parent then
		return nil
	end

	self._profiles[player] = profile
	self._loaded[player] = true
	self._sessionStartedAt[player] = os.clock()
	if not options or options.CountSession ~= false then
		profile.Stats.Sessions += 1
	end
	profile.Stats.LastPlayedUnix = os.time()
	player:SetAttribute("ProfileLoaded", true)
	player:SetAttribute("DataPersistent", persistent)
	self:_emit(player)
	return profile
end

function PlayerDataService:IsLoaded(player)
	return self._loaded[player] == true
end

function PlayerDataService:GetProfile(player)
	local profile = self._profiles[player]
	return if profile then deepCopy(profile) else nil
end

function PlayerDataService:GetClientProfile(player)
	local profile = self._profiles[player]
	if not profile then
		return nil
	end

	local clientStats = deepCopy(profile.Stats)
	local sessionStartedAt = self._sessionStartedAt[player]
	if sessionStartedAt then
		clientStats.TotalPlaySeconds += math.max(0, math.floor(os.clock() - sessionStartedAt))
	end

	return {
		Shards = profile.Shards,
		Inventory = deepCopy(profile.Inventory),
		Equipped = deepCopy(profile.Equipped),
		Stats = clientStats,
		Persistent = player:GetAttribute("DataPersistent") == true,
	}
end

function PlayerDataService:_checkpointSession(player, finalize)
	local startedAt = self._sessionStartedAt[player]
	local profile = self._profiles[player]
	if startedAt and profile then
		profile.Stats.TotalPlaySeconds += math.max(0, math.floor(os.clock() - startedAt))
		profile.Stats.LastPlayedUnix = os.time()
		self._sessionStartedAt[player] = if finalize then nil else os.clock()
	end
end

function PlayerDataService:SavePlayer(player)
	local profile = self._profiles[player]
	if not profile then
		return true
	end
	self:_checkpointSession(player, false)
	if not self._persistenceEnabled then
		return true
	end

	local snapshot = deepCopy(profile)
	local success, errorMessage = pcall(function()
		self._store:UpdateAsync("Player_" .. tostring(player.UserId), function()
			return snapshot
		end)
	end)

	if not success then
		warn("Profile save failed for " .. player.Name .. ": " .. tostring(errorMessage))
	end
	return success
end

function PlayerDataService:AddShards(player, amount)
	local profile = self._profiles[player]
	if not profile or typeof(amount) ~= "number" then
		return false
	end

	profile.Shards = math.max(0, profile.Shards + math.floor(amount))
	if amount > 0 then
		profile.Stats.ShardsEarned += math.floor(amount)
	end
	self:_emit(player)
	task.spawn(function()
		self:SavePlayer(player)
	end)
	return true
end

function PlayerDataService:PurchaseWithShards(player, itemId)
	local profile = self._profiles[player]
	local item = self._config.Cosmetics[itemId]
	if not profile then
		return false, "Profile is still loading."
	end
	if not item or item.Currency ~= "Shards" then
		return false, "This item cannot be purchased with Shards."
	end
	if profile.Inventory[itemId] then
		return false, "You already own this cosmetic."
	end
	if profile.Shards < item.Price then
		return false, "Not enough Reality Shards."
	end

	profile.Shards -= item.Price
	profile.Inventory[itemId] = true
	profile.Stats.ShardsSpent += item.Price
	profile.Stats.CosmeticsPurchased += 1
	self:_emit(player)
	task.spawn(function()
		self:SavePlayer(player)
	end)
	return true, item.Name .. " unlocked!"
end

function PlayerDataService:Equip(player, itemId)
	local profile = self._profiles[player]
	local item = self._config.Cosmetics[itemId]
	if not profile or not item then
		return false, "Cosmetic not found."
	end
	if not profile.Inventory[itemId] then
		return false, "You do not own this cosmetic."
	end

	profile.Equipped[item.Slot] = itemId
	profile.Stats.CosmeticsEquipped += 1
	self:_emit(player)
	task.spawn(function()
		self:SavePlayer(player)
	end)
	return true, item.Name .. " equipped."
end

function PlayerDataService:GrantPassItem(player, itemId)
	local profile = self._profiles[player]
	local item = self._config.Cosmetics[itemId]
	if not profile or not item or item.Currency ~= "Pass" then
		return false
	end
	if profile.Inventory[itemId] then
		return true
	end

	profile.Inventory[itemId] = true
	profile.Stats.CosmeticsPurchased += 1
	profile.Stats.RobuxPurchases += 1
	self:_emit(player)
	task.spawn(function()
		self:SavePlayer(player)
	end)
	return true
end

function PlayerDataService:RefreshOwnedPasses(player)
	if not self._profiles[player] then
		return
	end

	for itemId, item in pairs(self._config.Cosmetics) do
		if item.Currency == "Pass" and item.PassId > 0 then
			local success, ownsPass = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.PassId)
			end)
			if success and ownsPass then
				self._profiles[player].Inventory[itemId] = true
			end
		end
	end
	self:_emit(player)
end

function PlayerDataService:ProcessReceipt(receiptInfo)
	local _, product = findDeveloperProduct(self._config, receiptInfo.ProductId)
	if not product then
		warn("Unconfigured developer product receipt: " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player or not self._loaded[player] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptId = tostring(receiptInfo.PurchaseId)
	local currentProfile = self._profiles[player]
	if ReceiptLedger.Has(currentProfile, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if not self._persistenceEnabled then
		ReceiptLedger.Grant(currentProfile, receiptId, product.Shards)
		self:_emit(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local currentSnapshot = deepCopy(currentProfile)

	local success, savedProfile = pcall(function()
		return self._store:UpdateAsync("Player_" .. tostring(player.UserId), function(previous)
			local stored = reconcileProfile(self._config, previous)
			if ReceiptLedger.Has(stored, receiptId) then
				return stored
			end
			local candidate = deepCopy(currentSnapshot)
			ReceiptLedger.MergeHistory(candidate, stored)
			ReceiptLedger.Grant(candidate, receiptId, product.Shards)
			return candidate
		end)
	end)

	if not success then
		warn("Receipt save failed: " .. tostring(savedProfile))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	self._profiles[player] = reconcileProfile(self._config, savedProfile)
	self:_emit(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function PlayerDataService:IncrementStat(player, statName, amount)
	local profile = self._profiles[player]
	amount = amount or 1
	if not profile or typeof(profile.Stats[statName]) ~= "number" or typeof(amount) ~= "number" then
		return false
	end
	profile.Stats[statName] = math.max(0, profile.Stats[statName] + amount)
	self:_emitStats(player)
	return true
end

function PlayerDataService:ClaimDailyReward(player)
	local profile = self._profiles[player]
	if not profile then
		return false, "Your profile is still loading."
	end

	local today = math.floor(os.time() / 86400)
	local stats = profile.Stats
	if stats.LastDailyClaimDay == today then
		return false, "Daily Reactor already claimed. Return tomorrow!"
	end

	if stats.LastDailyClaimDay == today - 1 then
		stats.DailyStreak += 1
	else
		stats.DailyStreak = 1
	end
	stats.LastDailyClaimDay = today
	stats.DailyClaims += 1
	stats.LobbyInteractions += 1
	local reward = self._config.Lobby.DailyReward
	profile.Shards += reward
	stats.ShardsEarned += reward
	self:_emit(player)
	task.spawn(function()
		self:SavePlayer(player)
	end)
	return true, "+" .. tostring(reward) .. " Reality Shards! Daily streak: " .. tostring(stats.DailyStreak), reward
end

function PlayerDataService:RecordExpeditionStarted(player, mode, presets)
	local profile = self._profiles[player]
	if not profile then
		return
	end
	local stats = profile.Stats
	stats.ExpeditionsStarted += 1
	if mode == "Solo" then
		stats.SoloExpeditions += 1
	else
		stats.GroupExpeditions += 1
	end
	for _, preset in ipairs(presets or {}) do
		local puzzleStats = stats.Puzzles[preset]
		if puzzleStats then
			puzzleStats.Selected += 1
		end
	end
	self:_emitStats(player)
end

function PlayerDataService:RecordRoomStarted(player, preset)
	local profile = self._profiles[player]
	local puzzleStats = profile and profile.Stats.Puzzles[preset]
	if not puzzleStats then
		return
	end
	puzzleStats.Attempts += 1
	self:_emitStats(player)
end

function PlayerDataService:RecordPuzzleInteraction(player, preset)
	local profile = self._profiles[player]
	local puzzleStats = profile and profile.Stats.Puzzles[preset]
	if not puzzleStats then
		return
	end
	puzzleStats.Interactions += 1
	self:_emitStats(player)
end

function PlayerDataService:RecordRoomCompleted(player, preset, elapsed)
	local profile = self._profiles[player]
	if not profile then
		return
	end
	local stats = profile.Stats
	stats.RoomsCompleted += 1
	local puzzleStats = stats.Puzzles[preset]
	if puzzleStats then
		puzzleStats.Completed += 1
		puzzleStats.TotalSeconds += math.max(0, elapsed)
		if puzzleStats.BestSeconds == 0 or elapsed < puzzleStats.BestSeconds then
			puzzleStats.BestSeconds = elapsed
		end
	end
	self:_emitStats(player)
end

function PlayerDataService:RecordMistake(player, preset)
	local profile = self._profiles[player]
	if not profile then
		return
	end
	profile.Stats.TotalMistakes += 1
	local puzzleStats = preset and profile.Stats.Puzzles[preset]
	if puzzleStats then
		puzzleStats.Mistakes += 1
	end
	self:_emitStats(player)
end

function PlayerDataService:RecordExpeditionResult(player, won, mode, duration)
	local profile = self._profiles[player]
	if not profile then
		return
	end
	local stats = profile.Stats
	duration = math.max(0, duration or 0)
	stats.TotalRoundSeconds += duration
	if won then
		stats.ExpeditionsCompleted += 1
		stats.CurrentWinStreak += 1
		stats.BestWinStreak = math.max(stats.BestWinStreak, stats.CurrentWinStreak)
		if stats.BestRoundSeconds == 0 or duration < stats.BestRoundSeconds then
			stats.BestRoundSeconds = duration
		end
		if mode == "Solo" then
			stats.SoloWins += 1
		else
			stats.GroupWins += 1
		end
	else
		stats.ExpeditionsFailed += 1
		stats.CurrentWinStreak = 0
	end
	self:_emitStats(player)
	if not won then
		task.spawn(function()
			self:SavePlayer(player)
		end)
	end
end

function PlayerDataService:_finalizeSession(player)
	self:_checkpointSession(player, true)
end

function PlayerDataService:RemovePlayer(player)
	self:_finalizeSession(player)
	self:SavePlayer(player)
	self._profiles[player] = nil
	self._loaded[player] = nil
end

function PlayerDataService:Shutdown()
	self._running = false
	for _, player in ipairs(Players:GetPlayers()) do
		self:_finalizeSession(player)
		self:SavePlayer(player)
	end
	self.ProfileChanged:Destroy()
end

return PlayerDataService
