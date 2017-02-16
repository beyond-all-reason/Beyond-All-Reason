function gadget:GetInfo()
  return {
	name 	= "CMD_RAW_MOVE",
	desc	= "Make unit move ahead at all cost!",
	author	= "xponen",
	date	= "June 12 2014",
	license	= "GNU GPL, v2 or later",
	layer	= 0,
	enabled = true,
  }
end

if gadgetHandler:IsSyncedCode() then

local spGetUnitPosition = Spring.GetUnitPosition
local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spGiveOrderToUnit = Spring.GiveOrderToUnit
include("LuaRules/Configs/customcmds.h.lua")
local boolDef = {}

local moveRawCmdDesc = {
	id		= CMD_RAW_MOVE,
	type	= CMDTYPE.ICON_MAP,
	name	= 'MoveRaw',
	cursor	= 'Move',	-- add with LuaUI?
	action	= 'MoveRaw',
	tooltip = 'Move Toward destination regardless of obstacle.',
	hidden  = true, --not visible on UI
}

local rawMoveCommands = { -- commands that is processed by gadget
	[CMD.INSERT]=true,
	[CMD_RAW_MOVE] = true,
}

function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdTag)
	if (cmdID == CMD_RAW_MOVE) then
		Spring.Echo("Unit cmd done")
        local x, y, z = spGetUnitPosition(unitID)
        Spring.SetUnitMoveGoal(unitID,x,y,z,64,nil,false)
    else
        return false
    end
end

function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions) -- Only calls for custom commands
	if (cmdID ~= CMD_RAW_MOVE) then
		return false
	end

	local x, y, z = spGetUnitPosition(unitID)
	local distSqr = GetDistSqr({x, y, z}, cmdParams)
	if (distSqr > (64)) then
		return true, false -- command was used but don't remove it(unit have not reach destination yet)
	else
        --spGiveOrderToUnit(unitID, CMD.STOP, {}, {})
        Spring.Echo("Removing cmd..")
		return true, true -- command was used, remove it (unit reached destination)
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    Spring.Echo("Allow cmd: " .. cmdID)
	local case = ((cmdID == CMD_RAW_MOVE) and 1) or ((cmdID==CMD.INSERT and cmdParams[2] == CMD_RAW_MOVE) and 2) or 3
    if case < 3  then --NOTE: cmdParams[2] is the real cmdID for CMD.INSERT
        Spring.Echo("Raw moving")
        for k, v in pairs(cmdParams) do
            Spring.Echo(k, v)
        end
        if case == 1 then
            Spring.SetUnitMoveGoal(unitID, cmdParams[1],cmdParams[2],cmdParams[3],64,nil,true)
        else
            Spring.SetUnitMoveGoal(unitID, cmdParams[4],cmdParams[5],cmdParams[6],64,nil,true)  --NOTE: cmdParams[4] is the first real cmdParams for CMD.INSERT. referencing to: unit_teleporter.lua
        end
        return true -- allowed
	end
	return true
end

function GetDistSqr(a, b)
	local x,z = (a[1] - b[1]), (a[3] - b[3])
	return (x*x + z*z)
end

function gadget:Initialize()
	gadgetHandler:RegisterCMDID(CMD_RAW_MOVE)

	for _, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
    spInsertUnitCmdDesc(unitID, moveRawCmdDesc)
end

function gadget:AllowCommand_GetWantedCommand()	
	return rawMoveCommands
end

function gadget:AllowCommand_GetWantedUnitDefID()	
	return boolDef
end
-----------------------------------------------
--UNSYNCED--
-----------------------------------------------
else 

	include("LuaRules/Configs/customcmds.h.lua")
	function gadget:Initialize()
		--Note: IMO we must *allow* LUAUI to draw this command. We already used to seeing skirm command, and it is informative to players. 
		--Also, its informative to widget coder and allow player to decide when to manually micro units (like seeing unit stuck on cliff with jink command)
		gadgetHandler:RegisterCMDID(CMD_RAW_MOVE)
		Spring.SetCustomCommandDrawData(CMD_RAW_MOVE, "", {0.2,0.8,0.2,1}) -- "" mean there's no MOVE cursor if the command is drawn.
	end
end