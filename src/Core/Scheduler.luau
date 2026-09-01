--!strict
-- [Scheduler.luau]
-- Non-blocking coroutine and chunked frame scheduler for AethelDex

local Scheduler = {}

-- Maximum time in seconds to spend in a single frame before yielding to avoid dropping FPS
local DEFAULT_FRAME_BUDGET = 0.006 -- 6 milliseconds

function Scheduler.ChunkedIterate(list, processItem, onComplete, maxTimePerFrame)
	local budget = maxTimePerFrame or DEFAULT_FRAME_BUDGET
	local total = #list
	local index = 1

	task.spawn(function()
		local startTime = os.clock()

		while index <= total do
			local shouldContinue = processItem(list[index], index)
			if shouldContinue == false then
				break
			end

			index = index + 1

			if os.clock() - startTime >= budget then
				task.wait()
				startTime = os.clock()
			end
		end

		if onComplete then
			onComplete()
		end
	end)
end

function Scheduler.Defer(fn)
	task.defer(fn)
end

function Scheduler.Delay(seconds, fn)
	task.delay(seconds, fn)
end

return Scheduler
