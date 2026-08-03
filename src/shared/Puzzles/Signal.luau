local Signal = {}
local Difficulty = require(script.Parent.Parent.Difficulty)

local SIGNAL_COUNT = 3

function Signal.GenerateSolution(randomGenerator, difficulty)
	local normalizedDifficulty = Difficulty.Normalize(difficulty)
	local sequenceLength = Difficulty.Rank(normalizedDifficulty)
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

function Signal.BuildInitialState(_solution)
	return {
		Progress = 1,
	}
end

function Signal.Validate(solution, state)
	if
		type(solution) ~= "table"
		or type(state) ~= "table"
		or not Difficulty.IsValid(solution.Difficulty)
		or type(solution.SequenceIndices) ~= "table"
		or #solution.SequenceIndices ~= Difficulty.Rank(solution.Difficulty)
		or type(state.Progress) ~= "number"
	then
		return false
	end
	for position, signalIndex in ipairs(solution.SequenceIndices) do
		if type(signalIndex) ~= "number" or signalIndex < 1 or signalIndex > SIGNAL_COUNT then
			return false
		end
		if position > 1 and signalIndex == solution.SequenceIndices[position - 1] then
			return false
		end
	end
	return state.Progress > #solution.SequenceIndices
end

return Signal
