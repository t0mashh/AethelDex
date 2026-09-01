--!strict
-- [Signal.luau]
-- Ultra-fast linked-list based Signal implementation for AethelDex

local Signal = {}
Signal.__index = Signal

function Signal.new()
	local self = setmetatable({
		_head = nil,
	}, Signal)
	return self
end

function Signal:Connect(fn)
	local node = {
		fn = fn,
		next = self._head,
		prev = nil,
		connected = true,
	}

	if self._head then
		self._head.prev = node
	end
	self._head = node

	local connection
	connection = {
		Connected = true,
		Disconnect = function(conn)
			if not node.connected then
				return
			end
			node.connected = false
			conn.Connected = false

			if node.prev then
				node.prev.next = node.next
			else
				self._head = node.next
			end

			if node.next then
				node.next.prev = node.prev
			end
		end,
	}

	return connection
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Wait()
	local thread = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Fire(...)
	local current = self._head
	while current do
		local nextNode = current.next
		if current.connected then
			task.spawn(current.fn, ...)
		end
		current = nextNode
	end
end

function Signal:DisconnectAll()
	local current = self._head
	while current do
		current.connected = false
		current = current.next
	end
	self._head = nil
end

return Signal
