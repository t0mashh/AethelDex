--!strict
-- [NilScanner.luau]
-- Orphaned / nil-parented instance inspector and recovery manager for AethelDex

local Theme = require(script.Parent.Parent.UI.Theme)
local Icons = require(script.Parent.Parent.UI.Icons)

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
