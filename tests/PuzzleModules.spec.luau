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

local function auditSignal(module, seed)
	local solution = module.GenerateSolution(Random.new(seed), 1)
	local repeated = module.GenerateSolution(Random.new(seed), 1)
	expect(solution.CorrectIndex == repeated.CorrectIndex, "Signal is not deterministic")
	expect(not module.Validate(solution, module.BuildInitialState(solution)), "Signal starts solved")
	expect(module.Validate(solution, { SelectedIndex = solution.CorrectIndex }), "Signal solution is rejected")
end

local function auditPhaseFloor(module, seed)
	local solution = module.GenerateSolution(Random.new(seed), 1)
	local repeated = module.GenerateSolution(Random.new(seed), 1)
	expect(sameArray(solution.SafeColumns, repeated.SafeColumns), "PhaseFloor is not deterministic")
	expect(#solution.SafeColumns == 5, "PhaseFloor has the wrong row count")
	for row, column in ipairs(solution.SafeColumns) do
		expect(column >= 1 and column <= 5, "PhaseFloor column is out of bounds")
		if row > 1 then
			expect(math.abs(column - solution.SafeColumns[row - 1]) <= 1, "PhaseFloor path is discontinuous")
		end
	end
	expect(not module.Validate(solution, module.BuildInitialState(solution)), "PhaseFloor starts solved")
	expect(module.Validate(solution, { CurrentRow = 5, Failed = false }), "PhaseFloor solution is rejected")
end

local function auditEchoSequence(module, seed)
	local solution = module.GenerateSolution(Random.new(seed), 1)
	local repeated = module.GenerateSolution(Random.new(seed), 1)
	expect(sameArray(solution.SequenceIndices, repeated.SequenceIndices), "EchoSequence is not deterministic")
	local seen = {}
	for _, index in ipairs(solution.SequenceIndices) do
		expect(index >= 1 and index <= 3 and not seen[index], "EchoSequence is not a permutation")
		seen[index] = true
	end
	expect(not module.Validate(solution, module.BuildInitialState(solution)), "EchoSequence starts solved")
	expect(module.Validate(solution, { Progress = 4 }), "EchoSequence solution is rejected")
end

local function auditFrequencyDials(module, seed)
	local solution = module.GenerateSolution(Random.new(seed), 1)
	local repeated = module.GenerateSolution(Random.new(seed), 1)
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
	end
	expect(module.Validate(solution, { Values = table.clone(solution.Targets) }), "FrequencyDials solution is rejected")
end

local function auditPowerGrid(module, seed)
	local solution = module.GenerateSolution(Random.new(seed), 1)
	local repeated = module.GenerateSolution(Random.new(seed), 1)
	expect(sameArray(solution.Target, repeated.Target), "PowerGrid target is not deterministic")
	expect(sameArray(solution.ScramblePresses, repeated.ScramblePresses), "PowerGrid scramble is not deterministic")
	local replay = table.create(5, false)
	for _, pressed in ipairs(solution.ScramblePresses) do
		expect(pressed >= 1 and pressed <= 5, "PowerGrid press is out of bounds")
		for affected = math.max(1, pressed - 1), math.min(5, pressed + 1) do
			replay[affected] = not replay[affected]
		end
	end
	expect(sameArray(replay, solution.Target), "PowerGrid target is unreachable from its scramble")
	expect(not module.Validate(solution, module.BuildInitialState(solution)), "PowerGrid starts solved")
	expect(module.Validate(solution, { Current = table.clone(solution.Target) }), "PowerGrid solution is rejected")
end

function Spec.run(modules)
	for seed = 1, SEED_COUNT do
		auditSignal(modules.Signal, seed)
		auditPhaseFloor(modules.PhaseFloor, seed)
		auditEchoSequence(modules.EchoSequence, seed)
		auditFrequencyDials(modules.FrequencyDials, seed)
		auditPowerGrid(modules.PowerGrid, seed)
	end
	print(string.format("[QA][Tests] pure puzzle modules | presets=5 | seeds=%d each | result=PASS", SEED_COUNT))
end

return Spec
