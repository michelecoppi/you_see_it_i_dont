local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SeedUtil = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SeedUtil"))
local CosmeticsService = require(script:WaitForChild("CosmeticsService"))
local LeaderboardService = require(script:WaitForChild("LeaderboardService"))
local LobbyBuilder = require(script:WaitForChild("LobbyBuilder"))
local MapBuilder = require(script:WaitForChild("MapBuilder"))
local PlayerDataService = require(script:WaitForChild("PlayerDataService"))
local QAService = require(script:WaitForChild("QAService"))
local RemoteGuard = require(script:WaitForChild("RemoteGuard"))
local RoomGenerator = require(script:WaitForChild("RoomGenerator"))
local RoundCompletionValidator = require(script:WaitForChild("RoundCompletionValidator"))
local RoundDebugService = require(script:WaitForChild("RoundDebugService"))
local SoloDrone = require(script:WaitForChild("SoloDrone"))
local TelemetryService = require(script:WaitForChild("TelemetryService"))

local remotes = ReplicatedStorage:FindFirstChild("GameRemotes") or Instance.new("Folder")
remotes.Name = "GameRemotes"
remotes.Parent = ReplicatedStorage

local roundStateRemote = remotes:FindFirstChild("RoundState") or Instance.new("RemoteEvent")
roundStateRemote.Name = "RoundState"
roundStateRemote.Parent = remotes

local lobbyEvent = remotes:FindFirstChild("LobbyEvent") or Instance.new("RemoteEvent")
lobbyEvent.Name = "LobbyEvent"
lobbyEvent.Parent = remotes

local map = MapBuilder.Build(Config.Signals)
local lobby = LobbyBuilder.Build()
local soloDrone = SoloDrone.new(map.Root)
local playerData = PlayerDataService.new(Config)
local leaderboardService = LeaderboardService.new(Config, playerData, {
	Success = lobby.SuccessBoardLabel,
	Failure = lobby.FailureBoardLabel,
})
local telemetry = TelemetryService.new(Config)
local qa = QAService.new(Config, SeedUtil)
local roundDebug = RoundDebugService.new(Config)
local remoteGuard = RemoteGuard.new(Config.RemoteGuard, {
	OnReject = function(player, reason, action, count)
		if Config.RemoteGuard.LogRejections ~= false then
			warn(
				string.format(
					"[Security][RemoteGuard] action=%s | count=%d | reason=%s | userId=%d",
					action,
					count,
					reason,
					player and player.UserId or 0
				)
			)
		end
		roundDebug:Log("RemoteRejected", {
			action = action,
			count = count,
			reason = reason,
			userId = player and player.UserId or 0,
		})
	end,
})
local lobbyRandomGenerator = Random.new()
local roundSeedGenerator = Random.new()
local roomGenerator

print(
	string.format(
		"[Build][Server] version=%s | build=%s | environment=%s",
		Config.Version,
		Config.BuildId,
		Config.EnvironmentName
	)
)

local phase = "Lobby"
local timeLeft = 0
local roundNumber = 0
local gateOpen = false
local statusMessage = "Choose Solo Run or Group Run in the lobby."
local roundResolved = false
local roundMistakes = 0
local roundRoomTimings = {}
local totalRoundTime = 0
local roundStartedAt = 0
local pacingStats = {}
local currentMatchMode = "Solo"
local currentPresetOrder = {}
local currentRoundSeed = SeedUtil.Default
local currentRoundSeedId = SeedUtil.Identifier(currentRoundSeed)
local currentDifficulty = Config.Round.Difficulty
local currentStartRoom = 1
local currentRoomIndex = 0
local currentSpawnCFrame = map.Spawn.CFrame
local roundResultRecorded = {}
local matchRunning = false
local groupCountdown = nil

local participants = {}
local participantSet = {}
local soloQueue = {}
local soloQueued = {}
local groupQueue = {}
local groupQueued = {}
local visionEndsAt = {}
local visionReadyAt = {}
local lastPhysicalAction = {}

local function getServerTime()
	return workspace:GetServerTimeNow()
end

local function clearVisionState(player)
	visionEndsAt[player] = nil
	visionReadyAt[player] = nil
end

local function canUsePhysicalAction(player, action, cooldown)
	local actions = lastPhysicalAction[player]
	if not actions then
		actions = {}
		lastPhysicalAction[player] = actions
	end
	local now = os.clock()
	if now - (actions[action] or 0) < cooldown then
		return false
	end
	actions[action] = now
	return true
end

local function getRole(player)
	return player:GetAttribute("Role") or Config.Roles.Hybrid
end

local function isParticipant(player)
	return participantSet[player] == true and player.Parent == Players
end

local function isVisionActive(player, now)
	now = now or getServerTime()
	return phase == "Playing"
		and isParticipant(player)
		and getRole(player) == Config.Roles.Hybrid
		and (visionEndsAt[player] or 0) > now
end

local function getParticipants()
	local active = {}
	for _, player in ipairs(participants) do
		if isParticipant(player) then
			table.insert(active, player)
		end
	end
	return active
end

local function getInstructions(role)
	if role == Config.Roles.Seer then
		return "You alone see hidden clues. Guide the Operator through the expedition."
	elseif role == Config.Roles.Operator then
		return "You control consoles. Ask the Seer which signal and path are safe."
	else
		return "Use ALT VISION to reveal clues, memorize them, then interact with the room."
	end
end

local function sendRoundSnapshot(player)
	local now = getServerTime()
	if not isParticipant(player) then
		roundStateRemote:FireClient(player, {
			phase = "Lobby",
			timeLeft = 0,
			roundNumber = roundNumber,
			role = Config.Roles.Hybrid,
			roleColor = Config.RoleColors[Config.Roles.Hybrid],
			instructions = "Choose an expedition from the lobby.",
			status = "Welcome to the Reality Expedition Hub.",
			gateOpen = false,
			buildVersion = Config.Build.DisplayVersion,
			environment = Config.EnvironmentName,
			qaEnabled = qa.Enabled,
			visionEndsAt = 0,
			visionReadyAt = 0,
			serverNow = now,
		})
		return
	end

	local role = getRole(player)
	local visionActive = isVisionActive(player, now)
	local canReceiveSeerClues = role == Config.Roles.Seer or (role == Config.Roles.Hybrid and visionActive)
	roundStateRemote:FireClient(player, {
		phase = phase,
		timeLeft = timeLeft,
		roundNumber = roundNumber,
		role = role,
		roleColor = Config.RoleColors[role],
		instructions = getInstructions(role),
		status = statusMessage,
		gateOpen = gateOpen,
		buildVersion = Config.Build.DisplayVersion,
		environment = Config.EnvironmentName,
		seedId = currentRoundSeedId,
		qaEnabled = qa.Enabled,
		difficulty = currentDifficulty,
		qaPreset = currentPresetOrder[currentRoomIndex],
		qaRoom = currentRoomIndex,
		qaStartRoom = currentStartRoom,
		qaDifficulty = currentDifficulty,
		roomIndex = currentRoomIndex,
		seerClues = if canReceiveSeerClues and roomGenerator then roomGenerator:GetSeerClues() else nil,
		visionEndsAt = if visionActive then visionEndsAt[player] else 0,
		visionReadyAt = visionReadyAt[player] or 0,
		serverNow = now,
	})
end

local function broadcastRoundSnapshot()
	for _, player in ipairs(getParticipants()) do
		sendRoundSnapshot(player)
	end
end

local function requestAlternateVision(player)
	if phase ~= "Playing" then
		return false, "vision_out_of_phase"
	end
	if not isParticipant(player) then
		return false, "not_participant"
	end
	if getRole(player) ~= Config.Roles.Hybrid then
		return false, "role_not_authorized"
	end

	local now = getServerTime()
	if isVisionActive(player, now) or now < (visionReadyAt[player] or 0) then
		sendRoundSnapshot(player)
		return false, "vision_unavailable"
	end

	local visionConfig = Config.AlternateVision or {}
	local duration = math.max(0.1, visionConfig.Duration or 4)
	local cooldown = math.max(0, visionConfig.Cooldown or 8)
	local expectedEndsAt = now + duration
	visionEndsAt[player] = expectedEndsAt
	visionReadyAt[player] = expectedEndsAt + cooldown
	playerData:IncrementStat(player, "VisionUses", 1)
	telemetry:Log(player, "AlternateVisionUsed", 1, { currentMatchMode, "Solo", "Playing" })
	sendRoundSnapshot(player)

	task.delay(duration, function()
		if visionEndsAt[player] ~= expectedEndsAt then
			return
		end
		visionEndsAt[player] = nil
		if player.Parent == Players then
			sendRoundSnapshot(player)
		end
	end)
	return true
end

local function sendNotice(player, message, isError)
	lobbyEvent:FireClient(player, {
		type = "Notice",
		message = message,
		isError = isError == true,
	})
end

local function getQueueType(player)
	if soloQueued[player] then
		return "Solo"
	elseif groupQueued[player] then
		return "Group"
	end
	return nil
end

local function countValidQueue(queue, queuedSet)
	local count = 0
	for _, player in ipairs(queue) do
		if player.Parent == Players and queuedSet[player] then
			count += 1
		end
	end
	return count
end

local function buildLobbyState(player)
	return {
		PlayerState = player:GetAttribute("PlayerState") or "Lobby",
		QueueType = getQueueType(player),
		GroupQueueCount = countValidQueue(groupQueue, groupQueued),
		GroupCountdown = groupCountdown,
		MatchBusy = matchRunning,
		Profile = playerData:GetClientProfile(player),
	}
end

local function sendLobbyState(player)
	if player.Parent ~= Players then
		return
	end
	lobbyEvent:FireClient(player, {
		type = "State",
		state = buildLobbyState(player),
	})
end

local function broadcastLobbyState()
	local queueCount = countValidQueue(groupQueue, groupQueued)
	if matchRunning then
		lobby.QueueBoardLabel.Text = "GROUP QUEUE\n" .. tostring(queueCount) .. " WAITING  •  EXPEDITION ACTIVE"
	elseif groupCountdown then
		lobby.QueueBoardLabel.Text = "GROUP QUEUE\n"
			.. tostring(queueCount)
			.. " WAITING  •  DEPARTURE IN "
			.. tostring(groupCountdown)
	elseif queueCount < 2 then
		lobby.QueueBoardLabel.Text = "GROUP QUEUE\n"
			.. tostring(queueCount)
			.. " WAITING  •  NEED "
			.. tostring(2 - queueCount)
			.. " MORE"
	else
		lobby.QueueBoardLabel.Text = "GROUP QUEUE\n" .. tostring(queueCount) .. " WAITING  •  PREPARING"
	end

	for _, player in ipairs(Players:GetPlayers()) do
		sendLobbyState(player)
	end
end

local function removePlayerFromArray(array, player)
	for index = #array, 1, -1 do
		if array[index] == player then
			table.remove(array, index)
		end
	end
end

local function removeFromQueues(player)
	soloQueued[player] = nil
	groupQueued[player] = nil
	removePlayerFromArray(soloQueue, player)
	removePlayerFromArray(groupQueue, player)
	if not isParticipant(player) and player.Parent == Players then
		player:SetAttribute("PlayerState", "Lobby")
	end
end

local function teleportToLobby(player)
	local character = player.Character
	if character then
		character:PivotTo(lobby.Spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

local function teleportToStart(player)
	local character = player.Character
	if character then
		character:PivotTo(currentSpawnCFrame + Vector3.new(0, 4, 0))
	end
end

local function teleportParticipantsToStart()
	for _, player in ipairs(getParticipants()) do
		teleportToStart(player)
	end
end

local function setupLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	if not leaderstats:FindFirstChild("Escapes") then
		local escapes = Instance.new("IntValue")
		escapes.Name = "Escapes"
		escapes.Value = 0
		escapes.Parent = leaderstats
	end
end

local function assignRoles()
	local activePlayers = getParticipants()
	table.sort(activePlayers, function(a, b)
		return a.UserId < b.UserId
	end)

	if #activePlayers == 1 then
		activePlayers[1]:SetAttribute("Role", qa:ApplyRole(1, 1, Config.Roles.Hybrid))
	else
		for index, player in ipairs(activePlayers) do
			local defaultRole = if index % 2 == 1 then Config.Roles.Seer else Config.Roles.Operator
			local role = qa:ApplyRole(index, #activePlayers, defaultRole)
			player:SetAttribute("Role", role)
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local soloEnabled = isParticipant(player) and getRole(player) == Config.Roles.Hybrid
		if not soloEnabled then
			clearVisionState(player)
		end
		soloDrone:SetEnabledForPlayer(player, soloEnabled)
		if isParticipant(player) then
			sendRoundSnapshot(player)
		end
	end
end

local function calculateReward()
	local reward = Config.Economy.Rewards.Escape
	if roundMistakes == 0 then
		reward += Config.Economy.Rewards.NoMistakes
	end
	if #getParticipants() >= 2 then
		reward += Config.Economy.Rewards.GroupBonus
	end
	return reward
end

local function formatRoomTimings()
	local parts = {}
	for _, timing in ipairs(roundRoomTimings) do
		table.insert(parts, timing.Name .. " " .. tostring(math.round(timing.Seconds)) .. "s")
	end
	return table.concat(parts, " | ")
end

local function resolveRound(message, awardWin)
	if roundResolved then
		return
	end

	roundResolved = true
	if roomGenerator then
		roomGenerator:SetActive(false)
	end
	for _, player in ipairs(getParticipants()) do
		clearVisionState(player)
	end
	phase = if awardWin then "Success" else "Failed"
	timeLeft = 0
	local usedTime = if roundStartedAt > 0 then math.max(0, math.round(os.clock() - roundStartedAt)) else 0
	local outcome = if awardWin
		then "Success"
		elseif string.find(message, "Time ran out", 1, true) then "Timeout"
		else "Abandoned"
	roundDebug:Log("RoundResolved", {
		duration = usedTime,
		mistakes = roundMistakes,
		outcome = outcome,
		reason = message,
	})

	if awardWin then
		local reward = calculateReward()
		local splitText = formatRoomTimings()
		statusMessage = message .. " Completed in " .. tostring(usedTime) .. "s.  +" .. tostring(reward) .. " Shards"
		if splitText ~= "" then
			statusMessage ..= "\n" .. splitText
		end
		for _, player in ipairs(getParticipants()) do
			if not roundResultRecorded[player] then
				playerData:RecordExpeditionResult(player, true, currentMatchMode, usedTime)
				leaderboardService:UpdatePlayer(player)
				roundResultRecorded[player] = true
			end
			playerData:AddShards(player, reward)
			local profile = playerData:GetClientProfile(player)
			telemetry:Log(
				player,
				"ExpeditionEndedDuration",
				usedTime,
				{ currentMatchMode, outcome, tostring(#currentPresetOrder) .. "Rooms" }
			)
			if profile then
				telemetry:LogEconomy(
					player,
					Enum.AnalyticsEconomyFlowType.Source,
					reward,
					profile.Shards,
					"Gameplay",
					"ExpeditionReward",
					{ currentMatchMode, "Success", getRole(player) }
				)
			end
		end
	else
		statusMessage = message
		for _, player in ipairs(getParticipants()) do
			if not roundResultRecorded[player] then
				playerData:RecordExpeditionResult(player, false, currentMatchMode, usedTime)
				leaderboardService:UpdatePlayer(player)
				roundResultRecorded[player] = true
			end
			telemetry:Log(
				player,
				"ExpeditionEndedDuration",
				usedTime,
				{ currentMatchMode, outcome, tostring(#currentPresetOrder) .. "Rooms" }
			)
		end
	end

	broadcastRoundSnapshot()
end

roomGenerator = RoomGenerator.new(map.Root, map.Spawn, Config, {
	IsParticipant = isParticipant,
	IsVisionActive = isVisionActive,
	AllowPuzzleAction = function(player, action)
		return remoteGuard:Allow(player, "Puzzle", action)
	end,
	OnStatus = function(message)
		if phase ~= "Playing" then
			return
		end
		statusMessage = message
		broadcastRoundSnapshot()
	end,
	OnRoomStarted = function(roomIndex, preset, _displayName)
		currentRoomIndex = roomIndex
		roundDebug:Log("RoomStarted", {
			room = roomIndex,
			preset = preset,
		})
		for _, player in ipairs(getParticipants()) do
			playerData:RecordRoomStarted(player, preset)
			telemetry:Log(player, "RoomStarted", 1, { currentMatchMode, preset, tostring(roomIndex) })
		end
	end,
	OnPuzzleInteraction = function(player, preset, action)
		if phase == "Playing" and isParticipant(player) then
			playerData:RecordPuzzleInteraction(player, preset)
			roundDebug:Log("Interaction", {
				action = action,
				preset = preset,
				role = getRole(player),
			})
		end
	end,
	OnMistake = function(player, penalty, message, preset)
		if phase ~= "Playing" or not isParticipant(player) then
			return
		end
		roundMistakes += 1
		roundDebug:Log("PuzzleError", {
			message = message,
			preset = preset or "Unknown",
			role = getRole(player),
		})
		playerData:RecordMistake(player, preset)
		telemetry:Log(player, "PuzzleMistake", 1, { currentMatchMode, preset or "Unknown", getRole(player) })
		timeLeft = math.max(1, timeLeft - penalty)
		statusMessage = message .. " " .. tostring(penalty) .. " seconds lost."
		broadcastRoundSnapshot()
	end,
	OnRoomCompleted = function(_player, roomIndex, preset, displayName, elapsed, interactions)
		local interactionCount = 0
		for _, count in pairs(interactions) do
			interactionCount += count
		end
		roundDebug:Log("RoomCompleted", {
			interactions = interactionCount,
			preset = preset,
			room = roomIndex,
			seconds = string.format("%.2f", elapsed),
		})
		table.insert(roundRoomTimings, {
			Index = roomIndex,
			Preset = preset,
			Name = displayName,
			Seconds = elapsed,
		})
		local stat = pacingStats[preset]
		if not stat then
			stat = { Count = 0, Total = 0, Fastest = math.huge, Slowest = 0 }
			pacingStats[preset] = stat
		end
		stat.Count += 1
		stat.Total += elapsed
		stat.Fastest = math.min(stat.Fastest, elapsed)
		stat.Slowest = math.max(stat.Slowest, elapsed)
		print(
			string.format(
				"[Pacing] Round %d | Room %d | %s | %.1fs | session avg %.1fs (%d runs, %.1f-%.1f)",
				roundNumber,
				roomIndex,
				preset,
				elapsed,
				stat.Total / stat.Count,
				stat.Count,
				stat.Fastest,
				stat.Slowest
			)
		)
		for _, player in ipairs(getParticipants()) do
			playerData:RecordRoomCompleted(player, preset, elapsed)
			telemetry:Log(player, "RoomCompletedDuration", elapsed, { currentMatchMode, preset, getRole(player) })
			telemetry:Log(
				player,
				"RoomInteractionCount",
				interactions[player] or 0,
				{ currentMatchMode, preset, getRole(player) }
			)
		end
	end,
	OnFinished = function(player)
		local extractionState = roomGenerator:GetExtractionState()
		local character = player.Character
		local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local expectedRoomCount = math.max(1, #currentPresetOrder - currentStartRoom + 1)
		local elapsed = if roundStartedAt > 0 then math.max(0, os.clock() - roundStartedAt) else 0
		local valid, reason = RoundCompletionValidator.Validate({
			Phase = phase,
			IsParticipant = isParticipant(player),
			GeneratorActive = extractionState.Active,
			GoalUnlocked = extractionState.GoalUnlocked,
			CompletedRoomCount = #roundRoomTimings,
			ExpectedRoomCount = expectedRoomCount,
			ElapsedSeconds = elapsed,
			MinimumElapsedSeconds = (Config.Security.MinimumCompletionSecondsPerRoom or 2) * expectedRoomCount,
			PlayerPosition = if rootPart and rootPart:IsA("BasePart") then rootPart.Position else nil,
			GoalPosition = extractionState.GoalPosition,
			MaximumGoalDistance = Config.Security.ExtractionMaximumDistance or 14,
		})
		if not valid then
			roundDebug:Log("ExtractionRejected", {
				completedRooms = #roundRoomTimings,
				elapsed = string.format("%.2f", elapsed),
				expectedRooms = expectedRoomCount,
				reason = reason,
				userId = player.UserId,
			})
			return
		end
		resolveRound(player.DisplayName .. " stabilized the expedition!", true)
	end,
})

local function requestSolo(player)
	if isParticipant(player) then
		sendNotice(player, "You are already in an expedition.", true)
		return
	end
	if not playerData:IsLoaded(player) then
		sendNotice(player, "Your profile is still loading.", true)
		return
	end
	if soloQueued[player] then
		sendNotice(player, "Your Solo expedition is already queued.")
		return
	end

	removeFromQueues(player)
	soloQueued[player] = true
	table.insert(soloQueue, player)
	player:SetAttribute("PlayerState", "QueuedSolo")
	playerData:IncrementStat(player, "QueuesJoined", 1)
	telemetry:Log(player, "QueueJoined", 1, { "Solo", if matchRunning then "Busy" else "Ready", "Portal" })
	sendNotice(
		player,
		if matchRunning then "Solo run queued after the current expedition." else "Solo expedition preparing..."
	)
	broadcastLobbyState()
end

local function requestGroup(player)
	if isParticipant(player) then
		sendNotice(player, "You are already in an expedition.", true)
		return
	end
	if not playerData:IsLoaded(player) then
		sendNotice(player, "Your profile is still loading.", true)
		return
	end
	if groupQueued[player] then
		sendNotice(player, "You are already in the Group queue.")
		return
	end

	removeFromQueues(player)
	groupQueued[player] = true
	table.insert(groupQueue, player)
	player:SetAttribute("PlayerState", "QueuedGroup")
	playerData:IncrementStat(player, "QueuesJoined", 1)
	telemetry:Log(player, "QueueJoined", 1, { "Group", if matchRunning then "Busy" else "Ready", "Portal" })
	local queuePosition = math.min(countValidQueue(groupQueue, groupQueued), #lobby.QueueSpots)
	local queueSpot = lobby.QueueSpots[queuePosition]
	if queueSpot and player.Character then
		player.Character:PivotTo(queueSpot.CFrame + Vector3.new(0, 3.2, 0))
	end
	sendNotice(player, "Group queue joined. Waiting for at least two explorers.")
	broadcastLobbyState()
end

local function openShop(player)
	if not canUsePhysicalAction(player, "Shop", 0.8) then
		return
	end
	if not playerData:IsLoaded(player) then
		sendNotice(player, "Your cosmetics are still loading.", true)
		return
	end
	playerData:IncrementStat(player, "ShopVisits", 1)
	sendLobbyState(player)
	telemetry:Log(
		player,
		"ShopOpened",
		1,
		{ player:GetAttribute("PlayerState") or "Unknown", "LobbyUI", "BuyAndEquip" }
	)
	lobbyEvent:FireClient(player, { type = "OpenShop" })
end

local function openStats(player)
	if not canUsePhysicalAction(player, "Stats", 0.8) then
		return
	end
	if not playerData:IsLoaded(player) then
		sendNotice(player, "Your expedition archive is still loading.", true)
		return
	end
	playerData:IncrementStat(player, "StatsVisits", 1)
	sendLobbyState(player)
	telemetry:Log(
		player,
		"StatsOpened",
		1,
		{ player:GetAttribute("PlayerState") or "Unknown", "LobbyUI", "PersonalStats" }
	)
	lobbyEvent:FireClient(player, { type = "OpenStats" })
end

local function openWardrobe(player)
	if not canUsePhysicalAction(player, "Wardrobe", 0.8) then
		return
	end
	if not playerData:IsLoaded(player) then
		sendNotice(player, "Your cosmetic loadout is still loading.", true)
		return
	end
	playerData:IncrementStat(player, "WardrobeVisits", 1)
	sendLobbyState(player)
	telemetry:Log(
		player,
		"WardrobeOpened",
		1,
		{ player:GetAttribute("PlayerState") or "Unknown", "LoadoutStation", "Lobby" }
	)
	lobbyEvent:FireClient(player, { type = "OpenWardrobe" })
end

local lobbyBriefings = {
	"SOLO: scan first, memorize the clue, then disable ALT VISION before interacting.",
	"SEER: describe positions from the Operator's point of view: left, center, right.",
	"POWER GRID: each node also changes its immediate neighbors.",
	"INVISIBLE FLOOR: communicate one row at a time instead of the entire path.",
	"FREQUENCY VAULT: call out channels from left to right: 1, 2, 3.",
	"Clean expeditions award bonus Shards. Accuracy can be more valuable than speed.",
}

local function claimDailyReward(player)
	local success, message, reward = playerData:ClaimDailyReward(player)
	sendNotice(player, message, not success)
	if success then
		local emitter = lobby.DailyCore:FindFirstChild("RewardBurst")
		if emitter then
			emitter:Emit(35)
		end
		local profile = playerData:GetClientProfile(player)
		telemetry:Log(
			player,
			"DailyRewardClaimed",
			reward,
			{ tostring(profile and profile.Stats.DailyStreak or 1) .. "DayStreak", "Lobby", "DailyReactor" }
		)
		if profile then
			telemetry:LogEconomy(
				player,
				Enum.AnalyticsEconomyFlowType.Source,
				reward,
				profile.Shards,
				"DailyReward",
				"DailyReactor",
				{ "Lobby", "Daily", "Claimed" }
			)
		end
	end
end

local function setLobbyEnergy(player, choice)
	if not canUsePhysicalAction(player, "Mixer", 1.2) then
		return
	end
	for _, instance in ipairs(lobby.Root:GetDescendants()) do
		if
			instance:IsA("BasePart")
			and table.find({ "CeilingLightStrip", "LobbyWallAccent", "ColumnGlow", "HubCoreGlow" }, instance.Name)
		then
			instance.Color = choice.Color
			for _, child in ipairs(instance:GetChildren()) do
				if child:IsA("Light") then
					child.Color = choice.Color
				end
			end
		end
	end
	lobby.MixerLabel.Text = "REALITY MIXER\nACTIVE: " .. string.upper(choice.Id)
	lobby.MixerLabel.TextColor3 = choice.Color
	playerData:IncrementStat(player, "MixerUses", 1)
	playerData:IncrementStat(player, "LobbyInteractions", 1)
	telemetry:Log(player, "LobbyMixerUsed", 1, { choice.Id, "Lobby", "Shared" })
	sendNotice(player, choice.Id .. " energy is now active in the lobby.")
end

local function decodeBriefing(player)
	if not canUsePhysicalAction(player, "Briefing", 1.5) then
		return
	end
	local message = lobbyBriefings[lobbyRandomGenerator:NextInteger(1, #lobbyBriefings)]
	lobby.BriefingLabel.Text = "FIELD BRIEFING\n" .. string.upper(message)
	playerData:IncrementStat(player, "BriefingsRead", 1)
	playerData:IncrementStat(player, "LobbyInteractions", 1)
	telemetry:Log(player, "BriefingDecoded", 1, { "Lobby", "Tip", "PhysicalTerminal" })
	sendNotice(player, message)
end

lobby.SoloPrompt.Triggered:Connect(requestSolo)
lobby.GroupPrompt.Triggered:Connect(requestGroup)
lobby.DailyPrompt.Triggered:Connect(claimDailyReward)
lobby.BriefingPrompt.Triggered:Connect(decodeBriefing)
for _, choice in ipairs(lobby.MixerButtons) do
	choice.Prompt.Triggered:Connect(function(player)
		setLobbyEnergy(player, choice)
	end)
end

local launchDebounce = {}
lobby.LaunchPad.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = if character then Players:GetPlayerFromCharacter(character) else nil
	if not player or launchDebounce[player] or not playerData:IsLoaded(player) then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	launchDebounce[player] = true
	rootPart.AssemblyLinearVelocity =
		Vector3.new(rootPart.AssemblyLinearVelocity.X, 58, rootPart.AssemblyLinearVelocity.Z)
	local emitter = lobby.LaunchPad:FindFirstChild("LaunchBurst")
	if emitter then
		emitter:Emit(30)
	end
	playerData:IncrementStat(player, "LaunchPadUses", 1)
	playerData:IncrementStat(player, "LobbyInteractions", 1)
	telemetry:Log(player, "AnomalyPadUsed", 1, { "Lobby", "Launch", "Physical" })
	task.delay(1.5, function()
		launchDebounce[player] = nil
	end)
end)

local function findPassItem(passId)
	for itemId, item in pairs(Config.Cosmetics) do
		if item.Currency == "Pass" and item.PassId == passId and passId > 0 then
			return itemId
		end
	end
	return nil
end

local function findProductById(productId)
	for productKey, product in pairs(Config.DeveloperProducts) do
		if product.ProductId == productId and productId > 0 then
			return productKey, product
		end
	end
	return nil, nil
end

local ECONOMY_ACTIONS = {
	BuyPremium = true,
	BuyShards = true,
	BuySoft = true,
	Equip = true,
}

lobbyEvent.OnServerEvent:Connect(function(player, payload)
	local allowed, action = remoteGuard:Validate(player, payload)
	if not allowed then
		return
	end
	if ECONOMY_ACTIONS[action] and isParticipant(player) then
		remoteGuard:Reject(player, "economy_out_of_phase", action)
		return
	end

	if action == "RequestState" then
		sendRoundSnapshot(player)
		sendLobbyState(player)
	elseif action == "Solo" then
		requestSolo(player)
	elseif action == "Group" then
		requestGroup(player)
	elseif action == "CancelQueue" then
		local previousQueue = getQueueType(player)
		removeFromQueues(player)
		if previousQueue then
			playerData:IncrementStat(player, "QueuesCancelled", 1)
			telemetry:Log(
				player,
				"QueueCancelled",
				1,
				{ previousQueue, if matchRunning then "Busy" else "Ready", "Player" }
			)
		end
		sendNotice(player, "Queue cancelled.")
		broadcastLobbyState()
	elseif action == "OpenShop" then
		openShop(player)
	elseif action == "OpenStats" then
		openStats(player)
	elseif action == "OpenWardrobe" then
		openWardrobe(player)
	elseif action == "BuySoft" then
		local requestedItem = Config.Cosmetics[payload.itemId]
		if not requestedItem or requestedItem.Currency ~= "Shards" then
			remoteGuard:Reject(player, "invalid_identifier", action)
			sendNotice(player, "This cosmetic is not available for Shards.", true)
			return
		end
		local success, message = playerData:PurchaseWithShards(player, payload.itemId)
		sendNotice(player, message, not success)
		if success then
			local item = Config.Cosmetics[payload.itemId]
			local profile = playerData:GetClientProfile(player)
			telemetry:Log(player, "CosmeticPurchased", 1, { "Shards", item and item.Slot or "Unknown", payload.itemId })
			if item and profile then
				telemetry:LogEconomy(
					player,
					Enum.AnalyticsEconomyFlowType.Sink,
					item.Price,
					profile.Shards,
					Enum.AnalyticsEconomyTransactionType.Shop.Name,
					payload.itemId,
					{ "Cosmetic", item.Slot, "Lobby" }
				)
			end
		end
	elseif action == "Equip" then
		if not Config.Cosmetics[payload.itemId] then
			remoteGuard:Reject(player, "invalid_identifier", action)
			sendNotice(player, "Cosmetic not found.", true)
			return
		end
		local success, message = playerData:Equip(player, payload.itemId)
		sendNotice(player, message, not success)
		if success then
			local item = Config.Cosmetics[payload.itemId]
			telemetry:Log(player, "CosmeticEquipped", 1, { item and item.Slot or "Unknown", payload.itemId, "Lobby" })
		end
	elseif action == "RequestVision" then
		local accepted, reason = requestAlternateVision(player)
		if not accepted then
			remoteGuard:Reject(player, reason, action)
		end
	elseif action == "BuyPremium" then
		local item = Config.Cosmetics[payload.itemId]
		if item and item.Currency == "Pass" and item.PassId > 0 then
			MarketplaceService:PromptGamePassPurchase(player, item.PassId)
		else
			remoteGuard:Reject(player, "invalid_identifier", action)
			sendNotice(player, "This premium cosmetic is not configured yet.", true)
		end
	elseif action == "BuyShards" then
		local product = Config.DeveloperProducts[payload.productKey]
		if product and product.ProductId > 0 then
			MarketplaceService:PromptProductPurchase(player, product.ProductId)
		else
			remoteGuard:Reject(player, "invalid_identifier", action)
			sendNotice(player, "This Shard pack is not configured yet.", true)
		end
	end
end)

playerData.ProfileChanged.Event:Connect(function(player, profile)
	CosmeticsService.Apply(Config, player, profile)
	sendLobbyState(player)
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	local beforeProfile = player and playerData:GetClientProfile(player)
	local decision = playerData:ProcessReceipt(receiptInfo)
	local afterProfile = player and playerData:GetClientProfile(player)
	if
		decision == Enum.ProductPurchaseDecision.PurchaseGranted
		and player
		and beforeProfile
		and afterProfile
		and afterProfile.Shards > beforeProfile.Shards
	then
		local productKey = findProductById(receiptInfo.ProductId)
		local gained = afterProfile.Shards - beforeProfile.Shards
		telemetry:Log(player, "ShardPackPurchased", gained, { "Robux", productKey or "Unknown", "Lobby" })
		telemetry:LogEconomy(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			gained,
			afterProfile.Shards,
			"IAP",
			productKey or "ShardPack",
			{ "Robux", "ShardPack", "Lobby" }
		)
	end
	return decision
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchaseSuccess)
	if not purchaseSuccess then
		return
	end
	local itemId = findPassItem(passId)
	if itemId then
		playerData:GrantPassItem(player, itemId)
		local item = Config.Cosmetics[itemId]
		telemetry:Log(player, "CosmeticPurchased", 1, { "RobuxPass", item and item.Slot or "Unknown", itemId })
		sendNotice(player, Config.Cosmetics[itemId].Name .. " unlocked!")
	end
end)

Players.PlayerAdded:Connect(function(player)
	setupLeaderstats(player)
	player:SetAttribute("PlayerState", "Lobby")
	player:SetAttribute("Role", nil)

	player.CharacterAdded:Connect(function(_character)
		task.wait(0.2)
		local profile = playerData:GetProfile(player)
		if profile then
			CosmeticsService.Apply(Config, player, profile)
		end
		if isParticipant(player) then
			teleportToStart(player)
		else
			teleportToLobby(player)
		end
	end)

	task.spawn(function()
		local profile = playerData:LoadPlayer(player)
		if not profile or player.Parent ~= Players then
			return
		end
		playerData:RefreshOwnedPasses(player)
		leaderboardService:UpdatePlayer(player)
		CosmeticsService.Apply(Config, player, playerData:GetProfile(player))
		teleportToLobby(player)
		sendRoundSnapshot(player)
		sendLobbyState(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if isParticipant(player) and not roundResultRecorded[player] and phase == "Playing" then
		local duration = if roundStartedAt > 0 then math.max(0, math.round(os.clock() - roundStartedAt)) else 0
		playerData:RecordExpeditionResult(player, false, currentMatchMode, duration)
		telemetry:Log(
			player,
			"ExpeditionEndedDuration",
			duration,
			{ currentMatchMode, "PlayerLeft", tostring(#currentPresetOrder) .. "Rooms" }
		)
		roundResultRecorded[player] = true
	end
	leaderboardService:UpdatePlayer(player)
	removeFromQueues(player)
	participantSet[player] = nil
	remoteGuard:RemovePlayer(player)
	clearVisionState(player)
	lastPhysicalAction[player] = nil
	roundResultRecorded[player] = nil
	playerData:RemovePlayer(player)
	task.defer(function()
		if matchRunning then
			assignRoles()
		end
		broadcastLobbyState()
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	setupLeaderstats(player)
	player:SetAttribute("PlayerState", "Lobby")
	task.spawn(function()
		playerData:LoadPlayer(player)
		playerData:RefreshOwnedPasses(player)
		leaderboardService:UpdatePlayer(player)
		CosmeticsService.Apply(Config, player, playerData:GetProfile(player))
		teleportToLobby(player)
		sendRoundSnapshot(player)
		sendLobbyState(player)
	end)
end

local function cleanQueues()
	for index = #soloQueue, 1, -1 do
		local player = soloQueue[index]
		if player.Parent ~= Players or not soloQueued[player] then
			table.remove(soloQueue, index)
		end
	end
	for index = #groupQueue, 1, -1 do
		local player = groupQueue[index]
		if player.Parent ~= Players or not groupQueued[player] then
			table.remove(groupQueue, index)
		end
	end
end

local function takeSoloMatch()
	cleanQueues()
	local player = table.remove(soloQueue, 1)
	if not player then
		return nil
	end
	soloQueued[player] = nil
	return { player }
end

local function takeGroupMatch()
	cleanQueues()
	local selected = {}
	while #selected < 6 and #groupQueue > 0 do
		local player = table.remove(groupQueue, 1)
		if player and player.Parent == Players and groupQueued[player] then
			groupQueued[player] = nil
			table.insert(selected, player)
		end
	end
	return selected
end

local function waitForNextMatch()
	while true do
		cleanQueues()
		local qaPlayers = qa:GetReadyPlayers()
		if qaPlayers then
			local profilesReady = true
			for _, player in ipairs(qaPlayers) do
				profilesReady = profilesReady and playerData:IsLoaded(player)
			end
			if profilesReady then
				return qaPlayers
			end
		end
		local groupCount = countValidQueue(groupQueue, groupQueued)
		if groupCount >= 2 then
			local cancelled = false
			for remaining = 8, 1, -1 do
				cleanQueues()
				if countValidQueue(groupQueue, groupQueued) < 2 then
					cancelled = true
					break
				end
				groupCountdown = remaining
				broadcastLobbyState()
				task.wait(1)
			end
			groupCountdown = nil
			broadcastLobbyState()
			if not cancelled then
				local selected = takeGroupMatch()
				if #selected >= 2 then
					return selected
				end
			end
		elseif countValidQueue(soloQueue, soloQueued) > 0 then
			local selected = takeSoloMatch()
			if selected then
				return selected
			end
		end

		phase = "Lobby"
		task.wait(0.35)
	end
end

local function beginMatch(selectedPlayers)
	participants = {}
	participantSet = {}
	for _, player in ipairs(selectedPlayers) do
		if player.Parent == Players then
			removeFromQueues(player)
			clearVisionState(player)
			participantSet[player] = true
			player:SetAttribute("PlayerState", "Playing")
			table.insert(participants, player)
		end
	end

	if #participants == 0 then
		return false
	end

	currentMatchMode = if #participants == 1 then "Solo" else "Group"
	roundResultRecorded = {}
	matchRunning = true
	assignRoles()
	broadcastLobbyState()
	return true
end

local function returnMatchToLobby()
	roomGenerator:SetActive(false)
	gateOpen = false

	for _, player in ipairs(getParticipants()) do
		clearVisionState(player)
		participantSet[player] = nil
		player:SetAttribute("Role", nil)
		player:SetAttribute("PlayerState", "Lobby")
		soloDrone:SetEnabledForPlayer(player, false)
		teleportToLobby(player)
		sendRoundSnapshot(player)
	end

	participants = {}
	participantSet = {}
	matchRunning = false
	phase = "Lobby"
	statusMessage = "Choose your next expedition."
	currentSpawnCFrame = map.Spawn.CFrame
	broadcastLobbyState()
end

local function runMatch()
	phase = "Intermission"
	statusMessage = "Expedition chamber synchronizing..."
	gateOpen = false
	roundResolved = false
	roundMistakes = 0
	roundRoomTimings = {}
	totalRoundTime = 0
	roundStartedAt = 0
	currentRoomIndex = 0
	local roomCount = Config.Round.RoomCount or 3
	currentRoundSeed = qa.Seed or roundSeedGenerator:NextInteger(1, SeedUtil.Maximum)
	currentRoundSeed = SeedUtil.Normalize(currentRoundSeed)
	currentRoundSeedId = SeedUtil.Identifier(currentRoundSeed)
	local generationOptions = qa:GetGenerationOptions() or {}
	generationOptions.Difficulty = generationOptions.Difficulty or Config.Round.Difficulty
	generationOptions.Seed = currentRoundSeed
	generationOptions.SeedId = currentRoundSeedId
	generationOptions.BuildVersion = Config.Build.DisplayVersion
	generationOptions.Environment = Config.EnvironmentName
	currentStartRoom = generationOptions.StartRoomIndex or 1
	currentDifficulty = generationOptions.Difficulty
	currentRoomIndex = currentStartRoom
	currentPresetOrder = roomGenerator:Generate(Random.new(currentRoundSeed), roomCount, generationOptions)
	local generationValid, generationIssues = roomGenerator:Validate()
	roundDebug:Begin(Config.Build.DisplayVersion, Config.EnvironmentName, currentRoundSeedId, currentPresetOrder)
	if not generationValid then
		local reason = table.concat(generationIssues, "; ")
		roundDebug:Log("GenerationValidationFailed", { reason = reason })
		warn("Generated expedition failed validation: " .. reason)
		resolveRound("Generation validation failed. Seed " .. currentRoundSeedId .. ".", false)
		return
	end
	currentSpawnCFrame = if qa.Enabled then roomGenerator:GetStartCFrame(currentStartRoom) else map.Spawn.CFrame
	teleportParticipantsToStart()

	for remaining = Config.Round.IntermissionDuration, 1, -1 do
		if #getParticipants() == 0 then
			return
		end
		timeLeft = remaining
		broadcastRoundSnapshot()
		task.wait(1)
	end

	roundNumber += 1
	gateOpen = false
	phase = "Playing"
	statusMessage = "The procedural expedition is live. Work together!"
	totalRoundTime = math.max(
		Config.Round.MinimumPlayTime or 60,
		(Config.Round.BasePlayTime or 15) + (Config.Round.TimePerRoom or 22) * roomCount
	)
	timeLeft = totalRoundTime
	roundStartedAt = os.clock()
	teleportParticipantsToStart()
	for _, player in ipairs(getParticipants()) do
		playerData:RecordExpeditionStarted(player, currentMatchMode, currentPresetOrder)
		telemetry:Log(player, "ExpeditionStarted", 1, {
			currentMatchMode,
			tostring(#currentPresetOrder) .. "Rooms-" .. currentDifficulty,
			getRole(player),
		})
		telemetry:Log(
			player,
			"ExpeditionSeed",
			currentRoundSeed,
			{ Config.BuildId, Config.EnvironmentName, currentMatchMode }
		)
	end
	roomGenerator:Start(currentStartRoom)
	broadcastRoundSnapshot()

	while timeLeft > 0 and not roundResolved do
		task.wait(1)
		if #getParticipants() == 0 then
			resolveRound("The expedition was abandoned.", false)
			break
		end
		if not roundResolved then
			timeLeft = math.max(0, timeLeft - 1)
			broadcastRoundSnapshot()
		end
	end

	if not roundResolved then
		resolveRound("Time ran out. The realities drifted apart.", false)
	end

	for remaining = Config.Round.ResultDuration, 1, -1 do
		timeLeft = remaining
		broadcastRoundSnapshot()
		task.wait(1)
	end
end

game:BindToClose(function()
	leaderboardService:Destroy()
	playerData:Shutdown()
end)

while true do
	local selectedPlayers = waitForNextMatch()
	if beginMatch(selectedPlayers) then
		runMatch()
		returnMatchToLobby()
	end
end
