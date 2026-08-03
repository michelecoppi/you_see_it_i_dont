local PowerGrid = {}
local Difficulty = require(script.Parent.Parent.Difficulty)

local NODE_COUNT = 5

local function toggleNeighborhood(nodes, pressed)
	for affected = math.max(1, pressed - 1), math.min(NODE_COUNT, pressed + 1) do
		nodes[affected] = not nodes[affected]
	end
end

local function targetKey(target)
	local bits = table.create(NODE_COUNT)
	for index, value in ipairs(target) do
		bits[index] = if value then "1" else "0"
	end
	return table.concat(bits)
end

local function buildCandidates()
	local shortestByTarget = {}
	for mask = 1, (2 ^ NODE_COUNT) - 1 do
		local target = table.create(NODE_COUNT, false)
		local presses = {}
		for index = 1, NODE_COUNT do
			if math.floor(mask / (2 ^ (index - 1))) % 2 == 1 then
				table.insert(presses, index)
				toggleNeighborhood(target, index)
			end
		end
		local key = targetKey(target)
		local existing = shortestByTarget[key]
		if not existing or #presses < #existing.Presses then
			shortestByTarget[key] = {
				Target = target,
				Presses = presses,
			}
		end
	end

	local byMinimumActions = { {}, {}, {} }
	for _, candidate in pairs(shortestByTarget) do
		local actionCount = #candidate.Presses
		if byMinimumActions[actionCount] then
			table.insert(byMinimumActions[actionCount], candidate)
		end
	end
	for _, candidates in ipairs(byMinimumActions) do
		table.sort(candidates, function(left, right)
			return targetKey(left.Target) < targetKey(right.Target)
		end)
	end
	return byMinimumActions
end

local CANDIDATES = buildCandidates()

function PowerGrid.GenerateSolution(randomGenerator, difficulty)
	local normalizedDifficulty = Difficulty.Normalize(difficulty)
	local minimumActions = Difficulty.Rank(normalizedDifficulty)
	local candidates = CANDIDATES[minimumActions]
	local candidate = candidates[randomGenerator:NextInteger(1, #candidates)]

	return {
		Difficulty = normalizedDifficulty,
		MinimumActions = minimumActions,
		Target = table.clone(candidate.Target),
		ScramblePresses = table.clone(candidate.Presses),
	}
end

function PowerGrid.BuildInitialState(_solution)
	return {
		Current = table.create(NODE_COUNT, false),
	}
end

function PowerGrid.Validate(solution, state)
	if
		type(solution) ~= "table"
		or type(state) ~= "table"
		or not Difficulty.IsValid(solution.Difficulty)
		or solution.MinimumActions ~= Difficulty.Rank(solution.Difficulty)
		or type(solution.Target) ~= "table"
		or type(state.Current) ~= "table"
		or #solution.Target ~= NODE_COUNT
		or #state.Current ~= NODE_COUNT
	then
		return false
	end
	for index = 1, NODE_COUNT do
		if type(solution.Target[index]) ~= "boolean" or state.Current[index] ~= solution.Target[index] then
			return false
		end
	end
	return true
end

return PowerGrid
