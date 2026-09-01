--!strict
-- [VirtualList.luau]
-- High-performance virtualized windowing engine for AethelDex Explorer
-- Uses a fixed pool of ~35 recycled UI rows. O(1) mathematical scroll calculation.

local Theme = require(script.Parent.Parent.UI.Theme)
local Icons = require(script.Parent.Parent.UI.Icons)
local TreeState = require(script.Parent.TreeState)

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
		row.Name = "Row_" .. tostring(i)
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
