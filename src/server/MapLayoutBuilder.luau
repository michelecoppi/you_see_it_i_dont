-- Instantiates the static geometry exported from Blender (blender/export_roblox.py) into Roblox parts.
-- Layout modules live next to this module in MapLayouts; see blender/README.md for the workflow.
local MapLayoutBuilder = {}

local SHAPES = {
	Block = Enum.PartType.Block,
	Cylinder = Enum.PartType.Cylinder,
	Ball = Enum.PartType.Ball,
}

local function resolveMaterials(layout)
	local materials = {}
	for index, entry in ipairs(layout.Materials) do
		local color = entry.Color
		materials[index] = {
			Material = Enum.Material[entry.Material],
			Color = Color3.fromRGB(color[1], color[2], color[3]),
			Transparency = entry.Transparency or 0,
		}
	end
	return materials
end

local function addLight(part, spec, color)
	local fields = string.split(spec, ":")
	local kind = fields[1]
	local light
	if kind == "Surface" then
		light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId[fields[4] or "Bottom"]
		light.Angle = tonumber(fields[5]) or 90
	elseif kind == "Spot" then
		light = Instance.new("SpotLight")
		light.Face = Enum.NormalId[fields[4] or "Bottom"]
		light.Angle = tonumber(fields[5]) or 90
	else
		light = Instance.new("PointLight")
	end
	light.Range = tonumber(fields[2]) or 16
	light.Brightness = tonumber(fields[3]) or 1
	light.Color = color
	light.Shadows = false
	light.Parent = part
	return light
end

local function getFolder(parent, folders, name)
	if not name then
		return parent
	end
	local folder = folders[name]
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
		folders[name] = folder
	end
	return folder
end

-- Builds every part of `layout` under `parent`. Parts are grouped in Folders named after their
-- Blender sub-collection unless options.Flat is true. Returns the created parts in layout order.
function MapLayoutBuilder.Build(parent, layout, options)
	options = options or {}
	local materials = resolveMaterials(layout)
	local folders = {}
	local created = table.create(#layout.Parts)

	for _, spec in ipairs(layout.Parts) do
		local material = materials[spec.M]
		local position = spec.P
		local rotation = spec.R

		local part = Instance.new("Part")
		part.Name = spec.N
		part.Shape = SHAPES[spec.S or "Block"] or Enum.PartType.Block
		part.Size = Vector3.new(spec.Z[1], spec.Z[2], spec.Z[3])
		part.CFrame = if rotation
			then CFrame.new(
				position[1],
				position[2],
				position[3],
				rotation[1],
				rotation[2],
				rotation[3],
				rotation[4],
				rotation[5],
				rotation[6],
				rotation[7],
				rotation[8],
				rotation[9]
			)
			else CFrame.new(position[1], position[2], position[3])
		part.Anchored = true
		part.Material = material.Material
		part.Color = material.Color
		part.Transparency = spec.T or material.Transparency
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = spec.C ~= false
		if spec.C == false and not spec.Q then
			part.CanTouch = false
			part.CanQuery = false
		end
		part.CastShadow = if spec.D ~= nil then spec.D else material.Material ~= Enum.Material.Neon
		if spec.G then
			part:SetAttribute("GeometryRole", spec.G)
		end
		if spec.L then
			addLight(part, spec.L, material.Color)
		end
		part.Parent = if options.Flat then parent else getFolder(parent, folders, spec.F)
		table.insert(created, part)
	end

	return created
end

return MapLayoutBuilder
