local Workspace = game:GetService("Workspace")

local Spec = {}

local SEED = 424242
local PRESETS = { "Signal", "PhaseFloor", "EchoSequence", "FrequencyDials", "PowerGrid", "MirrorRelay", "RuneCircuit" }
local DIFFICULTIES = { "Easy", "Normal", "Hard" }

local CONFIG = {
	PuzzleOrder = PRESETS,
	Round = {
		WrongAnswerPenalty = 5,
		Difficulty = "Normal",
	},
	Roles = {
		Seer = "Seer",
		Operator = "Operator",
		Hybrid = "Solo",
	},
	Signals = {
		{
			Id = "RED",
			DisplayName = "RED",
			Symbol = "CIRCLE",
			Shape = Enum.PartType.Ball,
			Color = Color3.fromRGB(255, 77, 90),
		},
		{
			Id = "BLUE",
			DisplayName = "BLUE",
			Symbol = "SQUARE",
			Shape = Enum.PartType.Block,
			Color = Color3.fromRGB(63, 149, 255),
		},
		{
			Id = "GREEN",
			DisplayName = "GREEN",
			Symbol = "RING",
			Shape = Enum.PartType.Cylinder,
			Color = Color3.fromRGB(73, 222, 128),
		},
	},
}

local function expect(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function expectEqual(actual, expected, message)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local function formatNumber(value)
	return string.format("%.5f", value)
end

local function formatVector3(value)
	return table.concat({ formatNumber(value.X), formatNumber(value.Y), formatNumber(value.Z) }, ",")
end

local function formatColor3(value)
	return table.concat({ formatNumber(value.R), formatNumber(value.G), formatNumber(value.B) }, ",")
end

local function formatCFrame(value)
	local components = { value:GetComponents() }
	for index, component in ipairs(components) do
		components[index] = formatNumber(component)
	end
	return table.concat(components, ",")
end

local function formatAttribute(value)
	local valueType = typeof(value)
	if valueType == "Vector3" then
		return formatVector3(value)
	elseif valueType == "Color3" then
		return formatColor3(value)
	elseif valueType == "CFrame" then
		return formatCFrame(value)
	end
	return tostring(value)
end

local function instancePath(instance, root)
	local parts = {}
	local cursor = instance
	while cursor and cursor ~= root do
		table.insert(parts, 1, cursor.Name)
		cursor = cursor.Parent
	end
	return table.concat(parts, "/")
end

local function snapshot(root)
	local lines = {}
	for _, instance in ipairs(root:GetDescendants()) do
		local fields = { instancePath(instance, root), instance.ClassName }
		if instance:IsA("BasePart") then
			table.insert(fields, formatVector3(instance.Size))
			table.insert(fields, formatCFrame(instance.CFrame))
			table.insert(fields, formatColor3(instance.Color))
			table.insert(fields, instance.Material.Name)
			table.insert(fields, tostring(instance.CanCollide))
			table.insert(fields, formatNumber(instance.Transparency))
		elseif instance:IsA("TextLabel") then
			table.insert(fields, instance.Text)
		elseif instance:IsA("ProximityPrompt") then
			table.insert(fields, instance.ActionText)
			table.insert(fields, instance.ObjectText)
			table.insert(fields, tostring(instance.Enabled))
		end

		local attributes = instance:GetAttributes()
		local attributeNames = {}
		for name in pairs(attributes) do
			table.insert(attributeNames, name)
		end
		table.sort(attributeNames)
		for _, name in ipairs(attributeNames) do
			table.insert(fields, name .. "=" .. formatAttribute(attributes[name]))
		end
		table.insert(lines, table.concat(fields, "|"))
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end

local function makeFixture(name)
	local root = Instance.new("Folder")
	root.Name = name
	root.Parent = Workspace

	local deck = Instance.new("Part")
	deck.Name = "ChamberDeck_1"
	deck.Anchored = true
	deck.Size = Vector3.new(68, 1, 40)
	deck.CFrame = CFrame.new(0, 0, -45)
	deck:SetAttribute("GeometryRole", "Support")
	deck.Parent = root

	local spawnPart = Instance.new("Part")
	spawnPart.Name = "TestSpawn"
	spawnPart.Anchored = true
	spawnPart.Size = Vector3.new(8, 1, 8)
	spawnPart.CFrame = CFrame.new(0, 1, -63)
	spawnPart:SetAttribute("GeometryRole", "Spawn")
	spawnPart.Parent = root

	return root, spawnPart
end

local function generate(RoomGenerator, preset, difficulty, fixtureName)
	local root, spawnPart = makeFixture(fixtureName)
	local generator = RoomGenerator.new(root, spawnPart, CONFIG)
	local order = generator:Generate(Random.new(SEED), 1, {
		ForcedPreset = preset,
		Difficulty = difficulty,
		StartRoomIndex = 1,
		Seed = SEED,
		SeedId = "SEED-0000424242",
		BuildVersion = "test",
		Environment = "Studio",
	})
	local valid, issues = generator:Validate()
	return root, generator, order, valid, issues
end

local function countRoleContracts(root)
	local seerCount = 0
	local operatorPromptCount = 0
	local invalidRoles = {}
	for _, instance in ipairs(root:GetDescendants()) do
		local role = instance:GetAttribute("VisibleToRole")
		if role == CONFIG.Roles.Seer then
			seerCount += 1
		elseif role == CONFIG.Roles.Operator and instance:IsA("ProximityPrompt") then
			operatorPromptCount += 1
		elseif role ~= nil then
			table.insert(invalidRoles, tostring(role))
		end
	end
	return seerCount, operatorPromptCount, invalidRoles
end

local function countGeometryRoles(root)
	local counts = {}
	for _, instance in ipairs(root:GetDescendants()) do
		local role = instance:GetAttribute("GeometryRole")
		if role then
			counts[role] = (counts[role] or 0) + 1
		end
	end
	return counts
end

local function expectGeometryOverlap(generator, target, label)
	local blocker = Instance.new("Part")
	blocker.Name = "InjectedBlocker_" .. label
	blocker.Anchored = true
	blocker.Size = target.Size
	blocker.CFrame = target.CFrame
	blocker:SetAttribute("GeometryRole", "Blocker")
	blocker.Parent = target.Parent

	local valid, issues = generator:Validate()
	expect(not valid, label .. " overlap must fail validation")
	expect(string.find(table.concat(issues, "; "), "geometry overlap", 1, true) ~= nil, label .. " issue is reported")
	blocker:Destroy()

	local restoredValid, restoredIssues = generator:Validate()
	expect(
		restoredValid,
		label .. " fixture must recover after blocker removal: " .. table.concat(restoredIssues, "; ")
	)
end

function Spec.run(RoomGenerator)
	for _, difficulty in ipairs(DIFFICULTIES) do
		for _, preset in ipairs(PRESETS) do
			local firstRoot, firstGenerator, firstOrder, firstValid, firstIssues =
				generate(RoomGenerator, preset, difficulty, "PresetTest_First_" .. preset .. "_" .. difficulty)
			expectEqual(firstOrder[1], preset, preset .. " forced placement")
			expect(firstValid, preset .. " first validation failed: " .. table.concat(firstIssues, "; "))
			local firstGenerated = firstRoot:FindFirstChild("GeneratedRooms")
			expect(firstGenerated ~= nil, preset .. " generated folder exists")
			expectEqual(firstGenerated:GetAttribute("Difficulty"), difficulty, preset .. " folder difficulty")
			local firstRoom = firstGenerated:FindFirstChildWhichIsA("Model")
			expect(firstRoom ~= nil, preset .. " generated room exists")
			expectEqual(firstRoom:GetAttribute("Difficulty"), difficulty, preset .. " room difficulty")

			local seerCount, operatorPromptCount, invalidRoles = countRoleContracts(firstRoot)
			expectEqual(seerCount, 0, preset .. " must not replicate Seer-only clues in the DataModel")
			expect(#firstGenerator:GetSeerClues() > 0, preset .. " must retain a private Seer clue payload")
			expectEqual(#invalidRoles, 0, preset .. " uses only known role markers")
			if preset ~= "PhaseFloor" then
				expect(operatorPromptCount > 0, preset .. " must expose an Operator prompt")
			end
			local geometryRoles = countGeometryRoles(firstRoot)
			expect((geometryRoles.Gate or 0) > 0, preset .. " marks its gate for volumetric validation")
			expect((geometryRoles.Spawn or 0) > 0, preset .. " marks its spawn for volumetric validation")
			if preset == "PhaseFloor" then
				expect((geometryRoles.Path or 0) > 0, preset .. " marks its traversable path")
			else
				expect((geometryRoles.Console or 0) > 0, preset .. " marks its consoles for volumetric validation")
			end

			local firstSnapshot = snapshot(firstGenerated)

			local secondRoot, secondGenerator, secondOrder, secondValid, secondIssues =
				generate(RoomGenerator, preset, difficulty, "PresetTest_Second_" .. preset .. "_" .. difficulty)
			expectEqual(secondOrder[1], preset, preset .. " repeated forced placement")
			expect(secondValid, preset .. " repeated validation failed: " .. table.concat(secondIssues, "; "))
			local secondGenerated = secondRoot:FindFirstChild("GeneratedRooms")
			expect(secondGenerated ~= nil, preset .. " repeated generated folder exists")
			expectEqual(snapshot(secondGenerated), firstSnapshot, preset .. " is deterministic for the same seed")

			firstGenerator:Destroy()
			secondGenerator:Destroy()
			firstRoot:Destroy()
			secondRoot:Destroy()
			print(
				string.format(
					"[QA][Tests] preset=%s | difficulty=%s | seed=SEED-0000424242 | runs=2 | result=PASS",
					preset,
					difficulty
				)
			)
		end
	end

	local geometryRoot, geometryGenerator = generate(RoomGenerator, "Signal", "Normal", "GeometryOverlapContracts")
	local gate = geometryRoot:FindFirstChild("RoomGate_1", true)
	local console = geometryRoot:FindFirstChild("ConsoleBase_RED", true)
	local spawnPart = geometryRoot:FindFirstChild("TestSpawn")
	expect(gate ~= nil and console ~= nil and spawnPart ~= nil, "geometry mutation targets exist")
	expectGeometryOverlap(geometryGenerator, gate, "gate")
	expectGeometryOverlap(geometryGenerator, console, "console")
	expectGeometryOverlap(geometryGenerator, spawnPart, "spawn")
	geometryGenerator:Destroy()
	geometryRoot:Destroy()
end

return Spec
