-- Per-prefix sequence counters for builders.
--
-- Counters live for one VFS.Include of this file, which the spec helper re-runs
-- per include, so each spec file gets its own numbering and IDs do not depend on
-- how many teams the files before it built.

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
