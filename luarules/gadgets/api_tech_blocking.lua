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

GG.UnitBlocking = GG.UnitBlocking or {}

function gadget:Initialize()
	GG.UnitBlocking = GG.UnitBlocking or {}
end

function GG.UnitBlocking.AddBlockedUnit(unitDefID, teamID, reasonKey)
		blockedUnitDefs[unitDefID] = blockedUnitDefs[unitDefID] or {}
		blockedUnitDefs[unitDefID][reasonKey] = true
		SendToUnsynced("poop", unitDefID, teamID, reasonKey)
		Spring.SetTeamRulesParam(teamID, "unit_blocked_" .. unitDefID, 1)
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
		if frame % 300 == 0 then
			local unitDefIDs = {}
			for unitDefID in pairs(UnitDefs) do
				table.insert(unitDefIDs, unitDefID)
			end
			if #unitDefIDs > 0 then
				local randomIndex = math.random(1, #unitDefIDs)
				local randomUnitDefID = unitDefIDs[randomIndex]
				local randomTeamID = math.random(0, #Spring.GetTeamList() - 1)
				local randomReason = "random_block_" .. tostring(frame)
				GG.UnitBlocking.AddBlockedUnit(randomUnitDefID, randomTeamID, randomReason)
			end
		end
	end
elseif not gadgetHandler:IsSyncedCode() then --elseif for readability
	function HandlePoop(_, unitDefID, teamID, reasonKey)
		Spring.Echo("poop", unitDefID, teamID, reasonKey)
		if Script.LuaUI("poop") then
			Spring.Echo("poop, inside script.lua.", unitDefID, teamID, reasonKey)
			Script.LuaUI.poop(unitDefID, teamID, reasonKey)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("poop", HandlePoop)
	end
end