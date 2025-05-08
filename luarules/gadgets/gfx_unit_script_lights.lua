local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Script Lights and Distortion",
		desc = "Forwards Lighting Events to Widgets from COB Unit scripts",
		author = "Beherith",
		date = "Apr, 2008",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end


if gadgetHandler:IsSyncedCode() then
	local SendToUnsynced = SendToUnsynced

	local function UnitScriptLight(unitID, unitDefID, _, lightIndex, param)
		--Spring.Echo("Synced Gadget UnitScriptLight", unitID, unitDefID, lightIndex, param)
		SendToUnsynced("cob_UnitScriptLight", unitID, unitDefID, lightIndex, param)
	end
	
	local function UnitScriptDistortion(unitID, unitDefID, _, lightIndex, param)
		--Spring.Echo("Synced Gadget UnitScriptDistortion", unitID, unitDefID, lightIndex, param)
		SendToUnsynced("cob_UnitScriptDistortion", unitID, unitDefID, lightIndex, param)
	end

	function gadget:Initialize()
		gadgetHandler:RegisterGlobal("UnitScriptLight", UnitScriptLight)
		gadgetHandler:RegisterGlobal("UnitScriptDistortion", UnitScriptDistortion)
	end

	function gadget:Shutdown()
		gadgetHandler:DeregisterGlobal("UnitScriptLight")
		gadgetHandler:DeregisterGlobal("UnitScriptDistortion")
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
	
	local scriptUnitScriptLight = Script.LuaUI.UnitScriptLight
	
	local function UnitScriptLight(_, unitID, unitDefID, lightIndex, param)
		if not fullview and not CallAsTeam(myTeamID, spIsPosInLos, spGetUnitPosition(unitID)) then
			return
		end
		--Spring.Echo("Unsynced UnitScriptLight", unitID, unitDefID, lightIndex, param)
		if Script.LuaUI('UnitScriptLight') then 
			Script.LuaUI.UnitScriptLight(unitID, unitDefID, lightIndex, param)
		end
	end

	local scriptUnitScriptDistortion = Script.LuaUI.UnitScriptDistortion
	
	local function UnitScriptDistortion(_, unitID, unitDefID, lightIndex, param)
		if not fullview and not CallAsTeam(myTeamID, spIsPosInLos, spGetUnitPosition(unitID)) then
			return
		end
		--Spring.Echo("Unsynced UnitScriptDistortion", unitID, unitDefID, lightIndex, param)
		if Script.LuaUI('UnitScriptDistortion') then 
			Script.LuaUI.UnitScriptDistortion(unitID, unitDefID, lightIndex, param)
		end
	end
	
	function gadget:Initialize()
		gadgetHandler:AddSyncAction("cob_UnitScriptLight", UnitScriptLight)
		gadgetHandler:AddSyncAction("cob_UnitScriptDistortion", UnitScriptDistortion)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("cob_UnitScriptLight")
		gadgetHandler:RemoveSyncAction("cob_UnitScriptDistortion")
	end

end
