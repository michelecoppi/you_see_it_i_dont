local BuildInfo = require(script.Parent.BuildInfo)
local Environment = require(script.Parent.Environment)
local EnvironmentConfig = require(script.Parent.EnvironmentConfig)

local Config = {}

Config.Build = BuildInfo
Config.Version = BuildInfo.Version
Config.BuildId = BuildInfo.BuildId
Config.EnvironmentName = Environment.Resolve()
Config.Environment = Environment
Config.EnvironmentProfile = EnvironmentConfig.Get(Config.EnvironmentName)

Config.GameTitle = "YOU SEE IT, I DON'T"

Config.PuzzleOrder = {
	"Signal",
	"PhaseFloor",
	"EchoSequence",
	"FrequencyDials",
	"PowerGrid",
}

Config.Telemetry = Config.EnvironmentProfile.Telemetry
Config.Persistence = Config.EnvironmentProfile.Persistence
Config.Marketplace = Config.EnvironmentProfile.Marketplace

Config.Lobby = {
	DailyReward = 50,
}

Config.Round = {
	IntermissionDuration = 8,
	RoomCount = 3,
	BasePlayTime = 15,
	TimePerRoom = 22,
	MinimumPlayTime = 60,
	ResultDuration = 6,
	WrongAnswerPenalty = 5,
}

Config.AlternateVision = {
	Duration = 4,
	Cooldown = 8,
}

Config.Interactions = {
	ConsoleDistanceTolerance = 1.5,
	DefaultConsoleCooldown = 0.25,
	ConsoleCooldowns = {
		EchoButton = 0.45,
		FrequencyDial = 0.25,
		GridNode = 0.25,
		SignalButton = 0.55,
	},
}

Config.RemoteGuard = {
	LogRejections = true,
	RejectionLogInterval = 5,
	Categories = {
		Global = { Capacity = 30, RefillPerSecond = 15 },
		Lobby = { Capacity = 8, RefillPerSecond = 4 },
		Vision = { Capacity = 2, RefillPerSecond = 0.5 },
		Economy = { Capacity = 3, RefillPerSecond = 0.5 },
		Puzzle = { Capacity = 8, RefillPerSecond = 8 },
	},
}

Config.QA = {
	Enabled = false,
	PlayerCount = 1,
	StartRoom = 1,
}

Config.Debug = {
	EnableServerLog = false,
}

Config.Roles = {
	Seer = "Seer",
	Operator = "Operator",
	Hybrid = "Solo",
}

Config.Signals = {
	{
		Id = "RED",
		DisplayName = "RED",
		Color = Color3.fromRGB(255, 77, 90),
	},
	{
		Id = "BLUE",
		DisplayName = "BLUE",
		Color = Color3.fromRGB(63, 149, 255),
	},
	{
		Id = "GREEN",
		DisplayName = "GREEN",
		Color = Color3.fromRGB(73, 222, 128),
	},
}

Config.RoleColors = {
	[Config.Roles.Seer] = Color3.fromRGB(177, 110, 255),
	[Config.Roles.Operator] = Color3.fromRGB(255, 177, 66),
	[Config.Roles.Hybrid] = Color3.fromRGB(88, 224, 196),
}

Config.Economy = {
	DataStoreName = Config.Persistence.DataStoreName,
	EnableStudioPersistence = Config.Persistence.EnableStudioPersistence,
	StartingShards = 150,
	StudioStartingShards = 2000,
	Rewards = {
		Escape = 25,
		NoMistakes = 10,
		GroupBonus = 15,
	},
}

Config.CosmeticOrder = {
	"drone_default",
	"drone_mint",
	"drone_sunset",
	"trail_cyan",
	"trail_violet",
	"vision_cyan",
	"vision_sunset",
	"title_pathfinder",
	"drone_void",
	"vision_prismatic",
}

Config.Cosmetics = {
	drone_default = {
		Name = "Survey Drone",
		Description = "Standard expedition companion.",
		Slot = "Drone",
		Currency = "Starter",
		PrimaryColor = Color3.fromRGB(55, 77, 98),
		AccentColor = Color3.fromRGB(74, 255, 222),
	},
	drone_mint = {
		Name = "Mint Drone",
		Description = "A clean mint-and-navy drone shell.",
		Slot = "Drone",
		Currency = "Shards",
		Price = 250,
		PrimaryColor = Color3.fromRGB(31, 86, 89),
		AccentColor = Color3.fromRGB(99, 255, 202),
	},
	drone_sunset = {
		Name = "Sunset Drone",
		Description = "Warm shell recovered from a red reality.",
		Slot = "Drone",
		Currency = "Shards",
		Price = 450,
		PrimaryColor = Color3.fromRGB(103, 48, 72),
		AccentColor = Color3.fromRGB(255, 139, 91),
	},
	trail_cyan = {
		Name = "Cyan Trace",
		Description = "A bright phase trail behind your avatar.",
		Slot = "Trail",
		Currency = "Shards",
		Price = 300,
		PrimaryColor = Color3.fromRGB(70, 225, 218),
		AccentColor = Color3.fromRGB(91, 120, 255),
	},
	trail_violet = {
		Name = "Violet Trace",
		Description = "A deep violet dimensional trail.",
		Slot = "Trail",
		Currency = "Shards",
		Price = 550,
		PrimaryColor = Color3.fromRGB(177, 110, 255),
		AccentColor = Color3.fromRGB(91, 120, 255),
	},
	vision_cyan = {
		Name = "Cyan Vision",
		Description = "Recolors your alternate-reality scan.",
		Slot = "Vision",
		Currency = "Shards",
		Price = 650,
		PrimaryColor = Color3.fromRGB(45, 220, 219),
		AccentColor = Color3.fromRGB(61, 149, 255),
	},
	vision_sunset = {
		Name = "Sunset Vision",
		Description = "A warm anomaly overlay for solo scans.",
		Slot = "Vision",
		Currency = "Shards",
		Price = 850,
		PrimaryColor = Color3.fromRGB(255, 104, 120),
		AccentColor = Color3.fromRGB(255, 177, 66),
	},
	title_pathfinder = {
		Name = "PATHFINDER",
		Description = "An overhead title for skilled explorers.",
		Slot = "Title",
		Currency = "Shards",
		Price = 500,
		PrimaryColor = Color3.fromRGB(88, 224, 196),
	},
	drone_void = {
		Name = "Void Drone",
		Description = "Premium black-hole drone shell.",
		Slot = "Drone",
		Currency = "Pass",
		PassId = Config.Marketplace.GamePasses.VoidDrone,
		PrimaryColor = Color3.fromRGB(20, 14, 34),
		AccentColor = Color3.fromRGB(213, 94, 255),
	},
	vision_prismatic = {
		Name = "Prismatic Vision",
		Description = "Premium reality-vision colorway.",
		Slot = "Vision",
		Currency = "Pass",
		PassId = Config.Marketplace.GamePasses.PrismaticVision,
		PrimaryColor = Color3.fromRGB(225, 117, 255),
		AccentColor = Color3.fromRGB(80, 225, 255),
	},
}

Config.DeveloperProductOrder = {
	"shards_500",
	"shards_1250",
	"shards_3000",
}

Config.DeveloperProducts = {
	shards_500 = {
		Name = "500 Reality Shards",
		ProductId = Config.Marketplace.DeveloperProducts.Shards500,
		Shards = 500,
	},
	shards_1250 = {
		Name = "1,250 Reality Shards",
		ProductId = Config.Marketplace.DeveloperProducts.Shards1250,
		Shards = 1250,
	},
	shards_3000 = {
		Name = "3,000 Reality Shards",
		ProductId = Config.Marketplace.DeveloperProducts.Shards3000,
		Shards = 3000,
	},
}

return Config
