--!strict
-- [ReflectionEngine.luau]
-- Dynamic engine reflection, property discovery, and 2026 property categorizer

local Serializers = require(script.Parent.Serializers)

export type PropertyItem = {
	Name: string,
	Value: any,
	Type: string,
	Category: string,
	IsReadOnly: boolean,
	IsHidden: boolean,
}

local ReflectionEngine = {}

-- Standard property categorizations
local CATEGORY_MAP = {
	-- Identity & Hierarchy
	Name = "Data",
	Parent = "Data",
	ClassName = "Data",
	Archivable = "Data",

	-- Transform & Physical
	CFrame = "Transform",
	Position = "Transform",
	Orientation = "Transform",
	Rotation = "Transform",
	Size = "Transform",
	Anchored = "Physics",
	CanCollide = "Physics",
	CanTouch = "Physics",
	CanQuery = "Physics",
	Massless = "Physics",
	Velocity = "Physics",
	AssemblyLinearVelocity = "Physics",
	AssemblyAngularVelocity = "Physics",
	CustomPhysicalProperties = "Physics",
	CollisionGroup = "Physics",

	-- Appearance
	Color = "Appearance",
	BrickColor = "Appearance",
	Material = "Appearance",
	MaterialVariant = "Appearance",
	Transparency = "Appearance",
	Reflectance = "Appearance",
	CastShadow = "Appearance",

	-- GUI & Rendering
	Visible = "Appearance",
	ZIndex = "Appearance",
	LayoutOrder = "Appearance",
	BackgroundTransparency = "Appearance",
	BackgroundColor3 = "Appearance",
	BorderColor3 = "Appearance",
	BorderSizePixel = "Appearance",
	Text = "Content",
	TextColor3 = "Appearance",
	TextSize = "Appearance",
	TextScaled = "Appearance",
	Font = "Appearance",
	FontFace = "Appearance",
	Image = "Content",
	ImageColor3 = "Appearance",
	ImageTransparency = "Appearance",

	-- Audio (Modern 2026)
	SoundId = "Audio",
	Volume = "Audio",
	PlaybackSpeed = "Audio",
	TimePosition = "Audio",
	Playing = "Audio",
	Looped = "Audio",
	RollOffMinDistance = "Audio",
	RollOffMaxDistance = "Audio",
}

-- Fallback property list for standard Instances across engine classes
local COMMON_PROPERTY_NAMES = {
	"Name", "Parent", "Archivable", "ClassName",
	"CFrame", "Position", "Orientation", "Size", "Transparency", "Color", "BrickColor", "Material",
	"Anchored", "CanCollide", "CanTouch", "CanQuery", "Massless", "CollisionGroup",
	"AssemblyLinearVelocity", "AssemblyAngularVelocity",
	"Visible", "ZIndex", "LayoutOrder", "Active", "AnchorPoint",
	"BackgroundColor3", "BackgroundTransparency", "BorderColor3", "BorderSizePixel",
	"Text", "TextColor3", "TextSize", "TextScaled", "Font",
	"Image", "ImageColor3", "ImageTransparency",
	"SoundId", "Volume", "PlaybackSpeed", "TimePosition", "Playing", "Looped",
	"Enabled", "Adornee", "AlwaysOnTop", "LightEmission", "LightInfluence",
	"Brightness", "Range", "Shadows", "FieldOfView"
}

function ReflectionEngine.GetProperties(target)
	local result = {}
	local seen = {}

	-- 1. Try executor native reflection if present (e.g. getproperties / gethiddenproperties)
	local getproperties = (rawget(getfenv(), "getproperties") )
	local gethiddenproperties = (rawget(getfenv(), "gethiddenproperties") )

	if typeof(getproperties) == "function" then
		local ok, props = pcall(getproperties, target)
		if ok and typeof(props) == "table" then
			for propName, val in pairs(props) do
				seen[propName] = true
				table.insert(result, {
					Name = propName,
					Value = val,
					Type = typeof(val),
					Category = CATEGORY_MAP[propName] or "Other",
					IsReadOnly = (propName == "ClassName"),
					IsHidden = false,
				})
			end
		end
	end

	if typeof(gethiddenproperties) == "function" then
		local ok, hiddenProps = pcall(gethiddenproperties, target)
		if ok and typeof(hiddenProps) == "table" then
			for propName, val in pairs(hiddenProps) do
				if not seen[propName] then
					seen[propName] = true
					table.insert(result, {
						Name = propName,
						Value = val,
						Type = typeof(val),
						Category = "Hidden",
						IsReadOnly = false,
						IsHidden = true,
					})
				end
			end
		end
	end

	-- 2. Fallback probe for all remaining common engine properties
	for _, propName in ipairs(COMMON_PROPERTY_NAMES) do
		if not seen[propName] then
			local ok, val = pcall(function()
				return (target )[propName]
			end)

			if ok and val ~= nil then
				seen[propName] = true
				table.insert(result, {
					Name = propName,
					Value = val,
					Type = typeof(val),
					Category = CATEGORY_MAP[propName] or "Other",
					IsReadOnly = (propName == "ClassName"),
					IsHidden = false,
				})
			end
		end
	end

	-- Sort properties: Category first, then Alphabetically
	table.sort(result, function(a, b)
		if a.Category ~= b.Category then
			return a.Category < b.Category
		end
		return a.Name < b.Name
	end)

	return result
end

function ReflectionEngine.SetProperty(target, propName, newValueStr, propType)
	local parseOk, parsedValue = Serializers.ParseValue(newValueStr, propType)
	if not parseOk then
		return false, tostring(parsedValue)
	end

	-- Try native sethiddenproperty first if available
	local sethiddenproperty = (rawget(getfenv(), "sethiddenproperty") )
	if typeof(sethiddenproperty) == "function" then
		local sOk, sErr = pcall(sethiddenproperty, target, propName, parsedValue)
		if sOk then
			return true, nil
		end
	end

	local ok, err = pcall(function()
		(target )[propName] = parsedValue
	end)

	return ok, err
end

return ReflectionEngine
