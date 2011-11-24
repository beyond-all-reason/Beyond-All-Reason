function widget:GetInfo()
  return {
    name      = "Start Point Adder",
    desc      = "Add team start points once the game begins",
    author    = "abma",
    date      = "July 05, 2011",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

function widget:Initialize()
	local _, _, spec = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
	if spec then
		widgetHandler:RemoveWidget()
		return false
	end
end

function widget:Update()
	if (Spring.GetGameSeconds() > 0) then
		local x, y, z = Spring.GetTeamStartPosition(Spring.GetMyTeamID())
		local id=Spring.GetMyPlayerID()
		Spring.MarkerAddPoint(x, y, z, "Start " .. id )
		widgetHandler:RemoveWidget()
	end
end
