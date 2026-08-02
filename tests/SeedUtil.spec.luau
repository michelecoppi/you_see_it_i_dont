local Spec = {}

local function expectEqual(actual, expected, message)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local function expect(condition, message)
	if not condition then
		error(message, 2)
	end
end

function Spec.run(SeedUtil)
	local nan = math.acos(2)

	expectEqual(SeedUtil.Normalize(42), 42, "keeps an in-range integer")
	expectEqual(SeedUtil.Normalize(0), SeedUtil.Maximum, "wraps zero into the safe range")
	expectEqual(SeedUtil.Normalize(SeedUtil.Maximum + 1), 1, "wraps values above the safe range")
	expectEqual(SeedUtil.Normalize(-1), SeedUtil.Maximum - 1, "wraps negative integers")

	expectEqual(SeedUtil.Normalize(1.5, 99), 99, "uses the fallback for fractions")
	expectEqual(SeedUtil.Normalize(nan, 99), 99, "uses the fallback for NaN")
	expectEqual(SeedUtil.Normalize(math.huge, 99), 99, "uses the fallback for infinity")
	expectEqual(SeedUtil.Normalize("42", 99), 99, "does not coerce strings")
	expectEqual(SeedUtil.Normalize(nil, 1.5), SeedUtil.Default, "uses the default when fallback is invalid")

	expect(SeedUtil.IsValid(1), "minimum seed should be valid")
	expect(SeedUtil.IsValid(SeedUtil.Maximum), "maximum seed should be valid")
	expect(not SeedUtil.IsValid(0), "zero should not be valid")
	expect(not SeedUtil.IsValid(1.5), "fractions should not be valid")

	expectEqual(SeedUtil.Identifier(42), "SEED-0000000042", "formats a stable identifier")
	expectEqual(SeedUtil.Identifier(SeedUtil.Maximum + 1), SeedUtil.Identifier(1), "identifier follows normalized seed")
end

return Spec
