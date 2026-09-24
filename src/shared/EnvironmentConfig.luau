local Environment = require(script.Parent.Environment)

-- Marketplace identifiers intentionally remain zero until their assets are
-- created in the corresponding Roblox universe. Keep IDs scoped per profile.
-- Sessions: 0 means "use this same place". Set MatchPlaceId to a dedicated expedition place of the
-- same universe (and LobbyPlaceId to the hub place) only if you split the game into two places.
local Profiles = {
	[Environment.Names.Studio] = {
		Telemetry = {
			EnableAnalytics = false,
			PrintInStudio = true,
		},
		Persistence = {
			DataStoreName = "RealityProfiles_Studio_v1",
			EnableStudioPersistence = false,
		},
		Sessions = {
			MatchPlaceId = 0,
			LobbyPlaceId = 0,
		},
		Marketplace = {
			GamePasses = {
				VoidDrone = 0,
				PrismaticVision = 0,
			},
			DeveloperProducts = {
				Shards500 = 0,
				Shards1250 = 0,
				Shards3000 = 0,
			},
		},
	},
	[Environment.Names.PrivateTest] = {
		Telemetry = {
			EnableAnalytics = true,
			PrintInStudio = true,
		},
		Persistence = {
			DataStoreName = "RealityProfiles_PrivateTest_v1",
			EnableStudioPersistence = false,
		},
		Sessions = {
			MatchPlaceId = 0,
			LobbyPlaceId = 0,
		},
		Marketplace = {
			GamePasses = {
				VoidDrone = 0,
				PrismaticVision = 0,
			},
			DeveloperProducts = {
				Shards500 = 0,
				Shards1250 = 0,
				Shards3000 = 0,
			},
		},
	},
	[Environment.Names.SoftLaunch] = {
		Telemetry = {
			EnableAnalytics = true,
			PrintInStudio = true,
		},
		Persistence = {
			DataStoreName = "RealityProfiles_SoftLaunch_v1",
			EnableStudioPersistence = false,
		},
		Sessions = {
			MatchPlaceId = 0,
			LobbyPlaceId = 0,
		},
		Marketplace = {
			GamePasses = {
				VoidDrone = 0,
				PrismaticVision = 0,
			},
			DeveloperProducts = {
				Shards500 = 0,
				Shards1250 = 0,
				Shards3000 = 0,
			},
		},
	},
	[Environment.Names.Production] = {
		Telemetry = {
			EnableAnalytics = true,
			PrintInStudio = false,
		},
		Persistence = {
			DataStoreName = "RealityProfiles_v1",
			EnableStudioPersistence = false,
		},
		Sessions = {
			MatchPlaceId = 0,
			LobbyPlaceId = 0,
		},
		Marketplace = {
			GamePasses = {
				VoidDrone = 0,
				PrismaticVision = 0,
			},
			DeveloperProducts = {
				Shards500 = 0,
				Shards1250 = 0,
				Shards3000 = 0,
			},
		},
	},
}

local EnvironmentConfig = {}

function EnvironmentConfig.Get(environmentName)
	assert(Environment.IsValid(environmentName), "Unknown environment: " .. tostring(environmentName))
	return Profiles[environmentName]
end

return table.freeze(EnvironmentConfig)
