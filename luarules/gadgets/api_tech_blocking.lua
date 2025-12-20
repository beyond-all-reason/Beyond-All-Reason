local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Tech Blocking API",
		desc = "Provides API functions for managing unit tech blocking including terrain restrictions",
		author = "SethDGamre",
		date = "December 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--[[
todo:
-- cleanup and verify diff with gui_gridmenu.lua and gui_buildmenu.lua
-- verify the vfs.include buildmenu_config is cleaned of transplanted stuff
-- rename the api to something more descriptive
-- add console commands, including allowing them to be used by admins in multiplayer games
-- try to move maxThisUnit = 0 logic to api too
-- cleanup the for-loop in buildmenu and gridmenu that redundantly sets the unitDefID's key to true repeatedly for each reason
-- ensure multiple reasons are added and removed correctly
-- check performance
-- make sure we are populating and updating the teamrulesparams performantly

]]

if gadgetHandler:IsSyncedCode() then

	local DEFAULT_KEY = "defaultKey"
	local MAX_MESSAGES_PER_FRAME = 30

	local windDisabled = false
	local waterAvailable = true
	local geoAvailable = true

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

	local function reasonConcatenator(reasonsTable)
		local concatenatedReasons = {}
		for reasonKey in pairs(reasonsTable) do
			table.insert(concatenatedReasons, reasonKey)
		end
		return table.concat(concatenatedReasons, ",")
	end

	local unitRestrictions = VFS.Include("common/configs/unit_restrictions_config.lua")


	function gadget:Initialize()
		GG.UnitBlocking = GG.UnitBlocking or {}
		windDisabled = unitRestrictions.isWindDisabled()
		waterAvailable = unitRestrictions.shouldShowWaterUnits()
		geoAvailable = unitRestrictions.hasGeothermalFeatures()
		GG.UnitBlocking.UpdateAllTerrainRestrictions()
	end

	function GG.UnitBlocking.AddBlockedUnit(unitDefID, teamID, reasonKey)
		local blockedUnitDefs = teamBlockedUnitDefs[teamID]
		if not blockedUnitDefs then
			return
		end
		blockedUnitDefs[unitDefID] = blockedUnitDefs[unitDefID] or {}
		blockedUnitDefs[unitDefID][reasonKey] = true
		local concatenatedReasons = reasonConcatenator(blockedUnitDefs[unitDefID])
		Spring.SetTeamRulesParam(teamID, "unitdef_blocked_" .. unitDefID, concatenatedReasons)
		SendToUnsynced("UnitBlocked", unitDefID, teamID, blockedUnitDefs[unitDefID])
	end

	function GG.UnitBlocking.RemoveBlockedUnit(unitDefID, teamID, reasonKey)
		local blockedUnitDefs = teamBlockedUnitDefs[teamID]
		if not blockedUnitDefs then
			return false
		end
		if not blockedUnitDefs[unitDefID] or not blockedUnitDefs[unitDefID][reasonKey] then
			return false -- Reason was not blocking this unit
		end

		blockedUnitDefs[unitDefID][reasonKey] = nil
		local wasRemoved = true

		if not next(blockedUnitDefs[unitDefID]) then
			Spring.SetTeamRulesParam(teamID, "unitdef_blocked_" .. unitDefID, nil)
		else
			local concatenatedReasons = reasonConcatenator(blockedUnitDefs[unitDefID])
			Spring.SetTeamRulesParam(teamID, "unitdef_blocked_" .. unitDefID, concatenatedReasons)
		end
		return wasRemoved
	end

	function GG.UnitBlocking.IsUnitBlocked(unitDefID, teamID)
		local blockedUnitDefs = teamBlockedUnitDefs[teamID]
		if not blockedUnitDefs then
			return false, nil
		end
		local isBlocked = next(blockedUnitDefs[unitDefID]) or false
		return isBlocked, isBlocked and blockedUnitDefs[unitDefID]
	end

	function GG.UnitBlocking.UpdateTerrainRestrictions(teamID)
		if windDisabled then
			for unitDefID in pairs(unitRestrictions.isWind) do
				local unitName = UnitDefs[unitDefID] and UnitDefs[unitDefID].name or ("ID:" .. unitDefID)
				GG.UnitBlocking.AddBlockedUnit(unitDefID, teamID, "terrain_wind")
			end
		end

		if not waterAvailable then
			for unitDefID in pairs(unitRestrictions.isWaterUnit) do
				local unitName = UnitDefs[unitDefID] and UnitDefs[unitDefID].name or ("ID:" .. unitDefID)
				GG.UnitBlocking.AddBlockedUnit(unitDefID, teamID, "terrain_water")
			end
		end

		if not geoAvailable then
			for unitDefID in pairs(unitRestrictions.isGeothermal) do
				local unitName = UnitDefs[unitDefID] and UnitDefs[unitDefID].name or ("ID:" .. unitDefID)
				GG.UnitBlocking.AddBlockedUnit(unitDefID, teamID, "terrain_geothermal")
			end
		end
	end

	function GG.UnitBlocking.UpdateAllTerrainRestrictions()
		local teamsProcessed = 0
		for _, teamID in ipairs(teamsList) do
			if not Spring.GetGaiaTeamID() or teamID ~= Spring.GetGaiaTeamID() then
				local scavTeamID = Spring.Utilities.GetScavTeamID()
				local raptorTeamID = Spring.Utilities.GetRaptorTeamID()
				if (not scavTeamID or teamID ~= scavTeamID) and (not raptorTeamID or teamID ~= raptorTeamID) then
					teamsProcessed = teamsProcessed + 1
					GG.UnitBlocking.UpdateTerrainRestrictions(teamID)
				end
			end
		end
	end



	function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID)
		if cmdID < 0 then --it's a build command
			local buildDefID = -cmdID
			local blockedUnitDefs = teamBlockedUnitDefs[unitTeam]
			if not blockedUnitDefs then
				return true
			end
			local isBlocked = next(blockedUnitDefs[buildDefID]) or false
			if isBlocked then
				return false
			end
		end
		return true
	end
	
-------------------------------------------------------------------------------- Unsynced Code --------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------
elseif not gadgetHandler:IsSyncedCode() then --elseif for readability
	function gadget:RecvFromSynced(messageName, ...) --we use recvfromsynced instead of SyncAction because we don't want all widgets to access all team's available tech
		if messageName == "UnitBlocked" then
			local unitDefID, teamID, reasons = ...

			-- Only send tech data to allied teams to prevent information leakage
			local myAllyTeamID = Spring.GetMyAllyTeamID()
			local targetAllyTeamID = Spring.GetTeamAllyTeamID(teamID)

			if myAllyTeamID == targetAllyTeamID then
				Script.LuaUI.UnitBlocked(unitDefID, teamID, reasons)
			end
		end
	end
end