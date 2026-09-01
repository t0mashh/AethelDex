--!strict
-- [Signal.luau]
-- Ultra-fast linked-list based Signal implementation for AethelDex

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

type Node = {
	fn: (...any) -> (),
	next: Node?,
	prev: Node?,
	connected: boolean,
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({
		_head = nil :: Node?,
	}, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal:Connect(fn: (...any) -> ()): Connection
	local node: Node = {
		fn = fn,
		next = self._head,
		prev = nil,
		connected = true,
	}

	if self._head then
		self._head.prev = node
	end
	self._head = node

	local connection: Connection
	connection = {
		Connected = true,
		Disconnect = function(conn: Connection)
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

function Signal:Once(fn: (...any) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Fire(...: any)
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
