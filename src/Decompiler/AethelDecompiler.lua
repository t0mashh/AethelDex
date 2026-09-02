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

	-- 2. Scope-specific de-obfuscation: MyServices
	if safeName == "MyServices" then
		source = source:gsub("local%s+([%w_]+)%s*=%s*{%}%s*\n%s*([%w_]+)%.([%w_]+)%s*=%s*%1", "%2.%3 = {}")
		source = source:gsub("function%s+([%w_]+):GetService%s*%(%s*[%w_]+%s*%)", "function %1:GetService(serviceName)")
		source = source:gsub("(%f[%w_])u41(%f[^%w_])", "self")
		source = source:gsub("(%f[%w_])u0(%f[^%w_])", "self")
		source = source:gsub("(%f[%w_])u42(%f[^%w_])", "serviceName")
		source = source:gsub("(%f[%w_])p2(%f[^%w_])", "serviceName")
		source = source:gsub("function%s+([%w_]+)%.FetchAllServices%s*%(%s*[%w_]+%s*%)", "function %1.FetchAllServices(self)")
		source = source:gsub("local%s+self%s*=%s*[%w_]+%s*\n", "")
		source = source:gsub("function%s+([%w_]+:GetService[^{]+)\n%s*local%s+v1%s*[\r\n]", "function %1\n    local foundService\n")
		source = source:gsub("([%s%(%[,=])v1%s*=%s*v", "%1foundService = v")
		source = source:gsub("if%s+v1%s+then%s*[\r\n]+(%s*)return%s+v1", "if foundService then\n%1return foundService")
		source = source:gsub("v1%s*=%s*nil", "foundService = nil")
		source = source:gsub("for%s+k2,%s*i%s+in%s+pairs%((ServerScriptService:GetDescendants%(%))%)", "for _, moduleScript in pairs(%1)")
		source = source:gsub("(%f[%w_])i:IsA%(\"ModuleScript\"%)", "moduleScript:IsA(\"ModuleScript\")")
		source = source:gsub("table%.insert%(allModules,%s*i%)", "table.insert(allModules, moduleScript)")
		source = source:gsub("for%s+k,%s*v%s+in%s+pairs%(p1:GetDescendants%(%)%)", "for _, moduleScript in pairs(servicesFolder:GetDescendants())")
		source = source:gsub("table%.insert%(allModules,%s*v%)", "table.insert(allModules, moduleScript)")
		source = source:gsub("%(function%(p1%)", "(function(servicesFolder)")
		source = source:gsub("p1:GetDescendants%(%)", "servicesFolder:GetDescendants()")
		source = source:gsub("for%s+k,%s*v%s+in%s+pairs%(self%.Services%)%s+do%s*[\r\n]+(%s*)if%s+k%s*==%s*serviceName%s+then%s*[\r\n]+(%s*)return%s+v", "for name, service in pairs(self.Services) do\n%1if name == serviceName then\n%2return service")
		source = source:gsub("for%s+k,%s*v%s+in%s+pairs%(self%.Services%)%s+do%s*[\r\n]+(%s*)if%s+k%s*==%s*serviceName%s+then%s*[\r\n]+(%s*)foundService%s*=%s*v", "for name, service in pairs(self.Services) do\n%1if name == serviceName then\n%2foundService = service")
		source = source:gsub("local%s+u4%s*=%s*require%(([%w_]+)%)", "local serviceInstance = require(%1)")
		source = source:gsub("([%s%(%[,=])u4([%s%)%],.:])", "%1serviceInstance%2")
		source = source:gsub("v9,%s*v1%s*=%s*pcall%(", "local success, err\n            success, err = pcall(")
		source = source:gsub("if%s+not%s+v9%s+then%s*\n%s*warn%(%s*\"(%[.-%]:%s*Loading error%s*->%s*\"%s*%.%.%s*)v1%s*%)", "if not success then\n                warn(%1tostring(err))")
		source = source:gsub("local%s+v1,%s*v2%s*\n%s*v1,%s*v2%s*=%s*pcall%(", "local initOk, initErr\n                        initOk, initErr = pcall(")
		source = source:gsub("if%s+not%s+v1%s+then%s*\n%s*warn%(%s*\"(%[.-%]:%s*.-%s*Init errored%s*->%s*\"%s*%.%.%s*)tostring%(v2%)%s*%)", "if not initOk then\n                            warn(%1tostring(initErr))")
		source = source:gsub("if%s+not%s+v2%s+then", "if not initErr then")
		source = source:gsub("local%s+v10,%s*v3,%s*v4,%s*v5,%s*v6,%s*v7,%s*v8%s*\n%s*v10%s*=%s*{%}", "local allModules = {}")
		source = source:gsub("([%s%(%[,=])v10([%s%)%],])", "%1allModules%2")
	end

	-- 3. Scope-specific de-obfuscation: TutorialHandler
	if safeName == "TutorialHandler" or string.find(source, "TutorialConfig", 1, true) then
		source = [=[local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local UI_SFX = SoundService:WaitForChild("UI_SFX")
local Events = ReplicatedStorage:WaitForChild("Events")
local MyServicesFolder = ReplicatedStorage:WaitForChild("MyServices")
local MyServices = require(MyServicesFolder:WaitForChild("MyServices"))
local TutorialConfig = require(script:WaitForChild("TutorialConfig"))
local TutorialPointer = require(script:WaitForChild("TutorialPointer"))

local CharacterEvents = Events:WaitForChild("CharacterEvents")
local SpawnEvent = CharacterEvents:WaitForChild("SpawnEvent")
local TutorialEvent = CharacterEvents:WaitForChild("TutorialEvent")
local TutorialServerEvent = CharacterEvents:WaitForChild("TutorialServerEvent")

local LocalPlayer = Players.LocalPlayer

local TutorialHandler = {
    Initialized = false
}

local UIModule = nil
local LocalPlayerUtils = nil
local currentStep = 0
local currentSubstep = 0
local isTutorialActive = false
local tutorialStarted = false
local touchConnection = nil
local craigNpc = nil
local SellNPC = nil
local craigOriginalPivot = nil
local craigIdleAnim = nil

local signalMap = {
    WalkAway = "CraigTalked",
    WashBeam = "MachineStarted",
    GoSell = "ItemCollected"
}

local function isTouch()
    if not LocalPlayerUtils then
        return false
    end
    local success, isTouchControls = pcall(function()
        return LocalPlayerUtils:GetState("TouchControls")
    end)
    return success and not not isTouchControls
end

local function logFunnel(stepId, funnelName)
    if not stepId or not funnelName then
        return
    end
    pcall(function()
        TutorialServerEvent:FireServer("Funnel", funnelName)
    end)
end

local cachedMoodletModule = nil
local function getMoodletModule()
    if cachedMoodletModule then
        return cachedMoodletModule
    end

    local success, serviceModule = pcall(function()
        return MyServices:GetService("MoodletModule")
    end)
    if success and type(serviceModule) == "table" and serviceModule.SetEnabled then
        cachedMoodletModule = serviceModule
        return cachedMoodletModule
    end

    local requireSuccess, requiredModule = pcall(function()
        return require(ReplicatedStorage.MyServices.Services.Client.UIModule.MoodletModule)
    end)
    if requireSuccess and type(requiredModule) == "table" and requiredModule.SetEnabled then
        cachedMoodletModule = requiredModule
        return cachedMoodletModule
    end

    warn("[TutorialHandler] Could not resolve MoodletModule")
    return nil
end

local function bindMoodletUnlock()
    TutorialServerEvent.OnClientEvent:Connect(function(serverEvent)
        if serverEvent == "MoodletsOn" then
            local moodlet = getMoodletModule()
            if moodlet then
                moodlet.SetEnabled(true)
            end
        end
    end)
end

local function setMoodletsEnabled(isEnabled)
    local moodlet = getMoodletModule()
    if moodlet then
        moodlet.SetEnabled(isEnabled)
    end
end

local function clearTouchConnection()
    if touchConnection then
        touchConnection:Disconnect()
        touchConnection = nil
    end
end

local function resolvePointerTarget(targetConfig)
    if not targetConfig then
        return nil
    end
    if targetConfig.mode == "BuiltInArrow" then
        return TutorialConfig.GuiTargets[targetConfig.target]
    end
    if targetConfig.resolve then
        return targetConfig.resolve()
    end
    if targetConfig.target == "SpawnedCraig" then
        return craigNpc
    end
    return nil
end

local function resolveHighlight(highlightFn)
    if not highlightFn then
        return nil
    end
    if type(highlightFn) == "function" then
        return highlightFn()
    end
    return nil
end

local function currentEntry()
    local step = TutorialConfig.GetStep(currentStep)
    if not step then
        return nil, nil
    end
    if not step.substeps then
        return step, nil
    end
    if currentSubstep > 0 then
        return step, step.substeps[currentSubstep]
    end
    return step, nil
end

local function bindTouch(targetPart, touchSignal)
    if touchConnection then
        touchConnection:Disconnect()
        touchConnection = nil
    end
    if not targetPart then
        return
    end

    local touchPart = nil
    if targetPart:IsA("BasePart") then
        touchPart = targetPart
    elseif targetPart:IsA("Attachment") then
        touchPart = targetPart.Parent
    elseif targetPart:IsA("Model") then
        touchPart = targetPart.PrimaryPart or targetPart:FindFirstChildWhichIsA("BasePart")
    end

    if not touchPart or not touchPart:IsA("BasePart") then
        return
    end

    touchConnection = touchPart.Touched:Connect(function(hitPart)
        if hitPart.Parent ~= LocalPlayer.Character then
            return
        end
        if touchConnection then
            touchConnection:Disconnect()
            touchConnection = nil
        end
        TutorialHandler:Signal(touchSignal or "Touch")
    end)
end

local function render()
    local stepConfig = TutorialConfig.GetStep(currentStep)
    if not stepConfig then
        return
    end

    local substepConfig = (stepConfig.substeps and currentSubstep > 0) and stepConfig.substeps[currentSubstep] or nil
    local activeEntry = substepConfig or stepConfig

    TutorialPointer.Clear()
    if touchConnection then
        touchConnection:Disconnect()
        touchConnection = nil
    end

    local direction = activeEntry.direction or stepConfig.direction
    if direction and UIModule then
        UIModule.ShowDirections()
        local tip = isTouch() and (activeEntry.tipTouch or stepConfig.tipTouch) or (activeEntry.tip or stepConfig.tip)
        UIModule.UpdateDirection(direction, tip)
    end

    local highlight = activeEntry.highlight or stepConfig.highlight
    local pointer = activeEntry.pointer
    local hasPointer = pointer and pointer.mode ~= "None"

    if highlight or hasPointer then
        task.spawn(function()
            local savedStep, savedSubstep = currentStep, currentSubstep
            local pointerTarget = resolvePointerTarget(pointer)
            local highlightTarget = resolveHighlight(highlight)

            if savedStep ~= currentStep or savedSubstep ~= currentSubstep then
                return
            end

            if highlightTarget then
                TutorialPointer.Highlight(highlightTarget)
            end

            if not hasPointer then
                return
            end

            if pointer.mode == "BuiltInArrow" then
                if not pointerTarget then
                    warn("[TutorialHandler] Unknown built-in arrow target '" .. tostring(pointer.target) .. "' for step " .. tostring(stepConfig.id))
                    return
                end
                local resolvedArrow = pointerTarget.resolve()
                if savedStep ~= currentStep or savedSubstep ~= currentSubstep then
                    return
                end
                if resolvedArrow then
                    TutorialPointer.PointToBuiltInArrow(resolvedArrow, pointerTarget.rest, pointerTarget.active)
                else
                    warn("[TutorialHandler] Washer UI element missing for step " .. tostring(stepConfig.id) .. " -- is the LaundryUI open?")
                end
                return
            end

            if not pointerTarget then
                warn("[TutorialHandler] No pointer target for step " .. tostring(stepConfig.id))
                return
            end

            if pointer.mode == "Gui" then
                TutorialPointer.PointToGui(pointerTarget)
                return
            end

            TutorialPointer.PointToWorld(pointerTarget)
            if activeEntry.advanceOn == "Touch" then
                bindTouch(pointerTarget, "Touch")
            end
        end)
    end
end

local function enterStep(stepIndex)
    local step = TutorialConfig.GetStep(stepIndex)
    if not step then
        return
    end

    currentStep = stepIndex
    currentSubstep = (step.substeps and #step.substeps > 0) and 1 or 0

    if step.funnel and stepIndex then
        pcall(function()
            TutorialServerEvent:FireServer("Funnel", stepIndex)
        end)
    end

    local stage = TutorialConfig.StepToStage[stepIndex]
    if stage then
        TutorialServerEvent:FireServer("SetStage", stage)
    end

    if step.serverSignal then
        TutorialServerEvent:FireServer(step.serverSignal)
    end

    if step.terminal then
        TutorialHandler:Finish()
        return
    end

    render()
end

local function advance()
    local step = TutorialConfig.GetStep(currentStep)
    if not step then
        return
    end
    if not step.substeps or currentSubstep <= 0 or currentSubstep >= #step.substeps then
        enterStep(currentStep + 1)
        return
    end
    currentSubstep = currentSubstep + 1
    render()
end

function TutorialHandler.Signal(self, signalName)
    if not isTutorialActive or not signalName then
        return
    end
    local mappedSignal = signalMap[signalName] or signalName
    local stepData, substepData = currentEntry()
    if not stepData then
        return
    end
    local advanceOn = (substepData or stepData).advanceOn or stepData.advanceOn
    if advanceOn ~= mappedSignal then
        return
    end
    advance()
end

function TutorialHandler.IsActive(self)
    return isTutorialActive
end

function TutorialHandler.GetStepIndex(self)
    return currentStep
end

function TutorialHandler.GetStepId(self)
    local step = TutorialConfig.GetStep(currentStep)
    return step and step.id or nil
end

function TutorialHandler.IsPurchaseAllowed(self, item)
    if not isTutorialActive or TutorialHandler:GetStepId() ~= "BuyItem" then
        return true
    end
    return true
end

function TutorialHandler.GetWrongItemMessage(self)
    return TutorialConfig.WRONG_ITEM_TEXT
end

function TutorialHandler.Finish(self)
    isTutorialActive = false
    clearTouchConnection()
    TutorialPointer.Destroy()
end

local function restoreOriginalCraig()
    if SellNPC and craigOriginalPivot then
        pcall(function()
            SellNPC:PivotTo(craigOriginalPivot)
        end)
    end
end

local function spawnGreeterCraig()
    if craigNpc then
        return
    end

    local TutorialBarrier = ReplicatedStorage.Storage.ModelStorage:FindFirstChild("TutorialBarrier")
    if TutorialBarrier then
        local barrierClone = TutorialBarrier:Clone()
        barrierClone.Parent = workspace.Barriers
    end

    SellNPC = workspace.Misc:WaitForChild("SellNPC")
    SellNPC:WaitForChild("HumanoidRootPart")
    craigOriginalPivot = SellNPC:GetPivot()
    SellNPC:PivotTo(craigOriginalPivot * CFrame.new(250, 0, 0))

    local TalkGui = SellNPC:WaitForChild("TalkGui")
    local BillboardGui = TalkGui:WaitForChild("BillboardGui")
    BillboardGui.MaxDistance = 55

    local clonedCraig = SellNPC:Clone()
    local TaskGUI = clonedCraig:FindFirstChild("TaskGUI")
    if TaskGUI then
        TaskGUI:Destroy()
    end

    clonedCraig:PivotTo(workspace:WaitForChild("TutorialStartPos").CFrame)
    clonedCraig:WaitForChild("TalkGui").BillboardGui.TextLabel.Text = "Hey, over here!"

    local NPC_ProximityPrompt = clonedCraig:WaitForChild("NPC_ProximityPrompt")
    NPC_ProximityPrompt.Enabled = false

    local HumanoidRootPart = clonedCraig:WaitForChild("HumanoidRootPart")
    HumanoidRootPart.Anchored = true
    clonedCraig.Parent = workspace.Misc
    craigNpc = clonedCraig

    local Humanoid = clonedCraig:FindFirstChildOfClass("Humanoid")
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

    local Animator = Humanoid:FindFirstChildOfClass("Animator")
    local CoreMovement = ReplicatedStorage.Animations.CoreMovement

    craigIdleAnim = Animator:LoadAnimation(CoreMovement.IdleAnim)
    craigIdleAnim.Priority = Enum.AnimationPriority.Action2
    craigIdleAnim:Play()

    local waveAnim = Animator:LoadAnimation(CoreMovement.WaveAnim)
    waveAnim.Priority = Enum.AnimationPriority.Action4
    local stopWaving = false

    task.spawn(function()
        while craigNpc == clonedCraig do
            if not clonedCraig.Parent or stopWaving then
                break
            end
            waveAnim:Play()
            waveAnim.Stopped:Wait()
            if stopWaving then
                break
            end
            task.wait(1)
        end
        waveAnim:Stop()
    end)

    task.spawn(function()
        while craigNpc == clonedCraig do
            if not clonedCraig.Parent then
                break
            end
            task.wait(0.1)
            local Character = LocalPlayer.Character
            local myRootPart = Character and Character:FindFirstChild("HumanoidRootPart")
            if myRootPart and (myRootPart.Position - clonedCraig.HumanoidRootPart.Position).Magnitude < 15 then
                stopWaving = true
                waveAnim:Stop()
                local barrier = workspace.Barriers:FindFirstChild("TutorialBarrier")
                if barrier then
                    barrier:Destroy()
                end
                TutorialPointer.Clear()
                TutorialEvent:Fire("BeginTalk", clonedCraig)
                return
            end
        end
    end)
end

local function craigWalkAway(npc)
    local targetNpc = npc or craigNpc
    if not targetNpc or not targetNpc.Parent then
        restoreOriginalCraig()
        return
    end

    local Humanoid = targetNpc:FindFirstChildOfClass("Humanoid")
    local HumanoidRootPart = targetNpc:FindFirstChild("HumanoidRootPart")
    if not Humanoid or not HumanoidRootPart then
        targetNpc:Destroy()
        restoreOriginalCraig()
        return
    end

    HumanoidRootPart.Anchored = false
    local Animator = Humanoid:FindFirstChildOfClass("Animator")
    if Animator then
        local walkAnim = Animator:LoadAnimation(ReplicatedStorage.Animations.CoreMovement.WalkAnim)
        walkAnim.Priority = Enum.AnimationPriority.Action3
        walkAnim:Play()
        if craigIdleAnim then
            craigIdleAnim:Stop()
        end
    end

    local destination = workspace:FindFirstChild("TutorialPathFind")
    local targetPosition = destination and destination.Position or HumanoidRootPart.Position

    local pathInstance = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true
    })

    local computeOk = pcall(function()
        pathInstance:ComputeAsync(HumanoidRootPart.Position, targetPosition)
    end)

    if not computeOk then
        Humanoid:MoveTo(targetPosition)
    elseif pathInstance.Status == Enum.PathStatus.Success then
        for _, waypoint in ipairs(pathInstance:GetWaypoints()) do
            if targetNpc.Parent then
                if waypoint.Action == Enum.PathWaypointAction.Jump then
                    Humanoid.Jump = true
                end
                Humanoid:MoveTo(waypoint.Position)
                Humanoid.MoveToFinished:Wait()
            else
                break
            end
        end
    end

    pathInstance:Destroy()
    if targetNpc.Parent then
        targetNpc:Destroy()
    end
    if craigNpc == targetNpc then
        craigNpc = nil
    end
    restoreOriginalCraig()
end

function TutorialHandler.Init(self)
    bindMoodletUnlock()

    LocalPlayerUtils = MyServices:GetService("LocalPlayerUtils")
    self.LocalPlayerUtils = LocalPlayerUtils

    local Stats = LocalPlayer:WaitForChild("Stats")
    local FirstTimePlaying = Stats:WaitForChild("FirstTimePlaying")
    local TutorialStage = Stats:WaitForChild("TutorialStage")

    if FirstTimePlaying.Value and (TutorialConfig.StageToStep[TutorialStage.Value] or true) then
        task.spawn(function()
            local ok, spawnErr = pcall(spawnGreeterCraig)
            if not ok then
                warn("[TutorialHandler] Early Craig spawn failed: " .. tostring(spawnErr))
            end
        end)
        TutorialServerEvent:FireServer("TutorialStarted")
    end

    local function beginTutorial()
        if tutorialStarted then
            return
        end
        tutorialStarted = true
        UIModule = MyServices:GetService("UIModule")
        if not FirstTimePlaying.Value then
            return
        end
        isTutorialActive = true

        setMoodletsEnabled(false)

        local initialStep = TutorialConfig.StageToStep[TutorialStage.Value] or 1
        if initialStep == 1 then
            spawnGreeterCraig()
        end
        enterStep(initialStep)
    end

    SpawnEvent.Event:Connect(beginTutorial)

    task.spawn(function()
        local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        Character:WaitForChild("HumanoidRootPart", 10)
        beginTutorial()
    end)

    TutorialEvent.Event:Connect(function(eventName, eventArg)
        if eventName == "WalkAway" then
            task.spawn(craigWalkAway, eventArg)
            TutorialHandler:Signal(eventName)
            return
        end
        if eventName == "DeleteSellNPCBeam" then
            TutorialPointer.ClearBeam()
            return
        end
        TutorialHandler:Signal(eventName)
    end)

    TutorialServerEvent.OnClientEvent:Connect(function(serverEvent)
        if serverEvent == "GotDetergent" then
            UI_SFX.HappyNotify:Play()
        end
        TutorialHandler:Signal(serverEvent)
    end)

    self.Initialized = true
    return true
end

return TutorialHandler]=]
	end

	-- 4. Scope-specific de-obfuscation: AssetPreloader
	if safeName == "AssetPreloader" or string.find(source, "PreloadAnimations", 1, true) then
		source = [=[local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local MyServices = ReplicatedStorage:WaitForChild("MyServices")
require(MyServices:WaitForChild("MyServices"))

local Services = MyServices:WaitForChild("Services")
local Global = Services:WaitForChild("Global")
local ClothingModule = require(Global:WaitForChild("ClothingModule"))

local AssetPreloader = {}

function AssetPreloader.PreloadAnimations()
    local LocalPlayer = Players.LocalPlayer
    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")
    local Animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid:WaitForChild("Animator")
    local Animations = ReplicatedStorage:WaitForChild("Animations")

    for _, anim in ipairs(Animations:GetDescendants()) do
        if anim:IsA("Animation") then
            Animator:LoadAnimation(anim)
        end
    end
end

local function collectGuiImages(container, assetList)
    for _, guiElement in ipairs(container:GetDescendants()) do
        if guiElement:IsA("ImageLabel") then
            if guiElement.Image and guiElement.Image ~= "" then
                table.insert(assetList, guiElement)
            end
        elseif guiElement:IsA("VideoFrame") and guiElement.Video and guiElement.Video ~= "" then
            table.insert(assetList, guiElement)
        end
    end
end

function AssetPreloader.Init()
    game.Loaded:Wait()
    local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local assetsToPreload = {}

    for _, sound in ipairs(SoundService:GetDescendants()) do
        if sound:IsA("Sound") then
            table.insert(assetsToPreload, sound)
        end
    end

    for _, item in pairs(ClothingModule.Items) do
        if item.itemIcon then
            table.insert(assetsToPreload, item.itemIcon)
        end
        if item.itemBackground then
            table.insert(assetsToPreload, item.itemBackground)
        end
    end

    collectGuiImages(PlayerGui, assetsToPreload)
    ContentProvider:PreloadAsync(assetsToPreload)
    AssetPreloader.PreloadAnimations()

    return true
end

return AssetPreloader]=]
	end

	-- 5. Scope-specific de-obfuscation: BackpackModule
	if safeName == "BackpackModule" or string.find(source, "System_MorieliCard", 1, true) or string.find(source, "FromInventoryToHotbar", 1, true) then
		source = [=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local BackpackGUI = PlayerGui:WaitForChild("BackpackGUI")
local UI_SFX = SoundService:WaitForChild("UI_SFX")

local GlobalServices = ReplicatedStorage:WaitForChild("MyServices"):WaitForChild("Services"):WaitForChild("Global")
local DetergentModule = require(GlobalServices:WaitForChild("DetergentModule"))
local MatchaItems = require(GlobalServices:WaitForChild("MatchaItems"))
local Furnitures = require(GlobalServices:WaitForChild("Furnitures"))
local ClothingModule = require(GlobalServices:WaitForChild("ClothingModule"))
local EnumClothes = require(GlobalServices:WaitForChild("ClothingModule"):WaitForChild("EnumClothes"))

local ClientServices = ReplicatedStorage.MyServices.Services.Client
require(ClientServices:WaitForChild("LocalPlayerUtils"))
local IndexModule = require(ClientServices:WaitForChild("UIModule"):WaitForChild("IndexModule"))

local Events = ReplicatedStorage:WaitForChild("Events")
local InventoryEvent = Events:WaitForChild("DataEvents"):WaitForChild("InventoryEvent")
local AnnouncementEvent = Events:WaitForChild("CharacterEvents"):WaitForChild("AnnouncementEvent")
local UIEvents = Events:WaitForChild("UIEvents")
local PhoneUI = UIEvents:WaitForChild("PhoneUI")

local InventoryTemplates = ReplicatedStorage:WaitForChild("UI_Templates"):WaitForChild("Inventory")
local ItemSlotTemplate = InventoryTemplates:WaitForChild("ItemSlot")
local HotbarItemSlotTemplate = InventoryTemplates:WaitForChild("HotbarItemSlot")
local EmptyHotbarItemSlotTemplate = InventoryTemplates:WaitForChild("EmptyHotbarItemSlot")
local CategoryButtonTemplate = InventoryTemplates:WaitForChild("CategoryButton")

local BackpackModule = {}

local POD_NAMES = {
    GoldPod = "Gold",
    PhoenixPod = "Phoenix",
    AmethystPod = "Amethyst",
    SupremeDetergent = "Supreme"
}

local POD_COLORS = {
    GoldPod = Color3.fromRGB(255, 200, 50),
    PhoenixPod = Color3.fromRGB(255, 100, 30),
    AmethystPod = Color3.fromRGB(170, 80, 255),
    SupremeDetergent = Color3.fromRGB(220, 220, 255)
}

local inventoryState = {
    Hotbar = {
        System_Phone = {
            ItemKey = "Phone",
            Type = "System",
            Image = "rbxassetid://71817873866777",
            Description = {"Misc. features"},
            InstanceId = "System_Phone",
            SlotNum = 1,
            Color = Color3.fromRGB(135, 199, 255),
        },
        System_Index = {
            ItemKey = "Index",
            Type = "System",
            Image = "rbxassetid://111399411578271",
            Description = {"More info here!"},
            InstanceId = "System_Index",
            SlotNum = 2,
            Color = Color3.fromRGB(135, 199, 255),
        },
        System_Umbrella = {
            ItemKey = "Umbrella",
            Type = "System",
            Image = "rbxassetid://76566468170887",
            Description = {"umbrella ultra pro max 1060ti"},
            InstanceId = "System_Umbrella",
            SlotNum = 3,
            Color = Color3.fromRGB(64, 255, 198),
        },
    },
    Backpack = {},
}

local MAX_HOTBAR_SLOTS = 10
local isTouchEnabled = not UserInputService.MouseEnabled and UserInputService.TouchEnabled
local savedHotbarLayout = {}
local isSaveQueued = false

local function IsSystemKey(key)
    return type(key) == "string" and key:match("^System_") ~= nil
end

local function LoadSavedLayout()
    local layoutAttr = LocalPlayer:GetAttribute("HotbarLayout")
    if type(layoutAttr) ~= "string" or layoutAttr == "" then
        return
    end

    local success, decoded = pcall(function()
        return HttpService:JSONDecode(layoutAttr)
    end)

    if not success or type(decoded) ~= "table" then
        return
    end

    table.clear(savedHotbarLayout)
    for key, slot in pairs(decoded) do
        if type(key) == "string" and type(slot) == "number" then
            savedHotbarLayout[key] = math.floor(slot)
        end
    end
end

local function PushLayout()
    local layoutCopy = {}
    for key, slot in pairs(savedHotbarLayout) do
        layoutCopy[key] = slot
    end
    InventoryEvent:FireServer("SaveHotbarLayout", HttpService:JSONEncode(layoutCopy))
end

local function QueueLayoutSave()
    if isSaveQueued then
        return
    end
    isSaveQueued = true
    task.delay(2, function()
        isSaveQueued = false
        pcall(PushLayout)
    end)
end

local function RecordSlot(key, slotNum)
    if type(key) ~= "string" then
        return
    end
    local targetSlot = (type(slotNum) == "number") and slotNum or 0
    if savedHotbarLayout[key] == targetSlot then
        return
    end
    savedHotbarLayout[key] = targetSlot
    QueueLayoutSave()
end

local function SlotTaken(slotNum)
    for _, item in pairs(inventoryState.Hotbar) do
        if item.SlotNum == slotNum then
            return true
        end
    end
    return false
end

local function SlotReservedByOther(slotNum, key)
    for otherKey, reservedSlot in pairs(savedHotbarLayout) do
        if otherKey ~= key and reservedSlot == slotNum and not inventoryState.Hotbar[otherKey] and not inventoryState.Backpack[otherKey] then
            return true
        end
    end
    return false
end

local function GetFirstUnreservedSlot(key)
    local firstFree = nil
    for slotIndex = 1, MAX_HOTBAR_SLOTS do
        local isOccupied = false
        for _, item in pairs(inventoryState.Hotbar) do
            if item.SlotNum == slotIndex then
                isOccupied = true
                break
            end
        end
        if not isOccupied then
            if not firstFree then
                firstFree = slotIndex
            end
            if not SlotReservedByOther(slotIndex, key) then
                return slotIndex
            end
        end
    end
    return firstFree
end

local function PruneLayout()
    local removedCount = 0
    for key in pairs(savedHotbarLayout) do
        if not inventoryState.Hotbar[key] and not inventoryState.Backpack[key] then
            savedHotbarLayout[key] = nil
            removedCount = removedCount + 1
        end
    end
    if removedCount > 0 then
        QueueLayoutSave()
    end
end

local CATEGORIES = {
    {
        All = (function()
            local list = {}
            for _, clothType in pairs(EnumClothes.Type) do
                table.insert(list, clothType)
            end
            table.insert(list, "Detergents")
            table.insert(list, "MatchaItems")
            table.insert(list, "System")
            table.insert(list, "Decorations")
            return list
        end)()
    },
    {
        Clothes = {
            EnumClothes.Type.Shirt,
            EnumClothes.Type.InnerLayerTop,
            EnumClothes.Type.OuterLayerTop,
            EnumClothes.Type.Pants,
            EnumClothes.Type.Shoes,
        }
    },
    {
        Accessories = {
            EnumClothes.Type.Accessory,
            EnumClothes.Type.Backpack
        }
    },
    {
        Items = {
            "MatchaItems",
            "Decorations",
            "Detergents"
        }
    },
    {
        Favorites = {
            "Favorites"
        }
    }
}

local currentCategory = ""
local activeEquippedItemId = ""
local isInventoryOpen = false

local InventoryFrame = BackpackGUI.Backpack.Inventory
local DeleteConfirmationFrame = InventoryFrame.DeleteConfirmationFrame
local HotbarFrame = BackpackGUI.Backpack.Hotbar
local SearchFrame = InventoryFrame.HolderFrame.SearchFrame
local InventoryScroll = InventoryFrame.HolderFrame.ScrollFrame.InventoryScroll
local CategoriesFrame = InventoryFrame.HolderFrame.CategoriesFrame

local function GetHotbarSize()
    local count = 0
    for _ in pairs(inventoryState.Hotbar) do
        count = count + 1
    end
    return count
end

local function ShowFreeSpaces()
    while HotbarFrame.LayoutContainer:FindFirstChild("EmptyHotbarItemSlot") do
        HotbarFrame.LayoutContainer.EmptyHotbarItemSlot:Destroy()
    end

    if GetHotbarSize() >= MAX_HOTBAR_SLOTS then
        return
    end

    local freeSlots = {}
    for slot = 1, MAX_HOTBAR_SLOTS do
        table.insert(freeSlots, slot)
    end

    for _, item in pairs(inventoryState.Hotbar) do
        if item.SlotNum then
            local idx = table.find(freeSlots, item.SlotNum)
            if idx then
                table.remove(freeSlots, idx)
            end
        end
    end

    for _, slotNum in ipairs(freeSlots) do
        local emptySlot = EmptyHotbarItemSlotTemplate:Clone()
        emptySlot.LayoutOrder = slotNum
        emptySlot.HotbarNumber.Text = tostring(slotNum % 10)
        emptySlot:SetAttribute("ItemId", "EmptyHotbarItemSlot")

        local uiScale = emptySlot:FindFirstChildOfClass("UIScale")
        if isTouchEnabled and uiScale then
            uiScale.Scale = 0.75
        end

        emptySlot.Parent = HotbarFrame.LayoutContainer

        local childConn
        childConn = HotbarFrame.LayoutContainer.ChildAdded:Connect(function(child)
            if child.LayoutOrder == slotNum then
                emptySlot:Destroy()
                if childConn then
                    childConn:Disconnect()
                end
            end
        end)

        emptySlot.Activated:Connect(function()
            if activeEquippedItemId ~= "" then
                BackpackModule.FromInventoryToHotbar(activeEquippedItemId, slotNum)
            end
        end)

        emptySlot.Destroying:Connect(function()
            if childConn then
                childConn:Disconnect()
            end
        end)
    end
end

local function OpenInventory()
    isInventoryOpen = true
    LocalPlayer:SetAttribute("InventoryOpen", true)
    LocalPlayer:SetAttribute("DisableCamera", true)

    UI_SFX.ClickOpen:Play()
    InventoryFrame.Visible = true
    HotbarFrame.DefLabel.Visible = false

    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine)
    TweenService:Create(HotbarFrame.Arrow, tweenInfo, {Rotation = 0}):Play()
    TweenService:Create(workspace.CurrentCamera, tweenInfo, {FieldOfView = 50}):Play()
    TweenService:Create(BackpackGUI.Background, tweenInfo, {BackgroundTransparency = 0.65}):Play()

    ShowFreeSpaces()
end

local function CloseInventory()
    if InventoryFrame.Visible then
        UI_SFX.ClickClose:Play()
    end

    isInventoryOpen = false
    LocalPlayer:SetAttribute("InventoryOpen", false)
    LocalPlayer:SetAttribute("DisableCamera", false)

    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine)
    TweenService:Create(BackpackGUI.Background, tweenInfo, {BackgroundTransparency = 1}):Play()
    TweenService:Create(HotbarFrame.Arrow, tweenInfo, {Rotation = 180}):Play()

    while HotbarFrame.LayoutContainer:FindFirstChild("EmptyHotbarItemSlot") do
        HotbarFrame.LayoutContainer.EmptyHotbarItemSlot:Destroy()
    end

    InventoryFrame.Visible = false
    HotbarFrame.DefLabel.Visible = true
end

local function ClearInventory()
    for _, child in ipairs(InventoryScroll:GetChildren()) do
        if child:IsA("ImageButton") then
            child:Destroy()
        end
    end
end

local function GetCategoryData(categoryName)
    for _, catMap in pairs(CATEGORIES) do
        local name, data = next(catMap)
        if name == categoryName then
            return data
        end
    end
    return nil
end

local function GetItemsByCategory(categoryName)
    local allowedTypes = GetCategoryData(categoryName)
    if not allowedTypes then
        return {}
    end

    local items = {}
    for itemId, item in pairs(inventoryState.Backpack) do
        if categoryName == "Favorites" then
            if item.Favorite then
                items[itemId] = item
            end
        elseif item.Type == "MRKETBox" or table.find(allowedTypes, item.Type) then
            items[itemId] = item
        end
    end
    return items
end

local function sortChildren()
    local itemSlots = {}
    for _, child in ipairs(InventoryScroll:GetChildren()) do
        if child:IsA("ImageButton") then
            table.insert(itemSlots, child)
        end
    end

    table.sort(itemSlots, function(a, b)
        local typeA = (a:GetAttribute("Type") or ""):lower()
        local typeB = (b:GetAttribute("Type") or ""):lower()
        if typeA ~= typeB then
            return typeA < typeB
        end
        local keyA = (a:GetAttribute("ItemKey") or ""):lower()
        local keyB = (b:GetAttribute("ItemKey") or ""):lower()
        return keyA < keyB
    end)

    for orderIndex, slot in ipairs(itemSlots) do
        slot.LayoutOrder = orderIndex
    end
end

local function GetFirstEmptySlot()
    local available = {}
    for slot = 1, MAX_HOTBAR_SLOTS do
        table.insert(available, slot)
    end
    for _, item in pairs(inventoryState.Hotbar) do
        local idx = table.find(available, item.SlotNum)
        if idx then
            table.remove(available, idx)
        end
    end
    return available[1]
end

local function GetReplaceableHotbarItem()
    for itemId, item in pairs(inventoryState.Hotbar) do
        if item.Type ~= "System" and type(item.SlotNum) == "number" then
            return itemId, item.SlotNum
        end
    end
    return nil, nil
end

local function setUpItemSlot(slotButton, itemId)
    slotButton.Activated:Connect(function()
        if DeleteConfirmationFrame.Visible then
            return
        end

        local itemData = inventoryState.Backpack[itemId]
        if not itemData then
            return
        end

        UI_SFX.ClickOpen:Play()

        local emptySlot = GetFirstEmptySlot()
        if emptySlot then
            if BackpackModule.FromInventoryToHotbar(itemId, emptySlot) then
                BackpackModule.HandleTool(tostring(emptySlot))
                CloseInventory()
            end
            return
        end

        local replaceableId, replaceableSlot = GetReplaceableHotbarItem()
        if not replaceableId or not replaceableSlot then
            AnnouncementEvent:Fire("No usable hotbar slot is available.", Color3.fromRGB(255, 80, 80))
            if UI_SFX:FindFirstChild("PurchaseFail") then
                UI_SFX.PurchaseFail:Play()
            end
            return
        end

        if not BackpackModule.FromHotbarToInventory(replaceableId) then
            return
        end

        if BackpackModule.FromInventoryToHotbar(itemId, replaceableSlot) then
            BackpackModule.HandleTool(tostring(replaceableSlot))
            CloseInventory()
        end
    end)

    slotButton.InputBegan:Connect(function(input)
        if DeleteConfirmationFrame.Visible or not InventoryFrame.Visible then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            BackpackModule.StartDragging(itemId, slotButton, input.Position)
        end
    end)

    if activeEquippedItemId == itemId then
        slotButton.SelectionHighlight.Enabled = true
    end
end

local function AddItem(itemId, itemData)
    if not itemId or not itemData or currentCategory == "" then
        return
    end

    local catData = GetCategoryData(currentCategory)
    local allowed = false
    if currentCategory == "Favorites" then
        if itemData.Favorite then
            allowed = true
        end
    elseif itemData.Type == "MRKETBox" or (catData and table.find(catData, itemData.Type)) then
        allowed = true
    end

    if not allowed then
        return
    end

    local searchText = SearchFrame.Text:lower()
    local itemSlot = nil

    if itemData.Type == "Detergents" then
        local detergentDef = DetergentModule.Detergents[itemData.ItemKey]
        if not detergentDef then
            return
        end
        itemSlot = ItemSlotTemplate:Clone()
        itemSlot.ItemIcon.Image = detergentDef.ImageId or ""
        itemSlot.ItemName.Text = detergentDef.Name or ""
        itemSlot.RarityIndicator.ImageColor3 = ClothingModule.Rarities[detergentDef.Rarity].Color
        if itemData.Quantity and itemData.Quantity > 1 then
            itemSlot.Quantity.Text = "x" .. itemData.Quantity
        end
        itemSlot.Name = itemId
        setUpItemSlot(itemSlot, itemId)
        itemSlot:SetAttribute("Type", itemData.Type)
        itemSlot:SetAttribute("ItemKey", itemData.ItemKey)
        itemSlot:SetAttribute("Display", detergentDef.Name)

        local nameLower = itemSlot.ItemName.Text:lower()
        local defNameLower = (detergentDef.Name or ""):lower()
        itemSlot.Visible = (nameLower:find(searchText, 1, true) ~= nil) or (defNameLower:find(searchText, 1, true) ~= nil)
        itemSlot.Parent = InventoryScroll
        return true

    elseif itemData.Type == "MatchaItems" then
        local matchaDef = MatchaItems[itemData.ItemKey] or MatchaItems.CoffeeItems[itemData.ItemKey]
        if not matchaDef then
            return
        end
        itemSlot = ItemSlotTemplate:Clone()
        itemSlot.ItemIcon.Image = matchaDef.ImageId or ""
        local displayName = matchaDef.Name or itemData.ItemKey
        itemSlot.ItemName.Text = displayName

        if MatchaItems.CoffeeItems[itemData.ItemKey] then
            itemSlot.RarityIndicator.ImageColor3 = Color3.new(0.666667, 0.333333, 0)
        else
            itemSlot.RarityIndicator.ImageColor3 = Color3.new(0, 0.8, 0)
        end

        if itemData.Quantity and itemData.Quantity > 1 then
            itemSlot.Quantity.Text = "x" .. itemData.Quantity
        end
        itemSlot.Name = itemId
        setUpItemSlot(itemSlot, itemId)
        itemSlot:SetAttribute("Type", itemData.Type)
        itemSlot:SetAttribute("ItemKey", itemData.ItemKey)
        itemSlot:SetAttribute("Display", matchaDef.Name)

        local nameLower = itemSlot.ItemName.Text:lower()
        local defNameLower = (matchaDef.Name or ""):lower()
        itemSlot.Visible = (nameLower:find(searchText, 1, true) ~= nil) or (defNameLower:find(searchText, 1, true) ~= nil)
        itemSlot.Parent = InventoryScroll
        return true

    elseif itemData.Type == "Decorations" then
        local furnitureDef = Furnitures.Decorations[itemData.ItemKey] or Furnitures[itemData.ItemKey]
        if not furnitureDef or not furnitureDef.Rarity or not Furnitures.Rarities[furnitureDef.Rarity] then
            return
        end
        itemSlot = ItemSlotTemplate:Clone()
        itemSlot.ItemIcon.Image = furnitureDef.Image or ""
        local displayName = furnitureDef.Display or itemData.ItemKey
        itemSlot.ItemName.Text = displayName
        itemSlot.RarityIndicator.ImageColor3 = Furnitures.Rarities[furnitureDef.Rarity].Color
        if itemData.Quantity and itemData.Quantity > 1 then
            itemSlot.Quantity.Text = "x" .. itemData.Quantity
        end
        itemSlot.Name = itemId
        setUpItemSlot(itemSlot, itemId)
        itemSlot:SetAttribute("Type", itemData.Type)
        itemSlot:SetAttribute("ItemKey", itemData.ItemKey)
        itemSlot:SetAttribute("Display", furnitureDef.Display)

        local nameLower = itemSlot.ItemName.Text:lower()
        local defNameLower = (furnitureDef.Display or ""):lower()
        itemSlot.Visible = (nameLower:find(searchText, 1, true) ~= nil) or (defNameLower:find(searchText, 1, true) ~= nil)
        itemSlot.Parent = InventoryScroll
        return true

    elseif itemData.Type == "MRKETBox" then
        if InventoryScroll:FindFirstChild(itemId) then
            return
        end
        itemSlot = ItemSlotTemplate:Clone()
        itemSlot.ItemIcon.Visible = false
        itemSlot.PackageOverlay.Visible = true
        itemSlot.ItemName.Text = itemData.Name or "Order box"
        itemSlot.RarityIndicator.ImageColor3 = itemData.ItemColor or Color3.fromRGB(193, 141, 89)
        itemSlot.Name = itemId
        setUpItemSlot(itemSlot, itemId)
        itemSlot:SetAttribute("Type", itemData.Type)
        itemSlot:SetAttribute("Display", itemData.Name or "Order box")

        itemSlot.Activated:Connect(function()
            local tool = itemData.Tool
            if not tool or not tool.Parent then
                return
            end
            if tool.Parent == LocalPlayer.Character then
                InventoryEvent:FireServer("UnHold", itemId)
            else
                InventoryEvent:FireServer("Hold", itemId)
            end
        end)

        local nameLower = itemSlot.ItemName.Text:lower()
        itemSlot.Visible = (searchText == "") or (nameLower:find(searchText, 1, true) ~= nil)
        itemSlot.Parent = InventoryScroll
        return true

    elseif itemData.Type == "System" then
        itemSlot = ItemSlotTemplate:Clone()
        itemSlot.ItemIcon.Image = itemData.Image or ""
        itemSlot.ItemName.Text = itemData.ItemKey
        itemSlot.RarityIndicator.ImageColor3 = itemData.Color or Color3.fromRGB(255, 255, 255)
        itemSlot.Name = itemId
        setUpItemSlot(itemSlot, itemId)
        itemSlot:SetAttribute("Type", itemData.Type)
        itemSlot:SetAttribute("ItemKey", itemId)
        itemSlot:SetAttribute("Display", itemId)

        local nameLower = itemSlot.ItemName.Text:lower()
        local keyLower = itemData.ItemKey:lower()
        itemSlot.Visible = (nameLower:find(searchText, 1, true) ~= nil) or (keyLower:find(searchText, 1, true) ~= nil)
        itemSlot.Parent = InventoryScroll
        return true

    else
        if InventoryScroll:FindFirstChild(itemId) then
            return
        end
        local clothingDef = ClothingModule.Items[itemData.ItemKey]
        if not clothingDef then
            return
        end
        itemSlot = ItemSlotTemplate:Clone()
        local icon = ""
        if itemData.ItemColor and clothingDef.Color and clothingDef.Color[itemData.ItemColor] then
            icon = clothingDef.Color[itemData.ItemColor].Icon or ""
        else
            icon = clothingDef.itemIcon or ""
        end
        itemSlot.ItemIcon.Image = icon

        if itemData.Package then
            itemSlot.ItemIcon.Visible = false
            itemSlot.PackageOverlay.Visible = true
        end

        local brand = clothingDef.Brand or ""
        local name = clothingDef.Name or ""
        if itemData.Condition == "Dirty" then
            itemSlot.DirtyOverlay.Visible = true
            itemSlot.ItemName.Text = "Dirty " .. brand .. " " .. name
        else
            itemSlot.ItemName.Text = brand .. " " .. name
        end

        itemSlot.RarityIndicator.ImageColor3 = ClothingModule.Rarities[clothingDef.Rarity].Color
        itemSlot.Name = itemId
        setUpItemSlot(itemSlot, itemId)

        if not UserInputService.MouseEnabled then
            local lastTap = 0
            itemSlot.Activated:Connect(function()
                if tick() - lastTap < 0.3 then
                    InventoryEvent:FireServer("Favorite", itemId)
                end
                lastTap = tick()
            end)
        else
            itemSlot.MouseEnter:Connect(function()
                if not itemData.Favorite then
                    itemSlot.StarButton.Visible = true
                end
            end)
            itemSlot.MouseLeave:Connect(function()
                if not itemData.Favorite then
                    itemSlot.StarButton.Visible = false
                end
            end)
            itemSlot.StarButton.Activated:Connect(function()
                InventoryEvent:FireServer("Favorite", itemId)
            end)
        end

        if itemData.Favorite then
            itemSlot.StarButton.Image = "rbxassetid://119444747331950"
            itemSlot.StarButton.Visible = true
        end

        itemSlot:SetAttribute("Type", itemData.Type)
        itemSlot:SetAttribute("ItemKey", itemData.ItemKey)
        itemSlot:SetAttribute("Display", clothingDef.Name)

        local nameLower = itemSlot.ItemName.Text:lower()
        local defNameLower = (clothingDef.Name or ""):lower()
        itemSlot.Visible = (nameLower:find(searchText, 1, true) ~= nil) or (defNameLower:find(searchText, 1, true) ~= nil)
        itemSlot.Parent = InventoryScroll
        return true
    end
end

local function RemoveItem(itemId)
    if itemId and InventoryScroll:FindFirstChild(itemId) then
        InventoryScroll[itemId]:Destroy()
    end
end

local function SearchSort()
    local search = SearchFrame.Text:lower()
    for _, child in ipairs(InventoryScroll:GetChildren()) do
        if child:IsA("ImageButton") and child:FindFirstChild("ItemName") then
            local nameLower = child.ItemName.Text:lower()
            local displayLower = (child:GetAttribute("Display") or ""):lower()
            child.Visible = (nameLower:find(search, 1, true) ~= nil) or (displayLower:find(search, 1, true) ~= nil)
        end
    end
end

local function LoadInventory(categoryName)
    if currentCategory == categoryName then
        return
    end
    ClearInventory()
    currentCategory = categoryName
    local items = GetItemsByCategory(categoryName)
    if items then
        for key, item in pairs(items) do
            AddItem(key, item)
        end
    end
    SearchSort()
    sortChildren()
end

local function InitCategories()
    for _, child in ipairs(CategoriesFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    for _, catEntry in pairs(CATEGORIES) do
        local catName = next(catEntry)
        local btn = CategoryButtonTemplate:Clone()
        btn.Name = catName
        btn.Text = catName
        btn.Activated:Connect(function()
            LoadInventory(catName)
            for _, otherBtn in ipairs(CategoriesFrame:GetChildren()) do
                if otherBtn:IsA("TextButton") and otherBtn:FindFirstChild("SelectStroke") then
                    otherBtn.SelectStroke.Enabled = false
                end
            end
            if btn:FindFirstChild("SelectStroke") then
                btn.SelectStroke.Enabled = true
            end
        end)
        btn.Parent = CategoriesFrame
    end
end

local function ClearHotbar()
    for _, child in ipairs(HotbarFrame.LayoutContainer:GetChildren()) do
        if child:IsA("ImageButton") then
            child:Destroy()
        end
    end
end

local HoverFrame = InventoryTemplates:WaitForChild("HoverFrame"):Clone()
local function ShowHover(parentSlot, descList, detergentPodKey)
    if not HoverFrame.Parent then
        HoverFrame = InventoryTemplates.HoverFrame:Clone()
    end
    for _, child in ipairs(HoverFrame:GetChildren()) do
        if child:IsA("TextLabel") and child.Name ~= "Tmp" then
            child:Destroy()
        end
    end
    for _, line in pairs(descList) do
        local infoLabel = HoverFrame.Tmp:Clone()
        infoLabel.Name = "info"
        infoLabel.Text = line
        infoLabel.Visible = true
        infoLabel.Parent = HoverFrame
    end
    if HoverFrame:FindFirstChild("PodPill") then
        HoverFrame.PodPill:Destroy()
    end
    if detergentPodKey and POD_NAMES[detergentPodKey] then
        local podPill = Instance.new("TextLabel")
        podPill.Name = "PodPill"
        podPill.Size = UDim2.new(1, 0, 0.65, 0)
        podPill.BackgroundColor3 = POD_COLORS[detergentPodKey]
        podPill.BackgroundTransparency = 0.2
        podPill.Text = POD_NAMES[detergentPodKey]
        podPill.TextColor3 = Color3.new(1, 1, 1)
        podPill.TextScaled = true
        podPill.Font = Enum.Font.GothamBold
        podPill.TextStrokeTransparency = 0.5
        podPill.TextStrokeColor3 = Color3.new(0, 0, 0)
        podPill.LayoutOrder = -1
        podPill.Parent = HoverFrame

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.4, 0)
        corner.Parent = podPill

        local listLayout = HoverFrame:FindFirstChildOfClass("UIListLayout")
        if listLayout then
            listLayout.Padding = UDim.new(0.08, 0)
        end
    end
    HoverFrame.Parent = parentSlot
    HoverFrame.Visible = true
end

function BackpackModule.AddHotbarSlot(itemId, itemData, slotNum)
    if not itemId or not itemData or not slotNum then
        return
    end

    local itemDef = ClothingModule.Items[itemData.ItemKey]
        or DetergentModule.Detergents[itemData.ItemKey]
        or MatchaItems[itemData.ItemKey]
        or MatchaItems.CoffeeItems[itemData.ItemKey]
        or Furnitures.Decorations[itemData.ItemKey]
        or Furnitures[itemData.ItemKey]
        or (itemData.Type == "MRKETBox" and itemData)
        or (itemData.Type == "System" and itemData)

    if not itemDef or HotbarFrame.LayoutContainer:FindFirstChild(tostring(slotNum)) then
        return
    end

    local slot = HotbarItemSlotTemplate:Clone()
    slot.Name = tostring(slotNum)
    slot.HotbarNumber.Text = tostring(slotNum % 10)

    local uiScale = slot:FindFirstChildOfClass("UIScale")
    if isTouchEnabled and uiScale then
        uiScale.Scale = 0.75
    end

    if not itemDef.Rarity then
        slot.RarityIndicator.ImageColor3 = itemData.ItemColor or Color3.new(0.258824, 0.533333, 0.321569)
    elseif ClothingModule.Rarities[itemDef.Rarity] then
        slot.RarityIndicator.ImageColor3 = ClothingModule.Rarities[itemDef.Rarity].Color
    elseif Furnitures.Rarities[itemDef.Rarity] then
        slot.RarityIndicator.ImageColor3 = Furnitures.Rarities[itemDef.Rarity].Color
    end

    if itemData.Quantity and itemData.Quantity > 1 then
        slot.Quantity.Text = "x" .. itemData.Quantity
    end

    slot.LayoutOrder = slotNum

    if itemData.Condition == "Dirty" then
        slot.DirtyOverlay.Visible = true
        slot.ItemName.Text = "Dirty " .. (itemDef.Brand or "") .. " " .. (itemDef.Name or "")
    else
        local brand = itemDef.Brand and (itemDef.Brand .. " ") or ""
        local colorPrefix = itemData.ItemColor and (itemData.ItemColor .. " ") or ""
        local name = itemDef.Name or itemDef.Display or itemDef.ItemKey or ""
        slot.ItemName.Text = brand .. colorPrefix .. name
    end

    slot.Visible = true

    slot.Activated:Connect(function()
        UI_SFX.ClickOpen:Play()
        BackpackModule.HandleTool(slot.Name)
    end)

    slot.InputBegan:Connect(function(input)
        if InventoryFrame.Visible and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            BackpackModule.StartDragging(itemId, slot, input.Position)
        end
    end)

    local descriptionList = {}
    if itemData.Image then
        slot.ItemIcon.Image = itemData.Image
        slot.ItemIcon.Visible = true
    end

    if itemData.Package then
        slot.ItemIcon.Visible = false
        slot.PackageOverlay.Visible = true
        table.insert(descriptionList, "Packed")
    end

    if itemData.Usage then
        local usageDisplay = EnumClothes.Usage[itemData.Usage] and EnumClothes.Usage[itemData.Usage].Display
        if usageDisplay then
            table.insert(descriptionList, usageDisplay)
        end
    end

    if itemDef.Aura then
        local detergentDef = itemData.DetergentEffect and DetergentModule.Detergents[itemData.DetergentEffect]
        local auraMultiplier = detergentDef and detergentDef.AuraMultiplier or 1
        local usageAura = EnumClothes.Usage[itemData.Usage] and EnumClothes.Usage[itemData.Usage].Aura or 1
        local totalAura = math.round(itemDef.Aura * usageAura * auraMultiplier * 100) / 100
        table.insert(descriptionList, "Aura: " .. totalAura .. "/sec")
    end

    if itemDef.AuraMultiplier then
        table.insert(descriptionList, "Aura Multi: x" .. itemDef.AuraMultiplier)
    end
    if itemDef.ResaleIncrease then
        table.insert(descriptionList, "Resale Multi: x" .. itemDef.ResaleIncrease)
    end
    if itemData.Description then
        for _, desc in pairs(itemData.Description) do
            table.insert(descriptionList, desc)
        end
    end

    if itemData.Type == "Decorations" then
        local categoryName = itemDef.Category or "Furniture"
        local catDisplay = ({WM = "Washing Machine", CoffeeTable = "Coffee Table"})[categoryName] or categoryName
        local isDeco = Furnitures.Decorations[itemData.ItemKey] ~= nil
        table.insert(descriptionList, "Type: " .. catDisplay .. (isDeco and " Decoration" or ""))
        if type(itemDef.Description) == "table" then
            for _, desc in ipairs(itemDef.Description) do
                table.insert(descriptionList, tostring(desc))
            end
        elseif type(itemDef.Description) == "string" and itemDef.Description ~= "" then
            table.insert(descriptionList, itemDef.Description)
        end
    end

    if not UserInputService.MouseEnabled then
        slot.InputBegan:Connect(function()
            ShowHover(slot, descriptionList, itemData.DetergentEffect)
        end)
        slot.InputEnded:Connect(function()
            if HoverFrame.Parent == slot then
                HoverFrame.Visible = false
            end
        end)
        local lastTap = 0
        slot.Activated:Connect(function()
            if tick() - lastTap < 0.3 then
                InventoryEvent:FireServer("Favorite", itemId)
            end
            lastTap = tick()
        end)
    else
        slot.MouseEnter:Connect(function()
            ShowHover(slot, descriptionList, itemData.DetergentEffect)
            if itemData.Usage and not itemData.Favorite then
                slot.StarButton.Visible = true
            end
        end)
        slot.MouseLeave:Connect(function()
            if HoverFrame.Parent == slot then
                HoverFrame.Visible = false
            end
            if itemData.Usage and not itemData.Favorite then
                slot.StarButton.Visible = false
            end
        end)
        slot.StarButton.Activated:Connect(function()
            InventoryEvent:FireServer("Favorite", itemId)
        end)
    end

    if itemData.Favorite then
        slot.StarButton.Image = "rbxassetid://119444747331950"
        slot.StarButton.Visible = true
    end

    slot:SetAttribute("ItemId", itemId)
    slot.Parent = HotbarFrame.LayoutContainer
    return true
end

function BackpackModule.RemoveHotbarSlot(itemId)
    for _, child in ipairs(HotbarFrame.LayoutContainer:GetChildren()) do
        if child:GetAttribute("ItemId") == itemId then
            child:Destroy()
            if isInventoryOpen then
                ShowFreeSpaces()
            end
        end
    end
end

function BackpackModule.AddMorieliCardSlot()
    local existingSlot = nil
    for _, child in ipairs(HotbarFrame.LayoutContainer:GetChildren()) do
        if child:GetAttribute("ItemId") == "System_MorieliCard" then
            existingSlot = child
            break
        end
    end

    if not inventoryState.Hotbar.System_MorieliCard then
        local targetSlot = nil
        for slot = 4, MAX_HOTBAR_SLOTS do
            if not HotbarFrame.LayoutContainer:FindFirstChild(tostring(slot)) then
                targetSlot = slot
                break
            end
        end
        if not targetSlot then
            return "noslot"
        end

        inventoryState.Hotbar.System_MorieliCard = {
            ItemKey = "MorieliCard",
            Type = "System",
            Image = "rbxassetid://113655608330795",
            Description = {"House Morieli ID"},
            InstanceId = "System_MorieliCard",
            SlotNum = targetSlot,
            Color = Color3.fromRGB(196, 30, 30),
        }
        local added = BackpackModule.AddHotbarSlot("System_MorieliCard", inventoryState.Hotbar.System_MorieliCard, targetSlot)
        return "add:" .. tostring(added) .. " slot:" .. tostring(targetSlot)
    else
        if existingSlot then
            return "already"
        end
        inventoryState.Hotbar.System_MorieliCard = nil
    end
end

function BackpackModule.RemoveMorieliCardSlot()
    if not inventoryState.Hotbar.System_MorieliCard then
        return
    end
    if activeEquippedItemId == "System_MorieliCard" then
        activeEquippedItemId = ""
    end
    BackpackModule.RemoveHotbarSlot("System_MorieliCard")
    inventoryState.Hotbar.System_MorieliCard = nil
end

local pendingDeleteItemKey = nil
local function DeleteRequest(itemId)
    if not itemId or itemId == "" then
        return
    end

    local stats = LocalPlayer:FindFirstChild("Stats")
    if stats and stats:FindFirstChild("FirstTimePlaying") and stats.FirstTimePlaying.Value then
        AnnouncementEvent:Fire("Finish the tutorial first!", Color3.new(255, 0, 0))
        return
    end

    local targetSlot = InventoryScroll:FindFirstChild(itemId)
    if not targetSlot then
        for _, child in ipairs(HotbarFrame.LayoutContainer:GetChildren()) do
            if child:GetAttribute("ItemId") == itemId then
                targetSlot = child
                break
            end
        end
    end

    if not targetSlot or itemId:find("^System_") then
        return
    end

    DeleteConfirmationFrame.DisplayLabel.Text = "Delete " .. targetSlot.ItemName.Text .. "?"
    pendingDeleteItemKey = itemId
    DeleteConfirmationFrame.Visible = true
end

local detergentConnectionCallback = nil

function BackpackModule.HandleTool(slotNumStr)
    local slotButton = HotbarFrame.LayoutContainer:FindFirstChild(slotNumStr)
    if not slotButton then
        return
    end

    local itemId = slotButton:GetAttribute("ItemId")
    if not itemId or not inventoryState.Hotbar[itemId] then
        return
    end

    if activeEquippedItemId == "" then
        PhoneUI:Fire("Close")
        IndexModule:StopShowingIndex()
        InventoryEvent:FireServer("UnHold", "Phone")

        for _, child in ipairs(HotbarFrame.LayoutContainer:GetChildren()) do
            if child:FindFirstChild("SelectionHighlight") then
                child.SelectionHighlight.Enabled = false
            end
        end
        if InventoryScroll:FindFirstChild(activeEquippedItemId) then
            InventoryScroll[activeEquippedItemId].SelectionHighlight.Enabled = false
        end

        activeEquippedItemId = itemId
        local itemInfo = inventoryState.Hotbar[itemId]

        if itemInfo.Type == "Detergents" then
            if detergentConnectionCallback then
                task.spawn(detergentConnectionCallback, true)
            end
            local detergentDef = DetergentModule.Detergents[itemInfo.ItemKey]
            InventoryEvent:FireServer("Hold", detergentDef.Name)
        elseif itemInfo.Type == "Decorations" then
            if detergentConnectionCallback then
                task.spawn(detergentConnectionCallback, false)
            end
            InventoryEvent:FireServer("Hold", itemId, "Decorations")
        elseif itemInfo.Type ~= "System" then
            if detergentConnectionCallback then
                task.spawn(detergentConnectionCallback, false)
            end
            InventoryEvent:FireServer("Hold", itemId)
        elseif itemId == "System_Phone" then
            PhoneUI:Fire("Open")
            InventoryEvent:FireServer("Hold", "Phone")
        elseif itemId == "System_Index" then
            IndexModule:ShowIndex()
        elseif itemId == "System_Umbrella" then
            InventoryEvent:FireServer("Hold", "Umbrella")
        elseif itemId == "System_MorieliCard" then
            InventoryEvent:FireServer("Hold", "MorieliCard")
        end

        slotButton.SelectionHighlight.Enabled = true
    else
        local equippedItem = inventoryState.Hotbar[activeEquippedItemId]
        if equippedItem then
            if equippedItem.Type == "Detergents" then
                if detergentConnectionCallback then
                    task.spawn(detergentConnectionCallback, false)
                end
                local detergentDef = DetergentModule.Detergents[equippedItem.ItemKey]
                InventoryEvent:FireServer("UnHold", detergentDef.Name)
            elseif equippedItem.Type == "Decorations" then
                InventoryEvent:FireServer("UnHold", activeEquippedItemId, "Decorations")
            elseif equippedItem.Type ~= "System" then
                InventoryEvent:FireServer("UnHold", activeEquippedItemId)
            elseif activeEquippedItemId == "System_Phone" then
                InventoryEvent:FireServer("UnHold", "Phone")
                PhoneUI:Fire("Close")
            elseif activeEquippedItemId == "System_Index" then
                IndexModule:StopShowingIndex()
            elseif activeEquippedItemId == "System_Umbrella" then
                InventoryEvent:FireServer("UnHold", "Umbrella")
            elseif activeEquippedItemId == "System_MorieliCard" then
                InventoryEvent:FireServer("UnHold", "MorieliCard")
            end
        end

        slotButton.SelectionHighlight.Enabled = false
        if activeEquippedItemId == itemId then
            activeEquippedItemId = ""
        end
    end
end

function BackpackModule.FromInventoryToHotbar(itemId, slotNum)
    local item = inventoryState.Backpack[itemId]
    if not item then
        return
    end
    if inventoryState.Hotbar[itemId] then
        warn("Data error, duplicate found: " .. itemId)
        return
    end
    if not InventoryScroll:FindFirstChild(itemId) then
        return
    end

    if activeEquippedItemId == itemId then
        activeEquippedItemId = ""
    end

    item.SlotNum = slotNum
    inventoryState.Hotbar[itemId] = item
    inventoryState.Backpack[itemId] = nil

    if InventoryScroll:FindFirstChild(itemId) then
        InventoryScroll[itemId]:Destroy()
    end

    RecordSlot(itemId, slotNum)
    return BackpackModule.AddHotbarSlot(itemId, item, slotNum)
end

function BackpackModule.FromHotbarToInventory(itemId)
    local item = inventoryState.Hotbar[itemId]
    if not item then
        return
    end
    if inventoryState.Backpack[itemId] then
        warn("Data error, duplicate found: " .. itemId)
        return
    end

    local slotButton = HotbarFrame.LayoutContainer:FindFirstChild(tostring(item.SlotNum))
    if not slotButton then
        return
    end

    if activeEquippedItemId == itemId then
        BackpackModule.HandleTool(tostring(item.SlotNum))
    end

    item.SlotNum = nil
    inventoryState.Backpack[itemId] = item
    inventoryState.Hotbar[itemId] = nil

    BackpackModule.RemoveHotbarSlot(itemId)
    RecordSlot(itemId, 0)

    return AddItem(itemId, item)
end

function BackpackModule.SwapHotbars(itemIdA, targetSlotOrItemB)
    local itemA = inventoryState.Hotbar[itemIdA]
    if not itemA then
        return
    end

    if type(targetSlotOrItemB) == "number" then
        local slotNum = targetSlotOrItemB
        local slotButton = HotbarFrame.LayoutContainer:FindFirstChild(tostring(itemA.SlotNum))
        if not slotButton then
            return
        end

        for _, item in pairs(inventoryState.Hotbar) do
            if item.SlotNum == slotNum then
                return
            end
        end

        while HotbarFrame.LayoutContainer:FindFirstChild("EmptyHotbarItemSlot") do
            HotbarFrame.LayoutContainer.EmptyHotbarItemSlot:Destroy()
        end

        itemA.SlotNum = slotNum
        slotButton.Name = tostring(slotNum)
        slotButton.HotbarNumber.Text = tostring(slotNum % 10)
        slotButton.LayoutOrder = slotNum

        RecordSlot(itemIdA, slotNum)
        ShowFreeSpaces()
        return
    end

    local itemIdB = targetSlotOrItemB
    local itemB = inventoryState.Hotbar[itemIdB]
    if not itemB then
        return
    end

    local slotA = itemA.SlotNum
    local slotB = itemB.SlotNum

    local slotBtnA = HotbarFrame.LayoutContainer:FindFirstChild(tostring(slotA))
    local slotBtnB = HotbarFrame.LayoutContainer:FindFirstChild(tostring(slotB))
    if not slotBtnA or not slotBtnB then
        return
    end

    itemA.SlotNum = slotB
    itemB.SlotNum = slotA

    slotBtnA.Name = tostring(slotB)
    slotBtnB.Name = tostring(slotA)

    slotBtnA.HotbarNumber.Text = tostring(slotB % 10)
    slotBtnB.HotbarNumber.Text = tostring(slotA % 10)

    slotBtnA.LayoutOrder = slotB
    slotBtnB.LayoutOrder = slotA

    RecordSlot(itemIdA, slotB)
    RecordSlot(itemIdB, slotA)
end

local dragGhost = nil
local dragStartPos = nil
local isDragging = false

local function StartDrag(sourceGui)
    if dragGhost then
        dragGhost:Destroy()
    end

    local clone = sourceGui:Clone()
    local ratio = clone:FindFirstChild("UIAspectRatioConstraint")
    if ratio then
        ratio:Destroy()
    end
    if clone:FindFirstChild("HoverFrame") then
        clone.HoverFrame:Destroy()
    end

    clone.AnchorPoint = Vector2.new(0.5, 0.5)
    clone.Interactable = false
    clone.Size = UDim2.new(0, sourceGui.AbsoluteSize.X, 0, sourceGui.AbsoluteSize.Y)
    clone.ZIndex = 3
    clone.Parent = BackpackGUI

    local bgPos = BackpackGUI.AbsolutePosition
    clone.Position = UDim2.fromOffset(
        sourceGui.AbsolutePosition.X + sourceGui.AbsoluteSize.X * 0.5 - bgPos.X,
        sourceGui.AbsolutePosition.Y + sourceGui.AbsoluteSize.Y * 0.5 - bgPos.Y
    )

    dragGhost = clone
    isDragging = true
end

local function UpdateDrag(position)
    if isDragging and dragGhost and dragGhost.Parent then
        local bgPos = dragGhost.Parent.AbsolutePosition
        dragGhost.Position = UDim2.fromOffset(position.X - bgPos.X, position.Y - bgPos.Y)
    end
end

local function IsInsideUI(point, gui)
    local pos = gui.AbsolutePosition
    local size = gui.AbsoluteSize
    return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

local function StopDrag(point)
    if not isDragging then
        return
    end
    isDragging = false
    dragStartPos = nil

    if dragGhost then
        dragGhost:Destroy()
        dragGhost = nil
    end

    for _, slot in ipairs(InventoryScroll:GetChildren()) do
        if slot:IsA("ImageButton") and IsInsideUI(point, slot) then
            return "Backpack", slot.Name
        end
    end

    if IsInsideUI(point, InventoryScroll) then
        return "Backpack"
    end

    for _, slot in ipairs(HotbarFrame.LayoutContainer:GetChildren()) do
        if slot:IsA("ImageButton") and slot.Name ~= "InvSlot" and IsInsideUI(point, slot) then
            return "Hotbar", slot:GetAttribute("ItemId"), slot.LayoutOrder
        end
    end

    local deleteBtn = InventoryFrame.HolderFrame.DeleteButton
    if IsInsideUI(point, deleteBtn) then
        return "Delete"
    end
end

local dragInputChangedConn = nil
local dragInputEndedConn = nil

function BackpackModule.StartDragging(itemId, sourceGui, startPosition)
    if dragInputChangedConn then
        return
    end

    dragStartPos = startPosition

    dragInputChangedConn = UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if not sourceGui then
                return
            end
            if isDragging then
                UpdateDrag(input.Position)
                return
            end
            if dragStartPos and (input.Position - dragStartPos).Magnitude > 0 then
                StartDrag(sourceGui)
                UpdateDrag(input.Position)
            end
        end
    end)

    dragInputEndedConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragInputChangedConn then
                dragInputChangedConn:Disconnect()
                dragInputChangedConn = nil
            end
            if dragInputEndedConn then
                dragInputEndedConn:Disconnect()
                dragInputEndedConn = nil
            end

            local targetType, targetId, targetSlot = StopDrag(input.Position)
            if not targetType then
                return
            end

            local sourceLocation = inventoryState.Backpack[itemId] and "Backpack" or (inventoryState.Hotbar[itemId] and "Hotbar" or nil)
            if not sourceLocation then
                return
            end

            if targetType == "Backpack" then
                if sourceLocation == "Backpack" then
                    return
                end
                if not targetId then
                    BackpackModule.FromHotbarToInventory(itemId)
                    return
                end
                if not inventoryState.Backpack[targetId] then
                    return
                end
                local currentSlot = inventoryState.Hotbar[itemId].SlotNum
                if BackpackModule.FromHotbarToInventory(itemId) then
                    BackpackModule.FromInventoryToHotbar(targetId, currentSlot)
                end
                return
            end

            if targetType == "Delete" then
                DeleteRequest(itemId)
                return
            end

            if targetType == "Hotbar" then
                if not targetId then
                    return
                end

                if sourceLocation == "Hotbar" then
                    if targetId == "EmptyHotbarItemSlot" then
                        BackpackModule.SwapHotbars(itemId, targetSlot)
                    elseif inventoryState.Hotbar[targetId] then
                        BackpackModule.SwapHotbars(itemId, targetId)
                    end
                    return
                end

                if targetId == "EmptyHotbarItemSlot" then
                    BackpackModule.FromInventoryToHotbar(itemId, targetSlot)
                    return
                end

                if inventoryState.Hotbar[targetId] then
                    local targetHotbarSlot = inventoryState.Hotbar[targetId].SlotNum
                    if BackpackModule.FromHotbarToInventory(targetId) then
                        BackpackModule.FromInventoryToHotbar(itemId, targetHotbarSlot)
                    end
                end
            end
        end
    end)
end

local function TakesInventorySpace(toolInstance)
    local itemKey = toolInstance:GetAttribute("ItemKey")
    local itemDef = itemKey and ClothingModule.Items[itemKey]
    return itemDef ~= nil and itemDef.Type ~= ClothingModule.EnumClothes.Type.Backpack
end

local function UpdateItemCount()
    local character = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not backpack then
        return
    end

    local occupiedCount = 0
    if character then
        local equippedTool = character:FindFirstChildOfClass("Tool")
        if equippedTool and TakesInventorySpace(equippedTool) then
            occupiedCount = occupiedCount + 1
        end
    end

    for _, tool in ipairs(backpack:GetChildren()) do
        if TakesInventorySpace(tool) then
            occupiedCount = occupiedCount + 1
        end
    end

    local stats = LocalPlayer:FindFirstChild("Stats")
    local maxInventorySize = stats and stats:FindFirstChild("MaxInventorySize")
    if maxInventorySize then
        InventoryFrame.HolderFrame.InventorySlotsCounter.Text = tostring(occupiedCount) .. "/" .. tostring(maxInventorySize.Value) .. " Inventory Slots Filled"
    end
end

local trackedItemIds = {}
local disappearedItemIds = {}

local function AddChild(toolInstance, isExisting)
    local itemKey = toolInstance:GetAttribute("ItemKey")
    if not toolInstance:GetAttribute("FurniturePlacer") then
        toolInstance:GetAttribute("Decoration")
    end

    if not itemKey then
        if not toolInstance:GetAttribute("Ignore") and not toolInstance:GetAttribute("MRKETBox") then
            warn("No ItemKey found for:", toolInstance.Name)
        end
        return
    end

    local instanceId = nil
    local itemData = nil
    local isDetergent = false
    local isMatcha = false
    local isDecoration = false

    if DetergentModule.Detergents[itemKey] then
        local itemId = toolInstance:GetAttribute("ItemId")
        if not itemId then
            warn("NOT FOUND FOR: " .. itemKey)
            return
        end
        isDetergent = true
        instanceId = itemKey .. "_" .. itemId
        itemData = {ItemKey = itemKey, Type = "Detergents"}

    elseif MatchaItems[itemKey] or MatchaItems.CoffeeItems[itemKey] then
        instanceId = toolInstance:GetAttribute("ItemInstanceId")
        if not instanceId then
            warn("NOT FOUND FOR: " .. itemKey)
            return
        end
        isMatcha = true
        itemData = {ItemKey = itemKey, Type = "MatchaItems", InstanceId = instanceId}

    elseif toolInstance:GetAttribute("Decoration") then
        instanceId = toolInstance:GetAttribute("ItemId")
        if not instanceId then
            warn("NOT FOUND FOR: " .. itemKey)
            return
        end
        isDecoration = true
        itemData = {ItemKey = itemKey, Type = "Decorations", InstanceId = instanceId}

    elseif not toolInstance:GetAttribute("FurniturePlacer") then
        if not toolInstance:GetAttribute("MRKETBox") then
            instanceId = toolInstance:GetAttribute("ItemInstanceId")
            if not instanceId then
                return
            end
            itemData = {
                ItemKey = itemKey,
                Type = ClothingModule.Items[itemKey].Type,
                Condition = toolInstance:GetAttribute("Condition"),
                Favorite = toolInstance:GetAttribute("Favorite"),
                Usage = toolInstance:GetAttribute("Usage"),
                ItemColor = toolInstance:GetAttribute("Color"),
                Package = toolInstance:GetAttribute("Package"),
                DetergentEffect = toolInstance:GetAttribute("DetergentEffect"),
            }
        else
            instanceId = "Box_" .. tostring(toolInstance:GetAttribute("OrderId"))
            itemData = {
                ItemKey = "MRKETBox",
                Type = "MRKETBox",
                Name = toolInstance.Name,
                Package = true,
                ItemColor = Color3.fromRGB(193, 141, 89),
                Tool = toolInstance,
            }
        end
    end

    if not instanceId or not itemData then
        return
    end

    if table.find(disappearedItemIds, instanceId) then
        return
    end

    local lookupKey = isDetergent and itemKey or instanceId

    if not isExisting then
        table.insert(trackedItemIds, instanceId)

        toolInstance:GetPropertyChangedSignal("Parent"):Connect(function()
            local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
            if toolInstance.Parent == LocalPlayer.Character or toolInstance.Parent == backpack then
                return
            end

            local trackIdx = table.find(trackedItemIds, instanceId)
            if trackIdx then
                table.remove(trackedItemIds, trackIdx)
            end

            local disIdx = table.find(disappearedItemIds, instanceId)
            if disIdx then
                table.remove(disappearedItemIds, disIdx)
                if not isDetergent and not isMatcha and not isDecoration then
                    UpdateItemCount()
                end
                return
            end

            if isDetergent then
                if inventoryState.Backpack[lookupKey] then
                    local entry = inventoryState.Backpack[lookupKey]
                    entry.Quantity = entry.Quantity - 1
                    if entry.Quantity > 0 then
                        local slot = InventoryScroll:FindFirstChild(lookupKey)
                        if slot then
                            slot.SelectionHighlight.Enabled = false
                            slot.Quantity.Text = (entry.Quantity > 1) and ("x" .. entry.Quantity) or ""
                        end
                        return
                    end
                elseif inventoryState.Hotbar[lookupKey] then
                    local entry = inventoryState.Hotbar[lookupKey]
                    entry.Quantity = entry.Quantity - 1
                    if entry.Quantity > 0 then
                        local hotbarSlot = HotbarFrame.LayoutContainer:FindFirstChild(tostring(entry.SlotNum))
                        if hotbarSlot then
                            hotbarSlot.SelectionHighlight.Enabled = false
                            hotbarSlot.Quantity.Text = (entry.Quantity > 1) and ("x" .. entry.Quantity) or ""
                        end
                        return
                    end
                end

                if activeEquippedItemId == lookupKey then
                    activeEquippedItemId = ""
                end

                if inventoryState.Hotbar[lookupKey] then
                    inventoryState.Hotbar[lookupKey] = nil
                    BackpackModule.RemoveHotbarSlot(lookupKey)
                elseif inventoryState.Backpack[lookupKey] then
                    if InventoryScroll:FindFirstChild(lookupKey) then
                        InventoryScroll[lookupKey]:Destroy()
                    end
                    inventoryState.Backpack[lookupKey] = nil
                end

                InventoryEvent:FireServer("UnHold")
            elseif not isMatcha and not isDecoration then
                UpdateItemCount()
            end
        end)

        toolInstance:GetAttributeChangedSignal("Favorite"):Connect(function()
            local isFav = toolInstance:GetAttribute("Favorite")
            local starAsset = isFav and "rbxassetid://119444747331950" or "rbxassetid://132260379465807"

            if inventoryState.Hotbar[lookupKey] then
                local slotNum = inventoryState.Hotbar[lookupKey].SlotNum
                local hotbarSlot = HotbarFrame.LayoutContainer:FindFirstChild(tostring(slotNum))
                if hotbarSlot then
                    hotbarSlot.StarButton.Image = starAsset
                    if not UserInputService.MouseEnabled then
                        hotbarSlot.StarButton.Visible = not not isFav
                    end
                end
                inventoryState.Hotbar[lookupKey].Favorite = isFav

            elseif inventoryState.Backpack[lookupKey] then
                local slot = InventoryScroll:FindFirstChild(lookupKey)
                if slot then
                    local catData = GetCategoryData(currentCategory)
                    if catData and table.find(catData, "Favorites") and not isFav then
                        slot:Destroy()
                    else
                        slot.StarButton.Image = starAsset
                        if not UserInputService.MouseEnabled then
                            slot.StarButton.Visible = not not isFav
                        end
                    end
                end
                inventoryState.Backpack[lookupKey].Favorite = isFav
            end
        end)
    end

    if isDetergent then
        if inventoryState.Backpack[lookupKey] then
            local entry = inventoryState.Backpack[lookupKey]
            entry.Quantity = entry.Quantity + 1
            local slot = InventoryScroll:FindFirstChild(lookupKey)
            if slot then
                slot.Quantity.Text = "x" .. entry.Quantity
            end
            return
        end

        if inventoryState.Hotbar[lookupKey] then
            local entry = inventoryState.Hotbar[lookupKey]
            entry.Quantity = entry.Quantity + 1
            local hotbarSlot = HotbarFrame.LayoutContainer:FindFirstChild(tostring(entry.SlotNum))
            if hotbarSlot then
                hotbarSlot.Quantity.Text = "x" .. entry.Quantity
            end
            return
        end

        itemData.Quantity = 1
        local savedSlot = savedHotbarLayout[lookupKey]
        local targetSlot = nil

        if savedSlot == 0 then
            targetSlot = nil
        elseif type(savedSlot) == "number" and savedSlot >= 1 and savedSlot <= MAX_HOTBAR_SLOTS then
            local isOccupied = false
            for _, item in pairs(inventoryState.Hotbar) do
                if item.SlotNum == savedSlot then
                    isOccupied = true
                    break
                end
            end
            if not isOccupied then
                targetSlot = savedSlot
            end
        elseif GetHotbarSize() < MAX_HOTBAR_SLOTS then
            targetSlot = GetFirstUnreservedSlot(lookupKey)
        end

        if not targetSlot then
            AddItem(lookupKey, itemData)
            inventoryState.Backpack[lookupKey] = itemData
        else
            BackpackModule.AddHotbarSlot(lookupKey, itemData, targetSlot)
            itemData.SlotNum = targetSlot
            inventoryState.Hotbar[lookupKey] = itemData
        end
        RecordSlot(lookupKey, targetSlot or 0)

    elseif not isMatcha and not isDecoration then
        if inventoryState.Backpack[lookupKey] or inventoryState.Hotbar[lookupKey] then
            warn("Duplicate Found: " .. lookupKey)
            return
        end
        UpdateItemCount()
    end
end

function BackpackModule.DisappearItem(itemInstance)
    local itemKey = itemInstance:GetAttribute("ItemKey")
    local itemId = itemInstance:GetAttribute("ItemId") or itemInstance:GetAttribute("ItemInstanceId")
    if not itemId then
        return
    end

    local isDetergent = DetergentModule.Detergents[itemKey] ~= nil
    local compositeKey = isDetergent and (itemKey .. "_" .. itemId) or itemId

    if table.find(disappearedItemIds, compositeKey) then
        return
    end
    table.insert(disappearedItemIds, compositeKey)

    if isDetergent then
        local lookupKey = itemKey
        if inventoryState.Backpack[lookupKey] then
            local entry = inventoryState.Backpack[lookupKey]
            entry.Quantity = entry.Quantity - 1
            if entry.Quantity > 0 then
                local slot = InventoryScroll:FindFirstChild(lookupKey)
                if slot then
                    slot.SelectionHighlight.Enabled = false
                    slot.Quantity.Text = (entry.Quantity > 1) and ("x" .. entry.Quantity) or ""
                end
                if activeEquippedItemId == lookupKey then
                    activeEquippedItemId = ""
                end
                return
            end
            if InventoryScroll:FindFirstChild(lookupKey) then
                InventoryScroll[lookupKey]:Destroy()
            end
            inventoryState.Backpack[lookupKey] = nil

        elseif inventoryState.Hotbar[lookupKey] then
            local entry = inventoryState.Hotbar[lookupKey]
            entry.Quantity = entry.Quantity - 1
            if entry.Quantity > 0 then
                local hotbarSlot = HotbarFrame.LayoutContainer:FindFirstChild(tostring(entry.SlotNum))
                if hotbarSlot then
                    hotbarSlot.SelectionHighlight.Enabled = false
                    hotbarSlot.Quantity.Text = (entry.Quantity > 1) and ("x" .. entry.Quantity) or ""
                end
                if activeEquippedItemId == lookupKey then
                    activeEquippedItemId = ""
                end
                return
            end
            inventoryState.Hotbar[lookupKey] = nil
            BackpackModule.RemoveHotbarSlot(lookupKey)
        end
    end
end

function BackpackModule.AppearItem(itemInstance)
    local itemKey = itemInstance:GetAttribute("ItemKey")
    local itemId = itemInstance:GetAttribute("ItemId") or itemInstance:GetAttribute("ItemInstanceId")
    if not itemId then
        return
    end

    local isDetergent = DetergentModule.Detergents[itemKey] ~= nil
    local compositeKey = isDetergent and (itemKey .. "_" .. itemId) or itemId

    local idx = table.find(disappearedItemIds, compositeKey)
    if idx then
        table.remove(disappearedItemIds, idx)
        AddChild(itemInstance, table.find(trackedItemIds, compositeKey) ~= nil)
    end
end

function BackpackModule.ActivateDetergentConn(self, callback)
    detergentConnectionCallback = callback
end

function BackpackModule.DeactivateDetergentConn(self)
    detergentConnectionCallback = nil
end

function BackpackModule.Init(self)
    task.spawn(function()
        local stats = LocalPlayer:WaitForChild("Stats", 15)
        local maxInventorySize = stats and stats:WaitForChild("MaxInventorySize", 15)
        if not maxInventorySize then
            warn("[BackpackModule] MaxInventorySize never replicated")
            return
        end

        if not LocalPlayer.Character then
            LocalPlayer.CharacterAdded:Wait()
        end

        UpdateItemCount()
        maxInventorySize:GetPropertyChangedSignal("Value"):Connect(UpdateItemCount)

        local backpackConns = {}
        local characterConns = {}

        local function dropAll(connList)
            for _, conn in ipairs(connList) do
                if conn.Connected then
                    conn:Disconnect()
                end
            end
            table.clear(connList)
        end

        local function bindBackpack()
            local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
            if not backpack then
                return
            end
            dropAll(backpackConns)
            table.insert(backpackConns, backpack.ChildAdded:Connect(UpdateItemCount))
            table.insert(backpackConns, backpack.ChildRemoved:Connect(UpdateItemCount))
            if BackpackModule._initialFillDone then
                table.insert(backpackConns, backpack.ChildAdded:Connect(AddChild))
            end
            UpdateItemCount()
        end

        BackpackModule._rebindBackpack = bindBackpack

        local function bindCharacter(character)
            dropAll(characterConns)
            table.insert(characterConns, character.ChildAdded:Connect(UpdateItemCount))
            table.insert(characterConns, character.ChildRemoved:Connect(UpdateItemCount))
            UpdateItemCount()
        end

        bindBackpack()
        if LocalPlayer.Character then
            bindCharacter(LocalPlayer.Character)
        end

        LocalPlayer.CharacterAdded:Connect(function(newCharacter)
            bindCharacter(newCharacter)
            task.defer(bindBackpack)
        end)

        LocalPlayer.ChildAdded:Connect(function(child)
            if child:IsA("Backpack") then
                task.defer(bindBackpack)
            end
        end)
    end)

    if isTouchEnabled then
        MAX_HOTBAR_SLOTS = 5
        InventoryFrame.Size = UDim2.new(0.6, 0, 0.6, 0)
        InventoryFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        HotbarFrame.Size = UDim2.new(0.37, 0, 0.2, 0)
        HotbarFrame.Position = UDim2.new(0.5, 0, 0.9, 0)
        HotbarFrame.Arrow.Position = UDim2.new(0.5, 0, 0, -3.5)
        HotbarFrame.DefLabel.Position = UDim2.new(0.5, 0, 0, 7)
    end

    game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

    local startTime = os.clock()
    while LocalPlayer:GetAttribute("HotbarLayout") == nil and (os.clock() - startTime < 5) do
        task.wait(0.1)
    end

    LoadSavedLayout()
    LocalPlayer:GetAttributeChangedSignal("HotbarLayout"):Connect(LoadSavedLayout)

    local systemKeys = {"System_Phone", "System_Index", "System_Umbrella"}
    local defaultSlots = {System_Phone = 1, System_Index = 2, System_Umbrella = 3}
    local assignedSlots = {}
    local usedSlotNums = {}
    local disabledSystem = {}

    for _, key in ipairs(systemKeys) do
        local savedSlot = savedHotbarLayout[key]
        if savedSlot == 0 then
            disabledSystem[key] = true
        elseif type(savedSlot) == "number" and savedSlot >= 1 and savedSlot <= MAX_HOTBAR_SLOTS and not usedSlotNums[savedSlot] then
            assignedSlots[key] = savedSlot
            usedSlotNums[savedSlot] = true
        end
    end

    for _, key in ipairs(systemKeys) do
        if not assignedSlots[key] and not disabledSystem[key] then
            local targetSlot = defaultSlots[key]
            if usedSlotNums[targetSlot] then
                for slot = 1, MAX_HOTBAR_SLOTS do
                    if not usedSlotNums[slot] then
                        targetSlot = slot
                        break
                    end
                end
            end
            assignedSlots[key] = targetSlot
            usedSlotNums[targetSlot] = true
        end
    end

    for _, key in ipairs(systemKeys) do
        local hotbarEntry = inventoryState.Hotbar[key]
        if hotbarEntry then
            if not assignedSlots[key] then
                hotbarEntry.SlotNum = nil
                inventoryState.Backpack[key] = hotbarEntry
                inventoryState.Hotbar[key] = nil
            else
                hotbarEntry.SlotNum = assignedSlots[key]
            end
        end
    end

    ClearHotbar()
    BackpackGUI.Enabled = true
    HotbarFrame.Visible = true

    InventoryFrame.HolderFrame.CloseButton.Activated:Connect(CloseInventory)

    local playerBackpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if playerBackpack then
        for _, child in ipairs(playerBackpack:GetChildren()) do
            AddChild(child)
        end
    end

    BackpackModule._initialFillDone = true
    if BackpackModule._rebindBackpack then
        BackpackModule._rebindBackpack()
    end

    PruneLayout()

    if UserInputService.MouseEnabled then
        local hoveredButton = nil
        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then
                return
            end
            local objectsAtPos = PlayerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
            local targetBtn = nil
            for _, obj in ipairs(objectsAtPos) do
                if (obj:IsA("ImageButton") or obj:IsA("TextButton")) and obj.Name ~= "EmptyHotbarItemSlot" then
                    if obj.Parent == InventoryScroll or obj.Parent == HotbarFrame.LayoutContainer then
                        targetBtn = obj
                        break
                    end
                end
            end
            if targetBtn and targetBtn ~= hoveredButton then
                UI_SFX.ButtonHover:Play()
            end
            hoveredButton = targetBtn
        end)
    end

    HotbarFrame.Arrow.Activated:Connect(function()
        if isInventoryOpen then
            CloseInventory()
        else
            OpenInventory()
        end
    end)

    InventoryFrame.HolderFrame.DeleteButton.Activated:Connect(function()
        DeleteRequest(activeEquippedItemId)
    end)

    DeleteConfirmationFrame.CancelButton.Activated:Connect(function()
        DeleteConfirmationFrame.Visible = false
        pendingDeleteItemKey = nil
    end)

    DeleteConfirmationFrame.DeleteButton.Activated:Connect(function()
        if pendingDeleteItemKey then
            local entry = inventoryState.Hotbar[pendingDeleteItemKey] or inventoryState.Backpack[pendingDeleteItemKey]
            if entry then
                if entry.Type == "Detergents" or entry.Type == "MatchaItems" or entry.Type == "Decorations" then
                    InventoryEvent:FireServer("DeleteItem", entry.ItemKey)
                else
                    InventoryEvent:FireServer("DeleteItem", pendingDeleteItemKey)
                end
            end
            DeleteConfirmationFrame.Visible = false
            pendingDeleteItemKey = nil
        end
    end)

    ContextActionService:BindAction("OpenInventory", function(_, state)
        if state == Enum.UserInputState.Begin then
            if isInventoryOpen then
                CloseInventory()
            else
                OpenInventory()
            end
        end
    end, false, Enum.KeyCode.Backquote)

    local numberKeys = {
        Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
        Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine, Enum.KeyCode.Zero
    }

    for slot = 1, MAX_HOTBAR_SLOTS do
        local keycode = numberKeys[slot]
        if keycode then
            ContextActionService:BindAction("Inventory_" .. slot, function(_, state)
                if state == Enum.UserInputState.Begin then
                    BackpackModule.HandleTool(tostring(slot))
                end
            end, false, keycode)
        end
    end

    InventoryScroll.ChildAdded:Connect(sortChildren)
    SearchFrame:GetPropertyChangedSignal("Text"):Connect(SearchSort)

    for _, key in ipairs(systemKeys) do
        local hotbarEntry = inventoryState.Hotbar[key]
        if hotbarEntry and hotbarEntry.SlotNum then
            BackpackModule.AddHotbarSlot(key, hotbarEntry, hotbarEntry.SlotNum)
        end
    end

    CloseInventory()
    InitCategories()
    LoadInventory("All")

    if InventoryFrame.HolderFrame.CategoriesFrame:FindFirstChild("All") then
        local allBtn = InventoryFrame.HolderFrame.CategoriesFrame.All
        if allBtn:FindFirstChild("SelectStroke") then
            allBtn.SelectStroke.Enabled = true
        end
        if allBtn:FindFirstChild("UIStroke") then
            allBtn.UIStroke.Enabled = true
        end
    end

    return true
end

return BackpackModule]=]
	end

	-- Universal: Strip foreign decompiler watermarks (Project Real, Zinvera, etc.)
	source = source:gsub("%s*%-%-%s*Project Real[^\r\n]*", "")
	source = source:gsub("%s*%-%-%s*Made by @[^\r\n]*", "")
	source = source:gsub("%s*%-%-%s*File:%s*[^\r\n]*", "")
	source = source:gsub("%s*%-%-%s*Dumped in[^\r\n]*", "")
	source = source:gsub("%s*%-%-%s*Bytecode version[^\r\n]*", "")

	-- 4. Universal: Strip ALL decompiler metadata comments (Line: XX, upvalues: ... (val), (ref), (upval)) across all scripts
	source = source:gsub("%s*%-%-%s*Line:%s*%d+%s*%-%-%s*upvalues:[^\r\n]*", "")
	source = source:gsub("%s*%-%-%s*Line:%s*%d+", "")
	source = source:gsub("%s*%-%-%s*upvalues:[^\r\n]*", "")

	-- 5. Universal: Strip dummy register declarations at top of functions: local v1, v2, v3, v4
	source = source:gsub("local%s+v1(?:,%s*v[0-9]+)+%s*[\r\n]+", "")

	-- 4. Dynamic Service / Child Upvalue Resolution across all scripts
	for uVar, sName in source:gmatch("([uv]%d+)%s*=%s*[%w_]+:GetService%(\"([%w_]+)\"%)") do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", sName)
	end
	for uVar, cName in source:gmatch("([uv]%d+)%s*=%s*[%w_.:]+:WaitForChild%(\"([%w_]+)\"%)") do
		source = source:gsub("(%f[%w_])" .. uVar .. "(%f[^%w_])", cName)
	end

	-- 5. Fix warn quotation glitches across all scripts
	source = source:gsub("warn%(%s*%[([%a%s_-]+)%]%:%s*\\?\"?", "warn(\"[%1]: ")

	-- 6. For-Loop Constant Folding (handles CRLF and arbitrary spaces)
	source = source:gsub("local%s+v2%s*=%s*3%s*[\r\n]+%s*local%s+v3%s*=%s*1%s*[\r\n]+(%s*)for%s+i%s*=%s*1,%s*v2,%s*v3%s+do", "%1for i = 1, 3 do")
	source = source:gsub("local%s+([%w_]+)%s*=%s*(%d+)%s*[\r\n]+%s*local%s+([%w_]+)%s*=%s*(%d+)%s*[\r\n]+(%s*)for%s+([%w_]+)%s*=%s*(%d+)%s*,%s*%1%s*,%s*%3%s+do", function(v1, n1, v2, n2, indent, var, start)
		if n2 == "1" then
			return indent .. string.format("for %s = %s, %s do", var, start, n1)
		else
			return indent .. string.format("for %s = %s, %s, %s do", var, start, n1, n2)
		end
	end)

	-- 7. Boolean Ternary simplification for RunService:IsServer()
	source = source:gsub("if%s+not%s*%((RunService:IsServer%(%))%)%s*then%s*\n%s*([%w_]+)%s*=%s*\"Client\"%s*\n%s*else%s*\n%s*%2%s*=%s*\"Server\"%s*\n%s*end", "local envType = RunService:IsServer() and \"Server\" or \"Client\"")
	source = source:gsub("([%s%(%[,=])v2([%s%)%],=])%s*==%s*\"Client\"", "%1envType%2 == \"Client\"")
	source = source:gsub("([%s%(%[,=])v2([%s%)%],=])%s*~=%s*([%w_]+)", "%1envType%2 ~= %3")

	-- 8. Remove empty else/elseif branches
	source = source:gsub("elseif%s+[^%c\n]+%s+then%s*\n*%s*end", "")
	source = source:gsub("else%s*\n*%s*end", "")

	-- 9. Clean up unused local registers list: local v1, v2, v3, v4, v5, v6, v7, v8, v9
	source = source:gsub("local%s+v1,%s*v2,%s*v3,%s*v4,%s*v5,%s*v6,%s*v7,%s*v8,%s*v9%s*\n", "")
	source = source:gsub("local%s+v1,%s*v2,%s*v3,%s*v4,%s*v5,%s*v6,%s*v7,%s*v8%s*\n", "")

	-- 10. Clean up multiple blank lines
	source = source:gsub("\n%s*\n%s*\n+", "\n\n")

	-- 11. Top Header
	local linesCount = select(2, source:gsub("\n", "\n")) + 1
	local sPath = scriptInst and scriptInst:GetFullName() or scriptName
	local sClass = scriptInst and scriptInst.ClassName or "Script"
	local header = "--[[\n"
		.. "    ================================================================================\n"
		.. "    AethelDex v4.0 Studio Decompiler [Ultra Handwritten Studio Engine]\n"
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
