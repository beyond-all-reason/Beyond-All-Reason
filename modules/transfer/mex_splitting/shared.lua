
---@class MexRegionsShared
local Shared = {}

---@param x number
---@param z number
---@return string
function Shared.SpotKey(x, z)
	return math.floor(x + 0.5) .. "x" .. math.floor(z + 0.5)
end

Shared.LAYOUT_MSG = "mex_splitting_layout:" -- a widget handing the gadget the terraformer's save, before the start

return Shared
