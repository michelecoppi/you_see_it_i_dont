local Spec = {}

local function expect(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function validContext()
	return {
		Phase = "Playing",
		IsParticipant = true,
		GeneratorActive = true,
		GoalUnlocked = true,
		CompletedRoomCount = 3,
		ExpectedRoomCount = 3,
		ElapsedSeconds = 12,
		MinimumElapsedSeconds = 6,
		PlayerPosition = Vector3.new(0, 3, 71),
		GoalPosition = Vector3.new(0, 1, 71),
		MaximumGoalDistance = 14,
	}
end

local function expectRejected(RoundCompletionValidator, context, expectedReason)
	local valid, reason = RoundCompletionValidator.Validate(context)
	expect(not valid, expectedReason .. " must be rejected")
	expect(reason == expectedReason, string.format("expected %s, got %s", expectedReason, tostring(reason)))
end

function Spec.run(RoundCompletionValidator)
	local context = validContext()
	local valid, reason = RoundCompletionValidator.Validate(context)
	expect(valid and reason == nil, "a plausible extraction must be accepted")

	context.ElapsedSeconds = 5.99
	expectRejected(RoundCompletionValidator, context, "completion_too_fast")
	context = validContext()
	context.CompletedRoomCount = 2
	expectRejected(RoundCompletionValidator, context, "rooms_incomplete")
	context = validContext()
	context.PlayerPosition = Vector3.new(0, 3, 100)
	expectRejected(RoundCompletionValidator, context, "goal_too_far")
	context = validContext()
	context.GoalUnlocked = false
	expectRejected(RoundCompletionValidator, context, "goal_locked")
	context = validContext()
	context.IsParticipant = false
	expectRejected(RoundCompletionValidator, context, "not_participant")
end

return Spec
