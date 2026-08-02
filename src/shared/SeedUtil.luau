local SeedUtil = {}

-- Random.new accepts numeric seeds, but keeping them in a positive signed
-- 32-bit range makes their behaviour portable and easy to report in QA logs.
local DEFAULT_SEED = 1
local MAX_SEED = 2_147_483_646
local MAX_SAFE_INTEGER = 9_007_199_254_740_991

local function isSafeInteger(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and math.abs(value) <= MAX_SAFE_INTEGER
		and value % 1 == 0
end

function SeedUtil.IsValid(value)
	return isSafeInteger(value) and value >= 1 and value <= MAX_SEED
end

function SeedUtil.Normalize(value, fallback)
	local candidate = value
	if not isSafeInteger(candidate) then
		candidate = fallback
	end
	if not isSafeInteger(candidate) then
		candidate = DEFAULT_SEED
	end

	return ((candidate - 1) % MAX_SEED) + 1
end

function SeedUtil.Identifier(seed)
	return string.format("SEED-%010d", SeedUtil.Normalize(seed))
end

SeedUtil.Default = DEFAULT_SEED
SeedUtil.Maximum = MAX_SEED

return table.freeze(SeedUtil)
