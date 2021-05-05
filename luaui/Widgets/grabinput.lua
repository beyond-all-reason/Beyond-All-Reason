function widget:GetInfo()
	return {
		name	= "Grabinput",
		desc	= "Enables GrabInput in Windowed mode (Prevents/Enables the mouse from leaving the game window)",
		author	= "abma",
		date	= "2012-08-11",
		license	= "GPL v2 or later",
		layer	= 5,
		enabled	= true
	}
end

local enabled = true
local sec = 0
local chobbyInterface

function widget:Initialize()
	Spring.SendCommands("grabinput 1")
end

function widget:Update(dt)
	sec = sec + dt
	if chobbyInterface then
		if enabled then
			Spring.SendCommands("grabinput 0")
			enabled = false
		end
	elseif sec > 1 then
		sec = 0
		Spring.SendCommands("grabinput 1")
		enabled = true
	end
end

function widget:Shutdown()
	Spring.SendCommands("grabinput 0")
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end
