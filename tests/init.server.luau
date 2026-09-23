local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SeedUtil = require(ReplicatedStorage.Shared.SeedUtil)
local Difficulty = require(ReplicatedStorage.Shared.Difficulty)
local Config = require(ReplicatedStorage.Shared.Config)
local PresetOrder = require(ReplicatedStorage.Shared.PresetOrder)
local InteractionValidator = require(ServerScriptService.ServerModules.InteractionValidator)
local ReceiptLedger = require(ServerScriptService.ServerModules.ReceiptLedger)
local RemoteGuard = require(ServerScriptService.ServerModules.RemoteGuard)
local RoomGenerator = require(ServerScriptService.ServerModules.RoomGenerator)
local RoundCompletionValidator = require(ServerScriptService.ServerModules.RoundCompletionValidator)
local InteractionValidatorSpec = require(script:WaitForChild("InteractionValidator.spec"))
local ReceiptLedgerSpec = require(script:WaitForChild("ReceiptLedger.spec"))
local RemoteGuardSpec = require(script:WaitForChild("RemoteGuard.spec"))
local PresetOrderSpec = require(script:WaitForChild("PresetOrder.spec"))
local PuzzleModulesSpec = require(script:WaitForChild("PuzzleModules.spec"))
local RoomGeneratorSpec = require(script:WaitForChild("RoomGenerator.spec"))
local RoundCompletionValidatorSpec = require(script:WaitForChild("RoundCompletionValidator.spec"))
local SeedUtilSpec = require(script:WaitForChild("SeedUtil.spec"))
local EconomyConfigSpec = require(script:WaitForChild("EconomyConfig.spec"))

local Puzzles = ReplicatedStorage.Shared.Puzzles
local PuzzleModules = {
	Signal = require(Puzzles.Signal),
	PhaseFloor = require(Puzzles.PhaseFloor),
	EchoSequence = require(Puzzles.EchoSequence),
	FrequencyDials = require(Puzzles.FrequencyDials),
	PowerGrid = require(Puzzles.PowerGrid),
	MirrorRelay = require(Puzzles.MirrorRelay),
	RuneCircuit = require(Puzzles.RuneCircuit),
}

local success, message = pcall(function()
	SeedUtilSpec.run(SeedUtil)
	EconomyConfigSpec.run(Config)
	PresetOrderSpec.run(PresetOrder)
	PuzzleModulesSpec.run(PuzzleModules, Difficulty)
	InteractionValidatorSpec.run(InteractionValidator)
	ReceiptLedgerSpec.run(ReceiptLedger)
	RemoteGuardSpec.run(RemoteGuard)
	RoomGeneratorSpec.run(RoomGenerator)
	RoundCompletionValidatorSpec.run(RoundCompletionValidator)
end)
if not success then
	error("Quality tests failed: " .. tostring(message))
end

print(
	"[QA][Tests] economy config, receipts, extraction security, remote guard, interactions, seeds, puzzles and RoomGenerator passed"
)
