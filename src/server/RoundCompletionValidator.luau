local RoundCompletionValidator = {}

function RoundCompletionValidator.Validate(context)
	if context.Phase ~= "Playing" then
		return false, "round_inactive"
	end
	if not context.IsParticipant then
		return false, "not_participant"
	end
	if not context.GeneratorActive or not context.GoalUnlocked then
		return false, "goal_locked"
	end
	if context.CompletedRoomCount < context.ExpectedRoomCount then
		return false, "rooms_incomplete"
	end
	if context.ElapsedSeconds < context.MinimumElapsedSeconds then
		return false, "completion_too_fast"
	end
	if not context.PlayerPosition or not context.GoalPosition then
		return false, "position_missing"
	end
	if (context.PlayerPosition - context.GoalPosition).Magnitude > context.MaximumGoalDistance then
		return false, "goal_too_far"
	end
	return true, nil
end

return RoundCompletionValidator
