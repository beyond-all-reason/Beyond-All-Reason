

if Spring.Utilities.Gametype.IsSinglePlayer() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name	= "Self-Destruct Resign",
        desc	= "Converts a self-destruct to resign",
        author	= "Floris",
        date	= "October 2021",
        license	= "GNU GPL, v2 or later",
        layer	= 0,
        enabled	= true,
    }
end

if gadgetHandler:IsSyncedCode() then

	local thresholdPercentage = 0.95

	local CMD_SELFD = CMD.SELFD
	local selfdCheckTeamUnits = {}
	local spGetUnitSelfDTime = Spring.GetUnitSelfDTime
	local spGetTeamUnits = Spring.GetTeamUnits
	local gaiaTeamID = Spring.GetGaiaTeamID()

	local function forceResignTeam(teamID)

		-- cancel self-d orders
		local units = spGetTeamUnits(teamID)
		for i=1, #units do
			local unitID = units[i]
			if spGetUnitSelfDTime(unitID) > 0 then
				Spring.GiveOrderToUnit(unitID, CMD_SELFD, {}, 0)
			end
		end

		Spring.KillTeam(teamID)

		-- notify players in this team
		local players = Spring.GetPlayerList()
		for _, playerID in pairs(players) do
			if teamID == select(4, Spring.GetPlayerInfo(playerID, false)) then
				SendToUnsynced('forceResignMessage', playerID)
			end
		end
	end

	function gadget:Initialize()
		gadgetHandler:RegisterAllowCommand(CMD_SELFD)
	end

	function gadget:GameFrame(n)
		if n % 15 == 1 then
			for teamID, _ in pairs(selfdCheckTeamUnits) do

				-- check first if player has team players... that could possibly take
				--local numActiveTeamPlayers = 0
				--local allyTeamID = select(6, Spring.GetTeamInfo(teamID,false))
				--local teamList = Spring.GetTeamList(allyTeamID)
				--for _,tID in ipairs(teamList) do
				--	local luaAI = Spring.GetTeamLuaAI(tID)
				--	if tID ~= teamID and not select(4, Spring.GetTeamInfo(tID,false)) and (not luaAI or luaAI == "") and Spring.GetTeamRulesParam(tID, "numActivePlayers") > 0 then
				--		numActiveTeamPlayers = numActiveTeamPlayers + 1
				--	end
				--end

				-- players has teammates
				--if numActiveTeamPlayers > 1 then
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
						if skippedUnitCount >= skipResignAmount then
							break
						elseif selfdUnitCount >= triggerResignAmount then
							local LuaAI = Spring.GetTeamLuaAI(teamID)
							if not LuaAI or not ( string.find(LuaAI, "Scavengers") or string.find(LuaAI, "Raptors") ) then
								forceResignTeam(teamID)
							end
							break
						end
					end
				--end
			end
			selfdCheckTeamUnits = {}
		end
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		if teamID ~= gaiaTeamID then
			selfdCheckTeamUnits[teamID] = true
		end
		return true
	end


else -- UNSYNCED


	local myPlayerID = Spring.GetMyPlayerID()
	local myTeamID = Spring.GetMyTeamID()

	local function forceResignMessage(_, playerID)
		if playerID == myPlayerID then
		if not Spring.GetSpectatingState() then
			-- check first if player has team players
			local numActiveTeamPlayers = 0
			local allyID = select(6, Spring.GetTeamInfo(myTeamID, false))
			local teamList = Spring.GetTeamList(allyID)
			for _,tID in ipairs(teamList) do
					local luaAI = Spring.GetTeamLuaAI(tID)
					if tID ~= myTeamID and not select(4, Spring.GetTeamInfo(tID,false)) and (not luaAI or luaAI == "") and Spring.GetTeamRulesParam(tID, "numActivePlayers") > 0 then
						numActiveTeamPlayers = numActiveTeamPlayers + 1
					end
				end
				if numActiveTeamPlayers > 0 and Script.LuaUI('GadgetMessageProxy') then
					Spring.Echo("\255\255\166\166" .. Script.LuaUI.GadgetMessageProxy('ui.forceResignMessage'))
				end
			end
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction('forceResignMessage', forceResignMessage)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction('forceResignMessage')
	end
end
