
function widget:GetInfo()
	return {
		name      = 'Armageddon Countdown',
		desc      = '',
		author    = 'Niobium',
		date      = 'May 2011',
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end
----------------------------------------------------------------
-- Load?
----------------------------------------------------------------

local armageddonTime = 60 * (tonumber((Spring.GetModOptions() or {}).armageddontime) or 0)
if armageddonTime <= 0 then
    return false
end

----------------------------------------------------------------
----------------------------------------------------------------

local vsx,vsy = Spring.GetViewGeometry()
local font, chobbyInterface, gameStarted

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

function widget:Initialize()
	widget:ViewResize()
end

function widget:ViewResize()
    vsx,vsy = Spring.GetViewGeometry()

	font = WG['fonts'].getFont(nil, 1, 0.2, 1.3)
end

function widget:GameFrame(n)
    if n == 1 then
        gameStarted = true
    end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then return end
    local timeLeft = armageddonTime - Spring.GetGameSeconds()
    if timeLeft <= 300 and gameStarted then
        local vsx, vsy = gl.GetViewSizes()
        font:Begin()
        if timeLeft <= 0 then
            font:Print('\255\255\1\1ARMAGEDDON', 0.5 * vsx, 0.25 * vsy, 20, 'cvo')
        elseif timeLeft <= 60 then
            font:Print(string.format('\255\255\1\1Armageddon imminent... %i:%02i', timeLeft / 60, timeLeft % 60), 0.5 * vsx, 0.25 * vsy, 20, 'cvo')
        else
            font:Print(string.format('\255\255\255\1Armageddon approaches... %i:%02i', timeLeft / 60, timeLeft % 60), 0.5 * vsx, 0.25 * vsy, 20, 'cvo')
        end
        font:End()
    end
end

function widget:GameOver()
	widgetHandler:RemoveWidget(self)
end
