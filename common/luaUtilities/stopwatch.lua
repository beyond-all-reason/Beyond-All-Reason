--------------------------------------------------------------------------------
-- Stopwatch utility for performance auditing
-- Usage:
--   local Stopwatch = VFS.Include("common/luaUtilities/stopwatch.lua")
--   local sw = Stopwatch.new(timerFunc)
--   sw:Start()
--   -- do work
--   sw:Breakpoint("WorkName")
--   sw:Log(frame)
--------------------------------------------------------------------------------

local Stopwatch = {}
Stopwatch.__index = Stopwatch

function Stopwatch.new(timerFunc)
	local self = setmetatable({}, Stopwatch)
	self.timer = timerFunc or function() return 0 end
	self.startTime = 0
	self.lastTime = 0
	self.breakpoints = {}
	return self
end

function Stopwatch:Start()
	self.startTime = self.timer()
	self.lastTime = self.startTime
	self.breakpoints = {}
end

function Stopwatch:Breakpoint(name)
	local now = self.timer()
	self.breakpoints[#self.breakpoints + 1] = {
		name = name,
		duration = now - self.lastTime
	}
	self.lastTime = now
end

function Stopwatch:Total()
	return self.timer() - self.startTime
end

function Stopwatch:Log(frame, prefix)
	prefix = prefix or "[SolverAudit]"
	for _, bp in ipairs(self.breakpoints) do
		Spring.Echo(string.format("%s frame=%d metric=%s time_us=%.2f", prefix, frame, bp.name, bp.duration))
	end
end

function Stopwatch:Iterator()
	local i = 0
	return function()
		i = i + 1
		local bp = self.breakpoints[i]
		if bp then
			return bp.name, bp.duration
		end
	end
end

return Stopwatch


