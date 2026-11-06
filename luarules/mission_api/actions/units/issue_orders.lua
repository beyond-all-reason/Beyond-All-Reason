local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function issueOrders(unitName, orders)
	local tracking = GG['MissionAPI'].Modules.Tracking
	local gatherWaits = GG['MissionAPI'].Modules.GatherWaits
	if tracking.IsUnitNameUntracked(unitName) then return end

	local convertedOrders = GG['MissionAPI'].Modules.Loadout.ConvertOrdersTargetingNames(orders)

	-- Fence around mission-issued orders for UnitOrdered triggers using `ignoreMissionActions`.
	GG['MissionAPI'].issuingOrders = true
	gatherWaits.GiveOrdersWithGatherWaits(GG['MissionAPI'].trackedUnitIDs[unitName], convertedOrders)
	GG['MissionAPI'].issuingOrders = nil
end

return {
	{
		type = 'IssueOrders',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'orders', required = true, type = ParameterTypes.Orders },
		},
		actionFunction = issueOrders,
	}
}
