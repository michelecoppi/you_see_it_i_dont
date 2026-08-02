local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local TelemetryService = {}
TelemetryService.__index = TelemetryService

local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

local function safeText(value)
	if value == nil then
		return "none"
	end
	local result = tostring(value)
	return if #result > 50 then string.sub(result, 1, 50) else result
end

local function buildFields(dimensions)
	local fields = {}
	for index = 1, 3 do
		fields[FIELD_KEYS[index]] = safeText(dimensions and dimensions[index])
	end
	return fields
end

function TelemetryService.new(config)
	local self = setmetatable({}, TelemetryService)
	self._config = config.Telemetry or {}
	self._studio = RunService:IsStudio()
	return self
end

function TelemetryService:Log(player, eventName, value, dimensions)
	if not player or not player.Parent then
		return
	end

	value = if typeof(value) == "number" then value else 1
	local fields = buildFields(dimensions)
	if self._studio then
		if self._config.PrintInStudio ~= false then
			print(
				string.format(
					"[Telemetry] %s | user=%d | value=%.2f | %s | %s | %s",
					eventName,
					player.UserId,
					value,
					safeText(dimensions and dimensions[1]),
					safeText(dimensions and dimensions[2]),
					safeText(dimensions and dimensions[3])
				)
			)
		end
		return
	end

	if self._config.EnableAnalytics == false then
		return
	end

	local success, errorMessage = pcall(function()
		AnalyticsService:LogCustomEvent(player, eventName, value, fields)
	end)
	if not success then
		warn("Analytics custom event failed: " .. tostring(errorMessage))
	end
end

function TelemetryService:LogEconomy(player, flowType, amount, endingBalance, transactionType, itemSku, dimensions)
	if not player or not player.Parent or typeof(amount) ~= "number" or amount <= 0 then
		return
	end

	if self._studio then
		if self._config.PrintInStudio ~= false then
			print(
				string.format(
					"[TelemetryEconomy] %s | user=%d | shards=%d | balance=%d | %s",
					flowType.Name,
					player.UserId,
					math.floor(amount),
					math.floor(endingBalance),
					itemSku
				)
			)
		end
		return
	end

	if self._config.EnableAnalytics == false then
		return
	end

	local success, errorMessage = pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			flowType,
			"RealityShards",
			math.floor(amount),
			math.floor(endingBalance),
			transactionType,
			itemSku,
			buildFields(dimensions)
		)
	end)
	if not success then
		warn("Analytics economy event failed: " .. tostring(errorMessage))
	end
end

return TelemetryService
