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

if gadgetHandler:IsSyncedCode() then

	local UNAUTHORIZED_TEXT = "You are not authorized to use build blocking commands"

	local unsyncedMessageQueue = {}
	local currentSendIndex = 1
	local nextEnqueueIndex = 1
	local MAX_QUEUE_INDEX = 999999
	local MAX_MESSAGES_PER_FRAME = 100 -- something sane

	local function enqueueUnsyncedMessage(messageName, unitDefID, teamID, reasons) -- Because there are potentially thousands of units.
		local startIndex = nextEnqueueIndex
		while unsyncedMessageQueue[nextEnqueueIndex] do
			nextEnqueueIndex = nextEnqueueIndex + 1
			if nextEnqueueIndex > MAX_QUEUE_INDEX then
				nextEnqueueIndex = 1
			end
			if nextEnqueueIndex == startIndex then
				return
			end
		end

		unsyncedMessageQueue[nextEnqueueIndex] = {
			messageName = messageName,
			unitDefID = unitDefID,
			teamID = teamID,
			reasons = reasons
		}

		nextEnqueueIndex = nextEnqueueIndex + 1
		if nextEnqueueIndex > MAX_QUEUE_INDEX then
			nextEnqueueIndex = 1
		end
	end


	local windDisabled = false
	local waterAvailable = true
	local geoAvailable = true

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
	end
	for unitDefID, unitDef in pairs(UnitDefs) do
		for _, teamID in ipairs(teamsList) do
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
			if (_G and _G.powerusers and _G.powerusers[accountID]) or (SYNCED and SYNCED.powerusers and SYNCED.powerusers[accountID]) then
				return true
			end
		end
		return false
	end

	local unitRestrictions = VFS.Include("common/configs/unit_restrictions_config.lua")

	local permanentKeys = { -- these will not be removed via console commands.
		terrain_wind = true,
		terrain_water = true,
		terrain_geothermal = true,
	}

	local function commandBuildBlock(_, line, words, playerID)
		if not isAuthorized(playerID) then
			Spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
			return
		end

		if #words < 3 then
			Spring.SendMessageToPlayer(playerID, "Usage: /luarules buildblock <teamID|'all'> <reason_key> <unitDefID/unitDefName 1> <unitDefID/unitDefName 2> ... or 'all'")
			return
		end

		local teamParam = words[1]
		local reasonKey = words[2]
		local blockedCount = 0

		local teamsToProcess = {}
		if teamParam == "all" then
			for _, teamID in ipairs(teamsList) do
				if not ignoredTeams[teamID] then
					table.insert(teamsToProcess, teamID)
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

		if words[3] == "all" then
			for unitDefID in pairs(UnitDefs) do
				local actuallyBlocked = false
				for _, teamID in ipairs(teamsToProcess) do
					GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, reasonKey)
					actuallyBlocked = true
				end
				if actuallyBlocked then
					blockedCount = blockedCount + 1
				end
			end
		else
			for i = 3, #words do
				local unitDefID = tonumber(words[i])
				if not unitDefID then
					local nameDef = UnitDefNames[words[i]]
					if nameDef then
						unitDefID = nameDef.id
					end
				end

				if unitDefID and UnitDefs[unitDefID] then
					local actuallyBlocked = false
					for _, teamID in ipairs(teamsToProcess) do
						GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, reasonKey)
						actuallyBlocked = true
					end
					if actuallyBlocked then
						blockedCount = blockedCount + 1
					end
				else
					Spring.SendMessageToPlayer(playerID, "Invalid unitDefID or unitDefName: " .. tostring(words[i]))
				end
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
			Spring.SendMessageToPlayer(playerID, "Usage: /luarules buildunblock <teamID|'all'> <reason_key|'all'> <unitDefID/unitDefName 1> <unitDefID/unitDefName 2> ... or 'all'")
			return
		end

		local teamParam = words[1]
		local reasonKey = words[2]
		local unblockedCount = 0

		local teamsToProcess = {}
		if teamParam == "all" then
			for _, teamID in ipairs(teamsList) do
				if not ignoredTeams[teamID] then
					table.insert(teamsToProcess, teamID)
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

		if words[3] == "all" then
			for unitDefID in pairs(UnitDefs) do
				local actuallyUnblocked = false
				for _, teamID in ipairs(teamsToProcess) do
					if reasonKey == "all" then
						local blockedUnitDefs = teamBlockedUnitDefs[teamID]
						if blockedUnitDefs and blockedUnitDefs[unitDefID] then
							for reason in pairs(blockedUnitDefs[unitDefID]) do
								if not permanentKeys[reason] then
									if GG.BuildBlocking.RemoveBlockedUnit(unitDefID, teamID, reason) then
										actuallyUnblocked = true
									end
								end
							end
						end
					else
						if GG.BuildBlocking.RemoveBlockedUnit(unitDefID, teamID, reasonKey) then
							actuallyUnblocked = true
						end
					end
				end
				if actuallyUnblocked then
					unblockedCount = unblockedCount + 1
				end
			end
		else
			for i = 3, #words do
				local unitDefID = tonumber(words[i])
				if not unitDefID then
					local nameDef = UnitDefNames[words[i]]
					if nameDef then
						unitDefID = nameDef.id
					end
				end

				if unitDefID and UnitDefs[unitDefID] then
					local actuallyUnblocked = false
					for _, teamID in ipairs(teamsToProcess) do
						if reasonKey == "all" then
							local blockedUnitDefs = teamBlockedUnitDefs[teamID]
							if blockedUnitDefs and blockedUnitDefs[unitDefID] then
								for reason in pairs(blockedUnitDefs[unitDefID]) do
									if not permanentKeys[reason] then
										if GG.BuildBlocking.RemoveBlockedUnit(unitDefID, teamID, reason) then
											actuallyUnblocked = true
										end
									end
								end
							end
						else
							if GG.BuildBlocking.RemoveBlockedUnit(unitDefID, teamID, reasonKey) then
								actuallyUnblocked = true
							end
						end
					end
					if actuallyUnblocked then
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

	local function UpdateModoptionRestrictions(teamID)
		for unitDefID, unitDef in pairs(UnitDefs) do
			if unitDef.maxThisUnit == 0 then
				GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, "modoption_blocked")
			end
		end
	end

	local function UpdateAllModoptionRestrictions()
		for _, teamID in ipairs(teamsList) do
			if not ignoredTeams[teamID] then
				UpdateModoptionRestrictions(teamID)
			end
		end
	end

	local function UpdateTerrainRestrictions(teamID)
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

		if not geoAvailable then
			for unitDefID in pairs(unitRestrictions.isGeothermal) do
				GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, "terrain_geothermal")
			end
		end
	end

	local function UpdateAllTerrainRestrictions()
		for _, teamID in ipairs(teamsList) do
			if not ignoredTeams[teamID] then
				UpdateTerrainRestrictions(teamID)
			end
		end
	end

	function gadget:Initialize()
		GG.BuildBlocking = GG.BuildBlocking or {}
		windDisabled = unitRestrictions.isWindDisabled()
		waterAvailable = unitRestrictions.shouldShowWaterUnits()
		geoAvailable = unitRestrictions.hasGeothermalFeatures()
		UpdateAllTerrainRestrictions()
		UpdateAllModoptionRestrictions()

		gadgetHandler:AddChatAction('buildblock', commandBuildBlock, "Block units from being built by reason")
		gadgetHandler:AddChatAction('buildunblock', commandBuildUnblock, "Unblock units from being built by reason")
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
		blockedUnitDefs[unitDefID] = blockedUnitDefs[unitDefID] or {}
		blockedUnitDefs[unitDefID][reasonKey] = true
		local concatenatedReasons = reasonConcatenator(blockedUnitDefs[unitDefID])
		Spring.SetTeamRulesParam(teamID, "unitdef_blocked_" .. unitDefID, concatenatedReasons)
		enqueueUnsyncedMessage("UnitBlocked", unitDefID, teamID, blockedUnitDefs[unitDefID])
	end

	function GG.BuildBlocking.RemoveBlockedUnit(unitDefID, teamID, reasonKey)
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
		enqueueUnsyncedMessage("UnitBlocked", unitDefID, teamID, blockedUnitDefs[unitDefID])
		return wasRemoved
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

	function gadget:GameFrame()
		local processedCount = 0
		while processedCount < MAX_MESSAGES_PER_FRAME do
			local message = unsyncedMessageQueue[currentSendIndex]
			if not message then
				break
			end

			SendToUnsynced(message.messageName, message.unitDefID, message.teamID, message.reasons)
			unsyncedMessageQueue[currentSendIndex] = nil

			currentSendIndex = currentSendIndex + 1
			if currentSendIndex > MAX_QUEUE_INDEX then
				currentSendIndex = 1
			end

			processedCount = processedCount + 1
		end
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