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

-- provides:
--   GG.CampaignAI.SetUnitDefsEnabled(unitDefIDs, isEnabled, teamID)
--   GG.CampaignAI.SetUnitsCtrlEnabled(unitIDs, isEnabled, teamID)
--   GG.CampaignAI.SetAiActive(isActive, teamID)
--   GG.CampaignAI.SetAiState(state, teamID)
--   GG.CampaignAI.DefineSquad(squadID, unitCounts, x, z, gatherRange, attackRange, teamID)
--   GG.CampaignAI.ReadSignal(message, playerID), for RecvLuaMsg
-- state is a value of AiState in campaign_ai_msg.lua. unitCounts maps unitDefID to a count.
-- ReadSignal returns the AI's team, a value of Signal in campaign_ai_msg.lua and the one or two IDs
-- it came with, or nil when the message is not a signal from the player hosting that team's AI.

local SYNC_ACTION = "CampaignAI"
local SYNC_ACTION_SIGNAL = SYNC_ACTION .. "Signal"
local MESSAGE_SIGNAL = SYNC_ACTION_SIGNAL .. ":"

if gadgetHandler:IsSyncedCode() then
	local aiMsg = VFS.Include("luarules/Utilities/campaign_ai_msg.lua")
	local Topic = aiMsg.Topic
	local MsgBuilder = aiMsg.MsgBuilder
	local Squad = aiMsg.Squad

	local function setUnitDefsEnabled(unitDefIDs, isEnabled, teamID)
		local topic = isEnabled and Topic.ENABLE_UNITDEFS or Topic.DISABLE_UNITDEFS
		SendToUnsynced(SYNC_ACTION, teamID, MsgBuilder.new():cmdArray(topic, unitDefIDs):toString())
	end

	local function setUnitsCtrlEnabled(unitIDs, isEnabled, teamID)
		local topic = isEnabled and Topic.ENABLE_UNITS_CONTROL or Topic.DISABLE_UNITS_CONTROL
		SendToUnsynced(SYNC_ACTION, teamID, MsgBuilder.new():cmdArray(topic, unitIDs):toString())
	end

	local function setAiActive(isActive, teamID)
		local message = MsgBuilder.new():cmdValue(Topic.SET_AI_ACTIVE, isActive and 1 or 0):toString()
		SendToUnsynced(SYNC_ACTION, teamID, message)
	end

	local function setAiState(state, teamID)
		SendToUnsynced(SYNC_ACTION, teamID, MsgBuilder.new():cmdValue(Topic.SET_AI_STATE, state):toString())
	end

	local function defineSquad(squadID, unitCounts, x, z, gatherRange, attackRange, teamID)
		local message = MsgBuilder.new()
			:cmdValue(Topic.SQUAD_REQUEST_ID, squadID)
			:cmdDictArray(Topic.SQUAD_REQUEST_PARAMS, Squad.POSITION, { x, z })
			:paramValue(Squad.GATHER_RANGE, gatherRange)

		if attackRange then
			message:paramValue(Squad.ATTACK_RANGE, attackRange)
		end

		-- Sorted, so the message does not depend on the order pairs walks unitCounts in.
		local unitDefIDs = table.keys(unitCounts)
		table.sort(unitDefIDs)
		message:cmdDictArray(Topic.SQUAD_REQUEST_COMPOSE, unitDefIDs[1], { unitCounts[unitDefIDs[1]] })

		for i = 2, #unitDefIDs do
			message:paramValue(unitDefIDs[i], unitCounts[unitDefIDs[i]])
		end

		SendToUnsynced(SYNC_ACTION, teamID, message:toString())
	end

	local SIGNAL_FROM_AI = "^" .. aiMsg.Signal.PREFIX .. "(%d+:.+)"
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
		DefineSquad = defineSquad,
		ReadSignal = readSignal,
	}

	-- The AI calls this outside the simulation and only on the machine that hosts it, so the
	-- signal takes the way round through the net to reach synced code on every client.
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
	-- The engine creates the AIs after GamePreload, so a message from before the game starts has to wait.
	local aisExist = false
	local heldMessages = {}

	local function sendToAI(_, teamID, message)
		if aisExist then
			Spring.SendSkirmishAIMessage(teamID, message)
		else
			heldMessages[#heldMessages + 1] = { teamID, message }
		end
	end

	function gadget:GameStart()
		aisExist = true

		for _, held in ipairs(heldMessages) do
			Spring.SendSkirmishAIMessage(held[1], held[2])
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
