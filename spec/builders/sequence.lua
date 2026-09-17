-- Per-prefix counters behind the builders' generated IDs.
--
-- The spec helper's VFS.Include re-runs this file on every include, so a spec file gets
-- its own counters rather than picking up where the file before it stopped.

local M = {}

local _counters = {}

---@class SequenceOptions
---@field start integer|nil   -- first number to emit (default 1)
---@field step integer|nil    -- increment step (default 1)
---@field format fun(prefix:string, n:integer):string|nil -- optional formatter

---Create a generator function tied to a prefix (& cached counter)
---@param prefix string
---@param opts SequenceOptions|nil
---@return fun():string
function M.sequence(prefix, opts)
	opts = opts or {}
	local start = opts.start or 1
	local step = opts.step or 1
	local fmt = opts.format or function(p, n)
		return p .. tostring(n)
	end

	if _counters[prefix] == nil then
		_counters[prefix] = start
	end

	return function()
		local n = _counters[prefix]
		_counters[prefix] = n + step
		local str = fmt(prefix, n)
		if str == nil then
			str = prefix .. tostring(n)
		end
		return str
	end
end

return M
