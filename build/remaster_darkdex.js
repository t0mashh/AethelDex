// [remaster_darkdex.js]
// Remasters the authentic DarkDEX-V5 into AethelDex v1.0:
// - Keeps 100% of the authentic classic Dark Dex GUI, panels, icons, context menus and styling
// - Fixes folder expansion with lazy child loading + double-click expand
// - Eliminates the 6-second startup delay for instant opening (<0.05s)
// - Adds stealth mounting via gethui() / syn.protect_gui()
// - Replaces all deprecated APIs (ypcall, wait, spawn, tick, :connect)
// - Integrates AethelDex Universal Multi-Tier Decompiler Suite (Native + Cloud + In-Engine Bytecode Lifting)
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

// Prepend local f = {} at the very top of script so all functions have it in scope
code = "local f = {}\n" + code;

// 6. Safe Stealth Host in createDexGui
const safeHostCode = `
function createDexGui()
\tlocal DexGui = CreateInstance("ScreenGui",{DisplayOrder=0,Enabled=true,ResetOnSpawn=false,Name="AethelDex"})
\t
\t-- Stealth parenting
\tlocal hostParent = nil
\tpcall(function()
\t\tlocal gethui = (typeof(getgenv) == "function" and getgenv().gethui) or (typeof(gethui) == "function" and gethui)
\t\tif typeof(gethui) == "function" then
\t\t\thostParent = gethui()
\t\tend
\tend)
\tif not hostParent then
\t\tpcall(function()
\t\t\tlocal syn = (typeof(getgenv) == "function" and getgenv().syn) or syn
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

// Add Save Place button into Explorer TopBar
code = code.replace(
	'local DexGui62 = CreateInstance("TextButton",{Font=3,FontSize=5,Text="",TextColor3=Color3.new(0.10588236153126,0.16470588743687,0.20784315466881),TextScaled=false,TextSize=14,TextStrokeColor3=Color3.new(0,0,0),TextStrokeTransparency=1,TextTransparency=0,TextWrapped=false,TextXAlignment=2,TextYAlignment=1,AutoButtonColor=true,Modal=false,Selected=false,Style=0,Active=true,AnchorPoint=Vector2.new(0,0),BackgroundColor3=Color3.new(0.21960785984993,0.21960785984993,0.21960785984993),BackgroundTransparency=1,BorderColor3=Color3.new(0.10588236153126,0.16470588743687,0.20784315466881),BorderSizePixel=0,ClipsDescendants=false,Draggable=false,Position=UDim2.new(1,-25,0,25),Rotation=0,Selectable=true,Size=UDim2.new(0,25,0,25),SizeConstraint=0,Visible=true,ZIndex=1,Name="Settings",Parent = DexGui55})',
	`local savePlaceTopBtn = CreateInstance("TextButton",{Font=3,FontSize=5,Text="💾 Save Place",TextColor3=Color3.fromRGB(240,240,240),TextScaled=false,TextSize=11,TextStrokeColor3=Color3.new(0,0,0),TextStrokeTransparency=1,TextTransparency=0,TextWrapped=false,TextXAlignment=2,TextYAlignment=1,AutoButtonColor=true,Modal=false,Selected=false,Style=0,Active=true,AnchorPoint=Vector2.new(0,0),BackgroundColor3=Color3.fromRGB(35,85,155),BackgroundTransparency=0,BorderColor3=Color3.new(0,0,0),BorderSizePixel=0,ClipsDescendants=false,Draggable=false,Position=UDim2.new(1,-115,0,2),Rotation=0,Selectable=true,Size=UDim2.new(0,85,0,21),SizeConstraint=0,Visible=true,ZIndex=5,Name="SavePlaceBtn",Parent = DexGui55})
	local spc = Instance.new("UICorner") spc.CornerRadius = UDim.new(0, 4) spc.Parent = savePlaceTopBtn
	savePlaceTopBtn.MouseButton1Click:Connect(function()
		savePlaceTopBtn.Text = "Saving..."
		task.spawn(function()
			local ok, err = pcall(function()
				f.savePlace({mode = "full", decompile = true, native = true})
			end)
			if not ok then
				warn("[AethelDex SavePlace Error]: " .. tostring(err))
			end
			task.delay(3, function()
				pcall(function() savePlaceTopBtn.Text = "💾 Save Place" end)
			end)
		end)
	end)
	local DexGui62 = CreateInstance("TextButton",{Font=3,FontSize=5,Text="",TextColor3=Color3.new(0.10588236153126,0.16470588743687,0.20784315466881),TextScaled=false,TextSize=14,TextStrokeColor3=Color3.new(0,0,0),TextStrokeTransparency=1,TextTransparency=0,TextWrapped=false,TextXAlignment=2,TextYAlignment=1,AutoButtonColor=true,Modal=false,Selected=false,Style=0,Active=true,AnchorPoint=Vector2.new(0,0),BackgroundColor3=Color3.new(0.21960785984993,0.21960785984993,0.21960785984993),BackgroundTransparency=1,BorderColor3=Color3.new(0.10588236153126,0.16470588743687,0.20784315466881),BorderSizePixel=0,ClipsDescendants=false,Draggable=false,Position=UDim2.new(1,-25,0,25),Rotation=0,Selectable=true,Size=UDim2.new(0,25,0,25),SizeConstraint=0,Visible=true,ZIndex=1,Name="Settings",Parent = DexGui55})`
);

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
code = code.replace(/local activeWindows = \{\}[\r\n\s]+local f = \{\}/, `local activeWindows = {}
-- f already declared at top
f = f or {}`);
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

\t-- Save Place & Reverse Engineering Suite
\trightClickContext:AddDivider()
\trightClickContext:Add({Name = "💾 Save Place (.rbxl / Full)", Icon = "", DisabledIcon = "", Shortcut = "", Disabled = false, OnClick = function()
\t\tf.savePlace({mode = "full", decompile = true, native = true})
\t\trightClickContext:Hide()
\t\tend})
\trightClickContext:Add({Name = "📁 Dump All Scripts & Remotes", Icon = "", DisabledIcon = "", Shortcut = "", Disabled = false, OnClick = function()
\t\tf.savePlace({mode = "full", decompile = true, native = false})
\t\trightClickContext:Hide()
\t\tend})
\tif #selection.List > 0 then
\t\trightClickContext:Add({Name = "💾 Save Selected Instance", Icon = "", DisabledIcon = "", Shortcut = "", Disabled = false, OnClick = function()
\t\t\tf.saveInstanceTree(selection.List[1])
\t\t\trightClickContext:Hide()
\t\tend})
\tend

\t-- Parts`;

code = code.replace(/\t-- Parts/, rightClickScriptBlock);

// Hook SavePlaceBtn in f.hookWindowListener so all cloned active windows connect to f.savePlace
const newHookWindowClose = `\twindow.TopBar.Close.MouseButton1Click:connect(function()
\t\tif f.checkInPane(window) then f.removeFromPane(window) window.Visible = false return end
\t\twindow.Content:TweenSize(UDim2.new(1,-4,0,0),Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.4,true)
\t\ttask.wait(0.4)
\t\twindow.Visible = false
\tend)

\tlocal savePlaceBtn = window.TopBar:FindFirstChild("SavePlaceBtn")
\tif savePlaceBtn then
\t\tsavePlaceBtn.MouseButton1Click:Connect(function()
\t\t\tsavePlaceBtn.Text = "Saving..."
\t\t\ttask.spawn(function()
\t\t\t\tlocal ok, err = pcall(function()
\t\t\t\t\tf.savePlace({mode = "full", decompile = true, native = true})
\t\t\t\tend)
\t\t\t\tif not ok then
\t\t\t\t\twarn("[AethelDex SavePlace Error]: " .. tostring(err))
\t\t\t\tend
\t\t\t\ttask.delay(2, function()
\t\t\t\t\tpcall(function() savePlaceBtn.Text = "💾 Save Place" end)
\t\t\t\tend)
\t\t\tend)
\t\tend)
\tend`;

code = code.replace(/window\.TopBar\.Close\.MouseButton1Click:Connect\(function\(\)[\s\S]*?window\.Visible = false\r?\n\tend\)/i, newHookWindowClose);

// Inject AethelDex Multi-Tier Decompiler Suite
const decompilerSuite = fs.readFileSync(path.join(__dirname, '..', 'src', 'Decompiler', 'AethelDecompiler.lua'), 'utf8');
code = code.replace(/function f\.newExplorer\(\)/, decompilerSuite + "\nfunction f.newExplorer()");

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
    lag-free lazy folder expansion, and built-in universal decompiler engine.
    
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
