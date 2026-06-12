

if Spring.Utilities.Gametype.IsSinglePlayer() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name	= "Self-Destruct Resign",
        desc	= "Cancel the order and resign player when he tries to self-destruct all his units",
        author	= "Floris",
        date	= "October 2021",
        license	= "GNU GPL, v2 or later",
        layer	= 0,
        enabled	= true,
    }
end

local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamList = Spring.GetTeamList
local spGetAllyTeamList = Spring.GetAllyTeamList
local gaiaTeamID = Spring.GetGaiaTeamID()
local gaiaAllyTeamID = select(6, spGetTeamInfo(gaiaTeamID, false))

local function isLastAliveNonGaiaAllyTeam(teamID)
	local teamAllyTeamID = select(6, spGetTeamInfo(teamID, false))
	if not teamAllyTeamID then
		return false
	end

	local aliveNonGaiaAllyTeams = 0
	for _, allyTeamID in ipairs(spGetAllyTeamList()) do
		if allyTeamID ~= gaiaAllyTeamID then
			local teams = spGetTeamList(allyTeamID) or {}
			for _, tID in ipairs(teams) do
				if not select(4, spGetTeamInfo(tID, false)) then -- skip AIs
					aliveNonGaiaAllyTeams = aliveNonGaiaAllyTeams + 1
					break
				end
			end
			if aliveNonGaiaAllyTeams > 1 then
				return false
			end
		end
	end

	return aliveNonGaiaAllyTeams == 1 and teamAllyTeamID ~= gaiaAllyTeamID
end

local function hasActiveHumanTeammate(teamID)
	local allyTeamID = select(6, spGetTeamInfo(teamID, false))
	for _, tID in ipairs(spGetTeamList(allyTeamID) or {}) do
		local luaAI = Spring.GetTeamLuaAI(tID)
		if tID ~= teamID and not select(4, spGetTeamInfo(tID, false)) and (not luaAI or luaAI == "") and Spring.GetTeamRulesParam(tID, "numActivePlayers") > 0 then
			return true
		end
	end
	return false
end

if gadgetHandler:IsSyncedCode() then

	local thresholdPercentage = 0.95
	local allowedStrikes = 3

	local CMD_SELFD = CMD.SELFD
	local selfdCheckTeamUnits = {}
	local forceResignStrikesByTeamID = {}
	local spGetUnitSelfDTime = Spring.GetUnitSelfDTime
	local spGetTeamUnits = Spring.GetTeamUnits

	local function cancelSelfDestructOrders(teamID)
		local units = spGetTeamUnits(teamID)
		for i=1, #units do
			local unitID = units[i]
			if spGetUnitSelfDTime(unitID) > 0 then
				Spring.GiveOrderToUnit(unitID, CMD_SELFD, {}, 0)
			end
		end
	end

	local function notifyTeamPlayers(teamID, message)
		local players = Spring.GetPlayerList()
		for _, playerID in pairs(players) do
			if teamID == select(4, Spring.GetPlayerInfo(playerID, false)) then
				SendToUnsynced(message, playerID)
			end
		end
	end

	local function forceResignTeam(teamID)
		cancelSelfDestructOrders(teamID)

		local strikes = (forceResignStrikesByTeamID[teamID] or 0) + 1
		forceResignStrikesByTeamID[teamID] = strikes

		if strikes < allowedStrikes then
			notifyTeamPlayers(teamID, 'forceResignWarn')
			return
		end

		notifyTeamPlayers(teamID, 'forceResignMessage')
		Spring.KillTeam(teamID)
	end

	function gadget:Initialize()
		gadgetHandler:RegisterAllowCommand(CMD_SELFD)
	end

	function gadget:GameFrame(n)
		if n % 15 == 1 then
			for teamID, _ in pairs(selfdCheckTeamUnits) do
				if not isLastAliveNonGaiaAllyTeam(teamID) then
					local units = spGetTeamUnits(teamID)
					local unitCount = #units
					local triggerResignAmount = math.ceil(unitCount * thresholdPercentage)
					local skipResignAmount = unitCount - triggerResignAmount
					local selfdUnitCount = 0
					local skippedUnitCount = 0
					for i=1, unitCount do
						local unitID = units[i]
						if spGetUnitSelfDTime(unitID) > 0 then
							selfdUnitCount = selfdUnitCount + 1
						else
							skippedUnitCount = skippedUnitCount + 1
						end
						if skippedUnitCount > skipResignAmount then
							break
						elseif selfdUnitCount >= triggerResignAmount then
							local LuaAI = Spring.GetTeamLuaAI(teamID)
							if not LuaAI or not ( string.find(LuaAI, "Scavengers") or string.find(LuaAI, "Raptors") ) then
								forceResignTeam(teamID)
							end
							break
						end
					end
				end
			end
			selfdCheckTeamUnits = {}
		end
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		if teamID ~= gaiaTeamID and not isLastAliveNonGaiaAllyTeam(teamID) then
			selfdCheckTeamUnits[teamID] = true
		end
		return true
	end


else -- UNSYNCED


	local myPlayerID = Spring.GetMyPlayerID()
	local myTeamID = Spring.GetMyTeamID()

	local function showForceResignNotification(playerID, messageKey)
		if playerID ~= myPlayerID or Spring.GetSpectatingState() then
			return
		end
		if isLastAliveNonGaiaAllyTeam(myTeamID) then
			return
		end

		if hasActiveHumanTeammate(myTeamID) and Script.LuaUI('GadgetMessageProxy') then
			Spring.Echo("\255\255\166\166" .. Script.LuaUI.GadgetMessageProxy(messageKey))
		end
	end

	local function forceResignWarn(_, playerID)
		showForceResignNotification(playerID, 'ui.forceResignWarn')
	end

	local function forceResignMessage(_, playerID)
		showForceResignNotification(playerID, 'ui.forceResignMessage')
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction('forceResignWarn', forceResignWarn)
		gadgetHandler:AddSyncAction('forceResignMessage', forceResignMessage)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction('forceResignWarn')
		gadgetHandler:RemoveSyncAction('forceResignMessage')
	end
end
