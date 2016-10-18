
function widget:GetInfo()
	return {
		name      = "LOS View",
		desc      = "Turns LOS view on when playing and off when becomming spectator.",
		author    = "Bluestone",
		date      = "",
		license   = "Round Objects",
		layer     = 0,
		enabled   = true
	}
end

local myPlayerID = Spring.GetMyPlayerID()
local lastMapDrawMode = Spring.GetMapDrawMode()

function TurnOnLOS()
    if Spring.GetMapDrawMode()~="los" then
        Spring.SendCommands("togglelos")
    end
end

function TurnOffLOS()
    if Spring.GetMapDrawMode()=="los" then
        Spring.SendCommands("togglelos")
    end
end

function widget:Initialize()
	if (Spring.GetGameFrame() > 0 and lastMapDrawMode == "los") then
		TurnOnLOS()
	else
		TurnOffLOS()
	end
end

function widget:GameStart()
	myPlayerID = Spring.GetMyPlayerID()
	if Spring.GetSpectatingState() then
		TurnOffLOS()
	else
		TurnOnLOS()
	end
end

function widget:Shutdown()
    TurnOffLOS()
end

function widget:PlayerChanged(playerID)
	if Spring.GetGameFrame() > 0 then
		if playerID == myPlayerID then
			if Spring.GetSpectatingState() then
				TurnOffLOS()
			else
				TurnOnLOS()
			end
		end
	end
end

function widget:GetConfigData() --save config
	return {lastMapDrawMode=Spring.GetMapDrawMode()}
end

function widget:SetConfigData(data) --load config
	if data.lastMapDrawMode then
		lastMapDrawMode = data.lastMapDrawMode
	end
end

