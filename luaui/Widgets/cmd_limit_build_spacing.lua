local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Limit Build Spacing",
		desc = "Limits buildspacing to a maximum distance",
		author = "Floris",
		date = "June 2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local limit = 16
function widget:Update()
	local _, cmdID = SpringUnsynced.GetActiveCommand()
	if cmdID and cmdID < 0 then
		if SpringUnsynced.GetBuildSpacing() > limit then
			SpringUnsynced.SetBuildSpacing(limit)
		end
	end
end
