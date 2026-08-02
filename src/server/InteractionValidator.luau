local InteractionValidator = {}

local DEFAULT_DISTANCE_TOLERANCE = 1.5

local function reject(reason)
	return false, reason
end

function InteractionValidator.ValidateConsole(player, room, prompt, context)
	context = context or {}
	if context.GeneratorActive ~= true then
		return reject("generator_inactive")
	end
	if not room or room.Active ~= true or room.Index ~= context.ActiveRoomIndex then
		return reject("room_inactive")
	end
	if
		not room.Model
		or not room.Model.Parent
		or (context.RoomContainer and room.Model.Parent ~= context.RoomContainer)
	then
		return reject("room_missing")
	end
	if typeof(prompt) ~= "Instance" or not prompt:IsA("ProximityPrompt") then
		return reject("invalid_prompt")
	end

	local console = prompt.Parent
	if not console or not console:IsA("BasePart") then
		return reject("invalid_console")
	end
	if console:GetAttribute("GeometryRole") ~= "Console" then
		return reject("not_a_console")
	end
	if
		(context.OperatorRole and prompt:GetAttribute("VisibleToRole") ~= context.OperatorRole)
		or (context.Action and prompt:GetAttribute("InteractionAction") ~= context.Action)
	then
		return reject("invalid_contract")
	end
	if not console:IsDescendantOf(room.Model) or not prompt:IsDescendantOf(room.Model) then
		return reject("foreign_console")
	end
	if
		prompt:GetAttribute("RequiresRoomActive") ~= true
		or prompt:GetAttribute("RoomActive") ~= true
		or not prompt.Enabled
	then
		return reject("prompt_inactive")
	end

	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return reject("invalid_character")
	end

	local tolerance = context.DistanceTolerance
	if typeof(tolerance) ~= "number" then
		tolerance = DEFAULT_DISTANCE_TOLERANCE
	end
	local maximumDistance = math.max(0, prompt.MaxActivationDistance) + math.max(0, tolerance)
	if (root.Position - console.Position).Magnitude > maximumDistance then
		return reject("too_far")
	end

	return true, nil
end

return InteractionValidator
