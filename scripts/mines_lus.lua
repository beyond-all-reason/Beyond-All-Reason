
local base = piece("base")
local unitDefID = Spring.GetUnitDefID(unitID)
local triggerRange = tonumber(UnitDefs[unitDefID].customParams.detonaterange) or 64
local SpGetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local math_sqrt = math.sqrt
local stop_detect = 1

-- Author: Doo update jan 2026

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
	local inProgress = Spring.GetUnitIsBeingBuilt(unitID)
	while (inProgress) do
		inProgress = Spring.GetUnitIsBeingBuilt(unitID)
		Sleep(500)
	end
	StartThread(EnemyDetect)
end

function EnemyDetect()
	SetSignalMask(stop_detect)
	while true do
		if SpGetUnitNearestEnemy(unitID, triggerRange) ~= nil then
			StartThread(Detonate) -- I keep this because once the thread starts, a stop_detect signal should not prevent from autodesctruction
			break
		else
			Sleep(1)
		end
	end
end

function SetStunned(a,b) -- called by unit_stun_script.lua
	if b then
		Signal(stop_detect)
	else
		StartThread(EnemyDetect)
	end
end

function script.Activate() -- use on/off rather than firestate toggle
	StartThread(EnemyDetect)
end

function script.Deactivate()
	Signal(stop_detect)
end

function Detonate()
	Sleep(500)
	Spring.DestroyUnit(unitID, false, false)
end

function script.Killed()
	return 3
end