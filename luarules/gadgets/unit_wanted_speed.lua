--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Wanted Speed",
		desc      = "Adds a command which sets maxWantedSpeed.",
		author    = "GoogleFrog",
		date      = "11 November 2018",
		license   = "GNU GPL, v2 or later",
		layer     = -9999999999, -- Before every state toggle gadget.
		enabled   = not CMD.SET_WANTED_MAX_SPEED  --  loaded by default?
	}
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------



--I have no idea what this is trying to do or why
---local CMD_WANTED_SPEED = Spring.Utilities.CMD.WANTED_SPEED

--local wantedCommand = {

	--[CMD_WANTED_SPEED] = true,
--}







		Spring.Echo('hornetdebug wanted_speed loaded')



local units = {}
local moveTypeByDefID = {}
local moveType = 0
do


	--local moveData = {}
	--local moveType = 0
		
			
			
	--local getMovetype = Spring.Utilities.getMovetype
	for i = 1, #UnitDefs do
		--moveTypeByDefID[i] = getMovetype(UnitDefs[i])
		--moveData = spGetUnitMoveTypeData(i)
		
		
		--Spring.Echo("hornet movedef name" .. UnitDefs[i].moveDef.name)
		Spring.Echo("hornet movedef name")
		
		
		Spring.Echo('hornetdebug UnitDefs[i]')
		Spring.Echo(UnitDefs[i])
		for k,v in pairs(UnitDefs[i]) do
		  Spring.Echo(k,v)
		end		
		
		
		
		
		
		moveType = 0
		if UnitDefs[i].moveDef.name == "ground" then moveType = 2 end
		moveTypeByDefID[i] = moveType
	end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local function SetUnitWantedSpeed(unitID, unitDefID, wantedSpeed, forceUpdate)


Spring.Echo("hornet SetUnitWantedSpeed" .. unitID .. "wanted speed " .. (wantedSpeed or 'nil'))

	if not unitDefID then
		return
	end
	if not units[unitID] then
		if not (forceUpdate or wantedSpeed) then
			return
		end
		local moveType = moveTypeByDefID[unitDefID]
		units[unitID] = {
			unhandled = (moveType ~= 1) and (moveType ~= 2), -- Planes are unhandled.
			moveType = moveType,
		}
	end
	
	if units[unitID].unhandled then
		return
	end
	
	if Spring.MoveCtrl.GetTag(unitID) then
		units[unitID].lastWantedSpeed = wantedSpeed
		return
	end
	
	if (not forceUpdate) and (units[unitID].lastWantedSpeed == wantedSpeed) then
		return
	end
	units[unitID].lastWantedSpeed = wantedSpeed
	
	--Spring.Utilities.UnitEcho(unitID, wantedSpeed or "f")
	if units[unitID].moveType == 1 then
		Spring.MoveCtrl.SetGunshipMoveTypeData(unitID, "maxWantedSpeed", (wantedSpeed or 2000))
	elseif units[unitID].moveType == 2 then
		Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxWantedSpeed", (wantedSpeed or 2000))
	end
end



---this makes no sense, why does this chain exist
function GG.ForceUpdateWantedMaxSpeed(unitID, unitDefID, clearWanted)
	SetUnitWantedSpeed(unitID, unitDefID, (not clearWanted) and units and units[unitID] and units[unitID].lastWantedSpeed, true)
end

local function MaintainWantedSpeed(unitID)
	if not (units[unitID] and units[unitID].lastWantedSpeed) then
		return
	end
	
	if Spring.MoveCtrl.GetTag(unitID) then
		return
	end
	
	if units[unitID].moveType == 1 then
		Spring.MoveCtrl.SetGunshipMoveTypeData(unitID, "maxWantedSpeed", units[unitID].lastWantedSpeed)
	elseif units[unitID].moveType == 2 then
		Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxWantedSpeed", units[unitID].lastWantedSpeed)
	end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Command Handling

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID ~= CMD_WANTED_SPEED then
		MaintainWantedSpeed(unitID)
		return true
	end

	local wantedSpeed = cmdParams[1]
	if not (wantedSpeed and teamID) then
		return false
	end
	wantedSpeed = (wantedSpeed > 0) and wantedSpeed
	SetUnitWantedSpeed(unitID, unitDefID, wantedSpeed)

	-- Overkill?
	--for i = 2, #cmdParams do
	--	if teamID == Spring.GetUnitTeam(cmdParams[i]) then
	--		SetUnitWantedSpeed(cmdParams[i], Spring.GetUnitDefID(cmdParams[i]), wantedSpeed)
	--	end
	--end

	return false
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Cleanup

function gadget:UnitDestroyed(unitID)
	units[unitID] = nil
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
