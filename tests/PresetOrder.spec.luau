local Spec = {}

local function expectEqual(actual, expected, message)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local function expectArrayEqual(actual, expected, message)
	expectEqual(#actual, #expected, message .. " length")
	for index, value in ipairs(expected) do
		expectEqual(actual[index], value, message .. " item " .. tostring(index))
	end
end

function Spec.run(PresetOrder)
	local presets = { "Signal", "PhaseFloor", "EchoSequence", "FrequencyDials", "PowerGrid" }
	local first = PresetOrder.Build(presets, Random.new(424242), 3)
	local repeated = PresetOrder.Build(presets, Random.new(424242), 3)
	expectArrayEqual(repeated, first, "same seed produces the same order")
	expectEqual(#first, 3, "respects room count")

	local forced = PresetOrder.Build(presets, Random.new(424242), 3, "PowerGrid", 2)
	expectEqual(forced[2], "PowerGrid", "places the forced preset in the requested room")

	local oneRoom = PresetOrder.Build(presets, Random.new(7), 1, "Signal", 3)
	expectEqual(#oneRoom, 1, "clamps the target room to the selected room count")
	expectEqual(oneRoom[1], "Signal", "keeps forced preset inside selected rooms")
end

return Spec
