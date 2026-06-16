local gadget = gadget ---@type Gadget


--- TO USE: CHANGE THIS TO TRUE
local ENABLED = false -- set to true to enable the gadget, it will print a lot of info about unit orders
-------------------------------

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
		enabled = ENABLED,
	}
end

local CMDnames = {}
for cmdName, cmdID in pairs(CMD) do
	CMDnames[cmdID] = "CMD." .. cmdName
end

-- also add the GameCMD names, specific for BAR
for cmdName, cmdID in pairs(GameCMD) do
	CMDnames[cmdID] = "GameCMD." .. cmdName
end

local function summaryOrSomething(tbl)
	if VERBOSE then
		return tbl
	end

	return table.count(tbl)
end

local function command(cmdID)
	local ret
	
	-- Typically negative IDs are build/construct commands
	if cmdID < 0 then
		local unitDefName = UnitDefs[-cmdID].name
		return "BUILD(" .. unitDefName .. ")"
	end

	-- Try to get the command name from the global CMD table
	ret = CMDnames[cmdID]
	if ret then
		return ret
	end

	-- If not found, return UKNOWN with the cmdID
	return "UNKNOWN(" .. cmdID .. ")"
end

-- Spring.SetCustomCommandDrawData 
-- 

if gadgetHandler:IsSyncedCode() then
	-- Synced
	function gadget:CommandFallback(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
		if unitTeam ~= 0 then
			return false
		end
		Spring.Echo("CommandFallback", "uID", unitID, "defID", unitDefID,   command(cmdID), "params", summaryOrSomething(cmdParams), "opts", summaryOrSomething(cmdOptions), "tag", cmdTag)
		return false
	end
	
	function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, fromSynced, fromLua)
		if unitTeam ~= 0 then
			return true
		end

		Spring.Echo("AllowCommand", "uID", unitID, "defID", unitDefID,   command(cmdID), "params", summaryOrSomething(cmdParams), "opts", summaryOrSomething(cmdOptions), "tag", cmdTag, "synced", fromSynced, "lua", fromLua)
		return true
	end
else
	-- Unsynced
	function gadget:CommandNotify(cmdID, cmdParams, cmdOptions)
		Spring.Echo("CommandNotify",  command(cmdID), "params", summaryOrSomething(cmdParams), "opts", summaryOrSomething(cmdOptions))

		return false
	end

	local lastDefaultCommandKey = nil
	function gadget:DefaultCommand(type, unitID, defaultCmd)
		local key = (type or "nil") .. ":" .. (unitID or "nil")
		if unitID ~= nil and key ~= lastDefaultCommandKey then
			Spring.Echo("DefaultCommand", "type", type, "uID", unitID, "defaultCmd", command(defaultCmd))
			lastDefaultCommandKey = key
		end

		return nil
	end
	
	function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
		if unitTeam ~= 0 then
			return
		end
		
		Spring.Echo("UnitCommand", "uID", unitID, "defID", unitDefID,   command(cmdID), "params", summaryOrSomething(cmdParams), "opts", summaryOrSomething(cmdOptions), "tag", cmdTag)
	end
	
	function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
		if unitTeam ~= 0 then
			return
		end

		Spring.Echo("UnitCmdDone", "uID", unitID, "defID", unitDefID,   command(cmdID), "params", summaryOrSomething(cmdParams), "opts", summaryOrSomething(cmdOptions), "tag", cmdTag)
		local x, y, z = Spring.GetUnitPosition(unitID)
		if PING then
			Spring.MarkerAddPoint(x, y, z, "UnitCmdDone: " .. command(cmdID) .. " (tag: " .. tostring(cmdTag) .. ")")
		end
	end

	function gadget:UnitIdle(unitID, unitDefID, unitTeam)
		if unitTeam ~= 0 then
			return
		end
		
		Spring.Echo("UnitIdle", "uID", unitID, "defID", unitDefID)
		Spring.Echo(" ")
	end
end
