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
---@field canFly boolean
---@field reach number|nil load reach in elmos; nil for anything that is not an air transport
---@field isCommander boolean
---@field isParatrooper boolean drops with momentum instead of settling
---@field isStealthy boolean
---@field stealthsPassengers boolean a carrier that hides what it carries
---@field isNano boolean a nano turret: loads and sets down under its own rules
---@field leavesGhost boolean
---@field canMove boolean
---@field unstackRadius number elmos around a set-down nano within which an immobile ally counts as stacked
---@field minWaterDepth number
---@field maxWaterDepth number

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
			canFly = def.canFly == true,
			reach = Rules.Reach(def),
			isCommander = def.customParams.iscommander == "1",
			isParatrooper = (def.customParams.paratrooper or def.customParams.subfolder == "other/hats") and true
				or false,
			isStealthy = def.stealth == true,
			stealthsPassengers = def.customParams.stealths_passengers ~= nil,
			isNano = def.customParams.isnanoturret ~= nil,
			leavesGhost = def.leavesGhost == true,
			canMove = def.canMove == true,
			unstackRadius = math.floor((def.xsize + def.zsize) * 0.5 * 6),
			minWaterDepth = def.minWaterDepth,
			maxWaterDepth = def.maxWaterDepth,
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
