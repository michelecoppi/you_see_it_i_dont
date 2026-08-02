local EchoSequence = {}

local SIGNAL_COUNT = 3

function EchoSequence.GenerateSolution(randomGenerator, _difficulty)
	local sequenceIndices = { 1, 2, 3 }
	for index = #sequenceIndices, 2, -1 do
		local other = randomGenerator:NextInteger(1, index)
		sequenceIndices[index], sequenceIndices[other] = sequenceIndices[other], sequenceIndices[index]
	end
	return {
		SequenceIndices = sequenceIndices,
	}
end

function EchoSequence.BuildInitialState(_solution)
	return {
		Progress = 1,
	}
end

function EchoSequence.Validate(solution, state)
	if type(solution) ~= "table" or type(state) ~= "table" or type(solution.SequenceIndices) ~= "table" then
		return false
	end
	if #solution.SequenceIndices ~= SIGNAL_COUNT or type(state.Progress) ~= "number" then
		return false
	end
	local seen = {}
	for _, index in ipairs(solution.SequenceIndices) do
		if type(index) ~= "number" or index < 1 or index > SIGNAL_COUNT or seen[index] then
			return false
		end
		seen[index] = true
	end
	return state.Progress > SIGNAL_COUNT
end

return EchoSequence
