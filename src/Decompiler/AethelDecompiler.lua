--[[
    ================================================================================
    AethelDex Multi-Tier Decompiler Suite
    Universal Luau Decompiler Engine (Native + Cloud + In-Engine Bytecode Lifting)
    ================================================================================
--]]

local scriptViewerWindow = nil
local scriptViewerBox = nil
local scriptViewerTitle = nil
local currentScript = nil

-- [[ Built-In Luau Bytecode Engine ]]
function f.disassembleLuauBytecode(bytecode, scriptInst)
	local cursor = 1
	local len = #bytecode
	
	local bitLib = bit32 or bit or {}
	local band = bitLib.band or function(a, b) return (a % 2 == 1 and b % 2 == 1) and 1 or 0 end
	local rshift = bitLib.rshift or function(a, b) return math.floor(a / (2 ^ b)) end
	
	local function readByte()
		if cursor > len then return 0 end
		local b = string.byte(bytecode, cursor)
		cursor = cursor + 1
		return b
	end
	
	local function readVarInt()
		local result = 0
		local shift = 0
		while true do
			local b = readByte()
			result = result + band(b, 0x7F) * (2 ^ shift)
			if band(b, 0x80) == 0 then break end
			shift = shift + 7
		end
		return result
	end
	
	local function readInt32()
		local b0, b1, b2, b3 = readByte(), readByte(), readByte(), readByte()
		return b0 + b1 * 256 + b2 * 65536 + b3 * 16777216
	end
	
	local function readString(l)
		if l <= 0 then return "" end
		local s = string.sub(bytecode, cursor, cursor + l - 1)
		cursor = cursor + l
		return s
	end

	local version = readByte()
	if version == 0 then
		return "-- [Error]: Invalid Luau bytecode header (version 0)"
	end
	
	if version >= 4 then
		local typesVersion = readByte()
	end
	
	local stringCount = readVarInt()
	local stringTable = {}
	local remotes = {}
	local services = {}
	local urls = {}
	
	for i = 1, stringCount do
		local slen = readVarInt()
		local str = readString(slen)
		stringTable[i] = str
		
		local lower = string.lower(str)
		if string.find(lower, "remote", 1, true) or string.find(lower, "event", 1, true) or string.find(lower, "fire", 1, true) then
			table.insert(remotes, str)
		elseif string.find(lower, "service", 1, true) or str == "Workspace" or str == "Players" or str == "Lighting" or str == "ReplicatedStorage" then
			table.insert(services, str)
		elseif string.find(lower, "http://", 1, true) or string.find(lower, "https://", 1, true) or string.find(lower, "discord", 1, true) then
			table.insert(urls, str)
		end
	end
	
	local protoCount = readVarInt()
	local protos = {}
	
	for p = 1, protoCount do
		local proto = {
			id = p - 1,
			maxstacksize = readByte(),
			numparams = readByte(),
			numupvalues = readByte(),
			is_vararg = readByte(),
			instructions = {},
			constants = {}
		}
		
		if version >= 4 then
			proto.flags = readByte()
			local typesSize = readVarInt()
			if typesSize > 0 then
				cursor = cursor + typesSize
			end
		end
		
		local sizecode = readVarInt()
		for j = 1, sizecode do
			local ins = readInt32()
			proto.instructions[j] = ins
		end
		
		local sizek = readVarInt()
		for k = 1, sizek do
			local ktype = readByte()
			if ktype == 0 then
				proto.constants[k] = "nil"
			elseif ktype == 1 then
				proto.constants[k] = (readByte() == 1)
			elseif ktype == 2 then
				cursor = cursor + 8
				proto.constants[k] = "<number>"
			elseif ktype == 3 then
				local sId = readVarInt()
				proto.constants[k] = stringTable[sId] or ""
			elseif ktype == 4 then
				local imp = readInt32()
				proto.constants[k] = "<import>"
			elseif ktype == 5 then
				local tabSize = readVarInt()
				for t = 1, tabSize do readVarInt() end
				proto.constants[k] = "{}"
			elseif ktype == 6 then
				local cId = readVarInt()
				proto.constants[k] = "<closure:" .. cId .. ">"
			end
		end
		
		local sizep = readVarInt()
		for cp = 1, sizep do readVarInt() end
		
		proto.lineDefined = readVarInt()
		local debugNameId = readVarInt()
		proto.name = stringTable[debugNameId] or ("func_" .. (p - 1))
		
		protos[p] = proto
	end
	
	-- Build Disassembly Output
	local lines = {}
	table.insert(lines, "--[[")
	table.insert(lines, "    ================================================================================")
	table.insert(lines, "    AethelDex Universal Decompiler v1.0 [Built-In Luau Bytecode Engine]")
	table.insert(lines, "    Script: " .. (scriptInst and scriptInst:GetFullName() or "Unknown"))
	table.insert(lines, "    Class: " .. (scriptInst and scriptInst.ClassName or "LuaSourceContainer"))
	table.insert(lines, "    Bytecode: Luau v" .. version .. " | Protos: " .. protoCount .. " | Strings: " .. stringCount)
	table.insert(lines, "    ================================================================================")
	table.insert(lines, "--]]\n")
	
	if #services > 0 then
		table.insert(lines, "-- [[ Referenced Services ]]")
		local seen = {}
		for _, s in ipairs(services) do
			if not seen[s] and #s > 2 then
				seen[s] = true
				table.insert(lines, 'local ' .. s:gsub('[^%w_]', '') .. ' = game:GetService("' .. s .. '")')
			end
		end
		table.insert(lines, "")
	end
	
	if #remotes > 0 then
		table.insert(lines, "-- [[ Detected Remotes & Events ]]")
		local seen = {}
		for _, r in ipairs(remotes) do
			if not seen[r] and #r > 1 then
				seen[r] = true
				table.insert(lines, '-- Remote / Event: "' .. r .. '"')
			end
		end
		table.insert(lines, "")
	end
	
	if #urls > 0 then
		table.insert(lines, "-- [[ Detected URLs / Webhooks ]]")
		for _, u in ipairs(urls) do
			table.insert(lines, '-- URL: ' .. u)
		end
		table.insert(lines, "")
	end

	table.insert(lines, "-- [[ Extracted String Constants ]]")
	table.insert(lines, "local Strings = {")
	for i = 1, math.min(stringCount, 60) do
		local s = stringTable[i]
		if s and #s > 0 then
			table.insert(lines, string.format('    [%d] = %q,', i, s))
		end
	end
	if stringCount > 60 then
		table.insert(lines, "    -- ... (" .. (stringCount - 60) .. " more string constants omitted)")
	end
	table.insert(lines, "}\n")

	table.insert(lines, "-- [[ Reconstructed Function Prototypes ]]")
	for p = 1, #protos do
		local pr = protos[p]
		local pName = pr.name
		if not pName or pName == "" then pName = "proto_" .. (p - 1) end
		local paramList = {}
		for arg = 1, pr.numparams do
			table.insert(paramList, "arg" .. arg)
		end
		if pr.is_vararg == 1 then table.insert(paramList, "...") end
		
		table.insert(lines, string.format("local function %s(%s) -- Proto %d (Stack: %d, Upvalues: %d)", pName, table.concat(paramList, ", "), p - 1, pr.maxstacksize, pr.numupvalues))
		
		for j = 1, math.min(#pr.instructions, 40) do
			local ins = pr.instructions[j]
			local op = band(ins, 0xFF)
			local rA = band(rshift(ins, 8), 0xFF)
			local rB = band(rshift(ins, 16), 0xFF)
			local rC = band(rshift(ins, 24), 0xFF)
			
			if op == 4 then -- LOP_LOADK
				local kVal = pr.constants[rB + 1] or "nil"
				if type(kVal) == "string" and kVal ~= "<number>" and kVal ~= "nil" and not string.find(kVal, "^<") then
					kVal = string.format("%q", kVal)
				end
				table.insert(lines, string.format("    local r%d = %s", rA, tostring(kVal)))
			elseif op == 6 then -- LOP_GETGLOBAL
				local gName = pr.constants[rC + 1] or stringTable[rC + 1] or "Global"
				table.insert(lines, string.format("    local r%d = %s", rA, tostring(gName)))
			elseif op == 7 then -- LOP_SETGLOBAL
				local gName = pr.constants[rC + 1] or stringTable[rC + 1] or "Global"
				table.insert(lines, string.format("    %s = r%d", tostring(gName), rA))
			elseif op == 14 then -- LOP_GETTABLEKS
				local key = stringTable[rC + 1] or ("field_" .. rC)
				table.insert(lines, string.format("    local r%d = r%d.%s", rA, rB, key))
			elseif op == 15 then -- LOP_SETTABLEKS
				local key = stringTable[rC + 1] or ("field_" .. rC)
				table.insert(lines, string.format("    r%d.%s = r%d", rB, key, rA))
			elseif op == 19 then -- LOP_NAMECALL
				local method = stringTable[rC + 1] or ("method_" .. rC)
				table.insert(lines, string.format("    -- r%d:%s(...)", rA, method))
			elseif op == 20 then -- LOP_CALL
				table.insert(lines, string.format("    r%d(r%d)", rA, rA + 1))
			elseif op == 21 then -- LOP_RETURN
				table.insert(lines, string.format("    return r%d", rA))
			elseif op == 51 or op == 52 then -- LOP_NEWTABLE / DUPTABLE
				table.insert(lines, string.format("    local r%d = {}", rA))
			end
		end
		if #pr.instructions > 40 then
			table.insert(lines, "    -- ... (" .. (#pr.instructions - 40) .. " remaining instructions)")
		end
		table.insert(lines, "end\n")
	end
	
	return table.concat(lines, "\n")
end

-- [[ ModuleScript In-Memory Reflection ]]
function f.reflectModule(scriptInst, modData)
	local lines = {}
	table.insert(lines, "--[[")
	table.insert(lines, "    ================================================================================")
	table.insert(lines, "    AethelDex In-Memory ModuleScript Reflection")
	table.insert(lines, "    Module: " .. scriptInst:GetFullName())
	table.insert(lines, "    Exported Type: " .. type(modData))
	table.insert(lines, "    ================================================================================")
	table.insert(lines, "--]]\n")

	if type(modData) == "table" then
		table.insert(lines, "local Module = {}\n")
		for k, v in pairs(modData) do
			local keyStr = tostring(k)
			if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
				keyStr = "." .. k
			else
				keyStr = string.format("[%q]", tostring(k))
			end

			if type(v) == "function" then
				table.insert(lines, string.format("function Module%s(...)\n    -- [Exported Function in %s]\nend\n", keyStr, scriptInst.Name))
			elseif type(v) == "table" then
				table.insert(lines, string.format("Module%s = { -- [Subtable] }\n", keyStr))
			elseif type(v) == "string" then
				table.insert(lines, string.format("Module%s = %q\n", keyStr, v))
			else
				table.insert(lines, string.format("Module%s = %s\n", keyStr, tostring(v)))
			end
		end
		table.insert(lines, "return Module")
	elseif type(modData) == "function" then
		table.insert(lines, "return function(...)\n    -- [Executable Function exported by " .. scriptInst.Name .. "]\nend")
	else
		table.insert(lines, "return " .. tostring(modData))
	end

	return table.concat(lines, "\n")
end

-- [[ Decompiler Diagnostic Fallback ]]
function f.generateDecompileDiagnostic(scriptInst)
	local hasDecompile = (type(rawget(getfenv(), "decompile")) == "function")
	local hasBytecode = (type(rawget(getfenv(), "getscriptbytecode") or rawget(getfenv(), "get_script_bytecode") or rawget(getfenv(), "dumpstring")) == "function")
	local hasRequest = (type(rawget(getfenv(), "request") or rawget(getfenv(), "http_request")) == "function")

	local lines = {
		"-- ================================================================================",
		"-- AethelDex Decompiler Diagnostic Report",
		"-- Target: " .. (scriptInst and scriptInst:GetFullName() or "Script"),
		"-- Class: " .. (scriptInst and scriptInst.ClassName or "Unknown"),
		"-- ================================================================================",
		"-- [Executor Environment Status]:",
		"--   * Native decompile(): " .. (hasDecompile and "AVAILABLE" or "NOT FOUND"),
		"--   * Bytecode Extraction (getscriptbytecode): " .. (hasBytecode and "AVAILABLE" or "NOT FOUND"),
		"--   * HTTP Networking (request / http_request): " .. (hasRequest and "AVAILABLE" or "NOT FOUND"),
		"--",
		"-- [Analysis]:",
		"-- In live Roblox experiences, Lua source code is compiled into Luau bytecode and stripped",
		"-- by the Roblox engine. To decompile scripts, your executor needs either:",
		"--   1) A native 'decompile(script)' function, or",
		"--   2) A 'getscriptbytecode(script)' function so AethelDex's built-in engine can analyze it.",
		"--",
		"-- [Recommended Actions]:",
		"-- - Check your executor settings and enable 'UNC functions' or 'Bytecode access'.",
		"-- - Executors like Solara, Wave, Xeno, Celery, and MacSploit provide full bytecode access!",
		"-- ================================================================================"
	}
	return table.concat(lines, "\n")
end

-- [[ Master Decompiler Pipeline ]]
function f.decompileScript(scriptInst)
	if not scriptInst then return "-- [Error]: Invalid script instance" end

	-- Tier 1: Native Executor Decompiler
	local nativeDecompile = rawget(getfenv(), "decompile")
	if type(nativeDecompile) == "function" then
		local ok, res = pcall(nativeDecompile, scriptInst)
		if ok and type(res) == "string" and #res > 0 and not string.find(res, "failed to decompile", 1, true) then
			return res
		end
	end

	-- Tier 2: Plain Source (Studio or executor source bypass)
	local hasSource, rawSource = pcall(function() return scriptInst.Source end)
	if hasSource and type(rawSource) == "string" and #rawSource > 0 then
		return rawSource
	end

	-- Tier 3: Bytecode Extraction
	local getbytecode = rawget(getfenv(), "getscriptbytecode") 
		or rawget(getfenv(), "get_script_bytecode") 
		or rawget(getfenv(), "dumpstring")
		or rawget(getfenv(), "getbytecode")

	local bytecode = nil
	if type(getbytecode) == "function" then
		local ok, bc = pcall(getbytecode, scriptInst)
		if ok and type(bc) == "string" and #bc > 0 then
			bytecode = bc
		end
	end

	-- Tier 4: Cloud / Konstant API Decompilation
	if bytecode then
		local httpRequest = rawget(getfenv(), "request") 
			or rawget(getfenv(), "http_request") 
			or (rawget(getfenv(), "syn") and type(rawget(getfenv(), "syn")) == "table" and rawget(getfenv(), "syn").request)
			or (rawget(getfenv(), "http") and type(rawget(getfenv(), "http")) == "table" and rawget(getfenv(), "http").request)

		if type(httpRequest) == "function" then
			local ok, resp = pcall(function()
				return httpRequest({
					Url = "http://api.plusgiant5.com/konstant/decompile",
					Method = "POST",
					Headers = { ["Content-Type"] = "text/plain" },
					Body = bytecode,
					Timeout = 4
				})
			end)
			if ok and type(resp) == "table" and (resp.StatusCode == 200 or resp.Status == 200) and type(resp.Body) == "string" and #resp.Body > 20 then
				return resp.Body
			end
		end

		-- Tier 5: Built-In Offline Luau Bytecode Engine
		local ok, analyzed = pcall(function() return f.disassembleLuauBytecode(bytecode, scriptInst) end)
		if ok and type(analyzed) == "string" and #analyzed > 0 then
			return analyzed
		end
	end

	-- Tier 6: ModuleScript In-Memory Reflection
	local isModule = false
	pcall(function() isModule = scriptInst:IsA("ModuleScript") end)
	if isModule then
		local ok, modData = pcall(require, scriptInst)
		if ok then
			return f.reflectModule(scriptInst, modData)
		end
	end

	-- Tier 7: Diagnostic Report
	return f.generateDecompileDiagnostic(scriptInst)
end

function f.saveScript(scriptInst)
	if not scriptInst then return end
	local source = f.decompileScript(scriptInst)
	pcall(function()
		local writefile = (rawget(getfenv(), "writefile"))
		if type(writefile) == "function" then
			local filename = scriptInst.Name:gsub("[^%w_%-]", "_") .. "_" .. scriptInst.ClassName .. ".lua"
			writefile(filename, source)
		end
	end)
end

function f.viewScript(scriptInst)
	if not scriptInst then return end
	currentScript = scriptInst
	
	if not scriptViewerWindow then
		scriptViewerWindow = Instance.new("Frame")
		scriptViewerWindow.Name = "ScriptViewer"
		scriptViewerWindow.Size = UDim2.new(0, 640, 0, 480)
		scriptViewerWindow.Position = UDim2.new(0.5, -320, 0.5, -240)
		scriptViewerWindow.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
		scriptViewerWindow.BorderSizePixel = 1
		scriptViewerWindow.BorderColor3 = Color3.fromRGB(60, 60, 60)
		scriptViewerWindow.Active = true
		scriptViewerWindow.Draggable = true
		scriptViewerWindow.ZIndex = 50
		scriptViewerWindow.Parent = gui

		local topBar = Instance.new("Frame")
		topBar.Name = "TopBar"
		topBar.Size = UDim2.new(1, 0, 0, 28)
		topBar.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
		topBar.BorderSizePixel = 0
		topBar.ZIndex = 51
		topBar.Parent = scriptViewerWindow

		scriptViewerTitle = Instance.new("TextLabel")
		scriptViewerTitle.Name = "Title"
		scriptViewerTitle.Size = UDim2.new(1, -180, 1, 0)
		scriptViewerTitle.Position = UDim2.new(0, 10, 0, 0)
		scriptViewerTitle.BackgroundTransparency = 1
		scriptViewerTitle.TextColor3 = Color3.fromRGB(220, 220, 220)
		scriptViewerTitle.TextSize = 13
		scriptViewerTitle.Font = Enum.Font.SourceSansBold
		scriptViewerTitle.TextXAlignment = Enum.TextXAlignment.Left
		scriptViewerTitle.ZIndex = 52
		scriptViewerTitle.Parent = topBar

		local closeBtn = Instance.new("TextButton")
		closeBtn.Name = "Close"
		closeBtn.Size = UDim2.new(0, 28, 0, 28)
		closeBtn.Position = UDim2.new(1, -28, 0, 0)
		closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
		closeBtn.BorderSizePixel = 0
		closeBtn.Text = "X"
		closeBtn.TextColor3 = Color3.new(1, 1, 1)
		closeBtn.TextSize = 13
		closeBtn.Font = Enum.Font.SourceSansBold
		closeBtn.ZIndex = 52
		closeBtn.Parent = topBar
		closeBtn.MouseButton1Click:Connect(function()
			scriptViewerWindow.Visible = false
		end)

		local copyBtn = Instance.new("TextButton")
		copyBtn.Name = "Copy"
		copyBtn.Size = UDim2.new(0, 70, 0, 22)
		copyBtn.Position = UDim2.new(1, -170, 0, 3)
		copyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		copyBtn.BorderSizePixel = 0
		copyBtn.Text = "Copy Code"
		copyBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
		copyBtn.TextSize = 12
		copyBtn.Font = Enum.Font.SourceSans
		copyBtn.ZIndex = 52
		copyBtn.Parent = topBar
		copyBtn.MouseButton1Click:Connect(function()
			if scriptViewerBox then
				pcall(function()
					local setclipboard = (rawget(getfenv(), "setclipboard") or rawget(getfenv(), "toclipboard"))
					if type(setclipboard) == "function" then
						setclipboard(scriptViewerBox.Text)
					end
				end)
				copyBtn.Text = "Copied!"
				task.delay(1, function() copyBtn.Text = "Copy Code" end)
			end
		end)

		local saveBtn = Instance.new("TextButton")
		saveBtn.Name = "Save"
		saveBtn.Size = UDim2.new(0, 60, 0, 22)
		saveBtn.Position = UDim2.new(1, -95, 0, 3)
		saveBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		saveBtn.BorderSizePixel = 0
		saveBtn.Text = "Save File"
		saveBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
		saveBtn.TextSize = 12
		saveBtn.Font = Enum.Font.SourceSans
		saveBtn.ZIndex = 52
		saveBtn.Parent = topBar
		saveBtn.MouseButton1Click:Connect(function()
			if currentScript then
				f.saveScript(currentScript)
				saveBtn.Text = "Saved!"
				task.delay(1, function() saveBtn.Text = "Save File" end)
			end
		end)

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "CodeScroll"
		scroll.Size = UDim2.new(1, -8, 1, -36)
		scroll.Position = UDim2.new(0, 4, 0, 32)
		scroll.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 8
		scroll.CanvasSize = UDim2.new(0, 0, 0, 1000)
		scroll.ZIndex = 51
		scroll.Parent = scriptViewerWindow

		scriptViewerBox = Instance.new("TextBox")
		scriptViewerBox.Name = "CodeText"
		scriptViewerBox.Size = UDim2.new(1, -10, 1, 0)
		scriptViewerBox.Position = UDim2.new(0, 5, 0, 0)
		scriptViewerBox.BackgroundTransparency = 1
		scriptViewerBox.TextColor3 = Color3.fromRGB(220, 220, 220)
		scriptViewerBox.TextSize = 13
		scriptViewerBox.Font = Enum.Font.Code
		scriptViewerBox.TextXAlignment = Enum.TextXAlignment.Left
		scriptViewerBox.TextYAlignment = Enum.TextYAlignment.Top
		scriptViewerBox.ClearTextOnFocus = false
		scriptViewerBox.MultiLine = true
		scriptViewerBox.TextEditable = false
		scriptViewerBox.ZIndex = 52
		scriptViewerBox.Parent = scroll
	end

	scriptViewerTitle.Text = "Viewing: " .. scriptInst.Name .. " [" .. scriptInst.ClassName .. "]"
	scriptViewerBox.Text = "-- [AethelDex Decompiler]: Processing bytecode & lifting source code, please wait..."
	scriptViewerWindow.Visible = true

	task.spawn(function()
		local source = f.decompileScript(scriptInst)
		scriptViewerBox.Text = source
		local lines = select(2, string.gsub(source, "\n", "\n")) + 1
		local scroll = scriptViewerBox.Parent
		if scroll and scroll:IsA("ScrollingFrame") then
			scroll.CanvasSize = UDim2.new(0, 0, 0, lines * 16 + 40)
		end
	end)
end
