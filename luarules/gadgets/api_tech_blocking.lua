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

local teamBlockedUnitDefs = {}
-- data structure: unitDefID = {reasonKey = true, reasonKey = true, ...}

local teamsList = Spring.GetTeamList()
for _, teamID in ipairs(teamsList) do
	teamBlockedUnitDefs[teamID] = {}
end
for unitDefID, unitDef in pairs(UnitDefs) do
	for _, teamID in ipairs(teamsList) do
		teamBlockedUnitDefs[teamID][unitDefID] = {}
	end
end

GG.UnitBlocking = GG.UnitBlocking or {}

function gadget:Initialize()
	GG.UnitBlocking = GG.UnitBlocking or {}
end

function GG.UnitBlocking.AddBlockedUnit(unitDefID, teamID, reasonKey)
	local blockedUnitDefs = teamBlockedUnitDefs[teamID]
	if not blockedUnitDefs then
		return
	end
		blockedUnitDefs[unitDefID] = blockedUnitDefs[unitDefID] or {}
		blockedUnitDefs[unitDefID][reasonKey] = true
		SendToUnsynced("unitdef_blocked", unitDefID, teamID)
		Spring.SetTeamRulesParam(teamID, "unitdef_blocked_" .. unitDefID, 1)
	end

	function GG.UnitBlocking.RemoveBlockedUnit(unitDefID, teamID, reasonKey)
		local blockedUnitDefs = teamBlockedUnitDefs[teamID]
		if not teamBlockedUnitDefs then
			return
		end
		blockedUnitDefs[unitDefID][reasonKey] = nil
		if not next(blockedUnitDefs[unitDefID]) then
			Spring.SetTeamRulesParam(teamID, "unitdef_blocked_" .. unitDefID, nil)
		end
	end

	function GG.UnitBlocking.IsUnitBlocked(unitDefID, teamID)
		local blockedUnitDefs = teamBlockedUnitDefs[teamID]
		if not blockedUnitDefs then
			return false, nil
		end
		local isBlocked = next(blockedUnitDefs[unitDefID]) or false
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
				local randomReason = "unitdef_blocked_" .. tostring(frame)
				GG.UnitBlocking.AddBlockedUnit(randomUnitDefID, randomTeamID, randomReason)
			end
		end
	end


	function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID)
		if cmdID < 0 then --it's a build command
			local blockedUnitDefs = teamBlockedUnitDefs[unitTeam]
			if not blockedUnitDefs then
				return true
			end
			local isBlocked = next(blockedUnitDefs[unitDefID]) or false
			if isBlocked then
				return false
			end
		end
		return true
	end

-------------------------------------------------------------------------------- Unsynced Code --------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------
elseif not gadgetHandler:IsSyncedCode() then --elseif for readability
	function HandleUpdateUnitdefBlocked(_, unitDefID, teamID)
		Spring.Echo("unitdef_blocked", unitDefID, teamID)
		if Script.LuaUI("unitdef_blocked") then
			Spring.Echo("unitdef_blocked, inside script.lua. unitDefID: ", unitDefID, " teamID: ", teamID)
			Script.LuaUI.unitDefBlocked(unitDefID, teamID)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("unitDefBlocked", HandleUpdateUnitdefBlocked)
	end
end