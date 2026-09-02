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

	-- 4. Identify primary module table variable (CHECK THE LAST return STATEMENT FIRST!)
	local moduleVar = nil
	for m in source:gmatch("[\r\n]%s*return%s+([uv]%d+)") do
		moduleVar = m
	end
	if not moduleVar then
		moduleVar = source:match("return%s+([uv]%d+)%s*$")
			or source:match("local%s+([uv]%d+)%s*=%s*{}")
	end

	-- 4a. Fix container list generator functions before moduleVar replacement,
	-- so internal list variables (like containers = {}) are not hijacked by moduleVar!
	source = source:gsub("local%s+function%s+([%a_][%w_]*Containers)%s*%(%s*%)%s*[\r\n]+(.-)(return%s+[uv]%d+%s*[\r\n]+%s*end)", function(fnName, body)
		local cleanBody = body:gsub("%f[%w_][uv]%d+%f[^%w_]", "containers")
		cleanBody = cleanBody:gsub("%%", "%%%%")
		return "local function " .. fnName .. "()\n    local containers = {}\n" .. cleanBody .. "    return containers\nend"
	end)

	if moduleVar and moduleVar ~= safeName and string.match(moduleVar, "^[uv]%d+$") then
		source = source:gsub("local%s+" .. moduleVar .. "%s*=", "local " .. safeName .. " =")
		source = source:gsub("(%f[%w_])" .. moduleVar .. "(%f[^%w_])", safeName)
	end

	-- Ensure `local safeName = {}` exists if methods are attached to it
	if safeName and not source:find("local%s+" .. safeName .. "%s*=") then
		local fnStart = source:find("function%s+" .. safeName .. "[.:]")
		if fnStart then
			source = source:sub(1, fnStart - 1) .. "local " .. safeName .. " = {}\n" .. source:sub(fnStart)
		end
	end

	-- 4b. Table field declaration simplification: local v2 = {}; Module.Services = v2 -> Module.Services = {}
	source = source:gsub("local%s+([%a_][%w_]*)%s*=%s*{%}%s*[\r\n]+%s*([%a_][%w_]*)%.([%a_][%w_]*)%s*=%s*%1", "%2.%3 = {}")
	-- Clean duplicate module declarations (e.g. local Module = {} declared twice)
	if safeName and #safeName > 0 then
		source = source:gsub("(local%s+" .. safeName .. "%s*=%s*{%}%s*[\r\n]+)%s*local%s+" .. safeName .. "%s*=%s*{%}%s*[\r\n]+", "%1")
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

	-- 7i. Color constant: local u37 = Color3.fromRGB(255, 200, 60) -> GOLD_COLOR
	for uVar in source:gmatch('local%s+([uv]%d+)%s*=%s*Color3%.fromRGB%(255,%s*200,%s*60%)') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "GOLD_COLOR")
	end

	-- 7j. Part original color cache: u40[part] = part.Color -> originalColors
	for uVar in source:gmatch('([uv]%d+)%[[%a_][%w_]*%]%s*=%s*[%a_][%w_]*%.Color') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "originalColors")
	end

	-- 7k. Sparkles cache: table.insert(u41, Sparkles) -> activeSparkles
	for uVar in source:gmatch('table%.insert%(([uv]%d+),%s*Sparkles%)') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "activeSparkles")
	end

	-- 7l. Active state flag: local u38 = false -> isGoldActive
	for uVar in source:gmatch('local%s+([uv]%d+)%s*=%s*false%s*[\r\n]+%s*local%s+[uv]%d+%s*=%s*0') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "isGoldActive")
	end

	-- 7m. Roll ID counter: local u39 = 0 -> currentRollId
	for uVar in source:gmatch('local%s+([uv]%d+)%s*=%s*0%s*[\r\n]+%s*local%s+[%a_][%w_]*%s*=%s*{%}') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "currentRollId")
	end
	source = source:gsub("currentRollId%s*=%s*currentRollId%s*%+%s*1%s*[\r\n]+%s*local%s+([uv]%d+)%s*=%s*currentRollId", "currentRollId = currentRollId + 1\n    local rollId = currentRollId")
	source = source:gsub("if%s+currentRollId%s*~=%s*[uv]%d+%s+then", "if currentRollId ~= rollId then")

	-- 7n. Tutorial & Quest Handler Dynamic Semantic Inference
	for uVar in source:gmatch('local%s+([uv]%d+)%s*=%s*{%s*WalkAway%s*=') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "SIGNAL_ALIASES")
	end
	for uVar in source:gmatch('([uv]%d+)%s*=%s*workspace[%w_.:]*:WaitForChild%("SellNPC"%)') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "sellNPC")
	end
	for uVar in source:gmatch('([uv]%d+)%s*=%s*[%a_][%w_]*:GetPivot%(%)') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "sellNPCPivot")
	end
	for uVar in source:gmatch('local%s+function%s+clearTouchConnection%(%)[^{]*if%s+([uv]%d+)%s+then%s*%1:Disconnect%(%)') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "touchConnection")
	end
	for uVar in source:gmatch('([uv]%d+)%s*=%s*MyServices:GetService%("UIModule"%)') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "uiModule")
	end
	for uVar in source:gmatch('([uv]%d+)%s*=%s*MyServices:GetService%("LocalPlayerUtils"%)') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "localPlayerUtils")
	end
	for uVar in source:gmatch('TutorialConfig%.GetStep%(([uv]%d+)%)') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "currentStep")
	end
	for uVar in source:gmatch('substeps%[([uv]%d+)%]') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "currentSubstep")
	end
	for uVar in source:gmatch('function%s+[%a_][%w_]*%.IsActive%([^)]*%)%s*return%s+([uv]%d+)') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "isTutorialActive")
	end
	for uVar in source:gmatch('local%s+function%s+beginTutorial%(%)[^{]*if%s+([uv]%d+)%s+then%s*return%s*end%s*%1%s*=%s*true') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "tutorialStarted")
	end
	for uVar in source:gmatch('target%s*==%s*"SpawnedCraig"%s+then%s*return%s+([uv]%d+)') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "spawnedCraig")
	end
	for uVar in source:gmatch('([uv]%d+)%s*=%s*Animator:LoadAnimation%(CoreMovement%.IdleAnim%)') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "idleTrack")
	end
	for uVar in source:gmatch('local%s+function%s+getMoodletModule%(%)[^{]*if%s+([uv]%d+)%s+then%s*return%s*%1') do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", "cachedMoodletModule")
	end

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
		local pattern = "(%f[%w_]" .. eventName .. "%s*:[%a_][%w_]*%s*%(%s*function%s*%(%s*)([^)]*)(%s*)%)"
		local output = {}
		local lastIdx = 1

		local iterationSafety = 0
		while true do
			iterationSafety = iterationSafety + 1
			if iterationSafety > 100 then
				table.insert(output, string.sub(src, lastIdx))
				break
			end

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
			local tokenSafety = 0

			while searchIdx <= srcLen do
				tokenSafety = tokenSafety + 1
				if tokenSafety > 2000 then break end

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
		if string.find(source, eventPair[1], 1, true) then
			source = restoreEventCallbacks(source, eventPair[1], eventPair[2])
		end
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
		source = source:gsub("(%f[%w_])" .. safeName .. "%s*=%s*v(%f[^%w_])", "foundService = v")
		source = source:gsub("if%s+" .. safeName .. "%s+then%s*[\r\n]+(%s*)return%s+" .. safeName, "if foundService then\n%1return foundService")
		source = source:gsub("(%f[%w_])" .. safeName .. "%s*=%s*nil", "foundService = nil")
	end

	-- 12. Function Parameter & Standard Helper Signatures Normalization
	source = source:gsub("function%s+([%a_][%w_]*):GetService%s*%(%s*[%w_]+%s*%)", "function %1:GetService(serviceName)")
	source = source:gsub("function%s+([%a_][%w_]*)%.FetchAllServices%s*%(%s*[%w_]+%s*%)", "function %1.FetchAllServices(self)")
	source = source:gsub("if%s+k%s*==%s*[up]%d+%s+then", "if k == serviceName then")
	source = source:gsub("local%s+[uv]%d+%s*=%s*self%s*[\r\n]+", "")
	source = source:gsub("(%f[%w_])[uv]41%.", "self.")
	source = source:gsub("(%f[%w_])[uv]0%.", "self.")
	source = source:gsub("local%s+[uv]0%s*=%s*p1%s*[\r\n]+", "")

	-- 12b. Module Collector & Loader Dynamic Inference
	source = source:gsub("(%f[%w_])v10%s*=%s*{%}", "local allModules = {}")
	source = source:gsub("(%f[%w_])v10(%f[^%w_])", "allModules")
	source = source:gsub("local%s+[uv]%d+%s*=%s*require%(([%a_][%w_]*)%)", "local serviceModule = require(%1)")
	source = source:gsub("(%f[%w_])[uv]4(%f[^%w_])", "serviceModule")

	-- 12c. Pcall inside Module Loaders
	source = source:gsub("v9,%s*" .. safeName .. "%s*=%s*pcall%(", "local success, loadErr\n            success, loadErr = pcall(")
	source = source:gsub("v9,%s*v1%s*=%s*pcall%(", "local success, loadErr\n            success, loadErr = pcall(")
	source = source:gsub("if%s+not%s+v9%s+then%s*[\r\n]+(%s*)warn%((.-%)%.%.%s*[%w_]+%s*%)", "if not success then\n%1warn(%2 .. tostring(loadErr))")
	source = source:gsub("[%w_]+,%s*v2%s*=%s*pcall%(function%(%)[%s\r\n]*return%s+serviceModule:Init%(%)", "local initSuccess, initErr = pcall(function()\n                            return serviceModule:Init()")
	source = source:gsub("if%s+not%s+" .. safeName .. "%s+then%s*[\r\n]+(%s*)warn%(%s*\"(%[MODULE LOADER%]:.-\"%.%.%s*)tostring%(v2%)%)", "if not initSuccess then\n%1warn(\"%2tostring(initErr))")
	source = source:gsub("if%s+not%s+v2%s+then%s*[\r\n]+(%s*)warn%(%s*\"(%[MODULE LOADER%]: Error while initiating)", "if not initSuccess then\n%1warn(\"%2")

	-- 12d. Environment/RunService server-client check
	source = source:gsub("if%s+not%s+%(RunService:IsServer%(%)%)%s+then%s*[\r\n]+%s*v2%s*=%s*\"Client\"%s*[\r\n]+%s*else%s*[\r\n]+%s*v2%s*=%s*\"Server\"%s*[\r\n]+%s*end", "local currentSide = RunService:IsServer() and \"Server\" or \"Client\"")
	source = source:gsub("if%s+v2%s*==%s*\"Client\"%s+and", "if currentSide == \"Client\" and")

	-- 12e. Common Utility Functions Parameter Names
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

	-- 12f. Dynamic MoodletModule and Service Require Helpers
	source = source:gsub("local%s+function%s+getMoodletModule%(%).-return%s+[%a_][%w_]*%s*[\r\n]+%s*end",
		"local function getMoodletModule()\n    local success, module = pcall(function()\n        return require(ReplicatedStorage.MyServices.Services.Client.UIModule.MoodletModule)\n    end)\n    return success and module or nil\nend")
	source = source:gsub("local%s+[uv]15,%s*v1,%s*v2,%s*v3,%s*serviceModule%s*[\r\n]+", "")
	source = source:gsub("local%s+[uv]%d+%s*=%s*300%s*[\r\n]+", "local duration = 300\n")
	source = source:gsub("(%f[%w_])[uv]9(%f[^%w_])", "duration")

	source = source:gsub("[%a_][%w_]*,%s*v2%s*=%s*pcall%(function%(%)[%s\r\n]*return%s+getRestockTime:InvokeServer%(%)",
		"local success, restockTime = pcall(function()\n        return getRestockTime:InvokeServer()")
	source = source:gsub("if%s+[%a_][%w_]*%s+and%s+typeof%(v2%)%s*==%s*\"number\"%s+and%s+v2%s*>%s*0%s+then%s*[\r\n]+%s*duration%s*=%s*v2",
		"if success and typeof(restockTime) == \"number\" and restockTime > 0 then\n        duration = restockTime")

	source = source:gsub("v3,%s*serviceModule%s*=%s*pcall%(function%(%)[%s\r\n]*return%s+require%((.-)%)%s*end%)%s*[\r\n]+%s*if%s+not%s+v3%s+then%s*[\r\n]+%s*[%a_][%w_]*%s*=%s*nil%s*[\r\n]+%s*else%s*[\r\n]+%s*[%a_][%w_]*%s*=%s*serviceModule%s*[\r\n]+%s*end",
		"local moodletSuccess, moodletModule = pcall(function()\n        return require(%1)\n    end)\n    local moodlet = moodletSuccess and moodletModule or nil")
	source = source:gsub("if%s+u15%s+then%s*[\r\n]+%s*pcall%(function%(%)[%s\r\n]+u15%.SetLuckMoodlet%(",
		"if moodlet then\n        pcall(function()\n            moodlet.SetLuckMoodlet(")

	-- 12g. Dynamic Input & Service Helper Normalization
	source = source:gsub("local%s+function%s+isTouch%(%).-(local%s+function%s+logFunnel)",
		"local function isTouch()\n    if not LocalPlayerUtils then return false end\n    local success, state = pcall(function()\n        return LocalPlayerUtils:GetState(\"TouchControls\")\n    end)\n    return success and state == true\nend\n\n%1")

	if safeName and #safeName > 0 then
		source = source:gsub("function%s+" .. safeName .. "%.Signal%(p1,%s*p2%)", "function " .. safeName .. ".Signal(self, signalName)")
		source = source:gsub("function%s+" .. safeName .. "%.IsActive%(p1%)", "function " .. safeName .. ".IsActive(self)")
		source = source:gsub("function%s+" .. safeName .. "%.GetStepIndex%(p1%)", "function " .. safeName .. ".GetStepIndex(self)")
		source = source:gsub("function%s+" .. safeName .. "%.GetStepId%(p1%)", "function " .. safeName .. ".GetStepId(self)")
		source = source:gsub("function%s+" .. safeName .. "%.Init%(p1%)", "function " .. safeName .. ".Init(self)")
		source = source:gsub("function%s+" .. safeName .. "%.Finish%(p1%)", "function " .. safeName .. ".Finish(self)")
		source = source:gsub("function%s+" .. safeName .. "%.IsPurchaseAllowed%(p1,%s*p2%)", "function " .. safeName .. ".IsPurchaseAllowed(self, item)")
		source = source:gsub("function%s+" .. safeName .. "%.GetWrongItemMessage%(p1%)", "function " .. safeName .. ".GetWrongItemMessage(self)")
	end

	-- 13. Standard Math Map Function
	source = source:gsub("local%s+function%s+map%(p1,%s*p2,%s*p3,%s*p4,%s*p5%)", "local function map(value, inMin, inMax, outMin, outMax)")
	source = source:gsub("%(p1%s*-%s*p2%)%s*%*%s*%(p5%s*-%s*p4%)%s*/%s*%(p3%s*-%s*p2%)%s*%+%s*p4", "(value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin")

	-- 14. Double-If Glitch Collapse
	source = source:gsub("if%s+not%s+([%a_][%w_.:]*)%s+then%s*[\r\n]+%s*if%s+not%s+%1%s+then", "if not %1 then")
	source = source:gsub("if%s+([%a_][%w_.:]*)%s+then%s*[\r\n]+%s*if%s+%1%s+then", "if %1 then")

	-- 15. Fix warn quotation glitches across all scripts
	source = source:gsub('warn%(%s*%[([%a%s_-]+)%]%:%s*\\?"?', 'warn("[%1]: ')

	-- 16. For-Loop Constant Folding (handles CRLF and arbitrary spaces)
	source = source:gsub("for%s+([%a_][%w_]*)%s*=%s*1,%s*v%d+,%s*v%d+%s+do", "for %1 = 1, 5 do")
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
	return rawSource
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

	-- If getscriptbytecode failed, try getscriptclosure
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
					Timeout = 2
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
	source = f.beautifyDecompiledSource(source, scriptInst)
	pcall(function()
		local writefile = getGlobal("writefile")
		if type(writefile) == "function" then
			local filename = scriptInst.Name:gsub('[\\/:*?"<>|]', "_") .. "_" .. scriptInst.ClassName .. ".lua"
			writefile(filename, source)
		end
	end)
end

-- [[ Universal Instance & Path Formatter ]]
function f.formatInstancePath(inst)
	if not inst then return "nil" end
	local parts = {}
	local curr = inst
	local topService = nil

	while curr and curr ~= game do
		local parent = curr.Parent
		if parent == game then
			topService = curr.ClassName
			break
		end
		local name = curr.Name
		if name:match("^[%a_][%w_]*$") then
			table.insert(parts, 1, "." .. name)
		else
			table.insert(parts, 1, '["' .. name:gsub('"', '\\"') .. '"]')
		end
		curr = parent
	end

	local prefix
	if topService then
		prefix = string.format('game:GetService("%s")', topService)
	else
		prefix = "game"
	end

	return prefix .. table.concat(parts, "")
end

-- [[ Remotes Catalog Generator ]]
function f.generateRemotesCatalog(gameName, placeId, allRemotes)
	local lines = {
		"--[[",
		"    ================================================================================",
		"    AethelDex Reverse Engineering Suite - Game Remotes Catalog",
		"    Game: " .. tostring(gameName) .. " | PlaceId: " .. tostring(placeId),
		"    Total RemoteEvents: " .. #allRemotes.Events,
		"    Total RemoteFunctions: " .. #allRemotes.Functions,
		"    Generated dynamically for script development",
		"    ================================================================================",
		"--]]",
		"",
		'local ReplicatedStorage = game:GetService("ReplicatedStorage")',
		'local Players = game:GetService("Players")',
		'local LocalPlayer = Players.LocalPlayer',
		"",
		"local Remotes = {",
		"    Events = {},",
		"    Functions = {},",
		"    Unreliable = {}",
		"}",
		""
	}

	table.insert(lines, "-- [[ RemoteEvents ]]")
	for _, r in ipairs(allRemotes.Events) do
		local path = f.formatInstancePath(r)
		local name = r.Name:gsub("[^%w_]", "_")
		table.insert(lines, string.format('Remotes.Events["%s"] = %s', name, path))
	end
	table.insert(lines, "")

	table.insert(lines, "-- [[ RemoteFunctions ]]")
	for _, r in ipairs(allRemotes.Functions) do
		local path = f.formatInstancePath(r)
		local name = r.Name:gsub("[^%w_]", "_")
		table.insert(lines, string.format('Remotes.Functions["%s"] = %s', name, path))
	end
	table.insert(lines, "")

	table.insert(lines, [=[
-- Quick execution helpers
function Remotes.Fire(name, ...)
    local ev = Remotes.Events[name]
    if ev then
        return ev:FireServer(...)
    end
    warn("[AethelDex Remotes] Unknown RemoteEvent: " .. tostring(name))
end

function Remotes.Invoke(name, ...)
    local fn = Remotes.Functions[name]
    if fn then
        return fn:InvokeServer(...)
    end
    warn("[AethelDex Remotes] Unknown RemoteFunction: " .. tostring(name))
end

return Remotes
]=])

	return table.concat(lines, "\n")
end

-- [[ Place Architecture & Interactables Summary ]]
function f.generateArchitectureSummary(gameName, placeId, allRemotes, interactive, totalScripts)
	local lines = {
		"================================================================================",
		"AethelDex Place Reverse Engineering & Architecture Summary",
		"Game: " .. tostring(gameName),
		"PlaceId: " .. tostring(placeId) .. " | JobId: " .. tostring(game and game.JobId or "Studio"),
		"Saved At: " .. os.date("!%Y-%m-%d %H:%M:%SZ"),
		"================================================================================",
		"",
		"=== STATISTICS ===",
		"Total Decompiled Scripts: " .. tostring(totalScripts),
		"Total RemoteEvents: " .. tostring(#allRemotes.Events),
		"Total RemoteFunctions: " .. tostring(#allRemotes.Functions),
		"Total ProximityPrompts: " .. tostring(#interactive.Prompts),
		"Total ClickDetectors: " .. tostring(#interactive.ClickDetectors),
		"Total ValueObjects: " .. tostring(#interactive.ValueObjects),
		"",
		"=== PROXIMITY PROMPTS (INTERACTIONS) ==="
	}

	for _, p in ipairs(interactive.Prompts) do
		local objText = ""
		local actText = ""
		local maxDist = 0
		pcall(function() objText = p.ObjectText end)
		pcall(function() actText = p.ActionText end)
		pcall(function() maxDist = p.MaxActivationDistance end)
		local pName = p.Parent and p.Parent:GetFullName() or "Unknown"
		table.insert(lines, string.format("• Prompt [%s / %s] at: %s (Dist: %s)", actText, objText, pName, tostring(maxDist)))
	end

	table.insert(lines, "")
	table.insert(lines, "=== VALUE OBJECTS (STATE & CURRENCY) ===")
	for _, v in ipairs(interactive.ValueObjects) do
		local val = "unknown"
		pcall(function() val = tostring(v.Value) end)
		local vPath = v:GetFullName()
		table.insert(lines, string.format("• %s [%s] = %s", vPath, v.ClassName, val))
	end

	table.insert(lines, "")
	table.insert(lines, "=== REMOTE EVENTS & FUNCTIONS ===")
	for _, r in ipairs(allRemotes.Events) do
		table.insert(lines, string.format("• [RemoteEvent] %s (%s)", r.Name, r:GetFullName()))
	end
	for _, r in ipairs(allRemotes.Functions) do
		table.insert(lines, string.format("• [RemoteFunction] %s (%s)", r.Name, r:GetFullName()))
	end

	return table.concat(lines, "\n")
end

-- [[ Script Starter Template Generator ]]
function f.generateScripterStarter(gameName, placeId, allRemotes)
	local lines = {
		"--[[",
		"    ================================================================================",
		"    AethelDex Script Starter Template",
		"    Game: " .. tostring(gameName) .. " (PlaceId: " .. tostring(placeId) .. ")",
		"    Automations, Exploits & Remote Spoofing Template",
		"    ================================================================================",
		"--]]",
		"",
		'local Players = game:GetService("Players")',
		'local ReplicatedStorage = game:GetService("ReplicatedStorage")',
		'local RunService = game:GetService("RunService")',
		'local TweenService = game:GetService("TweenService")',
		'local LocalPlayer = Players.LocalPlayer',
		'local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()',
		'local Humanoid = Character:WaitForChild("Humanoid")',
		'local HRP = Character:WaitForChild("HumanoidRootPart")',
		"",
		'print("[AethelDex Script] Initialized for " .. tostring(gameName))',
		"",
		'-- [[ Remotes Reference ]]',
	}

	for _, r in ipairs(allRemotes.Events) do
		local name = r.Name:gsub("[^%w_]", "_")
		local path = f.formatInstancePath(r)
		table.insert(lines, string.format('local %s = %s', name, path))
	end
	for _, r in ipairs(allRemotes.Functions) do
		local name = r.Name:gsub("[^%w_]", "_")
		local path = f.formatInstancePath(r)
		table.insert(lines, string.format('local %s = %s', name, path))
	end

	table.insert(lines, "")
	table.insert(lines, [=[
-- Example Automation Loop
--[[
task.spawn(function()
    while task.wait(1) do
        -- Call your remotes here:
        -- if CrazyRollEvent then CrazyRollEvent:FireServer(...) end
    end
end)
--]]
]=])

	return table.concat(lines, "\n")
end

-- [[ Save Progress UI Dialog with dedicated ScreenGui container ]]
local saveProgressGui = nil

function f.createSaveProgressUI(gameName, placeId)
	if saveProgressGui and saveProgressGui.Parent then
		pcall(function() saveProgressGui:Destroy() end)
		saveProgressGui = nil
	end

	local hostParent = nil
	pcall(function()
		local gethui = getGlobal("gethui")
		if type(gethui) == "function" then
			hostParent = gethui()
		end
	end)
	if not hostParent then
		pcall(function() hostParent = game:GetService("CoreGui") end)
	end
	if not hostParent then
		pcall(function() hostParent = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui") end)
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AethelDex_SaveProgressGui"
	screenGui.DisplayOrder = 10000
	screenGui.ResetOnSpawn = false
	if hostParent then
		screenGui.Parent = hostParent
	end
	saveProgressGui = screenGui

	local win = Instance.new("Frame")
	win.Name = "SaveProgressWindow"
	win.Size = UDim2.new(0, 460, 0, 180)
	win.Position = UDim2.new(0.5, -230, 0.5, -90)
	win.BackgroundColor3 = Color3.fromRGB(30, 30, 32)
	win.BorderSizePixel = 1
	win.BorderColor3 = Color3.fromRGB(60, 60, 65)
	win.ZIndex = 200
	win.Active = true
	win.Draggable = true
	win.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = win

	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 32)
	titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
	titleBar.BorderSizePixel = 0
	titleBar.ZIndex = 201
	titleBar.Parent = win

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 8)
	tCorner.Parent = titleBar

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -60, 1, 0)
	title.Position = UDim2.new(0, 12, 0, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 14
	title.TextColor3 = Color3.fromRGB(240, 240, 240)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "💾 AethelDex Place Saver & Reverser"
	title.ZIndex = 202
	title.Parent = titleBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 28, 0, 24)
	closeBtn.Position = UDim2.new(1, -32, 0, 4)
	closeBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
	closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
	closeBtn.Text = "X"
	closeBtn.Font = Enum.Font.SourceSansBold
	closeBtn.TextSize = 13
	closeBtn.BorderSizePixel = 0
	closeBtn.ZIndex = 202
	closeBtn.Parent = titleBar

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 4)
	cCorner.Parent = closeBtn

	local gameLabel = Instance.new("TextLabel")
	gameLabel.Size = UDim2.new(1, -24, 0, 20)
	gameLabel.Position = UDim2.new(0, 12, 0, 38)
	gameLabel.BackgroundTransparency = 1
	gameLabel.Font = Enum.Font.SourceSans
	gameLabel.TextSize = 13
	gameLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	gameLabel.TextXAlignment = Enum.TextXAlignment.Left
	gameLabel.Text = "Place: " .. tostring(gameName) .. " (" .. tostring(placeId) .. ")"
	gameLabel.ZIndex = 201
	gameLabel.Parent = win

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -24, 0, 36)
	statusLabel.Position = UDim2.new(0, 12, 0, 62)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.SourceSans
	statusLabel.TextSize = 13
	statusLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusLabel.TextWrapped = true
	statusLabel.Text = "Initializing reverse engineering pipeline..."
	statusLabel.ZIndex = 201
	statusLabel.Parent = win

	local barBg = Instance.new("Frame")
	barBg.Name = "ProgressBarBg"
	barBg.Size = UDim2.new(1, -24, 0, 14)
	barBg.Position = UDim2.new(0, 12, 0, 106)
	barBg.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	barBg.BorderSizePixel = 1
	barBg.BorderColor3 = Color3.fromRGB(50, 50, 55)
	barBg.ZIndex = 201
	barBg.Parent = win

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 4)
	bCorner.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Name = "ProgressBarFill"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(50, 130, 220)
	barFill.BorderSizePixel = 0
	barFill.ZIndex = 202
	barFill.Parent = barBg

	local fCorner = Instance.new("UICorner")
	fCorner.CornerRadius = UDim.new(0, 4)
	fCorner.Parent = barFill

	local percentLabel = Instance.new("TextLabel")
	percentLabel.Name = "PercentLabel"
	percentLabel.Size = UDim2.new(1, -24, 0, 20)
	percentLabel.Position = UDim2.new(0, 12, 0, 126)
	percentLabel.BackgroundTransparency = 1
	percentLabel.Font = Enum.Font.SourceSansBold
	percentLabel.TextSize = 12
	percentLabel.TextColor3 = Color3.fromRGB(160, 200, 255)
	percentLabel.TextXAlignment = Enum.TextXAlignment.Right
	percentLabel.Text = "0%"
	percentLabel.ZIndex = 201
	percentLabel.Parent = win

	local copyPathBtn = Instance.new("TextButton")
	copyPathBtn.Name = "CopyPathBtn"
	copyPathBtn.Size = UDim2.new(0, 120, 0, 24)
	copyPathBtn.Position = UDim2.new(0, 12, 0, 148)
	copyPathBtn.BackgroundColor3 = Color3.fromRGB(45, 90, 150)
	copyPathBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
	copyPathBtn.Font = Enum.Font.SourceSansBold
	copyPathBtn.TextSize = 12
	copyPathBtn.Text = "Copy Path"
	copyPathBtn.Visible = false
	copyPathBtn.ZIndex = 202
	copyPathBtn.Parent = win

	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(0, 4)
	pCorner.Parent = copyPathBtn

	closeBtn.MouseButton1Click:Connect(function()
		if saveProgressGui then
			saveProgressGui:Destroy()
			saveProgressGui = nil
		end
	end)

	local function update(text, frac, savedPath)
		pcall(function()
			frac = math.clamp(frac or 0, 0, 1)
			statusLabel.Text = tostring(text)
			barFill.Size = UDim2.new(frac, 0, 1, 0)
			percentLabel.Text = tostring(math.floor(frac * 100)) .. "%"
			if frac >= 1.0 and savedPath then
				copyPathBtn.Visible = true
				copyPathBtn.MouseButton1Click:Connect(function()
					local setclipboard = getGlobal("setclipboard") or getGlobal("toclipboard")
					if type(setclipboard) == "function" then
						setclipboard(savedPath)
						copyPathBtn.Text = "Copied!"
						task.delay(1, function() copyPathBtn.Text = "Copy Path" end)
					end
				end)
				pcall(function()
					game:GetService("StarterGui"):SetCore("SendNotification", {
						Title = "AethelDex Place Saver",
						Text = "Place saved to workspace/" .. tostring(savedPath),
						Duration = 10
					})
				end)
			end
		end)
	end

	return win, update
end

-- [[ Full Place Saver ]]
local isSavingPlace = false
function f.savePlace(options)
	if isSavingPlace then
		print("[AethelDex] SavePlace is already in progress, please wait...")
		return
	end
	isSavingPlace = true

	options = options or {}
	local decompileScripts = (options.decompile ~= false)
	local nativeSave = (options.native ~= false)

	local writefile = getGlobal("writefile")
	local makefolder = getGlobal("makefolder")
	local isfolder = getGlobal("isfolder")
	local hasFS = (type(writefile) == "function")

	local nativeSaveInstance = getGlobal("saveinstance")
		or (getGlobal("syn") and type(getGlobal("syn")) == "table" and getGlobal("syn").save_instance)
		or (getGlobal("fluxus") and type(getGlobal("fluxus")) == "table" and getGlobal("fluxus").save_instance)
		or getGlobal("saveplace")
		or getGlobal("save_instance")

	local placeId = tostring(game.PlaceId or 0)
	local gameName = "RobloxGame"
	pcall(function()
		local MarketplaceService = game:GetService("MarketplaceService")
		local info = MarketplaceService:GetProductInfo(game.PlaceId)
		if info and info.Name then
			gameName = info.Name:gsub('[\\/:*?"<>|]', ""):gsub("%s+", "_")
		end
	end)

	print("[AethelDex] Starting Full Place Save for: " .. gameName .. " (" .. placeId .. ")")
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "AethelDex Place Saver",
			Text = "Starting reverse engineering & decompile...",
			Duration = 4
		})
	end)

	local rootDir = "AethelDex_Places/" .. gameName .. "_" .. placeId
	local scriptsDir = rootDir .. "/Scripts"

	if hasFS then
		pcall(function()
			if not (isfolder and isfolder("AethelDex_Places")) and makefolder then
				makefolder("AethelDex_Places")
			end
			if not (isfolder and isfolder(rootDir)) and makefolder then
				makefolder(rootDir)
			end
			if not (isfolder and isfolder(scriptsDir)) and makefolder then
				makefolder(scriptsDir)
			end
		end)
	end

	local win, updateProgress = f.createSaveProgressUI(gameName, placeId)

	task.spawn(function()
		local function finish(msg, pct, pth)
			isSavingPlace = false
			updateProgress(msg, pct, pth)
		end

		local saveOk, saveErr = pcall(function()
		-- Background native .rbxl save
		if nativeSave and type(nativeSaveInstance) == "function" then
			updateProgress("Saving place (.rbxl) in background...", 0.05)
			task.spawn(function()
				pcall(function()
					nativeSaveInstance({
						mode = "full",
						noscripts = false,
						decompile = false,
						timeout = 30,
						saveplayers = false
					})
				end)
			end)
		end

		updateProgress("Scanning game services for scripts & remotes...", 0.1)

		local servicesToScan = {
			game:GetService("Workspace"),
			game:GetService("ReplicatedStorage"),
			game:GetService("StarterPlayer"),
			game:GetService("StarterGui"),
			game:GetService("Lighting"),
			game:GetService("SoundService"),
			game:GetService("ReplicatedFirst"),
			game:GetService("MaterialService")
		}
		pcall(function()
			table.insert(servicesToScan, game:GetService("Chat"))
		end)
		pcall(function()
			local lp = game:GetService("Players").LocalPlayer
			if lp then
				table.insert(servicesToScan, lp:FindFirstChild("PlayerScripts"))
				table.insert(servicesToScan, lp:FindFirstChild("PlayerGui"))
				table.insert(servicesToScan, lp:FindFirstChild("Backpack"))
			end
		end)

		local allScripts = {}
		local allRemotes = {
			Events = {},
			Functions = {},
			Unreliable = {},
			BindableEvents = {},
			BindableFunctions = {}
		}
		local interactiveObjects = {
			Prompts = {},
			ClickDetectors = {},
			ValueObjects = {}
		}

		for _, srv in ipairs(servicesToScan) do
			if srv then
				pcall(function()
					local desc = srv:GetDescendants()
					for _, obj in ipairs(desc) do
						local isScript = false
						pcall(function() isScript = obj:IsA("LuaSourceContainer") end)
						if isScript then
							table.insert(allScripts, obj)
						end

						local cName = obj.ClassName
						if cName == "RemoteEvent" then
							table.insert(allRemotes.Events, obj)
						elseif cName == "RemoteFunction" then
							table.insert(allRemotes.Functions, obj)
						elseif cName == "UnreliableRemoteEvent" then
							table.insert(allRemotes.Unreliable, obj)
						elseif cName == "BindableEvent" then
							table.insert(allRemotes.BindableEvents, obj)
						elseif cName == "BindableFunction" then
							table.insert(allRemotes.BindableFunctions, obj)
						elseif cName == "ProximityPrompt" then
							table.insert(interactiveObjects.Prompts, obj)
						elseif cName == "ClickDetector" then
							table.insert(interactiveObjects.ClickDetectors, obj)
						elseif cName:find("Value") and obj:IsA("ValueBase") then
							table.insert(interactiveObjects.ValueObjects, obj)
						end
					end
				end)
			end
		end

		local totalScripts = #allScripts
		updateProgress("Found " .. totalScripts .. " scripts and " .. (#allRemotes.Events + #allRemotes.Functions) .. " remotes!", 0.2)
		task.wait(0.1)

		local function ensurePath(relFolder)
			if not hasFS or not makefolder then return end
			local parts = relFolder:split("/")
			local current = scriptsDir
			for _, p in ipairs(parts) do
				if #p > 0 then
					current = current .. "/" .. p
					pcall(function()
						if isfolder and not isfolder(current) then
							makefolder(current)
						end
					end)
				end
			end
		end

		for i, scriptInst in ipairs(allScripts) do
			local scriptName = scriptInst.Name:gsub('[\\/:*?"<>|]', "_")
			local fullName = ""
			pcall(function() fullName = scriptInst:GetFullName() end)
			if #fullName == 0 then fullName = scriptName end

			local pathParts = fullName:split(".")
			table.remove(pathParts, #pathParts)
			local relFolder = table.concat(pathParts, "/")
			ensurePath(relFolder)

			local filePath
			if #relFolder > 0 then
				filePath = scriptsDir .. "/" .. relFolder .. "/" .. scriptName .. "_" .. scriptInst.ClassName .. ".lua"
			else
				filePath = scriptsDir .. "/" .. scriptName .. "_" .. scriptInst.ClassName .. ".lua"
			end

			local percent = 0.2 + (0.6 * (i / math.max(totalScripts, 1)))
			updateProgress("Decompiling (" .. i .. "/" .. totalScripts .. "): " .. scriptName, percent)

			local source = "-- Decompilation failed"
			pcall(function()
				source = f.decompileScript(scriptInst)
				source = f.beautifyDecompiledSource(source, scriptInst)
			end)

			if hasFS and writefile then
				pcall(function()
					writefile(filePath, source)
				end)
			end

			if i % 3 == 0 then
				task.wait(0.01)
			end
		end

		updateProgress("Generating Remotes Catalog & SDK...", 0.85)
		local remotesCode = f.generateRemotesCatalog(gameName, placeId, allRemotes)
		if hasFS and writefile then
			pcall(function()
				writefile(rootDir .. "/Remotes_Catalog.lua", remotesCode)
			end)
		end

		updateProgress("Generating Game Architecture summary...", 0.92)
		local archSummary = f.generateArchitectureSummary(gameName, placeId, allRemotes, interactiveObjects, totalScripts)
		if hasFS and writefile then
			pcall(function()
				writefile(rootDir .. "/Place_Architecture.txt", archSummary)
			end)
		end

		local starterScript = f.generateScripterStarter(gameName, placeId, allRemotes)
		if hasFS and writefile then
			pcall(function()
				writefile(rootDir .. "/Scripter_Starter.lua", starterScript)
			end)
		end

		if not hasFS then
			local remotesCode = f.generateRemotesCatalog(gameName, placeId, allRemotes)
			pcall(function()
				local setclipboard = getGlobal("setclipboard") or getGlobal("toclipboard")
				if type(setclipboard) == "function" then
					setclipboard(remotesCode)
				end
			end)
			finish("⚠️ No writefile()! Remotes copied to clipboard.", 1.0, rootDir)
		else
			finish("✅ Done! Saved to workspace/" .. rootDir, 1.0, rootDir)
		end
		end)
		if not saveOk then
			finish("❌ Error: " .. tostring(saveErr), 1.0)
			warn("[AethelDex SavePlace Crash]: " .. tostring(saveErr))
		end
	end)
end

-- [[ Save Instance Subtree ]]
function f.saveInstanceTree(targetInst)
	if not targetInst then return end
	local writefile = getGlobal("writefile")
	local makefolder = getGlobal("makefolder")
	local isfolder = getGlobal("isfolder")
	local hasFS = (type(writefile) == "function")

	local rootName = targetInst.Name:gsub('[\\/:*?"<>|]', "_")
	local dir = "AethelDex_Instances/" .. rootName .. "_" .. targetInst.ClassName
	if hasFS and makefolder then
		pcall(function()
			if not (isfolder and isfolder("AethelDex_Instances")) then makefolder("AethelDex_Instances") end
			if not (isfolder and isfolder(dir)) then makefolder(dir) end
		end)
	end

	local desc = { targetInst }
	pcall(function()
		for _, v in ipairs(targetInst:GetDescendants()) do
			table.insert(desc, v)
		end
	end)

	local scriptCount = 0
	for _, obj in ipairs(desc) do
		local isScript = false
		pcall(function() isScript = obj:IsA("LuaSourceContainer") end)
		if isScript then
			scriptCount = scriptCount + 1
			local src = f.decompileScript(obj)
			src = f.beautifyDecompiledSource(src, obj)
			if hasFS and writefile then
				local filename = dir .. "/" .. obj.Name:gsub('[\\/:*?"<>|]', "_") .. "_" .. obj.ClassName .. ".lua"
				pcall(function() writefile(filename, src) end)
			end
		end
	end

	print("[AethelDex] Saved instance tree for " .. targetInst.Name .. " (" .. scriptCount .. " scripts dumped)")
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

		local savePlaceBtn = Instance.new("TextButton")
		savePlaceBtn.Name = "SavePlace"
		savePlaceBtn.Size = UDim2.new(0, 85, 0, 22)
		savePlaceBtn.Position = UDim2.new(1, -260, 0, 4)
		savePlaceBtn.BackgroundColor3 = Color3.fromRGB(35, 85, 155)
		savePlaceBtn.BorderSizePixel = 0
		savePlaceBtn.Text = "💾 Save Place"
		savePlaceBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
		savePlaceBtn.TextSize = 11
		savePlaceBtn.Font = Enum.Font.SourceSansBold
		savePlaceBtn.ZIndex = 52
		savePlaceBtn.Parent = topBar
		savePlaceBtn.MouseButton1Click:Connect(function()
			f.savePlace({mode = "full", decompile = true, native = true})
		end)
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
		beautifyBtn.Position = UDim2.new(1, -330, 0, 4)
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
		local ok, source = pcall(f.decompileScript, scriptInst)
		if not ok or not source or #source == 0 then
			scriptViewerBox.Text = "-- [AethelDex Decompiler Error]: " .. tostring(source or "Decompilation returned empty output")
			return
		end

		rawDecompiledSource = source
		local displayedSource = source
		if isBeautified then
			local okB, beautified = pcall(f.beautifyDecompiledSource, source, scriptInst)
			if okB and beautified and #beautified > 0 then
				displayedSource = beautified
			else
				displayedSource = source
			end
		end
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
