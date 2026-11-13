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
-- state is a value of AiState in campaign_ai_msg.lua.

local SYNC_ACTION = "CampaignAI"

if gadgetHandler:IsSyncedCode() then
	local aiMsg = VFS.Include("luarules/Utilities/campaign_ai_msg.lua")
	local Topic = aiMsg.Topic
	local MsgBuilder = aiMsg.MsgBuilder

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

	GG.CampaignAI = {
		SetUnitDefsEnabled = setUnitDefsEnabled,
		SetUnitsCtrlEnabled = setUnitsCtrlEnabled,
		SetAiActive = setAiActive,
		SetAiState = setAiState,
	}

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
	local function sendToAI(_, teamID, message)
		Spring.SendSkirmishAIMessage(teamID, message)
	end

	function gadget:Initialize()
		if not Spring.GetGameRulesParam("inMission") then
			gadgetHandler:RemoveGadget()
			return
		end
		gadgetHandler:AddSyncAction(SYNC_ACTION, sendToAI)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction(SYNC_ACTION)
	end
end
