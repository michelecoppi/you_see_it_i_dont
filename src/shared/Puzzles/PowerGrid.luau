local PowerGrid = {}

local NODE_COUNT = 5

local function toggleNeighborhood(nodes, pressed)
	for affected = math.max(1, pressed - 1), math.min(NODE_COUNT, pressed + 1) do
		nodes[affected] = not nodes[affected]
	end
end

function PowerGrid.GenerateSolution(randomGenerator, _difficulty)
	local target = table.create(NODE_COUNT, false)
	local scramblePresses = table.create(4)
	for pressIndex = 1, 4 do
		local pressed = randomGenerator:NextInteger(1, NODE_COUNT)
		scramblePresses[pressIndex] = pressed
		toggleNeighborhood(target, pressed)
	end

	local anyTargetOn = false
	for _, value in ipairs(target) do
		anyTargetOn = anyTargetOn or value
	end
	if not anyTargetOn then
		table.insert(scramblePresses, 3)
		toggleNeighborhood(target, 3)
	end

	return {
		Target = target,
		ScramblePresses = scramblePresses,
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
