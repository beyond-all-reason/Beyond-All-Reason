local gadget = gadget ---@type Gadget

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
	local ignoreUnits = {}
	local gameFrame = Spring.GetGameFrame()
	local startFrame = Spring.GetGameFrame()	-- used in case of luarules reload
	local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt

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

	local function addSkipOrder(unitID)
		ignoreUnits[unitID] = gameFrame + 1
	end

	function gadget:Initialize()
		GG['apm'] = {}
		GG['apm'].addSkipOrder = addSkipOrder

		gadgetHandler:RegisterAllowCommand(CMD.ANY)
	end

	function gadget:UnitFinished(unitID, unitDefID, teamID, builderID)
		ignoreUnits[unitID] = gameFrame + 1
	end

	-- be aware that these arent exclusively user actioned commands
	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, fromSynced, fromLua)
		-- limit to 1 action per gameframe
		if not teamAddedActionFrame[teamID] and totalTeamActions[teamID] and not ignoreUnitDefs[unitID] then
			if not ignoreUnits[unitID] and not spGetUnitIsBeingBuilt(unitID) then	-- believe it or not but unitcreated can come after AllowCommand (with nocost at least)
				totalTeamActions[teamID] = totalTeamActions[teamID] + 1
				teamAddedActionFrame[teamID] = true
			end
		end
		ignoreUnits[unitID] = gameFrame + 7	-- dont count severe cmd spam
		return true
	end

	function gadget:GameFrame(gf)
		gameFrame = gf
		teamAddedActionFrame = {}
		if gf % 300 == 1 then	-- every 10 secs
			for teamID, totalActions in pairs(totalTeamActions) do
				local apm = totalActions / ((gf-startFrame)/1800)	-- 1800 frames = 1 min
				SendToUnsynced("apmBroadcast", teamID, math.floor(apm+0.5))
			end
		end
		for unitID, frame in pairs(ignoreUnits) do
			if frame == gf then
				ignoreUnits[unitID] = nil
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
