--!strict
-- [Theme.luau]
-- Fluent 2026 Design Tokens, colors, typography, and layout metrics

export type Theme = {
	-- Backgrounds
	BgBase: Color3,
	BgSurface: Color3,
	BgElevated: Color3,
	BgHover: Color3,
	BgSelected: Color3,

	-- Borders & Strokes
	BorderSubtle: Color3,
	BorderStrong: Color3,

	-- Accents
	Accent: Color3,
	AccentHover: Color3,
	AccentSuccess: Color3,
	AccentWarning: Color3,
	AccentDanger: Color3,

	-- Text
	TextPrimary: Color3,
	TextSecondary: Color3,
	TextMuted: Color3,

	-- Dimensions & Corner Radii
	CornerRadius: number,
	CornerRadiusSmall: number,
	RowHeight: number,
	FontSize: number,
	Font: Font,
	FontBold: Font,
}

local Theme: Theme = {
	BgBase = Color3.fromRGB(18, 19, 23),
	BgSurface = Color3.fromRGB(25, 27, 33),
	BgElevated = Color3.fromRGB(33, 36, 44),
	BgHover = Color3.fromRGB(42, 46, 56),
	BgSelected = Color3.fromRGB(45, 75, 140),

	BorderSubtle = Color3.fromRGB(48, 52, 64),
	BorderStrong = Color3.fromRGB(70, 76, 92),

	Accent = Color3.fromRGB(79, 117, 255),
	AccentHover = Color3.fromRGB(105, 139, 255),
	AccentSuccess = Color3.fromRGB(46, 204, 113),
	AccentWarning = Color3.fromRGB(241, 196, 15),
	AccentDanger = Color3.fromRGB(231, 76, 60),

	TextPrimary = Color3.fromRGB(245, 246, 250),
	TextSecondary = Color3.fromRGB(175, 180, 195),
	TextMuted = Color3.fromRGB(115, 120, 135),

	CornerRadius = 8,
	CornerRadiusSmall = 4,
	RowHeight = 24,
	FontSize = 13,
	Font = Font.fromEnum(Enum.Font.SourceSans),
	FontBold = Font.fromEnum(Enum.Font.SourceSansBold),
}

return Theme
