local PhaseFloor = {}

local COLUMNS = 5
local ROWS = 5

function PhaseFloor.GenerateSolution(randomGenerator, _difficulty)
	local safeColumns = table.create(ROWS)
	safeColumns[1] = randomGenerator:NextInteger(2, 4)
	for row = 2, ROWS do
		safeColumns[row] = math.clamp(safeColumns[row - 1] + randomGenerator:NextInteger(-1, 1), 1, COLUMNS)
	end
	return {
		SafeColumns = safeColumns,
	}
end

function PhaseFloor.BuildInitialState(_solution)
	return {
		CurrentRow = 0,
		Failed = false,
	}
end

function PhaseFloor.Validate(solution, state)
	if type(solution) ~= "table" or type(state) ~= "table" or type(solution.SafeColumns) ~= "table" then
		return false
	end
	if #solution.SafeColumns ~= ROWS or state.Failed == true or type(state.CurrentRow) ~= "number" then
		return false
	end
	for row, column in ipairs(solution.SafeColumns) do
		if type(column) ~= "number" or column < 1 or column > COLUMNS then
			return false
		end
		if row > 1 and math.abs(column - solution.SafeColumns[row - 1]) > 1 then
			return false
		end
	end
	return state.CurrentRow >= ROWS
end

return PhaseFloor
