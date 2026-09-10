local Traits = VFS.Include("modules/transport/lib/traits.lua") ---@type TransportTraits

local MAP_SIZE_X, MAP_SIZE_Z = Game.mapSizeX, Game.mapSizeZ

local WAKE_MARGIN = 32
local wakeRadius = nil ---@type number|nil memoized: the widest nano search radius plus the margin

---@return number
local function getWakeRadius()
	if wakeRadius == nil then
		wakeRadius = WAKE_MARGIN
		for unitDefID, def in pairs(UnitDefs) do
			if def.customParams.isnanoturret then
				wakeRadius = math.max(wakeRadius, Traits.Of(unitDefID).unstackRadius + WAKE_MARGIN)
			end
		end
	end
	return wakeRadius
end

---@class TransportUnstack
local Unstack = {}

---@param unitID integer
---@return table<integer, integer> turrets nano turret -> its def
function Unstack.TurretsUnder(unitID)
	local turrets = {}
	local x, _, z = Spring.GetUnitPosition(unitID)
	if x == nil then
		return turrets
	end
	for _, other in ipairs(Spring.GetUnitsInCylinder(x, z, getWakeRadius())) do
		local otherDefID = Spring.GetUnitDefID(other)
		if Traits.Of(otherDefID).isNano then
			turrets[other] = otherDefID
		end
	end
	return turrets
end

---@param unitID integer
---@param unitDefID integer
---@return boolean done
function Unstack.Step(unitID, unitDefID)
	local traits = Traits.Of(unitDefID)
	local radius = traits.unstackRadius
	local x, _, z = Spring.GetUnitPosition(unitID)
	local allyTeam = Spring.GetUnitAllyTeam(unitID)
	local ax, az, nearestSq = nil, nil, radius * radius + 1
	for _, other in ipairs(Spring.GetUnitsInCylinder(x, z, radius)) do
		if
			other ~= unitID
			and Spring.GetUnitAllyTeam(other) == allyTeam
			and not Traits.Of(Spring.GetUnitDefID(other)).canMove
		then
			local ox, _, oz = Spring.GetUnitPosition(other)
			local ddx, ddz = ox - x, oz - z
			local distSq = ddx * ddx + ddz * ddz
			if distSq < nearestSq then
				ax, az, nearestSq = ox, oz, distSq
			end
		end
	end
	if ax == nil then
		return true
	end
	if Spring.GetUnitTransporter(unitID) then
		return false
	end
	local r = math.random(1, 3)
	local dx, dz = 0, 0
	if r == 1 then
		if x == ax or z == az then
			local testRange = radius * 2
			dx = math.random(-testRange, testRange)
			dz = math.random(-testRange, testRange)
		end
	elseif r == 2 then
		if x > ax then
			dx = math.random(1, 10)
		elseif x < ax then
			dx = -math.random(1, 10)
		end
	else
		if z > az then
			dz = math.random(1, 10)
		elseif z < az then
			dz = -math.random(1, 10)
		end
	end
	if dx == 0 and dz == 0 then
		return false
	end
	local tx, tz = x + dx, z + dz
	if tx < 0 or tx > MAP_SIZE_X or tz < 0 or tz > MAP_SIZE_Z then
		return false
	end
	local y = Spring.GetGroundHeight(tx, tz)
	if -traits.minWaterDepth > y and -traits.maxWaterDepth < y then
		Spring.SetUnitPosition(unitID, tx, tz)
	end
	return false
end

return Unstack
