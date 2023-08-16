function gadget:GetInfo()
	return {
		name = "Unit Script BuildStartStop",
		desc = "Forwards BuildStartStop Events to Widgets from COB Unit scripts",
		author = "Beherith",
		date = "2023.07.04",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true, --  loaded by default?
	}
end

--[[
SUPER IMPORTANT NOTES!

Stuff needed in the cob script:

Wierdly, this is called way more often than one expects
	-- It is called once for placing the nanoframe
	-- And called once more for starting construction!



lua_UnitScriptBuildStartStop(onoff, param1, param2, param3) 
{
	return 0;
}

StartBuilding(heading, pitch){
	call-script lua_UnitScriptBuildStartStop(onoff, 1,2,3);
}
StopBuilding(heading, pitch){
	call-script lua_UnitScriptBuildStartStop(onoff, 1,2,3);
}

or for Lua it should be:

	if Script.LuaRules("UnitScriptBuildStartStop") then 
		Script.LuaRules.UnitScriptBuildStartStop(unitID, Spring.GetUnitDefID(unitID), nil, 1, 2,3,4)
	end
	
]]--

-- 2023.07.19 TODO:
-- Batch the SendToUnsynced calls by using table.concat to create a large string of all units that must be turned on or off. 
-- Otherwise the function call overhead might be more than expected
-- This also allows batch push-popping in the future
-- Send stopped and started as separate lua messages to unsynced
-- WAIT is not handled at all.

-- UnitScriptBuildStartStop takes 4.5 us after caching, cause of the sendtounsynced shit - which is actually not that bad!
-- Regular StopBuilding is 1 us

local buildTypeMap = {"assist", "repair", "reclaim", "resurrect", "capture","restore", "terraform", "inwaitstance"}

if gadgetHandler:IsSyncedCode() then
	local SendToUnsynced = SendToUnsynced
	
	local buildStartStopCache = {} 
	-- maps unitID to buildstate, and only forwards events on actual change.
	-- In this case, whenever the incoming command is off, then dont actually cache that unless the cache was 1 to begin with?
	local unitIDIsBuilding = {} -- true for units that are building, false for others, nil for 'new' units
	
	
	--[[
	local function UnitScriptBuildStartStop(unitID, unitDefID, _, onoff, param1, param2, param3)
		--Spring.Echo(math.random(), unitID, unitDefID, onoff)
		if (onoff ~= 0) or (buildStartStopCache[unitID] ~= 0) then -- TODO only ignore multiple stops 
			--Spring.Echo(Spring.GetGameFrame(), "Synced Gadget UnitScriptBuildStartStop",unitID, unitDefID, onoff, param1, param2, param3)
			SendToUnsynced("cob_UnitScriptBuildStartStop", unitID, unitDefID, onoff, param1, param2, param3)
		end
		buildStartStopCache[unitID] = onoff
	end
	]]--
	
	local function UnitScriptBuildStartStopBatched(unitID, unitDefID, _, onoff, param1, param2, param3)
		Spring.Echo(Spring.GetGameFrame(),math.random(), unitID, unitDefID, onoff)
		tracy.Message("UnitScriptBuildStartStopBatched")
		
		if onoff == 1 then -- the unit is now building (start build doesnt get sent twice, does it?)
			unitIDIsBuilding[unitID] = onoff
			buildStartStopCache[unitID] = onoff
		else
			
		end
		
		
		buildStartStopCache[unitID] = onoff
	end
	
	function gadget:GameFramePost() 
		local sendTable = {}
		local numSendTable = 0
		if next(buildStartStopCache) then 
			
			for unitID, onoff in pairs(buildStartStopCache) do 
				numSendTable = numSendTable + 1 
				sendTable[numSendTable] = unitID
				numSendTable = numSendTable + 1
				sendTable[numSendTable] = onoff
			end
			
			--Spring.Echo("LOL POST SYNCED UPDATE", numSendTable/2)
			SendToUnsynced("cob_UnitScriptBuildStartStop", numSendTable, unpack(sendTable))
			buildStartStopCache = {}
		end
	end 

	function gadget:Initialize()
		gadgetHandler:RegisterGlobal("UnitScriptBuildStartStop", UnitScriptBuildStartStopBatched)
	end

	function gadget:Shutdown()
		gadgetHandler:DeregisterGlobal("UnitScriptBuildStartStop")
	end
	
	function gadget:UnitDestroyed(unitID)
		buildStartStopCache[unitID] = nil 
		unitIDIsBuilding[unitID] = nil
	end
	
	function gadget:UnitStartBuilding(unitID, unitDefID, unitTeam, silent, buildType)
		Spring.Echo("SYNCED UnitStartBuilding", Spring.GetGameFrame(), math.random(), unitID, unitDefID, unitTeam, silent, buildType )
	end	
	function gadget:UnitStopBuilding(unitID, unitDefID, unitTeam)
		Spring.Echo("SYNCED UnitStopBuilding",Spring.GetGameFrame(),  math.random(), unitID, unitDefID, unitTeam )
	end
	

else	-- UNSYNCED

	local myTeamID = Spring.GetMyTeamID()
	local myPlayerID = Spring.GetMyPlayerID()
	local mySpec, fullview = Spring.GetSpectatingState()
	local spGetUnitPosition = Spring.GetUnitPosition
	local spIsPosInLos = Spring.IsPosInLos

	function gadget:PlayerChanged(playerID)
		if playerID == myPlayerID then
			myTeamID = Spring.GetMyTeamID()
			mySpec, fullview = Spring.GetSpectatingState()
		end
	end
	
	local scriptUnitScriptBuildStartStop = Script.LuaUI.UnitScriptBuildStartStop
	
	local function UnitScriptBuildStartStop(_, unitID, unitDefID, onoff, param1, param2, param3)
		if not fullview and not CallAsTeam(myTeamID, spIsPosInLos, spGetUnitPosition(unitID)) then
			return
		end
		--Spring.Echo("Unsynced UnitScriptBuildStartStop", unitID, unitDefID, onoff, param1, param2, param3)
		if Script.LuaUI('UnitScriptBuildStartStop') then 
			Script.LuaUI.UnitScriptBuildStartStop(unitID, unitDefID, onoff, param1, param2, param3)
		end
	end

	local function UnitScriptBuildStartStopBatched(hidename, numEntries, ...)
		local args = {...}
		local buildStartStopCache = {} -- key unitID, value onoff
		local numVisible = 0
		for i=1,numEntries,2 do 
			local unitID = args[i]
			--Spring.Echo(hidename, numEntries, unitID)
			if fullview or CallAsTeam(myTeamID, spIsPosInLos, spGetUnitPosition(unitID)) then
				buildStartStopCache[unitID] = args[i +1]
				numVisible = numVisible + 1
			end
		end
		--Spring.Echo("U:UnitScriptBuildStartStopBatched", numEntries, numVisible,Script.LuaUI('UnitScriptBuildStartStopBatched'))
		if numVisible > 0 and Script.LuaUI('UnitScriptBuildStartStopBatched') then  

			Script.LuaUI.UnitScriptBuildStartStopBatched(numVisible, buildStartStopCache)
		end
	end
	
	function gadget:UnitStartBuilding(unitID, unitDefID, unitTeam, silent, buildType)
		Spring.Echo("UNSYNCED UnitStartBuilding", unitID, unitDefID, unitTeam, silent, buildType )
	end
	

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("cob_UnitScriptBuildStartStop", UnitScriptBuildStartStopBatched)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("cob_UnitScriptBuildStartStop")
	end

end
