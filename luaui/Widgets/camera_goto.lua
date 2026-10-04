local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Camera Goto",
		desc = "Target camera to map position. /goto x z",
		author = "Floris",
		date = "June 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local function handleGoto(_, _, args)
	if not args[2] then
		return
	end
	local x, z = tonumber(args[1]), tonumber(args[2])
	if not x or not z then
		return
	end
	Spring.SetCameraTarget(x, Spring.GetGroundHeight(x,z), z)
end


function widget:Shutdown()
	widgetHandler:RemoveAction("goto")
end

function widget:Initialize()
	widgetHandler:AddAction("goto", handleGoto, nil, "t")
end
