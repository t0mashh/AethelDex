--!strict
-- [Config.luau]
-- Central configuration, settings, and constants for AethelDex v1.0

export type DexConfig = {
	Version: string,
	BuildYear: number,
	ThemeName: string,
	RowHeight: number,
	FontSize: number,
	MaxCachedNodes: number,
	AutoDecompile: boolean,
	RemoteSpyEnabled: boolean,
	MobileMode: boolean,
	Keybindings: {
		ToggleDex: Enum.KeyCode,
		CommandPalette: Enum.KeyCode,
		Search: Enum.KeyCode,
		Copy: Enum.KeyCode,
		Paste: Enum.KeyCode,
		Delete: Enum.KeyCode,
	},
}

local Config: DexConfig = {
	Version = "1.0.0-PRO",
	BuildYear = 2026,
	ThemeName = "Obsidian",
	RowHeight = 24,
	FontSize = 13,
	MaxCachedNodes = 200000,
	AutoDecompile = false,
	RemoteSpyEnabled = false,
	MobileMode = false,
	Keybindings = {
		ToggleDex = Enum.KeyCode.F8,
		CommandPalette = Enum.KeyCode.K,
		Search = Enum.KeyCode.F,
		Copy = Enum.KeyCode.C,
		Paste = Enum.KeyCode.V,
		Delete = Enum.KeyCode.Delete,
	},
}

return Config
