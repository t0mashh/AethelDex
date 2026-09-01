--!strict
-- [PropertiesView.luau]
-- Real-time interactive Property Inspector with category collapsing and type editors

local Theme = require(script.Parent.Parent.UI.Theme)
local ReflectionEngine = require(script.Parent.Parent.Reflection.ReflectionEngine)
local Serializers = require(script.Parent.Parent.Reflection.Serializers)

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
			catHeader.Name = "Cat_" .. currentCategory
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
		row.Name = "Prop_" .. prop.Name
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
