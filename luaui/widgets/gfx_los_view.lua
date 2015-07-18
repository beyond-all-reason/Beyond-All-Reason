
function widget:GetInfo()
	return {
		name      = "LOS View",
		desc      = "Turns LOS view on while the game is in progress",
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
        TurnOnLOS()
    end
end

function widget:GameStart()
    TurnOnLOS()
end

function widget:Shutdown()
    TurnOffLOS()
end
