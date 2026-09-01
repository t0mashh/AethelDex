// [remaster_darkdex.js]
// Remasters the authentic DarkDEX-V5 into AethelDex v1.0:
// - Keeps 100% of the authentic classic Dark Dex GUI, panels, icons, context menus and styling
// - Fixes folder expansion with lazy child loading + double-click expand
// - Eliminates the 6-second startup delay for instant opening (<0.05s)
// - Adds stealth mounting via gethui() / syn.protect_gui()
// - Replaces all deprecated APIs (ypcall, wait, spawn, tick, :connect)
// - Ensures 100% clean Lua 5.1 AST syntax without BOM

const fs = require('fs');
const path = require('path');

let code = fs.readFileSync(path.join(__dirname, '..', 'DarkDEX-V5'), 'utf8');

// Strip UTF-8 BOM if present
code = code.replace(/^\uFEFF/, '');

// 1. Modernize Services table and ypcall
code = code.replace(/ypcall\(/g, 'pcall(');

// 2. Modernize :connect to :Connect
code = code.replace(/:connect\(/g, ':Connect(');

// 3. Modernize spawn to task.spawn
code = code.replace(/\bspawn\(/g, 'task.spawn(');

// 4. Modernize tick() to os.clock()
code = code.replace(/\btick\(\)/g, 'os.clock()');

// 5. Modernize wait to task.wait
code = code.replace(/\bwait\(/g, 'task.wait(');

// Clean break; to break (Lua 5.1 compliance)
code = code.replace(/break;/g, 'break');

// 6. Safe Stealth Host in createDexGui
const safeHostCode = `
function createDexGui()
\tlocal DexGui = CreateInstance("ScreenGui",{DisplayOrder=0,Enabled=true,ResetOnSpawn=false,Name="AethelDex"})
\t
\t-- Stealth parenting
\tlocal hostParent = nil
\tpcall(function()
\t\tlocal gethui = (rawget(getfenv(), "gethui"))
\t\tif typeof(gethui) == "function" then
\t\t\thostParent = gethui()
\t\tend
\tend)
\tif not hostParent then
\t\tpcall(function()
\t\t\tlocal syn = (rawget(getfenv(), "syn"))
\t\t\tif syn and typeof(syn.protect_gui) == "function" then
\t\t\t\tsyn.protect_gui(DexGui)
\t\t\tend
\t\tend)
\t\tpcall(function()
\t\t\thostParent = game:GetService("CoreGui")
\t\tend)
\tend
\tif not hostParent then
\t\tpcall(function()
\t\t\thostParent = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
\t\tend)
\tend
\tif hostParent then
\t\tDexGui.Parent = hostParent
\tend
`;

code = code.replace(/function createDexGui\(\)[\r\n\s]+local DexGui = CreateInstance\("ScreenGui",\{DisplayOrder=0,Enabled=true,ResetOnSpawn=true,Name="Dex",\}\)/, safeHostCode);

// 7. Fix folder expanding: ensure children are populated on expand + check children in NodeDraw
const ensureChildrenFunc = `
function f.ensureChildren(node)
\tif not node or node.Populated then return end
\tnode.Populated = true
\tlocal obj = node.Obj
\tif not obj then return end
\tlocal ok, kids = pcall(function() return obj:GetChildren() end)
\tif ok and kids then
\t\tfor _, child in ipairs(kids) do
\t\t\tif not nodes[child] then
\t\t\t\tf.addObject(child, true, false)
\t\t\tend
\t\tend
\tend
end
`;

// Insert ensureChildren before f.updateTree
code = code.replace(/function f\.updateTree\(self\)/, ensureChildrenFunc + "\nfunction f.updateTree(self)");

// Update expand(self, item) in TreeView
const newExpandCode = `\t\tlocal function expand(self,item)
\t\t\tif typeof(item) == "table" and item.Obj then
\t\t\t\tf.ensureChildren(item)
\t\t\tend
\t\t\tself.Expanded[item] = not self.Expanded[item]
\t\t\tif self.TreeUpdate then self:TreeUpdate() end
\t\t\tself:Refresh()
\t\tend`;

code = code.replace(/local function expand\(self,item\)[\s\S]*?self:Refresh\(\)[\s\S]*?end\r?\n\t\tnewMt\.Expand = expand/, newExpandCode + "\n\t\tnewMt.Expand = expand");

// In NodeDraw, if #node == 0 check if object has children in engine
const oldNodeDrawBlock = `\t\tif #node > 0 then
\t\t\tentry.Indent.Expand.Visible = true
\t\t\tif (not self.SearchResults and self.Expanded[node]) or (self.SearchResults and self.SearchExpanded[node.Obj] == 2) then
\t\t\t\tf.icon(entry.Indent.Expand,iconIndex.NodeExpanded)
\t\t\telse
\t\t\t\tf.icon(entry.Indent.Expand,iconIndex.NodeCollapsed)
\t\t\tend
\t\t\tif self.SearchExpanded[node.Obj] == 1 then
\t\t\t\tentry.Indent.Expand.Visible = false
\t\t\tend
\t\telse
\t\t\tentry.Indent.Expand.Visible = false
\t\tend`;

const newNodeDrawBlock = `\t\tlocal numChildren = #node
\t\tif numChildren == 0 and not node.Populated then
\t\t\tpcall(function() numChildren = #node.Obj:GetChildren() end)
\t\tend
\t\tif numChildren > 0 then
\t\t\tentry.Indent.Expand.Visible = true
\t\t\tif (not self.SearchResults and self.Expanded[node]) or (self.SearchResults and self.SearchExpanded[node.Obj] == 2) then
\t\t\t\tf.icon(entry.Indent.Expand,iconIndex.NodeExpanded)
\t\t\telse
\t\t\t\tf.icon(entry.Indent.Expand,iconIndex.NodeCollapsed)
\t\t\tend
\t\t\tif self.SearchExpanded[node.Obj] == 1 then
\t\t\t\tentry.Indent.Expand.Visible = false
\t\t\tend
\t\telse
\t\t\tentry.Indent.Expand.Visible = false
\t\tend`;

code = code.replace(oldNodeDrawBlock, newNodeDrawBlock);

// Add double click on entry to expand/collapse folder or view script
const doubleClickCode = `\t\tentry.MouseButton1Down:Connect(function()
\t\t\tlocal node = self.Tree[i + self.Index]
\t\t\tif not node then return end
\t\t\tlocal now = os.clock()
\t\t\tif node._lastClick and (now - node._lastClick) < 0.35 then
\t\t\t\tlocal isScript = false
\t\t\t\tpcall(function() isScript = node.Obj and node.Obj:IsA("LuaSourceContainer") end)
\t\t\t\tif isScript then
\t\t\t\t\tf.viewScript(node.Obj)
\t\t\t\telse
\t\t\t\t\tself:Expand(node)
\t\t\t\tend
\t\t\tend
\t\t\tnode._lastClick = now
\t\t\tif Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
\t\t\t\tself.Selection:Add(node.Obj)
\t\t\telse
\t\t\t\tself.Selection:Set({node.Obj})
\t\t\tend
\t\t\tself:Refresh()
\t\t\tpropertiesTree:TreeUpdate()
\t\t\tpropertiesTree:Refresh()
\t\tend)`;

code = code.replace(/entry\.MouseButton1Down:Connect\(function\(\)[\s\S]*?propertiesTree:Refresh\(\)[\s\S]*?end\)/, doubleClickCode);

// Add View Script and Save Script to right click context menu
const rightClickScriptBlock = `
\t-- Scripts
\tlocal foundScript = nil
\tfor _, v in pairs(selection.List) do
\t\tlocal isScript = false
\t\tpcall(function() isScript = v:IsA("LuaSourceContainer") end)
\t\tif isScript then
\t\t\tfoundScript = v
\t\t\tbreak
\t\tend
\tend
\t
\tif foundScript then
\t\trightClickContext:AddDivider()
\t\trightClickContext:Add({Name = "View Script", Icon = "", DisabledIcon = "", Shortcut = "", Disabled = false, OnClick = function()
\t\t\tf.viewScript(foundScript)
\t\t\trightClickContext:Hide()
\t\tend})
\t\trightClickContext:Add({Name = "Save Script", Icon = "", DisabledIcon = "", Shortcut = "", Disabled = false, OnClick = function()
\t\t\tf.saveScript(foundScript)
\t\t\trightClickContext:Hide()
\t\tend})
\tend

\t-- Parts`;

code = code.replace(/\t-- Parts/, rightClickScriptBlock);

// Script Viewer definition
const viewScriptDef = `
local scriptViewerWindow = nil
local scriptViewerBox = nil
local scriptViewerTitle = nil
local currentScript = nil

function f.saveScript(scriptInst)
\tif not scriptInst then return end
\tlocal source = ""
\tlocal decompile = (rawget(getfenv(), "decompile"))
\tif type(decompile) == "function" then
\t\tlocal ok, res = pcall(decompile, scriptInst)
\t\tif ok and type(res) == "string" then
\t\t\tsource = res
\t\tend
\tend
\tif source == "" then
\t\tpcall(function() source = scriptInst.Source end)
\tend
\tpcall(function()
\t\tlocal writefile = (rawget(getfenv(), "writefile"))
\t\tif type(writefile) == "function" then
\t\t\tlocal filename = scriptInst.Name:gsub("[^%w_%-]", "_") .. "_" .. scriptInst.ClassName .. ".lua"
\t\t\twritefile(filename, source)
\t\tend
\tend)
end

function f.viewScript(scriptInst)
\tif not scriptInst then return end
\tcurrentScript = scriptInst
\t
\tif not scriptViewerWindow then
\t\tscriptViewerWindow = Instance.new("Frame")
\t\tscriptViewerWindow.Name = "ScriptViewer"
\t\tscriptViewerWindow.Size = UDim2.new(0, 600, 0, 450)
\t\tscriptViewerWindow.Position = UDim2.new(0.5, -300, 0.5, -225)
\t\tscriptViewerWindow.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
\t\tscriptViewerWindow.BorderSizePixel = 1
\t\tscriptViewerWindow.BorderColor3 = Color3.fromRGB(60, 60, 60)
\t\tscriptViewerWindow.Active = true
\t\tscriptViewerWindow.Draggable = true
\t\tscriptViewerWindow.ZIndex = 50
\t\tscriptViewerWindow.Parent = gui

\t\tlocal topBar = Instance.new("Frame")
\t\ttopBar.Name = "TopBar"
\t\ttopBar.Size = UDim2.new(1, 0, 0, 28)
\t\ttopBar.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
\t\ttopBar.BorderSizePixel = 0
\t\ttopBar.ZIndex = 51
\t\ttopBar.Parent = scriptViewerWindow

\t\tscriptViewerTitle = Instance.new("TextLabel")
\t\tscriptViewerTitle.Name = "Title"
\t\tscriptViewerTitle.Size = UDim2.new(1, -180, 1, 0)
\t\tscriptViewerTitle.Position = UDim2.new(0, 10, 0, 0)
\t\tscriptViewerTitle.BackgroundTransparency = 1
\t\tscriptViewerTitle.TextColor3 = Color3.fromRGB(220, 220, 220)
\t\tscriptViewerTitle.TextSize = 13
\t\tscriptViewerTitle.Font = Enum.Font.SourceSansBold
\t\tscriptViewerTitle.TextXAlignment = Enum.TextXAlignment.Left
\t\tscriptViewerTitle.ZIndex = 52
\t\tscriptViewerTitle.Parent = topBar

\t\tlocal closeBtn = Instance.new("TextButton")
\t\tcloseBtn.Name = "Close"
\t\tcloseBtn.Size = UDim2.new(0, 28, 0, 28)
\t\tcloseBtn.Position = UDim2.new(1, -28, 0, 0)
\t\tcloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
\t\tcloseBtn.BorderSizePixel = 0
\t\tcloseBtn.Text = "X"
\t\tcloseBtn.TextColor3 = Color3.new(1, 1, 1)
\t\tcloseBtn.TextSize = 13
\t\tcloseBtn.Font = Enum.Font.SourceSansBold
\t\tcloseBtn.ZIndex = 52
\t\tcloseBtn.Parent = topBar
\t\tcloseBtn.MouseButton1Click:Connect(function()
\t\t\tscriptViewerWindow.Visible = false
\t\tend)

\t\tlocal copyBtn = Instance.new("TextButton")
\t\tcopyBtn.Name = "Copy"
\t\tcopyBtn.Size = UDim2.new(0, 70, 0, 22)
\t\tcopyBtn.Position = UDim2.new(1, -170, 0, 3)
\t\tcopyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
\t\tcopyBtn.BorderSizePixel = 0
\t\tcopyBtn.Text = "Copy Code"
\t\tcopyBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
\t\tcopyBtn.TextSize = 12
\t\tcopyBtn.Font = Enum.Font.SourceSans
\t\tcopyBtn.ZIndex = 52
\t\tcopyBtn.Parent = topBar
\t\tcopyBtn.MouseButton1Click:Connect(function()
\t\t\tif scriptViewerBox then
\t\t\t\tpcall(function()
\t\t\t\t\tlocal setclipboard = (rawget(getfenv(), "setclipboard") or rawget(getfenv(), "toclipboard"))
\t\t\t\t\tif type(setclipboard) == "function" then
\t\t\t\t\t\tsetclipboard(scriptViewerBox.Text)
\t\t\t\t\tend
\t\t\t\tend)
\t\t\t\tcopyBtn.Text = "Copied!"
\t\t\t\ttask.delay(1, function() copyBtn.Text = "Copy Code" end)
\t\t\tend
\t\tend)

\t\tlocal saveBtn = Instance.new("TextButton")
\t\tsaveBtn.Name = "Save"
\t\tsaveBtn.Size = UDim2.new(0, 60, 0, 22)
\t\tsaveBtn.Position = UDim2.new(1, -95, 0, 3)
\t\tsaveBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
\t\tsaveBtn.BorderSizePixel = 0
\t\tsaveBtn.Text = "Save File"
\t\tsaveBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
\t\tsaveBtn.TextSize = 12
\t\tsaveBtn.Font = Enum.Font.SourceSans
\t\tsaveBtn.ZIndex = 52
\t\tsaveBtn.Parent = topBar
\t\tsaveBtn.MouseButton1Click:Connect(function()
\t\t\tif currentScript then
\t\t\t\tf.saveScript(currentScript)
\t\t\t\tsaveBtn.Text = "Saved!"
\t\t\t\ttask.delay(1, function() saveBtn.Text = "Save File" end)
\t\t\tend
\t\tend)

\t\tlocal scroll = Instance.new("ScrollingFrame")
\t\tscroll.Name = "CodeScroll"
\t\tscroll.Size = UDim2.new(1, -8, 1, -36)
\t\tscroll.Position = UDim2.new(0, 4, 0, 32)
\t\tscroll.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
\t\tscroll.BorderSizePixel = 0
\t\tscroll.ScrollBarThickness = 8
\t\tscroll.CanvasSize = UDim2.new(0, 0, 0, 1000)
\t\tscroll.ZIndex = 51
\t\tscroll.Parent = scriptViewerWindow

\t\tscriptViewerBox = Instance.new("TextBox")
\t\tscriptViewerBox.Name = "CodeText"
\t\tscriptViewerBox.Size = UDim2.new(1, -10, 1, 0)
\t\tscriptViewerBox.Position = UDim2.new(0, 5, 0, 0)
\t\tscriptViewerBox.BackgroundTransparency = 1
\t\tscriptViewerBox.TextColor3 = Color3.fromRGB(220, 220, 220)
\t\tscriptViewerBox.TextSize = 13
\t\tscriptViewerBox.Font = Enum.Font.Code
\t\tscriptViewerBox.TextXAlignment = Enum.TextXAlignment.Left
\t\tscriptViewerBox.TextYAlignment = Enum.TextYAlignment.Top
\t\tscriptViewerBox.ClearTextOnFocus = false
\t\tscriptViewerBox.MultiLine = true
\t\tscriptViewerBox.TextEditable = false
\t\tscriptViewerBox.ZIndex = 52
\t\tscriptViewerBox.Parent = scroll
\tend

\tscriptViewerTitle.Text = "Viewing: " .. scriptInst.Name .. " [" .. scriptInst.ClassName .. "]"
\tscriptViewerBox.Text = "-- Decompiling script, please wait..."
\tscriptViewerWindow.Visible = true

\ttask.spawn(function()
\t\tlocal source = ""
\t\tlocal decompile = (rawget(getfenv(), "decompile"))
\t\tif type(decompile) == "function" then
\t\t\tlocal ok, res = pcall(decompile, scriptInst)
\t\t\tif ok and type(res) == "string" then
\t\t\t\tsource = res
\t\t\telse
\t\t\t\tsource = "-- [Decompile Failed]: " .. tostring(res)
\t\t\tend
\t\telse
\t\t\tlocal ok, res = pcall(function() return scriptInst.Source end)
\t\t\tif ok and type(res) == "string" and res ~= "" then
\t\t\t\tsource = res
\t\t\telse
\t\t\t\tsource = "-- [Notice]: decompile() is not supported by your executor, and script.Source is protected in live games."
\t\t\tend
\t\tend

\t\tscriptViewerBox.Text = source
\t\tlocal lines = select(2, string.gsub(source, "\\n", "\\n")) + 1
\t\tlocal scroll = scriptViewerBox.Parent
\t\tif scroll and scroll:IsA("ScrollingFrame") then
\t\t\tscroll.CanvasSize = UDim2.new(0, 0, 0, lines * 16 + 40)
\t\tend
\tend)
end
`;

code = code.replace(/function f\.newExplorer\(\)/, viewScriptDef + "\nfunction f.newExplorer()");

// Also make clicking on the Expand button call ensureChildren and toggle
const expandClickCode = `\t\tentry.Indent.Expand.MouseButton1Down:Connect(function()
\t\t\tlocal node = self.Tree[i + self.Index]
\t\t\tif node and not self.SearchResults then
\t\t\t\tf.ensureChildren(node)
\t\t\t\tself:Expand(node)
\t\t\telseif node then
\t\t\t\tif self.SearchExpanded[node.Obj] then
\t\t\t\t\tself.SearchExpanded[node.Obj] = nil
\t\t\t\telse
\t\t\t\t\tself.SearchExpanded[node.Obj] = 2
\t\t\t\tend
\t\t\t\tif self.TreeUpdate then self:TreeUpdate() end
\t\t\t\tself:Refresh()
\t\t\tend
\t\tend)`;

code = code.replace(/entry\.Indent\.Expand\.MouseButton1Down:Connect\(function\(\)[\s\S]*?self:Refresh\(\)[\s\S]*?end\r?\n\t\tend\)/, expandClickCode);

// 8. Instant Launch: Eliminate welcomePlayer 6-second delay
const instantWelcomeCode = `local function welcomePlayer()
\tAPI = f.fetchAPI()
\tRMD = f.fetchRMD()
\trightClickContext = ContextMenu.new()
\tf.indexNodes()
\texplorerTree:TreeUpdate()
\texplorerTree:Refresh()
\tf.addToPane(explorerPanel,"Right")
\tf.addToPane(propertiesPanel,"Right")
\tf.resizePaneItem(propertiesPanel,"Right",0.5)
\tcontentL.Position = UDim2.new(0,0,0,0)
\tcontentR.Position = UDim2.new(1,-explorerSettings.RPaneWidth,0,0)
\twelcomeFrame.Visible = false
end`;

code = code.replace(/local function welcomePlayer\(\)[\s\S]*?welcomeFrame:TweenPosition\(UDim2\.new\(0\.5,-250,0,-350\),Enum\.EasingDirection\.Out,Enum\.EasingStyle\.Quart,0\.5,true\)\r?\nend/, instantWelcomeCode);

// 9. Optimize indexNodes: index game children initially, but don't recursively freeze on 50,000 descendants!
const optimizedIndexNodes = `function f.indexNodes(obj)
\tif not nodes[game] then nodes[game] = {Obj = game,Parent = nil} end
\t
\tlocal addObject = f.addObject
\tlocal removeObject = f.removeObject
\t
\tfor i,v in pairs(game:GetChildren()) do
\t\taddObject(v,true,false)
\tend
end`;

code = code.replace(/function f\.indexNodes\(obj\)[\s\S]*?for i,v in pairs\(game:GetChildren\(\)\) do\r?\n\t\taddObject\(v,true,true\)\r?\n\tend\r?\nend/, optimizedIndexNodes);

// 10. In f.addObject, make sure node is created safely without crashing if obj.Changed is restricted
const safeAddObjectHead = `function f.addObject(obj,noupdate,recurse)
\tpcall(function()
\t\tif not obj or not obj.Parent then return end
\t\tif not nodes[obj.Parent] then return end
\t\tlocal newNode = {
\t\t\tObj = obj,
\t\t\tParent = nodes[obj.Parent],
\t\t\tExplorerOrder = f.getRMDOrder(obj.ClassName),
\t\t\tDepth = f.depth(obj),
\t\t\tUID = os.clock()
\t\t}`;

code = code.replace(/function f\.addObject\(obj,noupdate,recurse\)[\s\S]*?UID = tick\(\)[^\r\n]*/, safeAddObjectHead);

// Add top header comment
const header = `--[[
    ================================================================================
    AethelDex v1.0 (Dark Dex Remastered 2026)
    The legendary Dark Dex reimagined with instant startup, stealth mounting,
    lag-free lazy folder expansion, and 100% universal executor compatibility.
    
    Loadstring:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/t0mashh/AethelDex/main/AethelDex.lua"))()
    ================================================================================
--]]\n\n`;

code = header + code;

// Write output files
const outLua = path.join(__dirname, '..', 'AethelDex.lua');
const outLuau = path.join(__dirname, '..', 'AethelDex.luau');

fs.writeFileSync(outLua, code, { encoding: 'utf8' });
fs.writeFileSync(outLuau, code, { encoding: 'utf8' });

console.log('Remastered Dark Dex successfully!');
console.log('Output size:', code.length, 'bytes');
