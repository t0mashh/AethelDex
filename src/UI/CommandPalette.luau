--!strict
-- [CommandPalette.luau]
-- Quick Spotlight-style launcher (Ctrl+K) for instant fuzzy search & commands

local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)

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

function CommandPalette.new(parentGui, onAction)
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

	return self
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
		btn.Name = "Cmd_" .. cmd.Id
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
