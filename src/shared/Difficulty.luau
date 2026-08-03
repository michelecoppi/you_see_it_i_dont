local Difficulty = {}

Difficulty.Names = {
	Easy = "Easy",
	Normal = "Normal",
	Hard = "Hard",
}

Difficulty.Order = {
	Difficulty.Names.Easy,
	Difficulty.Names.Normal,
	Difficulty.Names.Hard,
}

Difficulty.Default = Difficulty.Names.Normal

local RANKS = {
	[Difficulty.Names.Easy] = 1,
	[Difficulty.Names.Normal] = 2,
	[Difficulty.Names.Hard] = 3,
}

function Difficulty.Normalize(value)
	if type(value) == "number" then
		return Difficulty.Order[math.clamp(math.floor(value), 1, #Difficulty.Order)]
	end
	if type(value) == "string" then
		local lowered = string.lower(value)
		for _, name in ipairs(Difficulty.Order) do
			if string.lower(name) == lowered then
				return name
			end
		end
	end
	return Difficulty.Default
end

function Difficulty.Rank(value)
	return RANKS[Difficulty.Normalize(value)]
end

function Difficulty.IsValid(value)
	return type(value) == "string" and RANKS[value] ~= nil
end

return Difficulty
