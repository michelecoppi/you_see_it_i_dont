local RunService = game:GetService("RunService")

local Environment = {}

Environment.Names = table.freeze({
	Studio = "Studio",
	PrivateTest = "PrivateTest",
	SoftLaunch = "SoftLaunch",
	Production = "Production",
})

-- In Studio, set the DataModel attribute below to one of Environment.Names to
-- exercise another environment's configuration. Overrides are deliberately
-- ignored outside Studio so a published server always selects Production.
Environment.StudioOverrideAttribute = "EnvironmentOverride"

-- Change this versioned value when producing a published PrivateTest or
-- SoftLaunch build. Runtime/client attributes are never trusted in live servers.
Environment.PublishedEnvironment = Environment.Names.Production

local validNames = {
	[Environment.Names.Studio] = true,
	[Environment.Names.PrivateTest] = true,
	[Environment.Names.SoftLaunch] = true,
	[Environment.Names.Production] = true,
}

function Environment.IsValid(name)
	return type(name) == "string" and validNames[name] == true
end

function Environment.Resolve()
	if not RunService:IsStudio() then
		return Environment.PublishedEnvironment
	end

	local override = game:GetAttribute(Environment.StudioOverrideAttribute)
	if override == nil or override == "" then
		return Environment.Names.Studio
	end

	if Environment.IsValid(override) then
		return override
	end

	warn(
		string.format(
			"Ignoring invalid %s value %q; using Studio",
			Environment.StudioOverrideAttribute,
			tostring(override)
		)
	)
	return Environment.Names.Studio
end

return table.freeze(Environment)
