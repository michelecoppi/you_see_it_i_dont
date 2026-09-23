-- Shared visual tokens for the research facility and its interfaces.
local VisualTheme = {
	Colors = {
		Void = Color3.fromRGB(9, 16, 25),
		Panel = Color3.fromRGB(17, 29, 42),
		Steel = Color3.fromRGB(53, 67, 82),
		SteelLight = Color3.fromRGB(91, 108, 123),
		Concrete = Color3.fromRGB(70, 82, 94),
		White = Color3.fromRGB(235, 245, 250),
		Muted = Color3.fromRGB(172, 193, 208),
		Cyan = Color3.fromRGB(48, 207, 247),
		Blue = Color3.fromRGB(55, 135, 255),
		Violet = Color3.fromRGB(162, 91, 247),
		Orange = Color3.fromRGB(255, 151, 53),
		Green = Color3.fromRGB(99, 226, 154),
		Pink = Color3.fromRGB(250, 118, 200),
	},
	UI = {
		CornerRadius = 10,
		StrokeThickness = 1.5,
		PanelTransparency = 0.06,
	},
	Lighting = {
		Brightness = 2.7,
		Ambient = Color3.fromRGB(81, 100, 118),
		OutdoorAmbient = Color3.fromRGB(58, 75, 93),
		Exposure = 0.12,
		BloomIntensity = 0.26,
		BloomThreshold = 1.4,
	},
}

return table.freeze(VisualTheme)
