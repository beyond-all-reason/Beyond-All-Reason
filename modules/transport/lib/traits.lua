---@class TransportDefTraits
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

---@class TransportTraits
local Traits = {}

local cache = {} ---@type table<integer, TransportDefTraits>

---@param unitDefID integer
---@return TransportDefTraits
function Traits.Of(unitDefID)
	local traits = cache[unitDefID]
	if traits == nil then
		local def = UnitDefs[unitDefID] ---@type table|nil
		assert(def ~= nil, "transport: no unit def " .. tostring(unitDefID))
		traits = {
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
		cache[unitDefID] = traits
	end
	return traits
end

---@param unitID integer|nil
---@return TransportDefTraits|nil
function Traits.OfUnit(unitID)
	local unitDefID = unitID ~= nil and Spring.GetUnitDefID(unitID) or nil
	if unitDefID == nil then
		return nil
	end
	return Traits.Of(unitDefID)
end

return Traits
