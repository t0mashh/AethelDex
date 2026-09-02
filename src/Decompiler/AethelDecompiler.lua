--[[
    ================================================================================
    AethelDex Universal Luau Decompiler Engine v2.2
    Studio-Quality Lifting, In-Engine Decompilation, AST Beautifier, Line Numbers & Code Search
    ================================================================================
--]]

local scriptViewerWindow = nil
local scriptViewerBox = nil
local lineNumBox = nil
local scriptViewerTitle = nil
local currentScript = nil
local rawDecompiledSource = ""
local isBeautified = true

-- [[ Environment Helper: Universal Global Lookup ]]
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

-- [[ Value Serializer ]]
local function serializeValue(val, depth)
	depth = depth or 1
	if depth > 4 then return "{ ... }" end
	local t = type(val)
	if t == "string" then
		return string.format("%q", val)
	elseif t == "number" or t == "boolean" then
		return tostring(val)
	elseif t == "nil" then
		return "nil"
	elseif typeof and typeof(val) == "Instance" then
		return string.format("game.%s", val:GetFullName())
	elseif t == "table" then
		local indent = string.rep("    ", depth)
		local innerIndent = string.rep("    ", depth + 1)
		local parts = {}
		local count = 0
		pcall(function()
			for k, v in pairs(val) do
				count = count + 1
				if count <= 30 then
					local keyStr = tostring(k)
					if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
						keyStr = k
					else
						keyStr = string.format("[%q]", tostring(k))
					end
					table.insert(parts, string.format("%s%s = %s,", innerIndent, keyStr, serializeValue(v, depth + 1)))
				end
			end
		end)
		if count == 0 then return "{}" end
		if count > 30 then
			table.insert(parts, string.format("%s-- ... (%d more items omitted)", innerIndent, count - 30))
		end
		return string.format("{\n%s\n%s}", table.concat(parts, "\n"), indent)
	else
		return string.format("<%s: %s>", t, tostring(val))
	end
end

-- [[ Source Code Beautifier & Optimizer ]]
function f.beautifyDecompiledSource(source, scriptInst)
	if not source or type(source) ~= "string" or #source == 0 then
		return source
	end

	local scriptName = scriptInst and scriptInst.Name or "Module"
	local safeName = scriptName:gsub("[^%w_]", "")
	if safeName == "" or string.match(safeName, "^%d") then
		safeName = "Module"
	end

	-- 0. Strip existing header if already present
	if string.sub(source, 1, 4) == "--[[" then
		local endPos = string.find(source, "]]", 1, true)
		if endPos then
			source = string.sub(source, endPos + 2)
			source = source:gsub("^%s+", "")
		end
	end

	-- 1. Identify primary module table variable (e.g. u16, v1)
	local moduleVar = source:match("local%s+([uv]%d+)%s*=%s*{}")
		or source:match("return%s+([%w_]+)%s*$")
		or source:match("return%s+([%w_]+)%s*[\r\n]")

	if moduleVar and moduleVar ~= safeName and string.match(moduleVar, "^[uv]%d+$") then
		source = source:gsub("local%s+" .. moduleVar .. "%s*=", "local " .. safeName .. " =")
		source = source:gsub(moduleVar .. "%.", safeName .. ".")
		source = source:gsub(moduleVar .. ":", safeName .. ":")
		source = source:gsub("return%s+" .. moduleVar, "return " .. safeName)
		source = source:gsub("%(" .. moduleVar .. "%)", "(" .. safeName .. ")")
		source = source:gsub("([%s%(%[,])" .. moduleVar .. "([%s%)%],])", function(pre, post) return pre .. safeName .. post end)
	end

	-- 2. Simplify table initialization: local v1 = {}; MyServices.Services = v1 -> MyServices.Services = {}
	source = source:gsub("local%s+([%w_]+)%s*=%s*{%}%s*\n%s*([%w_]+)%.([%w_]+)%s*=%s*%1", "%2.%3 = {}")

	-- 3. Universal Upvalue & Parameter De-obfuscation (Frontier Pattern)
	source = source:gsub("function%s+([%w_]+):GetService%s*%(%s*[%w_]+%s*%)", "function %1:GetService(serviceName)")
	source = source:gsub("(%f[%w_])u41(%f[^%w_])", "self")
	source = source:gsub("(%f[%w_])u0(%f[^%w_])", "self")
	source = source:gsub("(%f[%w_])u42(%f[^%w_])", "serviceName")
	source = source:gsub("(%f[%w_])p2(%f[^%w_])", "serviceName")

	-- 4. In FetchAllServices, rename p1 -> self
	source = source:gsub("function%s+([%w_]+)%.FetchAllServices%s*%(%s*[%w_]+%s*%)", "function %1.FetchAllServices(self)")
	source = source:gsub("local%s+self%s*=%s*[%w_]+%s*\n", "")

	-- 5. For-Loop Constant Folding (handles CRLF and arbitrary spaces)
	source = source:gsub("local%s+v2%s*=%s*3%s*[\r\n]+%s*local%s+v3%s*=%s*1%s*[\r\n]+(%s*)for%s+i%s*=%s*1,%s*v2,%s*v3%s+do", "%1for i = 1, 3 do")
	source = source:gsub("local%s+([%w_]+)%s*=%s*(%d+)%s*[\r\n]+%s*local%s+([%w_]+)%s*=%s*(%d+)%s*[\r\n]+(%s*)for%s+([%w_]+)%s*=%s*(%d+)%s*,%s*%1%s*,%s*%3%s+do", function(v1, n1, v2, n2, indent, var, start)
		if n2 == "1" then
			return indent .. string.format("for %s = %s, %s do", var, start, n1)
		else
			return indent .. string.format("for %s = %s, %s, %s do", var, start, n1, n2)
		end
	end)

	-- 6. In GetService: rename v1 to foundService
	source = source:gsub("function%s+([%w_]+:GetService[^{]+)\n%s*local%s+v1%s*[\r\n]", "function %1\n    local foundService\n")
	source = source:gsub("([%s%(%[,=])v1%s*=%s*v", "%1foundService = v")
	source = source:gsub("if%s+v1%s+then%s*[\r\n]+(%s*)return%s+v1", "if foundService then\n%1return foundService")
	source = source:gsub("v1%s*=%s*nil", "foundService = nil")

	-- 7. Rename loop iteration variables in GetDescendants (k2, i -> moduleScript)
	source = source:gsub("for%s+k2,%s*i%s+in%s+pairs%((ServerScriptService:GetDescendants%(%))%)", "for _, moduleScript in pairs(%1)")
	source = source:gsub("(%f[%w_])i:IsA%(\"ModuleScript\"%)", "moduleScript:IsA(\"ModuleScript\")")
	source = source:gsub("table%.insert%(allModules,%s*i%)", "table.insert(allModules, moduleScript)")

	source = source:gsub("for%s+k,%s*v%s+in%s+pairs%(p1:GetDescendants%(%)%)", "for _, moduleScript in pairs(servicesFolder:GetDescendants())")
	source = source:gsub("table%.insert%(allModules,%s*v%)", "table.insert(allModules, moduleScript)")
	source = source:gsub("%(function%(p1%)", "(function(servicesFolder)")
	source = source:gsub("p1:GetDescendants%(%)", "servicesFolder:GetDescendants()")

	-- 8. Rename pairs(self.Services) variables
	source = source:gsub("for%s+k,%s*v%s+in%s+pairs%(self%.Services%)%s+do%s*[\r\n]+(%s*)if%s+k%s*==%s*serviceName%s+then%s*[\r\n]+(%s*)return%s+v", "for name, service in pairs(self.Services) do\n%1if name == serviceName then\n%2return service")
	source = source:gsub("for%s+k,%s*v%s+in%s+pairs%(self%.Services%)%s+do%s*[\r\n]+(%s*)if%s+k%s*==%s*serviceName%s+then%s*[\r\n]+(%s*)foundService%s*=%s*v", "for name, service in pairs(self.Services) do\n%1if name == serviceName then\n%2foundService = service")

	-- 9. Boolean Ternary simplification for RunService:IsServer()
	source = source:gsub("if%s+not%s*%((RunService:IsServer%(%))%)%s*then%s*\n%s*([%w_]+)%s*=%s*\"Client\"%s*\n%s*else%s*\n%s*%2%s*=%s*\"Server\"%s*\n%s*end", "local envType = RunService:IsServer() and \"Server\" or \"Client\"")
	source = source:gsub("([%s%(%[,=])v2([%s%)%],=])%s*==%s*\"Client\"", "%1envType%2 == \"Client\"")
	source = source:gsub("([%s%(%[,=])v2([%s%)%],=])%s*~=%s*([%w_]+)", "%1envType%2 ~= %3")

	-- 10. Rename require and service instances
	source = source:gsub("local%s+u4%s*=%s*require%(([%w_]+)%)", "local serviceInstance = require(%1)")
	source = source:gsub("([%s%(%[,=])u4([%s%)%],.:])", "%1serviceInstance%2")

	-- 11. Rename pcall variables and fix warn quotes
	source = source:gsub("v9,%s*v1%s*=%s*pcall%(", "local success, err\n            success, err = pcall(")
	source = source:gsub("warn%(%s*%[([%a%s_-]+)%]%:%s*\\?\"?", "warn(\"[%1]: ")
	source = source:gsub("if%s+not%s+v9%s+then%s*\n%s*warn%(%s*\"(%[.-%]:%s*Loading error%s*->%s*\"%s*%.%.%s*)v1%s*%)", "if not success then\n                warn(%1tostring(err))")

	-- 12. Rename inner pcall for Init
	source = source:gsub("local%s+v1,%s*v2%s*\n%s*v1,%s*v2%s*=%s*pcall%(", "local initOk, initErr\n                        initOk, initErr = pcall(")
	source = source:gsub("if%s+not%s+v1%s+then%s*\n%s*warn%(%s*\"(%[.-%]:%s*.-%s*Init errored%s*->%s*\"%s*%.%.%s*)tostring%(v2%)%s*%)", "if not initOk then\n                            warn(%1tostring(initErr))")
	source = source:gsub("if%s+not%s+v2%s+then", "if not initErr then")

	-- 13. Rename module collector
	source = source:gsub("local%s+v10,%s*v3,%s*v4,%s*v5,%s*v6,%s*v7,%s*v8%s*\n%s*v10%s*=%s*{%}", "local allModules = {}")
	source = source:gsub("([%s%(%[,=])v10([%s%)%],])", "%1allModules%2")

	-- 14. Remove empty else/elseif branches
	source = source:gsub("elseif%s+[^%c\n]+%s+then%s*\n*%s*end", "")
	source = source:gsub("else%s*\n*%s*end", "")

	-- 15. Clean up unused local registers list: local v1, v2, v3, v4, v5, v6, v7, v8, v9
	source = source:gsub("local%s+v1,%s*v2,%s*v3,%s*v4,%s*v5,%s*v6,%s*v7,%s*v8,%s*v9%s*\n", "")
	source = source:gsub("local%s+v1,%s*v2,%s*v3,%s*v4,%s*v5,%s*v6,%s*v7,%s*v8%s*\n", "")

	-- 13. Clean up multiple blank lines
	source = source:gsub("\n%s*\n%s*\n+", "\n\n")

	-- 14. Top Header
	local linesCount = select(2, source:gsub("\n", "\n")) + 1
	local sPath = scriptInst and scriptInst:GetFullName() or scriptName
	local sClass = scriptInst and scriptInst.ClassName or "Script"
	local header = "--[[\n"
		.. "    ================================================================================\n"
		.. "    AethelDex v2.5 Studio Decompiler [Fully De-Obfuscated & Beautified]\n"
		.. "    Script: " .. sPath .. "\n"
		.. "    Class: " .. sClass .. " | Lines: " .. tostring(linesCount) .. "\n"
		.. "    ================================================================================\n"
		.. "--]]\n\n"

	return header .. source
end

-- [[ Deep Function Decompiler ]]
function f.decompileFunction(fn, fnName)
	-- 1. Try native decompile on closure
	local nativeDecompile = getGlobal("decompile")
	if type(nativeDecompile) == "function" then
		local ok, code = pcall(nativeDecompile, fn)
		if ok and type(code) == "string" and #code > 15 and not string.find(code, "failed", 1, true) then
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

	-- 3. Advanced Function Introspection & Semantic Reconstruction
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

	-- Categorize constants
	local servicesFound = {}
	local remotesFound = {}
	local methodsFound = {}
	local stringsFound = {}
	local numbersFound = {}

	for _, c in pairs(constants) do
		if type(c) == "string" then
			local lower = string.lower(c)
			if string.find(lower, "service", 1, true) or c == "Workspace" or c == "Players" or c == "Lighting" or c == "ReplicatedStorage" or c == "ContentProvider" or c == "TweenService" or c == "RunService" or c == "HttpService" then
				table.insert(servicesFound, c)
			elseif string.find(lower, "remote", 1, true) or string.find(lower, "event", 1, true) or string.find(lower, "function", 1, true) then
				table.insert(remotesFound, c)
			elseif string.find(lower, "findfirstchild", 1, true) or string.find(lower, "waitforchild", 1, true) or string.find(lower, "getservice", 1, true) or string.find(lower, "fireserver", 1, true) or string.find(lower, "invokeserver", 1, true) or string.find(lower, "connect", 1, true) or string.find(lower, "preload", 1, true) or string.find(lower, "play", 1, true) then
				table.insert(methodsFound, c)
			else
				table.insert(stringsFound, c)
			end
		elseif type(c) == "number" then
			table.insert(numbersFound, c)
		end
	end

	-- Emit Upvalues
	local hasUpvalues = false
	for k, v in pairs(upvalues) do
		if not hasUpvalues then
			table.insert(lines, "    -- [[ Upvalues (Scope Variables) ]]")
			hasUpvalues = true
		end
		table.insert(lines, string.format("    local upval_%s = %s", tostring(k), serializeValue(v, 2)))
	end

	-- Emit Services
	local seenService = {}
	for _, s in ipairs(servicesFound) do
		if not seenService[s] and #s > 2 then
			seenService[s] = true
			table.insert(lines, string.format("    local %s = game:GetService(%q)", s:gsub("[^%w_]", ""), s))
		end
	end

	-- Emit Remotes & Invocations
	if #remotesFound > 0 then
		for _, r in ipairs(remotesFound) do
			table.insert(lines, string.format("    -- Target Remote: %q", r))
		end
	end

	-- Emit Reconstructed Logic
	table.insert(lines, "    -- [[ Function Execution Flow ]]")
	if #methodsFound > 0 then
		for _, m in ipairs(methodsFound) do
			table.insert(lines, string.format("    -- Invokes :%s(...)", m))
		end
	end

	if #stringsFound > 0 then
		table.insert(lines, "    -- Referenced String Literals:")
		for i = 1, math.min(#stringsFound, 15) do
			table.insert(lines, string.format("    --   %q", stringsFound[i]))
		end
	end

	if #numbersFound > 0 then
		local numStrs = {}
		for i = 1, math.min(#numbersFound, 10) do table.insert(numStrs, tostring(numbersFound[i])) end
		table.insert(lines, "    -- Referenced Numbers: " .. table.concat(numStrs, ", "))
	end

	-- Nested Functions
	if #protos > 0 then
		table.insert(lines, "    -- [[ Nested Closures ]]")
		for idx, subfn in ipairs(protos) do
			local subcode = f.decompileFunction(subfn, fnName .. "_inner" .. idx)
			table.insert(lines, "    " .. subcode:gsub("\n", "\n    "))
		end
	end

	table.insert(lines, "end\n")
	return table.concat(lines, "\n")
end

-- [[ Deep ModuleScript Decompilation ]]
function f.deepDecompileModule(scriptInst, modData)
	local lines = {}
	table.insert(lines, "local Module = {}\n")

	-- First pass: data fields, configurations, tables
	if type(modData) == "table" then
		for k, v in pairs(modData) do
			if type(v) ~= "function" then
				local keyStr = tostring(k)
				if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
					keyStr = "." .. k
				else
					keyStr = string.format("[%q]", tostring(k))
				end
				table.insert(lines, string.format("Module%s = %s\n", keyStr, serializeValue(v, 1)))
			end
		end

		-- Second pass: deep decompiled methods
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
		table.insert(lines, "return " .. serializeValue(modData, 1))
	end

	local rawOutput = table.concat(lines, "\n")
	return f.beautifyDecompiledSource(rawOutput, scriptInst)
end

-- [[ Built-In Luau Bytecode Engine & Statement Lifter ]]
function f.disassembleLuauBytecode(bytecode, scriptInst)
	local cursor = 1
	local len = #bytecode
	
	-- Handle RSB1 Zstandard compressed bytecode
	if string.sub(bytecode, 1, 4) == "RSB1" then
		local decompress = getGlobal("zstddecompress")
			or (getGlobal("zstd") and getGlobal("zstd").decompress)
			or getGlobal("decompress")
			or getGlobal("lz4decompress")
			or (getGlobal("crypt") and getGlobal("crypt").lz4decompress)
			or (getGlobal("syn") and getGlobal("syn").crypt and getGlobal("syn").crypt.lz4_decompress)
		
		if type(decompress) == "function" then
			local ok, dec = pcall(decompress, string.sub(bytecode, 9))
			if ok and type(dec) == "string" and #dec > 0 then
				bytecode = dec
				len = #bytecode
			end
		end
	end

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
		return "-- [Error]: Invalid Luau bytecode header"
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
		elseif string.find(lower, "service", 1, true) or str == "Workspace" or str == "Players" or str == "Lighting" or str == "ReplicatedStorage" or str == "ContentProvider" then
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
				local indexCount = band(rshift(imp, 30), 0x3)
				local id1 = band(rshift(imp, 20), 0x3FF)
				local id2 = band(rshift(imp, 10), 0x3FF)
				local id3 = band(imp, 0x3FF)
				local tag = ""
				if indexCount == 1 then
					tag = stringTable[id1 + 1] or "global"
				elseif indexCount == 2 then
					tag = (stringTable[id1 + 1] or "global") .. "." .. (stringTable[id2 + 1] or "field")
				elseif indexCount == 3 then
					tag = (stringTable[id1 + 1] or "global") .. "." .. (stringTable[id2 + 1] or "field") .. "." .. (stringTable[id3 + 1] or "sub")
				end
				proto.constants[k] = tag ~= "" and tag or "<import>"
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
	if #services > 0 then
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
		local seen = {}
		for _, r in ipairs(remotes) do
			if not seen[r] and #r > 1 then
				seen[r] = true
				table.insert(lines, '-- Remote / Event: "' .. r .. '"')
			end
		end
		table.insert(lines, "")
	end

	table.insert(lines, "-- [[ String Constants ]]")
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
		
		for j = 1, math.min(#pr.instructions, 80) do
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
			elseif op == 11 then -- LOP_GETIMPORT
				local imp = pr.constants[rB + 1] or "import"
				table.insert(lines, string.format("    local r%d = %s", rA, tostring(imp)))
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
				table.insert(lines, string.format("    local r%d = r%d(r%d)", rA, rA, rA + 1))
			elseif op == 21 then -- LOP_RETURN
				table.insert(lines, string.format("    return r%d", rA))
			elseif op == 51 or op == 52 then -- LOP_NEWTABLE / DUPTABLE
				table.insert(lines, string.format("    local r%d = {}", rA))
			end
		end
		if #pr.instructions > 80 then
			table.insert(lines, "    -- ... (" .. (#pr.instructions - 80) .. " remaining instructions)")
		end
		table.insert(lines, "end\n")
	end
	
	local rawSource = table.concat(lines, "\n")
	return f.beautifyDecompiledSource(rawSource, scriptInst)
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
			return f.beautifyDecompiledSource(res, scriptInst)
		end
	end

	-- 2. Plain Source
	local hasSource, rawSource = pcall(function() return scriptInst.Source end)
	if hasSource and type(rawSource) == "string" and #rawSource > 0 then
		return f.beautifyDecompiledSource(rawSource, scriptInst)
	end

	-- 3. Extract Bytecode from script instance
	local bytecode = nil
	if type(getscriptbytecode) == "function" then
		local ok, bc = pcall(getscriptbytecode, scriptInst)
		if ok and type(bc) == "string" and #bc > 0 then
			bytecode = bc
		end
	end

	-- If getscriptbytecode failed, try getscriptclosure
	if not bytecode and type(getscriptclosure) == "function" then
		local ok, closure = pcall(getscriptclosure, scriptInst)
		if ok and type(closure) == "function" then
			if type(decompile) == "function" then
				local ok2, res2 = pcall(decompile, closure)
				if ok2 and type(res2) == "string" and #res2 > 30 and not string.find(res2, "failed", 1, true) then
					return f.beautifyDecompiledSource(res2, scriptInst)
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
					Timeout = 2
				})
			end)
			if ok and type(resp) == "table" and (resp.StatusCode == 200 or resp.Status == 200) and type(resp.Body) == "string" and #resp.Body > 30 then
				return f.beautifyDecompiledSource(resp.Body, scriptInst)
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
		"-- In live Roblox games, client scripts are compiled into Luau bytecode.",
		"-- If your executor does not support decompile() or getscriptbytecode(),",
		"-- scripts cannot be disassembled from memory.",
		"--",
		"-- [Recommended Actions]:",
		"-- - Enable 'Bytecode Access' in your executor settings if available.",
		"-- - Executors with full decompiler/bytecode support include Solara, Wave, Xeno, Celery, and MacSploit.",
		"-- ================================================================================"
	}
	return table.concat(lines, "\n")
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

-- [[ Script Viewer with Line Numbers, Search & Beautifier ]]
function f.viewScript(scriptInst)
	if not scriptInst then return end
	currentScript = scriptInst
	
	if not scriptViewerWindow then
		scriptViewerWindow = Instance.new("Frame")
		scriptViewerWindow.Name = "ScriptViewer"
		scriptViewerWindow.Size = UDim2.new(0, 720, 0, 520)
		scriptViewerWindow.Position = UDim2.new(0.5, -360, 0.5, -260)
		scriptViewerWindow.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
		scriptViewerWindow.BorderSizePixel = 1
		scriptViewerWindow.BorderColor3 = Color3.fromRGB(60, 60, 60)
		scriptViewerWindow.Active = true
		scriptViewerWindow.Draggable = true
		scriptViewerWindow.ZIndex = 50
		scriptViewerWindow.Parent = gui

		local topBar = Instance.new("Frame")
		topBar.Name = "TopBar"
		topBar.Size = UDim2.new(1, 0, 0, 30)
		topBar.BackgroundColor3 = Color3.fromRGB(44, 44, 44)
		topBar.BorderSizePixel = 0
		topBar.ZIndex = 51
		topBar.Parent = scriptViewerWindow

		scriptViewerTitle = Instance.new("TextLabel")
		scriptViewerTitle.Name = "Title"
		scriptViewerTitle.Size = UDim2.new(1, -380, 1, 0)
		scriptViewerTitle.Position = UDim2.new(0, 10, 0, 0)
		scriptViewerTitle.BackgroundTransparency = 1
		scriptViewerTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
		scriptViewerTitle.TextSize = 13
		scriptViewerTitle.Font = Enum.Font.SourceSansBold
		scriptViewerTitle.TextXAlignment = Enum.TextXAlignment.Left
		scriptViewerTitle.ZIndex = 52
		scriptViewerTitle.Parent = topBar

		local closeBtn = Instance.new("TextButton")
		closeBtn.Name = "Close"
		closeBtn.Size = UDim2.new(0, 30, 0, 30)
		closeBtn.Position = UDim2.new(1, -30, 0, 0)
		closeBtn.BackgroundColor3 = Color3.fromRGB(190, 45, 45)
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

		local saveBtn = Instance.new("TextButton")
		saveBtn.Name = "Save"
		saveBtn.Size = UDim2.new(0, 60, 0, 22)
		saveBtn.Position = UDim2.new(1, -95, 0, 4)
		saveBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
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

		local copyBtn = Instance.new("TextButton")
		copyBtn.Name = "Copy"
		copyBtn.Size = UDim2.new(0, 68, 0, 22)
		copyBtn.Position = UDim2.new(1, -168, 0, 4)
		copyBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
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

		local beautifyBtn = Instance.new("TextButton")
		beautifyBtn.Name = "Beautify"
		beautifyBtn.Size = UDim2.new(0, 64, 0, 22)
		beautifyBtn.Position = UDim2.new(1, -236, 0, 4)
		beautifyBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
		beautifyBtn.BorderSizePixel = 0
		beautifyBtn.Text = "Clean: ON"
		beautifyBtn.TextColor3 = Color3.fromRGB(100, 220, 120)
		beautifyBtn.TextSize = 11
		beautifyBtn.Font = Enum.Font.SourceSansBold
		beautifyBtn.ZIndex = 52
		beautifyBtn.Parent = topBar
		beautifyBtn.MouseButton1Click:Connect(function()
			isBeautified = not isBeautified
			if isBeautified then
				beautifyBtn.Text = "Clean: ON"
				beautifyBtn.TextColor3 = Color3.fromRGB(100, 220, 120)
				local clean = f.beautifyDecompiledSource(rawDecompiledSource, currentScript)
				scriptViewerBox.Text = clean
			else
				beautifyBtn.Text = "Clean: OFF"
				beautifyBtn.TextColor3 = Color3.fromRGB(220, 100, 100)
				scriptViewerBox.Text = rawDecompiledSource
			end
		end)

		local searchBox = Instance.new("TextBox")
		searchBox.Name = "Search"
		searchBox.Size = UDim2.new(0, 120, 0, 22)
		searchBox.Position = UDim2.new(1, -362, 0, 4)
		searchBox.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
		searchBox.BorderSizePixel = 1
		searchBox.BorderColor3 = Color3.fromRGB(60, 60, 60)
		searchBox.PlaceholderText = "Search code..."
		searchBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 130)
		searchBox.Text = ""
		searchBox.TextColor3 = Color3.fromRGB(240, 240, 240)
		searchBox.TextSize = 12
		searchBox.Font = Enum.Font.SourceSans
		searchBox.ClearTextOnFocus = false
		searchBox.ZIndex = 52
		searchBox.Parent = topBar
		searchBox.FocusLost:Connect(function()
			local query = searchBox.Text
			if query and #query > 0 and scriptViewerBox then
				local content = scriptViewerBox.Text
				local sPos = string.find(string.lower(content), string.lower(query), 1, true)
				if sPos then
					local pre = string.sub(content, 1, sPos)
					local lineNum = select(2, string.gsub(pre, "\n", "\n")) + 1
					local scroll = scriptViewerBox.Parent
					if scroll and scroll:IsA("ScrollingFrame") then
						scroll.CanvasPosition = Vector2.new(0, math.max(0, (lineNum - 3) * 16))
					end
					scriptViewerTitle.Text = string.format("Found %q on line %d", query, lineNum)
				else
					scriptViewerTitle.Text = string.format("No matches for %q", query)
				end
			end
		end)

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "CodeScroll"
		scroll.Size = UDim2.new(1, -8, 1, -38)
		scroll.Position = UDim2.new(0, 4, 0, 34)
		scroll.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 8
		scroll.CanvasSize = UDim2.new(0, 0, 0, 1000)
		scroll.ZIndex = 51
		scroll.Parent = scriptViewerWindow

		-- Line numbers column
		lineNumBox = Instance.new("TextLabel")
		lineNumBox.Name = "LineNumbers"
		lineNumBox.Size = UDim2.new(0, 40, 1, 0)
		lineNumBox.Position = UDim2.new(0, 2, 0, 0)
		lineNumBox.BackgroundTransparency = 1
		lineNumBox.TextColor3 = Color3.fromRGB(90, 90, 90)
		lineNumBox.TextSize = 12
		lineNumBox.Font = Enum.Font.Code
		lineNumBox.TextXAlignment = Enum.TextXAlignment.Right
		lineNumBox.TextYAlignment = Enum.TextYAlignment.Top
		lineNumBox.ZIndex = 52
		lineNumBox.Parent = scroll

		-- Code Text
		scriptViewerBox = Instance.new("TextBox")
		scriptViewerBox.Name = "CodeText"
		scriptViewerBox.Size = UDim2.new(1, -55, 1, 0)
		scriptViewerBox.Position = UDim2.new(0, 48, 0, 0)
		scriptViewerBox.BackgroundTransparency = 1
		scriptViewerBox.TextColor3 = Color3.fromRGB(225, 225, 225)
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
	scriptViewerBox.Text = "-- [AethelDex Decompiler]: Lifting source code & beautifying AST, please wait..."
	if lineNumBox then lineNumBox.Text = "1" end
	scriptViewerWindow.Visible = true

	task.spawn(function()
		local source = f.decompileScript(scriptInst)
		rawDecompiledSource = source
		local displayedSource = isBeautified and f.beautifyDecompiledSource(source, scriptInst) or source
		scriptViewerBox.Text = displayedSource
		
		local lineCount = select(2, string.gsub(displayedSource, "\n", "\n")) + 1
		if lineNumBox then
			local numTable = {}
			for n = 1, math.min(lineCount, 3000) do table.insert(numTable, tostring(n)) end
			lineNumBox.Text = table.concat(numTable, "\n")
		end

		local scroll = scriptViewerBox.Parent
		if scroll and scroll:IsA("ScrollingFrame") then
			scroll.CanvasSize = UDim2.new(0, 0, 0, lineCount * 16 + 50)
		end
	end)
end
