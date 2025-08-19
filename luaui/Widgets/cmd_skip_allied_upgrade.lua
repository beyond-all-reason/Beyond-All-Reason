local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Skip Allied Upgrade Toggle",
		desc = "Adds a flag indicating if allied buildings should be ignored when upgrading mexes and geos + a command to toggle this flag.",
		author = "SuperKitowiec",
		date = "August 27, 2025",
		license = "GNU GPL, v2 or later",
		version = 1,
		layer = -999999,
		enabled = true,
	}
end

local skipAlliedBuildings = false

local SkipAlliedUpgradeWidget = {}

---@param spots table Array of spots to filter
---@param unitDefIdsToCheck table
---@return table Filtered array of spots
function SkipAlliedUpgradeWidget.filterOutAlliedSpots(spots, unitDefIdsToCheck)
	if not skipAlliedBuildings then
		return spots
	end
	local filteredSpots = {}
	local nextFilteredSpotIndex = 1 -- to avoid recalculating table length in case of large 'spots' table
	local myTeamID = Spring.GetMyTeamID()

	for i = 1, #spots do
		local spot = spots[i]
		local units = Spring.GetUnitsInCylinder(spot.x, spot.z, Game.extractorRadius)
		local hasAlliedExtractor = false

		for j = 1, #units do
			local unitDefID = Spring.GetUnitDefID(units[j])

			if unitDefIdsToCheck[unitDefID] then
				local unitTeam = Spring.GetUnitTeam(units[j])
				if Spring.AreTeamsAllied(myTeamID, unitTeam) and unitTeam ~= myTeamID then
					hasAlliedExtractor = true
					break
				end
			end
		end

		if not hasAlliedExtractor then
			filteredSpots[nextFilteredSpotIndex] = spot
			nextFilteredSpotIndex = nextFilteredSpotIndex + 1
		end
	end
	return filteredSpots
end

function widget:Initialize()
	skipAlliedBuildings = false
	WG['skip_allied_upgrade'] = SkipAlliedUpgradeWidget

	widgetHandler:AddAction("skip_allied_upgrade", function() skipAlliedBuildings = true end, nil, "p")
	widgetHandler:AddAction("skip_allied_upgrade", function() skipAlliedBuildings = false end, nil, "r")
end

function widget:Shutdown()
	widgetHandler:RemoveAction("skip_allied_upgrade")
end


