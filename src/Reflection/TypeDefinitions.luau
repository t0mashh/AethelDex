--!strict
-- [TypeDefinitions.luau]
-- Core type definitions for AethelDex v1.0

export type TreeNode = {
	Instance: Instance,
	Depth: number,
	HasChildren: boolean,
	IsExpanded: boolean,
	Visible: boolean,
	Children: { TreeNode },
	Parent: TreeNode?,
	CustomIcon: string?,
}

export type PropertyDescriptor = {
	Name: string,
	ValueType: string,
	Category: string,
	IsReadOnly: boolean,
	IsHidden: boolean,
	Value: any,
}

export type NetworkCallLog = {
	Id: string,
	Timestamp: number,
	Remote: Instance,
	RemoteType: "RemoteEvent" | "RemoteFunction" | "UnreliableRemoteEvent",
	Method: "FireServer" | "InvokeServer" | "OnClientEvent",
	Arguments: { any },
	CallerScript: Instance?,
	Blocked: boolean,
}

export type SearchFilter = {
	Query: string,
	ClassName: string?,
	PropertyName: string?,
	PropertyValue: string?,
	Tag: string?,
	IsRegex: boolean,
}

return {}
