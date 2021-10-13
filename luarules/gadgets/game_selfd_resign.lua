
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
				--Spring.SendMessageToPlayer(playerID, "\255\255\166\166You're being force-resigned: Self-destructing all units is considered unwanted behavior.")
			end
		end
	end

	function gadget:GameFrame(n)
		if n % 15 == 1 then
			for teamID, _ in pairs(selfdCheckTeamUnits) do
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
						forceResignTeam(teamID)
						break
					end
				end
			end
			selfdCheckTeamUnits = {}
		end
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		if cmdID == CMD_SELFD then
			selfdCheckTeamUnits[teamID] = true
		end
		return true
	end


else -- UNSYNCED


	local myPlayerID = Spring.GetMyPlayerID()

	local function forceResignMessage(_, playerID)
		if playerID == myPlayerID then
			Spring.Echo(  "\255\255\166\166" .. Spring.I18N('ui.forceResignMessage') )
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction('forceResignMessage', forceResignMessage)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction('forceResignMessage')
	end
end
