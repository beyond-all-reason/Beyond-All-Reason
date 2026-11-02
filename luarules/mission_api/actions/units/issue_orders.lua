local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function issueOrders(unitName, orders)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

	local loadout = GG['MissionAPI'].Modules.Loadout
	local gatherWaits = GG['MissionAPI'].Modules.GatherWaits
	local units = GG['MissionAPI'].trackedUnitIDs[unitName]
	local taggedOrders, gatherKeys = gatherWaits.TagOrders(orders)

	-- At each GATHERWAIT the units of the name that can gather wait for each other; the others take the
	-- orders as written.
	local gatherers, others = units, {}
	if #gatherKeys > 0 then
		gatherers = {}
		for unitID in pairs(units) do
			if gatherWaits.CanGather(UnitDefs[Spring.GetUnitDefID(unitID)]) then
				gatherers[unitID] = true
			else
				others[unitID] = true
			end
		end
	end

	-- Fence around mission-issued orders for UnitOrdered triggers using `ignoreMissionActions`.
	GG['MissionAPI'].issuingOrders = true
	Spring.GiveOrderArrayToUnitMap(gatherers, loadout.ConvertOrdersTargetingNames(taggedOrders))
	if next(others) then
		Spring.GiveOrderArrayToUnitMap(others, loadout.ConvertOrdersTargetingNames(orders))
	end
	GG['MissionAPI'].issuingOrders = nil

	gatherWaits.Add(gatherKeys, gatherers)
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
