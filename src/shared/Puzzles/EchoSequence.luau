local EchoSequence = {}
local Difficulty = require(script.Parent.Parent.Difficulty)

local SIGNAL_COUNT = 3
local SEQUENCE_LENGTHS = { 3, 4, 5 }

function EchoSequence.GenerateSolution(randomGenerator, difficulty)
	local normalizedDifficulty = Difficulty.Normalize(difficulty)
	local sequenceLength = SEQUENCE_LENGTHS[Difficulty.Rank(normalizedDifficulty)]
	local sequenceIndices = table.create(sequenceLength)
	for position = 1, sequenceLength do
		local signalIndex = randomGenerator:NextInteger(1, SIGNAL_COUNT)
		if position > 1 and signalIndex == sequenceIndices[position - 1] then
			signalIndex = (signalIndex % SIGNAL_COUNT) + 1
		end
		sequenceIndices[position] = signalIndex
	end
	return {
		Difficulty = normalizedDifficulty,
		SequenceIndices = sequenceIndices,
	}
end

function EchoSequence.BuildInitialState(_solution)
	return {
		Progress = 1,
	}
end

function EchoSequence.Validate(solution, state)
	if
		type(solution) ~= "table"
		or type(state) ~= "table"
		or not Difficulty.IsValid(solution.Difficulty)
		or type(solution.SequenceIndices) ~= "table"
	then
		return false
	end
	if
		#solution.SequenceIndices ~= SEQUENCE_LENGTHS[Difficulty.Rank(solution.Difficulty)]
		or type(state.Progress) ~= "number"
	then
		return false
	end
	for position, index in ipairs(solution.SequenceIndices) do
		if type(index) ~= "number" or index < 1 or index > SIGNAL_COUNT then
			return false
		end
		if position > 1 and index == solution.SequenceIndices[position - 1] then
			return false
		end
	end
	return state.Progress > #solution.SequenceIndices
end

return EchoSequence
