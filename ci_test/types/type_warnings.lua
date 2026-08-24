-- CI fixture. Deliberately broken; delete ci_test/ before merging.

---@param maybe string|nil
---@return number
local function measure(maybe)
	return #maybe
end

---@param opts table?
local function useOptions(opts)
	return opts.enabled
end

local unusedLocal = 12

return { measure = measure, useOptions = useOptions }
