---Field names mirror UnitDef's exactly, so Rules runs on a facts table or
---a def alike — one read through the engine proxy per def, ever.
---@class TransportDefFacts
---@field isTransport boolean
---@field isFactory boolean
---@field mass number
---@field speed number
---@field xsize integer
---@field cantBeTransported boolean
---@field transportCapacity integer|nil
---@field transportSize integer|nil
---@field minTransportSize integer|nil
---@field transportMass number|nil
---@field minTransportMass number|nil
---@field footprintX number the engine-scaled xsize

local Rules = VFS.Include("modules/transport/lib/rules.lua") ---@type TransportRules

---@class TransportDefs
local Defs = {}

local cache = {} ---@type table<integer, TransportDefFacts>

---@param unitDefID number|nil
---@return TransportDefFacts|nil
function Defs.Of(unitDefID)
	if unitDefID == nil then
		return nil
	end
	---@cast unitDefID integer
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
			xsize = def.xsize,
			cantBeTransported = def.cantBeTransported,
			transportCapacity = def.transportCapacity,
			transportSize = def.transportSize,
			minTransportSize = def.minTransportSize,
			transportMass = def.transportMass,
			minTransportMass = def.minTransportMass,
			footprintX = def.xsize / Rules.FOOTPRINT_SCALE,
		}
		cache[unitDefID] = facts
	end
	return facts
end

---@param unitID integer|nil
---@return TransportDefFacts|nil
function Defs.OfUnit(unitID)
	if unitID == nil then
		return nil
	end
	return Defs.Of(Spring.GetUnitDefID(unitID))
end

return Defs
