const fs = require('fs');
const path = require('path');

// 1. Update src/Decompiler/AethelDecompiler.lua
const decompilerPath = path.join(__dirname, '..', 'src', 'Decompiler', 'AethelDecompiler.lua');
let decompiler = fs.readFileSync(decompilerPath, 'utf8');

const placeSaverSuite = `function f.saveScript(scriptInst)
	if not scriptInst then return end
	local source = f.decompileScript(scriptInst)
	source = f.beautifyDecompiledSource(source, scriptInst)
	pcall(function()
		local writefile = getGlobal("writefile")
		if type(writefile) == "function" then
			local filename = scriptInst.Name:gsub('[\\\\/:*?"<>|]', "_") .. "_" .. scriptInst.ClassName .. ".lua"
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
			table.insert(parts, 1, '["' .. name:gsub('"', '\\\\"') .. '"]')
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

	return table.concat(lines, "\\n")
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

	return table.concat(lines, "\\n")
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

	return table.concat(lines, "\\n")
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
function f.savePlace(options)
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
			gameName = info.Name:gsub('[\\\\/:*?"<>|]', ""):gsub("%s+", "_")
		end
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
			local scriptName = scriptInst.Name:gsub('[\\\\/:*?"<>|]', "_")
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

		updateProgress("✅ Done! Saved to workspace/" .. rootDir, 1.0, rootDir)
	end)
end

-- [[ Save Instance Subtree ]]
function f.saveInstanceTree(targetInst)
	if not targetInst then return end
	local writefile = getGlobal("writefile")
	local makefolder = getGlobal("makefolder")
	local isfolder = getGlobal("isfolder")
	local hasFS = (type(writefile) == "function")

	local rootName = targetInst.Name:gsub('[\\\\/:*?"<>|]', "_")
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
				local filename = dir .. "/" .. obj.Name:gsub('[\\\\/:*?"<>|]', "_") .. "_" .. obj.ClassName .. ".lua"
				pcall(function() writefile(filename, src) end)
			end
		end
	end

	print("[AethelDex] Saved instance tree for " .. targetInst.Name .. " (" .. scriptCount .. " scripts dumped)")
end`;

// Replace function f.saveScript with regex to be CRLF-safe
const saveScriptRegex = /function f\.saveScript\(scriptInst\)[\s\S]*?\nend/;
if (!saveScriptRegex.test(decompiler)) {
	throw new Error("Could not find f.saveScript in AethelDecompiler.lua!");
}
decompiler = decompiler.replace(saveScriptRegex, placeSaverSuite);

// Also add Save Place button in ScriptViewer topBar if not already added
if (!decompiler.includes('savePlaceBtn.Name = "SavePlace"')) {
	const targetCopyBtn = `\t\tcopyBtn.Parent = topBar`;
	const savePlaceBtnViewer = `\t\tcopyBtn.Parent = topBar

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
		end)`;

	decompiler = decompiler.replace(targetCopyBtn, savePlaceBtnViewer);
	decompiler = decompiler.replace(
		`beautifyBtn.Position = UDim2.new(1, -236, 0, 4)`,
		`beautifyBtn.Position = UDim2.new(1, -330, 0, 4)`
	);
}

fs.writeFileSync(decompilerPath, decompiler, 'utf8');
console.log("Updated AethelDecompiler.lua successfully! Contains f.savePlace:", decompiler.includes('function f.savePlace'));
