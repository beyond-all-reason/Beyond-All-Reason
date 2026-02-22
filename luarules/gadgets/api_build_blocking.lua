local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Build Blocking API",
		desc = "Centralized unitDef build blocking including map terrain and modoption restrictions",
		author = "SethDGamre",
		date = "December 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

 -- these will not be removed with "all" reason key from console commands.
 -- they must be removed explicitly with the reason key.
local allExemptReasonKeys = {
terrain_wind = true,
terrain_water = true,
terrain_geothermal = true,
max_this_unit = true,
modoption_blocked = true,
}

if gadgetHandler:IsSyncedCode() then
	local function notifyUnitBlocked(unitDefID, teamID, reasons)
		local reasonsStr = ""
		local count = 0
		for r, _ in pairs(reasons) do
			if count > 0 then reasonsStr = reasonsStr .. "," end
			reasonsStr = reasonsStr .. r
			count = count + 1
		end

		SendToUnsynced("BuildBlocked_" .. teamID, unitDefID, reasonsStr)
	end


	local windDisabled = false
	local waterAvailable = true
	local geoInitialized, landGeoAvailable, seaGeoAvailable

	local teamBlockedUnitDefs = {}
	-- data structure: unitDefID = {reasonKey = true, reasonKey = true, ...}

	local teamsList = Spring.GetTeamList()

	local ignoredTeams = {}
	local scavTeamID, raptorTeamID = Spring.Utilities.GetScavTeamID(), Spring.Utilities.GetRaptorTeamID()
	if scavTeamID then
		ignoredTeams[scavTeamID] = true
	end
	if raptorTeamID then
		ignoredTeams[raptorTeamID] = true
	end

	for _, teamID in ipairs(teamsList) do
		teamBlockedUnitDefs[teamID] = {}
		for unitDefID in pairs(UnitDefs) do
			teamBlockedUnitDefs[teamID][unitDefID] = {}
		end
	end

	GG.BuildBlocking = GG.BuildBlocking or {}

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
			if _G.permissions.cmd[accountID] and not _G.isSinglePlayer then
				return true
			end
		end
		return false
	end

	local unitRestrictions = VFS.Include("common/configs/unit_restrictions_config.lua")

	local function parseTeamParameter(teamParam, playerID)
		if teamParam == "all" then
			local teams = {}
			for _, teamID in ipairs(teamsList) do
				if not ignoredTeams[teamID] then
					teams[#teams + 1] = teamID
				end
			end
			return teams
		else
			local targetTeamID = tonumber(teamParam)
			if not targetTeamID or not Spring.GetTeamInfo(targetTeamID) then
				Spring.SendMessageToPlayer(playerID, "Invalid teamID: " .. tostring(teamParam) .. ". Use 'all' or a valid team number.")
				return nil
			end
			return {targetTeamID}
		end
	end

	local function parseUnitIdentifier(identifier)
		local unitDefID = tonumber(identifier)
		if not unitDefID then
			local nameDef = UnitDefNames[identifier]
			if nameDef then
				unitDefID = nameDef.id
			end
		end
		return (unitDefID and UnitDefs[unitDefID]) and unitDefID or nil
	end

	local function processUnblockReasons(unitDefID, teamID, reasonKey)
		if reasonKey == "all" then
			local blockedUnitDefs = teamBlockedUnitDefs[teamID]
			if blockedUnitDefs and blockedUnitDefs[unitDefID] then
				local removed = false
				for reason in pairs(blockedUnitDefs[unitDefID]) do
					if not allExemptReasonKeys[reason] then
						if GG.BuildBlocking.RemoveBlockedUnit(unitDefID, teamID, reason) then
							removed = true
						end
					end
				end
				return removed
			end
			return false
		else
			return GG.BuildBlocking.RemoveBlockedUnit(unitDefID, teamID, reasonKey)
		end
	end

	local function commandBuildBlock(cmd, line, words, playerID)
		if not isAuthorized(playerID) then
			if _G.isSinglePlayer then
				Spring.SendMessageToPlayer(playerID, "You must enable /cheats in order to use buildblock commands")
			else
				Spring.SendMessageToPlayer(playerID, "You are not authorized to use buildblock commands")
			end
			return
		end

		if #words < 3 then
			Spring.SendMessageToPlayer(playerID, "Usage: /luarules buildblock <teamID|'all'> <reason_key> <unitDefID/unitDefName 1> <unitDefID/unitDefName 2> ... or 'all'")
			return
		end

		local teamParam = words[1]
		local reasonKey = words[2]
		local teamsToProcess = parseTeamParameter(teamParam, playerID)
		if not teamsToProcess then
			return
		end

		local blockedCount = 0
		if words[3] == "all" then
			for unitDefID in pairs(UnitDefs) do
				for _, teamID in ipairs(teamsToProcess) do
					GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, reasonKey)
				end
				blockedCount = blockedCount + 1
			end
		else
			for i = 3, #words do
				local unitDefID = parseUnitIdentifier(words[i])
				if unitDefID then
					for _, teamID in ipairs(teamsToProcess) do
						GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, reasonKey)
					end
					blockedCount = blockedCount + 1
				else
					Spring.SendMessageToPlayer(playerID, "Invalid unitDefID or unitDefName: " .. tostring(words[i]))
				end
			end
		end

		local teamMsg = (teamParam == "all") and "all teams" or ("team " .. teamParam)
		Spring.SendMessageToPlayer(playerID, "Blocked " .. blockedCount .. " unit(s) with reason '" .. reasonKey .. "' for " .. teamMsg)
	end

	local function commandBuildUnblock(cmd, line, words, playerID)
		if not isAuthorized(playerID) then
			if _G.isSinglePlayer then
				Spring.SendMessageToPlayer(playerID, "You must enable /cheats in order to use buildunblock commands")
			else
				Spring.SendMessageToPlayer(playerID, "You are not authorized to use buildunblock commands")
			end
			return
		end

		if #words < 3 then
			Spring.SendMessageToPlayer(playerID, "Usage: /luarules buildunblock <teamID|'all'> <reason_key|'all'> <unitDefID/unitDefName 1> <unitDefID/unitDefName 2> ... or 'all'")
			return
		end

		local teamParam = words[1]
		local reasonKey = words[2]
		local teamsToProcess = parseTeamParameter(teamParam, playerID)
		if not teamsToProcess then
			return
		end

		local unblockedCount = 0
		if words[3] == "all" then
			for unitDefID in pairs(UnitDefs) do
				local removed = false
				for _, teamID in ipairs(teamsToProcess) do
					if processUnblockReasons(unitDefID, teamID, reasonKey) then
						removed = true
					end
				end
				if removed then
					unblockedCount = unblockedCount + 1
				end
			end
		else
			for i = 3, #words do
				local unitDefID = parseUnitIdentifier(words[i])
				if unitDefID then
					local removed = false
					for _, teamID in ipairs(teamsToProcess) do
						if processUnblockReasons(unitDefID, teamID, reasonKey) then
							removed = true
						end
					end
					if removed then
						unblockedCount = unblockedCount + 1
					end
				else
					Spring.SendMessageToPlayer(playerID, "Invalid unitDefID or unitDefName: " .. tostring(words[i]))
				end
			end
		end

		local teamMsg = (teamParam == "all") and "all teams" or ("team " .. teamParam)
		Spring.SendMessageToPlayer(playerID, "Unblocked " .. unblockedCount .. " unit(s) with reason '" .. reasonKey .. "' for " .. teamMsg)
	end
	
	function gadget:Initialize()
		GG.BuildBlocking = GG.BuildBlocking or {}

		windDisabled = unitRestrictions.isWindDisabled()
		waterAvailable = unitRestrictions.shouldShowWaterUnits()
		for _, teamID in ipairs(teamsList) do
			if not ignoredTeams[teamID] then
				if windDisabled then
					for unitDefID in pairs(unitRestrictions.isWind) do
						GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, "terrain_wind")
					end
				end
				if not waterAvailable then
					for unitDefID in pairs(unitRestrictions.isWaterUnit) do
						GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, "terrain_water")
					end
				end
				
				for unitDefID, unitDef in pairs(UnitDefs) do
					if unitDef.maxThisUnit == 0 then
						GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, "max_this_unit")
					elseif unitDef.customParams.modoption_blocked then
						GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, "modoption_blocked")
					end
				end
			end
		end

		gadgetHandler:AddChatAction('buildblock', commandBuildBlock, "Block units from being built by reason")
		gadgetHandler:AddChatAction('buildunblock', commandBuildUnblock, "Unblock units from being built by reason")

		gadgetHandler:RegisterAllowCommand(CMD.BUILD)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction('buildblock')
		gadgetHandler:RemoveChatAction('buildunblock')
	end

	function GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, reasonKey)
		local blockedUnitDefs = teamBlockedUnitDefs[teamID]
		if not blockedUnitDefs then
			return
		end
		local unitReasons = blockedUnitDefs[unitDefID]
		unitReasons[reasonKey] = true
		local concatenatedReasons = reasonConcatenator(unitReasons)
		Spring.SetTeamRulesParam(teamID, "unitdef_blocked_" .. unitDefID, concatenatedReasons)
		notifyUnitBlocked(unitDefID, teamID, unitReasons)
	end

	function GG.BuildBlocking.RemoveBlockedUnit(unitDefID, teamID, reasonKey)
		local blockedUnitDefs = teamBlockedUnitDefs[teamID]
		if not blockedUnitDefs then
			return false
		end
		local unitReasons = blockedUnitDefs[unitDefID]
		if not unitReasons[reasonKey] then
			return false
		end

		unitReasons[reasonKey] = nil

		if next(unitReasons) then
			local concatenatedReasons = reasonConcatenator(unitReasons)
			Spring.SetTeamRulesParam(teamID, "unitdef_blocked_" .. unitDefID, concatenatedReasons)
		else
			Spring.SetTeamRulesParam(teamID, "unitdef_blocked_" .. unitDefID, nil)
		end
		notifyUnitBlocked(unitDefID, teamID, unitReasons)
		return true
	end

	function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID)
		-- Allows CMD.BUILD (cmdID < 0)
		local buildDefID = -cmdID
		local blockedUnitDefs = teamBlockedUnitDefs[unitTeam]
		if blockedUnitDefs and blockedUnitDefs[buildDefID] and next(blockedUnitDefs[buildDefID]) then
			return false
		end
		return true
	end

	function gadget:GameFrame(frame)
		if not geoInitialized then -- because the geothermal features don't exist until after Initialize() and GameStart()
			landGeoAvailable, seaGeoAvailable = unitRestrictions.hasGeothermalFeatures()
			geoInitialized = true
			for _, teamID in ipairs(teamsList) do
				if not ignoredTeams[teamID] then
					if not landGeoAvailable then
						for unitDefID in pairs(unitRestrictions.isLandGeothermal) do
							GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, "terrain_geothermal")
						end
					end
					if not seaGeoAvailable then
						for unitDefID in pairs(unitRestrictions.isSeaGeothermal) do
							GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, "terrain_geothermal")
						end
					end
				end
			end
		end
	end

-------------------------------------------------------------------------------- Unsynced Code --------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------
elseif not gadgetHandler:IsSyncedCode() then --elseif for readability

	local myPlayerID = Spring.GetMyPlayerID()
	local myTeamID = Spring.GetMyTeamID()

	local function HandleBuildBlocked(_, unitDefID, reasonsStr)
		if Script.LuaUI.UnitBlocked then
			local reasons = {}
			for r in string.gmatch(reasonsStr, "[^,]+") do
				reasons[r] = true
			end
			Script.LuaUI.UnitBlocked(unitDefID, reasons)
		end
	end

	local function UpdateSyncActions()
		if myTeamID then gadgetHandler:RemoveSyncAction("BuildBlocked_" .. myTeamID) end

		myPlayerID = Spring.GetMyPlayerID()
		myTeamID = Spring.GetMyTeamID()

		if myTeamID then
			gadgetHandler:AddSyncAction("BuildBlocked_" .. myTeamID, HandleBuildBlocked)
		end
	end

	function gadget:Initialize()
		UpdateSyncActions()
	end

	function gadget:PlayerChanged(playerID)
		if playerID == myPlayerID then
			UpdateSyncActions()
		end
	end

	function gadget:Shutdown()
		if myTeamID then gadgetHandler:RemoveSyncAction("BuildBlocked_" .. myTeamID) end
	end
end