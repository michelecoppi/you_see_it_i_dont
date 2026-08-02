local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QALog = require(ReplicatedStorage.Shared.QALog)
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("RuntimeQAMatrixEvent")
local lastCaseId = 0

local function acknowledgeCase()
	local caseId = workspace:GetAttribute("RuntimeQACaseId")
	if typeof(caseId) ~= "number" or caseId <= lastCaseId then
		return
	end
	lastCaseId = caseId
	local generated = workspace:FindFirstChild("RuntimeQAMap")
		and workspace.RuntimeQAMap:FindFirstChild("GeneratedRooms")
	local room = generated and generated:FindFirstChildWhichIsA("Model")
	remote:FireServer({
		kind = "CaseAck",
		caseId = caseId,
		preset = workspace:GetAttribute("RuntimeQAPreset"),
		role = player:GetAttribute("Role"),
		roomName = room and room.Name or "missing",
		seedId = generated and generated:GetAttribute("SeedId") or "missing",
	})
end

remote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.kind ~= "ErrorProbe" then
		return
	end
	local formatted = QALog.FormatClientError(
		"C:\\Users\\Coppi\\PrivateScript",
		"tester@example.com|probe\nmessage",
		"token=qa-secret C:\\Users\\Coppi\\trace"
	)
	remote:FireServer({
		kind = "ErrorProbeAck",
		formatted = formatted,
	})
end)

workspace:GetAttributeChangedSignal("RuntimeQACaseId"):Connect(acknowledgeCase)
remote:FireServer({ kind = "Ready" })
acknowledgeCase()
