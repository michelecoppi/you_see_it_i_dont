local Signal = {}

local SIGNAL_COUNT = 3

function Signal.GenerateSolution(randomGenerator, _difficulty)
	return {
		CorrectIndex = randomGenerator:NextInteger(1, SIGNAL_COUNT),
	}
end

function Signal.BuildInitialState(_solution)
	return {
		SelectedIndex = nil,
	}
end

function Signal.Validate(solution, state)
	return type(solution) == "table"
		and type(state) == "table"
		and type(solution.CorrectIndex) == "number"
		and solution.CorrectIndex >= 1
		and solution.CorrectIndex <= SIGNAL_COUNT
		and state.SelectedIndex == solution.CorrectIndex
end

return Signal
