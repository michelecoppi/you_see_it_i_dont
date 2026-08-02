local Workspace = game:GetService("Workspace")

local Spec = {}

local function expect(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function expectRejected(InteractionValidator, player, room, prompt, context, expectedReason)
	local valid, reason = InteractionValidator.ValidateConsole(player, room, prompt, context)
	expect(not valid, expectedReason .. " must be rejected")
	expect(reason == expectedReason, string.format("expected %s, got %s", expectedReason, tostring(reason)))
end

function Spec.run(InteractionValidator)
	local fixture = Instance.new("Folder")
	fixture.Name = "InteractionValidatorFixture"
	fixture.Parent = Workspace

	local roomModel = Instance.new("Model")
	roomModel.Name = "ActiveRoom"
	roomModel.Parent = fixture

	local console = Instance.new("Part")
	console.Name = "Console"
	console.Anchored = true
	console.Position = Vector3.new(0, 3, 0)
	console:SetAttribute("GeometryRole", "Console")
	console.Parent = roomModel

	local prompt = Instance.new("ProximityPrompt")
	prompt.Enabled = true
	prompt.MaxActivationDistance = 11
	prompt:SetAttribute("RequiresRoomActive", true)
	prompt:SetAttribute("RoomActive", true)
	prompt:SetAttribute("VisibleToRole", "Operator")
	prompt:SetAttribute("InteractionAction", "SignalButton")
	prompt.Parent = console

	local character = Instance.new("Model")
	character.Name = "Character"
	character.Parent = fixture
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = true
	root.Position = Vector3.new(0, 3, 5)
	root.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	local player = { Character = character }

	local room = {
		Active = true,
		Index = 1,
		Model = roomModel,
	}
	local context = {
		GeneratorActive = true,
		ActiveRoomIndex = 1,
		DistanceTolerance = 1.5,
		RoomContainer = fixture,
		OperatorRole = "Operator",
		Action = "SignalButton",
	}

	local valid, reason = InteractionValidator.ValidateConsole(player, room, prompt, context)
	expect(valid and reason == nil, "nearby console in the active room must be accepted")

	root.Position = Vector3.new(0, 3, 20)
	expectRejected(InteractionValidator, player, room, prompt, context, "too_far")
	root.Position = Vector3.new(0, 3, 5)

	room.Active = false
	expectRejected(InteractionValidator, player, room, prompt, context, "room_inactive")
	room.Active = true

	context.ActiveRoomIndex = 2
	expectRejected(InteractionValidator, player, room, prompt, context, "room_inactive")
	context.ActiveRoomIndex = 1

	console:SetAttribute("GeometryRole", nil)
	expectRejected(InteractionValidator, player, room, prompt, context, "not_a_console")
	console:SetAttribute("GeometryRole", "Console")
	prompt:SetAttribute("InteractionAction", "EchoButton")
	expectRejected(InteractionValidator, player, room, prompt, context, "invalid_contract")
	prompt:SetAttribute("InteractionAction", "SignalButton")

	local foreignRoom = Instance.new("Model")
	foreignRoom.Name = "ForeignRoom"
	foreignRoom.Parent = fixture
	console.Parent = foreignRoom
	expectRejected(InteractionValidator, player, room, prompt, context, "foreign_console")

	fixture:Destroy()
end

return Spec
