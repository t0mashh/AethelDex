--!strict
-- [WindowManager.luau]
-- Docking window manager, tab switcher, and panel coordinator for AethelDex

local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)

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
	closeBtn.Text = "✕"
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
		btn.Name = "Tab_" .. def.Id
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
