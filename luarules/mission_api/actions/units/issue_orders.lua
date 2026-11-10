local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function issueOrders(unitName, orders, marching, direction)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

	local convertedOrders = GG['MissionAPI'].Modules.Loadout.ConvertOrdersTargetingNames(orders)
	local unitIDs = GG['MissionAPI'].trackedUnitIDs[unitName]

	-- Fence around mission-issued orders for UnitOrdered triggers using `ignoreMissionActions`.
	GG['MissionAPI'].issuingOrders = true
	if marching then
		GG['MissionAPI'].Modules.Marching.GiveMarchingOrders(unitIDs, convertedOrders, direction)
	else
		Spring.GiveOrderArrayToUnitMap(unitIDs, convertedOrders)
	end
	GG['MissionAPI'].issuingOrders = nil
end

return {
	{
		type = 'IssueOrders',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'orders', required = true, type = ParameterTypes.Orders },
			{ name = 'marching', required = false, type = ParameterTypes.Boolean },
			{ name = 'direction', required = false, type = ParameterTypes.Direction },
		},
		actionFunction = issueOrders,
	}
}
