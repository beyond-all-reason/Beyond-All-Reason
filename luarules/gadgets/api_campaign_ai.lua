local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Campaign AI API for Gadgets",
		desc = "Allows gadgets to communicate with the campaign AI",
		date = "2026",
		layer = 1, -- requires GG.MissionAPI, run after api_missions.lua
		enabled = true,
	}
end

local BroadcastUnitDefsEnabled
local BroadcastUnitsCtrlEnabled
local BroadcastSetAiActive
local BroadcastSetAiState

if not gadgetHandler:IsSyncedCode() then
	local aiMsg = VFS.Include("luarules/utilities/campaign_ai_msg.lua")

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("SetUnitDefsEnabled", BroadcastUnitDefsEnabled)
		gadgetHandler:AddSyncAction("SetUnitsCtrlEnabled", BroadcastUnitsCtrlEnabled)
		gadgetHandler:AddSyncAction("SetAiActive", BroadcastSetAiActive)
		gadgetHandler:AddSyncAction("SetAiState", BroadcastSetAiState)
	end

	BroadcastUnitDefsEnabled = function(_, unitDefIDs, isEnabled, teamID)
		local msg = aiMsg.MsgBuilder
			.new()
			:cmdArray(isEnabled and aiMsg.Topic.ENABLE_UNITDEFS or aiMsg.Topic.DISABLE_UNITDEFS, unitDefIDs)
			:toString()
		Spring.SendSkirmishAIMessage(teamID, msg)
	end

	BroadcastUnitsCtrlEnabled = function(_, unitIDs, isEnabled, teamID)
		local msg = aiMsg.MsgBuilder
			.new()
			:cmdArray(isEnabled and aiMsg.Topic.ENABLE_UNITS_CONTROL or aiMsg.Topic.DISABLE_UNITS_CONTROL, unitIDs)
			:toString()
		Spring.SendSkirmishAIMessage(teamID, msg)
	end

	BroadcastSetAiActive = function(_, isActive, teamID)
		local msg = aiMsg.MsgBuilder.new():cmdValue(aiMsg.Topic.SET_AI_ACTIVE, isActive and 1 or 0):toString()
		Spring.SendSkirmishAIMessage(teamID, msg)
	end

	BroadcastSetAiState = function(_, state, teamID)
		-- state must correspond to an enum of aiMsg.AiState
		local msg = aiMsg.MsgBuilder.new():cmdValue(aiMsg.Topic.SET_AI_STATE, state):toString()
		Spring.SendSkirmishAIMessage(teamID, msg)
	end
end

GG.CampaignAI = {}

---@param unitDefIDs table of UnitDefID to allow construction
GG.CampaignAI.SetUnitDefsEnabled = function(unitDefIDs, isEnabled, teamID)
	if gadgetHandler:IsSyncedCode() then
		SendToUnsynced("SetUnitDefsEnabled", unitDefIDs, isEnabled, teamID)
	else
		BroadcastUnitDefsEnabled("SetUnitDefsEnabled", unitDefIDs, isEnabled, teamID)
	end
end

---@param unitIDs table of UnitID to enable control by AI
GG.CampaignAI.SetUnitsCtrlEnabled = function(unitIDs, isEnabled, teamID)
	if gadgetHandler:IsSyncedCode() then
		SendToUnsynced("SetUnitsCtrlEnabled", unitIDs, isEnabled, teamID)
	else
		BroadcastUnitsCtrlEnabled("SetUnitsCtrlEnabled", unitIDs, isEnabled, teamID)
	end
end

GG.CampaignAI.SetAiActive = function(isActive, teamID)
	if gadgetHandler:IsSyncedCode() then
		SendToUnsynced("SetAiActive", isActive, teamID)
	else
		BroadcastSetAiActive("SetAiActive", isActive, teamID)
	end
end

GG.CampaignAI.SetAiState = function(state, teamID)
	if gadgetHandler:IsSyncedCode() then
		SendToUnsynced("SetAiState", state, teamID)
	else
		BroadcastSetAiState("SetAiState", state, teamID)
	end
end
