---@class TransportRules
local Rules = {}

local REACH_BASIC = 20
local REACH_TECH = 30

Rules.UNLOAD_SETTLE_FRAMES = 10
Rules.PARATROOPER_MAX_VELOCITY = 10
Rules.PARATROOPER_GROUND_MARGIN = 5

-- The engine compares footprints at twice the def's size.
Rules.FOOTPRINT_SCALE = 2

---@param unitDef table
---@return number|nil reach nil for anything that is not an air transport
function Rules.Reach(unitDef)
	if not (unitDef.canFly and unitDef.isTransport) then
		return nil
	end
	if unitDef.customParams.techlevel then
		return REACH_TECH
	end
	return REACH_BASIC
end

---@param distance number
---@param reach number|nil
---@return boolean
function Rules.WithinReach(distance, reach)
	return reach == nil or distance <= reach
end

---@param y number the unit's (or the goal's) height
---@param height number|nil the unit's model height
---@return boolean
function Rules.Submerged(y, height)
	return height == nil or y + height < 0
end

---@param velocity number
---@return number clamped
function Rules.ClampParatrooperVelocity(velocity)
	local max = Rules.PARATROOPER_MAX_VELOCITY
	if velocity > max then
		return max
	elseif velocity < -max then
		return -max
	end
	return velocity
end

---@param transportDef table
---@param unitDef table
---@param carriedMass number|nil mass already aboard
---@param carriedCount integer|nil units already aboard
---@return boolean
function Rules.CanCarry(transportDef, unitDef, carriedMass, carriedCount)
	if not transportDef.isTransport or unitDef.cantBeTransported then
		return false
	end
	if carriedCount and transportDef.transportCapacity and carriedCount >= transportDef.transportCapacity then
		return false
	end
	if unitDef.xsize > (transportDef.transportSize or 0) * Rules.FOOTPRINT_SCALE then
		return false
	end
	if unitDef.xsize < (transportDef.minTransportSize or 0) * Rules.FOOTPRINT_SCALE then
		return false
	end
	if unitDef.mass < (transportDef.minTransportMass or 0) then
		return false
	end
	return unitDef.mass + (carriedMass or 0) <= (transportDef.transportMass or 0)
end

return Rules
