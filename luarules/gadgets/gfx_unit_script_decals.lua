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

	-- a sim frame's decals as unitID, unitDefID, lightIndex, posx, posz, heading runs, handed over once in GameFramePost
	local decals, decalCount = {}, 0

	local function UnitScriptDecal(unitID, unitDefID, _, lightIndex, posx, posz, heading)
		local n = decalCount
		decals[n + 1] = unitID
		decals[n + 2] = unitDefID
		decals[n + 3] = lightIndex
		decals[n + 4] = posx
		decals[n + 5] = posz
		decals[n + 6] = heading
		decalCount = n + 6
	end

	function gadget:GameFramePost()
		if decalCount > 0 then
			SendToUnsynced("cob_UnitScriptDecals", decals, decalCount)
			decals, decalCount = {}, 0
		end
	end

	function gadget:Initialize()
		gadgetHandler:RegisterGlobal("UnitScriptDecal", UnitScriptDecal)
	end

	function gadget:Shutdown()
		gadgetHandler:DeregisterGlobal("UnitScriptDecal")
	end
else -- UNSYNCED
	local myAllyTeamID = Spring.GetLocalAllyTeamID()
	local myPlayerID = Spring.GetLocalPlayerID()
	local mySpec, fullview = Spring.GetSpectatingState()
	local spIsUnitInLos = Spring.IsUnitInLos

	function gadget:PlayerChanged(playerID)
		if playerID == myPlayerID then
			myAllyTeamID = Spring.GetLocalAllyTeamID()
			mySpec, fullview = Spring.GetSpectatingState()
		end
	end

	-- moves the decals of units the local player can see to the front, in order, and returns their length
	local function keepVisible(decals, count)
		if fullview then
			return count
		end
		local kept = 0
		for i = 1, count, 6 do
			if spIsUnitInLos(decals[i], myAllyTeamID) then
				for j = 0, 5 do
					decals[kept + 1 + j] = decals[i + j]
				end
				kept = kept + 6
			end
		end
		for i = kept + 1, count do
			decals[i] = nil
		end
		return kept
	end

	local function UnitScriptDecals(_, decals, count)
		count = keepVisible(decals, count)
		if count > 0 and Script.LuaUI("UnitScriptDecalBatch") then
			Script.LuaUI.UnitScriptDecalBatch(decals, count)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("cob_UnitScriptDecals", UnitScriptDecals)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("cob_UnitScriptDecals")
	end
end
