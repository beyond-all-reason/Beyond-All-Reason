local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Campaign AI API for Gadgets",
		desc = "Allows gadgets to communicate with the campaign AI",
		date = "2026",
		layer = 1, -- after api_missions.lua sets inMission
		enabled = true,
	}
end

local SYNC_ACTION = "CampaignAI"
local SYNC_ACTION_SIGNAL = SYNC_ACTION .. "Signal"
local MESSAGE_SIGNAL = SYNC_ACTION_SIGNAL .. ":"

if gadgetHandler:IsSyncedCode() then
	local aiMsg = VFS.Include("luarules/Utilities/campaign_ai_msg.lua")
	local topics = aiMsg.Topic
	local newMessage = aiMsg.MsgBuilder.new
	local squadParams = aiMsg.Squad
	local militaryParams = aiMsg.Military
	local planParams = aiMsg.Plan

	local function setUnitDefsEnabled(unitDefIDs, isEnabled, teamID)
		local topic = isEnabled and topics.ENABLE_UNITDEFS or topics.DISABLE_UNITDEFS
		SendToUnsynced(SYNC_ACTION, teamID, newMessage():cmdArray(topic, unitDefIDs):toString())
	end

	local function setUnitsCtrlEnabled(unitIDs, isEnabled, teamID)
		local topic = isEnabled and topics.ENABLE_UNITS_CONTROL or topics.DISABLE_UNITS_CONTROL
		SendToUnsynced(SYNC_ACTION, teamID, newMessage():cmdArray(topic, unitIDs):toString())
	end

	local function setAiActive(isActive, teamID)
		local message = newMessage():cmdValue(topics.SET_AI_ACTIVE, isActive and 1 or 0):toString()
		SendToUnsynced(SYNC_ACTION, teamID, message)
	end

	local function setAiState(state, teamID)
		SendToUnsynced(SYNC_ACTION, teamID, newMessage():cmdValue(topics.SET_AI_STATE, state):toString())
	end

	local function setProductionEnabled(unitIDs, isEnabled, teamID)
		local message = newMessage():cmdDictArray(topics.SET_FACTORY_ACTIVE, isEnabled and 1 or 0, unitIDs):toString()
		SendToUnsynced(SYNC_ACTION, teamID, message)
	end

	local function setMexCap(share, countsAllies, teamID)
		local message = newMessage():cmdArray(topics.SET_MEX_CAP, { share, countsAllies and 1 or 0 }):toString()
		SendToUnsynced(SYNC_ACTION, teamID, message)
	end

	local function setMilitaryQuota(scouts, attackPower, raidPower, teamID)
		local quotas = {
			[militaryParams.SCOUTS_COUNT] = scouts,
			[militaryParams.ATTACK_POWER] = attackPower,
			[militaryParams.RAID_POWER] = raidPower,
		}
		SendToUnsynced(SYNC_ACTION, teamID, newMessage():cmdDict(topics.AI_MILITARY_PARAMS, quotas):toString())
	end

	local function setUnitDefRetreat(unitDefID, retreat, teamID)
		local message = newMessage():cmdDictArray(topics.SET_UNITDEF_RETREAT_HP, unitDefID, { retreat }):toString()
		SendToUnsynced(SYNC_ACTION, teamID, message)
	end

	local function defineSquad(squadID, unitCounts, x, z, gatherRange, attackRange, teamID)
		local message = newMessage()
			:cmdValue(topics.SQUAD_REQUEST_ID, squadID)
			:cmdDictArray(topics.SQUAD_REQUEST_PARAMS, squadParams.POSITION, { x, z })
			:paramValue(squadParams.GATHER_RANGE, gatherRange)

		if attackRange then
			message:paramValue(squadParams.ATTACK_RANGE, attackRange)
		end

		message:cmdDict(topics.SQUAD_REQUEST_COMPOSE, unitCounts)
		SendToUnsynced(SYNC_ACTION, teamID, message:toString())
	end

	local function setSquadTask(squadID, task, x, z, attackRange, teamID)
		local message = newMessage()
			:cmdValue(topics.SQUAD_ID, squadID)
			:cmdValue(topics.SQUAD_TASK, task)
			:cmdDictArray(topics.SQUAD_PARAMS, squadParams.POSITION, { x, z })

		if attackRange then
			message:paramValue(squadParams.ATTACK_RANGE, attackRange)
		end

		SendToUnsynced(SYNC_ACTION, teamID, message:toString())
	end

	local function cancelSquad(squadID, teamID)
		local message = newMessage():cmdValue(topics.SQUAD_REQUEST_CANCEL, squadID):toString()
		SendToUnsynced(SYNC_ACTION, teamID, message)
	end

	local function disbandSquad(squadID, teamID)
		SendToUnsynced(SYNC_ACTION, teamID, newMessage():cmdValue(topics.SQUAD_DISBAND, squadID):toString())
	end

	local function setSquadRegather(squadID, regathers, teamID)
		local message = newMessage()
			:cmdValue(topics.SQUAD_REQUEST_ID, squadID)
			:cmdDictArray(topics.SQUAD_REQUEST_PARAMS, squadParams.REBUILD, { regathers and 1 or 0 })
		SendToUnsynced(SYNC_ACTION, teamID, message:toString())
	end

	local function setSquadRetreat(squadID, retreat, isAssembled, teamID)
		local message = newMessage()
			:cmdValue(topics.SQUAD_REQUEST_ID, squadID)
			:cmdDictArray(topics.SQUAD_REQUEST_PARAMS, squadParams.RETREAT, { retreat })

		if isAssembled then
			message
				:cmdValue(topics.SQUAD_ID, squadID)
				:cmdDictArray(topics.SQUAD_PARAMS, squadParams.RETREAT, { retreat })
		end

		SendToUnsynced(SYNC_ACTION, teamID, message:toString())
	end

	local function setSquadTarget(squadID, unitID, teamID)
		local message = newMessage()
			:cmdValue(topics.SQUAD_ID, squadID)
			:cmdDictArray(topics.SQUAD_PARAMS, squadParams.PRIO_TARGET, { unitID })
		SendToUnsynced(SYNC_ACTION, teamID, message:toString())
	end

	local function setSquadEscort(squadID, unitID, teamID)
		local message = newMessage():cmdValue(topics.SQUAD_ID, squadID):cmdValue(topics.SQUAD_ESCORT, unitID)
		SendToUnsynced(SYNC_ACTION, teamID, message:toString())
	end

	local function defineAiRegion(regionID, polygon, teamID)
		local message = newMessage():cmdDictArray(topics.TRIGGER_REGION_ID, regionID, polygon):toString()
		SendToUnsynced(SYNC_ACTION, teamID, message)
	end

	local function clearAiRegion(regionID, teamID)
		local message = newMessage():cmdValue(topics.TRIGGER_REGION_CLEAR, regionID):toString()
		SendToUnsynced(SYNC_ACTION, teamID, message)
	end

	local function defineBuildArea(buildAreaID, polygon, unitDefID, facing, buildsAtOnce, teamID)
		local message = newMessage()
			:cmdDictArray(topics.BUILD_REGION_ID, buildAreaID, polygon)
			:addValue(unitDefID)
			:addValue(facing)
			:addValue(buildsAtOnce)
		SendToUnsynced(SYNC_ACTION, teamID, message:toString())
	end

	local function addToBasePlan(basePlanID, unitDefID, x, z, isRebuilt, teamID)
		local message = newMessage()
			:cmdValue(topics.BASE_PLAN_ID, basePlanID)
			:cmdDictArray(topics.BASE_ADD_BUILDTASK, planParams.UNITDEF, { unitDefID })
			:paramArray(planParams.POSITION, { x, z })
			:paramValue(planParams.REBUILD, isRebuilt and 1 or 0)
		SendToUnsynced(SYNC_ACTION, teamID, message:toString())
	end

	local function cancelBasePlan(basePlanID, teamID)
		local message = newMessage():cmdValue(topics.BASE_PLAN_CANCEL, basePlanID):toString()
		SendToUnsynced(SYNC_ACTION, teamID, message)
	end

	local SIGNAL_FROM_AI = "^" .. aiMsg.Signal.PREFIX .. "(%d+:%d+;?%d*)$"
	local SIGNAL_MESSAGE = "^" .. MESSAGE_SIGNAL .. "(%d+):(%d+):(%d+);?(%d*)$"

	local function readSignal(message, playerID)
		local team, signal, id, detailID = message:match(SIGNAL_MESSAGE)
		local teamID = tonumber(team) --[[@as integer?]]
		if not teamID then
			return
		end

		local _, _, hostPlayerID = Spring.GetAIInfo(teamID)
		if playerID ~= hostPlayerID then
			return
		end

		return teamID, tonumber(signal), tonumber(id), tonumber(detailID)
	end

	GG.CampaignAI = {
		SetUnitDefsEnabled = setUnitDefsEnabled,
		SetUnitsCtrlEnabled = setUnitsCtrlEnabled,
		SetAiActive = setAiActive,
		SetAiState = setAiState,
		SetProductionEnabled = setProductionEnabled,
		SetMexCap = setMexCap,
		SetMilitaryQuota = setMilitaryQuota,
		SetUnitDefRetreat = setUnitDefRetreat,
		DefineSquad = defineSquad,
		SetSquadTask = setSquadTask,
		CancelSquad = cancelSquad,
		DisbandSquad = disbandSquad,
		SetSquadRegather = setSquadRegather,
		SetSquadRetreat = setSquadRetreat,
		SetSquadTarget = setSquadTarget,
		SetSquadEscort = setSquadEscort,
		DefineAiRegion = defineAiRegion,
		ClearAiRegion = clearAiRegion,
		DefineBuildArea = defineBuildArea,
		AddToBasePlan = addToBasePlan,
		CancelBasePlan = cancelBasePlan,
		ReadSignal = readSignal,
	}

	-- Only the AI's host gets this call, so acting on it here would desync. Sent as a Lua rules
	-- message, the signal reaches RecvLuaMsg on every client on the same frame.
	function gadget:RecvSkirmishAIMessage(teamID, message)
		local signal = message:match(SIGNAL_FROM_AI)
		if signal then
			SendToUnsynced(SYNC_ACTION_SIGNAL, teamID, signal)
		end
	end

	function gadget:Initialize()
		if not Spring.GetGameRulesParam("inMission") then
			gadgetHandler:RemoveGadget()
			return
		end
	end

	function gadget:Shutdown()
		GG.CampaignAI = nil
	end
else
	local AI_SHORT_NAME = "CampaignAI"
	local REMOTE_AI_SHORT_NAME = "UNKNOWN" -- Spring.GetAIInfo, for an AI that another player hosts

	-- The engine creates the AIs after GamePreload, so a message from before the game starts has to wait.
	local aisExist = false
	local heldMessages = {}
	local warnedTeams = {}

	local function send(teamID, message)
		local _, _, _, shortName = Spring.GetAIInfo(teamID)
		if shortName == AI_SHORT_NAME then
			Spring.SendSkirmishAIMessage(teamID, message)
		elseif shortName and shortName ~= REMOTE_AI_SHORT_NAME and not warnedTeams[teamID] then
			warnedTeams[teamID] = true
			local warning = "Team " .. teamID .. " is run by " .. shortName .. ", not by the campaign AI"
			Spring.Log("Campaign AI API", LOG.WARNING, warning)
		end
	end

	local function sendToAI(_, teamID, message)
		if aisExist then
			send(teamID, message)
		else
			heldMessages[#heldMessages + 1] = { teamID, message }
		end
	end

	function gadget:GameStart()
		aisExist = true

		for _, held in ipairs(heldMessages) do
			send(held[1], held[2])
		end

		heldMessages = {}
	end

	local function relaySignal(_, teamID, signal)
		Spring.SendLuaRulesMsg(MESSAGE_SIGNAL .. teamID .. ":" .. signal)
	end

	function gadget:Initialize()
		if not Spring.GetGameRulesParam("inMission") then
			gadgetHandler:RemoveGadget()
			return
		end
		aisExist = Spring.GetGameFrame() > 0
		gadgetHandler:AddSyncAction(SYNC_ACTION, sendToAI)
		gadgetHandler:AddSyncAction(SYNC_ACTION_SIGNAL, relaySignal)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction(SYNC_ACTION)
		gadgetHandler:RemoveSyncAction(SYNC_ACTION_SIGNAL)
	end
end
