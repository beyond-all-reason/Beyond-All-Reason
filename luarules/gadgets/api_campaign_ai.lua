local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Campaign AI API for Gadgets",
		desc = "Allows gadgets to communicate with the campaign AI",
		date = "2026",
		layer = 1,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	local aiMsg = VFS.Include("luarules/utilities/campaign_ai_msg.lua")

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("GadgetEnableUnitDefs", BroadcastEnableUnitDefs)
		gadgetHandler:AddSyncAction("GadgetDisableUnitDefs", BroadcastDisableUnitDefs)
		gadgetHandler:AddSyncAction("GadgetEnableUnitsCtrl", BroadcastEnableUnitsCtrl)
		gadgetHandler:AddSyncAction("GadgetDisableUnitsCtrl", BroadcastDisableUnitsCtrl)
	end

	function BroadcastEnableUnitDefs(_, teamID, unitDefIDs)
		local msg = aiMsg.BuildArray(aiMsg.topic.ENABLE_UNITDEFS, unitDefIDs)
		Spring.SendSkirmishAIMessage(teamID, msg)
	end

	function BroadcastDisableUnitDefs(_, teamID, unitDefIDs)
		local msg = aiMsg.BuildArray(aiMsg.topic.DISABLE_UNITDEFS, unitDefIDs)
		Spring.SendSkirmishAIMessage(teamID, msg)
	end

	function BroadcastEnableUnitsCtrl(_, teamID, unitIDs)
		local msg = aiMsg.BuildArray(aiMsg.topic.ENABLE_UNITS_CONTROL, unitIDs)
		Spring.SendSkirmishAIMessage(teamID, msg)
	end

	function BroadcastDisableUnitsCtrl(_, teamID, unitIDs)
		local msg = aiMsg.BuildArray(aiMsg.topic.DISABLE_UNITS_CONTROL, unitIDs)
		Spring.SendSkirmishAIMessage(teamID, msg)
	end
end

GG.campaign_ai = {}

---@param unitDefIDs array of UnitDefIDs to allow construction
GG.campaign_ai.GadgetEnableUnitDefs = function(unitDefIDs)
	if gadgetHandler:IsSyncedCode() then
		SendToUnsynced("GadgetEnableUnitDefs", unitDefIDs)
	else
		BroadcastEnableUnitDefs("GadgetEnableUnitDefs", unitDefIDs)
	end
end

---@param unitDefIDs array of UnitDefIDs to forbid construction
GG.campaign_ai.GadgetDisableUnitDefs = function(unitDefIDs)
	if gadgetHandler:IsSyncedCode() then
		SendToUnsynced("GadgetDisableUnitDefs", unitDefIDs)
	else
		BroadcastDisableUnitDefs("GadgetDisableUnitDefs", unitDefIDs)
	end
end

---@param unitIDs array of UnitIDs to enable control by AI
GG.campaign_ai.GadgetEnableUnitsCtrl = function(unitIDs)
	if gadgetHandler:IsSyncedCode() then
		SendToUnsynced("GadgetEnableUnitsCtrl", unitIDs)
	else
		BroadcastEnableUnitsCtrl("GadgetEnableUnitsCtrl", unitIDs)
	end
end

---@param unitIDs array of UnitIDs to disable control by AI
GG.campaign_ai.GadgetDisableUnitsCtrl = function(unitIDs)
	if gadgetHandler:IsSyncedCode() then
		SendToUnsynced("GadgetDisableUnitsCtrl", unitIDs)
	else
		BroadcastDisableUnitsCtrl("GadgetDisableUnitsCtrl", unitIDs)
	end
end
