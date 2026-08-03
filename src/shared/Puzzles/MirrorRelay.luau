local MirrorRelay = {}
local Difficulty = require(script.Parent.Parent.Difficulty)

local ORIENTATION_COUNT = 4
local MIRROR_COUNTS = { 3, 4, 5 }

function MirrorRelay.GenerateSolution(randomGenerator, difficulty)
	local normalizedDifficulty = Difficulty.Normalize(difficulty)
	local rank = Difficulty.Rank(normalizedDifficulty)
	local mirrorCount = MIRROR_COUNTS[rank]
	local targets = table.create(mirrorCount)
	local initialOrientations = table.create(mirrorCount)
	local requiredTurns = table.create(mirrorCount)
	local minimumTurns = 0

	for index = 1, mirrorCount do
		local target = randomGenerator:NextInteger(1, ORIENTATION_COUNT)
		local turns = randomGenerator:NextInteger(1, rank)
		targets[index] = target
		requiredTurns[index] = turns
		initialOrientations[index] = ((target - turns - 1) % ORIENTATION_COUNT) + 1
		minimumTurns += turns
	end

	return {
		Difficulty = normalizedDifficulty,
		Targets = targets,
		InitialOrientations = initialOrientations,
		RequiredTurns = requiredTurns,
		MinimumTurns = minimumTurns,
	}
end

function MirrorRelay.BuildInitialState(solution)
	return {
		Orientations = table.clone(solution.InitialOrientations),
	}
end

function MirrorRelay.Rotate(solution, state, mirrorIndex)
	if
		type(solution) ~= "table"
		or type(state) ~= "table"
		or type(state.Orientations) ~= "table"
		or type(mirrorIndex) ~= "number"
		or mirrorIndex < 1
		or mirrorIndex > #state.Orientations
	then
		return false
	end
	state.Orientations[mirrorIndex] = (state.Orientations[mirrorIndex] % ORIENTATION_COUNT) + 1
	return MirrorRelay.Validate(solution, state)
end

function MirrorRelay.Validate(solution, state)
	if
		type(solution) ~= "table"
		or type(state) ~= "table"
		or not Difficulty.IsValid(solution.Difficulty)
		or type(solution.Targets) ~= "table"
		or type(solution.InitialOrientations) ~= "table"
		or type(solution.RequiredTurns) ~= "table"
		or type(state.Orientations) ~= "table"
	then
		return false
	end
	local expectedCount = MIRROR_COUNTS[Difficulty.Rank(solution.Difficulty)]
	if
		#solution.Targets ~= expectedCount
		or #solution.InitialOrientations ~= expectedCount
		or #solution.RequiredTurns ~= expectedCount
		or #state.Orientations ~= expectedCount
	then
		return false
	end
	for index = 1, expectedCount do
		local target = solution.Targets[index]
		local current = state.Orientations[index]
		local turns = solution.RequiredTurns[index]
		if
			type(target) ~= "number"
			or target < 1
			or target > ORIENTATION_COUNT
			or type(current) ~= "number"
			or current < 1
			or current > ORIENTATION_COUNT
			or type(turns) ~= "number"
			or turns < 1
			or turns > Difficulty.Rank(solution.Difficulty)
			or ((target - solution.InitialOrientations[index]) % ORIENTATION_COUNT) ~= turns
			or current ~= target
		then
			return false
		end
	end
	return true
end

return MirrorRelay
