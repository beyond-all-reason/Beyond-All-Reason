---@class TransportDefFacts
---@field isTransport boolean
---@field isFactory boolean
---@field mass number
---@field speed number

---@class TransportDefs
local Defs = {}

local cache = {} ---@type table<integer, TransportDefFacts>

---@param unitDefID integer|nil
---@return TransportDefFacts|nil
function Defs.Of(unitDefID)
	if unitDefID == nil then
		return nil
	end
	local facts = cache[unitDefID]
	if facts == nil then
		local def = UnitDefs[unitDefID] ---@type table|nil
		if def == nil then
			return nil
		end
		facts = {
			isTransport = def.isTransport,
			isFactory = def.isFactory,
			mass = def.mass,
			speed = def.speed,
		}
		cache[unitDefID] = facts
	end
	return facts
end

return Defs
