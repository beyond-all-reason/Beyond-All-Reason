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
---@field halfX number half the footprint in elmos along x at facing 0
---@field halfZ number half the footprint in elmos along z at facing 0
---@field floatOnWater boolean
---@field minWaterDepth number
---@field maxWaterDepth number
---@field isCarrierDrone boolean a unit a carrier spawns and releases itself: never pinned where it was set down

local Spring = Spring --[[@as Recoil.Shared]]
local UnitDefs = UnitDefs
local UnitDefNames = UnitDefNames ---@type table<string, UnitDef|nil>|nil absent in a spec that fakes only UnitDefs
local WeaponDefs = WeaponDefs

local Rules = require("modules/transport/lib/rules")

---@class TransportTraits
local Traits = {}

local cache = {} ---@type table<integer, TransportDefTraits>

-- The units carriers spawn: named by the carrier weapon's carried_unit, one or several
---@type table<integer, boolean>|nil unit def id -> true; built on first use
local carrierDrones = nil

---@param unitDefID integer
---@return boolean
local function isCarrierDrone(unitDefID)
	if carrierDrones == nil then
		carrierDrones = {}
		for _, weaponDef in pairs(WeaponDefs or {}) do
			local carried = weaponDef.customParams and weaponDef.customParams.carried_unit
			if carried then
				for name in tostring(carried):gmatch("%S+") do
					local def = UnitDefNames and UnitDefNames[name]
					if def then
						carrierDrones[def.id] = true
					end
				end
			end
		end
	end
	return carrierDrones[unitDefID] == true
end

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
			halfX = def.xsize * Rules.ELMOS_PER_FOOTPRINT_CELL / 2,
			halfZ = def.zsize * Rules.ELMOS_PER_FOOTPRINT_CELL / 2,
			floatOnWater = def.floatOnWater == true,
			minWaterDepth = def.minWaterDepth,
			maxWaterDepth = def.maxWaterDepth,
			isCarrierDrone = isCarrierDrone(unitDefID),
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
