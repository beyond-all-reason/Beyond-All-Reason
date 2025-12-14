local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Tech Blocking API",
		desc = "Provides API functions for managing unit tech blocking",
		author = "SethDGamre",
		date = "December 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	
	local DEFAULT_KEY = "defaultKey"
	local MAX_MESSAGES_PER_FRAME = 30

	local blockedUnitDefs = {}
	-- data structure: unitDefID = {reasonKey = true, reasonKey = true, ...}

	for unitDefID, unitDef in pairs(UnitDefs) do
		blockedUnitDefs[unitDefID] = {}
	end

	function GG.UnitBlocking.AddBlockedUnit(unitDefID, teamID, reasonKey)
		blockedUnitDefs[unitDefID] = blockedUnitDefs[unitDefID] or {}
		blockedUnitDefs[unitDefID][reasonKey] = true
		SendToUnsynced("poop", unitDefID, teamID, reasonKey)
		Spring.SetTeamRulesParam(teamID, "unit_blocked_" .. unitDefID, reasonKey)
	end

	function GG.UnitBlocking.RemoveBlockedUnit(unitDefID, teamID, reasonKey)
		if blockedUnitDefs[unitDefID] then
			blockedUnitDefs[unitDefID][reasonKey] = nil
			Spring.SetTeamRulesParam(teamID, "unit_blocked_" .. unitDefID, nil)
		end
	end

	function GG.UnitBlocking.IsUnitBlocked(unitDefID, teamID)
		local isBlocked = next(blockedUnitDefs[unitDefID])
		return isBlocked, isBlocked and blockedUnitDefs[unitDefID]
	end

	function gadget:GameFrame(frame)
	end
else
	function HandlePoop(_, unitDefID, teamID, reasonKey)
		if Script.LuaUI("poop") then
			Script.LuaUI.poop(unitDefID, teamID, reasonKey)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("poop", HandlePoop)
	end
end