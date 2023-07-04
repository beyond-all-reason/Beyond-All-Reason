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


if gadgetHandler:IsSyncedCode() then
	local SendToUnsynced = SendToUnsynced
	
	local buildStartStopCache = {} -- maps unitID to buildstate, and only forwards events on actual change.

	local function UnitScriptBuildStartStop(unitID, unitDefID, _, onoff, param1, param2, param3)
		if (onoff ~= 0) or (buildStartStopCache[unitID] ~= 0) then -- TODO only ignore multiple stops 
			--Spring.Echo(Spring.GetGameFrame(), "Synced Gadget UnitScriptBuildStartStop",unitID, unitDefID, onoff, param1, param2, param3)
			SendToUnsynced("cob_UnitScriptBuildStartStop", unitID, unitDefID, onoff, param1, param2, param3)
		end
		
		buildStartStopCache[unitID] = onoff
	end

	function gadget:Initialize()
		gadgetHandler:RegisterGlobal("UnitScriptBuildStartStop", UnitScriptBuildStartStop)
	end

	function gadget:Shutdown()
		gadgetHandler:DeregisterGlobal("UnitScriptBuildStartStop")
	end
	
	function gadget:UnitDestroyed(unitID)
		buildStartStopCache[unitID] = nil 
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

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("cob_UnitScriptBuildStartStop", UnitScriptBuildStartStop)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("cob_UnitScriptBuildStartStop")
	end

end
