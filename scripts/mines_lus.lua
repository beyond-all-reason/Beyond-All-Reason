
local base = piece("base")
local unitDefID = Spring.GetUnitDefID(unitID)
local triggerRange = tonumber(UnitDefs[unitDefID].customParams.detonaterange) or 64
local SpGetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local stop_detect = 1
local currentFireState = 2 -- default to fire at will, UnitCommand will change it on StatePrefs triggering
local isBuilt = false

-- Author: Doo update jan 2026

function FireStateChange(toFireState)
	currentFireState = toFireState -- update fireState on cmds
	if not isBuilt then -- gate by isBuilt, because units being built can be set to fire at will
		return
	end
	if toFireState < 2 then
		Signal(stop_detect)
	else
		Signal(stop_detect) -- in case called while already active
		StartThread(EnemyDetect)
	end
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
	isBuilt = Spring.GetUnitIsBeingBuilt(unitID) == false
	while (not isBuilt) do
		isBuilt = Spring.GetUnitIsBeingBuilt(unitID) == false
		Sleep(500)
	end
	if currentFireState == 2 then -- gate by fireState (isBuilt already gated)
		StartThread(EnemyDetect)
	end
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

function SetStunned(isStunned) -- called by unit_stun_script.lua
	if isStunned then
		Signal(stop_detect)
	else
		if isBuilt and currentFireState == 2 then -- gate by fireState AND isBuilt (because units being built can become unstunned)
			StartThread(EnemyDetect)
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