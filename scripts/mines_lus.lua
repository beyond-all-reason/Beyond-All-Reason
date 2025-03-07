
local base = piece("base")
local unitDefID = Spring.GetUnitDefID(unitID)
local triggerRange = tonumber(UnitDefs[unitDefID].customParams.detonaterange) or 64

local math_sqrt = math.sqrt

-- Author: Doo
-- Requires customParams.detonaterange in unitDefs or 64 elmos range will be used
-- Possible enhancements: Use GetUnitsInCylinder(or sphere) of detonaterange and check for any restriction on target units

function GetClosestEnemyDistance()
	targetID = Spring.GetUnitNearestEnemy(unitID, triggerRange)
	if targetID then
		local tx,ty,tz = Spring.GetUnitPosition(targetID)
		local dis = distance(ux,uy,uz,tx,ty,tz)
		return dis
	else
		return math.huge
	end
end

function distance(x1,y1,z1,x2,y2,z2)
	local x = (x1-x2)
	local y = (y1-y2)
	local z = (z1-z2)
	local dist = math_sqrt(x*x + y*y + z*z)
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
	ux,uy,uz = Spring.GetUnitPosition(unitID)
	StartThread(EnemyDetect)
end

function EnemyDetect()
	while true do
		local inProgress = Spring.GetUnitIsBeingBuilt(unitID)
		local firestate = Spring.GetUnitStates(unitID, false)
		local stunned = Spring.GetUnitIsStunned (unitID) 
		if not inProgress and firestate and firestate > 0 and GetClosestEnemyDistance() <= triggerRange and not stunned then
			StartThread(Detonate)
			break
		else
			Sleep(1)
		end
	end
end

function Detonate()
	Sleep(500)
	Spring.DestroyUnit(unitID, false, false)
end

function script.Killed()
	return 3
end