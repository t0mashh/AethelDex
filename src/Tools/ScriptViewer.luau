--!strict
-- [ScriptViewer.luau]
-- In-game Luau script viewer with decompiler integration and syntax highlighting

local Theme = require(script.Parent.Parent.UI.Theme)

export type ScriptViewer = {
	Container: Frame,
	ViewScript: (self: ScriptViewer, scriptInst: Instance) -> (),
	Destroy: (self: ScriptViewer) -> (),
}

local ScriptViewer = {}
ScriptViewer.__index = ScriptViewer

function ScriptViewer.new(parentFrame)
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
		local setclipboard = (rawget(getfenv(), "setclipboard") )
		if typeof(setclipboard) == "function" and self._currentCode ~= "" then
			setclipboard(self._currentCode)
			copyBtn.Text = "Copied!"
			task.delay(1, function()
				copyBtn.Text = "Copy Code"
			end)
		end
	end)

	return self
end

function ScriptViewer:ViewScript(scriptInst)
	self._title.Text = "Viewing: " .. scriptInst.Name .. " [" .. scriptInst.ClassName .. "]"
	self._codeLabel.Text = "Decompiling / Fetching source, please wait..."

	task.spawn(function()
		local source = ""
		local decompile = (rawget(getfenv(), "decompile") )

		if typeof(decompile) == "function" then
			local ok, res = pcall(decompile, scriptInst)
			if ok and typeof(res) == "string" then
				source = res
			else
				source = "-- Decompile failed: " .. tostring(res)
			end
		else
			-- Try reading .Source property (works in Studio / privileged environments)
			local ok, res = pcall(function()
				return (scriptInst ).Source
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
			highlighted = string.gsub(highlighted, "%f[%a]" .. kw .. "%f[%A]", '<font color="#4f75ff"><b>' .. kw .. '</b></font>')
		end

		-- Highlight comments
		highlighted = string.gsub(highlighted, "(%-%-[^\n]*)", '<font color="#737887"><i>%1</i></font>')

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
