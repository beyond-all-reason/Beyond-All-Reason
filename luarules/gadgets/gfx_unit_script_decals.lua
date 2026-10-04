local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Script Decals",
		desc = "Forwards Decaling Events to Widgets from COB Unit scripts",
		author = "Beherith",
		date = "2023.02.07",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end


if gadgetHandler:IsSyncedCode() then
	local SendToUnsynced = SendToUnsynced

	local function UnitScriptDecal(unitID, unitDefID, _, lightIndex, posx,posz, heading)
		--Spring.Echo("Synced Gadget UnitScriptDecal", unitID, unitDefID, lightIndex, posx,posz, heading)
		SendToUnsynced("cob_UnitScriptDecal", unitID, unitDefID, lightIndex, posx,posz, heading)
	end

	function gadget:Initialize()
		gadgetHandler:RegisterGlobal("UnitScriptDecal", UnitScriptDecal)
	end

	function gadget:Shutdown()
		gadgetHandler:DeregisterGlobal("UnitScriptDecal")
	end

else	-- UNSYNCED

	local myAllyTeamID = Spring.GetMyAllyTeamID()
	local myPlayerID = Spring.GetMyPlayerID()
	local mySpec, fullview = Spring.GetSpectatingState()
	local spIsUnitInLos = Spring.IsUnitInLos

	function gadget:PlayerChanged(playerID)
		if playerID == myPlayerID then
			myAllyTeamID = Spring.GetMyAllyTeamID()
			mySpec, fullview = Spring.GetSpectatingState()
		end
	end
	
	local scriptUnitScriptDecal = Script.LuaUI.UnitScriptDecal
	
	local function UnitScriptDecal(_, unitID, unitDefID, lightIndex, posx,posz, heading)
		if not fullview and not spIsUnitInLos(unitID, myAllyTeamID) then
			return
		end
		--Spring.Echo("Unsynced UnitScriptDecal", unitID, unitDefID, lightIndex, posx,posz, heading)
		if Script.LuaUI('UnitScriptDecal') then 
			Script.LuaUI.UnitScriptDecal(unitID, unitDefID, lightIndex, posx,posz, heading)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("cob_UnitScriptDecal", UnitScriptDecal)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("cob_UnitScriptDecal")
	end

end
