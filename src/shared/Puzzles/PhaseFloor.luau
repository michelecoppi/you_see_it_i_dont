local PhaseFloor = {}
local Difficulty = require(script.Parent.Parent.Difficulty)

local COLUMNS = 5
local ROWS = 5

function PhaseFloor.GenerateSolution(randomGenerator, difficulty)
	local normalizedDifficulty = Difficulty.Normalize(difficulty)
	local difficultyRank = Difficulty.Rank(normalizedDifficulty)
	local safeColumns = table.create(ROWS)
	safeColumns[1] = randomGenerator:NextInteger(2, 4)
	for row = 2, ROWS do
		local previousColumn = safeColumns[row - 1]
		if difficultyRank == 1 then
			safeColumns[row] = previousColumn
		elseif difficultyRank == 2 then
			safeColumns[row] = math.clamp(previousColumn + randomGenerator:NextInteger(-1, 1), 1, COLUMNS)
		else
			local direction
			if previousColumn == 1 then
				direction = 1
			elseif previousColumn == COLUMNS then
				direction = -1
			else
				direction = if randomGenerator:NextInteger(0, 1) == 0 then -1 else 1
			end
			safeColumns[row] = previousColumn + direction
		end
	end
	return {
		Difficulty = normalizedDifficulty,
		SafeColumns = safeColumns,
	}
end

function PhaseFloor.BuildInitialState(_solution)
	return {
		CurrentRow = 0,
		Failed = false,
	}
end

function PhaseFloor.Advance(solution, state, row, column)
	if
		type(solution) ~= "table"
		or type(state) ~= "table"
		or type(solution.SafeColumns) ~= "table"
		or type(state.CurrentRow) ~= "number"
		or type(row) ~= "number"
		or type(column) ~= "number"
		or row < 1
		or row > ROWS
		or column < 1
		or column > COLUMNS
	then
		return false, "invalid"
	end
	if column ~= solution.SafeColumns[row] then
		state.CurrentRow = 0
		state.Failed = false
		return false, "unsafe"
	end
	if row <= state.CurrentRow then
		return false, "repeated"
	end
	if row ~= state.CurrentRow + 1 then
		state.CurrentRow = 0
		state.Failed = false
		return false, "skipped"
	end

	state.CurrentRow = row
	return PhaseFloor.Validate(solution, state), "advanced"
end

function PhaseFloor.Validate(solution, state)
	if
		type(solution) ~= "table"
		or type(state) ~= "table"
		or not Difficulty.IsValid(solution.Difficulty)
		or type(solution.SafeColumns) ~= "table"
	then
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
		if row > 1 and solution.Difficulty == Difficulty.Names.Easy and column ~= solution.SafeColumns[row - 1] then
			return false
		end
		if row > 1 and solution.Difficulty == Difficulty.Names.Hard and column == solution.SafeColumns[row - 1] then
			return false
		end
	end
	return state.CurrentRow >= ROWS
end

return PhaseFloor
