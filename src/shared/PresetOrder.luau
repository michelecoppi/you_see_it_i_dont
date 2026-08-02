local PresetOrder = {}

function PresetOrder.Build(presets, randomGenerator, roomCount, forcedPreset, startRoomIndex)
	assert(type(presets) == "table" and #presets > 0, "presets must not be empty")
	assert(randomGenerator ~= nil, "randomGenerator is required")

	local order = table.clone(presets)
	for index = #order, 2, -1 do
		local other = randomGenerator:NextInteger(1, index)
		order[index], order[other] = order[other], order[index]
	end

	local selectedCount = math.clamp(math.floor(roomCount or 3), 1, #order)
	if forcedPreset then
		local forcedIndex = table.find(order, forcedPreset)
		assert(forcedIndex ~= nil, "unknown forced preset: " .. tostring(forcedPreset))
		local targetIndex = math.clamp(math.floor(startRoomIndex or 1), 1, selectedCount)
		order[forcedIndex], order[targetIndex] = order[targetIndex], order[forcedIndex]
	end

	local selected = {}
	for index = 1, selectedCount do
		table.insert(selected, order[index])
	end
	return selected
end

return table.freeze(PresetOrder)
