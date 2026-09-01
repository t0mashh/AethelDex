--!strict
-- [TreeState.luau]
-- DataModel hierarchy state, expansion tracker, and selection manager for AethelDex

local Signal = require(script.Parent.Parent.Core.Signal)

export type Node = {
	Instance: Instance,
	Depth: number,
	Expanded: boolean,
	HasChildren: boolean,
	ParentNode: Node?,
	Children: { Node },
}

export type TreeState = {
	RootNodes: { Node },
	NodeMap: { [Instance]: Node },
	FlattenedList: { Node },
	SelectedInstances: { [Instance]: boolean },
	SelectionList: { Instance },
	
	OnSelectionChanged: Signal.Signal<{ Instance }>,
	OnTreeStructureChanged: Signal.Signal<()>,

	ToggleExpand: (self: TreeState, node: Node) -> (),
	SetExpanded: (self: TreeState, node: Node, expanded: boolean) -> (),
	Select: (self: TreeState, inst: Instance, isMulti: boolean?) -> (),
	Deselect: (self: TreeState, inst: Instance) -> (),
	ClearSelection: (self: TreeState) -> (),
	RebuildFlattened: (self: TreeState) -> (),
	AddRootService: (self: TreeState, service: Instance) -> (),
}

local TreeState = {}
TreeState.__index = TreeState

function TreeState.new()
	local self = setmetatable({
		RootNodes = {},
		NodeMap = {},
		FlattenedList = {},
		SelectedInstances = {},
		SelectionList = {},

		OnSelectionChanged = Signal.new(),
		OnTreeStructureChanged = Signal.new(),
	}, TreeState)

	return self
end

function TreeState:CreateNode(inst, depth, parentNode)
	local hasKids = #inst:GetChildren() > 0
	local node = {
		Instance = inst,
		Depth = depth,
		Expanded = false,
		HasChildren = hasKids,
		ParentNode = parentNode,
		Children = {},
	}
	self.NodeMap[inst] = node
	return node
end

function TreeState:AddRootService(service)
	if self.NodeMap[service] then
		return
	end
	local rootNode = self:CreateNode(service, 0, nil)
	table.insert(self.RootNodes, rootNode)
	self:RebuildFlattened()
end

function TreeState:PopulateChildren(node)
	local children = node.Instance:GetChildren()
	node.HasChildren = #children > 0
	table.clear(node.Children)

	for _, child in ipairs(children) do
		local childNode = self.NodeMap[child]
		if not childNode then
			childNode = self:CreateNode(child, node.Depth + 1, node)
		else
			childNode.Depth = node.Depth + 1
			childNode.ParentNode = node
		end
		table.insert(node.Children, childNode)
	end
end

function TreeState:ToggleExpand(node)
	self:SetExpanded(node, not node.Expanded)
end

function TreeState:SetExpanded(node, expanded)
	if node.Expanded == expanded then
		return
	end

	node.Expanded = expanded
	if expanded then
		self:PopulateChildren(node)
	end

	self:RebuildFlattened()
	self.OnTreeStructureChanged:Fire()
end

local function flattenRecursive(node, output)
	table.insert(output, node)
	if node.Expanded then
		for _, child in ipairs(node.Children) do
			flattenRecursive(child, output)
		end
	end
end

function TreeState:RebuildFlattened()
	table.clear(self.FlattenedList)
	for _, root in ipairs(self.RootNodes) do
		flattenRecursive(root, self.FlattenedList)
	end
end

function TreeState:Select(inst, isMulti)
	if not isMulti then
		table.clear(self.SelectedInstances)
		table.clear(self.SelectionList)
	end

	if not self.SelectedInstances[inst] then
		self.SelectedInstances[inst] = true
		table.insert(self.SelectionList, inst)
	end

	self.OnSelectionChanged:Fire(self.SelectionList)
end

function TreeState:Deselect(inst)
	if self.SelectedInstances[inst] then
		self.SelectedInstances[inst] = nil
		for i, selected in ipairs(self.SelectionList) do
			if selected == inst then
				table.remove(self.SelectionList, i)
				break
			end
		end
		self.OnSelectionChanged:Fire(self.SelectionList)
	end
end

function TreeState:ClearSelection()
	table.clear(self.SelectedInstances)
	table.clear(self.SelectionList)
	self.OnSelectionChanged:Fire(self.SelectionList)
end

return TreeState
