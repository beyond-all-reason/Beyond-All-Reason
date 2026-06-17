
local base = piece("base")
local unitDefID = Spring.GetUnitDefID(unitID)
local triggerRange = tonumber(UnitDefs[unitDefID].customParams.detonaterange) or 64
local spGetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local stop_detect = 1
local currentFireState = 2 -- default to fire at will, UnitCommand will change it
local isBuilt = false -- default to false, LUS will update it when the unit is built
local notStunned = true -- default to not stunned, unit_stun_script.lua will change it

-- Author: Doo update jan 2026

local function CheckIfCanDetectAndStartThread()
	-- I don't expect stun/unstun and firestates changes spams to happen
	-- if it happens, maybe gate this branch with an "isActive" bool instead
	-- would avoid starting multiple threads (even though they're always killed immediately)
	if  currentFireState == 2 and notStunned and isBuilt then  -- isBuilt last, because mostly true
		Signal(stop_detect) -- in case was active, else no-op
		StartThread(EnemyDetect)
	else
		Signal(stop_detect) -- in case was active, else no-op
	end
end

function FireStateChange(toFireState)
	currentFireState = toFireState -- update fireState on cmds
	CheckIfCanDetectAndStartThread()
end

function SetStunned(isStunned) -- called by unit_stun_script.lua
	notStunned = not isStunned
	CheckIfCanDetectAndStartThread()
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
	-- this seems to be loaded after the first UnitCommand() CMD.FIRE_STATE is fired, see cmd_mines_firestate.lua comments
	currentFireState = Spring.GetUnitStates(unitID).firestate
	isBuilt = Spring.GetUnitIsBeingBuilt(unitID) == false
	while (not isBuilt) do
		isBuilt = Spring.GetUnitIsBeingBuilt(unitID) == false
		Sleep(500)
	end
	CheckIfCanDetectAndStartThread()
end

function EnemyDetect()
	SetSignalMask(stop_detect)
	while true do
		if spGetUnitNearestEnemy(unitID, triggerRange) ~= nil then
			StartThread(Detonate) -- Makes sure detonation is not cancellable
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