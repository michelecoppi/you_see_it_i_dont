local RuneCircuit = {}
local Difficulty = require(script.Parent.Parent.Difficulty)

local RUNE_COUNT = 5
local SEQUENCE_LENGTHS = { 3, 4, 5 }

function RuneCircuit.GenerateSolution(randomGenerator, difficulty)
	local normalizedDifficulty = Difficulty.Normalize(difficulty)
	local runePool = table.create(RUNE_COUNT)
	for index = 1, RUNE_COUNT do
		runePool[index] = index
	end
	for index = RUNE_COUNT, 2, -1 do
		local swapIndex = randomGenerator:NextInteger(1, index)
		runePool[index], runePool[swapIndex] = runePool[swapIndex], runePool[index]
	end

	local sequenceLength = SEQUENCE_LENGTHS[Difficulty.Rank(normalizedDifficulty)]
	local sequenceIndices = table.create(sequenceLength)
	for index = 1, sequenceLength do
		sequenceIndices[index] = runePool[index]
	end
	return {
		Difficulty = normalizedDifficulty,
		SequenceIndices = sequenceIndices,
	}
end

function RuneCircuit.BuildInitialState(_solution)
	return {
		Progress = 1,
	}
end

function RuneCircuit.Advance(solution, state, runeIndex)
	if
		type(solution) ~= "table"
		or type(state) ~= "table"
		or type(solution.SequenceIndices) ~= "table"
		or type(state.Progress) ~= "number"
		or type(runeIndex) ~= "number"
	then
		return false, "invalid"
	end
	if runeIndex ~= solution.SequenceIndices[state.Progress] then
		state.Progress = 1
		return false, "wrong"
	end
	state.Progress += 1
	return RuneCircuit.Validate(solution, state), "accepted"
end

function RuneCircuit.Validate(solution, state)
	if
		type(solution) ~= "table"
		or type(state) ~= "table"
		or not Difficulty.IsValid(solution.Difficulty)
		or type(solution.SequenceIndices) ~= "table"
		or type(state.Progress) ~= "number"
	then
		return false
	end
	local expectedLength = SEQUENCE_LENGTHS[Difficulty.Rank(solution.Difficulty)]
	if #solution.SequenceIndices ~= expectedLength then
		return false
	end
	local seen = {}
	for _, runeIndex in ipairs(solution.SequenceIndices) do
		if type(runeIndex) ~= "number" or runeIndex < 1 or runeIndex > RUNE_COUNT or seen[runeIndex] then
			return false
		end
		seen[runeIndex] = true
	end
	return state.Progress > expectedLength
end

return RuneCircuit
