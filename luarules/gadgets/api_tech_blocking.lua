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
-- verify the vfs.include buildmenu_config is cleaned of transplanted stuff
-- cleanup and verify diff with gui_gridmenu.lua and gui_buildmenu.lua
-- cleanup the for-loop in buildmenu and gridmenu that redundantly sets the unitDefID's key to true repeatedly for each reason
-- try to move maxThisUnit = 0 logic to api too
-- make sure we are populating and updating the teamrulesparams performantly
-- check performance
-- rename the api to something more descriptive

]]

if gadgetHandler:IsSyncedCode() then

	local DEFAULT_KEY = "defaultKey"
	local MAX_MESSAGES_PER_FRAME = 30
	local UNAUTHORIZED_TEXT = "You are not authorized to use build blocking commands"

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

	local function isAuthorized(playerID)
		if Spring.IsCheatingEnabled() then
			return true
		else
			local playername, _, _, _, _, _, _, _, _, _, accountInfo = Spring.GetPlayerInfo(playerID)
			local accountID = (accountInfo and accountInfo.accountid) and tonumber(accountInfo.accountid) or -1
			if (_G and _G.powerusers and _G.powerusers[accountID]) or (SYNCED and SYNCED.powerusers and SYNCED.powerusers[accountID]) then
				return true
			end
		end
		return false
	end

	local unitRestrictions = VFS.Include("common/configs/unit_restrictions_config.lua")

	local function commandBuildBlock(_, line, words, playerID)
		if not isAuthorized(playerID) then
			Spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
			return
		end

		if #words < 3 then
			Spring.SendMessageToPlayer(playerID, "Usage: /luarules buildblock <teamID|'all'> <reason_key> <unitDefID 1> <unitDefID 2> ...")
			return
		end

		local teamParam = words[1]
		local reasonKey = words[2]
		local blockedCount = 0

		local teamsToProcess = {}
		if teamParam == "all" then
			for _, teamID in ipairs(teamsList) do
				if not Spring.GetGaiaTeamID() or teamID ~= Spring.GetGaiaTeamID() then
					local scavTeamID = Spring.Utilities.GetScavTeamID()
					local raptorTeamID = Spring.Utilities.GetRaptorTeamID()
					if (not scavTeamID or teamID ~= scavTeamID) and (not raptorTeamID or teamID ~= raptorTeamID) then
						table.insert(teamsToProcess, teamID)
					end
				end
			end
		else
			local targetTeamID = tonumber(teamParam)
			if not targetTeamID or not Spring.GetTeamInfo(targetTeamID) then
				Spring.SendMessageToPlayer(playerID, "Invalid teamID: " .. tostring(teamParam) .. ". Use 'all' or a valid team number.")
				return
			end
			table.insert(teamsToProcess, targetTeamID)
		end

		for i = 3, #words do
			local unitDefID = tonumber(words[i])
			if unitDefID and UnitDefs[unitDefID] then
				local actuallyBlocked = false
				for _, teamID in ipairs(teamsToProcess) do
					GG.UnitBlocking.AddBlockedUnit(unitDefID, teamID, reasonKey)
					actuallyBlocked = true
				end
				if actuallyBlocked then
					blockedCount = blockedCount + 1
				end
			else
				Spring.SendMessageToPlayer(playerID, "Invalid unitDefID: " .. tostring(words[i]))
			end
		end

		local teamMsg = (teamParam == "all") and "all teams" or ("team " .. teamParam)
		Spring.SendMessageToPlayer(playerID, "Blocked " .. blockedCount .. " unit(s) with reason '" .. reasonKey .. "' for " .. teamMsg)
	end

	local function commandBuildUnblock(_, line, words, playerID)
		if not isAuthorized(playerID) then
			Spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
			return
		end

		if #words < 3 then
			Spring.SendMessageToPlayer(playerID, "Usage: /luarules buildunblock <teamID|'all'> <reason_key> <unitDefID 1> <unitDefID 2> ...")
			return
		end

		local teamParam = words[1]
		local reasonKey = words[2]
		local unblockedCount = 0

		local teamsToProcess = {}
		if teamParam == "all" then
			for _, teamID in ipairs(teamsList) do
				if not Spring.GetGaiaTeamID() or teamID ~= Spring.GetGaiaTeamID() then
					local scavTeamID = Spring.Utilities.GetScavTeamID()
					local raptorTeamID = Spring.Utilities.GetRaptorTeamID()
					if (not scavTeamID or teamID ~= scavTeamID) and (not raptorTeamID or teamID ~= raptorTeamID) then
						table.insert(teamsToProcess, teamID)
					end
				end
			end
		else
			local targetTeamID = tonumber(teamParam)
			if not targetTeamID or not Spring.GetTeamInfo(targetTeamID) then
				Spring.SendMessageToPlayer(playerID, "Invalid teamID: " .. tostring(teamParam) .. ". Use 'all' or a valid team number.")
				return
			end
			table.insert(teamsToProcess, targetTeamID)
		end

		for i = 3, #words do
			local unitDefID = tonumber(words[i])
			if unitDefID and UnitDefs[unitDefID] then
				local actuallyUnblocked = false
				for _, teamID in ipairs(teamsToProcess) do
					if GG.UnitBlocking.RemoveBlockedUnit(unitDefID, teamID, reasonKey) then
						actuallyUnblocked = true
					end
				end
				if actuallyUnblocked then
					unblockedCount = unblockedCount + 1
				end
			else
				Spring.SendMessageToPlayer(playerID, "Invalid unitDefID: " .. tostring(words[i]))
			end
		end

		local teamMsg = (teamParam == "all") and "all teams" or ("team " .. teamParam)
		Spring.SendMessageToPlayer(playerID, "Unblocked " .. unblockedCount .. " unit(s) with reason '" .. reasonKey .. "' for " .. teamMsg)
	end

	function gadget:Initialize()
		GG.UnitBlocking = GG.UnitBlocking or {}
		windDisabled = unitRestrictions.isWindDisabled()
		waterAvailable = unitRestrictions.shouldShowWaterUnits()
		geoAvailable = unitRestrictions.hasGeothermalFeatures()
		GG.UnitBlocking.UpdateAllTerrainRestrictions()

		gadgetHandler:AddChatAction('buildblock', commandBuildBlock, "Block units from being built by reason")
		gadgetHandler:AddChatAction('buildunblock', commandBuildUnblock, "Unblock units from being built by reason")
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction('buildblock')
		gadgetHandler:RemoveChatAction('buildunblock')
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
		SendToUnsynced("UnitBlocked", unitDefID, teamID, blockedUnitDefs[unitDefID])
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
			Spring.Echo("buildDefID: " .. -cmdID)
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