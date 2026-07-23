local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

local function issueOrders(unitName, orders)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

	local convertedOrders = GG['MissionAPI'].Modules.Loadout.ConvertOrdersTargetingNames(orders)
	Spring.GiveOrderArrayToUnitMap(GG['MissionAPI'].trackedUnitIDs[unitName], convertedOrders)
end

return {
	type = 'IssueOrders',
	parameters = {
		{ name = 'unitName', required = true, type = Types.UnitName },
		{ name = 'orders', required = true, type = Types.Orders },
	},
	actionFunction = issueOrders,
}
