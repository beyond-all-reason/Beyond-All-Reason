local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "DEBUG NOMERGE1",
		desc = "Minimal reproducing example for the gl.Blending bug",
		author = "TheDujin",
		date = "April 2026",
		license = "Irrelevant",
		layer = 1,
		enabled = true
	}
end

local lastEchoFrame = 0

function widget:Initialize()

end


function widget:DrawScreen()
	gl.Blending(false)
	local frame = Spring.GetGameFrame()
	if frame - lastEchoFrame >= 60 then
		lastEchoFrame = frame
		Spring.Echo("REMOVE DEBUG NOMERGE WIDGET LAYER 1 BEFORE MERGE")
	end
end
