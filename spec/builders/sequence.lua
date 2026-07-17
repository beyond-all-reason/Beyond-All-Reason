-- Per-prefix sequence counters for tests/builders
-- Usage:
--   local seq = require("common.unitTesting.seq")
--   local nextUser   = seq.sequence("user_", { start = 1 })   -- "user_1","user_2",...
--   local nextTeamId = seq.sequence("team#", { start = 100 }) -- "team#100","team#101",...

local M = {}

-- private counter store (prefix -> next integer)
local _counters = {} ---@type table<string, integer>

---@class SequenceOptions
---@field start integer|nil   -- first number to emit (default 1)
---@field step integer|nil    -- increment step (default 1)
---@field format (fun(prefix:string, n:integer): string|integer)|nil -- optional formatter

---Get current counter for prefix (or defaultStart - 1 if unset)
---@param prefix string
---@param defaultStart integer?
---@return integer
local function current(prefix, defaultStart)
	local n = _counters[prefix]
	if n == nil then
		return (defaultStart or 1) - 1
	end
	return n - 1
end

---Create a generator function tied to a prefix (& cached counter)
---@param prefix string
---@param opts SequenceOptions|nil
---@return fun(): string|integer
function M.sequence(prefix, opts)
	opts = opts or ({} --[[@as SequenceOptions]])
	local start = opts.start or 1
	local step = opts.step or 1
	local fmt = opts.format or function(p, n)
		return p .. tostring(n)
	end

	-- If first time seeing this prefix, initialize its next value
	if _counters[prefix] == nil then
		_counters[prefix] = start
	end

	return function()
		local n = _counters[prefix] --[[@as integer]] -- initialized above
		_counters[prefix] = n + step
		local str = fmt(prefix, n)
		if str == nil then
			str = prefix .. tostring(n)
		end
		return str
	end
end

---Peek without incrementing
---@param prefix string
---@param defaultStart integer|nil
---@return integer
function M.peek(prefix, defaultStart)
	return current(prefix, defaultStart)
end

---Force the next value (useful in tests)
---@param prefix string
---@param nextValue integer
function M.set(prefix, nextValue)
	_counters[prefix] = nextValue
end

---Reset one prefix (or all if nil)
---@param prefix string|nil
function M.reset(prefix)
	if prefix == nil then
		for k in pairs(_counters) do
			_counters[k] = nil
		end
	else
		_counters[prefix] = nil
	end
end

return M
