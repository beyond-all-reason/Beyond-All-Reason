local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Toggle Key",
		desc = "Allows a toggle to be activated on key press and deactivated on key release",
		author = "hihoman23",
		date = "Feb 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- cmd, optLine, optWords, data, isRepeat, release, actions
function ToggleCMD(_ , optLine)
    Spring.SetActiveCommand(optLine)
end

function widget:Initialize()
    widgetHandler:AddAction("toggle", ToggleCMD, nil, "pr")
end