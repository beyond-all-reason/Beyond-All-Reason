
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
    if Spring.GetGameFrame()>0 then
		if Spring.GetSpectatingState() then
			TurnOffLOS()
		else
			TurnOnLOS()
		end
    end
end

function widget:GameStart()
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
	if Spring.GetSpectatingState() then
		TurnOffLOS()
	else
		TurnOnLOS()
	end
end
