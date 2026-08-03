local Spec = {}

local SEED_COUNT = 5000

local function expect(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function sameArray(left, right)
	if #left ~= #right then
		return false
	end
	for index = 1, #left do
		if left[index] ~= right[index] then
			return false
		end
	end
	return true
end

local function auditSignal(module, seed, difficulty, rank)
	local solution = module.GenerateSolution(Random.new(seed), difficulty)
	local repeated = module.GenerateSolution(Random.new(seed), difficulty)
	expect(solution.Difficulty == difficulty, "Signal difficulty is not preserved")
	expect(sameArray(solution.SequenceIndices, repeated.SequenceIndices), "Signal is not deterministic")
	expect(#solution.SequenceIndices == rank, "Signal has the wrong sequence length")
	for position, signalIndex in ipairs(solution.SequenceIndices) do
		expect(signalIndex >= 1 and signalIndex <= 3, "Signal index is out of bounds")
		if position > 1 then
			expect(signalIndex ~= solution.SequenceIndices[position - 1], "Signal repeats an adjacent input")
		end
	end
	expect(not module.Validate(solution, module.BuildInitialState(solution)), "Signal starts solved")
	expect(module.Validate(solution, { Progress = rank + 1 }), "Signal solution is rejected")
end

local function auditPhaseFloor(module, seed, difficulty, rank)
	local solution = module.GenerateSolution(Random.new(seed), difficulty)
	local repeated = module.GenerateSolution(Random.new(seed), difficulty)
	expect(solution.Difficulty == difficulty, "PhaseFloor difficulty is not preserved")
	expect(sameArray(solution.SafeColumns, repeated.SafeColumns), "PhaseFloor is not deterministic")
	expect(#solution.SafeColumns == 5, "PhaseFloor has the wrong row count")
	for row, column in ipairs(solution.SafeColumns) do
		expect(column >= 1 and column <= 5, "PhaseFloor column is out of bounds")
		if row > 1 then
			expect(math.abs(column - solution.SafeColumns[row - 1]) <= 1, "PhaseFloor path is discontinuous")
			if rank == 1 then
				expect(column == solution.SafeColumns[row - 1], "Easy PhaseFloor path must be straight")
			elseif rank == 3 then
				expect(column ~= solution.SafeColumns[row - 1], "Hard PhaseFloor path must turn every row")
			end
		end
	end
	expect(not module.Validate(solution, module.BuildInitialState(solution)), "PhaseFloor starts solved")
	expect(module.Validate(solution, { CurrentRow = 5, Failed = false }), "PhaseFloor solution is rejected")
	local orderedState = module.BuildInitialState(solution)
	local skipped, skippedReason = module.Advance(solution, orderedState, 2, solution.SafeColumns[2])
	expect(not skipped and skippedReason == "skipped", "PhaseFloor accepts a skipped row")
	expect(orderedState.CurrentRow == 0, "PhaseFloor skip does not reset progress")
	for row, column in ipairs(solution.SafeColumns) do
		local completed = module.Advance(solution, orderedState, row, column)
		expect(completed == (row == #solution.SafeColumns), "PhaseFloor ordered progress is invalid")
	end
end

local function auditEchoSequence(module, seed, difficulty, rank)
	local solution = module.GenerateSolution(Random.new(seed), difficulty)
	local repeated = module.GenerateSolution(Random.new(seed), difficulty)
	local expectedLength = ({ 3, 4, 5 })[rank]
	expect(solution.Difficulty == difficulty, "EchoSequence difficulty is not preserved")
	expect(sameArray(solution.SequenceIndices, repeated.SequenceIndices), "EchoSequence is not deterministic")
	expect(#solution.SequenceIndices == expectedLength, "EchoSequence has the wrong sequence length")
	for position, index in ipairs(solution.SequenceIndices) do
		expect(index >= 1 and index <= 3, "EchoSequence index is out of bounds")
		if position > 1 then
			expect(index ~= solution.SequenceIndices[position - 1], "EchoSequence repeats an adjacent input")
		end
	end
	expect(not module.Validate(solution, module.BuildInitialState(solution)), "EchoSequence starts solved")
	expect(module.Validate(solution, { Progress = expectedLength + 1 }), "EchoSequence solution is rejected")
end

local function auditFrequencyDials(module, seed, difficulty, rank)
	local solution = module.GenerateSolution(Random.new(seed), difficulty)
	local repeated = module.GenerateSolution(Random.new(seed), difficulty)
	expect(solution.Difficulty == difficulty, "FrequencyDials difficulty is not preserved")
	expect(solution.RequiredTurns == rank, "FrequencyDials has the wrong required turn count")
	expect(sameArray(solution.Targets, repeated.Targets), "FrequencyDials targets are not deterministic")
	expect(sameArray(solution.InitialValues, repeated.InitialValues), "FrequencyDials state is not deterministic")
	local initialState = module.BuildInitialState(solution)
	expect(not module.Validate(solution, initialState), "FrequencyDials starts solved")
	for index, target in ipairs(solution.Targets) do
		expect(target >= 1 and target <= 4, "FrequencyDials target is out of bounds")
		expect(
			initialState.Values[index] >= 1 and initialState.Values[index] <= 4,
			"FrequencyDials value is out of bounds"
		)
		expect((target - initialState.Values[index]) % 4 == rank, "FrequencyDials action distance is incorrect")
	end
	expect(module.Validate(solution, { Values = table.clone(solution.Targets) }), "FrequencyDials solution is rejected")
end

local function minimumGridActions(target)
	local minimum = math.huge
	for mask = 0, 31 do
		local replay = table.create(5, false)
		local actionCount = 0
		for pressed = 1, 5 do
			if math.floor(mask / (2 ^ (pressed - 1))) % 2 == 1 then
				actionCount += 1
				for affected = math.max(1, pressed - 1), math.min(5, pressed + 1) do
					replay[affected] = not replay[affected]
				end
			end
		end
		if sameArray(replay, target) then
			minimum = math.min(minimum, actionCount)
		end
	end
	return minimum
end

local function auditPowerGrid(module, seed, difficulty, rank)
	local solution = module.GenerateSolution(Random.new(seed), difficulty)
	local repeated = module.GenerateSolution(Random.new(seed), difficulty)
	expect(solution.Difficulty == difficulty, "PowerGrid difficulty is not preserved")
	expect(solution.MinimumActions == rank, "PowerGrid has the wrong minimum action metadata")
	expect(sameArray(solution.Target, repeated.Target), "PowerGrid target is not deterministic")
	expect(sameArray(solution.ScramblePresses, repeated.ScramblePresses), "PowerGrid scramble is not deterministic")
	expect(#solution.ScramblePresses == rank, "PowerGrid scramble has the wrong action count")
	local replay = table.create(5, false)
	for _, pressed in ipairs(solution.ScramblePresses) do
		expect(pressed >= 1 and pressed <= 5, "PowerGrid press is out of bounds")
		for affected = math.max(1, pressed - 1), math.min(5, pressed + 1) do
			replay[affected] = not replay[affected]
		end
	end
	expect(sameArray(replay, solution.Target), "PowerGrid target is unreachable from its scramble")
	expect(minimumGridActions(solution.Target) == rank, "PowerGrid target has the wrong optimal action count")
	expect(not module.Validate(solution, module.BuildInitialState(solution)), "PowerGrid starts solved")
	expect(module.Validate(solution, { Current = table.clone(solution.Target) }), "PowerGrid solution is rejected")
end

local function auditMirrorRelay(module, seed, difficulty, rank)
	local solution = module.GenerateSolution(Random.new(seed), difficulty)
	local repeated = module.GenerateSolution(Random.new(seed), difficulty)
	local expectedCount = rank + 2
	expect(solution.Difficulty == difficulty, "MirrorRelay difficulty is not preserved")
	expect(sameArray(solution.Targets, repeated.Targets), "MirrorRelay targets are not deterministic")
	expect(
		sameArray(solution.InitialOrientations, repeated.InitialOrientations),
		"MirrorRelay state is not deterministic"
	)
	expect(sameArray(solution.RequiredTurns, repeated.RequiredTurns), "MirrorRelay turns are not deterministic")
	expect(#solution.Targets == expectedCount, "MirrorRelay has the wrong mirror count")
	local state = module.BuildInitialState(solution)
	expect(not module.Validate(solution, state), "MirrorRelay starts solved")
	local totalTurns = 0
	for index = 1, expectedCount do
		local turns = solution.RequiredTurns[index]
		expect(turns >= 1 and turns <= rank, "MirrorRelay turn count is out of bounds")
		expect(
			(solution.Targets[index] - solution.InitialOrientations[index]) % 4 == turns,
			"MirrorRelay orientation distance is incorrect"
		)
		totalTurns += turns
		for _ = 1, turns do
			module.Rotate(solution, state, index)
		end
	end
	expect(solution.MinimumTurns == totalTurns, "MirrorRelay minimum turn metadata is incorrect")
	expect(module.Validate(solution, state), "MirrorRelay known route is rejected")
end

local function auditRuneCircuit(module, seed, difficulty, rank)
	local solution = module.GenerateSolution(Random.new(seed), difficulty)
	local repeated = module.GenerateSolution(Random.new(seed), difficulty)
	local expectedLength = rank + 2
	expect(solution.Difficulty == difficulty, "RuneCircuit difficulty is not preserved")
	expect(sameArray(solution.SequenceIndices, repeated.SequenceIndices), "RuneCircuit is not deterministic")
	expect(#solution.SequenceIndices == expectedLength, "RuneCircuit has the wrong sequence length")
	local seen = {}
	for _, runeIndex in ipairs(solution.SequenceIndices) do
		expect(runeIndex >= 1 and runeIndex <= 5, "RuneCircuit index is out of bounds")
		expect(not seen[runeIndex], "RuneCircuit repeats a rune")
		seen[runeIndex] = true
	end
	local state = module.BuildInitialState(solution)
	expect(not module.Validate(solution, state), "RuneCircuit starts solved")
	local wrongRune = (solution.SequenceIndices[1] % 5) + 1
	local wrongAccepted, wrongReason = module.Advance(solution, state, wrongRune)
	expect(
		not wrongAccepted and wrongReason == "wrong" and state.Progress == 1,
		"RuneCircuit wrong input does not reset"
	)
	for position, runeIndex in ipairs(solution.SequenceIndices) do
		local completed = module.Advance(solution, state, runeIndex)
		expect(completed == (position == expectedLength), "RuneCircuit known sequence is rejected")
	end
end

function Spec.run(modules, Difficulty)
	expect(Difficulty.Normalize(nil) == Difficulty.Names.Normal, "Difficulty default is not Normal")
	expect(Difficulty.Normalize("easy") == Difficulty.Names.Easy, "Difficulty names are not normalized")
	expect(Difficulty.Normalize(3) == Difficulty.Names.Hard, "Difficulty numeric aliases are not normalized")
	expect(Difficulty.Normalize("unknown") == Difficulty.Names.Normal, "Invalid difficulty does not use the default")
	for rank, difficulty in ipairs(Difficulty.Order) do
		for seed = 1, SEED_COUNT do
			auditSignal(modules.Signal, seed, difficulty, rank)
			auditPhaseFloor(modules.PhaseFloor, seed, difficulty, rank)
			auditEchoSequence(modules.EchoSequence, seed, difficulty, rank)
			auditFrequencyDials(modules.FrequencyDials, seed, difficulty, rank)
			auditPowerGrid(modules.PowerGrid, seed, difficulty, rank)
			auditMirrorRelay(modules.MirrorRelay, seed, difficulty, rank)
			auditRuneCircuit(modules.RuneCircuit, seed, difficulty, rank)
		end
		print(
			string.format(
				"[QA][Tests] pure puzzle modules | difficulty=%s | presets=7 | seeds=%d each | result=PASS",
				difficulty,
				SEED_COUNT
			)
		)
	end
end

return Spec
