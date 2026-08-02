local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SeedUtil = require(ReplicatedStorage.Shared.SeedUtil)
local PresetOrder = require(ReplicatedStorage.Shared.PresetOrder)
local InteractionValidator = require(ServerScriptService.ServerModules.InteractionValidator)
local RemoteGuard = require(ServerScriptService.ServerModules.RemoteGuard)
local RoomGenerator = require(ServerScriptService.ServerModules.RoomGenerator)
local InteractionValidatorSpec = require(script:WaitForChild("InteractionValidator.spec"))
local RemoteGuardSpec = require(script:WaitForChild("RemoteGuard.spec"))
local PresetOrderSpec = require(script:WaitForChild("PresetOrder.spec"))
local PuzzleModulesSpec = require(script:WaitForChild("PuzzleModules.spec"))
local RoomGeneratorSpec = require(script:WaitForChild("RoomGenerator.spec"))
local SeedUtilSpec = require(script:WaitForChild("SeedUtil.spec"))

local Puzzles = ReplicatedStorage.Shared.Puzzles
local PuzzleModules = {
	Signal = require(Puzzles.Signal),
	PhaseFloor = require(Puzzles.PhaseFloor),
	EchoSequence = require(Puzzles.EchoSequence),
	FrequencyDials = require(Puzzles.FrequencyDials),
	PowerGrid = require(Puzzles.PowerGrid),
}

local success, message = pcall(function()
	SeedUtilSpec.run(SeedUtil)
	PresetOrderSpec.run(PresetOrder)
	PuzzleModulesSpec.run(PuzzleModules)
	InteractionValidatorSpec.run(InteractionValidator)
	RemoteGuardSpec.run(RemoteGuard)
	RoomGeneratorSpec.run(RoomGenerator)
end)
if not success then
	error("Quality tests failed: " .. tostring(message))
end

print("[QA][Tests] remote guard, interaction security, seeds, puzzles and all five RoomGenerator preset tests passed")
