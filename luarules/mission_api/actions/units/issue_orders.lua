local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local FormationOrders = require("modules/formation_orders")

-- A Direction: a compass angle (0 north, clockwise) as a heading, or the point to face.
local function getFacing(direction)
	if direction and direction.angle then
		-- TODO: refactor to call CompassAngleToHeading when it is merged
		return math.rad(180 - direction.angle)
	end
	return direction
end

local function issueOrders(unitName, orders, formation)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

	local convertedOrders = GG['MissionAPI'].Modules.Loadout.ConvertOrdersTargetingNames(orders)
	local unitIDs = GG['MissionAPI'].trackedUnitIDs[unitName]

	-- Fence around mission-issued orders for UnitOrdered triggers using `ignoreMissionActions`.
	GG['MissionAPI'].issuingOrders = true
	if formation then
		local options = {
			facing = getFacing(formation.direction),
			pace = formation.matchSpeed and GG['MissionAPIActionHelper'].matchFormationSpeed or nil,
		}
		FormationOrders.GiveFormationOrders(table.keys(unitIDs), convertedOrders, options)
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
			-- With formation, each MOVE, FIGHT and PATROL order sends each unit to its own spot: the group keeps
			-- its shape around the order's point, or spreads along a line when the order has several points.
			-- { direction = Direction }: the way the shape faces at each point, as in MoveUnits.
			-- { matchSpeed = true }: the ground units arrive together at the first point.
			{ name = 'formation', required = false, type = ParameterTypes.Formation },
		},
		actionFunction = issueOrders,
	}
}
