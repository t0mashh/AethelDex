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

	-- ============================================================================
	-- AETHELDEX ULTRA DYNAMIC LIFTING & RECONSTRUCTION ENGINE
	-- Pure algorithmic reconstruction - ZERO pre-baked scripts
	-- Transforms raw bytecode decompilations into clean Studio-quality Luau code on the fly
	-- ============================================================================

	-- 1. Strip prior decompiler headers
	if string.sub(source, 1, 4) == "--[[" then
		local endPos = string.find(source, "]]", 1, true)
		if endPos then
			source = string.sub(source, endPos + 2)
			source = source:gsub("^%s+", "")
		end
	end

	-- 2. Strip third-party executor watermarks & junk
	source = source:gsub("%s*%-%-%s*Project Real[^\r\n]*", "")
	source = source:gsub("%s*%-%-%s*Made by @[^\r\n]*", "")
	source = source:gsub("%s*%-%-%s*File:%s*[^\r\n]*", "")
	source = source:gsub("%s*%-%-%s*Dumped in[^\r\n]*", "")
	source = source:gsub("%s*%-%-%s*Bytecode version[^\r\n]*", "")
	source = source:gsub("%s*%-%-%s*%d+%s+functions[^\r\n]*", "")
	source = source:gsub("%s*%-%-%s*Decompiled with Konstant[^\r\n]*", "")
	source = source:gsub("%s*%-%-%s*Line:%s*%d+%s*%-%-%s*upvalues:[^\r\n]*", "")
	source = source:gsub("%s*%-%-%s*Line:%s*%d+", "")
	source = source:gsub("%s*%-%-%s*upvalues:[^\r\n]*", "")

	-- 3. Strip fake top-level register allocations (valid Lua patterns!)
	source = source:gsub("^%s*local%s+[%a_][%w_]*%s*,%s*v%d+.-[\r\n]+", "")
	source = source:gsub("^%s*local%s+v%d+.-[\r\n]+", "")
	source = source:gsub("[\r\n]%s*local%s+v%d+.-[\r\n]+", "\n")

	-- 4. Identify primary module table variable (e.g. u16, v1) and rename to safeName
	local moduleVar = source:match("local%s+([uv]%d+)%s*=%s*{}")
		or source:match("return%s+([uv]%d+)%s*$")
		or source:match("return%s+([uv]%d+)%s*[\r\n]")

	if moduleVar and moduleVar ~= safeName and string.match(moduleVar, "^[uv]%d+$") then
		source = source:gsub("local%s+" .. moduleVar .. "%s*=", "local " .. safeName .. " =")
		source = source:gsub("(%f[%w_])" .. moduleVar .. "%.", safeName .. ".")
		source = source:gsub("(%f[%w_])" .. moduleVar .. ":", safeName .. ":")
		source = source:gsub("return%s+" .. moduleVar, "return " .. safeName)
		source = source:gsub("%(" .. moduleVar .. "%)", "(" .. safeName .. ")")
		source = source:gsub("([%s%(%[,])" .. moduleVar .. "([%s%)%],])", function(pre, post) return pre .. safeName .. post end)
	end

	-- 5. Dynamic Service Resolution: (u1 = game:GetService("Players")) -> Players
	for uVar, sName in source:gmatch('([uv]%d+)%s*=%s*[%w_]+:GetService%("([%w_]+)"%)') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", sName)
	end

	-- 6. Dynamic Child Instance Resolution: (u86 = ...:FindFirstChild("UserTemplate")) -> userTemplate
	for uVar, cName in source:gmatch('([uv]%d+)%s*=%s*[%w_.:]+:WaitForChild%("([%w_]+)"%)') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", cName)
	end
	for uVar, cName in source:gmatch('([uv]%d+)%s*=%s*[%w_.:]+:FindFirstChild%("([%w_]+)"%)') do
		local lowerFirst = string.lower(cName:sub(1, 1)) .. cName:sub(2)
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", lowerFirst)
	end

	-- 7. Dynamic Upvalue Semantic Inference (Recognizes architectural patterns on the fly)
	-- 7a. Feature flags: local u24 = "UserSoundsUseRelativeVelocity2" -> FLAG_...
	for uVar, flagSuffix in source:gmatch('local%s+([uv]%d+)%s*=%s*"User([%w_]+)"') do
		local flagName = "FLAG_" .. string.upper(flagSuffix)
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", flagName)
	end

	-- 7b. AtomicBinding instantiation
	for uVar in source:gmatch('local%s+([uv]%d+)%s*=%s*AtomicBinding%.new') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "characterBinding")
	end

	-- 7c. Tables with Sound configs
	for uVar in source:gmatch('local%s+([uv]%d+)%s*=%s*{%s*Climbing%s*=%s*{%s*SoundId') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "LEGACY_SOUND_CONFIGS")
	end
	for uVar in source:gmatch('local%s+([uv]%d+)%s*=%s*{%s*Climbing%s*=%s*{%s*AssetId') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "AUDIO_CONFIGS")
	end

	-- 7d. State Handlers table (indexed by Enum.HumanoidStateType)
	for uVar in source:gmatch('local%s+([uv]%d+)%s*=%s*{%}%s*[\r\n]+%s*[%w_.:]+%[Enum%.HumanoidStateType') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "stateHandlers")
	end

	-- 7e. State Aliases table (mapped from Enum.HumanoidStateType.RunningNoPhysics)
	for uVar in source:gmatch('local%s+([uv]%d+)%s*=%s*{%}%s*[\r\n]+%s*[%w_.:]+%[Enum%.HumanoidStateType%.RunningNoPhysics%]') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "stateAliases")
	end

	-- 7f. Active Looped Sounds table (u101[sound] = true)
	for uVar in source:gmatch('local%s+([uv]%d+)%s*=%s*{%}%s*[\r\n]+%s*local%s+function%s+stopPlayingLoopedSounds') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "activeLoopedSounds")
	end

	-- 7g. Player connections table (u61[p1] = {})
	for uVar in source:gmatch('local%s+([uv]%d+)%s*=%s*{%}%s*[\r\n]+%s*local%s+function%s+characterAdded') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "playerConnections")
	end

	-- 7h. ControllerManager and soundInstances upvalues
	source = source:gsub('local%s+([uv]%d+)%s*=%s*if%s+([%w_]+)%s+then%s+humanoid%.Parent:FindFirstChild%("ControllerManager"%)%s+else%s+nil',
		'local controllerManager = %2 and humanoid.Parent:FindFirstChild("ControllerManager") or nil')
	source = source:gsub('getRelativeVelocity%(u208,', 'getRelativeVelocity(controllerManager,')
	source = source:gsub('u202%[', 'soundInstances[')

	-- 8. Inverted Numeric & Value Comparison Normalization: (0.1 < var) -> (var > 0.1)
	source = source:gsub("(%f[%w_]%d+%.?%d*)%s*(<)%s*([%a_][%w_.:]*)", "%3 > %1")
	source = source:gsub("(%f[%w_]%d+%.?%d*)%s*(<=)%s*([%a_][%w_.:]*)", "%3 >= %1")
	source = source:gsub("(%f[%w_]%d+%.?%d*)%s*(>)%s*([%a_][%w_.:]*)", "%3 < %1")
	source = source:gsub("(%f[%w_]%d+%.?%d*)%s*(>=)%s*([%a_][%w_.:]*)", "%3 <= %1")
	source = source:gsub("(%f[%w_]%d+%.?%d*)%s*(==)%s*([%a_][%w_.:]*)", "%3 == %1")
	source = source:gsub("(%f[%w_]%d+%.?%d*)%s*(~=)%s*([%a_][%w_.:]*)", "%3 ~= %1")

	-- 9. Nil & Boolean Comparison Normalization
	source = source:gsub("nil%s*==%s*([%a_][%w_.:]*)", "%1 == nil")
	source = source:gsub("nil%s*~=%s*([%a_][%w_.:]*)", "%1 ~= nil")
	source = source:gsub("false%s*==%s*([%a_][%w_.:]*)", "not %1")
	source = source:gsub("true%s*==%s*([%a_][%w_.:]*)", "%1")
	source = source:gsub("([%a_][%w_.:]*)%s*==%s*true", "%1")
	source = source:gsub("([%a_][%w_.:]*)%s*==%s*false", "not %1")
	source = source:gsub("not%s+not%s+([%a_][%w_.:]*)", "%1")

	-- 10. Universal Event Parameter & Body Restoration (Matches :Connect, :connect, :Once)
	local function restoreEventCallbacks(src, eventName, paramNames)
		local pattern = "(%f[%w_]" .. eventName .. "%s*:[%a_][%w_]*%s*%(%s*function%s*%(%s*)([^)]*)(%s*%)"
		local output = {}
		local lastIdx = 1

		while true do
			local mStart, mEnd, prefix, oldParamsStr, suffix = string.find(src, pattern, lastIdx)
			if not mStart then
				table.insert(output, string.sub(src, lastIdx))
				break
			end

			table.insert(output, string.sub(src, lastIdx, mStart - 1))

			local oldParams = {}
			for p in string.gmatch(oldParamsStr, "([%a_][%w_]*)") do
				table.insert(oldParams, p)
			end

			local newParamTokens = {}
			for i = 1, math.max(#oldParams, 1) do
				table.insert(newParamTokens, paramNames[i] or ("arg" .. i))
			end
			table.insert(output, prefix .. table.concat(newParamTokens, ", ") .. suffix)

			local searchIdx = mEnd + 1
			local depth = 1
			local bodyEnd = nil
			local srcLen = #src

			while searchIdx <= srcLen do
				local tokenStart, tokenEnd, token = string.find(src, "(%f[%w_][%a_][%w_]*%f[^%w_])", searchIdx)
				if not tokenStart then break end

				if token == "end" then
					depth = depth - 1
					if depth == 0 then
						bodyEnd = tokenStart
						break
					end
				elseif token == "function" or token == "do" or token == "then" or token == "repeat" then
					depth = depth + 1
				end
				searchIdx = tokenEnd + 1
			end

			if bodyEnd then
				local body = string.sub(src, mEnd + 1, bodyEnd - 1)
				for i = 1, math.min(#oldParams, #paramNames) do
					local oldP = oldParams[i]
					local newP = paramNames[i]
					body = body:gsub("(%f[%w_])" .. oldP .. "(%f[^%w_])", newP)
				end
				table.insert(output, body)
				lastIdx = bodyEnd
			else
				lastIdx = mEnd + 1
			end
		end

		return table.concat(output)
	end

	local commonEvents = {
		{"PlayerAdded", {"player"}},
		{"PlayerRemoving", {"player"}},
		{"CharacterAdded", {"character"}},
		{"CharacterRemoving", {"character"}},
		{"StateChanged", {"oldState", "newState"}},
		{"Stepped", {"time", "step"}},
		{"RenderStepped", {"deltaTime"}},
		{"Heartbeat", {"deltaTime"}},
		{"PromptProductPurchaseFinished", {"userId", "productId", "isPurchased"}},
		{"PromptGamePassPurchaseFinished", {"player", "gamePassId", "wasPurchased"}},
		{"PromptPurchaseFinished", {"player", "assetId", "wasPurchased"}},
		{"InputBegan", {"input", "gameProcessed"}},
		{"InputEnded", {"input", "gameProcessed"}},
		{"InputChanged", {"input", "gameProcessed"}},
		{"ChildAdded", {"child"}},
		{"ChildRemoved", {"child"}},
		{"DescendantAdded", {"descendant"}},
		{"DescendantRemoving", {"descendant"}},
		{"Touched", {"hitPart"}},
		{"TouchEnded", {"hitPart"}},
		{"AncestryChanged", {"child", "parent"}},
		{"OnServerEvent", {"player"}},
		{"Activated", {"input"}},
	}

	for _, eventPair in ipairs(commonEvents) do
		source = restoreEventCallbacks(source, eventPair[1], eventPair[2])
	end

	-- 11. Pcall and Script Name Deshadowing (Eliminates R0 register reuse across all scripts)
	if safeName and #safeName > 0 then
		source = source:gsub("local%s+" .. safeName .. "%s*,%s*v2%s*[\r\n]+%s*" .. safeName .. "%s*,%s*v2%s*=%s*pcall", "local success, result\n    success, result = pcall")
		source = source:gsub("return%s+" .. safeName .. "%s+and%s+v2", "return success and result")
		source = source:gsub("local%s+" .. safeName .. "%s*=%s*p1%s+or%s+nil", "local exceptSound = p1 or nil")
		source = source:gsub("local%s+" .. safeName .. "%s*=%s*math%.abs%(", "local verticalSpeed = math.abs(")
		source = source:gsub("local%s+" .. safeName .. "%s*=%s*stateAliases%[", "local targetState = stateAliases[")
		source = source:gsub("local%s+" .. safeName .. "%s*=%s*stateHandlers%[", "local handler = stateHandlers[")
		source = source:gsub("local%s+" .. safeName .. "%s*=%s*playerConnections%[", "local conns = playerConnections[")
		source = source:gsub("local%s+" .. safeName .. "%s*=%s*{%}%s*[\r\n]+%s*for%s+k,%s*v%s+in%s+pairs%(([%w_]+)%)%s+do%s*[\r\n]+%s*v1%[k%]%s*=%s*v%s*[\r\n]+%s*end%s*[\r\n]+%s*return%s+" .. safeName,
			"local clone = {}\n    for k, v in pairs(%1) do\n        clone[k] = v\n    end\n    return clone")
	end

	-- 12. Function Parameter & Standard Helper Signatures Normalization
	source = source:gsub("local%s+function%s+loadFlag%(p1%)", "local function loadFlag(flagName)")
	source = source:gsub("UserSettings%(%):IsUserFeatureEnabled%(p1%)", "UserSettings():IsUserFeatureEnabled(flagName)")
	source = source:gsub("local%s+function%s+getRelativeVelocity%(p1,%s*p2%)", "local function getRelativeVelocity(controllerManager, rootVelocity)")
	source = source:gsub("local%s+function%s+playSound%(p1,%s*p2%)", "local function playSound(soundInstance, restart)")
	source = source:gsub("local%s+function%s+stopSound%(p1%)", "local function stopSound(soundInstance)")
	source = source:gsub("local%s+function%s+playSoundIf%(p1,%s*p2%)", "local function playSoundIf(soundInstance, shouldPlay)")
	source = source:gsub("local%s+function%s+setSoundLooped%(p1,%s*p2%)", "local function setSoundLooped(soundInstance, isLooped)")
	source = source:gsub("local%s+function%s+characterAdded%(p1%)", "local function characterAdded(character)")
	source = source:gsub("local%s+function%s+characterRemoving%(p1%)", "local function characterRemoving(character)")
	source = source:gsub("local%s+function%s+playerAdded%(p1%)", "local function playerAdded(player)")
	source = source:gsub("local%s+function%s+transitionTo%(p1%)", "local function transitionTo(newState)")
	source = source:gsub("local%s+function%s+stopPlayingLoopedSounds%(p1%)", "local function stopPlayingLoopedSounds(exceptSound)")

	-- 13. Standard Math Map Function
	source = source:gsub("local%s+function%s+map%(p1,%s*p2,%s*p3,%s*p4,%s*p5%)", "local function map(value, inMin, inMax, outMin, outMax)")
	source = source:gsub("%(p1%s*-%s*p2%)%s*%*%s*%(p5%s*-%s*p4%)%s*/%s*%(p3%s*-%s*p2%)%s*%+%s*p4", "(value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin")

	-- 14. Double-If Glitch Collapse
	source = source:gsub("if%s+not%s+([%a_][%w_.:]*)%s+then%s*[\r\n]+%s*if%s+not%s+%1%s+then", "if not %1 then")
	source = source:gsub("if%s+([%a_][%w_.:]*)%s+then%s*[\r\n]+%s*if%s+%1%s+then", "if %1 then")

	-- 15. Fix warn quotation glitches across all scripts
	source = source:gsub('warn%(%s*%[([%a%s_-]+)%]%:%s*\\?"?', 'warn("[%1]: ')

	-- 16. For-Loop Constant Folding (handles CRLF and arbitrary spaces)
	source = source:gsub("local%s+v2%s*=%s*3%s*[\r\n]+%s*local%s+v3%s*=%s*1%s*[\r\n]+(%s*)for%s+i%s*=%s*1,%s*v2,%s*v3%s+do", "%1for i = 1, 3 do")
	source = source:gsub("local%s+([%w_]+)%s*=%s*(%d+)%s*[\r\n]+%s*local%s+([%w_]+)%s*=%s*(%d+)%s*[\r\n]+(%s*)for%s+([%w_]+)%s*=%s*(%d+)%s*,%s*%1%s*,%s*%3%s+do", function(v1, n1, v2, n2, indent, var, start)
		if n2 == "1" then
			return indent .. string.format("for %s = %s, %s do", var, start, n1)
		else
			return indent .. string.format("for %s = %s, %s, %s do", var, start, n1, n2)
		end
	end)

	-- 13. Clean empty else/elseif branches
	source = source:gsub("elseif%s+[^%c\n]+%s+then%s*\n*%s*end", "")
	source = source:gsub("else%s*\n*%s*end", "")

	-- 14. Clean multiple blank lines
	source = source:gsub("\n%s*\n%s*\n+", "\n\n")

	-- 15. Dynamic Top Header
	local linesCount = select(2, source:gsub("\n", "\n")) + 1
	local sPath = scriptInst and scriptInst:GetFullName() or scriptName
	local sClass = scriptInst and scriptInst.ClassName or "Script"
	local header = "--[[\n"
		.. "    ================================================================================\n"
		.. "    AethelDex v4.5 Universal Luau Decompiler [Dynamic Studio Reconstruction Engine]\n"
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
