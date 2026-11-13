local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function issueOrders(unitName, orders, marching, direction, matchSpeed)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

	local missionOrders = GG['MissionAPI'].Modules.Orders
	local unitIDs = GG['MissionAPI'].trackedUnitIDs[unitName]
	if marching then
		local marchingModule = GG['MissionAPI'].Modules.Marching
		local unitOrders = marchingModule.GetMarchingOrders(unitIDs, orders, direction)
		missionOrders.GiveUnitOrders(unitOrders)
		if matchSpeed then
			marchingModule.MatchSpeed(unitOrders)
		end
	else
		missionOrders.GiveOrders(unitIDs, orders)
	end
end

return {
	{
		type = 'IssueOrders',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'orders', required = true, type = ParameterTypes.Orders },
			{ name = 'marching', required = false, type = ParameterTypes.Boolean },
			{ name = 'direction', required = false, type = ParameterTypes.Direction },
			{ name = 'matchSpeed', required = false, type = ParameterTypes.Boolean },
		},
		actionFunction = issueOrders,
	}
}
