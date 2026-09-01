--!strict
-- [Main.luau]
-- Master orchestrator and lifecycle entrypoint for AethelDex v1.0

local UserInputService = game:GetService("UserInputService")

local SafeHost = require(script.Parent.Core.SafeHost)
local Config = require(script.Parent.Core.Config)
local Janitor = require(script.Parent.Core.Janitor)

local TreeState = require(script.Parent.Tree.TreeState)
local SearchEngine = require(script.Parent.Tree.SearchEngine)
local VirtualList = require(script.Parent.Tree.VirtualList)

local WindowManager = require(script.Parent.UI.WindowManager)
local CommandPalette = require(script.Parent.UI.CommandPalette)
local TouchEngine = require(script.Parent.UI.TouchEngine)

local PropertiesView = require(script.Parent.Tools.PropertiesView)
local RemoteSpy = require(script.Parent.Tools.RemoteSpy)
local ScriptViewer = require(script.Parent.Tools.ScriptViewer)
local NilScanner = require(script.Parent.Tools.NilScanner)

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
		frame.Name = "TabContent_" .. name
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
