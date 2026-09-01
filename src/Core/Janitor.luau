--!strict
-- [Janitor.luau]
-- Safe lifecycle management and connection cleaner for AethelDex

local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
	local self = setmetatable({
		_objects = {},
	}, Janitor)
	return self
end

function Janitor:Add(object, methodName)
	if object == nil then
		return object
	end
	self._objects[object] = methodName or true
	return object
end

function Janitor:Remove(object)
	self._objects[object] = nil
end

local function cleanObject(object, method)
	if typeof(object) == "RBXScriptConnection" then
		object:Disconnect()
	elseif typeof(object) == "Instance" then
		object:Destroy()
	elseif typeof(object) == "function" then
		task.spawn(object)
	elseif typeof(object) == "thread" then
		task.cancel(object)
	elseif typeof(object) == "table" then
		if typeof(method) == "string" and typeof(object[method]) == "function" then
			object[method](object)
		elseif typeof(object.Destroy) == "function" then
			object:Destroy()
		elseif typeof(object.Disconnect) == "function" then
			object:Disconnect()
		end
	end
end

function Janitor:Cleanup()
	local objects = self._objects
	self._objects = {}

	for object, method in pairs(objects) do
		cleanObject(object, method)
	end
end

function Janitor:Destroy()
	self:Cleanup()
end

return Janitor
