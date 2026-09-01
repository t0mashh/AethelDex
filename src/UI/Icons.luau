--!strict
-- [Icons.luau]
-- Icon provider for Roblox DataModel classes and AethelDex UI tools

local Icons = {}

-- Standard Roblox Studio class icons mapped to rbxassetid
local CLASS_ICONS = {
	Workspace = "rbxassetid://6031075931",
	Players = "rbxassetid://6031075931",
	Lighting = "rbxassetid://6031075931",
	ReplicatedStorage = "rbxassetid://6031075931",
	ServerScriptService = "rbxassetid://6031075931",
	ServerStorage = "rbxassetid://6031075931",
	StarterGui = "rbxassetid://6031075931",
	StarterPack = "rbxassetid://6031075931",
	StarterPlayer = "rbxassetid://6031075931",
	SoundService = "rbxassetid://6031075931",
	Chat = "rbxassetid://6031075931",
	Folder = "rbxassetid://6031075931",
	Model = "rbxassetid://6031075931",
	Part = "rbxassetid://6031075931",
	MeshPart = "rbxassetid://6031075931",
	Script = "rbxassetid://6031075931",
	LocalScript = "rbxassetid://6031075931",
	ModuleScript = "rbxassetid://6031075931",
	RemoteEvent = "rbxassetid://6031075931",
	RemoteFunction = "rbxassetid://6031075931",
	UnreliableRemoteEvent = "rbxassetid://6031075931",
	ScreenGui = "rbxassetid://6031075931",
	Frame = "rbxassetid://6031075931",
	TextLabel = "rbxassetid://6031075931",
	TextButton = "rbxassetid://6031075931",
	TextBox = "rbxassetid://6031075931",
	ImageLabel = "rbxassetid://6031075931",
	ImageButton = "rbxassetid://6031075931",
	Sound = "rbxassetid://6031075931",
	ParticleEmitter = "rbxassetid://6031075931",
	Attachment = "rbxassetid://6031075931",
	Humanoid = "rbxassetid://6031075931",
	Camera = "rbxassetid://6031075931",
}

local DEFAULT_ICON = "rbxassetid://6031075931"

function Icons.GetClassIcon(className)
	return CLASS_ICONS[className] or DEFAULT_ICON
end

-- Navigation and tool symbols
Icons.EXPAND_ARROW = "▼"
Icons.COLLAPSE_ARROW = "▶"
Icons.CLOSE = "✕"
Icons.SEARCH = "🔍"
Icons.SETTINGS = "⚙"
Icons.TERMINAL = "💻"
Icons.NETWORK = "📡"
Icons.COPY = "📋"
Icons.TRASH = "🗑"

return Icons
