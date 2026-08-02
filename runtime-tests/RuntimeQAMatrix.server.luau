local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local RoomGenerator = require(ServerScriptService.Modules.RoomGenerator)
local RoundDebugService = require(ServerScriptService.Modules.RoundDebugService)
local TelemetryService = require(ServerScriptService.Modules.TelemetryService)

local SEED = 424242
local SEED_ID = "SEED-0000424242"
local CLIENT_SETTLE_SECONDS = 15
local CLIENT_CONNECT_TIMEOUT_SECONDS = 45
local ACK_TIMEOUT_SECONDS = 8

local remote = Instance.new("RemoteEvent")
remote.Name = "RuntimeQAMatrixEvent"
remote.Parent = ReplicatedStorage

local readyPlayers = {}
local caseAcks = {}
local errorProbeAcks = {}

remote.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.kind == "Ready" then
		readyPlayers[player] = true
	elseif payload.kind == "CaseAck" and typeof(payload.caseId) == "number" then
		caseAcks[payload.caseId] = caseAcks[payload.caseId] or {}
		caseAcks[payload.caseId][player] = payload
	elseif payload.kind == "ErrorProbeAck" then
		errorProbeAcks[player] = payload.formatted
	end
end)

local function sortedPlayers()
	local result = Players:GetPlayers()
	table.sort(result, function(a, b)
		return a.UserId < b.UserId
	end)
	return result
end

local function waitUntil(predicate, timeoutSeconds)
	local deadline = os.clock() + timeoutSeconds
	repeat
		if predicate() then
			return true
		end
		task.wait(0.1)
	until os.clock() >= deadline
	return predicate()
end

local function waitForStableClientCount()
	local deadline = os.clock() + CLIENT_CONNECT_TIMEOUT_SECONDS
	local lastCount = #Players:GetPlayers()
	local stableSince = os.clock()

	repeat
		task.wait(0.25)
		local count = #Players:GetPlayers()
		if count ~= lastCount then
			lastCount = count
			stableSince = os.clock()
		end
	until (lastCount > 0 and os.clock() - stableSince >= CLIENT_SETTLE_SECONDS) or os.clock() >= deadline

	return lastCount
end

local function createFixture()
	local root = Instance.new("Folder")
	root.Name = "RuntimeQAMap"
	root.Parent = workspace

	local deck = Instance.new("Part")
	deck.Name = "ChamberDeck_1"
	deck.Anchored = true
	deck.Size = Vector3.new(68, 1, 40)
	deck.CFrame = CFrame.new(0, 0, -45)
	deck:SetAttribute("GeometryRole", "Support")
	deck.Parent = root

	local spawnPart = Instance.new("Part")
	spawnPart.Name = "RuntimeQASpawn"
	spawnPart.Anchored = true
	spawnPart.Transparency = 1
	spawnPart.CanCollide = false
	spawnPart.CFrame = CFrame.new(0, 4, -61)
	spawnPart:SetAttribute("GeometryRole", "Spawn")
	spawnPart.Parent = root
	return root, spawnPart
end

local function assignRoles(players, runIndex)
	local roles = {}
	for index, player in ipairs(players) do
		local role
		if #players == 1 then
			role = Config.Roles.Hybrid
		elseif (index + runIndex) % 2 == 0 then
			role = Config.Roles.Seer
		else
			role = Config.Roles.Operator
		end
		player:SetAttribute("Role", role)
		roles[index] = role
	end
	return table.concat(roles, ",")
end

local function countRoleMarkers(root)
	local seer = 0
	local operator = 0
	local invalid = 0
	for _, instance in ipairs(root:GetDescendants()) do
		local role = instance:GetAttribute("VisibleToRole")
		if role == Config.Roles.Seer then
			seer += 1
		elseif role == Config.Roles.Operator then
			operator += 1
		elseif role ~= nil then
			invalid += 1
		end
	end
	return seer, operator, invalid
end

local function appendIssues(target, prefix, issues)
	for _, issue in ipairs(issues) do
		table.insert(target, prefix .. issue)
	end
end

local function run()
	workspace:SetAttribute("RuntimeQAMatrixResult", "RUNNING")
	workspace:SetAttribute("RuntimeQACaseId", 0)
	waitForStableClientCount()

	local players = sortedPlayers()
	if #players == 0 then
		error("[QA][Matrix] no Studio clients connected")
	end
	if
		not waitUntil(function()
			for _, player in ipairs(players) do
				if not readyPlayers[player] then
					return false
				end
			end
			return true
		end, ACK_TIMEOUT_SECONDS)
	then
		error("[QA][Matrix] clients did not become ready")
	end

	local root, spawnPart = createFixture()
	local generator = RoomGenerator.new(root, spawnPart, Config)
	local roundDebug = RoundDebugService.new(Config)
	local telemetry = TelemetryService.new(Config)
	local failures = {}
	local passed = 0
	local caseId = 0

	for _, preset in ipairs(Config.PuzzleOrder) do
		for runIndex = 1, 2 do
			caseId += 1
			local roles = assignRoles(players, runIndex)
			local order = generator:Generate(Random.new(SEED), 1, {
				ForcedPreset = preset,
				StartRoomIndex = 1,
				Seed = SEED,
				SeedId = SEED_ID,
				BuildVersion = Config.Build.DisplayVersion,
				Environment = Config.EnvironmentName,
			})
			local valid, validationIssues = generator:Validate()
			local seerMarkers, operatorMarkers, invalidMarkers = countRoleMarkers(root)
			local seerClues = generator:GetSeerClues()
			local issues = {}
			if order[1] ~= preset then
				table.insert(issues, "forced preset mismatch")
			end
			if not valid then
				appendIssues(issues, "validation: ", validationIssues)
			end
			if seerMarkers > 0 then
				table.insert(issues, "Seer clue leaked into replicated DataModel")
			end
			if #seerClues == 0 then
				table.insert(issues, "missing private Seer clue payload")
			end
			if preset ~= "PhaseFloor" and operatorMarkers == 0 then
				table.insert(issues, "missing Operator interaction")
			end
			if invalidMarkers > 0 then
				table.insert(issues, "unknown role markers")
			end

			roundDebug:Begin(Config.Build.DisplayVersion, Config.EnvironmentName, SEED_ID, { preset })
			roundDebug:Log("RuntimeMatrixCase", {
				case = caseId,
				clients = #players,
				preset = preset,
				roles = roles,
				run = runIndex,
			})
			workspace:SetAttribute("RuntimeQAPreset", preset)
			workspace:SetAttribute("RuntimeQARun", runIndex)
			workspace:SetAttribute("RuntimeQASeedId", SEED_ID)
			workspace:SetAttribute("RuntimeQACaseId", caseId)

			local receivedAllAcks = waitUntil(function()
				local acknowledgements = caseAcks[caseId] or {}
				for _, player in ipairs(players) do
					local ack = acknowledgements[player]
					if
						not ack
						or ack.preset ~= preset
						or ack.role ~= player:GetAttribute("Role")
						or not string.find(ack.roomName or "", preset, 1, true)
						or ack.seedId ~= SEED_ID
					then
						return false
					end
				end
				return true
			end, ACK_TIMEOUT_SECONDS)
			if not receivedAllAcks then
				table.insert(issues, "missing or invalid client acknowledgement")
			end

			for _, player in ipairs(players) do
				telemetry:Log(
					player,
					"QAMatrixCase",
					1,
					{ tostring(#players) .. "Clients", preset, player:GetAttribute("Role") }
				)
			end
			if #issues == 0 then
				passed += 1
				print(
					string.format(
						"[QA][Matrix] case=%d | clients=%d | preset=%s | run=%d | roles=%s | result=PASS",
						caseId,
						#players,
						preset,
						runIndex,
						roles
					)
				)
			else
				appendIssues(failures, string.format("case %d %s: ", caseId, preset), issues)
				warn(
					string.format(
						"[QA][Matrix] case=%d | clients=%d | preset=%s | run=%d | result=FAIL | issues=%s",
						caseId,
						#players,
						preset,
						runIndex,
						table.concat(issues, "; ")
					)
				)
			end
		end
	end

	remote:FireAllClients({ kind = "ErrorProbe" })
	local probesValid = waitUntil(function()
		for _, player in ipairs(players) do
			local formatted = errorProbeAcks[player]
			if
				type(formatted) ~= "string"
				or not string.find(formatted, "[QA][Client] error", 1, true)
				or string.find(formatted, "Coppi", 1, true)
				or string.find(formatted, "tester@example.com", 1, true)
				or string.find(formatted, "qa-secret", 1, true)
			then
				return false
			end
		end
		return true
	end, ACK_TIMEOUT_SECONDS)
	if not probesValid then
		table.insert(failures, "client error sanitization probe failed")
	end

	local result = if #failures == 0 and passed == caseId then "PASS" else "FAIL"
	local summary =
		string.format("clients=%d cases=%d/%d errorProbe=%s", #players, passed, caseId, tostring(probesValid))
	workspace:SetAttribute("RuntimeQAMatrixClientCount", #players)
	workspace:SetAttribute("RuntimeQAMatrixSummary", summary)
	workspace:SetAttribute("RuntimeQAMatrixResult", result)
	print(string.format("[QA][Matrix] complete | result=%s | %s", result, summary))
	if #failures > 0 then
		error("[QA][Matrix] failures: " .. table.concat(failures, " | "))
	end
	generator:Destroy()
	root:Destroy()
end

local success, message = pcall(run)
if not success then
	workspace:SetAttribute("RuntimeQAMatrixResult", "FAIL")
	warn(tostring(message))
	error("Runtime QA matrix failed")
end
