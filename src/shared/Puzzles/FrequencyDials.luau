local FrequencyDials = {}

local DIAL_COUNT = 3
local CHANNEL_COUNT = 4

function FrequencyDials.GenerateSolution(randomGenerator, _difficulty)
	local targets = table.create(DIAL_COUNT)
	local initialValues = table.create(DIAL_COUNT)
	for index = 1, DIAL_COUNT do
		targets[index] = randomGenerator:NextInteger(1, CHANNEL_COUNT)
		initialValues[index] = ((targets[index] + randomGenerator:NextInteger(0, 2)) % CHANNEL_COUNT) + 1
	end
	return {
		Targets = targets,
		InitialValues = initialValues,
	}
end

function FrequencyDials.BuildInitialState(solution)
	return {
		Values = table.clone(solution.InitialValues),
	}
end

function FrequencyDials.Validate(solution, state)
	if
		type(solution) ~= "table"
		or type(state) ~= "table"
		or type(solution.Targets) ~= "table"
		or type(state.Values) ~= "table"
		or #solution.Targets ~= DIAL_COUNT
		or #state.Values ~= DIAL_COUNT
	then
		return false
	end
	for index = 1, DIAL_COUNT do
		local target = solution.Targets[index]
		local value = state.Values[index]
		if
			type(target) ~= "number"
			or target < 1
			or target > CHANNEL_COUNT
			or type(value) ~= "number"
			or value < 1
			or value > CHANNEL_COUNT
			or value ~= target
		then
			return false
		end
	end
	return true
end

return FrequencyDials
