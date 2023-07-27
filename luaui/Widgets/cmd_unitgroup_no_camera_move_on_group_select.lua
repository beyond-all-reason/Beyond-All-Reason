local versionNumber = "1.0"

function widget:GetInfo()
	return {
		name      = "Unit Groups - No camera move on group select",
		desc      = "Disables the camera movement if you select a unit group twice [v" .. string.format("%s", versionNumber ) .. "]",
		author    = "very_bad_soldier",
		date      = "Januar 6, 2013",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = false
	}
end

local spGetSelectedUnits = Spring.GetSelectedUnits
local spSelectUnitArray	 = Spring.SelectUnitArray

function widget:CommandsChanged( id, params, options )
	spSelectUnitArray( spGetSelectedUnits() )
end