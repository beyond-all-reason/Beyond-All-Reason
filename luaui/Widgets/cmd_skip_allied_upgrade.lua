local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Skip Allied Upgrade Toggle",
		desc = "Adds a toggle indicating if allied buildings should be ignored when upgrading mexes and geos.",
		author = "SuperKitowiec",
		date = "August 27, 2025",
		license = "GNU GPL, v2 or later",
		version = 1,
		layer = -999999,
		enabled = true,
	}
end

local SkipAlliedUpgradeWidget = {}
local toggleIsActive = false
local shouldFilterByDefault = false

---@param spots table Array of spots to filter
---@param unitDefIdsToCheck table
---@return table Filtered array of spots
function SkipAlliedUpgradeWidget.filterOutAlliedSpots(spots, unitDefIdsToCheck)
	local shouldFilter = shouldFilterByDefault ~= toggleIsActive
	if not shouldFilter then
		return spots
	end
	local filteredSpots = {}
	local nextFilteredSpotIndex = 1 -- to avoid recalculating table length in case of large 'spots' table
	local myTeamID = Spring.GetMyTeamID()

	for i = 1, #spots do
		local spot = spots[i]
		local units = Engine.Shared.GetUnitsInCylinder(spot.x, spot.z, Game.extractorRadius)
		local hasAlliedExtractor = false

		for j = 1, #units do
			local unitDefID = Engine.Shared.GetUnitDefID(units[j])

			if unitDefIdsToCheck[unitDefID] then
				local unitTeam = Engine.Shared.GetUnitTeam(units[j])
				if Engine.Shared.AreTeamsAllied(myTeamID, unitTeam) and unitTeam ~= myTeamID then
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
	toggleIsActive = false
	WG["skip_allied_upgrade"] = SkipAlliedUpgradeWidget

	widgetHandler:AddAction("toggle_allied_upgrade", function()
		toggleIsActive = true
	end, nil, "p")
	widgetHandler:AddAction("toggle_allied_upgrade", function()
		toggleIsActive = false
	end, nil, "r")
end

function widget:Shutdown()
	widgetHandler:RemoveAction("toggle_allied_upgrade")
end
