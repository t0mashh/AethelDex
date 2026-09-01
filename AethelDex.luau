--!strict
--[[
    ================================================================================
    AethelDex v1.0.0-PRO (Build 2026)
    Next-Generation In-Game DataModel Hierarchy Explorer & Debugger Suite for Roblox
    
    Loadstring Usage:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/REPLACE_WITH_USER/AethelDex/main/AethelDex.luau"))()
    ================================================================================
--]]

local __modules = {}
local __cache = {}

local function __require(name: string): any
    if __cache[name] ~= nil then
        return __cache[name]
    end
    local loader = __modules[name]
    if not loader then
        error("[AethelDex Bundle] Module not found: " .. tostring(name))
    end
    local result = loader()
    __cache[name] = result
    return result
end

-- Module: Signal
__modules["Signal"] = function()
    -- [Signal.luau]
    -- Ultra-fast linked-list based Signal implementation for AethelDex
    
    export type Connection = {
    	Connected: boolean,
    	Disconnect: (self: Connection) -> (),
    }
    
    export type Signal<T...> = {
    	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
    	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
    	Wait: (self: Signal<T...>) -> T...,
    	Fire: (self: Signal<T...>, T...) -> (),
    	DisconnectAll: (self: Signal<T...>) -> (),
    }
    
    type Node = {
    	fn: (...any) -> (),
    	next: Node?,
    	prev: Node?,
    	connected: boolean,
    }
    
    local Signal = {}
    Signal.__index = Signal
    
    function Signal.new<T...>(): Signal<T...>
    	local self = setmetatable({
    		_head = nil :: Node?,
    	}, Signal)
    	return (self :: any) :: Signal<T...>
    end
    
    function Signal:Connect(fn: (...any) -> ()): Connection
    	local node: Node = {
    		fn = fn,
    		next = self._head,
    		prev = nil,
    		connected = true,
    	}
    
    	if self._head then
    		self._head.prev = node
    	end
    	self._head = node
    
    	local connection: Connection
    	connection = {
    		Connected = true,
    		Disconnect = function(conn: Connection)
    			if not node.connected then
    				return
    			end
    			node.connected = false
    			conn.Connected = false
    
    			if node.prev then
    				node.prev.next = node.next
    			else
    				self._head = node.next
    			end
    
    			if node.next then
    				node.next.prev = node.prev
    			end
    		end,
    	}
    
    	return connection
    end
    
    function Signal:Once(fn: (...any) -> ()): Connection
    	local connection: Connection
    	connection = self:Connect(function(...)
    		connection:Disconnect()
    		fn(...)
    	end)
    	return connection
    end
    
    function Signal:Wait(): ...any
    	local thread = coroutine.running()
    	local connection: Connection
    	connection = self:Connect(function(...)
    		connection:Disconnect()
    		task.spawn(thread, ...)
    	end)
    	return coroutine.yield()
    end
    
    function Signal:Fire(...: any)
    	local current = self._head
    	while current do
    		local nextNode = current.next
    		if current.connected then
    			task.spawn(current.fn, ...)
    		end
    		current = nextNode
    	end
    end
    
    function Signal:DisconnectAll()
    	local current = self._head
    	while current do
    		current.connected = false
    		current = current.next
    	end
    	self._head = nil
    end
    
    return Signal
end

-- Module: Janitor
__modules["Janitor"] = function()
    -- [Janitor.luau]
    -- Safe lifecycle management and connection cleaner for AethelDex
    
    export type Destructible =
    	RBXScriptConnection
    	| Instance
    	| () -> ()
    	| thread
    	| { Destroy: (any) -> () }
    	| { Disconnect: (any) -> () }
    
    export type Janitor = {
    	Add: <T>(self: Janitor, object: T, methodName: string?) -> T,
    	Remove: (self: Janitor, object: any) -> (),
    	Cleanup: (self: Janitor) -> (),
    	Destroy: (self: Janitor) -> (),
    }
    
    local Janitor = {}
    Janitor.__index = Janitor
    
    function Janitor.new(): Janitor
    	local self = setmetatable({
    		_objects = {} :: { [any]: any },
    	}, Janitor)
    	return (self :: any) :: Janitor
    end
    
    function Janitor:Add<T>(object: T, methodName: string?): T
    	if object == nil then
    		return object
    	end
    	self._objects[object] = methodName or true
    	return object
    end
    
    function Janitor:Remove(object: any)
    	self._objects[object] = nil
    end
    
    local function cleanObject(object: any, method: any)
    	if typeof(object) == "RBXScriptConnection" then
    		object:Disconnect()
    	elseif typeof(object) == "Instance" then
    		object:Destroy()
    	elseif typeof(object) == "function" then
    		task.spawn(object)
    	elseif typeof(object) == "thread" then
    		task.cancel(object)
    	elseif typeof(object) == "table" then
    		if typeof(method) == "string" and typeof(object[method]) == "function" then
    			object[method](object)
    		elseif typeof(object.Destroy) == "function" then
    			object:Destroy()
    		elseif typeof(object.Disconnect) == "function" then
    			object:Disconnect()
    		end
    	end
    end
    
    function Janitor:Cleanup()
    	local objects = self._objects
    	self._objects = {}
    
    	for object, method in pairs(objects) do
    		cleanObject(object, method)
    	end
    end
    
    function Janitor:Destroy()
    	self:Cleanup()
    end
    
    return Janitor
end

-- Module: Config
__modules["Config"] = function()
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
end

-- Module: Scheduler
__modules["Scheduler"] = function()
    -- [Scheduler.luau]
    -- Non-blocking coroutine and chunked frame scheduler for AethelDex
    
    local Scheduler = {}
    
    -- Maximum time in seconds to spend in a single frame before yielding to avoid dropping FPS
    local DEFAULT_FRAME_BUDGET = 0.006 -- 6 milliseconds
    
    function Scheduler.ChunkedIterate<T>(
    	list: { T },
    	processItem: (item: T, index: number) -> boolean?,
    	onComplete: (() -> ())?,
    	maxTimePerFrame: number?
    )
    	local budget = maxTimePerFrame or DEFAULT_FRAME_BUDGET
    	local total = #list
    	local index = 1
    
    	task.spawn(function()
    		local startTime = os.clock()
    
    		while index <= total do
    			local shouldContinue = processItem(list[index], index)
    			if shouldContinue == false then
    				break
    			end
    
    			index += 1
    
    			if os.clock() - startTime >= budget then
    				task.wait()
    				startTime = os.clock()
    			end
    		end
    
    		if onComplete then
    			onComplete()
    		end
    	end)
    end
    
    function Scheduler.Defer(fn: () -> ())
    	task.defer(fn)
    end
    
    function Scheduler.Delay(seconds: number, fn: () -> ())
    	task.delay(seconds, fn)
    end
    
    return Scheduler
end

-- Module: SafeHost
__modules["SafeHost"] = function()
    -- [SafeHost.luau]
    -- Environment detection, stealth mounting, and GUI host manager for AethelDex
    
    local CoreGui = game:GetService("CoreGui")
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    
    export type SafeHost = {
    	RootGui: ScreenGui,
    	Container: Instance,
    	IsStealth: boolean,
    	Destroy: (self: SafeHost) -> (),
    }
    
    local SafeHost = {}
    SafeHost.__index = SafeHost
    
    local function getSafeRef(inst: Instance): Instance
    	local cloneref = (rawget(getfenv(), "cloneref") :: any)
    	if typeof(cloneref) == "function" then
    		local success, result = pcall(cloneref, inst)
    		if success and typeof(result) == "Instance" then
    			return result
    		end
    	end
    	return inst
    end
    
    function SafeHost.new(customName: string?): SafeHost
    	local name = customName or ("AethelDex_" .. string.sub(HttpService:GenerateGUID(false), 1, 8))
    	local screenGui = Instance.new("ScreenGui")
    	screenGui.Name = name
    	screenGui.ResetOnSpawn = false
    	screenGui.DisplayOrder = 999999
    	screenGui.IgnoreGuiInset = true
    
    	local hostContainer: Instance = CoreGui
    	local isStealth = false
    
    	local gethui = (rawget(getfenv(), "gethui") :: any)
    	local syn = (rawget(getfenv(), "syn") :: any)
    
    	if typeof(gethui) == "function" then
    		local success, hui = pcall(gethui)
    		if success and typeof(hui) == "Instance" then
    			hostContainer = getSafeRef(hui)
    			screenGui.Parent = hostContainer
    			isStealth = true
    		end
    	end
    
    	if not isStealth and syn and typeof(syn.protect_gui) == "function" then
    		pcall(syn.protect_gui, screenGui)
    		screenGui.Parent = getSafeRef(CoreGui)
    		isStealth = true
    	end
    
    	if screenGui.Parent == nil then
    		-- Fallback to CoreGui or PlayerGui
    		local parented = pcall(function()
    			screenGui.Parent = getSafeRef(CoreGui)
    		end)
    
    		if not parented or screenGui.Parent == nil then
    			local localPlayer = Players.LocalPlayer
    			if localPlayer then
    				local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
    				if playerGui then
    					screenGui.Parent = getSafeRef(playerGui)
    				end
    			end
    		end
    	end
    
    	local self = setmetatable({
    		RootGui = screenGui,
    		Container = hostContainer,
    		IsStealth = isStealth,
    	}, SafeHost)
    
    	return (self :: any) :: SafeHost
    end
    
    function SafeHost:Destroy()
    	if self.RootGui then
    		self.RootGui:Destroy()
    	end
    end
    
    return SafeHost
end

-- Module: TypeDefinitions
__modules["TypeDefinitions"] = function()
    -- [TypeDefinitions.luau]
    -- Core type definitions for AethelDex v1.0
    
    export type TreeNode = {
    	Instance: Instance,
    	Depth: number,
    	HasChildren: boolean,
    	IsExpanded: boolean,
    	Visible: boolean,
    	Children: { TreeNode },
    	Parent: TreeNode?,
    	CustomIcon: string?,
    }
    
    export type PropertyDescriptor = {
    	Name: string,
    	ValueType: string,
    	Category: string,
    	IsReadOnly: boolean,
    	IsHidden: boolean,
    	Value: any,
    }
    
    export type NetworkCallLog = {
    	Id: string,
    	Timestamp: number,
    	Remote: Instance,
    	RemoteType: "RemoteEvent" | "RemoteFunction" | "UnreliableRemoteEvent",
    	Method: "FireServer" | "InvokeServer" | "OnClientEvent",
    	Arguments: { any },
    	CallerScript: Instance?,
    	Blocked: boolean,
    }
    
    export type SearchFilter = {
    	Query: string,
    	ClassName: string?,
    	PropertyName: string?,
    	PropertyValue: string?,
    	Tag: string?,
    	IsRegex: boolean,
    }
    
    return {}
end

-- Module: Serializers
__modules["Serializers"] = function()
    -- [Serializers.luau]
    -- Bidirectional string <-> Luau Type serializer and formatters
    
    local Serializers = {}
    
    function Serializers.FormatValue(val: any, valType: string?): string
    	local t = valType or typeof(val)
    
    	if val == nil then
    		return "nil"
    	elseif t == "string" then
    		return tostring(val)
    	elseif t == "number" then
    		return string.format("%.4f", val):gsub("%.?0+$", "")
    	elseif t == "boolean" then
    		return val and "true" or "false"
    	elseif t == "Vector2" then
    		return string.format("%.2f, %.2f", val.X, val.Y)
    	elseif t == "Vector3" then
    		return string.format("%.2f, %.2f, %.2f", val.X, val.Y, val.Z)
    	elseif t == "CFrame" then
    		local x, y, z = val.X, val.Y, val.Z
    		local rx, ry, rz = val:ToEulerAnglesXYZ()
    		return string.format(
    			"Pos(%.1f, %.1f, %.1f) Rot(%.1f, %.1f, %.1f)",
    			x, y, z,
    			math.deg(rx), math.deg(ry), math.deg(rz)
    		)
    	elseif t == "Color3" then
    		return string.format("%d, %d, %d", math.round(val.R * 255), math.round(val.G * 255), math.round(val.B * 255))
    	elseif t == "BrickColor" then
    		return val.Name
    	elseif t == "UDim" then
    		return string.format("%.2f, %d", val.Scale, val.Offset)
    	elseif t == "UDim2" then
    		return string.format("{%.2f, %d}, {%.2f, %d}", val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset)
    	elseif t == "EnumItem" then
    		return val.Name
    	elseif t == "Instance" then
    		return val.Name .. " [" .. val.ClassName .. "]"
    	elseif t == "Font" then
    		return val.Family .. " (" .. tostring(val.Weight.Name) .. ")"
    	elseif t == "buffer" then
    		return "[buffer: " .. tostring(buffer.len(val)) .. " bytes]"
    	else
    		return tostring(val)
    	end
    end
    
    function Serializers.ParseValue(inputStr: string, targetType: string): (boolean, any)
    	if targetType == "string" then
    		return true, inputStr
    	elseif targetType == "number" then
    		local num = tonumber(inputStr)
    		if num ~= nil then
    			return true, num
    		end
    		return false, "Invalid number"
    	elseif targetType == "boolean" then
    		local lower = string.lower(inputStr)
    		if lower == "true" or lower == "1" then
    			return true, true
    		elseif lower == "false" or lower == "0" then
    			return true, false
    		end
    		return false, "Invalid boolean"
    	elseif targetType == "Vector3" then
    		local parts = string.split(inputStr, ",")
    		if #parts == 3 then
    			local x, y, z = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
    			if x and y and z then
    				return true, Vector3.new(x, y, z)
    			end
    		end
    		return false, "Expected 'x, y, z'"
    	elseif targetType == "Vector2" then
    		local parts = string.split(inputStr, ",")
    		if #parts == 2 then
    			local x, y = tonumber(parts[1]), tonumber(parts[2])
    			if x and y then
    				return true, Vector2.new(x, y)
    			end
    		end
    		return false, "Expected 'x, y'"
    	elseif targetType == "Color3" then
    		local parts = string.split(inputStr, ",")
    		if #parts == 3 then
    			local r, g, b = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
    			if r and g and b then
    				return true, Color3.fromRGB(r, g, b)
    			end
    		end
    		return false, "Expected 'r, g, b' (0-255)"
    	elseif targetType == "UDim2" then
    		local numbers = {}
    		for num in string.gmatch(inputStr, "[-+]?%d*%.?%d+") do
    			table.insert(numbers, tonumber(num))
    		end
    		if #numbers == 4 then
    			return true, UDim2.new(numbers[1], numbers[2], numbers[3], numbers[4])
    		end
    		return false, "Expected '{xs, xo}, {ys, yo}'"
    	end
    
    	return false, "Unsupported direct parse type: " .. targetType
    end
    
    return Serializers
end

-- Module: Theme
__modules["Theme"] = function()
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
end

-- Module: Icons
__modules["Icons"] = function()
    -- [Icons.luau]
    -- Icon provider for Roblox DataModel classes and AethelDex UI tools
    
    local Icons = {}
    
    -- Standard Roblox Studio class icons mapped to rbxassetid
    local CLASS_ICONS: { [string]: string } = {
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
    
    function Icons.GetClassIcon(className: string): string
    	return CLASS_ICONS[className] or DEFAULT_ICON
    end
    
    -- Navigation and tool symbols
    Icons.EXPAND_ARROW = "в–ј"
    Icons.COLLAPSE_ARROW = "в–¶"
    Icons.CLOSE = "вњ•"
    Icons.SEARCH = "рџ”Ќ"
    Icons.SETTINGS = "вљ™"
    Icons.TERMINAL = "рџ’»"
    Icons.NETWORK = "рџ“Ў"
    Icons.COPY = "рџ“‹"
    Icons.TRASH = "рџ—‘"
    
    return Icons
end

-- Module: TouchEngine
__modules["TouchEngine"] = function()
    -- [TouchEngine.luau]
    -- Adaptive touch controller, gesture recognizer, and mobile hitboxes for AethelDex
    
    local UserInputService = game:GetService("UserInputService")
    local Theme = __require("Theme")
    
    export type TouchEngine = {
    	IsTouchDevice: boolean,
    	MinHitboxSize: number,
    	CreateMobileToggle: (onToggle: () -> ()) -> ImageButton,
    }
    
    local TouchEngine = {}
    
    TouchEngine.IsTouchDevice = UserInputService.TouchEnabled
    TouchEngine.MinHitboxSize = TouchEngine.IsTouchDevice and 44 or 24
    
    function TouchEngine.CreateMobileToggle(onToggle: () -> ()): ImageButton
    	local button = Instance.new("ImageButton")
    	button.Name = "AethelDex_MobileToggle"
    	button.Size = UDim2.fromOffset(50, 50)
    	button.Position = UDim2.new(0, 15, 0.5, -25)
    	button.BackgroundColor3 = Theme.Accent
    	button.Image = "rbxassetid://6031075931"
    	button.ImageColor3 = Color3.new(1, 1, 1)
    	button.ZIndex = 1000000
    
    	local corner = Instance.new("UICorner")
    	corner.CornerRadius = UDim.new(1, 0)
    	corner.Parent = button
    
    	local stroke = Instance.new("UIStroke")
    	stroke.Color = Color3.new(1, 1, 1)
    	stroke.Thickness = 2
    	stroke.Transparency = 0.5
    	stroke.Parent = button
    
    	-- Dragging logic for mobile floating button
    	local dragging = false
    	local dragStart: Vector2
    	local startPos: UDim2
    
    	button.InputBegan:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
    			dragging = true
    			dragStart = input.Position
    			startPos = button.Position
    
    			input.Changed:Connect(function()
    				if input.UserInputState == Enum.UserInputState.End then
    					dragging = false
    				end
    			end)
    		end
    	end)
    
    	UserInputService.InputChanged:Connect(function(input)
    		if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
    			local delta = input.Position - dragStart
    			button.Position = UDim2.new(
    				startPos.X.Scale,
    				startPos.X.Offset + delta.X,
    				startPos.Y.Scale,
    				startPos.Y.Offset + delta.Y
    			)
    		end
    	end)
    
    	button.Activated:Connect(onToggle)
    
    	return button
    end
    
    return TouchEngine
end

-- Module: ReflectionEngine
__modules["ReflectionEngine"] = function()
    -- [ReflectionEngine.luau]
    -- Dynamic engine reflection, property discovery, and 2026 property categorizer
    
    local Serializers = __require("Serializers")
    
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
    local CATEGORY_MAP: { [string]: string } = {
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
    
    function ReflectionEngine.GetProperties(target: Instance): { PropertyItem }
    	local result: { PropertyItem } = {}
    	local seen: { [string]: boolean } = {}
    
    	-- 1. Try executor native reflection if present (e.g. getproperties / gethiddenproperties)
    	local getproperties = (rawget(getfenv(), "getproperties") :: any)
    	local gethiddenproperties = (rawget(getfenv(), "gethiddenproperties") :: any)
    
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
    				return (target :: any)[propName]
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
    
    function ReflectionEngine.SetProperty(target: Instance, propName: string, newValueStr: string, propType: string): (boolean, string?)
    	local parseOk, parsedValue = Serializers.ParseValue(newValueStr, propType)
    	if not parseOk then
    		return false, tostring(parsedValue)
    	end
    
    	-- Try native sethiddenproperty first if available
    	local sethiddenproperty = (rawget(getfenv(), "sethiddenproperty") :: any)
    	if typeof(sethiddenproperty) == "function" then
    		local sOk, sErr = pcall(sethiddenproperty, target, propName, parsedValue)
    		if sOk then
    			return true, nil
    		end
    	end
    
    	local ok, err = pcall(function()
    		(target :: any)[propName] = parsedValue
    	end)
    
    	return ok, err
    end
    
    return ReflectionEngine
end

-- Module: TreeState
__modules["TreeState"] = function()
    -- [TreeState.luau]
    -- DataModel hierarchy state, expansion tracker, and selection manager for AethelDex
    
    local Signal = __require("Signal")
    
    export type Node = {
    	Instance: Instance,
    	Depth: number,
    	Expanded: boolean,
    	HasChildren: boolean,
    	ParentNode: Node?,
    	Children: { Node },
    }
    
    export type TreeState = {
    	RootNodes: { Node },
    	NodeMap: { [Instance]: Node },
    	FlattenedList: { Node },
    	SelectedInstances: { [Instance]: boolean },
    	SelectionList: { Instance },
    	
    	OnSelectionChanged: Signal.Signal<{ Instance }>,
    	OnTreeStructureChanged: Signal.Signal<()>,
    
    	ToggleExpand: (self: TreeState, node: Node) -> (),
    	SetExpanded: (self: TreeState, node: Node, expanded: boolean) -> (),
    	Select: (self: TreeState, inst: Instance, isMulti: boolean?) -> (),
    	Deselect: (self: TreeState, inst: Instance) -> (),
    	ClearSelection: (self: TreeState) -> (),
    	RebuildFlattened: (self: TreeState) -> (),
    	AddRootService: (self: TreeState, service: Instance) -> (),
    }
    
    local TreeState = {}
    TreeState.__index = TreeState
    
    function TreeState.new(): TreeState
    	local self = setmetatable({
    		RootNodes = {} :: { Node },
    		NodeMap = {} :: { [Instance]: Node },
    		FlattenedList = {} :: { Node },
    		SelectedInstances = {} :: { [Instance]: boolean },
    		SelectionList = {} :: { Instance },
    
    		OnSelectionChanged = Signal.new(),
    		OnTreeStructureChanged = Signal.new(),
    	}, TreeState)
    
    	return (self :: any) :: TreeState
    end
    
    function TreeState:CreateNode(inst: Instance, depth: number, parentNode: Node?): Node
    	local hasKids = #inst:GetChildren() > 0
    	local node: Node = {
    		Instance = inst,
    		Depth = depth,
    		Expanded = false,
    		HasChildren = hasKids,
    		ParentNode = parentNode,
    		Children = {},
    	}
    	self.NodeMap[inst] = node
    	return node
    end
    
    function TreeState:AddRootService(service: Instance)
    	if self.NodeMap[service] then
    		return
    	end
    	local rootNode = self:CreateNode(service, 0, nil)
    	table.insert(self.RootNodes, rootNode)
    	self:RebuildFlattened()
    end
    
    function TreeState:PopulateChildren(node: Node)
    	local children = node.Instance:GetChildren()
    	node.HasChildren = #children > 0
    	table.clear(node.Children)
    
    	for _, child in ipairs(children) do
    		local childNode = self.NodeMap[child]
    		if not childNode then
    			childNode = self:CreateNode(child, node.Depth + 1, node)
    		else
    			childNode.Depth = node.Depth + 1
    			childNode.ParentNode = node
    		end
    		table.insert(node.Children, childNode)
    	end
    end
    
    function TreeState:ToggleExpand(node: Node)
    	self:SetExpanded(node, not node.Expanded)
    end
    
    function TreeState:SetExpanded(node: Node, expanded: boolean)
    	if node.Expanded == expanded then
    		return
    	end
    
    	node.Expanded = expanded
    	if expanded then
    		self:PopulateChildren(node)
    	end
    
    	self:RebuildFlattened()
    	self.OnTreeStructureChanged:Fire()
    end
    
    local function flattenRecursive(node: Node, output: { Node })
    	table.insert(output, node)
    	if node.Expanded then
    		for _, child in ipairs(node.Children) do
    			flattenRecursive(child, output)
    		end
    	end
    end
    
    function TreeState:RebuildFlattened()
    	table.clear(self.FlattenedList)
    	for _, root in ipairs(self.RootNodes) do
    		flattenRecursive(root, self.FlattenedList)
    	end
    end
    
    function TreeState:Select(inst: Instance, isMulti: boolean?)
    	if not isMulti then
    		table.clear(self.SelectedInstances)
    		table.clear(self.SelectionList)
    	end
    
    	if not self.SelectedInstances[inst] then
    		self.SelectedInstances[inst] = true
    		table.insert(self.SelectionList, inst)
    	end
    
    	self.OnSelectionChanged:Fire(self.SelectionList)
    end
    
    function TreeState:Deselect(inst: Instance)
    	if self.SelectedInstances[inst] then
    		self.SelectedInstances[inst] = nil
    		for i, selected in ipairs(self.SelectionList) do
    			if selected == inst then
    				table.remove(self.SelectionList, i)
    				break
    			end
    		end
    		self.OnSelectionChanged:Fire(self.SelectionList)
    	end
    end
    
    function TreeState:ClearSelection()
    	table.clear(self.SelectedInstances)
    	table.clear(self.SelectionList)
    	self.OnSelectionChanged:Fire(self.SelectionList)
    end
    
    return TreeState
end

-- Module: SearchEngine
__modules["SearchEngine"] = function()
    -- [SearchEngine.luau]
    -- High-speed search engine with prefix filters (c:, p:, t:) and regex support
    
    local TreeState = __require("TreeState")
    
    export type MatchResult = {
    	Node: TreeState.Node,
    	MatchedText: string,
    }
    
    local SearchEngine = {}
    
    function SearchEngine.FilterNodes(nodes: { TreeState.Node }, query: string): { TreeState.Node }
    	local trimmed = string.gsub(query, "^%s*(.-)%s*$", "%1")
    	if trimmed == "" then
    		return nodes
    	end
    
    	local results: { TreeState.Node } = {}
    
    	-- Check for prefix filters
    	local classFilter: string? = nil
    	local propFilterName: string? = nil
    	local propFilterValue: string? = nil
    	local tagFilter: string? = nil
    	local rawTerm = trimmed
    
    	if string.sub(trimmed, 1, 2) == "c:" then
    		classFilter = string.lower(string.sub(trimmed, 3))
    	elseif string.sub(trimmed, 1, 2) == "t:" then
    		tagFilter = string.sub(trimmed, 3)
    	elseif string.sub(trimmed, 1, 2) == "p:" then
    		local propQuery = string.sub(trimmed, 3)
    		local eqPos = string.find(propQuery, "=")
    		if eqPos then
    			propFilterName = string.sub(propQuery, 1, eqPos - 1)
    			propFilterValue = string.lower(string.sub(propQuery, eqPos + 1))
    		else
    			propFilterName = propQuery
    		end
    	end
    
    	local lowerRaw = string.lower(rawTerm)
    
    	for _, node in ipairs(nodes) do
    		local inst = node.Instance
    		local match = false
    
    		if classFilter then
    			if string.find(string.lower(inst.ClassName), classFilter, 1, true) then
    				match = true
    			end
    		elseif tagFilter then
    			local CollectionService = game:GetService("CollectionService")
    			if CollectionService:HasTag(inst, tagFilter) then
    				match = true
    			end
    		elseif propFilterName then
    			local ok, val = pcall(function()
    				return (inst :: any)[propFilterName :: string]
    			end)
    			if ok and val ~= nil then
    				if propFilterValue then
    					if string.find(string.lower(tostring(val)), propFilterValue, 1, true) then
    						match = true
    					end
    				else
    					match = true
    				end
    			end
    		else
    			-- Standard text search by Instance Name or ClassName
    			if string.find(string.lower(inst.Name), lowerRaw, 1, true) or
    			   string.find(string.lower(inst.ClassName), lowerRaw, 1, true) then
    				match = true
    			end
    		end
    
    		if match then
    			table.insert(results, node)
    		end
    	end
    
    	return results
    end
    
    return SearchEngine
end

-- Module: VirtualList
__modules["VirtualList"] = function()
    -- [VirtualList.luau]
    -- High-performance virtualized windowing engine for AethelDex Explorer
    -- Uses a fixed pool of ~35 recycled UI rows. O(1) mathematical scroll calculation.
    
    local Theme = __require("Theme")
    local Icons = __require("Icons")
    local TreeState = __require("TreeState")
    
    export type VirtualList = {
    	ScrollingFrame: ScrollingFrame,
    	TreeState: TreeState.TreeState,
    	RowPool: { Frame },
    	VisibleRowCount: number,
    	RowHeight: number,
    	RenderedNodes: { TreeState.Node },
    	
    	UpdateData: (self: VirtualList, nodes: { TreeState.Node }) -> (),
    	UpdateView: (self: VirtualList) -> (),
    	Destroy: (self: VirtualList) -> (),
    }
    
    local VirtualList = {}
    VirtualList.__index = VirtualList
    
    function VirtualList.new(parentFrame: Frame, treeState: TreeState.TreeState): VirtualList
    	local scroll = Instance.new("ScrollingFrame")
    	scroll.Name = "TreeScroll"
    	scroll.Size = UDim2.new(1, 0, 1, -40)
    	scroll.Position = UDim2.new(0, 0, 0, 40)
    	scroll.BackgroundTransparency = 1
    	scroll.BorderSizePixel = 0
    	scroll.ScrollBarThickness = 6
    	scroll.ScrollBarImageColor3 = Theme.BorderStrong
    	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    	scroll.Parent = parentFrame
    
    	local rowHeight = Theme.RowHeight
    	local visibleRows = math.ceil(parentFrame.AbsoluteSize.Y / rowHeight) + 4
    	if visibleRows < 20 then
    		visibleRows = 35
    	end
    
    	local pool: { Frame } = {}
    
    	local self = setmetatable({
    		ScrollingFrame = scroll,
    		TreeState = treeState,
    		RowPool = pool,
    		VisibleRowCount = visibleRows,
    		RowHeight = rowHeight,
    		RenderedNodes = {},
    	}, VirtualList)
    
    	-- Instantiate the recycled pool of UI rows
    	for i = 1, visibleRows do
    		local row = Instance.new("Frame")
    		row.Name = `Row_{i}`
    		row.Size = UDim2.new(1, 0, 0, rowHeight)
    		row.BackgroundTransparency = 1
    		row.BorderSizePixel = 0
    		row.Visible = false
    		row.Parent = scroll
    
    		local rowBtn = Instance.new("TextButton")
    		rowBtn.Name = "RowBtn"
    		rowBtn.Size = UDim2.new(1, 0, 1, 0)
    		rowBtn.BackgroundTransparency = 1
    		rowBtn.Text = ""
    		rowBtn.AutoButtonColor = false
    		rowBtn.Parent = row
    
    		-- Expand / Collapse arrow button
    		local arrow = Instance.new("TextButton")
    		arrow.Name = "Arrow"
    		arrow.Size = UDim2.fromOffset(16, 16)
    		arrow.Position = UDim2.new(0, 4, 0.5, -8)
    		arrow.BackgroundTransparency = 1
    		arrow.TextColor3 = Theme.TextSecondary
    		arrow.TextSize = 10
    		arrow.Text = Icons.COLLAPSE_ARROW
    		arrow.Font = Enum.Font.SourceSansBold
    		arrow.Parent = row
    
    		-- Class icon
    		local icon = Instance.new("ImageLabel")
    		icon.Name = "Icon"
    		icon.Size = UDim2.fromOffset(16, 16)
    		icon.Position = UDim2.new(0, 22, 0.5, -8)
    		icon.BackgroundTransparency = 1
    		icon.Image = Icons.GetClassIcon("Part")
    		icon.Parent = row
    
    		-- Item Name
    		local nameLabel = Instance.new("TextLabel")
    		nameLabel.Name = "ItemName"
    		nameLabel.Size = UDim2.new(1, -45, 1, 0)
    		nameLabel.Position = UDim2.new(0, 44, 0, 0)
    		nameLabel.BackgroundTransparency = 1
    		nameLabel.TextColor3 = Theme.TextPrimary
    		nameLabel.TextSize = Theme.FontSize
    		nameLabel.Font = Enum.Font.SourceSans
    		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    		nameLabel.Parent = row
    
    		table.insert(pool, row)
    	end
    
    	-- Hook scroll listener for instantaneous view updates
    	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    		self:UpdateView()
    	end)
    
    	return (self :: any) :: VirtualList
    end
    
    function VirtualList:UpdateData(nodes: { TreeState.Node })
    	self.RenderedNodes = nodes
    	local totalHeight = #nodes * self.RowHeight
    	self.ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    	self:UpdateView()
    end
    
    function VirtualList:UpdateView()
    	local nodes = self.RenderedNodes
    	local total = #nodes
    	local offsetY = self.ScrollingFrame.CanvasPosition.Y
    	local startIndex = math.clamp(math.floor(offsetY / self.RowHeight) + 1, 1, math.max(1, total))
    
    	for poolIndex = 1, self.VisibleRowCount do
    		local row = self.RowPool[poolIndex]
    		local itemIndex = startIndex + poolIndex - 1
    
    		if itemIndex <= total then
    			local node = nodes[itemIndex]
    			local inst = node.Instance
    
    			row.Position = UDim2.new(0, 0, 0, (itemIndex - 1) * self.RowHeight)
    			row.Visible = true
    
    			local isSelected = self.TreeState.SelectedInstances[inst] == true
    			row.BackgroundTransparency = isSelected and 0 or 1
    			row.BackgroundColor3 = isSelected and Theme.BgSelected or Theme.BgHover
    
    			local indent = node.Depth * 16
    			local arrow = row:FindFirstChild("Arrow") :: TextButton?
    			local icon = row:FindFirstChild("Icon") :: ImageLabel?
    			local nameLabel = row:FindFirstChild("ItemName") :: TextLabel?
    			local rowBtn = row:FindFirstChild("RowBtn") :: TextButton?
    
    			if arrow then
    				arrow.Position = UDim2.new(0, indent + 4, 0.5, -8)
    				arrow.Visible = node.HasChildren
    				arrow.Text = node.Expanded and Icons.EXPAND_ARROW or Icons.COLLAPSE_ARROW
    			end
    
    			if icon then
    				icon.Position = UDim2.new(0, indent + 22, 0.5, -8)
    				icon.Image = Icons.GetClassIcon(inst.ClassName)
    			end
    
    			if nameLabel then
    				nameLabel.Position = UDim2.new(0, indent + 44, 0, 0)
    				nameLabel.Size = UDim2.new(1, -(indent + 48), 1, 0)
    				nameLabel.Text = inst.Name
    			end
    
    			-- Bind click actions
    			if arrow then
    				arrow.MouseButton1Click:Connect(function()
    					self.TreeState:ToggleExpand(node)
    				end)
    			end
    
    			if rowBtn then
    				rowBtn.MouseButton1Click:Connect(function()
    					self.TreeState:Select(inst, false)
    				end)
    			end
    		else
    			row.Visible = false
    		end
    	end
    end
    
    function VirtualList:Destroy()
    	self.ScrollingFrame:Destroy()
    end
    
    return VirtualList
end

-- Module: PropertiesView
__modules["PropertiesView"] = function()
    -- [PropertiesView.luau]
    -- Real-time interactive Property Inspector with category collapsing and type editors
    
    local Theme = __require("Theme")
    local ReflectionEngine = __require("ReflectionEngine")
    local Serializers = __require("Serializers")
    
    export type PropertiesView = {
    	Container: Frame,
    	CurrentTarget: Instance?,
    	SetTarget: (self: PropertiesView, inst: Instance?) -> (),
    	Refresh: (self: PropertiesView) -> (),
    	Destroy: (self: PropertiesView) -> (),
    }
    
    local PropertiesView = {}
    PropertiesView.__index = PropertiesView
    
    function PropertiesView.new(parentFrame: Frame): PropertiesView
    	local container = Instance.new("Frame")
    	container.Name = "PropertiesContainer"
    	container.Size = UDim2.fromScale(1, 1)
    	container.BackgroundTransparency = 1
    	container.Parent = parentFrame
    
    	-- Header search / filter
    	local searchBox = Instance.new("TextBox")
    	searchBox.Name = "PropSearch"
    	searchBox.Size = UDim2.new(1, -16, 0, 26)
    	searchBox.Position = UDim2.fromOffset(8, 6)
    	searchBox.BackgroundColor3 = Theme.BgElevated
    	searchBox.TextColor3 = Theme.TextPrimary
    	searchBox.PlaceholderText = "Search Properties..."
    	searchBox.PlaceholderColor3 = Theme.TextMuted
    	searchBox.TextSize = Theme.FontSize
    	searchBox.Font = Enum.Font.SourceSans
    	searchBox.ClearTextOnFocus = false
    	searchBox.Parent = container
    
    	local searchCorner = Instance.new("UICorner")
    	searchCorner.CornerRadius = UDim.new(0, Theme.CornerRadiusSmall)
    	searchCorner.Parent = searchBox
    
    	local listScroll = Instance.new("ScrollingFrame")
    	listScroll.Name = "PropsScroll"
    	listScroll.Size = UDim2.new(1, 0, 1, -38)
    	listScroll.Position = UDim2.fromOffset(0, 38)
    	listScroll.BackgroundTransparency = 1
    	listScroll.BorderSizePixel = 0
    	listScroll.ScrollBarThickness = 5
    	listScroll.ScrollBarImageColor3 = Theme.BorderStrong
    	listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    	listScroll.Parent = container
    
    	local listLayout = Instance.new("UIListLayout")
    	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	listLayout.Padding = UDim.new(0, 1)
    	listLayout.Parent = listScroll
    
    	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    		listScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
    	end)
    
    	local self = setmetatable({
    		Container = container,
    		CurrentTarget = nil,
    		_scroll = listScroll,
    		_search = searchBox,
    	}, PropertiesView)
    
    	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    		self:Refresh()
    	end)
    
    	return (self :: any) :: PropertiesView
    end
    
    function PropertiesView:SetTarget(inst: Instance?)
    	self.CurrentTarget = inst
    	self:Refresh()
    end
    
    function PropertiesView:Refresh()
    	local scroll = self._scroll
    	local filter = string.lower(self._search.Text)
    
    	-- Clear current rows
    	for _, child in ipairs(scroll:GetChildren()) do
    		if child:IsA("Frame") then
    			child:Destroy()
    		end
    	end
    
    	local target = self.CurrentTarget
    	if not target then
    		local emptyLabel = Instance.new("TextLabel")
    		emptyLabel.Size = UDim2.new(1, 0, 0, 40)
    		emptyLabel.BackgroundTransparency = 1
    		emptyLabel.TextColor3 = Theme.TextMuted
    		emptyLabel.TextSize = Theme.FontSize
    		emptyLabel.Font = Enum.Font.SourceSansItalic
    		emptyLabel.Text = "No Instance Selected"
    		emptyLabel.Parent = scroll
    		return
    	end
    
    	local props = ReflectionEngine.GetProperties(target)
    	local currentCategory = ""
    	local rowOrder = 1
    
    	for _, prop in ipairs(props) do
    		if filter ~= "" and not string.find(string.lower(prop.Name), filter, 1, true) then
    			continue
    		end
    
    		-- Category header
    		if prop.Category ~= currentCategory then
    			currentCategory = prop.Category
    			local catHeader = Instance.new("Frame")
    			catHeader.Name = `Cat_{currentCategory}`
    			catHeader.Size = UDim2.new(1, 0, 0, 20)
    			catHeader.BackgroundColor3 = Theme.BgElevated
    			catHeader.BorderSizePixel = 0
    			catHeader.LayoutOrder = rowOrder
    			rowOrder += 1
    			catHeader.Parent = scroll
    
    			local catLabel = Instance.new("TextLabel")
    			catLabel.Size = UDim2.new(1, -10, 1, 0)
    			catLabel.Position = UDim2.fromOffset(10, 0)
    			catLabel.BackgroundTransparency = 1
    			catLabel.TextColor3 = Theme.Accent
    			catLabel.TextSize = 11
    			catLabel.Font = Enum.Font.SourceSansBold
    			catLabel.TextXAlignment = Enum.TextXAlignment.Left
    			catLabel.Text = string.upper(currentCategory)
    			catLabel.Parent = catHeader
    		end
    
    		-- Property row
    		local row = Instance.new("Frame")
    		row.Name = `Prop_{prop.Name}`
    		row.Size = UDim2.new(1, 0, 0, 24)
    		row.BackgroundColor3 = Theme.BgSurface
    		row.BorderSizePixel = 0
    		row.LayoutOrder = rowOrder
    		rowOrder += 1
    		row.Parent = scroll
    
    		-- Name
    		local nameLabel = Instance.new("TextLabel")
    		nameLabel.Size = UDim2.new(0.45, -10, 1, 0)
    		nameLabel.Position = UDim2.fromOffset(10, 0)
    		nameLabel.BackgroundTransparency = 1
    		nameLabel.TextColor3 = prop.IsReadOnly and Theme.TextMuted or Theme.TextPrimary
    		nameLabel.TextSize = Theme.FontSize
    		nameLabel.Font = Enum.Font.SourceSans
    		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    		nameLabel.Text = prop.Name
    		nameLabel.Parent = row
    
    		-- Value box (Editable)
    		local valBox = Instance.new("TextBox")
    		valBox.Size = UDim2.new(0.55, -10, 1, -4)
    		valBox.Position = UDim2.new(0.45, 0, 0, 2)
    		valBox.BackgroundColor3 = Theme.BgElevated
    		valBox.TextColor3 = prop.IsReadOnly and Theme.TextMuted or Theme.TextPrimary
    		valBox.TextSize = Theme.FontSize
    		valBox.Font = Enum.Font.SourceSans
    		valBox.TextXAlignment = Enum.TextXAlignment.Left
    		valBox.TextTruncate = Enum.TextTruncate.AtEnd
    		valBox.ClearTextOnFocus = false
    		valBox.Text = Serializers.FormatValue(prop.Value, prop.Type)
    		valBox.TextEditable = not prop.IsReadOnly
    		valBox.Parent = row
    
    		local boxCorner = Instance.new("UICorner")
    		boxCorner.CornerRadius = UDim.new(0, 3)
    		boxCorner.Parent = valBox
    
    		if not prop.IsReadOnly then
    			valBox.FocusLost:Connect(function(enterPressed)
    				if enterPressed then
    					local ok, err = ReflectionEngine.SetProperty(target, prop.Name, valBox.Text, prop.Type)
    					if not ok then
    						valBox.TextColor3 = Theme.AccentDanger
    						task.delay(1, function()
    							valBox.TextColor3 = Theme.TextPrimary
    							local currentVal = pcall(function()
    								return (target :: any)[prop.Name]
    							end)
    							valBox.Text = Serializers.FormatValue(currentVal, prop.Type)
    						end)
    					else
    						valBox.TextColor3 = Theme.AccentSuccess
    						task.delay(0.5, function()
    							valBox.TextColor3 = Theme.TextPrimary
    						end)
    					end
    				end
    			end)
    		end
    	end
    end
    
    function PropertiesView:Destroy()
    	self.Container:Destroy()
    end
    
    return PropertiesView
end

-- Module: RemoteSpy
__modules["RemoteSpy"] = function()
    -- [RemoteSpy.luau]
    -- Network traffic logger, parameter inspector, and code generator for AethelDex
    
    local Theme = __require("Theme")
    local Serializers = __require("Serializers")
    
    export type LogEntry = {
    	Id: number,
    	Time: string,
    	Remote: Instance,
    	Type: string,
    	Args: { any },
    }
    
    export type RemoteSpy = {
    	Container: Frame,
    	Logs: { LogEntry },
    	IsActive: boolean,
    	Start: (self: RemoteSpy) -> (),
    	Stop: (self: RemoteSpy) -> (),
    	Clear: (self: RemoteSpy) -> (),
    	Destroy: (self: RemoteSpy) -> (),
    }
    
    local RemoteSpy = {}
    RemoteSpy.__index = RemoteSpy
    
    function RemoteSpy.new(parentFrame: Frame): RemoteSpy
    	local container = Instance.new("Frame")
    	container.Name = "RemoteSpyContainer"
    	container.Size = UDim2.fromScale(1, 1)
    	container.BackgroundTransparency = 1
    	container.Parent = parentFrame
    
    	-- Toolbar
    	local toolbar = Instance.new("Frame")
    	toolbar.Name = "Toolbar"
    	toolbar.Size = UDim2.new(1, 0, 0, 32)
    	toolbar.BackgroundColor3 = Theme.BgElevated
    	toolbar.BorderSizePixel = 0
    	toolbar.Parent = container
    
    	local toggleBtn = Instance.new("TextButton")
    	toggleBtn.Name = "ToggleBtn"
    	toggleBtn.Size = UDim2.fromOffset(80, 24)
    	toggleBtn.Position = UDim2.fromOffset(8, 4)
    	toggleBtn.BackgroundColor3 = Theme.AccentSuccess
    	toggleBtn.TextColor3 = Color3.new(1, 1, 1)
    	toggleBtn.TextSize = 12
    	toggleBtn.Font = Enum.Font.SourceSansBold
    	toggleBtn.Text = "Running"
    	toggleBtn.Parent = toolbar
    
    	local toggleCorner = Instance.new("UICorner")
    	toggleCorner.CornerRadius = UDim.new(0, Theme.CornerRadiusSmall)
    	toggleCorner.Parent = toggleBtn
    
    	local clearBtn = Instance.new("TextButton")
    	clearBtn.Name = "ClearBtn"
    	clearBtn.Size = UDim2.fromOffset(60, 24)
    	clearBtn.Position = UDim2.fromOffset(96, 4)
    	clearBtn.BackgroundColor3 = Theme.BgSurface
    	clearBtn.TextColor3 = Theme.TextSecondary
    	clearBtn.TextSize = 12
    	clearBtn.Font = Enum.Font.SourceSans
    	clearBtn.Text = "Clear"
    	clearBtn.Parent = toolbar
    
    	local clearCorner = Instance.new("UICorner")
    	clearCorner.CornerRadius = UDim.new(0, Theme.CornerRadiusSmall)
    	clearCorner.Parent = clearBtn
    
    	-- Logs scroll
    	local logScroll = Instance.new("ScrollingFrame")
    	logScroll.Name = "LogScroll"
    	logScroll.Size = UDim2.new(1, 0, 1, -34)
    	logScroll.Position = UDim2.fromOffset(0, 34)
    	logScroll.BackgroundTransparency = 1
    	logScroll.BorderSizePixel = 0
    	logScroll.ScrollBarThickness = 5
    	logScroll.ScrollBarImageColor3 = Theme.BorderStrong
    	logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    	logScroll.Parent = container
    
    	local logLayout = Instance.new("UIListLayout")
    	logLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	logLayout.Padding = UDim.new(0, 2)
    	logLayout.Parent = logScroll
    
    	logLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    		logScroll.CanvasSize = UDim2.new(0, 0, 0, logLayout.AbsoluteContentSize.Y + 10)
    	end)
    
    	local self = setmetatable({
    		Container = container,
    		Logs = {} :: { LogEntry },
    		IsActive = true,
    		_scroll = logScroll,
    		_toggleBtn = toggleBtn,
    		_counter = 0,
    	}, RemoteSpy)
    
    	toggleBtn.MouseButton1Click:Connect(function()
    		if self.IsActive then
    			self:Stop()
    		else
    			self:Start()
    		end
    	end)
    
    	clearBtn.MouseButton1Click:Connect(function()
    		self:Clear()
    	end)
    
    	-- Automatically attach network hooks
    	self:HookNetwork()
    
    	return (self :: any) :: RemoteSpy
    end
    
    function RemoteSpy:HookNetwork()
    	local hookmetamethod = (rawget(getfenv(), "hookmetamethod") :: any)
    	local checkcaller = (rawget(getfenv(), "checkcaller") :: any)
    
    	if typeof(hookmetamethod) == "function" and typeof(checkcaller) == "function" then
    		local oldNamecall: any
    		oldNamecall = hookmetamethod(game, "__namecall", function(selfRemote, ...)
    			local method = getnamecallmethod()
    			if not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
    				if typeof(selfRemote) == "Instance" and (selfRemote:IsA("RemoteEvent") or selfRemote:IsA("RemoteFunction")) then
    					local args = { ... }
    					task.defer(function()
    						self:AddLog(selfRemote, method, args)
    					end)
    				end
    			end
    			return oldNamecall(selfRemote, ...)
    		end)
    	end
    end
    
    function RemoteSpy:AddLog(remote: Instance, method: string, args: { any })
    	if not self.IsActive then
    		return
    	end
    
    	self._counter += 1
    	local entry: LogEntry = {
    		Id = self._counter,
    		Time = os.date("%X"),
    		Remote = remote,
    		Type = remote.ClassName,
    		Args = args,
    	}
    
    	table.insert(self.Logs, entry)
    
    	-- Render log item
    	local row = Instance.new("Frame")
    	row.Name = `Log_{entry.Id}`
    	row.Size = UDim2.new(1, -8, 0, 28)
    	row.Position = UDim2.fromOffset(4, 0)
    	row.BackgroundColor3 = Theme.BgElevated
    	row.BorderSizePixel = 0
    	row.Parent = self._scroll
    
    	local rowCorner = Instance.new("UICorner")
    	rowCorner.CornerRadius = UDim.new(0, Theme.CornerRadiusSmall)
    	rowCorner.Parent = row
    
    	local titleLabel = Instance.new("TextLabel")
    	titleLabel.Size = UDim2.new(0.7, -10, 1, 0)
    	titleLabel.Position = UDim2.fromOffset(8, 0)
    	titleLabel.BackgroundTransparency = 1
    	titleLabel.TextColor3 = Theme.TextPrimary
    	titleLabel.TextSize = Theme.FontSize
    	titleLabel.Font = Enum.Font.SourceSans
    	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    	titleLabel.Text = `[{entry.Time}] {remote.Name} ({#args} args)`
    	titleLabel.Parent = row
    
    	local copyBtn = Instance.new("TextButton")
    	copyBtn.Size = UDim2.fromOffset(70, 20)
    	copyBtn.Position = UDim2.new(1, -78, 0.5, -10)
    	copyBtn.BackgroundColor3 = Theme.Accent
    	copyBtn.TextColor3 = Color3.new(1, 1, 1)
    	copyBtn.TextSize = 11
    	copyBtn.Font = Enum.Font.SourceSansBold
    	copyBtn.Text = "Copy Call"
    	copyBtn.Parent = row
    
    	local btnCorner = Instance.new("UICorner")
    	btnCorner.CornerRadius = UDim.new(0, 3)
    	btnCorner.Parent = copyBtn
    
    	copyBtn.MouseButton1Click:Connect(function()
    		local code = self:GenerateScript(remote, method, args)
    		local setclipboard = (rawget(getfenv(), "setclipboard") :: any)
    		if typeof(setclipboard) == "function" then
    			setclipboard(code)
    			copyBtn.Text = "Copied!"
    			task.delay(1, function()
    				copyBtn.Text = "Copy Call"
    			end)
    		end
    	end)
    end
    
    function RemoteSpy:GenerateScript(remote: Instance, method: string, args: { any }): string
    	local fullPath = remote:GetFullName()
    	local formattedArgs = {}
    	for _, arg in ipairs(args) do
    		table.insert(formattedArgs, Serializers.FormatValue(arg))
    	end
    	return string.format("%s:%s(%s)", fullPath, method, table.concat(formattedArgs, ", "))
    end
    
    function RemoteSpy:Start()
    	self.IsActive = true
    	self._toggleBtn.BackgroundColor3 = Theme.AccentSuccess
    	self._toggleBtn.Text = "Running"
    end
    
    function RemoteSpy:Stop()
    	self.IsActive = false
    	self._toggleBtn.BackgroundColor3 = Theme.AccentWarning
    	self._toggleBtn.Text = "Paused"
    end
    
    function RemoteSpy:Clear()
    	table.clear(self.Logs)
    	for _, child in ipairs(self._scroll:GetChildren()) do
    		if child:IsA("Frame") then
    			child:Destroy()
    		end
    	end
    end
    
    function RemoteSpy:Destroy()
    	self.Container:Destroy()
    end
    
    return RemoteSpy
end

-- Module: ScriptViewer
__modules["ScriptViewer"] = function()
    -- [ScriptViewer.luau]
    -- In-game Luau script viewer with decompiler integration and syntax highlighting
    
    local Theme = __require("Theme")
    
    export type ScriptViewer = {
    	Container: Frame,
    	ViewScript: (self: ScriptViewer, scriptInst: Instance) -> (),
    	Destroy: (self: ScriptViewer) -> (),
    }
    
    local ScriptViewer = {}
    ScriptViewer.__index = ScriptViewer
    
    function ScriptViewer.new(parentFrame: Frame): ScriptViewer
    	local container = Instance.new("Frame")
    	container.Name = "ScriptViewerContainer"
    	container.Size = UDim2.fromScale(1, 1)
    	container.BackgroundTransparency = 1
    	container.Parent = parentFrame
    
    	-- Top bar
    	local topBar = Instance.new("Frame")
    	topBar.Name = "TopBar"
    	topBar.Size = UDim2.new(1, 0, 0, 32)
    	topBar.BackgroundColor3 = Theme.BgElevated
    	topBar.BorderSizePixel = 0
    	topBar.Parent = container
    
    	local title = Instance.new("TextLabel")
    	title.Name = "ScriptTitle"
    	title.Size = UDim2.new(1, -120, 1, 0)
    	title.Position = UDim2.fromOffset(10, 0)
    	title.BackgroundTransparency = 1
    	title.TextColor3 = Theme.TextPrimary
    	title.TextSize = Theme.FontSize
    	title.Font = Enum.Font.SourceSansBold
    	title.TextXAlignment = Enum.TextXAlignment.Left
    	title.Text = "No script selected"
    	title.Parent = topBar
    
    	local copyBtn = Instance.new("TextButton")
    	copyBtn.Name = "CopyBtn"
    	copyBtn.Size = UDim2.fromOffset(80, 24)
    	copyBtn.Position = UDim2.new(1, -90, 0.5, -12)
    	copyBtn.BackgroundColor3 = Theme.Accent
    	copyBtn.TextColor3 = Color3.new(1, 1, 1)
    	copyBtn.TextSize = 12
    	copyBtn.Font = Enum.Font.SourceSansBold
    	copyBtn.Text = "Copy Code"
    	copyBtn.Parent = topBar
    
    	local btnCorner = Instance.new("UICorner")
    	btnCorner.CornerRadius = UDim.new(0, Theme.CornerRadiusSmall)
    	btnCorner.Parent = copyBtn
    
    	-- Code Scroll Area
    	local codeScroll = Instance.new("ScrollingFrame")
    	codeScroll.Name = "CodeScroll"
    	codeScroll.Size = UDim2.new(1, 0, 1, -34)
    	codeScroll.Position = UDim2.fromOffset(0, 34)
    	codeScroll.BackgroundColor3 = Theme.BgBase
    	codeScroll.BorderSizePixel = 0
    	codeScroll.ScrollBarThickness = 6
    	codeScroll.ScrollBarImageColor3 = Theme.BorderStrong
    	codeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    	codeScroll.Parent = container
    
    	local codeLabel = Instance.new("TextLabel")
    	codeLabel.Name = "CodeContent"
    	codeLabel.Size = UDim2.new(1, -16, 1, -10)
    	codeLabel.Position = UDim2.fromOffset(8, 5)
    	codeLabel.BackgroundTransparency = 1
    	codeLabel.TextColor3 = Theme.TextPrimary
    	codeLabel.TextSize = 12
    	codeLabel.Font = Enum.Font.Code
    	codeLabel.TextXAlignment = Enum.TextXAlignment.Left
    	codeLabel.TextYAlignment = Enum.TextYAlignment.Top
    	codeLabel.Text = "-- Select a script to view bytecode or decompiled source"
    	codeLabel.RichText = true
    	codeLabel.Parent = codeScroll
    
    	local self = setmetatable({
    		Container = container,
    		_title = title,
    		_codeLabel = codeLabel,
    		_codeScroll = codeScroll,
    		_currentCode = "",
    	}, ScriptViewer)
    
    	copyBtn.MouseButton1Click:Connect(function()
    		local setclipboard = (rawget(getfenv(), "setclipboard") :: any)
    		if typeof(setclipboard) == "function" and self._currentCode ~= "" then
    			setclipboard(self._currentCode)
    			copyBtn.Text = "Copied!"
    			task.delay(1, function()
    				copyBtn.Text = "Copy Code"
    			end)
    		end
    	end)
    
    	return (self :: any) :: ScriptViewer
    end
    
    function ScriptViewer:ViewScript(scriptInst: Instance)
    	self._title.Text = `Viewing: {scriptInst.Name} [{scriptInst.ClassName}]`
    	self._codeLabel.Text = "Decompiling / Fetching source, please wait..."
    
    	task.spawn(function()
    		local source = ""
    		local decompile = (rawget(getfenv(), "decompile") :: any)
    
    		if typeof(decompile) == "function" then
    			local ok, res = pcall(decompile, scriptInst)
    			if ok and typeof(res) == "string" then
    				source = res
    			else
    				source = `-- Decompile failed: {tostring(res)}`
    			end
    		else
    			-- Try reading .Source property (works in Studio / privileged environments)
    			local ok, res = pcall(function()
    				return (scriptInst :: any).Source
    			end)
    			if ok and typeof(res) == "string" then
    				source = res
    			else
    				source = "-- [Notice] Decompiler is not available in current environment and .Source is protected."
    			end
    		end
    
    		self._currentCode = source
    
    		-- Basic Luau syntax highlighter via RichText
    		local highlighted = source
    		highlighted = string.gsub(highlighted, "&", "&amp;")
    		highlighted = string.gsub(highlighted, "<", "&lt;")
    		highlighted = string.gsub(highlighted, ">", "&gt;")
    
    		-- Highlight keywords
    		local keywords = { "local", "function", "return", "if", "then", "else", "elseif", "end", "for", "in", "do", "while", "repeat", "until" }
    		for _, kw in ipairs(keywords) do
    			highlighted = string.gsub(highlighted, "%f[%a]" .. kw .. "%f[%A]", `<font color="#4f75ff"><b>{kw}</b></font>`)
    		end
    
    		-- Highlight comments
    		highlighted = string.gsub(highlighted, "(%-%-[^\n]*)", `<font color="#737887"><i>%1</i></font>`)
    
    		self._codeLabel.Text = highlighted
    
    		-- Adjust scroll height based on line count
    		local lines = select(2, string.gsub(source, "\n", "\n")) + 1
    		self._codeScroll.CanvasSize = UDim2.new(0, 0, 0, lines * 15 + 30)
    	end)
    end
    
    function ScriptViewer:Destroy()
    	self.Container:Destroy()
    end
    
    return ScriptViewer
end

-- Module: NilScanner
__modules["NilScanner"] = function()
    -- [NilScanner.luau]
    -- Orphaned / nil-parented instance inspector and recovery manager for AethelDex
    
    local Theme = __require("Theme")
    local Icons = __require("Icons")
    
    export type NilScanner = {
    	Container: Frame,
    	Scan: (self: NilScanner) -> (),
    	Destroy: (self: NilScanner) -> (),
    }
    
    local NilScanner = {}
    NilScanner.__index = NilScanner
    
    function NilScanner.new(parentFrame: Frame): NilScanner
    	local container = Instance.new("Frame")
    	container.Name = "NilScannerContainer"
    	container.Size = UDim2.fromScale(1, 1)
    	container.BackgroundTransparency = 1
    	container.Parent = parentFrame
    
    	-- Toolbar
    	local toolbar = Instance.new("Frame")
    	toolbar.Name = "Toolbar"
    	toolbar.Size = UDim2.new(1, 0, 0, 32)
    	toolbar.BackgroundColor3 = Theme.BgElevated
    	toolbar.BorderSizePixel = 0
    	toolbar.Parent = container
    
    	local scanBtn = Instance.new("TextButton")
    	scanBtn.Name = "ScanBtn"
    	scanBtn.Size = UDim2.fromOffset(100, 24)
    	scanBtn.Position = UDim2.fromOffset(8, 4)
    	scanBtn.BackgroundColor3 = Theme.Accent
    	scanBtn.TextColor3 = Color3.new(1, 1, 1)
    	scanBtn.TextSize = 12
    	scanBtn.Font = Enum.Font.SourceSansBold
    	scanBtn.Text = "Scan Nil"
    	scanBtn.Parent = toolbar
    
    	local scanCorner = Instance.new("UICorner")
    	scanCorner.CornerRadius = UDim.new(0, Theme.CornerRadiusSmall)
    	scanCorner.Parent = scanBtn
    
    	-- List scroll
    	local scroll = Instance.new("ScrollingFrame")
    	scroll.Name = "NilScroll"
    	scroll.Size = UDim2.new(1, 0, 1, -34)
    	scroll.Position = UDim2.fromOffset(0, 34)
    	scroll.BackgroundTransparency = 1
    	scroll.BorderSizePixel = 0
    	scroll.ScrollBarThickness = 5
    	scroll.ScrollBarImageColor3 = Theme.BorderStrong
    	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    	scroll.Parent = container
    
    	local layout = Instance.new("UIListLayout")
    	layout.SortOrder = Enum.SortOrder.LayoutOrder
    	layout.Padding = UDim.new(0, 2)
    	layout.Parent = scroll
    
    	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    	end)
    
    	local self = setmetatable({
    		Container = container,
    		_scroll = scroll,
    		_scanBtn = scanBtn,
    	}, NilScanner)
    
    	scanBtn.MouseButton1Click:Connect(function()
    		self:Scan()
    	end)
    
    	return (self :: any) :: NilScanner
    end
    
    function NilScanner:Scan()
    	local scroll = self._scroll
    	for _, child in ipairs(scroll:GetChildren()) do
    		if child:IsA("Frame") then
    			child:Destroy()
    		end
    	end
    
    	local nilList: { Instance } = {}
    	local getnilinstances = (rawget(getfenv(), "getnilinstances") :: any) or (rawget(getfenv(), "get_nil_instances") :: any)
    
    	if typeof(getnilinstances) == "function" then
    		local ok, res = pcall(getnilinstances)
    		if ok and typeof(res) == "table" then
    			nilList = res
    		end
    	end
    
    	if #nilList == 0 then
    		local emptyLabel = Instance.new("TextLabel")
    		emptyLabel.Size = UDim2.new(1, 0, 0, 40)
    		emptyLabel.BackgroundTransparency = 1
    		emptyLabel.TextColor3 = Theme.TextMuted
    		emptyLabel.TextSize = Theme.FontSize
    		emptyLabel.Font = Enum.Font.SourceSansItalic
    		emptyLabel.Text = "No nil instances found (or getnilinstances is not supported)"
    		emptyLabel.Parent = scroll
    		return
    	end
    
    	for i, inst in ipairs(nilList) do
    		local row = Instance.new("Frame")
    		row.Name = `Nil_{i}`
    		row.Size = UDim2.new(1, -8, 0, 26)
    		row.Position = UDim2.fromOffset(4, 0)
    		row.BackgroundColor3 = Theme.BgElevated
    		row.BorderSizePixel = 0
    		row.Parent = scroll
    
    		local rowCorner = Instance.new("UICorner")
    		rowCorner.CornerRadius = UDim.new(0, Theme.CornerRadiusSmall)
    		rowCorner.Parent = row
    
    		local nameLabel = Instance.new("TextLabel")
    		nameLabel.Size = UDim2.new(1, -120, 1, 0)
    		nameLabel.Position = UDim2.fromOffset(8, 0)
    		nameLabel.BackgroundTransparency = 1
    		nameLabel.TextColor3 = Theme.TextPrimary
    		nameLabel.TextSize = Theme.FontSize
    		nameLabel.Font = Enum.Font.SourceSans
    		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    		nameLabel.Text = `{inst.Name} [{inst.ClassName}]`
    		nameLabel.Parent = row
    
    		local restoreBtn = Instance.new("TextButton")
    		restoreBtn.Size = UDim2.fromOffset(90, 20)
    		restoreBtn.Position = UDim2.new(1, -98, 0.5, -10)
    		restoreBtn.BackgroundColor3 = Theme.AccentSuccess
    		restoreBtn.TextColor3 = Color3.new(1, 1, 1)
    		restoreBtn.TextSize = 11
    		restoreBtn.Font = Enum.Font.SourceSansBold
    		restoreBtn.Text = "Restore to WS"
    		restoreBtn.Parent = row
    
    		local btnCorner = Instance.new("UICorner")
    		btnCorner.CornerRadius = UDim.new(0, 3)
    		btnCorner.Parent = restoreBtn
    
    		restoreBtn.MouseButton1Click:Connect(function()
    			pcall(function()
    				inst.Parent = workspace
    			end)
    			restoreBtn.Text = "Restored!"
    		end)
    	end
    end
    
    function NilScanner:Destroy()
    	self.Container:Destroy()
    end
    
    return NilScanner
end

-- Module: CommandPalette
__modules["CommandPalette"] = function()
    -- [CommandPalette.luau]
    -- Quick Spotlight-style launcher (Ctrl+K) for instant fuzzy search & commands
    
    local UserInputService = game:GetService("UserInputService")
    local Theme = __require("Theme")
    
    export type CommandPalette = {
    	Container: Frame,
    	IsOpen: boolean,
    	Open: (self: CommandPalette) -> (),
    	Close: (self: CommandPalette) -> (),
    	Toggle: (self: CommandPalette) -> (),
    	Destroy: (self: CommandPalette) -> (),
    }
    
    local CommandPalette = {}
    CommandPalette.__index = CommandPalette
    
    function CommandPalette.new(parentGui: ScreenGui, onAction: (actionId: string, payload: any?) -> ()): CommandPalette
    	local overlay = Instance.new("Frame")
    	overlay.Name = "PaletteOverlay"
    	overlay.Size = UDim2.fromScale(1, 1)
    	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    	overlay.BackgroundTransparency = 0.5
    	overlay.Visible = false
    	overlay.ZIndex = 100000
    	overlay.Parent = parentGui
    
    	local modal = Instance.new("Frame")
    	modal.Name = "PaletteModal"
    	modal.Size = UDim2.fromOffset(480, 280)
    	modal.Position = UDim2.new(0.5, -240, 0.25, 0)
    	modal.BackgroundColor3 = Theme.BgSurface
    	modal.BorderSizePixel = 0
    	modal.Parent = overlay
    
    	local modalCorner = Instance.new("UICorner")
    	modalCorner.CornerRadius = UDim.new(0, Theme.CornerRadius)
    	modalCorner.Parent = modal
    
    	local modalStroke = Instance.new("UIStroke")
    	modalStroke.Color = Theme.BorderStrong
    	modalStroke.Thickness = 1.5
    	modalStroke.Parent = modal
    
    	local input = Instance.new("TextBox")
    	input.Name = "PaletteInput"
    	input.Size = UDim2.new(1, -24, 0, 36)
    	input.Position = UDim2.fromOffset(12, 12)
    	input.BackgroundColor3 = Theme.BgElevated
    	input.TextColor3 = Theme.TextPrimary
    	input.PlaceholderText = "Type a command or instance name (e.g. 'workspace', 'remotes', 'nil')..."
    	input.PlaceholderColor3 = Theme.TextMuted
    	input.TextSize = 14
    	input.Font = Enum.Font.SourceSans
    	input.ClearTextOnFocus = false
    	input.Parent = modal
    
    	local inputCorner = Instance.new("UICorner")
    	inputCorner.CornerRadius = UDim.new(0, Theme.CornerRadiusSmall)
    	inputCorner.Parent = input
    
    	local listScroll = Instance.new("ScrollingFrame")
    	listScroll.Name = "ActionScroll"
    	listScroll.Size = UDim2.new(1, -24, 1, -64)
    	listScroll.Position = UDim2.fromOffset(12, 54)
    	listScroll.BackgroundTransparency = 1
    	listScroll.BorderSizePixel = 0
    	listScroll.ScrollBarThickness = 4
    	listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    	listScroll.Parent = modal
    
    	local layout = Instance.new("UIListLayout")
    	layout.SortOrder = Enum.SortOrder.LayoutOrder
    	layout.Padding = UDim.new(0, 4)
    	layout.Parent = listScroll
    
    	local self = setmetatable({
    		Container = overlay,
    		IsOpen = false,
    		_modal = modal,
    		_input = input,
    		_scroll = listScroll,
    		_onAction = onAction,
    	}, CommandPalette)
    
    	-- Keybinding: Ctrl+K or Cmd+K
    	UserInputService.InputBegan:Connect(function(inp, gpe)
    		if gpe then
    			return
    		end
    		if inp.KeyCode == Enum.KeyCode.K and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
    			self:Toggle()
    		elseif inp.KeyCode == Enum.KeyCode.Escape and self.IsOpen then
    			self:Close()
    		end
    	end)
    
    	self:PopulateStandardCommands()
    
    	return (self :: any) :: CommandPalette
    end
    
    function CommandPalette:PopulateStandardCommands()
    	local commands = {
    		{ Id = "tab:explorer", Name = "Explorer: Focus DataModel Tree", Hint = "Jump to tree" },
    		{ Id = "tab:properties", Name = "Properties: Inspect Selected", Hint = "View properties" },
    		{ Id = "tab:remotes", Name = "Remote Spy: Monitor Network", Hint = "Inspect remotes" },
    		{ Id = "tab:scriptviewer", Name = "Script Viewer: Open Decompiler", Hint = "View scripts" },
    		{ Id = "tab:nil", Name = "Nil Scanner: Find Hidden Instances", Hint = "Inspect nil" },
    		{ Id = "action:toggle_mobile", Name = "Toggle Touch Mode", Hint = "Mobile layout" },
    	}
    
    	for i, cmd in ipairs(commands) do
    		local btn = Instance.new("TextButton")
    		btn.Name = `Cmd_{cmd.Id}`
    		btn.Size = UDim2.new(1, 0, 0, 30)
    		btn.BackgroundColor3 = Theme.BgElevated
    		btn.AutoButtonColor = false
    		btn.Text = ""
    		btn.Parent = self._scroll
    
    		local corner = Instance.new("UICorner")
    		corner.CornerRadius = UDim.new(0, Theme.CornerRadiusSmall)
    		corner.Parent = btn
    
    		local label = Instance.new("TextLabel")
    		label.Size = UDim2.new(0.7, 0, 1, 0)
    		label.Position = UDim2.fromOffset(8, 0)
    		label.BackgroundTransparency = 1
    		label.TextColor3 = Theme.TextPrimary
    		label.TextSize = Theme.FontSize
    		label.Font = Enum.Font.SourceSans
    		label.TextXAlignment = Enum.TextXAlignment.Left
    		label.Text = cmd.Name
    		label.Parent = btn
    
    		local hint = Instance.new("TextLabel")
    		hint.Size = UDim2.new(0.3, -16, 1, 0)
    		hint.Position = UDim2.new(0.7, 0, 0, 0)
    		hint.BackgroundTransparency = 1
    		hint.TextColor3 = Theme.TextMuted
    		hint.TextSize = 11
    		hint.Font = Enum.Font.SourceSansItalic
    		hint.TextXAlignment = Enum.TextXAlignment.Right
    		hint.Text = cmd.Hint
    		hint.Parent = btn
    
    		btn.MouseButton1Click:Connect(function()
    			self:Close()
    			self._onAction(cmd.Id)
    		end)
    	end
    
    	self._scroll.CanvasSize = UDim2.new(0, 0, 0, #commands * 34)
    end
    
    function CommandPalette:Open()
    	self.IsOpen = true
    	self.Container.Visible = true
    	self._input:CaptureFocus()
    end
    
    function CommandPalette:Close()
    	self.IsOpen = false
    	self.Container.Visible = false
    	self._input:ReleaseFocus()
    end
    
    function CommandPalette:Toggle()
    	if self.IsOpen then
    		self:Close()
    	else
    		self:Open()
    	end
    end
    
    function CommandPalette:Destroy()
    	self.Container:Destroy()
    end
    
    return CommandPalette
end

-- Module: WindowManager
__modules["WindowManager"] = function()
    -- [WindowManager.luau]
    -- Docking window manager, tab switcher, and panel coordinator for AethelDex
    
    local UserInputService = game:GetService("UserInputService")
    local Theme = __require("Theme")
    
    export type WindowManager = {
    	RootWindow: Frame,
    	ContentArea: Frame,
    	CurrentTab: string,
    	SwitchTab: (self: WindowManager, tabId: string) -> (),
    	ToggleVisibility: (self: WindowManager) -> (),
    	Destroy: (self: WindowManager) -> (),
    }
    
    local WindowManager = {}
    WindowManager.__index = WindowManager
    
    function WindowManager.new(parentGui: ScreenGui, onTabSwitched: (tabId: string) -> ()): WindowManager
    	local window = Instance.new("Frame")
    	window.Name = "AethelDex_MainWindow"
    	window.Size = UDim2.fromOffset(680, 520)
    	window.Position = UDim2.new(0.5, -340, 0.5, -260)
    	window.BackgroundColor3 = Theme.BgBase
    	window.BorderSizePixel = 0
    	window.Active = true
    	window.Parent = parentGui
    
    	local winCorner = Instance.new("UICorner")
    	winCorner.CornerRadius = UDim.new(0, Theme.CornerRadius)
    	winCorner.Parent = window
    
    	local winStroke = Instance.new("UIStroke")
    	winStroke.Color = Theme.BorderSubtle
    	winStroke.Thickness = 1
    	winStroke.Parent = window
    
    	-- Title Bar & Drag Area
    	local titleBar = Instance.new("Frame")
    	titleBar.Name = "TitleBar"
    	titleBar.Size = UDim2.new(1, 0, 0, 36)
    	titleBar.BackgroundColor3 = Theme.BgSurface
    	titleBar.BorderSizePixel = 0
    	titleBar.Parent = window
    
    	local titleCorner = Instance.new("UICorner")
    	titleCorner.CornerRadius = UDim.new(0, Theme.CornerRadius)
    	titleCorner.Parent = titleBar
    
    	-- Title text
    	local titleLabel = Instance.new("TextLabel")
    	titleLabel.Name = "AppTitle"
    	titleLabel.Size = UDim2.fromOffset(130, 36)
    	titleLabel.Position = UDim2.fromOffset(12, 0)
    	titleLabel.BackgroundTransparency = 1
    	titleLabel.TextColor3 = Theme.Accent
    	titleLabel.TextSize = 14
    	titleLabel.Font = Enum.Font.SourceSansBold
    	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    	titleLabel.Text = "AethelDex v1.0"
    	titleLabel.Parent = titleBar
    
    	-- Tabs container
    	local tabsFrame = Instance.new("Frame")
    	tabsFrame.Name = "TabsFrame"
    	tabsFrame.Size = UDim2.new(1, -200, 1, 0)
    	tabsFrame.Position = UDim2.fromOffset(140, 0)
    	tabsFrame.BackgroundTransparency = 1
    	tabsFrame.Parent = titleBar
    
    	local tabLayout = Instance.new("UIListLayout")
    	tabLayout.FillDirection = Enum.FillDirection.Horizontal
    	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	tabLayout.Padding = UDim.new(0, 4)
    	tabLayout.Parent = tabsFrame
    
    	-- Close button
    	local closeBtn = Instance.new("TextButton")
    	closeBtn.Name = "CloseBtn"
    	closeBtn.Size = UDim2.fromOffset(36, 36)
    	closeBtn.Position = UDim2.new(1, -36, 0, 0)
    	closeBtn.BackgroundTransparency = 1
    	closeBtn.TextColor3 = Theme.TextMuted
    	closeBtn.TextSize = 14
    	closeBtn.Font = Enum.Font.SourceSansBold
    	closeBtn.Text = "вњ•"
    	closeBtn.Parent = titleBar
    
    	-- Content Area
    	local contentArea = Instance.new("Frame")
    	contentArea.Name = "ContentArea"
    	contentArea.Size = UDim2.new(1, 0, 1, -36)
    	contentArea.Position = UDim2.fromOffset(0, 36)
    	contentArea.BackgroundTransparency = 1
    	contentArea.Parent = window
    
    	local self = setmetatable({
    		RootWindow = window,
    		ContentArea = contentArea,
    		CurrentTab = "explorer",
    		_tabButtons = {} :: { [string]: TextButton },
    		_onTabSwitched = onTabSwitched,
    	}, WindowManager)
    
    	-- Dragging mechanics
    	local dragging = false
    	local dragStart: Vector2
    	local startPos: UDim2
    
    	titleBar.InputBegan:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    			dragging = true
    			dragStart = input.Position
    			startPos = window.Position
    
    			input.Changed:Connect(function()
    				if input.UserInputState == Enum.UserInputState.End then
    					dragging = false
    				end
    			end)
    		end
    	end)
    
    	UserInputService.InputChanged:Connect(function(input)
    		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
    			local delta = input.Position - dragStart
    			window.Position = UDim2.new(
    				startPos.X.Scale,
    				startPos.X.Offset + delta.X,
    				startPos.Y.Scale,
    				startPos.Y.Offset + delta.Y
    			)
    		end
    	end)
    
    	closeBtn.MouseButton1Click:Connect(function()
    		self:ToggleVisibility()
    	end)
    
    	-- Define Tabs
    	local tabDefs = {
    		{ Id = "explorer", Name = "Explorer" },
    		{ Id = "properties", Name = "Properties" },
    		{ Id = "remotes", Name = "Remote Spy" },
    		{ Id = "scriptviewer", Name = "Script Viewer" },
    		{ Id = "nil", Name = "Nil Scanner" },
    	}
    
    	for _, def in ipairs(tabDefs) do
    		local btn = Instance.new("TextButton")
    		btn.Name = `Tab_{def.Id}`
    		btn.Size = UDim2.fromOffset(80, 26)
    		btn.Position = UDim2.fromOffset(0, 5)
    		btn.BackgroundColor3 = Theme.BgElevated
    		btn.BackgroundTransparency = (def.Id == "explorer") and 0 or 1
    		btn.TextColor3 = (def.Id == "explorer") and Theme.Accent or Theme.TextSecondary
    		btn.TextSize = 12
    		btn.Font = Enum.Font.SourceSansBold
    		btn.Text = def.Name
    		btn.Parent = tabsFrame
    
    		local btnCorner = Instance.new("UICorner")
    		btnCorner.CornerRadius = UDim.new(0, Theme.CornerRadiusSmall)
    		btnCorner.Parent = btn
    
    		btn.MouseButton1Click:Connect(function()
    			self:SwitchTab(def.Id)
    		end)
    
    		self._tabButtons[def.Id] = btn
    	end
    
    	return (self :: any) :: WindowManager
    end
    
    function WindowManager:SwitchTab(tabId: string)
    	self.CurrentTab = tabId
    	for id, btn in pairs(self._tabButtons) do
    		if id == tabId then
    			btn.BackgroundTransparency = 0
    			btn.TextColor3 = Theme.Accent
    		else
    			btn.BackgroundTransparency = 1
    			btn.TextColor3 = Theme.TextSecondary
    		end
    	end
    	self._onTabSwitched(tabId)
    end
    
    function WindowManager:ToggleVisibility()
    	self.RootWindow.Visible = not self.RootWindow.Visible
    end
    
    function WindowManager:Destroy()
    	self.RootWindow:Destroy()
    end
    
    return WindowManager
end

-- Module: Main
__modules["Main"] = function()
    -- [Main.luau]
    -- Master orchestrator and lifecycle entrypoint for AethelDex v1.0
    
    local UserInputService = game:GetService("UserInputService")
    
    local SafeHost = __require("SafeHost")
    local Config = __require("Config")
    local Janitor = __require("Janitor")
    
    local TreeState = __require("TreeState")
    local SearchEngine = __require("SearchEngine")
    local VirtualList = __require("VirtualList")
    
    local WindowManager = __require("WindowManager")
    local CommandPalette = __require("CommandPalette")
    local TouchEngine = __require("TouchEngine")
    
    local PropertiesView = __require("PropertiesView")
    local RemoteSpy = __require("RemoteSpy")
    local ScriptViewer = __require("ScriptViewer")
    local NilScanner = __require("NilScanner")
    
    local AethelDex = {}
    
    function AethelDex.Init()
    	local janitor = Janitor.new()
    
    	-- 1. Initialize SafeHost
    	local host = SafeHost.new("AethelDex_v1")
    	janitor:Add(host)
    
    	-- 2. Initialize Tree State
    	local treeState = TreeState.new()
    
    	-- 3. Populate standard root services
    	local standardServices = {
    		"Workspace",
    		"Players",
    		"Lighting",
    		"ReplicatedStorage",
    		"ReplicatedFirst",
    		"StarterGui",
    		"StarterPack",
    		"StarterPlayer",
    		"SoundService",
    		"Chat",
    		"MaterialService",
    		"TextChatService",
    	}
    
    	for _, serviceName in ipairs(standardServices) do
    		local ok, service = pcall(function()
    			return game:GetService(serviceName)
    		end)
    		if ok and service then
    			treeState:AddRootService(service)
    		end
    	end
    
    	-- 4. Setup Main Window Manager
    	local activeTab = "explorer"
    	local tabContainers: { [string]: Frame } = {}
    
    	local windowMgr: WindowManager.WindowManager
    	windowMgr = WindowManager.new(host.RootGui, function(tabId)
    		activeTab = tabId
    		for id, container in pairs(tabContainers) do
    			container.Visible = (id == tabId)
    		end
    	end)
    	janitor:Add(windowMgr)
    
    	-- 5. Create Tab Views
    	local function createTabContainer(name: string): Frame
    		local frame = Instance.new("Frame")
    		frame.Name = `TabContent_{name}`
    		frame.Size = UDim2.fromScale(1, 1)
    		frame.BackgroundTransparency = 1
    		frame.Visible = (name == "explorer")
    		frame.Parent = windowMgr.ContentArea
    		tabContainers[name] = frame
    		return frame
    	end
    
    	-- Tab 1: Explorer
    	local explorerFrame = createTabContainer("explorer")
    	
    	-- Search bar in Explorer
    	local searchInput = Instance.new("TextBox")
    	searchInput.Name = "ExplorerSearch"
    	searchInput.Size = UDim2.new(1, -16, 0, 26)
    	searchInput.Position = UDim2.fromOffset(8, 6)
    	searchInput.BackgroundColor3 = Color3.fromRGB(33, 36, 44)
    	searchInput.TextColor3 = Color3.fromRGB(245, 246, 250)
    	searchInput.PlaceholderText = "Search instances (c:Class, p:Prop, t:Tag)..."
    	searchInput.PlaceholderColor3 = Color3.fromRGB(115, 120, 135)
    	searchInput.TextSize = 13
    	searchInput.Font = Enum.Font.SourceSans
    	searchInput.ClearTextOnFocus = false
    	searchInput.Parent = explorerFrame
    
    	local searchCorner = Instance.new("UICorner")
    	searchCorner.CornerRadius = UDim.new(0, 4)
    	searchCorner.Parent = searchInput
    
    	local virtualList = VirtualList.new(explorerFrame, treeState)
    	virtualList:UpdateData(treeState.FlattenedList)
    	janitor:Add(virtualList)
    
    	searchInput:GetPropertyChangedSignal("Text"):Connect(function()
    		local filtered = SearchEngine.FilterNodes(treeState.FlattenedList, searchInput.Text)
    		virtualList:UpdateData(filtered)
    	end)
    
    	treeState.OnTreeStructureChanged:Connect(function()
    		if searchInput.Text == "" then
    			virtualList:UpdateData(treeState.FlattenedList)
    		else
    			local filtered = SearchEngine.FilterNodes(treeState.FlattenedList, searchInput.Text)
    			virtualList:UpdateData(filtered)
    		end
    	end)
    
    	-- Tab 2: Properties
    	local propertiesFrame = createTabContainer("properties")
    	local propView = PropertiesView.new(propertiesFrame)
    	janitor:Add(propView)
    
    	-- Hook selection changed: Automatically update properties and script viewer
    	treeState.OnSelectionChanged:Connect(function(selection)
    		local first = selection[1]
    		propView:SetTarget(first)
    	end)
    
    	-- Tab 3: Remote Spy
    	local remotesFrame = createTabContainer("remotes")
    	local remoteSpy = RemoteSpy.new(remotesFrame)
    	janitor:Add(remoteSpy)
    
    	-- Tab 4: Script Viewer
    	local scriptsFrame = createTabContainer("scriptviewer")
    	local scriptViewer = ScriptViewer.new(scriptsFrame)
    	janitor:Add(scriptViewer)
    
    	-- Double-click or select script to view
    	treeState.OnSelectionChanged:Connect(function(selection)
    		local first = selection[1]
    		if first and (first:IsA("LuaSourceContainer") or first:IsA("Script") or first:IsA("LocalScript") or first:IsA("ModuleScript")) then
    			scriptViewer:ViewScript(first)
    		end
    	end)
    
    	-- Tab 5: Nil Scanner
    	local nilFrame = createTabContainer("nil")
    	local nilScanner = NilScanner.new(nilFrame)
    	janitor:Add(nilScanner)
    
    	-- 6. Setup Command Palette (Ctrl+K)
    	local palette = CommandPalette.new(host.RootGui, function(actionId)
    		if string.sub(actionId, 1, 4) == "tab:" then
    			local tabId = string.sub(actionId, 5)
    			windowMgr:SwitchTab(tabId)
    		elseif actionId == "action:toggle_mobile" then
    			-- Toggle mobile layout
    		end
    	end)
    	janitor:Add(palette)
    
    	-- 7. Mobile Touch Floating Button (if Touch Device)
    	if TouchEngine.IsTouchDevice then
    		local mobileBtn = TouchEngine.CreateMobileToggle(function()
    			windowMgr:ToggleVisibility()
    		end)
    		mobileBtn.Parent = host.RootGui
    		janitor:Add(mobileBtn)
    	end
    
    	-- 8. Global Keybinds
    	UserInputService.InputBegan:Connect(function(input, gpe)
    		if gpe then
    			return
    		end
    		if input.KeyCode == Config.Keybindings.ToggleDex then
    			windowMgr:ToggleVisibility()
    		end
    	end)
    
    	print("[AethelDex v1.0] Successfully mounted and ready! Press F8 or use Ctrl+K to open Command Palette.")
    end
    
    return AethelDex
end

-- Bootstrap AethelDex v1.0
local Main = __require("Main")
Main.Init()
return Main
