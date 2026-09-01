--!strict
-- [RemoteSpy.luau]
-- Network traffic logger, parameter inspector, and code generator for AethelDex

local Theme = require(script.Parent.Parent.UI.Theme)
local Serializers = require(script.Parent.Parent.Reflection.Serializers)

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
