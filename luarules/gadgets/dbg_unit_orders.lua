local gadget = gadget ---@type Gadget

local VERBOSE = false -- this print the whole table, instead of the count of indexes in the table
local PING = false -- this will add a ping on the map when a UnitCmdDone is called, showing the command that was done and the tag of the command

function gadget:GetInfo()
	return {
		name = "Unit Orders Debug",
		desc = "Debug the life cycle of unit orders",
		author = "uBdead",
		date = "May 2026",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = false
	}
end

local function count(tbl)
	if VERBOSE then
		return tbl
	end
	
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

local function command(cmdID)
	if cmdID == CMD.STOP then
		return "CMD.STOP"
	elseif cmdID == CMD.INSERT then
		return "CMD.INSERT"
	elseif cmdID == CMD.REMOVE then
		return "CMD.REMOVE"
	elseif cmdID == CMD.WAIT then
		return "CMD.WAIT"
	elseif cmdID == CMD.TIMEWAIT then
		return "CMD.TIMEWAIT"
	elseif cmdID == CMD.DEATHWAIT then
		return "CMD.DEATHWAIT"
	elseif cmdID == CMD.SQUADWAIT then
		return "CMD.SQUADWAIT"
	elseif cmdID == CMD.GATHERWAIT then
		return "CMD.GATHERWAIT"
	elseif cmdID == CMD.MOVE then
		return "CMD.MOVE"
	elseif cmdID == CMD.PATROL then
		return "CMD.PATROL"
	elseif cmdID == CMD.FIGHT then
		return "CMD.FIGHT"
	elseif cmdID == CMD.ATTACK then
		return "CMD.ATTACK"
	elseif cmdID == CMD.RECLAIM then
		return "CMD.RECLAIM"
	elseif cmdID == CMD.REPAIR then
		return "CMD.REPAIR"
	elseif cmdID == CMD.RESURRECT then
		return "CMD.RESURRECT"
	elseif cmdID == CMD.GUARD then
		return "CMD.GUARD"
	elseif cmdID == CMD.LOAD_UNITS then
		return "CMD.LOAD_UNITS"
	elseif cmdID == CMD.UNLOAD_UNITS then
		return "CMD.UNLOAD_UNITS"
	elseif cmdID == CMD.ONOFF then
		return "CMD.ONOFF"
	elseif cmdID == CMD.CLOAK then
		return "CMD.CLOAK"
	elseif cmdID == CMD.REPEAT then
		return "CMD.REPEAT"
	elseif cmdID == CMD.RESTORE then
		return "CMD.RESTORE"
	elseif cmdID == CMD.FIRE_STATE then
		return "CMD.FIRE_STATE"
	elseif cmdID == CMD.MOVE_STATE then
		return "CMD.MOVE_STATE"
	elseif cmdID == CMD.BUILD then
		return "CMD.BUILD"
	else
		return tostring(cmdID)
	end
end

-- Spring.SetCustomCommandDrawData 
-- 

if gadgetHandler:IsSyncedCode() then
	-- Synced
	function gadget:CommandFallback(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
		if unitTeam ~= 0 then
			return false
		end
		Spring.Echo("CommandFallback", unitID, unitDefID, unitTeam, command(cmdID), count(cmdParams), count(cmdOptions), cmdTag)
		return false
	end
	
	function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, fromSynced, fromLua)
		if unitTeam ~= 0 then
			return true
		end

		Spring.Echo("AllowCommand", unitID, unitDefID, unitTeam, command(cmdID), count(cmdParams), count(cmdOptions), cmdTag, fromSynced, fromLua)
		return true
	end
else
	-- Unsynced
	function gadget:CommandNotify(cmdID, cmdParams, cmdOptions)
		Spring.Echo("CommandNotify", command(cmdID), count(cmdParams), count(cmdOptions))

		return false
	end

	local lastDefaultCommandKey = nil
	function gadget:DefaultCommand(type, unitID)
		local key = (type or "nil") .. ":" .. (unitID or "nil")
		if unitID ~= nil and key ~= lastDefaultCommandKey then
			Spring.Echo("DefaultCommand", type, unitID)
			lastDefaultCommandKey = key
		end
	end
	
	function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
		if unitTeam ~= 0 then
			return
		end
		
		Spring.Echo("UnitCommand", unitID, unitDefID, unitTeam, command(cmdID), count(cmdParams), count(cmdOptions), cmdTag)
	end
	
	function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
		if unitTeam ~= 0 then
			return
		end

		Spring.Echo("UnitCmdDone", unitID, unitDefID, unitTeam, command(cmdID), count(cmdParams), count(cmdOptions), cmdTag)
		local x, y, z = Spring.GetUnitPosition(unitID)
		if PING then
			Spring.MarkerAddPoint(x, y, z, "UnitCmdDone: " .. command(cmdID) .. " (tag: " .. tostring(cmdTag) .. ")")
		end
	end

	function gadget:UnitIdle(unitID, unitDefID, unitTeam)
		if unitTeam ~= 0 then
			return
		end
		
		Spring.Echo("UnitIdle", unitID, unitDefID, unitTeam)
		Spring.Echo(" ")
	end
end
