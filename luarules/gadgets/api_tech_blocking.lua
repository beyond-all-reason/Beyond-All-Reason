local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Tech Blocking API",
		desc = "Provides API functions for managing unit tech blocking including terrain restrictions",
		author = "SethDGamre",
		date = "December 2025",
		license = "GNU GPL, v2 or later",
		layer = -1,
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

	local function reasonConcatenator(reasonsTable)
		local concatenatedReasons = {}
		for reasonKey in pairs(reasonsTable) do
			table.insert(concatenatedReasons, reasonKey)
		end
		return table.concat(concatenatedReasons, ",")
	end

	-- Load terrain restriction configuration
	local unitRestrictions = VFS.Include("common/configs/unit_restrictions_config.lua")
	local isWind = unitRestrictions.isWind
	local isWaterUnit = unitRestrictions.isWaterUnit
	local isGeothermal = unitRestrictions.isGeothermal
	local isWindDisabled = unitRestrictions.isWindDisabled
	local shouldShowWaterUnits = unitRestrictions.shouldShowWaterUnits
	local hasGeothermalFeatures = unitRestrictions.hasGeothermalFeatures

	function gadget:Initialize()
		GG.UnitBlocking = GG.UnitBlocking or {}

		-- Initialize terrain restrictions for all teams
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
		--Spring.Echo("Setting TeamRulesParam for team " .. teamID .. ", unitDefID " .. unitDefID .. ": " .. concatenatedReasons)
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
			--Spring.Echo("Clearing TeamRulesParam for team " .. teamID .. ", unitDefID " .. unitDefID)
			Spring.SetTeamRulesParam(teamID, "unitdef_blocked_" .. unitDefID, nil)
		else
			local concatenatedReasons = reasonConcatenator(blockedUnitDefs[unitDefID])
			--Spring.Echo("Updating TeamRulesParam for team " .. teamID .. ", unitDefID " .. unitDefID .. ": " .. concatenatedReasons)
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

	-- Terrain restriction functions
	function GG.UnitBlocking.UpdateTerrainRestrictions(teamID)
		local windUnitsBlocked = 0
		local waterUnitsBlocked = 0
		local geoUnitsBlocked = 0

		if isWindDisabled then
			for unitDefID in pairs(isWind) do
				local unitName = UnitDefs[unitDefID] and UnitDefs[unitDefID].name or ("ID:" .. unitDefID)
				--Spring.Echo("[UnitBlocking] Blocking wind unit: " .. unitName .. " for team " .. teamID)
				GG.UnitBlocking.AddBlockedUnit(unitDefID, teamID, "terrain_wind")
				local paramValue = Spring.GetTeamRulesParam(teamID, "unitdef_blocked_" .. unitDefID)
				windUnitsBlocked = windUnitsBlocked + 1
			end
		end

		if not waterAvailable then
			for unitDefID in pairs(isWaterUnit) do
				local unitName = UnitDefs[unitDefID] and UnitDefs[unitDefID].name or ("ID:" .. unitDefID)
				--Spring.Echo("[UnitBlocking] Blocking water unit: " .. unitName .. " for team " .. teamID)
				GG.UnitBlocking.AddBlockedUnit(unitDefID, teamID, "terrain_water")
				local paramValue = Spring.GetTeamRulesParam(teamID, "unitdef_blocked_" .. unitDefID)
				waterUnitsBlocked = waterUnitsBlocked + 1
			end
		end

		if not geoAvailable then
			for unitDefID in pairs(isGeothermal) do
				local unitName = UnitDefs[unitDefID] and UnitDefs[unitDefID].name or ("ID:" .. unitDefID)
				--Spring.Echo("[UnitBlocking] Blocking geothermal unit: " .. unitName .. " for team " .. teamID)
				GG.UnitBlocking.AddBlockedUnit(unitDefID, teamID, "terrain_geothermal")
				geoUnitsBlocked = geoUnitsBlocked + 1
			end
		end

		-- Summary
		local totalBlocked = windUnitsBlocked + waterUnitsBlocked + geoUnitsBlocked
		if totalBlocked > 0 then
			--Spring.Echo(string.format("[UnitBlocking] Terrain restrictions summary for team %d: %d wind, %d water, %d geothermal units blocked",
			--	teamID, windUnitsBlocked, waterUnitsBlocked, geoUnitsBlocked))
		else
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

	function gadget:GameFrame(frame)
		if frame % 120 == 0 then
			GG.UnitBlocking.UpdateAllTerrainRestrictions()
		end
	end

	function gadget:FeatureCreated(featureID, allyTeam)
		local featureDefID = Spring.GetFeatureDefID(featureID)
		local featureDef = FeatureDefs[featureDefID]
		if featureDef and featureDef.geoThermal then
			local featureName = featureDef.name or ("ID:" .. featureDefID)
			-- Geothermal feature was added, update restrictions
			GG.UnitBlocking.UpdateAllTerrainRestrictions()
		end
	end

	function gadget:FeatureDestroyed(featureID, allyTeam)
		local featureDefID = Spring.GetFeatureDefID(featureID)
		local featureDef = FeatureDefs[featureDefID]
		if featureDef and featureDef.geoThermal then
			local featureName = featureDef.name or ("ID:" .. featureDefID)
			-- Geothermal feature was destroyed, update restrictions
			GG.UnitBlocking.UpdateAllTerrainRestrictions()
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
				--Spring.Echo("UnitBlocked, sent to allied team: ", teamID)
				Script.LuaUI.UnitBlocked(unitDefID, teamID, reasons)
			else
				--Spring.Echo("UnitBlocked, not sending to non-allied team: ", teamID)
			end
		end
	end
end