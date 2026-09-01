--[[
    ================================================================================
    AethelDex Advanced Multi-Tier Decompiler Suite
    Universal Luau Decompiler Engine (Native + Cloud + In-Engine Bytecode Lifting + Deep Module Introspection)
    ================================================================================
--]]

local scriptViewerWindow = nil
local scriptViewerBox = nil
local scriptViewerTitle = nil
local currentScript = nil

-- [[ Environment Helper: Safe Global Lookup ]]
-- In executors, APIs like decompile, getscriptbytecode, request are stored in getgenv() or _G.
local function getGlobal(name)
	local val = nil
	pcall(function()
		if typeof(getgenv) == "function" then
			local g = getgenv()
			if g and g[name] ~= nil then
				val = g[name]
				return
			end
		end
		if _G and _G[name] ~= nil then
			val = _G[name]
			return
		end
		if typeof(getrenv) == "function" then
			local r = getrenv()
			if r and r[name] ~= nil then
				val = r[name]
				return
			end
		end
		local env = getfenv and getfenv()
		if env and env[name] ~= nil then
			val = env[name]
			return
		end
	end)
	return val
end

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
	local assetIds = {}
	
	for i = 1, stringCount do
		local slen = readVarInt()
		local str = readString(slen)
		stringTable[i] = str
		
		local lower = string.lower(str)
		if string.find(lower, "remote", 1, true) or string.find(lower, "event", 1, true) or string.find(lower, "fire", 1, true) then
			table.insert(remotes, str)
		elseif string.find(lower, "service", 1, true) or str == "Workspace" or str == "Players" or str == "Lighting" or str == "ReplicatedStorage" or str == "ContentProvider" then
			table.insert(services, str)
		elseif string.find(lower, "http://", 1, true) or string.find(lower, "https://", 1, true) or string.find(lower, "discord", 1, true) then
			table.insert(urls, str)
		elseif string.find(lower, "rbxassetid://", 1, true) or string.find(str, "^%d%d%d%d%d+$") then
			table.insert(assetIds, str)
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
	table.insert(lines, "    AethelDex Universal Decompiler v1.0 [Luau Bytecode Engine]")
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
	
	if #assetIds > 0 then
		table.insert(lines, "-- [[ Detected Assets & Animations ]]")
		local seen = {}
		for _, a in ipairs(assetIds) do
			if not seen[a] then
				seen[a] = true
				table.insert(lines, '-- Asset: ' .. a)
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
	for i = 1, math.min(stringCount, 80) do
		local s = stringTable[i]
		if s and #s > 0 then
			table.insert(lines, string.format('    [%d] = %q,', i, s))
		end
	end
	if stringCount > 80 then
		table.insert(lines, "    -- ... (" .. (stringCount - 80) .. " more string constants omitted)")
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
		
		for j = 1, math.min(#pr.instructions, 60) do
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
		if #pr.instructions > 60 then
			table.insert(lines, "    -- ... (" .. (#pr.instructions - 60) .. " remaining instructions)")
		end
		table.insert(lines, "end\n")
	end
	
	return table.concat(lines, "\n")
end

-- [[ Deep Function Decompiler ]]
function f.decompileFunction(fn, fnName)
	-- 1. Try native decompile on closure
	local nativeDecompile = getGlobal("decompile")
	if type(nativeDecompile) == "function" then
		local ok, code = pcall(nativeDecompile, fn)
		if ok and type(code) == "string" and #code > 10 and not string.find(code, "failed", 1, true) then
			return code
		end
	end

	-- 2. Try dumping closure bytecode
	local dump = getGlobal("dumpstring") or string.dump
	if type(dump) == "function" then
		local ok, bc = pcall(dump, fn)
		if ok and type(bc) == "string" and #bc > 0 then
			local res = f.disassembleLuauBytecode(bc, nil)
			if res and #res > 30 then
				return res
			end
		end
	end

	-- 3. Advanced Function Introspection via getconstants / getupvalues / getprotos / debug
	local getconstants = getGlobal("getconstants") or (debug and debug.getconstants)
	local getupvalues = getGlobal("getupvalues") or (debug and debug.getupvalues)
	local getprotos = getGlobal("getprotos") or (debug and debug.getprotos)
	local getinfo = getGlobal("getinfo") or (debug and debug.getinfo)

	local lines = {}
	local info = {}
	if type(getinfo) == "function" then pcall(function() info = getinfo(fn) end) end

	local constants = {}
	if type(getconstants) == "function" then pcall(function() constants = getconstants(fn) end) end

	local upvalues = {}
	if type(getupvalues) == "function" then pcall(function() upvalues = getupvalues(fn) end) end

	local protos = {}
	if type(getprotos) == "function" then pcall(function() protos = getprotos(fn) end) end

	local paramCount = info.numparams or 0
	local params = {}
	for i = 1, paramCount do table.insert(params, "arg" .. i) end
	if info.is_vararg == 1 then table.insert(params, "...") end

	table.insert(lines, string.format("function %s(%s)", fnName, table.concat(params, ", ")))

	-- Upvalues
	if #upvalues > 0 then
		table.insert(lines, "    -- Upvalues captured by function:")
		for k, v in pairs(upvalues) do
			if type(v) == "string" then
				table.insert(lines, string.format("    --   upval_%s = %q", tostring(k), v))
			else
				table.insert(lines, string.format("    --   upval_%s = %s", tostring(k), tostring(v)))
			end
		end
	end

	-- Constants (Remotes, Assets, Services)
	if #constants > 0 then
		local assetsFound = {}
		local remotesFound = {}
		local methodsFound = {}
		local otherConstants = {}

		for _, c in pairs(constants) do
			if type(c) == "string" then
				local lower = string.lower(c)
				if string.find(lower, "rbxassetid://", 1, true) or string.find(c, "^%d%d%d%d%d+$") then
					table.insert(assetsFound, c)
				elseif string.find(lower, "remote", 1, true) or string.find(lower, "event", 1, true) then
					table.insert(remotesFound, c)
				elseif string.find(lower, "preload", 1, true) or string.find(lower, "connect", 1, true) or string.find(lower, "fire", 1, true) or string.find(lower, "wait", 1, true) then
					table.insert(methodsFound, c)
				else
					table.insert(otherConstants, c)
				end
			else
				table.insert(otherConstants, tostring(c))
			end
		end

		if #assetsFound > 0 then
			table.insert(lines, "    -- Target Assets / Animations:")
			for _, a in ipairs(assetsFound) do
				table.insert(lines, string.format("    --   Asset: %q", a))
			end
		end

		if #remotesFound > 0 then
			table.insert(lines, "    -- Referenced Remotes:")
			for _, r in ipairs(remotesFound) do
				table.insert(lines, string.format("    --   Remote: %q", r))
			end
		end

		if #methodsFound > 0 then
			table.insert(lines, "    -- Invoked APIs & Methods:")
			for _, m in ipairs(methodsFound) do
				table.insert(lines, string.format("    --   :%s(...)", m))
			end
		end

		if #otherConstants > 0 then
			table.insert(lines, "    -- Constants:")
			for _, oc in ipairs(otherConstants) do
				table.insert(lines, string.format("    --   %s", tostring(oc)))
			end
		end
	end

	-- Sub-functions
	if #protos > 0 then
		table.insert(lines, "    -- Inner Nested Functions:")
		for idx, subfn in ipairs(protos) do
			local subcode = f.decompileFunction(subfn, fnName .. "_sub" .. idx)
			table.insert(lines, "    " .. subcode:gsub("\n", "\n    "))
		end
	end

	table.insert(lines, "end\n")
	return table.concat(lines, "\n")
end

-- [[ Deep ModuleScript Decompilation ]]
function f.deepDecompileModule(scriptInst, modData)
	local lines = {}
	table.insert(lines, "--[[")
	table.insert(lines, "    ================================================================================")
	table.insert(lines, "    AethelDex Deep ModuleScript Decompiler")
	table.insert(lines, "    Module: " .. scriptInst:GetFullName())
	table.insert(lines, "    Exported Type: " .. type(modData))
	table.insert(lines, "    ================================================================================")
	table.insert(lines, "--]]\n")

	if type(modData) == "table" then
		table.insert(lines, "local Module = {}\n")

		-- First pass: data fields
		for k, v in pairs(modData) do
			if type(v) ~= "function" then
				local keyStr = tostring(k)
				if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
					keyStr = "." .. k
				else
					keyStr = string.format("[%q]", tostring(k))
				end

				if type(v) == "table" then
					local subKeys = {}
					pcall(function()
						for sk, sv in pairs(v) do
							if #subKeys < 20 then
								table.insert(subKeys, string.format("        [%q] = %s,", tostring(sk), tostring(sv)))
							end
						end
					end)
					if #subKeys > 0 then
						table.insert(lines, string.format("Module%s = {\n%s\n}\n", keyStr, table.concat(subKeys, "\n")))
					else
						table.insert(lines, string.format("Module%s = {}\n", keyStr))
					end
				elseif type(v) == "string" then
					table.insert(lines, string.format("Module%s = %q\n", keyStr, v))
				else
					table.insert(lines, string.format("Module%s = %s\n", keyStr, tostring(v)))
				end
			end
		end

		-- Second pass: deep function decompilation
		for k, v in pairs(modData) do
			if type(v) == "function" then
				local keyStr = tostring(k)
				if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
					keyStr = "." .. k
				else
					keyStr = string.format("[%q]", tostring(k))
				end

				local fnCode = f.decompileFunction(v, "Module" .. keyStr)
				table.insert(lines, fnCode)
			end
		end

		table.insert(lines, "return Module")
	elseif type(modData) == "function" then
		local fnCode = f.decompileFunction(modData, scriptInst.Name)
		table.insert(lines, fnCode)
		table.insert(lines, "return " .. scriptInst.Name)
	else
		table.insert(lines, "return " .. tostring(modData))
	end

	return table.concat(lines, "\n")
end

-- [[ Decompiler Diagnostic Fallback ]]
function f.generateDecompileDiagnostic(scriptInst)
	local hasDecompile = (type(getGlobal("decompile")) == "function")
	local hasBytecode = (type(getGlobal("getscriptbytecode") or getGlobal("get_script_bytecode") or getGlobal("dumpstring")) == "function")
	local hasClosure = (type(getGlobal("getscriptclosure")) == "function")
	local hasRequest = (type(getGlobal("request") or getGlobal("http_request")) == "function")

	local lines = {
		"-- ================================================================================",
		"-- AethelDex Decompiler Diagnostic Report",
		"-- Target: " .. (scriptInst and scriptInst:GetFullName() or "Script"),
		"-- Class: " .. (scriptInst and scriptInst.ClassName or "Unknown"),
		"-- ================================================================================",
		"-- [Executor Environment Status]:",
		"--   * Native decompile(): " .. (hasDecompile and "AVAILABLE" or "NOT FOUND"),
		"--   * Bytecode Extraction (getscriptbytecode): " .. (hasBytecode and "AVAILABLE" or "NOT FOUND"),
		"--   * Script Closure Access (getscriptclosure): " .. (hasClosure and "AVAILABLE" or "NOT FOUND"),
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

	local decompile = getGlobal("decompile")
	local getscriptbytecode = getGlobal("getscriptbytecode") 
		or getGlobal("get_script_bytecode") 
		or getGlobal("dumpstring")
		or getGlobal("getbytecode")
	local getscriptclosure = getGlobal("getscriptclosure")
	local httpRequest = getGlobal("request") 
		or getGlobal("http_request") 
		or (getGlobal("syn") and type(getGlobal("syn")) == "table" and getGlobal("syn").request)
		or (getGlobal("http") and type(getGlobal("http")) == "table" and getGlobal("http").request)

	-- 1. Native decompile(scriptInst)
	if type(decompile) == "function" then
		local ok, res = pcall(decompile, scriptInst)
		if ok and type(res) == "string" and #res > 30 and not string.find(res, "failed to decompile", 1, true) then
			return res
		end
	end

	-- 2. Plain Source
	local hasSource, rawSource = pcall(function() return scriptInst.Source end)
	if hasSource and type(rawSource) == "string" and #rawSource > 0 then
		return rawSource
	end

	-- 3. Extract Bytecode from script instance
	local bytecode = nil
	if type(getscriptbytecode) == "function" then
		local ok, bc = pcall(getscriptbytecode, scriptInst)
		if ok and type(bc) == "string" and #bc > 0 then
			bytecode = bc
		end
	end

	-- If getscriptbytecode failed, try getscriptclosure + dump
	if not bytecode and type(getscriptclosure) == "function" then
		local ok, closure = pcall(getscriptclosure, scriptInst)
		if ok and type(closure) == "function" then
			if type(decompile) == "function" then
				local ok2, res2 = pcall(decompile, closure)
				if ok2 and type(res2) == "string" and #res2 > 30 and not string.find(res2, "failed", 1, true) then
					return res2
				end
			end
			local dump = getGlobal("dumpstring") or string.dump
			if type(dump) == "function" then
				local ok3, bc = pcall(dump, closure)
				if ok3 and type(bc) == "string" and #bc > 0 then
					bytecode = bc
				end
			end
		end
	end

	-- 4. Process Bytecode (Cloud API -> Local Engine)
	if bytecode then
		-- 4a. Cloud Decompiler API (Konstant)
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
			if ok and type(resp) == "table" and (resp.StatusCode == 200 or resp.Status == 200) and type(resp.Body) == "string" and #resp.Body > 30 then
				return resp.Body
			end
		end

		-- 4b. In-Engine Luau Bytecode Engine
		local ok, analyzed = pcall(function() return f.disassembleLuauBytecode(bytecode, scriptInst) end)
		if ok and type(analyzed) == "string" and #analyzed > 50 then
			return analyzed
		end
	end

	-- 5. Deep ModuleScript Decompilation & Introspection
	local isModule = false
	pcall(function() isModule = scriptInst:IsA("ModuleScript") end)
	if isModule then
		local ok, modData = pcall(require, scriptInst)
		if ok then
			return f.deepDecompileModule(scriptInst, modData)
		end
	end

	-- 6. Diagnostic Report
	return f.generateDecompileDiagnostic(scriptInst)
end

function f.saveScript(scriptInst)
	if not scriptInst then return end
	local source = f.decompileScript(scriptInst)
	pcall(function()
		local writefile = getGlobal("writefile")
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
					local setclipboard = getGlobal("setclipboard") or getGlobal("toclipboard")
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
