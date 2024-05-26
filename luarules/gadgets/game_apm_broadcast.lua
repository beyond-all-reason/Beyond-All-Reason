function gadget:GetInfo()
	return {
		name	= "APM Broadcast",
		desc	= "Broadcasts ActionsPerMinute",
		author	= "Floris",
		date	= "May 2024",
		license	= "GNU GPL, v2 or later",
		layer	= 99999999,
		enabled = true,
	}
end


if gadgetHandler:IsSyncedCode() then

	local teamAddedActionFrame = {}
	local startFrame = Spring.GetGameFrame()	-- used in case of luarules reload

	local totalTeamActions = {}
	for _, teamID in ipairs(Spring.GetTeamList()) do
		totalTeamActions[teamID] = 0
	end
	local ignoreUnitDefs = {}
	for uDefID, uDef in pairs(UnitDefs) do
		if uDef.customParams.drone then
			ignoreUnitDefs[uDefID] = true
		end
	end

	-- be aware that these arent exclusively user actioned commands
	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
		-- limit to 1 action per gameframe
		if not teamAddedActionFrame[teamID] and totalTeamActions[teamID] and not ignoreUnitDefs[unitDefID] then
			totalTeamActions[teamID] = totalTeamActions[teamID] + 1
			teamAddedActionFrame[teamID] = true
		end
		return true
	end

	function gadget:GameFrame(gf)
		teamAddedActionFrame = {}
		if gf % 450 == 1 then	-- every 15 secs
			for teamID, totalActions in pairs(totalTeamActions) do
				local apm = totalActions / ((gf-startFrame)/1800)	-- 1800 frames = 1 min
				SendToUnsynced("apmBroadcast", teamID, math.floor(apm+0.5))
			end
		end
	end

	function gadget:TeamDied(teamID)
		totalTeamActions[teamID] = nil
	end


else	-- unsynced


	local function handleApmEvent(_, teamID, apm)
		if Script.LuaUI("ApmEvent") then
			Script.LuaUI.ApmEvent(teamID, apm)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("apmBroadcast", handleApmEvent)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("apmBroadcast")
	end

end
