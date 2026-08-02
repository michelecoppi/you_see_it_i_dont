local RunService = game:GetService("RunService")

local RoundDebugService = {}
RoundDebugService.__index = RoundDebugService

local function safe(value)
	local text = tostring(value == nil and "none" or value)
	text = string.gsub(text, "[%c|]", " ")
	return string.sub(text, 1, 80)
end

function RoundDebugService.new(config)
	local self = setmetatable({}, RoundDebugService)
	self._enabled = RunService:IsStudio() or (config.Debug and config.Debug.EnableServerLog == true)
	self._context = {}
	return self
end

function RoundDebugService:Begin(buildVersion, environment, seedId, presets)
	self._context = {
		Build = buildVersion,
		Environment = environment,
		Seed = seedId,
		Presets = table.concat(presets, ","),
	}
	self:Log("RoundGenerated", {
		presets = self._context.Presets,
	})
end

function RoundDebugService:Log(eventName, fields)
	if not self._enabled then
		return
	end
	local parts = {
		"[QA][Server] " .. safe(eventName),
		"build=" .. safe(self._context.Build),
		"environment=" .. safe(self._context.Environment),
		"seed=" .. safe(self._context.Seed),
	}
	local keys = {}
	for key in pairs(fields or {}) do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		table.insert(parts, safe(key) .. "=" .. safe(fields[key]))
	end
	print(table.concat(parts, " | "))
end

return RoundDebugService
