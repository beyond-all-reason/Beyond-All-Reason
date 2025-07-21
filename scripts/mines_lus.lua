local Spring_GetUnitDefID = Spring.GetUnitDefID
local Spring_GetUnitPosition = Spring.GetUnitPosition
local Spring_GetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local Spring_GetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local Spring_GetUnitStates = Spring.GetUnitStates
local Spring_GetUnitIsStunned = Spring.GetUnitIsStunned
local Spring_DestroyUnit = Spring.DestroyUnit

local base = piece("base")
local unitDefID = Spring_GetUnitDefID(unitID)
local triggerRange = tonumber(UnitDefs[unitDefID].customParams.detonaterange) or 64
local minFootprint = tonumber(UnitDefs[unitDefID].customParams.minfootprint) or 0

local math_sqrt = math.sqrt

local ux, uy, uz

-- Author: Doo
-- Requires customParams.detonaterange in unitDefs or 64 elmos range will be used
-- It is also possible to limit the detonation to a certain footprint (not mass!) by setting customParams.minfootprint
-- Possible enhancements: Use GetUnitsInCylinder(or sphere) of detonaterange and check for any restriction on target units

function GetClosestEnemy()
	local targetID = Spring_GetUnitNearestEnemy(unitID, triggerRange)
	if targetID then
		local tx, ty, tz = Spring_GetUnitPosition(targetID)
		local distanceVal = distance(ux, uy, uz, tx, ty, tz)
		local targetDefID = Spring_GetUnitDefID(targetID)
	   local footprintVal = UnitDefs[targetDefID].xsize or 0
	   return distanceVal, footprintVal
	else
		return math.huge, 0
	end
end

function distance(x1, y1, z1, x2, y2, z2)
	local x = (x1 - x2)
	local y = (y1 - y2)
	local z = (z1 - z2)
	local dist = math_sqrt(x * x + y * y + z * z)
	return dist
end

function script.AimWeapon()
	return false
end

function script.QueryWeapon()
	return base
end

function script.AimFromWeapon()
	return base
end

function script.FireWeapon()
end

function script.Create()
	ux, uy, uz = Spring_GetUnitPosition(unitID)
	StartThread(EnemyDetect)
end

function EnemyDetect()
	while true do
		if not Spring_GetUnitIsBeingBuilt(unitID) then
			local unitStates = Spring_GetUnitStates(unitID)
			if unitStates and unitStates.firestate and unitStates.firestate > 0 then
				if not Spring_GetUnitIsStunned(unitID) then
					local enemyDist, enemyFootprint = GetClosestEnemy()
				   if enemyDist <= triggerRange then
					   if enemyFootprint >= minFootprint then
						   -- Spring.Echo("MINE DETONATION: " .. unitID .. " at " .. ux .. ", " .. uy .. ", " .. uz .. " triggered by enemy at distance: " .. enemyDist .. " with xsize: " .. enemyFootprint .. " vs minFootprint: " .. minFootprint)
						   StartThread(Detonate)
						   return
					   end
				   end
				end
			end
		end

		Sleep(1)
	end
end

function Detonate()
	Sleep(500)
	Spring_DestroyUnit(unitID, false, false)
end

function script.Killed()
	return 3
end
